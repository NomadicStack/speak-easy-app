"""Evaluate saved Whisper models on a simple filepath/text manifest."""

from __future__ import annotations

import argparse
import csv
import gc
import json
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
    parser.add_argument("--metadata-csv", default="data/personal/metadata4.csv")
    parser.add_argument("--data-root", default="data/personal")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--max-length", type=int, default=64)
    parser.add_argument("--text-normalization", choices=["basic", "phrase"], default="basic")
    parser.add_argument("--model", action="append", nargs="+", metavar="MODEL", required=True)
    return parser.parse_args()


def parse_model_specs(model_args: list[list[str]]) -> list[tuple[str, str, str]]:
    """Parse model arguments into name, path, and description triples."""
    specs = []
    for spec in model_args:
        if len(spec) < 2:
            raise ValueError("--model requires NAME PATH [DESCRIPTION]")
        name, model_path, *description = spec
        specs.append((name, model_path, " ".join(description)))
    return specs


def normalize_text(text: str, mode: str) -> str:
    """Normalize text for metric comparison."""
    if mode == "phrase":
        return normalize_phrase(text)
    return normalize_basic(text)


def load_items(metadata_csv: Path, data_root: Path) -> list[dict[str, Any]]:
    """Load audio items from a filepath/text manifest."""
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
                    "audio_path": str(audio_path),
                    "audio": np.asarray(audio, dtype=np.float32),
                    "text": row["text"].strip(),
                }
            )
    return items


def load_model_and_processor(model_path: Path, device: str, dtype: torch.dtype):
    """Load a full Whisper model or a PEFT adapter."""
    if (model_path / "adapter_config.json").exists():
        with (model_path / "adapter_config.json").open() as f:
            adapter_config = json.load(f)
        base_name = adapter_config.get("base_model_name_or_path", "openai/whisper-small.en")
        processor_source = model_path if (model_path / "tokenizer.json").exists() else base_name
        processor = WhisperProcessor.from_pretrained(processor_source)
        model = AutoModelForSpeechSeq2Seq.from_pretrained(base_name, dtype=dtype, low_cpu_mem_usage=True).to(device)
        from peft import PeftModel

        model = PeftModel.from_pretrained(model, model_path).to(device)
        return model, processor

    processor = WhisperProcessor.from_pretrained(model_path)
    model = AutoModelForSpeechSeq2Seq.from_pretrained(model_path, dtype=dtype, low_cpu_mem_usage=True).to(device)
    return model, processor


def transcribe(model, processor: WhisperProcessor, audio: np.ndarray, device: str, dtype: torch.dtype, max_length: int) -> str:
    """Transcribe one audio array."""
    inputs = processor(audio, sampling_rate=16000, return_tensors="pt", return_attention_mask=True)
    input_features = inputs.input_features.to(device, dtype=dtype)
    attention_mask = inputs.attention_mask.to(device)
    with torch.inference_mode():
        pred_ids = model.generate(input_features=input_features, attention_mask=attention_mask, max_length=max_length)
    return processor.batch_decode(pred_ids, skip_special_tokens=True)[0].strip()


def evaluate_model(
    name: str,
    model_path: Path,
    description: str,
    items: list[dict[str, Any]],
    device: str,
    dtype: torch.dtype,
    max_length: int,
    text_normalization: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Evaluate one saved Whisper model."""
    model, processor = load_model_and_processor(model_path, device, dtype)
    model.eval()

    rows = []
    refs, preds = [], []
    for i, item in enumerate(items):
        raw_pred = transcribe(model, processor, item["audio"], device, dtype, max_length)
        ref = normalize_text(item["text"], text_normalization)
        pred = normalize_text(raw_pred, text_normalization)
        refs.append(ref)
        preds.append(pred)
        rows.append(
            {
                "model": name,
                "description": description,
                "model_path": str(model_path),
                "filepath": item["filepath"],
                "raw_ref": item["text"],
                "raw_pred": raw_pred,
                "ref": ref,
                "pred": pred,
                "correct": pred == ref,
            }
        )
        if (i + 1) % 25 == 0 or i == len(items) - 1:
            print(f"  {name} {i + 1}/{len(items)}: ref={ref!r} pred={pred!r}")

    metrics = {
        "model": name,
        "description": description,
        "model_path": str(model_path),
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


def write_report(output_dir: Path, metrics_df: pd.DataFrame, metadata_csv: Path, text_normalization: str) -> None:
    """Write a concise Markdown report."""
    lines = [
        f"# {metadata_csv.stem} Whisper evaluation",
        "",
        f"- Text normalization: `{text_normalization}`",
        "",
        "| model | checkpoint description | rows | WER % | CER % | exact % | error |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in metrics_df.itertuples(index=False):
        description = str(row.description).replace("|", "\\|")
        error = str(getattr(row, "error", "")).replace("|", "\\|")
        lines.append(f"| {row.model} | {description} | {row.rows} | {row.wer_pct} | {row.cer_pct} | {row.exact_pct} | {error} |")
    lines += ["", "- Metrics CSV: `metrics.csv`", "- Predictions CSV: `predictions.csv`", ""]
    (output_dir / "report.md").write_text("\n".join(lines))


def main() -> None:
    """Run metadata evaluation."""
    args = parse_args()
    project_root = Path(__file__).resolve().parents[1]
    metadata_csv = (project_root / args.metadata_csv).resolve()
    data_root = (project_root / args.data_root).resolve()
    output_dir = (project_root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float32
    print(f"Device: {device}")
    print(f"Metadata: {metadata_csv}")
    print(f"Text normalization: {args.text_normalization}")
    items = load_items(metadata_csv, data_root)
    print(f"Rows: {len(items)}")

    prediction_rows = []
    metric_rows = []
    for name, model_path, description in parse_model_specs(args.model):
        resolved_path = (project_root / model_path).resolve()
        print(f"Evaluating {name}: {resolved_path}")
        try:
            rows, metrics = evaluate_model(
                name,
                resolved_path,
                description,
                items,
                device,
                dtype,
                args.max_length,
                args.text_normalization,
            )
            prediction_rows.extend(rows)
        except Exception as exc:
            metrics = {
                "model": name,
                "description": description,
                "model_path": str(resolved_path),
                "rows": len(items),
                "wer": float("nan"),
                "cer": float("nan"),
                "exact": float("nan"),
                "error": str(exc),
            }
            print(f"{name} failed: {exc}")
        metric_rows.append(metrics)
        if not pd.isna(metrics["wer"]):
            print(f"{name} WER={metrics['wer'] * 100:.2f}% CER={metrics['cer'] * 100:.2f}% exact={metrics['exact'] * 100:.2f}%")

    metrics_df = pd.DataFrame(metric_rows)
    metrics_df["wer_pct"] = (metrics_df["wer"] * 100).round(2)
    metrics_df["cer_pct"] = (metrics_df["cer"] * 100).round(2)
    metrics_df["exact_pct"] = (metrics_df["exact"] * 100).round(2)
    metrics_df = metrics_df.sort_values("wer", na_position="last")
    predictions_df = pd.DataFrame(prediction_rows)
    metrics_df.to_csv(output_dir / "metrics.csv", index=False)
    predictions_df.to_csv(output_dir / "predictions.csv", index=False)
    write_report(output_dir, metrics_df, metadata_csv, args.text_normalization)
    print(metrics_df[["model", "description", "rows", "wer_pct", "cer_pct", "exact_pct"]].to_string(index=False))


if __name__ == "__main__":
    main()
