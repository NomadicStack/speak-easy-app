# Voice Data Collection & ML Processing Guide

This document details the end-to-end architecture, step-by-step instructions for using the app to collect voice data, data packaging specifications, and the machine learning ingestion pipeline for SpeakEasy.

---

## 1. Overview & Design Philosophy

Personalizing Automatic Speech Recognition (ASR) for individuals with dysarthria requires fine-tuning on speech samples paired with accurate reference text. Because dysarthric speech features varied phoneme distortions, atypical prosody, and breath pauses, off-the-shelf models struggle without personalized training data.

### Privacy-First Architecture
Unlike cloud-first approaches that upload raw patient audio to remote databases, SpeakEasy implements a **100% on-device, privacy-preserving pipeline**:
- **Zero Cloud Databases**: Voice recordings are never sent to third-party databases (like Firestore or AWS S3).
- **Persistent Local Sandbox Storage**: Audio recordings stay in the app's local sandbox under persistent per-deck directories (`Documents/VoiceStudio/Decks/<deckId>/audio/` and `samples.json`).
- **Safe & Non-Destructive**: Exiting a session or returning to the decks list never wipes audio files. Partially completed sessions can be paused and resumed at any time.
- **User-Controlled Export**: Data leaves the device only when the user or caregiver explicitly reviews and sends it via **Email** or **AirDrop / Share Sheet**.
- **Caregiver Collaboration**: Supports an optional Caregiver CC email so family members or speech therapists stay informed.

---

## 2. How to Use the App to Collect Voice Data (Step-by-Step Guide)

SpeakEasy provides two complementary pathways to collect voice data:
1. **Mode 1: Guided Voice Studio (Structured Training Decks)**
2. **Mode 2: Everyday Live Corrections (Spontaneous Conversation)**

```
                                  DATA COLLECTION PATHWAYS
                                             │
           ┌─────────────────────────────────┴─────────────────────────────────┐
           ▼                                                                   ▼
┌─────────────────────────────────┐                       ┌─────────────────────────────────────┐
│  Mode 1: Guided Voice Studio    │                       │  Mode 2: Everyday Live Corrections  │
├─────────────────────────────────┤                       ├─────────────────────────────────────┤
│ • Structured prompt decks       │                       │ • Spontaneous daily conversation    │
│ • Example or custom phrase sets │                       │ • Tap "Incorrect?" on Transcribe    │
│ • Waveform meter & TTS preview  │                       │ • Correct text saved with raw audio │
│ • Non-destructive auto-save     │                       │ • Sent as batch from Voice Studio   │
│ • Resume anytime / Review takes │                       │                                     │
└─────────────────────────────────┘                       └─────────────────────────────────────┘
```

---

### Step-by-Step: Mode 1 (Guided Voice Studio)

#### Step 1: Configure Recipient Emails (First-Time Setup)
1. In SpeakEasy, tap the **Settings** tab (gear icon).
2. Under **Feedback & Data Collection**:
   - **Recipient Email**: Enter the developer or ML engineer's email (e.g., `developer@example.com`).
   - **Caregiver CC Email**: (Optional) Enter a caregiver, family member, or clinician's email.
   - **Your Name**: Enter the speaker's name to identify the data session.

#### Step 2: Open Voice Studio
1. Tap the **Voice Studio** tab (waveform & microphone icon) in the navigation rail (iPad) or bottom navigation bar (iPhone).
2. The Voice Studio home screen shows:
   - **Pending Corrections Banner**: Appears if any live conversation corrections have been saved.
   - **Training Decks List**: Lists all starter and custom decks with phrase counts and current completion badges.

#### Step 3: Choose or Create a Training Deck
- **Option A: Use the Starter Deck**
  - **Daily Essentials (Example)**: A curated 10-phrase starter deck covering urgent requests (*"I need a glass of water please"*, *"It is time for my medicine"*).
- **Option B: Create a Custom Deck**
  1. Tap **"New Deck"** or **"Manage Decks"** in the top right.
  2. Enter a **Group Name** (e.g., *"Dining & Drinks"*, *"Emergency Requests"*, *"Work & Phone"*).
  3. Choose an icon that fits the topic (e.g., fork & knife, heart, telephone).
  4. Tap **"Create Group"**.
  5. Tap your new group to open **Group Details**.
  6. Enter phrases into the text box and tap **"Add"**. Add as many or as few phrases as desired (no minimum or mandatory 10-count requirement).
  7. Tap **"Done"** to return to the deck list.

#### Step 4: Record Phrases in the Studio
1. On the deck card, tap **"Start"** (or **"Resume"** if continuing a previous session).
2. SpeakEasy displays the full-screen Recording Studio:
   - **TTS Example ("Listen to Prompt")**: Tap the blue speaker button to hear the phrase pronounced aloud at a clear, comfortable cadence using `AVSpeechSynthesizer`.
   - **Phrase Navigation (`<` and `>`)**: Use the chevron buttons in the top header to freely browse between cards in the deck.
   - **Fatigue Checkpoint**: At the halfway mark of longer decks, an encouraging reminder appears suggesting the speaker pause, take a breath, or sip water.
3. **Record Your Audio**:
   - Tap the large **Microphone button** at the bottom (turns red and active).
   - Speak the phrase into the device microphone naturally.
   - The **Live Waveform Visualizer** confirms that speech amplitude is being captured.
   - Tap the **Stop button** (red square) when finished speaking.
4. **Review Your Recording**:
   - **Play Back**: Tap **"Play Back"** to listen to the recording through the device loudspeaker.
   - **Redo**: If you coughed, hesitated, or had background noise, tap **"Redo"** to discard only this card's audio and re-record.
   - **Next**: Tap **"Next"** (or **"Finish"** on the last phrase) to save the take into the deck and advance to the next phrase.

#### Step 5: Pausing and Resuming Anytime
- You do **not** have to complete the entire deck in one sitting.
- Tap **"Exit Session"** at any time.
- All recorded `.wav` files and progress are **automatically saved** in the deck's persistent directory.
- On the Voice Studio home screen:
  - Decks in progress show an orange badge (e.g., `3/7 recorded`) and a **"Resume"** button.
  - Tapping **"Resume"** automatically jumps directly to the first phrase you haven't recorded yet.
  - Completed decks show a green `✓ Done (X)` badge and a **"Review"** button.

#### Step 6: Review and Export Voice Data
1. When all phrases in the deck are recorded, the **Session Complete 🎉** screen appears.
2. **Review Individual Takes**:
   - Scroll through the list of recorded phrases.
   - Tap **"Play"** on any phrase row to listen back to that specific take.
3. **Exporting Your Data**:
   - **Send Voice Data via Email**: Opens an Apple Mail compose sheet with the pre-packaged `.zip` archive (containing 16kHz WAV files and `metadata.csv`) attached, pre-filled with the recipient, CC, and formatted session summary. Tap the blue send arrow.
   - **AirDrop or Save Archive**: If Apple Mail is not configured, tap **"AirDrop or Save Archive"** to open the iOS Share Sheet. AirDrop the archive directly to a nearby Mac or save it to the Files app / iCloud Drive.
4. **Group Locking**:
   - Sending training data for a custom group **automatically locks** that group.
   - Locking prevents accidental phrase modifications so the collected audio remains strictly aligned with the training dataset.
   - If phrases ever need editing later, the group can be unlocked in the group details screen.
5. **Return to Decks**:
   - Tap **"Return to Decks"** to exit. All recordings and metadata remain saved on the device.
   - If you ever want to completely wipe the recordings for a deck and re-record from scratch, tap **"Reset & Re-record Deck"** (with confirmation dialog).

---

### Step-by-Step: Mode 2 (Everyday Live Corrections)

Mode 2 allows collecting natural, spontaneous speech samples whenever SpeakEasy makes a transcription error during daily conversations.

1. **Transcribe Screen**: Speak as normal on the primary **Transcribe** screen.
2. **Flagging Misrecognitions**: If Whisper transcribes words incorrectly, tap the **"Incorrect?"** button below the transcription bubble.
3. **Saving the True Text**:
   - An inline editor appears showing the recognized text.
   - Type the correct intended phrase using the keyboard or predictive text.
   - Tap **"Save Correction"**.
4. **Automatic Queuing**:
   - The original 16kHz mono audio slice and the corrected reference text are securely saved into the pending corrections queue (`Documents/VoiceStudio/LiveCorrections/`).
5. **Batch Export**:
   - Go to the **Voice Studio** tab.
   - An orange banner displays **"Pending Conversation Corrections (X corrections ready to send)"**.
   - Tap **"Send Corrections Archive"** to export all pending corrections as a single ZIP archive (`VoiceData_Corrections_...zip`).
   - Tap the trash icon if you wish to clear pending corrections.

---

## 3. Audio Specifications & Packaging

### Technical Audio Specifications
All audio recorded by `TrainingSessionManager` and `AudioRecorder` strictly conforms to the exact tensor requirements of Whisper and WhisperKit:
- **Format**: Linear PCM (`.wav`)
- **Sampling Rate**: 16,000 Hz (16 kHz)
- **Channels**: 1 (Mono)
- **Bit Depth**: 16-bit integer PCM
- **Audio Session Category**: `AVAudioSession.Category.playAndRecord` with `.defaultToSpeaker` and `.allowBluetoothHFP` options.

### On-Device Sandbox Directory Structure
Recordings are persistently organized by deck ID inside the app sandbox:

```
Documents/VoiceStudio/
├── Decks/
│   ├── daily_essentials/
│   │   ├── samples.json               <-- Persisted array of RecordedSample objects
│   │   └── audio/
│   │       ├── sample_01_a1b2c3.wav
│   │       ├── sample_02_d4e5f6.wav
│   │       └── ...
│   └── custom_dining_drinks/
│       ├── samples.json
│       └── audio/
│           ├── sample_01_789abc.wav
│           └── ...
└── LiveCorrections/
    ├── corrections.json
    └── audio/
        ├── correction_01.wav
        └── ...
```

### Export Archive Structure
When generating an export archive for fine-tuning, `TrainingSessionManager` bundles the files into a standardized ZIP:

```
VoiceData_custom_dining_drinks_20260903_120000.zip
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
| `scenario_group` | Categorical deck tag for evaluation grouping | `custom_dining_drinks` |
| `recorded_at` | ISO 8601 timestamp of recording | `2026-09-03T21:30:00Z` |

---

## 4. Machine Learning Ingestion Pipeline

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
  --archive path/to/VoiceData_custom_dining_drinks_20260903_120000.zip \
  --data-root data/personal/ \
  --manifest-csv metadata_whisper_deploy_all.csv \
  --default-split train
```

### Key Behaviors of `import_voice_session_archive.py`:
1. **Collision Avoidance**: If `sample_01.wav` already exists from a previous session, the script renames it to `sample_01_1.wav` and updates the manifest path accordingly.
2. **Text Normalization**: Verifies and ensures the `norm_text` column is generated using `whisper_text_normalization.normalize_phrase()`.
3. **Master Manifest Merging**: Appends new rows to `data/personal/metadata_whisper_deploy_all.csv` while checking for existing filepaths to prevent duplication.

---

## 5. Fine-Tuning the Custom Model

Once new sessions have been imported into `data/personal/`, run the fine-tuning script:

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
Evaluate checkpoints to identify the model with the lowest Word Error Rate (WER) and Character Error Rate (CER):

```bash
python ml/whisper_finetuning/select_whisper_checkpoint_by_wer.py \
  --runs-dir checkpoints/experiments/whisper-small-personal-$(date +%Y%m%d) \
  --metadata-csv data/personal/metadata_splits.csv
```

---

## 6. Model Deployment & Loop Closure

After selecting the best checkpoint:
1. **Convert to CoreML**: Use `whisperkittools` to convert the PyTorch checkpoint to Apple CoreML `.mlmodelc` packages (AudioEncoder, TextDecoder, MelSpectrogram).
2. **Distribution**:
   - **Via Access Token**: Compress the model directory into a `.zip` archive, upload to Cloud Storage, and generate an access token in Firestore `paid_tokens` (see [token_access_control.md](file:///Users/dalaimingat/Desktop/mydev/DysarthriaApp/docs/token_access_control.md)).
   - **Direct Bundle Update**: Place the model folder directly inside `DysarthriaApp/Models/`.
3. **Activation**: The user enters their token in Settings -> "Import Custom Model", downloads their updated model, and SpeakEasy switches to the personalized Whisper model.

