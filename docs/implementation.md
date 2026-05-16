# iOS Application Implementation Documentation

This document details the software architecture, design patterns, and specific implementation details of the Dysarthria Transcription iOS app built using Swift and WhisperKit.

## Architecture Overview
The application follows the **MVVM (Model-View-ViewModel)** architectural pattern, separating the UI from the heavy machine learning and audio processing logic.

*   **View:** `ContentView.swift` handles the SwiftUI interface and responsive scaling (iPad vs. iPhone).
*   **ViewModel:** `TranscriptionViewModel.swift` manages the state of the CoreML model loading and inference. `AudioRecorder.swift` acts as a specialized ViewModel for audio session management.
*   **Model:** Provided dynamically via the `WhisperKit` library and the device's local filesystem.

---

## Components Breakdown

### 1. `DysarthriaApp.swift` (Entry Point)
*   **Purpose:** The main entry point of the SwiftUI application.
*   **Implementation:** Initializes the app lifecycle and mounts the `ContentView` within a standard `WindowGroup`.

### 2. `ContentView.swift` (UI Layer)
*   **Purpose:** The primary user interface for recording speech and viewing transcriptions.
*   **Utility Features:**
    *   **Clear:** Resets the transcription state via `transcriptionVM.clearTranscription()`.
    *   **Copy:** Copies the current transcription to the system clipboard using `UIPasteboard`.
    *   **Share:** Integrates the native `ShareLink` to export text to other apps.
*   **Context Input:** Includes a `TextField` bound to `transcriptionVM.initialPrompt`, allowing users to provide real-time hints to the model.
*   **iPad Responsive Design:** 
    *   Uses `@Environment(\.horizontalSizeClass)` and `.verticalSizeClass) to detect iPad usage (`.regular` size classes).
    *   **Dynamic Scaling:** Automatically scales up typography (e.g., `.system(size: 50)` for headers) and expands touch targets (the record button scales from 80pt to 120pt) for accessibility.
    *   **Layout Constraints:** Constrains the transcription text box to a `maxWidth` of 900pt to prevent awkward, unreadable stretching on large 12.9" iPad Pro screens.
*   **State Awareness:** Binds to `audioRecorder.isRecording` and `transcriptionVM.isModelLoaded` to disable buttons and update UI states (like showing the loading spinner) in real-time.

### 3. `AudioRecorder.swift` (Audio Engine)
*   **Purpose:** Handles low-level interaction with the device microphone via Apple's `AVFoundation`.
*   **Strict Formatting:** WhisperKit models require specifically formatted audio tensors. This class configures the `AVAudioRecorder` to enforce:
    *   **Format:** Linear PCM (`.wav`)
    *   **Sample Rate:** 16,000 Hz (16 kHz)
    *   **Channels:** 1 (Mono)
*   **Manual Gating:** We strictly rely on a manual Start/Stop interaction. Automatic Voice Activity Detection (VAD) is intentionally avoided, as dysarthric speech often contains long pauses or labored breathing that would trigger false cut-offs in standard VAD algorithms.
*   **Storage:** Safely writes the `.wav` file to `FileManager.default.temporaryDirectory` and returns the file URL to the UI.

### 4. `TranscriptionViewModel.swift` (Inference Manager)
*   **Purpose:** Bridges the UI and the underlying `WhisperKit` inference engine, executing CoreML logic.
*   **Hardware Optimization:** 
    *   Uses `computeUnits: .all` in `WhisperKitConfig`. This ensures the model runs on the **Apple Neural Engine (ANE)** where available, while falling back to GPU or CPU, resulting in significantly lower latency and better battery efficiency.
*   **Phase 1 Initialization:** 
    *   Initializes `WhisperKitConfig` targeting `openai_whisper-small.en`.
    *   Runs on a background `Task` (`await initializeWhisperKit()`) to prevent blocking the main thread while the ~150MB CoreML model is downloaded from Hugging Face and loaded into the Apple Neural Engine (ANE).
*   **Transcription Logic & Decoding Options:** 
    *   Exposes `transcribeAudio(at:)` which receives the temporary `.wav` file.
    *   Applies dysarthria-specific decoding adjustments:
        *   `temperature = 0.0`: Uses greedy decoding for high stability.
        *   `temperatureIncrementOnFallback = 0.2`: Allows the model to retry with sampling if the initial result is poor, which helps with slurred or indistinct consonants.
        *   `initialPrompt`: Dynamically passed from the UI. This allows for "contextual priming" (e.g., providing key words the speaker is likely to say), which is a powerful tool for improving accuracy in slurred speech.

---

## Completed: Phase 2 Migration (Custom Dysarthria Model)
The custom fine-tuned weights for the Dysarthria model have been successfully integrated into the application.

1.  **Model Conversion:**
    *   Used `whisperkittools` in a stable Python 3.12 environment to convert the fine-tuned PyTorch weights to CoreML (`.mlmodelc`).
    *   **Accuracy Fix:** Enabled `use_cache: true` in `config.json` to resolve initial correctness issues during the conversion of the Text Decoder.
2.  **Bundle Integration:**
    *   The converted model components (`AudioEncoder`, `TextDecoder`, `MelSpectrogram`) and metadata (`config.json`, `tokenizer.json`) are bundled in the `Models/CustomDysarthriaModel` directory.
3.  **Code Implementation:**
    ```swift
    // TranscriptionViewModel.swift
    func initializeWhisperKit() async {
        // ...
        let modelURL = Bundle.main.url(forResource: "CustomDysarthriaModel", withExtension: nil)!
        let config = WhisperKitConfig(
            model: "CustomDysarthriaModel", 
            modelFolder: modelURL.deletingLastPathComponent().path,
            tokenizerFolder: modelURL,
            computeOptions: ModelComputeOptions(
                melCompute: .cpuAndNeuralEngine,
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            ),
            download: false // Ensures local model is used
        )
        self.whisperKit = try await WhisperKit(config)
        // ...
    }
    ```

---

## Recent Enhancements (May 2026)

### 1. Developer Environment Fixes
*   **Xcode MCP Connection:** Resolved "disconnected" status by correctly setting the active developer directory to the Xcode application bundle (`xcode-select -s /Applications/Xcode.app/Contents/Developer`). This enabled the `mcpbridge` utility required for IDE integration.

### 2. Audio Stability & Simulator Support
*   **Simulator Optimization:** Modified `AudioRecorder.swift` to use 16-bit integer PCM instead of floating-point and reduced `AVEncoderAudioQuality` to `.medium`. This resolved `HALC_ProxyIOContext` overload errors and "skipping cycle" logs caused by virtual audio driver constraints in the iOS Simulator.
*   **Thread Safety:** Optimized the recording start sequence to prevent Main Thread contention during heavy WhisperKit model loading.

### 3. UI/UX Redesign (SpeakEasy)
*   **Branding:** Rebranded the app from "Dysarthria Transcription" to **"SpeakEasy"** for a friendlier, less clinical user experience.
*   **Visual Hierarchy:** Applied a distinct **Blue** color to the header to differentiate it from the primary transcription results.
*   **Accessibility (Massive Text):** Increased transcription font sizes significantly to improve readability for users with motor or visual impairments:
    *   **iPhone:** 34pt Bold.
    *   **iPad:** 54pt Bold.
*   **Simplified Interface:** 
    *   Refactored the "Initial Prompt" field into an expandable **"Advanced Context (Optional)"** disclosure group. This reduces cognitive load for new users while maintaining power-user features.
    *   Upgraded the "Model Ready" status message to a professional, pill-shaped badge with a checkmark icon and high-contrast styling.

### 4. Feedback & Fine-tuning Loop (Phase 1.5)
*   **Correction Logic:** Implemented an \"Incorrect?\" feature that allows users to manually fix transcriptions.
*   **Data Collection:**
    *   **Audio Storage:** Permanent copies of audio files associated with corrections are saved to the `Documents/FeedbackAudio` directory.
    *   **Log Persistence:** Metadata (timestamp, original text, corrected text, audio filename) is stored as a JSON log in `UserDefaults`.
*   **Accuracy Statistics:** Added real-time tracking of \"Total Transcriptions\" vs. \"Total Corrections\" to provide an empirical measure of model performance.
*   **Reporting & Configuration:** 
    *   **Direct Mail:** Uses a SwiftUI-wrapped `MFMailComposeViewController` (`MailView.swift`) to open a pre-filled email draft.
    *   **Customizable Recipient:** The feedback destination is now configurable via a \"Feedback Configuration\" section in the UI (persisted via `@AppStorage`).
    *   **User Identity:** Includes the user's optional email address in the report body for developer follow-up and sets it as the `preferredSendingEmailAddress` in the mail composer.
*   **Storage Management & Cleanup:**
    *   **Automated Cleanup:** Implemented `clearFeedbackData()` which is triggered automatically after a successful email send (`.sent` result).
    *   **Resource Reclamation:** This method deletes all archived `.wav` files and clears the correction logs, preventing duplicate reports and ensuring the app doesn't consume excessive disk space over time.


### 5. Transcription Pipeline Stability (May 2026)
*   **File Collision Avoidance:** Refactored `AudioRecorder` to generate unique filenames using UUIDs.
*   **WhisperKit Compatibility:** Disabled the `promptTokens` property in `DecodingOptions` for higher reliability.
*   **Graceful Silence Handling:** Configured `suppressBlank = false` in `DecodingOptions`.
*   **Storage Resource Management:** Implemented a "one-in, one-out" cleanup strategy in `TranscriptionViewModel`.
*   **iPad Audio Routing:** Enhanced `AVAudioSession` configuration with `.defaultToSpeaker`.

### 6. Transcription Concatenation & Formatting Fixes (May 2026)
*   **Manual Segment Joining:** Resolved an issue where WhisperKit's default `text` property concatenated segments without spaces. The pipeline now manually iterates through `TranscriptionResult.segments`, trims whitespace, and joins them with a single space.
*   **Special Token Cleaning:** Implemented a regular expression (`<\\|.*?\\|>`) to strip Whisper special tokens (e.g., `<|startoftranscript|>`, `<|0.00|>`) from the raw segment text, ensuring only the intended speech is displayed.
*   **Session-Based Newlines:** To improve readability, the app now separates different recording sessions (start/stop) with a newline (`\n`), while keeping speech within a single recording on one line.
*   **Persistent Visibility:** Removed the "Transcribing..." placeholder that previously overwrote existing text, allowing users to view previous transcriptions while new audio is being processed.

### 7. UI/UX Redesign for High-Frequency Actions (May 2026)
*   **Dual-Button Control Bar:** Relocated the **Clear** action from the toolbar to a prominent, large circular button at the bottom of the screen, mirroring the **Record** button.
*   **Enhanced Accessibility:**
    *   **Record Button:** Increased to 100pt (iPhone) / 140pt (iPad).
    *   **Clear Button:** Sized at 70pt (iPhone) / 100pt (iPad) for easy thumb access during rapid usage cycles.
*   **Visual Feedback:** The button bar utilizes dynamic opacity to indicate state (e.g., dimming the Clear button when the text is empty or transcription is in progress).

### 8. iPad Landscape & Accessibility Scaling (May 2026)
*   **Adaptive Sidebar:** Implemented a navigation rail for iPad in landscape mode, maximizing screen utility.
*   **Two-Column AAC View:** Redesigned the "Smart Speak" interface for iPad landscape, separating inputs and results into two distinct vertical columns.
*   **Wrapping Quick Chips:** Upgraded the "Quick Chips" from a scrollable list to a wrapping grid layout (`LazyVGrid`) in landscape mode to improve 1-tap accessibility.
*   **Universal UI Scaling:** Dramatically increased font sizes (up to 72pt) and button sizes (up to 180pt) across all views to meet the needs of users with motor or visual impairments.
*   **Orientation-Aware UI:** Leveraged `GeometryReader` alongside size classes to provide a seamless transition between portrait and landscape layouts.

### 9. Dynamic Quick Chips & Input Refinement (May 2026)
*   **QuickChipManager:** Implemented a new persistence layer for AAC shortcuts using `UserDefaults` and `JSONEncoder`.
*   **Dynamic Settings UI:** Added a dedicated management section in the Settings view for adding, editing, and deleting Quick Chips.
*   **Scrollable Chip Grid:** Wrapped the landscape chip grid in a `ScrollView` to prevent layout overflow when many chips are added.
*   **Shorthand Area Refinement:** Increased the height of the AAC shorthand box and optimized font sizes to balance visibility with content density.

### 10. UI Polish & Component Optimization (May 2026)
*   **Collapsible iPad Sidebar**: Refactored the iPad landscape navigation rail to be icon-only by default (100pt width), expanding to 220pt with full labels via a dedicated menu toggle. Uses `.spring()` animations for smooth state transitions.
*   **Quick Chip "Communication Board"**: Replaced capsule-style chips with a large, rectangular tile grid. Features prominent emojis and bold text, providing a "soundboard" experience with large, accessible hit targets.
*   **Explicit Deletion**: Replaced the "swipe-to-delete" gesture for Quick Chips with a visible **Red Trash Icon** next to each entry in the Settings view to improve discoverability.
*   **Information Density Refinement**:
    *   **Quick Chips**: Tiles use a `LazyVGrid` across all orientations, eliminating unintuitive horizontal scrolling.
    *   **Generated Options**: Redesigned sentence cards with compact, corner-aligned **Speak** and **Message** circular buttons, maximizing space for text.
    *   **Shorthand Input**: Implemented orientation-aware height constraints (140pt in landscape for wrapping, 50-80pt in portrait for compactness).
*   **Record Button Balancing**: Scaled down the primary record button (140pt on iPad, 90pt on iPhone) to reclaim vertical space while maintaining accessibility standards.
*   **Layout Stability**: Applied `maxHeight: .infinity` and strategic `Spacer` management to ensure UI components remain visible and properly positioned on initial load and empty states.
