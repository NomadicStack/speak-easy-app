# Implementation Report: Model Management & On-Device Downloader

This document details the implementation of the selectable and downloadable model system for the DysarthriaApp.

## 1. Features

- **Feature-Gated Onboarding:** AI model setup is exclusively triggered when accessing the "Smart Speak" tab, keeping the core transcription feature lightweight.
- **On-Device Download:** Models are downloaded directly to the device and stored locally.
- **Background Downloads:** Supports large file downloads using `URLSession` background configurations.
- **Model Management:** Users can manage their "AI Brain" via a purple brain icon located in the Smart Speak tab.

## 2. Architecture

### `ModelManager.swift`
The central hub for all model-related operations:
- **Registry:** Maintains a list of supported models with metadata (name, size, URL).
- **Download Engine:** Handles `URLSessionDownloadTask` with progress tracking.
- **Storage:** Manages the lifecycle of model files in the app's `Documents/Models` directory.
- **Persistence:** Stores the user's selected model ID in `UserDefaults`.

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
- **Format Compatibility:** Uses the native `.litertlm` format supported by the **LiteRTLM-Swift** engine.

## 4. Troubleshooting & Known Issues

### Memory Limits
- **Issue:** Large models like Gemma 4 E2B require significant RAM.
- **Fix:** Added the `increased-memory-limit` entitlement to the project.

### LiteRTLM-Swift Transition
- **Status:** Successfully migrated from MediaPipe `LlmInference` to the modern `LiteRTLM-Swift` framework, which natively supports `.litertlm` bundles.
...
1. **Add Library:** Add the `LiteRTLM-Swift` Swift Package.
2. **Real URLs:** Update the placeholder URLs in `ModelManager` with real direct-download links for `.litertlm` models.
3. **Inference Logic:** The `GemmaService` is fully integrated with `LiteRTLMEngine`.
