# SpeakEasy (Dysarthria Transcription & Smart AAC App)

SpeakEasy is a specialized iPad application designed to bridge the communication gap for individuals with dysarthria. It provides high-accuracy speech-to-text transcription for slurred or labored speech and features an AI-powered "Smart Speak" expander that turns fragmented shorthand into polished, natural sentences.

## Key Features

- **Local AI Inference:** Both transcription and AI generation happen 100% on-device. No audio or text data ever leaves the device, ensuring total privacy.
- **Accurate Transcription:** Uses Apple's Neural Engine and a custom fine-tuned Whisper model via **WhisperKit** to transcribe dysarthric speech. Gated behind a token-based access control system for secure model provisioning.
- **Paid Token Access Control:** Dynamic backend-verified token checking that downloads the user's custom fine-tuned Whisper model over HTTPS and extracts it locally for offline ASR capability.
- **Smart Speak (AAC Expander):** Uses a local **Gemma 4 (2B)** LLM via Google's official **LiteRT-LM** (`LiteRTLM`) to expand shorthand phrases and quick-chip shortcuts into fully formed sentences.
- **Accessibility-First UI:** Features massive typography, responsive iPad layouts, and customizable Quick Chips.
- **Native Integration:** Spoken output via iPadOS Text-to-Speech (`AVSpeechSynthesizer`) and direct integration with the Messages app.

## Storage & Privacy

SpeakEasy bundles custom AI models directly within the app to guarantee offline operation and data privacy.

- **App Size:** ~500 MB (base) + 2.6 GB (Gemma 4 2B)
- **Model Sizes:** 
    - Transcription: ~468 MB (Custom Fine-tuned Whisper-Small)
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
  - Contains Views, ViewModels, Services (`AudioRecorder`, `TranscriptionViewModel`, `AACViewModel`, `GemmaService`, `TokenService`, `KeychainHelper`).
- `backend/`: Firebase Cloud Functions and Firestore rules configuration for token validation.
- `ml/whisper_finetuning/`: Python pipeline for training the custom Whisper ASR model.
  - Includes training loops, metadata normalization, and checkpoint evaluation by WER/CER.
- `docs/`: Technical documentation.
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
