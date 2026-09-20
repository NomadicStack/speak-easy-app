"""Import and merge Voice Studio ZIP archives sent via email into the training manifest."""

from __future__ import annotations

import argparse
import csv
import shutil
import tempfile
import zipfile
from pathlib import Path

from whisper_text_normalization import normalize_phrase


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--archive",
        required=True,
        type=Path,
        help="Path to the VoiceData_*.zip archive received via email",
    )
    parser.add_argument(
        "--data-root",
        default=Path("data/personal"),
        type=Path,
        help="Root directory for training audio and manifests",
    )
    parser.add_argument(
        "--manifest-csv",
        default="metadata_whisper_deploy_all.csv",
        help="Filename of the master manifest CSV inside data-root",
    )
    parser.add_argument(
        "--default-split",
        default="train",
        choices=["train", "test", "holdout"],
        help="Default dataset split for newly imported samples",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    archive_path = args.archive.resolve()
    data_root = args.data_root.resolve()
    manifest_path = data_root / args.manifest_csv
    audio_dest_dir = data_root / "audio"

    if not archive_path.exists():
        raise FileNotFoundError(f"Archive not found: {archive_path}")

    audio_dest_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        print(f"Extracting {archive_path.name}...")
        with zipfile.ZipFile(archive_path, "r") as zip_ref:
            zip_ref.extractall(tmp_path)

        # Locate metadata.csv inside archive
        meta_files = list(tmp_path.rglob("metadata.csv"))
        if not meta_files:
            raise FileNotFoundError("No metadata.csv found inside the ZIP archive.")

        meta_csv = meta_files[0]
        meta_dir = meta_csv.parent

        # Read existing manifest if present to prevent duplicate relpaths
        existing_relpaths = set()
        existing_rows = []
        if manifest_path.exists():
            with manifest_path.open("r", encoding="utf-8", newline="") as f:
                reader = csv.DictReader(f)
                fieldnames = reader.fieldnames or []
                for row in reader:
                    existing_relpaths.add(row["filepath"])
                    existing_rows.append(row)
        else:
            fieldnames = ["filepath", "text", "norm_text", "splits", "scenario_group", "display_text"]

        imported_count = 0
        new_rows = []

        with meta_csv.open("r", encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                raw_relpath = row["filepath"]
                src_audio = meta_dir / raw_relpath
                if not src_audio.exists():
                    # Check fallback directly under tmp
                    src_audio = tmp_path / raw_relpath
                if not src_audio.exists():
                    filename = Path(raw_relpath).name
                    matches = list(tmp_path.rglob(filename))
                    if matches:
                        src_audio = matches[0]

                if not src_audio.exists():
                    print(f"Warning: audio file not found: {raw_relpath}, skipping.")
                    continue

                # Generate unique destination filename if collision occurs
                dest_audio_name = src_audio.name
                dest_audio_path = audio_dest_dir / dest_audio_name
                counter = 1
                while dest_audio_path.exists() and f"audio/{dest_audio_name}" in existing_relpaths:
                    stem = src_audio.stem
                    ext = src_audio.suffix
                    dest_audio_name = f"{stem}_{counter}{ext}"
                    dest_audio_path = audio_dest_dir / dest_audio_name
                    counter += 1

                shutil.copy2(src_audio, dest_audio_path)
                canonical_relpath = f"audio/{dest_audio_name}"

                text = row.get("text", "").strip()
                norm_text = row.get("norm_text", "").strip()
                if not norm_text and text:
                    norm_text = normalize_phrase(text)

                split = row.get("splits", args.default_split).strip() or args.default_split
                scenario_group = row.get("scenario_group", "general").strip()

                new_row = {
                    "filepath": canonical_relpath,
                    "text": norm_text,
                    "norm_text": norm_text,
                    "display_text": text,
                    "splits": split,
                    "scenario_group": scenario_group,
                }
                # Preserve all extra columns from incoming metadata (e.g. recorded_at, original_transcription)
                for k, v in row.items():
                    if k not in new_row and k != "filepath":
                        new_row[k] = v.strip() if isinstance(v, str) else v

                new_rows.append(new_row)
                existing_relpaths.add(canonical_relpath)
                imported_count += 1

        # Write updated master manifest
        all_rows = existing_rows + new_rows
        all_fieldnames = ["filepath", "text", "norm_text", "splits", "scenario_group", "display_text"]
        for row in all_rows:
            for k in row.keys():
                if k not in all_fieldnames:
                    all_fieldnames.append(k)

        with manifest_path.open("w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=all_fieldnames)
            writer.writeheader()
            writer.writerows(all_rows)

        print(f"Successfully imported {imported_count} samples from {archive_path.name}.")
        print(f"Master manifest updated at: {manifest_path} (Total samples: {len(all_rows)})")


if __name__ == "__main__":
    main()
