# Whisper Fine-Tuning

This folder contains the Python scripts used to fine-tune the custom Whisper ASR model for SpeakEasy.

## Files

- `train_personal_whisper.py`: trains Whisper on a filepath/text/split manifest.
- `evaluate_personal_whisper_metadata.py`: evaluates saved Whisper checkpoints on a metadata CSV.
- `select_whisper_checkpoint_by_wer.py`: selects the best checkpoint by WER, CER, and exact match.
- `normalize_whisper_metadata.py`: creates normalized phrase-level metadata for deployment scoring.
- `whisper_text_normalization.py`: shared text normalization helpers.

## Best Small Whisper Run

The deployment model was trained from `openai/whisper-small.en` with full fine-tuning.

```bash
python ml/whisper_finetuning/train_personal_whisper.py \
  --base-model openai/whisper-small.en \
  --mode full \
  --run-name whisper-small-deploy-all-2500-20260511 \
  --metadata-csv data/personal/metadata_whisper_deploy_all_20260510.csv \
  --train-on-all \
  --max-steps 2500 \
  --learning-rate 1e-05 \
  --gradient-accumulation-steps 1 \
  --eval-steps 100 \
  --save-steps 100 \
  --save-total-limit 20 \
  --skip-baseline \
  --skip-post-train-eval
```

The selected deployment checkpoint was `checkpoint-2300`, chosen by normalized phrase-level scoring.

## Data Policy

Private audio, raw datasets, and generated model weights are intentionally not committed to this repository.
