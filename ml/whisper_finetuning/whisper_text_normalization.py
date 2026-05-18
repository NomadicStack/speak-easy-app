"""Shared text normalization helpers for Whisper manifests and evaluation."""

from __future__ import annotations

import re


QUOTE_TRANSLATION = str.maketrans(
    {
        "\u2018": "'",
        "\u2019": "'",
        "\u201b": "'",
        "\u2032": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u201e": '"',
        "\u2033": '"',
    }
)


def normalize_basic(text: str) -> str:
    """Lowercase and trim text for legacy metric comparison."""
    return str(text).lower().strip()


def normalize_phrase(text: str) -> str:
    """Normalize phrase text while preserving word content."""
    value = str(text).translate(QUOTE_TRANSLATION).lower()
    value = re.sub(r"[^a-z0-9\s']", " ", value)
    return re.sub(r"\s+", " ", value).strip()
