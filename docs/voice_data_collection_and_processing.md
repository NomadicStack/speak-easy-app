# Voice Data Collection & ML Processing Guide

This document details the end-to-end architecture, user experience, data packaging, and machine learning pipeline for collecting and processing speech data in SpeakEasy.

---

## 1. Overview & Design Philosophy

Personalizing Automatic Speech Recognition (ASR) for individuals with dysarthria requires fine-tuning on speech samples paired with accurate reference text. Because dysarthric speech features varied phoneme distortions, atypical prosody, and breath pauses, off-the-shelf models struggle without personalized training data.

### Privacy-First Architecture
Unlike cloud-first approaches that upload raw patient audio to remote databases, SpeakEasy implements a **100% on-device, privacy-preserving pipeline**:
- **Zero Cloud Databases**: Voice recordings are never sent to third-party databases (like Firestore or AWS S3).
- **Local Sandbox Storage**: Audio recordings stay in the app's local sandbox (`Documents/VoiceStudio/`).
- **User-Controlled Export**: Data leaves the device only when the user or caregiver explicitly reviews and sends it via **Email** or **AirDrop / Share Sheet**.
- **Caregiver Collaboration**: Supports an optional Caregiver CC email so family members or speech therapists stay informed.

---

## 2. In-App Data Collection Workflows

SpeakEasy provides two complementary data collection pathways:

```
                                  DATA COLLECTION MODES
                                           │
         ┌─────────────────────────────────┴─────────────────────────────────┐
         ▼                                                                   ▼
┌─────────────────────────────────┐                       ┌─────────────────────────────────────┐
│  Mode 1: Guided Voice Studio    │                       │  Mode 2: In-Situ Live Corrections   │
├─────────────────────────────────┤                       ├─────────────────────────────────────┤
│ • 10-phrase structured decks    │                       │ • Spontaneous daily conversation    │
│ • "Listen to Prompt" (TTS)      │                       │ • User taps "Incorrect?" on tab 1   │
│ • Waveform meter & playback     │                       │ • Audio + correction saved to queue │
│ • Prevents vocal fatigue        │                       │ • Exported as batch from Studio     │
└─────────────────────────────────┘                       └─────────────────────────────────────┘
```

### Mode 1: Guided Voice Training Studio ("Voice Studio")
Located in the 3rd primary tab on the navigation rail (iPad landscape) and bottom bar (portrait/iPhone).

1. **Bite-Sized 10-Phrase Decks**:
   To prevent vocal and respiratory fatigue for individuals with motor speech impairments, prompts are organized into curated 10-phrase decks:
   - **Daily Essentials**: Urgent requests (e.g., *"I need a glass of water please"*, *"It is time for my medicine"*).
   - **Home & Assistance**: Environmental and device control (e.g., *"Please turn down the volume"*, *"Where is my phone?"*).
   - **Greetings & Social**: Polite phrases and everyday interactions (e.g., *"Good morning, how are you?"*, *"I agree with what you said"*).
   - **Health & Well-being**: Communicating pain and physical sensations (e.g., *"I am feeling pain right now"*, *"My back is hurting a lot"*).
   - **Custom Phrases**: Allows caregivers or speech-language pathologists (SLPs) to add custom sentences (e.g., family names, pets, local places).

2. **Accessibility Features**:
   - **Massive Hit Targets**: Primary action buttons are sized **85pt to 120pt** with high visual contrast.
   - **Oversized Typography**: Prompts are rendered at **30pt–44pt bold**.
   - **"Listen to Prompt" (TTS Preview)**: A speaker button reads the prompt aloud at a natural cadence using `AVSpeechSynthesizer` before the speaker attempts vocalization.
   - **Real-Time Waveform Visualizer**: A 12-bar dynamic level meter reflects audio amplitude during recording, confirming the microphone is capturing sound.
   - **Review Before Advancing**: Users can play back their recording, tap "Redo", or advance with "Next Phrase ➔".

### Mode 2: In-Situ Live Correction Donation
1. During everyday use on the **Transcribe** screen, if Whisper misrecognizes a phrase, the user taps **"Incorrect?"**.
2. The user corrects the text in the inline editor and taps **"Save Correction"**.
3. In addition to updating local usage statistics, the `.wav` recording and corrected text are automatically queued into `TrainingSessionManager.shared.addLiveCorrection`.
4. Pending corrections can be reviewed and exported as a unified batch from the Voice Studio screen.

---

## 3. Audio Specifications & On-Device Packaging

### Audio Capture Specifications
All audio recorded by `TrainingSessionManager` and `AudioRecorder` strictly conforms to the exact tensor requirements of Whisper and WhisperKit:
- **Format**: Linear PCM (`.wav`)
- **Sampling Rate**: 16,000 Hz (16 kHz)
- **Channels**: 1 (Mono)
- **Bit Depth**: 16-bit integer PCM
- **Floating Point**: `false`

### Automated ZIP Archive Generation
Upon completing a 10-phrase session or triggering a corrections export, `TrainingSessionManager` automatically structures and compresses the files:

```
VoiceData_daily_essentials_20260903_120000.zip
├── metadata.csv
└── audio/
    ├── sample_01.wav
    ├── sample_02.wav
    ├── sample_03.wav
    └── ...
```

### Pre-Formatted `metadata.csv` Schema
The generated CSV strictly adheres to the schema expected by `ml/whisper_finetuning/train_personal_whisper.py`:

```csv
filepath,text,norm_text,splits,scenario_group,recorded_at
audio/sample_01.wav,"I need a glass of water please.","i need a glass of water please",train,daily_essentials,2026-09-03T21:30:00Z
audio/sample_02.wav,"Please help me sit up.","please help me sit up",train,daily_essentials,2026-09-03T21:31:12Z
```

| Column | Description | Example |
| :--- | :--- | :--- |
| `filepath` | Relative path to audio file inside archive | `audio/sample_01.wav` |
| `text` | Display reference text with original casing and punctuation | `"I need a glass of water please."` |
| `norm_text` | Normalized text (lowercase, stripped punctuation) | `"i need a glass of water please"` |
| `splits` | Dataset partition (`train`, `test`, `holdout`) | `train` |
| `scenario_group` | Categorical deck tag for evaluation grouping | `daily_essentials` |
| `recorded_at` | ISO 8601 timestamp of recording | `2026-09-03T21:30:00Z` |

---

## 4. Export & Transmission Pathways

When the user finishes a session, two export options are presented:

1. **Send via Email (`MailView.swift`)**:
   - Opens a native `MFMailComposeViewController` sheet.
   - **Recipient**: Pre-filled from `@AppStorage("feedback_recipient")` (configured in Settings).
   - **CC**: Pre-filled from `@AppStorage("caregiver_cc_email")` (optional caregiver email).
   - **Subject**: `SpeakEasy Voice Training Data - <UserName> (<DeckName>)`.
   - **Attachment**: The single `.zip` file (tagged with `application/zip` MIME type).
   - **Disk Management**: Upon verified email send (`.sent`), local temporary audio files for the session are automatically cleared to save iPad storage.

2. **AirDrop or Save Archive (Share Sheet Fallback)**:
   - If the iPad has no Apple Mail account configured, tapping **"AirDrop or Save Archive"** presents the native iOS `UIActivityViewController`.
   - Caregivers can AirDrop the `.zip` archive directly to a nearby Mac or save it to iCloud Drive / Files app.

---

## 5. Machine Learning Ingestion Pipeline

When the developer or model trainer receives a `VoiceData_*.zip` file, they ingest it into the training environment with a single automated CLI script:

```
   [Emailed VoiceData.zip]
              │
              ▼
   python ml/whisper_finetuning/import_voice_session_archive.py
              │
              ├── Extracts audio into: data/personal/audio/*.wav
              ├── Resolves filename collisions automatically
              ├── Applies text normalization (whisper_text_normalization.py)
              └── Merges records into: data/personal/metadata_whisper_deploy_all.csv
              │
              ▼
   [Ready for train_personal_whisper.py]
```

### Ingestion Command

```bash
python ml/whisper_finetuning/import_voice_session_archive.py \
  --archive path/to/VoiceData_daily_essentials_20260903_120000.zip \
  --data-root data/personal/ \
  --manifest-csv metadata_whisper_deploy_all.csv \
  --default-split train
```

### Key Behaviors of `import_voice_session_archive.py`:
1. **Collision Avoidance**: If `sample_01.wav` already exists from a previous session, the script renames it to `sample_01_1.wav` and updates the manifest path accordingly.
2. **Text Normalization**: Verifies and ensures the `norm_text` column is generated using `whisper_text_normalization.normalize_phrase()`.
3. **Master Manifest Merging**: Appends new rows to `data/personal/metadata_whisper_deploy_all.csv` while checking for existing filepaths to prevent duplication.

---

## 6. Fine-Tuning the Custom Model

Once new sessions have been imported, run the fine-tuning script:

```bash
python ml/whisper_finetuning/train_personal_whisper.py \
  --base-model openai/whisper-small.en \
  --mode full \
  --run-name whisper-small-personal-$(date +%Y%m%d) \
  --metadata-csv data/personal/metadata_whisper_deploy_all.csv \
  --train-on-all \
  --max-steps 2500 \
  --learning-rate 1e-05 \
  --gradient-accumulation-steps 1 \
  --eval-steps 100 \
  --save-steps 100 \
  --save-total-limit 10 \
  --skip-baseline
```

### Checkpoint Selection & Evaluation
Evaluate checkpoints to find the model with the lowest Word Error Rate (WER) and Character Error Rate (CER):

```bash
python ml/whisper_finetuning/select_whisper_checkpoint_by_wer.py \
  --runs-dir checkpoints/experiments/whisper-small-personal-$(date +%Y%m%d) \
  --metadata-csv data/personal/metadata_splits.csv
```

---

## 7. Model Deployment & Loop Closure

After selecting the best checkpoint:
1. **Convert to CoreML**: Use `whisperkittools` to convert the PyTorch checkpoint to Apple CoreML `.mlmodelc` packages (AudioEncoder, TextDecoder, MelSpectrogram).
2. **Distribution**:
   - **Via Access Token**: Compress the model directory into a `.zip` archive, upload to Cloud Storage, and generate an access token in Firestore `paid_tokens` (see [token_access_control.md](file:///c:/Users/Dalai/dev/dysarthria-app/docs/token_access_control.md)).
   - **Direct Bundle Update**: Place the model folder directly inside `DysarthriaApp/Models/`.
3. **Activation**: The user enters their token in Settings -> "Import Custom Model", downloads their updated model, and SpeakEasy switches to the personalized Whisper model.
