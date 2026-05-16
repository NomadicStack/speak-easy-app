"""Create a normalized Whisper metadata manifest."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from whisper_text_normalization import normalize_phrase


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-csv", required=True)
    parser.add_argument("--output-csv", required=True)
    return parser.parse_args()


def main() -> None:
    """Normalize text columns in a Whisper manifest."""
    args = parse_args()
    project_root = Path(__file__).resolve().parents[1]
    input_csv = (project_root / args.input_csv).resolve()
    output_csv = (project_root / args.output_csv).resolve()
    output_csv.parent.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(input_csv)
    if "text" not in df.columns:
        raise ValueError("Input manifest must contain a text column")

    if "display_text" not in df.columns:
        df["display_text"] = df["text"]
    df["match_text"] = df["text"].map(normalize_phrase)
    df["text"] = df["match_text"]
    df["norm_text"] = df["match_text"]
    df.to_csv(output_csv, index=False)

    print(f"Wrote {len(df)} rows to {output_csv}")
    print(f"Changed text rows: {(df['display_text'] != df['text']).sum()}")


if __name__ == "__main__":
    main()
