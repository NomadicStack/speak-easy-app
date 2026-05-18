"""Select the best Whisper checkpoint by WER and CER."""

from __future__ import annotations

import argparse
import csv
import gc
import re
from pathlib import Path
from typing import Any

import librosa
import numpy as np
import pandas as pd
import torch
from jiwer import cer, wer
from transformers import AutoModelForSpeechSeq2Seq, WhisperProcessor

from whisper_text_normalization import normalize_basic, normalize_phrase


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint-root", required=True)
    parser.add_argument("--metadata-csv", default="data/personal/metadata_whisper_validation_20260509.csv")
    parser.add_argument("--data-root", default="data/personal")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--max-length", type=int, default=64)
    parser.add_argument("--text-normalization", choices=["basic", "phrase"], default="basic")
    return parser.parse_args()


def checkpoint_step(path: Path) -> int:
    """Return the numeric step for a checkpoint path."""
    match = re.search(r"checkpoint-(\d+)$", path.name)
    if not match:
        raise ValueError(f"Invalid checkpoint path: {path}")
    return int(match.group(1))


def list_checkpoints(root: Path) -> list[Path]:
    """List checkpoints sorted by step."""
    checkpoints = [path for path in root.glob("checkpoint-*") if path.is_dir()]
    if not checkpoints:
        raise FileNotFoundError(f"No checkpoint-* directories under {root}")
    return sorted(checkpoints, key=checkpoint_step)


def normalize_text(text: str, mode: str) -> str:
    """Normalize text for metric comparison."""
    if mode == "phrase":
        return normalize_phrase(text)
    return normalize_basic(text)


def load_items(metadata_csv: Path, data_root: Path) -> list[dict[str, Any]]:
    """Load validation audio items."""
    items = []
    with metadata_csv.open(newline="") as f:
        for row in csv.DictReader(f):
            audio_path = data_root / row["filepath"]
            if not audio_path.exists():
                raise FileNotFoundError(audio_path)
            audio, _ = librosa.load(audio_path, sr=16000, mono=True)
            items.append(
                {
                    "filepath": row["filepath"],
                    "audio": np.asarray(audio, dtype=np.float32),
                    "text": row["text"].strip(),
                    "split": row.get("splits", ""),
                    "source_dataset": row.get("source_dataset", ""),
                }
            )
    return items


def configure_generation(model: torch.nn.Module, processor: WhisperProcessor) -> None:
    """Set Whisper generation IDs for checkpoint evaluation."""
    model.config.forced_decoder_ids = None
    model.generation_config.forced_decoder_ids = None
    for cfg in (model.config, model.generation_config):
        cfg.pad_token_id = processor.tokenizer.pad_token_id
        cfg.bos_token_id = processor.tokenizer.bos_token_id
        cfg.eos_token_id = processor.tokenizer.eos_token_id


def load_model(checkpoint: Path, device: str, dtype: torch.dtype):
    """Load a full Whisper checkpoint and processor."""
    processor = WhisperProcessor.from_pretrained(checkpoint)
    model = AutoModelForSpeechSeq2Seq.from_pretrained(checkpoint, dtype=dtype, low_cpu_mem_usage=True).to(device)
    configure_generation(model, processor)
    return model, processor


def transcribe(model, processor: WhisperProcessor, audio: np.ndarray, device: str, dtype: torch.dtype, max_length: int) -> str:
    """Transcribe one audio array."""
    inputs = processor(audio, sampling_rate=16000, return_tensors="pt", return_attention_mask=True)
    input_features = inputs.input_features.to(device, dtype=dtype)
    attention_mask = inputs.attention_mask.to(device)
    with torch.inference_mode():
        pred_ids = model.generate(input_features=input_features, attention_mask=attention_mask, max_length=max_length)
    return processor.batch_decode(pred_ids, skip_special_tokens=True)[0].strip()


def evaluate_checkpoint(
    checkpoint: Path,
    items: list[dict[str, Any]],
    device: str,
    dtype: torch.dtype,
    max_length: int,
    text_normalization: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Evaluate one checkpoint."""
    model, processor = load_model(checkpoint, device, dtype)
    model.eval()
    rows = []
    refs, preds = [], []
    step = checkpoint_step(checkpoint)
    for item in items:
        raw_pred = transcribe(model, processor, item["audio"], device, dtype, max_length)
        ref = normalize_text(item["text"], text_normalization)
        pred = normalize_text(raw_pred, text_normalization)
        refs.append(ref)
        preds.append(pred)
        rows.append(
            {
                "checkpoint": checkpoint.name,
                "step": step,
                "checkpoint_path": str(checkpoint),
                "filepath": item["filepath"],
                "split": item["split"],
                "source_dataset": item["source_dataset"],
                "raw_ref": item["text"],
                "raw_pred": raw_pred,
                "ref": ref,
                "pred": pred,
                "correct": pred == ref,
            }
        )
    metrics = {
        "checkpoint": checkpoint.name,
        "step": step,
        "checkpoint_path": str(checkpoint),
        "rows": len(items),
        "wer": wer(refs, preds),
        "cer": cer(refs, preds),
        "exact": sum(row["correct"] for row in rows) / len(rows),
    }
    del model, processor
    gc.collect()
    if device == "cuda":
        torch.cuda.empty_cache()
    return rows, metrics


def write_report(output_dir: Path, metrics_df: pd.DataFrame, best_path: Path, text_normalization: str) -> None:
    """Write a Markdown checkpoint selection report."""
    lines = [
        "# Whisper checkpoint selection",
        "",
        f"- Best checkpoint: `{best_path}`",
        f"- Text normalization: `{text_normalization}`",
        "",
        "| checkpoint | step | rows | WER % | CER % | exact % |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in metrics_df.itertuples(index=False):
        lines.append(f"| {row.checkpoint} | {row.step} | {row.rows} | {row.wer_pct} | {row.cer_pct} | {row.exact_pct} |")
    lines += ["", "- Metrics CSV: `metrics.csv`", "- Predictions CSV: `predictions.csv`", "- Best checkpoint path: `best_checkpoint.txt`", ""]
    (output_dir / "report.md").write_text("\n".join(lines))


def main() -> None:
    """Run checkpoint selection."""
    args = parse_args()
    project_root = Path(__file__).resolve().parents[1]
    checkpoint_root = (project_root / args.checkpoint_root).resolve()
    metadata_csv = (project_root / args.metadata_csv).resolve()
    data_root = (project_root / args.data_root).resolve()
    output_dir = (project_root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float32
    items = load_items(metadata_csv, data_root)
    prediction_rows = []
    metric_rows = []
    for checkpoint in list_checkpoints(checkpoint_root):
        print(f"Evaluating {checkpoint.name}...")
        rows, metrics = evaluate_checkpoint(
            checkpoint,
            items,
            device,
            dtype,
            args.max_length,
            args.text_normalization,
        )
        prediction_rows.extend(rows)
        metric_rows.append(metrics)
        print(f"{checkpoint.name} WER={metrics['wer'] * 100:.2f}% CER={metrics['cer'] * 100:.2f}% exact={metrics['exact'] * 100:.2f}%")
    metrics_df = pd.DataFrame(metric_rows)
    metrics_df["wer_pct"] = (metrics_df["wer"] * 100).round(2)
    metrics_df["cer_pct"] = (metrics_df["cer"] * 100).round(2)
    metrics_df["exact_pct"] = (metrics_df["exact"] * 100).round(2)
    metrics_df = metrics_df.sort_values(["wer", "cer", "exact", "step"], ascending=[True, True, False, True])
    best_path = Path(metrics_df.iloc[0]["checkpoint_path"])
    pd.DataFrame(prediction_rows).to_csv(output_dir / "predictions.csv", index=False)
    metrics_df.to_csv(output_dir / "metrics.csv", index=False)
    (output_dir / "best_checkpoint.txt").write_text(str(best_path) + "\n")
    write_report(output_dir, metrics_df, best_path, args.text_normalization)
    print(f"Best checkpoint: {best_path}")


if __name__ == "__main__":
    main()
