"""Automated tests for Voice Studio data collection, packaging, and Whisper ingestion."""

import csv
import io
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
import zipfile
from pathlib import Path

# Add ml/whisper_finetuning to path
REPO_ROOT = Path(__file__).resolve().parent.parent
ML_DIR = REPO_ROOT / "ml" / "whisper_finetuning"
sys.path.insert(0, str(ML_DIR))

from whisper_text_normalization import normalize_phrase

SPLITS = {"train", "val", "test", "holdout"}


def load_records_whisper(metadata_csv: Path, data_root: Path) -> list[dict[str, str]]:
    """Exact parser from train_personal_whisper.py to verify dataset compatibility."""
    records = []
    with metadata_csv.open(newline="", encoding="utf-8") as f:
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
                        "recorded_at": row.get("recorded_at", ""),
                        "original_transcription": row.get("original_transcription", ""),
                    }
                )
    return records


def create_dummy_wav(path: Path, duration_seconds: float = 0.5, sample_rate: int = 16000) -> None:
    """Create a valid 16kHz 16-bit mono PCM WAV file."""
    num_samples = int(sample_rate * duration_seconds)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)  # Mono
        wf.setsampwidth(2)  # 16-bit (2 bytes)
        wf.setframerate(sample_rate)  # 16,000 Hz
        # Silent or low amplitude PCM
        data = struct.pack(f"<{num_samples}h", *([0] * num_samples))
        wf.writeframes(data)


class TestVoiceDataCollectionAndIngestion(unittest.TestCase):
    """Test suite covering the complete Voice Studio data pipeline."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.work_dir = Path(self.temp_dir.name)
        self.data_root = self.work_dir / "data_personal"
        self.data_root.mkdir(parents=True, exist_ok=True)
        self.manifest_name = "test_manifest.csv"

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_text_normalization(self):
        """Verify normalization preserves word content and handles dysarthria training cases."""
        self.assertEqual(
            normalize_phrase("Could you please turn on the light?"),
            "could you please turn on the light",
        )
        self.assertEqual(
            normalize_phrase("It's time for my medicine."),
            "it's time for my medicine",
        )
        self.assertEqual(
            normalize_phrase("“Water, please!”"),
            "water please",
        )

    def test_voice_studio_session_archive_ingestion(self):
        """Verify end-to-end import of a Voice Studio session archive."""
        # 1. Create a simulated VoiceData ZIP archive matching Swift output
        zip_path = self.work_dir / "VoiceData_daily_essentials_20260903_220000.zip"
        
        session_folder = self.work_dir / "session_export"
        audio_folder = session_folder / "audio"
        audio_folder.mkdir(parents=True)

        create_dummy_wav(audio_folder / "sample_01.wav")
        create_dummy_wav(audio_folder / "sample_02.wav")

        metadata_csv = session_folder / "metadata.csv"
        with metadata_csv.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["filepath", "text", "norm_text", "splits", "scenario_group", "recorded_at"])
            writer.writerow([
                "audio/sample_01.wav",
                "I need a glass of water please.",
                "i need a glass of water please",
                "train",
                "daily_essentials",
                "2026-09-03T22:00:10Z"
            ])
            writer.writerow([
                "audio/sample_02.wav",
                "Please turn on the light.",
                "please turn on the light",
                "train",
                "daily_essentials",
                "2026-09-03T22:00:30Z"
            ])

        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.write(metadata_csv, arcname="metadata.csv")
            zf.write(audio_folder / "sample_01.wav", arcname="audio/sample_01.wav")
            zf.write(audio_folder / "sample_02.wav", arcname="audio/sample_02.wav")

        # 2. Ingest via import_voice_session_archive CLI
        script_path = ML_DIR / "import_voice_session_archive.py"
        cmd = [
            sys.executable,
            str(script_path),
            "--archive", str(zip_path),
            "--data-root", str(self.data_root),
            "--manifest-csv", self.manifest_name,
            "--default-split", "train",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, f"Import script failed:\n{result.stderr}")
        self.assertIn("Successfully imported 2 samples", result.stdout)

        # 3. Verify files exist in destination
        imported_manifest = self.data_root / self.manifest_name
        self.assertTrue(imported_manifest.exists())
        self.assertTrue((self.data_root / "audio" / "sample_01.wav").exists())
        self.assertTrue((self.data_root / "audio" / "sample_02.wav").exists())

        # 4. Verify train_personal_whisper load_records compatibility
        records = load_records_whisper(imported_manifest, self.data_root)
        self.assertEqual(len(records), 2)
        self.assertEqual(records[0]["text"], "i need a glass of water please")
        self.assertEqual(records[0]["scenario_group"], "daily_essentials")
        self.assertEqual(records[0]["split"], "train")
        self.assertEqual(records[0]["recorded_at"], "2026-09-03T22:00:10Z")
        self.assertTrue(Path(records[0]["audio_path"]).exists())

    def test_live_corrections_archive_and_collision_handling(self):
        """Verify importing a second archive with duplicate audio filenames avoids overwriting."""
        # 1. Ingest first session
        zip1_path = self.work_dir / "session1.zip"
        with zipfile.ZipFile(zip1_path, "w") as zf:
            wav_tmp = self.work_dir / "sample_01.wav"
            create_dummy_wav(wav_tmp)
            zf.write(wav_tmp, arcname="audio/sample_01.wav")
            
            meta = io.StringIO()
            writer = csv.writer(meta)
            writer.writerow(["filepath", "text", "norm_text", "splits", "scenario_group", "recorded_at"])
            writer.writerow(["audio/sample_01.wav", "First phrase", "first phrase", "train", "greetings", "2026-09-03T20:00:00Z"])
            zf.writestr("metadata.csv", meta.getvalue())

        script_path = ML_DIR / "import_voice_session_archive.py"
        subprocess.run([
            sys.executable, str(script_path),
            "--archive", str(zip1_path),
            "--data-root", str(self.data_root),
            "--manifest-csv", self.manifest_name,
        ], check=True)

        # 2. Ingest second archive with same filename (sample_01.wav) as live correction
        zip2_path = self.work_dir / "corrections.zip"
        with zipfile.ZipFile(zip2_path, "w") as zf:
            wav_tmp2 = self.work_dir / "sample_01_diff.wav"
            create_dummy_wav(wav_tmp2)
            zf.write(wav_tmp2, arcname="audio/sample_01.wav")
            
            meta2 = io.StringIO()
            writer = csv.writer(meta2)
            writer.writerow(["filepath", "text", "norm_text", "splits", "scenario_group", "recorded_at", "original_transcription"])
            writer.writerow([
                "audio/sample_01.wav",
                "Second phrase corrected",
                "second phrase corrected",
                "train",
                "live_correction",
                "2026-09-03T21:00:00Z",
                "second phrase imperfect"
            ])
            zf.writestr("metadata.csv", meta2.getvalue())

        result2 = subprocess.run([
            sys.executable, str(script_path),
            "--archive", str(zip2_path),
            "--data-root", str(self.data_root),
            "--manifest-csv", self.manifest_name,
        ], capture_output=True, text=True)
        self.assertEqual(result2.returncode, 0)

        # Verify collision was handled by renaming the second file
        imported_manifest = self.data_root / self.manifest_name
        records = load_records_whisper(imported_manifest, self.data_root)
        self.assertEqual(len(records), 2)
        
        # Audio paths must be different
        self.assertNotEqual(records[0]["relpath"], records[1]["relpath"])
        self.assertEqual(records[0]["relpath"], "audio/sample_01.wav")
        self.assertEqual(records[1]["relpath"], "audio/sample_01_1.wav")
        self.assertTrue(Path(records[0]["audio_path"]).exists())
        self.assertTrue(Path(records[1]["audio_path"]).exists())
        self.assertEqual(records[1]["original_transcription"], "second phrase imperfect")

    def test_audio_format_specification(self):
        """Verify dummy audio matches iOS settings: 16000 Hz, 16-bit Mono Linear PCM."""
        test_wav = self.work_dir / "format_test.wav"
        create_dummy_wav(test_wav, duration_seconds=1.0, sample_rate=16000)

        with wave.open(str(test_wav), "rb") as wf:
            self.assertEqual(wf.getnchannels(), 1)  # Mono
            self.assertEqual(wf.getsampwidth(), 2)  # 16-bit
            self.assertEqual(wf.getframerate(), 16000)  # 16kHz
            self.assertEqual(wf.getnframes(), 16000)  # 1 second

    def test_custom_deck_arbitrary_phrase_count(self):
        """Verify that user-created custom group decks with arbitrary phrase counts (e.g. 3, 5, 12) work end-to-end."""
        # Simulate a custom deck with 3 phrases created by the user
        zip_path = self.work_dir / "VoiceData_custom_dining_drinks_20260903_230000.zip"
        phrases = [
            "I would like some water.",
            "Can I get a fork please?",
            "The soup is hot."
        ]
        
        with zipfile.ZipFile(zip_path, "w") as zf:
            meta = io.StringIO()
            writer = csv.writer(meta)
            writer.writerow(["filepath", "text", "norm_text", "splits", "scenario_group", "recorded_at"])
            for idx, text in enumerate(phrases, 1):
                wav_file = self.work_dir / f"sample_{idx:02d}.wav"
                create_dummy_wav(wav_file, duration_seconds=0.7)
                zf.write(wav_file, arcname=f"audio/sample_{idx:02d}.wav")
                writer.writerow([
                    f"audio/sample_{idx:02d}.wav",
                    text,
                    normalize_phrase(text),
                    "train",
                    "custom_dining_drinks",
                    f"2026-09-03T23:0{idx}:00Z"
                ])
            zf.writestr("metadata.csv", meta.getvalue())

        script_path = ML_DIR / "import_voice_session_archive.py"
        subprocess.run([
            sys.executable, str(script_path),
            "--archive", str(zip_path),
            "--data-root", str(self.data_root),
            "--manifest-csv", self.manifest_name,
        ], check=True)

        imported_manifest = self.data_root / self.manifest_name
        records = load_records_whisper(imported_manifest, self.data_root)
        self.assertEqual(len(records), 3)
        self.assertTrue(all(r["scenario_group"] == "custom_dining_drinks" for r in records))
        self.assertEqual(records[0]["text"], "i would like some water")
        self.assertEqual(records[1]["text"], "can i get a fork please")
        self.assertEqual(records[2]["text"], "the soup is hot")


if __name__ == "__main__":
    unittest.main()
