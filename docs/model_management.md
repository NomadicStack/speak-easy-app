# Implementation Report: Model Management & On-Device Downloader

This document details the implementation of the selectable and downloadable model system for the DysarthriaApp.

## 1. Features

- **Feature-Gated Onboarding:** AI model setup is exclusively triggered when accessing the "Smart Speak" tab, keeping the core transcription feature lightweight.
- **On-Device Download:** Models are downloaded directly to the device and stored locally.
- **Background Downloads:** Supports large file downloads using `URLSession` background configurations.
- **Token-Gated Speech Models:** Speech models are not pre-bundled in the application package (Option A). The "Transcribe" tab is locked until a caregiver registers a subscription token, initiating a secure download of the user's unique fine-tuned Whisper model.
- **Model Management:** Users can manage their "AI Brain" via a purple brain icon located in the Smart Speak tab.
- **Simulated AI Mode:** A developer toggle in the Model Selection UI that bypasses real LLM loading for testing on resource-constrained environments (e.g., Mac Simulator).
- **Caregiver Messaging:** Allows users to send AI-expanded sentences directly to a caregiver via SMS.
- **Smart Contact Routing:** Users can manage a list of contacts (e.g., Mom, Dad). If a contact's name is mentioned in the shorthand input, the app automatically routes the message to that specific person. If no name is found, it falls back to the primary caregiver.

## 2. Architecture

### `ContactManager.swift`
A central hub for managing the user's contact list, handling persistence via `UserDefaults`, and providing the logic for name-based routing.

### `MessageService.swift`
A specialized service that wraps `MFMessageComposeViewController` to handle system-level text messaging safely on iOS devices.

### `ModelManager.swift`
The central hub for all LLM (Gemma) model-related operations:
- **Registry:** Maintains a list of supported models with metadata (name, size, URL).
- **Download Engine:** Handles `URLSessionDownloadTask` with progress tracking.
- **Storage:** Manages the lifecycle of model files in the app's `Documents/Models` directory.
- **Persistence:** Stores the user's selected model ID in `UserDefaults`.

### `TokenService.swift`
The coordinator for user-specific custom Whisper ASR models:
- **Backend Verification:** Communicates with secure HTTP Cloud Functions to validate user access tokens.
- **Download Handler:** Downloads custom model zip folders from presigned Cloud Storage URLs.
- **Extraction Engine:** Integrates `ZIPFoundation` to unzip and configure WhisperKit files locally inside `Documents/WhisperModels/`.

### `KeychainHelper.swift`
Maintains validation states offline by securely writing, reading, and clearing authorization tokens within the iOS Keychain.

### `ModelSelectionView.swift`
A dedicated UI for managing models:
- **Download Action:** Initiates a download with a visual progress indicator.
- **Selection Action:** Switches the active model once the download is complete.
- **Contextual Actions:** Allows users to delete downloaded models to free up space.

### `OnboardingView.swift`
A feature-gate experience shown only in the Smart Speak tab. It ensures the app has an AI "brain" before allowing expansion features, while providing clear feedback that the download is optional for basic transcription users.

### `ContentView.swift`
Manages the top-level gating logic. It uses a `Group` within the `TabView` to switch between `OnboardingView` and `AACExpanderView` for the Smart Speak tab based on the user's completion status.

## 3. Integration with AI Services

### `GemmaService.swift`
The service has been updated to be dynamic:
- It checks `ModelManager.shared.selectedModel` to find the current model's local path.
- **Loading Diagnostics:** Added debug logging for file size and hex signatures to verify file integrity before initialization.
- **Format Compatibility:** Uses the native `.litertlm` format supported by the **Google LiteRT-LM** engine.

## 4. Troubleshooting & Known Issues

### Memory Limits
- **Issue:** Large models like Gemma 4 E2B require significant RAM.
- **Fix:** Added the `increased-memory-limit` entitlement to the project.

### Google LiteRT-LM Transition
- **Status:** Migrated to Google's official **LiteRT-LM** (`google-ai-edge/LiteRT-LM`) Swift framework (`LiteRTLM`), providing native support for `.litertlm` bundles with GPU (Metal) and CPU backends.
- **Steps:**
1. **Add Library:** Add the `google-ai-edge/LiteRT-LM` Swift Package (`LiteRTLM` target).
2. **Real URLs:** Update the URLs in `ModelManager` with direct-download links for `.litertlm` models.
3. **Inference Logic:** `GemmaService` is integrated with `EngineConfig`, `Engine`, and `Conversation`.

## 5. Testing & Simulation

### Simulated AI Mode
To facilitate testing on environments that cannot support a 2.6GB local LLM (like the iPad Simulator), a **Simulated AI Mode** is available:

- **Toggle:** Found in the **Model Selection (Brain Icon)** menu under "Testing & Debug".
- **Behavior:** Bypasses `Engine.initialize()` and `conversation.sendMessage()`.
- **Logic:** 
  - Simulates a 1.5-second processing delay.
  - Returns 3 mock expansion sentences using the input shorthand.
  - Allows full end-to-end testing of the UI, Voice-to-Text flow, and TTS (Text-to-Speech) without real AI hardware requirements.
