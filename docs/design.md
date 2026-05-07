## Design Document: On-Device Dysarthria Transcription (iOS)

This architecture utilizes **WhisperKit** (by Argmax) for native Apple Neural Engine (ANE) acceleration and a "Record-then-Process" workflow to maximize accuracy for non-standard speech.


### 1. Model Conversion & Preparation

*Note: The fine-tuned dysarthric speech model is currently in development. We are using a two-phase approach for model integration. See `implementation_plan.md` for full details.*

#### Phase 1: Temporary Solution (Base Whisper Model)
Until the fine-tuned model is ready, we will use the pre-converted `openai_whisper-small.en` model provided by Argmax. This unblocks UI and audio pipeline development.
* **Model:** `openai_whisper-small.en`
* **Integration:** WhisperKit can automatically fetch this model at runtime. Alternatively, it can be downloaded via the WhisperKit CLI and bundled offline.

#### Phase 2: Permanent Solution (Fine-Tuned Model)
Once the custom fine-tuned weights are ready, they must be converted to Core ML and bundled into the app.

* **Tool:** `whisperkittools` (Python-based converter).
* **Command:** ```bash
    pip install whisperkittools
    whisperkit-generate-model --model-version /path/to/your/finetuned-small --output-dir ./Models
    ```
* **Output:** A folder containing `.mlmodelc` or `.mlpackage` files.
* **Xcode Integration:** Drag the generated folder into your Xcode project. Ensure it is added to **"Copy Bundle Resources"** in Build Phases.


### 2. Software Architecture

#### Core Components
* **Audio Engine:** Uses `AVFoundation` to record a mono 16kHz PCM `.wav` file.
* **Inference Engine:** `WhisperKit` handles the Mel-spectrogram conversion and ANE execution.
* **UI Layer:** Simple Start/Stop toggle to accommodate dysarthria-specific speech pacing.

#### Implementation Logic (Swift)

**A. Initialization**
During Phase 1 (Temporary), initialize WhisperKit with the base model name:
```swift
let config = WhisperKitConfig(model: "openai_whisper-small.en")
let whisperKit = try await WhisperKit(config)
```

For Phase 2 (Permanent), load your custom model directly from the app bundle:
```swift
let modelURL = Bundle.main.url(forResource: "Your_Model_Folder", withExtension: nil)!
let config = WhisperKitConfig(
    model: "CustomModel", 
    modelFolder: modelURL,
    computeUnits: .all // Uses Neural Engine + GPU + CPU
)
let whisperKit = try await WhisperKit(config)
```

**B. Transcription Configuration**
Fine-tune decoding parameters to handle phonetic variability:
```swift
var options = DecodingOptions()
options.temperature = 0.0        // Uses greedy decoding for speed and stability
options.temperatureIncrementOnFallback = 0.2 // Fallback for complex speech
options.initialPrompt = "The following is speech from a person with dysarthria..." // Contextual bias
```

**C. Transcription Call**
Executed once the user stops the recording.
```swift
func processAudio(at url: URL) async {
    let results = try? await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
    self.onScreenText = results?.first?.text ?? ""
}
```


### 3. Optimization for Dysarthria
| Feature | Implementation | Benefit |
| :--- | :--- | :--- |
| **Manual Gating** | User-controlled Start/Stop buttons. | Prevents auto-VAD from cutting off slow speech or labored breathing. |
| **Greedy Decoding** | `temperature = 0.0` with fallbacks. | Maximizes Neural Engine performance while allowing retries for slurred consonants. |
| **Local Inference** | 100% on-device (ANE). | No latency spikes; maintains privacy for sensitive clinical data. |
| **Initial Prompting** | Pass frequent vocabulary to `initialPrompt`. | Corrects common misinterpretations of the speaker's unique vocal patterns. |



