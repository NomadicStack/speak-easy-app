# SpeakEasy (Dysarthria Transcription & Smart AAC App)

SpeakEasy is a specialized iPad application designed to bridge the communication gap for individuals with dysarthria. It provides high-accuracy speech-to-text transcription for slurred or labored speech and features an AI-powered "Smart Speak" expander that turns fragmented shorthand into polished, natural sentences.

## Key Features

- **Local AI Inference:** Both transcription and AI generation happen 100% on-device. No audio or text data ever leaves the device, ensuring total privacy.
- **Accurate Transcription:** Uses Apple's Neural Engine via **WhisperKit** to transcribe dysarthric speech. By default, auto-downloads a free `openai_whisper-small` model from WhisperKit's public hub.
- **Custom Model Import:** Users with a fine-tuned speech model can enter an access token in Settings to download and swap in their personalized Whisper model.
- **Single-Model Storage Optimization:** SpeakEasy automatically maintains only one speech model on disk at a time (~460MB), purging cached base files when custom models are imported and restoring the base model when reverted.
- **Transparent Model Indicator:** Real-time badge on the Transcribe tab displays the active model (`✓ Base (Whisper Small)` or `✨ Custom (ModelName)`).
- **Smart Speak (AAC Expander):** Uses a local **Gemma 4 (2B)** LLM via Google's official **LiteRT-LM** (`LiteRTLM`) to expand shorthand phrases and quick-chip shortcuts into fully formed sentences.
- **Accessibility-First UI:** Features massive typography, responsive iPad layouts, and customizable Quick Chips.
- **Voice Studio (In-App Data Collection):** An accessible 10-phrase recording studio for gathering personalized speech data. Automatically packages 16kHz mono WAVs and pre-formatted metadata into a `.zip` archive for direct export via Email (with Caregiver CC) or AirDrop.
- **Native Integration:** Spoken output via iPadOS Text-to-Speech (`AVSpeechSynthesizer`) and direct integration with the Messages app.

## Storage & Privacy

SpeakEasy downloads AI models directly to the device to guarantee offline operation and data privacy.

- **App Size:** ~500 MB (base) + 2.6 GB (Gemma 4 2B)
- **Model Sizes:** 
    - Speech Transcription: ~460 MB (Only one active model stored on-device: Default Base `openai_whisper-small` or Custom Fine-tuned Model)
    - Smart Speak: ~2.6 GB (Gemma 4 2B INT4)
- **Privacy:** Your voice recordings and transcripts are never uploaded to the cloud.

## Tech Stack

- **Language:** Swift 5.10+ & Python 3 (for ML)
- **Framework:** SwiftUI
- **Transcription Engine:** [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML)
- **LLM Engine:** [Google LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) ([Documentation](https://developers.google.com/edge/litert-lm/swift))
- **Minimum OS:** iPadOS 17.0+
- **Recommended Hardware:** iPad with M-series chip.

## Project Structure

- `DysarthriaApp/`: Source code for the main iPad application.
  - Contains Views, ViewModels, Services (`AudioRecorder`, `TranscriptionViewModel`, `AACViewModel`, `TrainingSessionManager`, `PromptDeckProvider`, `GemmaService`, `TokenService`, `KeychainHelper`).
- `backend/`: Firebase Cloud Functions and Firestore rules configuration for token validation.
- `ml/whisper_finetuning/`: Python pipeline for training the custom Whisper ASR model.
  - Includes training loops, archive ingestion (`import_voice_session_archive.py`), metadata normalization, and checkpoint evaluation by WER/CER.
- `docs/`: Technical documentation.
  - `voice_data_collection_and_processing.md`: Complete guide on in-app voice data collection, ZIP packaging, and ML ingestion.
  - `architecture_overview.md`: Complete system architecture and component breakdown.
  - `token_access_control.md`: Detailed configuration and setup guide for access control.
  - `aac-expander-design.md`: Design philosophy for the Smart Speak feature.

## Getting Started

### Prerequisites
- macOS with Xcode 15.0 or later.
- A physical iPad is highly recommended for performance testing.

### Setup
1. Clone the repository.
2. Open `DysarthriaApp.xcodeproj` in Xcode.
3. Add the required dependencies via Swift Package Manager:
   - WhisperKit: `https://github.com/argmaxinc/argmax-oss-swift`
   - LiteRT-LM: `https://github.com/google-ai-edge/LiteRT-LM`
4. Configure Microphone permissions in `Info.plist` (`NSMicrophoneUsageDescription`).
5. Build and Run (**Cmd + R**).

## License

[Creative Commons Attribution 4.0 International License (CC BY 4.0)](LICENSE)
