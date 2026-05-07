# iOS App Implementation Plan: Dysarthria Transcription

This document outlines the step-by-step implementation plan for the iOS on-device transcription app, built using **WhisperKit**. 

Due to the fine-tuned dysarthria model being currently in development, this implementation follows a **two-phase rollout**. Phase 1 uses a temporary pre-converted base model, allowing full development of the audio engine and UI. Phase 2 involves swapping the model for the custom fine-tuned weights once they are ready.

---

## Phase 1: Temporary Setup (Base Whisper Model)

To unblock iOS development, we will use the `openai_whisper-small.en` model provided by Argmax via Hugging Face.

### 1. Project & Dependency Setup
*   **IDE:** Xcode 15.0+ (macOS 14.0+ target recommended).
*   **Dependency:** Add the Argmax OSS Swift package via Swift Package Manager (SPM).
    *   URL: `https://github.com/argmaxinc/argmax-oss-swift`
    *   Products: Select `WhisperKit` (or `ArgmaxOSS`).

### 2. UI & Audio Engine Implementation
*   **UI:** Create a simple interface with a manual "Start/Stop Recording" button. Manual gating is critical; do not rely on standard Voice Activity Detection (VAD) since dysarthric speech may contain pauses or labored breathing that trigger false cut-offs.
*   **Audio Engine (`AVFoundation`):**
    *   Configure the audio session for recording.
    *   Record mono, 16kHz PCM audio (`.wav` format).
    *   Save the temporary audio file to the device's local cache or temp directory upon stopping.

### 3. Temporary Inference Integration
*   **Initialization:** Initialize WhisperKit with the standard small English model. WhisperKit will automatically download the Core ML package on the first run.
    ```swift
    import WhisperKit
    
    // Auto-fetches from Hugging Face: argmaxinc/whisperkit-coreml
    let config = WhisperKitConfig(
        model: "openai_whisper-small.en",
        computeUnits: .all // Maximizes Neural Engine usage
    )
    let whisperKit = try await WhisperKit(config)
    ```
*   **Decoding Configuration:**
    ```swift
    var options = DecodingOptions()
    options.temperature = 0.0
    options.temperatureIncrementOnFallback = 0.2
    options.initialPrompt = self.initialPrompt // Dynamic context from UI
    ```
*   **Execution:** Pass the recorded audio URL to `whisperKit.transcribe(audioPath: decodedOptions:)` when the user stops recording.

---

## Phase 2: Permanent Migration (Fine-Tuned Model)

Once the fine-tuned model for dysarthric speech is fully trained, we will migrate the iOS app to use it.

### 1. Model Conversion
The PyTorch/Hugging Face fine-tuned weights must be converted to Apple's Core ML format using the `whisperkittools` CLI.

**Actionable Steps (macOS Environment):**
```bash
# 1. Setup a Python environment
python -m venv venv && source venv/bin/activate

# 2. Install conversion tools
pip install whisperkittools

# 3. Convert the model (replace path with your fine-tuned model)
whisperkit-generate-model \
    --model-version /path/to/your/finetuned-model \
    --output-dir ./Models/CustomDysarthriaModel
```

### 2. App Integration Update
*   **Bundle the Model:** Drag the resulting `./Models/CustomDysarthriaModel` folder (which contains the `.mlmodelc` files) into Xcode. Ensure it is selected in the **"Copy Bundle Resources"** build phase.
*   **Code Update:** Modify the initialization code to load the local bundled model instead of fetching from the network.
    ```swift
    // Load custom model directly from the app bundle
    let modelURL = Bundle.main.url(forResource: "CustomDysarthriaModel", withExtension: nil)!
    let config = WhisperKitConfig(
        model: "CustomDysarthriaModel", 
        modelFolder: modelURL,
        computeUnits: .all // Maximizes ANE utilization
    )
    let whisperKit = try await WhisperKit(config)
    ```

---

## Phase 3: Verification & Testing Strategy

To ensure high accuracy and stability, perform the following verification checks during both phases.

### A. Functional Verification
1.  **Audio Fidelity:** Verify that the `AVFoundation` engine generates strictly 16kHz, mono `.wav` files. WhisperKit relies on this specific tensor shape.
2.  **Hardware Utilization:** Run the app via Xcode connected to a physical device. Open the **Debug Navigator** -> **Energy Impact / CPU**. Ensure the Apple Neural Engine (ANE) is taking the primary load during inference, rather than maxing out the CPU.
3.  **No Cut-offs:** Test the manual recording button with extremely slow speech (simulating dysarthria). Ensure no audio is truncated.

### B. Migration Verification
1.  **Drop-in Replacement Test:** Ensure that migrating from Phase 1 to Phase 2 strictly involves updating the `WhisperKitConfig`. The transcription API call and audio engine should remain exactly the same.

### C. Performance & Accuracy Metrics
1.  **Latency Benchmark:** Measure the inference time. The delay between pressing "Stop" and the text appearing on-screen should ideally be under 2 seconds for a 10-second recording.
2.  **WER (Word Error Rate) Comparison:**
    *   During Phase 1, establish a baseline WER by having dysarthric test users (or playing the UASpeech dataset) speak into the device using the `openai_whisper-small.en` model.
    *   During Phase 2, repeat the test. The custom model must demonstrate a quantitatively lower WER on the device to be considered successful.
