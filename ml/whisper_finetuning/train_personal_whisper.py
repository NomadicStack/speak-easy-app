"""Train Whisper on the personal split manifest."""

from __future__ import annotations

import argparse
import csv
import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import librosa
import numpy as np
import pandas as pd
import torch
from datasets import Dataset
from jiwer import cer, wer
from transformers import AutoModelForSpeechSeq2Seq, Seq2SeqTrainer, Seq2SeqTrainingArguments, WhisperProcessor


SPLITS = ("train", "test", "holdout")


@dataclass
class DataCollatorSpeechSeq2SeqWithPadding:
    """Pad Whisper input features and labels for a batch."""

    processor: Any

    def __call__(self, features):
        """Return a padded batch with ignored label padding."""
        input_features = [{"input_features": f["input_features"]} for f in features]
        batch = self.processor.feature_extractor.pad(input_features, return_tensors="pt")

        label_features = [{"input_ids": f["labels"]} for f in features]
        labels_batch = self.processor.tokenizer.pad(label_features, return_tensors="pt")
        labels = labels_batch["input_ids"].masked_fill(labels_batch.attention_mask.ne(1), -100)

        if (labels[:, 0] == self.processor.tokenizer.bos_token_id).all().item():
            labels = labels[:, 1:]

        batch["labels"] = labels
        return batch


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-model", default="openai/whisper-small.en")
    parser.add_argument("--mode", choices=["full", "lora"], default="full")
    parser.add_argument("--run-name", required=True)
    parser.add_argument("--metadata-csv", default="data/personal/metadata_splits_20260501.csv")
    parser.add_argument("--data-root", default="data/personal")
    parser.add_argument("--runs-root", default="checkpoints/experiments")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--max-steps", type=int, default=250)
    parser.add_argument("--gradient-accumulation-steps", type=int, default=8)
    parser.add_argument("--learning-rate", type=float, default=None)
    parser.add_argument("--eval-steps", type=int, default=10)
    parser.add_argument("--save-steps", type=int, default=10)
    parser.add_argument("--save-total-limit", type=int, default=5)
    parser.add_argument("--seed", type=int, default=3407)
    parser.add_argument("--skip-baseline", action="store_true")
    parser.add_argument("--skip-post-train-eval", action="store_true")
    parser.add_argument("--train-on-all", action="store_true")
    parser.add_argument("--resume-from-checkpoint", default=None)
    parser.add_argument("--allow-prompt-overlap", action="store_true")
    parser.add_argument("--lora-r", type=int, default=8)
    parser.add_argument("--lora-alpha", type=int, default=16)
    parser.add_argument("--lora-dropout", type=float, default=0.05)
    return parser.parse_args()


def seed_everything(seed: int) -> None:
    """Seed Python, NumPy, and Torch."""
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


def configure_model(model: torch.nn.Module, processor: WhisperProcessor) -> None:
    """Set Whisper generation and token IDs for training."""
    model.config.forced_decoder_ids = None
    model.generation_config.forced_decoder_ids = None
    model.generation_config.max_length = None
    for cfg in (model.config, model.generation_config):
        cfg.pad_token_id = processor.tokenizer.pad_token_id
        cfg.bos_token_id = processor.tokenizer.bos_token_id
        cfg.eos_token_id = processor.tokenizer.eos_token_id
    model.config.use_cache = False


def add_lora(model: torch.nn.Module, args: argparse.Namespace) -> torch.nn.Module:
    """Attach LoRA adapters to Whisper attention projections."""
    from peft import LoraConfig, get_peft_model

    config = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        bias="none",
        target_modules=["q_proj", "v_proj"],
    )
    model = get_peft_model(model, config)
    model.print_trainable_parameters()
    return model


def load_records(metadata_csv: Path, data_root: Path) -> list[dict[str, str]]:
    """Load split records from the personal manifest."""
    records = []
    with metadata_csv.open(newline="") as f:
        for row in csv.DictReader(f):
            audio_path = data_root / row["filepath"]
            text = row["text"].strip()
            split = row["splits"].strip()
            if audio_path.exists() and text and split in SPLITS:
                records.append(
                    {
                        "audio_path": str(audio_path),
                        "relpath": row["filepath"],
                        "text": text,
                        "scenario_group": row.get("scenario_group", ""),
                        "norm_text": row.get("norm_text", ""),
                        "text_overlap_eval_group": row.get("text_overlap_eval_group", ""),
                        "split": split,
                    }
                )
    return records


def load_one(rec: dict[str, str]) -> dict[str, Any]:
    """Load one audio/text record."""
    audio, _ = librosa.load(rec["audio_path"], sr=16000, mono=True)
    return {
        "audio": np.asarray(audio, dtype=np.float32),
        "audio_path": rec["audio_path"],
        "relpath": rec["relpath"],
        "text": rec["text"],
        "scenario_group": rec["scenario_group"],
        "norm_text": rec["norm_text"],
        "text_overlap_eval_group": rec["text_overlap_eval_group"],
        "split": rec["split"],
    }


def assert_no_prompt_leak(items_by_split: dict[str, list[dict[str, Any]]]) -> None:
    """Assert normalized prompts are disjoint across splits."""
    for i, left in enumerate(SPLITS):
        for right in SPLITS[i + 1 :]:
            overlap = {x["norm_text"] for x in items_by_split[left]} & {x["norm_text"] for x in items_by_split[right]}
            if overlap:
                raise ValueError(f"{left}/{right} norm_text overlap: {sorted(overlap)[:10]}")


def prepare_datasets(train_items: list[dict[str, Any]], eval_items: list[dict[str, Any]], processor: WhisperProcessor) -> dict[str, Dataset]:
    """Convert loaded items into Whisper datasets."""
    def prepare_dataset(batch):
        """Convert one loaded item into Whisper input features and labels."""
        features = processor.feature_extractor(batch["audio"], sampling_rate=16000).input_features[0]
        labels = processor.tokenizer(batch["text"]).input_ids
        return {"input_features": features, "labels": labels, "text": batch["text"]}

    datasets = {}
    for split, items in (("train", train_items), ("eval", eval_items)):
        if not items:
            continue
        datasets[split] = Dataset.from_list(items).map(
            prepare_dataset,
            remove_columns=list(items[0].keys()),
        )
    return datasets


def normalize_metric_text(text: str) -> str:
    """Normalize text for metric comparison."""
    return str(text).lower().strip()


def transcribe(model, processor: WhisperProcessor, audio: np.ndarray, device: str, dtype: torch.dtype, max_length: int) -> str:
    """Transcribe one audio array."""
    inputs = processor(audio, sampling_rate=16000, return_tensors="pt", return_attention_mask=True)
    input_features = inputs.input_features.to(device, dtype=dtype)
    attention_mask = inputs.attention_mask.to(device)
    with torch.inference_mode():
        pred_ids = model.generate(input_features=input_features, attention_mask=attention_mask, max_length=max_length)
    return processor.batch_decode(pred_ids, skip_special_tokens=True)[0].strip()


def evaluate_items(model, processor, items: list[dict[str, Any]], label: str, device: str, dtype: torch.dtype) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Evaluate transcription quality for loaded items."""
    rows = []
    refs, preds = [], []
    model.eval()
    for i, item in enumerate(items):
        ref = normalize_metric_text(item["text"])
        pred = normalize_metric_text(transcribe(model, processor, item["audio"], device, dtype, max_length=32))
        refs.append(ref)
        preds.append(pred)
        rows.append(
            {
                "eval_split": label,
                "relpath": item["relpath"],
                "split": item["split"],
                "scenario_group": item["scenario_group"],
                "norm_text": item["norm_text"],
                "text_overlap_eval_group": item.get("text_overlap_eval_group", ""),
                "ref": ref,
                "pred": pred,
                "correct": pred == ref,
            }
        )
        if (i + 1) % 10 == 0 or i == len(items) - 1:
            print(f"  {label} {i+1}/{len(items)}: ref={ref!r} pred={pred!r}")
    metrics = {"split": label, "wer": wer(refs, preds), "cer": cer(refs, preds), "rows": len(items)}
    return rows, metrics


def evaluate_all(
    model,
    processor,
    items_by_split: dict[str, list[dict[str, Any]]],
    train_items: list[dict[str, Any]],
    device: str,
    dtype: torch.dtype,
    stage: str,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Evaluate train, test, holdout, and all rows."""
    prediction_rows = []
    metric_rows = []
    all_items = items_by_split["train"] + items_by_split["test"] + items_by_split["holdout"]
    train_texts = {item["norm_text"] for item in train_items}
    seen_test = [item for item in items_by_split["test"] if item["norm_text"] in train_texts]
    unseen_test = [item for item in items_by_split["test"] if item["norm_text"] not in train_texts]
    eval_groups = [
        ("train", items_by_split["train"]),
        ("test", items_by_split["test"]),
        ("test_seen_text", seen_test),
        ("test_unseen_text", unseen_test),
        ("holdout", items_by_split["holdout"]),
        ("all", all_items),
    ]
    for split, items in eval_groups:
        if not items:
            continue
        print(f"{stage} on {split}...")
        rows, metrics = evaluate_items(model, processor, items, split, device, dtype)
        prediction_rows.extend({**row, "stage": stage} for row in rows)
        metric_rows.append({**metrics, "stage": stage})
        print(f"{stage} {split} WER = {metrics['wer']*100:.0f}%  CER = {metrics['cer']*100:.0f}%")
    return pd.DataFrame(prediction_rows), pd.DataFrame(metric_rows)


def build_training_args(args: argparse.Namespace, output_dir: Path, device: str, has_eval: bool) -> Seq2SeqTrainingArguments:
    """Build version-compatible Seq2SeqTrainingArguments."""
    kwargs = dict(
        output_dir=str(output_dir),
        per_device_train_batch_size=1,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate if args.learning_rate is not None else (1e-4 if args.mode == "lora" else 1e-5),
        warmup_steps=10,
        max_steps=args.max_steps,
        gradient_checkpointing=True,
        fp16=(device == "cuda"),
        predict_with_generate=True,
        generation_max_length=32,
        per_device_eval_batch_size=4,
        logging_steps=5,
        save_steps=args.save_steps,
        save_total_limit=args.save_total_limit,
        load_best_model_at_end=has_eval,
        save_strategy="steps",
        report_to="none",
        remove_unused_columns=False,
    )
    if has_eval:
        kwargs |= {
            "eval_steps": args.eval_steps,
            "greater_is_better": False,
            "metric_for_best_model": "eval_loss",
        }
    try:
        return Seq2SeqTrainingArguments(eval_strategy="steps" if has_eval else "no", **kwargs)
    except TypeError:
        return Seq2SeqTrainingArguments(evaluation_strategy="steps" if has_eval else "no", **kwargs)


def save_run_config(args: argparse.Namespace, run_dir: Path, item_counts: dict[str, int]) -> None:
    """Save run configuration as JSON."""
    config = vars(args) | {"item_counts": item_counts}
    (run_dir / "run_config.json").write_text(json.dumps(config, indent=2) + "\n")


def order_metrics(metrics_df: pd.DataFrame) -> pd.DataFrame:
    """Order metrics by split, then evaluation stage."""
    split_order = ["train", "test", "test_seen_text", "test_unseen_text", "holdout", "all"]
    stage_order = ["baseline", "post_train"]
    ordered = metrics_df.copy()
    ordered["split_order"] = ordered["split"].map({name: i for i, name in enumerate(split_order)}).fillna(len(split_order))
    ordered["stage_order"] = ordered["stage"].map({name: i for i, name in enumerate(stage_order)}).fillna(len(stage_order))
    ordered = ordered.sort_values(["split_order", "stage_order", "split", "stage"]).drop(columns=["split_order", "stage_order"])
    return ordered.reset_index(drop=True)


def dataframe_to_markdown(data: pd.DataFrame) -> str:
    """Render a small dataframe as a Markdown table."""
    columns = list(data.columns)
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join(["---"] * len(columns)) + " |",
    ]
    for row in data.itertuples(index=False, name=None):
        lines.append("| " + " | ".join(str(value) for value in row) + " |")
    return "\n".join(lines)


def write_markdown_report(
    args: argparse.Namespace,
    result_dir: Path,
    run_dir: Path,
    model_dir: Path,
    metrics_df: pd.DataFrame,
) -> None:
    """Write a Markdown evaluation report."""
    result_dir.mkdir(parents=True, exist_ok=True)
    project_root = result_dir.parents[1]
    report_path = result_dir / "report.md"
    display_df = metrics_df[["split", "stage", "rows", "wer_pct", "cer_pct"]].copy()
    lines = [
        f"# {args.run_name}",
        "",
        "## Config",
        "",
        f"- Base model: `{args.base_model}`",
        f"- Mode: `{args.mode}`",
        f"- Max steps: `{args.max_steps}`",
        f"- Gradient accumulation steps: `{args.gradient_accumulation_steps}`",
        f"- Learning rate: `{args.learning_rate if args.learning_rate is not None else ('1e-4' if args.mode == 'lora' else '1e-5')}`",
        f"- Train on all rows: `{args.train_on_all}`",
        f"- Eval steps: `{args.eval_steps}`",
        f"- Save steps: `{args.save_steps}`",
        f"- Metadata: `{args.metadata_csv}`",
        f"- Run dir: `{run_dir.relative_to(project_root) if run_dir.is_relative_to(project_root) else run_dir}`",
        f"- Saved model: `{model_dir.relative_to(project_root) if model_dir.is_relative_to(project_root) else model_dir}`",
        "",
        "## Metrics",
        "",
        dataframe_to_markdown(display_df),
        "",
        "## Artifacts",
        "",
        f"- Metrics CSV: `{(result_dir / 'metrics.csv').relative_to(project_root) if (result_dir / 'metrics.csv').is_relative_to(project_root) else result_dir / 'metrics.csv'}`",
        f"- Predictions CSV: `{(result_dir / 'predictions.csv').relative_to(project_root) if (result_dir / 'predictions.csv').is_relative_to(project_root) else result_dir / 'predictions.csv'}`",
        f"- Trainer output: `{(run_dir / 'trainer').relative_to(project_root) if (run_dir / 'trainer').is_relative_to(project_root) else run_dir / 'trainer'}`",
        "",
    ]
    report_path.write_text("\n".join(lines))
    print(f"Saved Markdown report to {report_path}")


def main() -> None:
    """Run training and evaluation."""
    args = parse_args()
    seed_everything(args.seed)

    project_root = Path(__file__).resolve().parents[1]
    data_root = (project_root / args.data_root).resolve()
    metadata_csv = (project_root / args.metadata_csv).resolve()
    run_dir = (project_root / args.runs_root / args.run_name).resolve()
    result_dir = (project_root / args.results_root / args.run_name).resolve()
    output_dir = run_dir / "trainer"
    model_dir = run_dir / ("adapter" if args.mode == "lora" else "model")
    run_dir.mkdir(parents=True, exist_ok=True)
    result_dir.mkdir(parents=True, exist_ok=True)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float32
    print(f"Device: {device}")
    if device == "cuda":
        print(torch.cuda.get_device_name(0))

    print(f"Metadata: {metadata_csv}")
    print(f"Run dir: {run_dir}")
    records = load_records(metadata_csv, data_root)
    print("Decoding personal audio...")
    all_items = [load_one(r) for r in records]
    items_by_split = {split: [it for it in all_items if it["split"] == split] for split in SPLITS}
    if not args.allow_prompt_overlap and not args.train_on_all:
        assert_no_prompt_leak(items_by_split)
    print("Counts:", {split: len(items_by_split[split]) for split in SPLITS}, "all", len(all_items))
    train_items = all_items if args.train_on_all else items_by_split["train"]
    eval_items = all_items if args.train_on_all else items_by_split["test"]
    print(f"Trainer datasets: train={len(train_items)} eval={len(eval_items)}")
    item_counts = {split: len(items_by_split[split]) for split in SPLITS}
    item_counts |= {"trainer_train": len(train_items), "trainer_eval": len(eval_items)}
    save_run_config(args, run_dir, item_counts)

    processor = WhisperProcessor.from_pretrained(args.base_model, language="english", task="transcribe")
    model = AutoModelForSpeechSeq2Seq.from_pretrained(args.base_model, dtype=dtype, low_cpu_mem_usage=True).to(device)
    configure_model(model, processor)
    if args.mode == "lora":
        model = add_lora(model, args)
        model.enable_input_require_grads()
    model.eval()

    datasets = prepare_datasets(train_items, eval_items, processor)
    metrics_frames = []
    predictions_frames = []

    if not args.skip_baseline:
        preds, metrics = evaluate_all(model, processor, items_by_split, train_items, device, dtype, "baseline")
        predictions_frames.append(preds)
        metrics_frames.append(metrics)

    model.train()
    model.config.use_cache = False
    if device == "cuda":
        model.float()
    print(f"Trainable params: {sum(p.numel() for p in model.parameters() if p.requires_grad):,}")
    has_eval = "eval" in datasets

    trainer_kwargs = dict(
        args=build_training_args(args, output_dir, device, has_eval),
        model=model,
        train_dataset=datasets["train"],
        data_collator=DataCollatorSpeechSeq2SeqWithPadding(processor=processor),
    )
    if has_eval:
        trainer_kwargs["eval_dataset"] = datasets["eval"]
    try:
        trainer = Seq2SeqTrainer(processing_class=processor, **trainer_kwargs)
    except TypeError:
        trainer = Seq2SeqTrainer(tokenizer=processor.feature_extractor, **trainer_kwargs)

    trainer.train(resume_from_checkpoint=args.resume_from_checkpoint)
    model.save_pretrained(model_dir)
    processor.save_pretrained(model_dir)
    print(f"Saved model to {model_dir}")

    if args.skip_post_train_eval:
        print("Skipping post-training transcription eval.")
        return

    preds, metrics = evaluate_all(model, processor, items_by_split, train_items, device, dtype, "post_train")
    predictions_frames.append(preds)
    metrics_frames.append(metrics)

    metrics_df = pd.concat(metrics_frames, ignore_index=True)
    metrics_df["wer_pct"] = (metrics_df["wer"] * 100).round(0).astype(int)
    metrics_df["cer_pct"] = (metrics_df["cer"] * 100).round(0).astype(int)
    metrics_df = order_metrics(metrics_df)
    predictions_df = pd.concat(predictions_frames, ignore_index=True)
    metrics_df.to_csv(result_dir / "metrics.csv", index=False)
    predictions_df.to_csv(result_dir / "predictions.csv", index=False)
    write_markdown_report(args, result_dir, run_dir, model_dir, metrics_df)
    print(metrics_df[["split", "stage", "rows", "wer_pct", "cer_pct"]].to_string(index=False))


if __name__ == "__main__":
    main()
