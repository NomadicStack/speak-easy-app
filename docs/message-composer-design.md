# Design Document: On-Device AI Message Composer (SpeakEasy)

## Problem Statement

People with dysarthria can transcribe speech via SpeakEasy, but the raw output is often fragmented, misspelled, or grammatically rough. Manually editing it into a sendable text message is a major barrier for users with motor impairments. We need an **on-device** AI layer that polishes raw transcriptions into clean messages — with **zero data leaving the iPad**.

---

## Feature Overview

After transcription, the user taps **"Compose Message"**. The app runs **Gemma 4 2B (4-bit quantized)** locally via **MLX Swift** to produce a clean, concise message. The user reviews, edits if needed, and sends via the native iOS Messages app — all in 2-3 taps, fully offline.

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  WhisperKit  │────▶│  Raw Text    │────▶│  Gemma 4 2B      │────▶│  Polished     │
│  (ANE)       │     │  on screen   │     │  (MLX / GPU)     │     │  Message      │
└─────────────┘     └──────────────┘     └──────────────────┘     └──────┬───────┘
                                                                         │
                                                               ┌─────────▼────────┐
                                                               │  MFMessageCompose │
                                                               │  (Send via SMS)   │
                                                               └──────────────────┘
```

---

## On-Device Strategy: MLX Swift (Same as Locally AI / AI Edge Gallery)

### Why MLX?

Apps like **Locally AI** and **Google AI Edge Gallery** run Gemma on-device using Apple's **MLX** framework. MLX is purpose-built for Apple Silicon and is the gold standard for on-device LLM inference on iOS/iPadOS/macOS. Here's why it's the right choice for SpeakEasy:

| Factor | MLX Swift | MediaPipe |
|:---|:---|:---|
| **Used by** | Locally AI, Apple's LLMEval reference app | Google AI Edge Gallery (Android) |
| **iOS integration** | Native Swift, SPM package | CocoaPods only (no SPM) |
| **Compute** | Metal GPU (unified memory) | Metal GPU |
| **Package manager** | ✅ Swift Package Manager | ❌ Requires CocoaPods migration |
| **Model format** | HuggingFace `.safetensors` (MLX format) | `.task` bundle (custom conversion) |
| **iPad performance** | ~40 tok/s on M-series, ~20 tok/s on A-series | Similar |
| **Apple Silicon optimization** | Designed for it (unified memory) | Generic cross-platform |

**MLX uses Swift Package Manager** — the same dependency system this project already uses for WhisperKit. No CocoaPods migration needed. This is the decisive advantage.

### Why On-Device? (Privacy Requirements)

| Concern | On-Device Answer |
|:---|:---|
| **Privacy** | Transcriptions of clinical/personal speech never leave the device |
| **Offline** | Works with no internet — critical for users in clinical/home settings |
| **Latency** | No network round-trip; generation starts immediately |
| **Cost** | No API usage fees; no rate limits |
| **No API key** | Zero configuration for the end user |

---

## Architecture

### New Components

```
DysarthriaApp/
├── GemmaService.swift                // NEW — MLX Swift LLM inference wrapper
├── MessageComposerViewModel.swift    // NEW — Compose state, tone, message lifecycle
├── MessageComposeView.swift          // NEW — MFMessageComposeViewController wrapper
├── ContentView.swift                 // MODIFIED — Add "Compose Message" button
├── TranscriptionViewModel.swift      // UNCHANGED
└── ...
```

### New SPM Dependency

```swift
// Package.swift or Xcode → Package Dependencies
.package(url: "https://github.com/ml-explore/mlx-swift-lm/", from: "1.0.0")

// Target dependency
.product(name: "MLXLLM", package: "mlx-swift-lm")
```

### Model Source

Use a pre-quantized 4-bit Gemma model from the `mlx-community` on HuggingFace:

```
mlx-community/gemma-4-2b-it-4bit
```

The model is downloaded on first use and cached locally in the app's sandbox. Subsequent launches load from cache instantly.

---

### 1. `GemmaService.swift` — On-Device LLM Engine

```swift
import MLXLLM
import MLXLMCommon

@MainActor
class GemmaService: ObservableObject {
    @Published var isModelLoaded: Bool = false
    @Published var isGenerating: Bool = false
    @Published var loadingProgress: String = ""

    private var modelContainer: ModelContainer?

    // HuggingFace model identifier (pre-quantized for mobile)
    private let modelID = "mlx-community/gemma-4-2b-it-4bit"

    /// Load model on-demand (called when user opens Compose sheet)
    func loadModel() async throws {
        guard !isModelLoaded else { return }
        loadingProgress = "Downloading model..."

        let config = ModelConfiguration.configuration(id: modelID)
        self.modelContainer = try await MLXLLM.loadModelContainer(configuration: config)
            { progress in
                self.loadingProgress = "Loading: \(Int(progress.fractionCompleted * 100))%"
            }

        self.isModelLoaded = true
        self.loadingProgress = ""
    }

    /// Generate polished message from raw transcription
    func compose(rawText: String, tone: String) async throws -> String {
        guard let container = modelContainer else { throw GemmaError.modelNotLoaded }
        isGenerating = true
        defer { isGenerating = false }

        let prompt = buildPrompt(rawText: rawText, tone: tone)

        let result = try await container.perform { (model, tokenizer) in
            let input = try await tokenizer.applyChatTemplate(
                messages: [["role": "user", "content": prompt]]
            )
            return try MLXLMCommon.generate(
                input: input,
                parameters: .init(temperature: 0.3, topP: 0.9),
                model: model,
                tokenizer: tokenizer,
                maxTokens: 256
            )
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Release GPU memory after composition
    func unloadModel() {
        self.modelContainer = nil
        self.isModelLoaded = false
    }

    private func buildPrompt(rawText: String, tone: String) -> String {
        """
        You are a message assistant for a person with dysarthria (a speech \
        disorder). They dictated a message using speech-to-text, but the \
        transcription may contain errors, repeated words, or fragments.

        Your job:
        - Interpret their intended meaning
        - Produce a clean, natural text message ready to send
        - Tone: \(tone)
        - Keep it concise (1-3 sentences max)
        - Do NOT add information they didn't say
        - Output ONLY the final message text, nothing else

        Raw transcription: "\(rawText)"
        """
    }
}

enum GemmaError: Error, LocalizedError {
    case modelNotLoaded
    var errorDescription: String? {
        "Gemma model is not loaded."
    }
}
```

### 2. `MessageComposerViewModel.swift` — State Manager

```swift
@MainActor
class MessageComposerViewModel: ObservableObject {
    @Published var composedMessage: String = ""
    @Published var isComposing: Bool = false
    @Published var showComposerSheet: Bool = false
    @Published var showSMSSheet: Bool = false
    @Published var recipientNumber: String = ""
    @Published var selectedTone: MessageTone = .casual
    @Published var error: String?
    @Published var isEditing: Bool = false

    private var rawTranscription: String = ""
    let gemmaService = GemmaService()

    enum MessageTone: String, CaseIterable, Identifiable {
        case casual = "Casual"
        case formal = "Formal"
        case friendly = "Friendly"
        var id: String { rawValue }
    }

    func compose(from transcription: String) {
        rawTranscription = transcription
        isComposing = true
        error = nil

        Task {
            do {
                try await gemmaService.loadModel()
                let result = try await gemmaService.compose(
                    rawText: transcription,
                    tone: selectedTone.rawValue
                )
                composedMessage = result
                gemmaService.unloadModel()  // Free GPU memory
            } catch {
                self.error = "Could not compose message. You can still edit manually."
                composedMessage = transcription  // Fallback: raw text
            }
            isComposing = false
        }
    }

    func regenerate() {
        compose(from: rawTranscription)
    }
}
```

### 3. `MessageComposeView.swift` — SMS Wrapper

Mirrors the existing `MailView.swift` pattern:

```swift
import MessageUI

struct MessageComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    var completion: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let completion: (MessageComposeResult) -> Void
        init(completion: @escaping (MessageComposeResult) -> Void) {
            self.completion = completion
        }
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                           didFinishWith result: MessageComposeResult) {
            completion(result)
            controller.dismiss(animated: true)
        }
    }
}
```

---

## Memory Coexistence Strategy

### Hardware Separation (ANE vs GPU)

WhisperKit runs on the **Apple Neural Engine (ANE)**. MLX runs Gemma on the **Metal GPU**. On Apple Silicon iPads, these are **separate hardware units** with a **unified memory** architecture — meaning the system can allocate memory to either without copying.

```
┌─────────────────────────────────────────────────────┐
│                 iPad (Apple Silicon)                  │
│                                                      │
│  ┌──────────────┐    ┌──────────────┐               │
│  │  Neural Engine │    │  Metal GPU   │               │
│  │  (WhisperKit)  │    │  (Gemma/MLX) │               │
│  │  ~150 MB       │    │  ~1.5 GB     │               │
│  └──────────────┘    └──────────────┘               │
│                                                      │
│          Unified Memory (8-16 GB)                    │
└─────────────────────────────────────────────────────┘
```

### Sequential Handoff (On-Demand Load/Unload)

Even though the hardware is separate, we implement a **load-on-demand** pattern to be conservative with memory:

```
Record → [WhisperKit on ANE] → Transcribe → Text on screen
                                                   ↓
                                        User taps "Compose"
                                                   ↓
                                      [Gemma loads on GPU] → Generate
                                                   ↓
                                      [Gemma unloads] → User edits/sends
```

- **Gemma loads** when the composer sheet opens
- **Gemma unloads** immediately after generation completes
- **WhisperKit stays resident** on the ANE throughout

### iPad RAM Headroom

| iPad Model | RAM | WhisperKit | Gemma 4-bit | Headroom |
|:---|:---|:---|:---|:---|
| iPad Pro M4 | 16 GB | ~150 MB | ~1.5 GB | ✅ ~14 GB free |
| iPad Pro M2 | 16 GB | ~150 MB | ~1.5 GB | ✅ ~14 GB free |
| iPad Air M2 | 8 GB | ~150 MB | ~1.5 GB | ✅ ~6 GB free |
| iPad (10th gen, A14) | 4 GB | ~150 MB | ~1.5 GB | ⚠️ Tight |

iPad is the primary target. M-series iPads have abundant RAM and will run Gemma at ~40 tokens/sec. A-series iPads (A14/A15) can still run it but at lower speed (~15-20 tok/s).

---

## Model Download Strategy

Unlike bundling, the MLX approach downloads the model from HuggingFace **on first use** and caches it locally. This is how **Locally AI** handles it.

### First Launch Flow

1. User taps "Compose Message" for the first time.
2. App checks if the model is cached locally.
3. **If cached:** Load from local cache (~2-3 seconds).
4. **If not cached:** Download from HuggingFace (~1.2 GB), show progress bar in composer sheet, cache to app sandbox, then load.
5. Ready to generate.

### Bundling vs. Download

| | Bundle in App | Download on First Use |
|:---|:---|:---|
| **App Store size** | +1.2 GB | No impact |
| **App Store review** | Slower (large binary) | Normal |
| **Model updates** | Requires app update | Change model ID in code |
| **User experience** | Instant on first use | One-time download wait |

Since app size is not a concern, the model can also be bundled via Xcode's "Copy Bundle Resources" as an alternative. The code can check bundle first, then fall back to HuggingFace download — giving instant first use + updatable.

---

## Prompt Engineering

The prompt leverages Gemma's instruction-tuned format and is optimized for:
1. **Fixing transcription artifacts** — repeated words, missing letters, broken grammar
2. **Preserving speaker intent** — no added content or hallucinated details
3. **SMS brevity** — 1-3 sentences max
4. **Tone matching** — user-selectable

### Examples

| Raw Transcription | Tone | Composed Output |
|:---|:---|:---|
| `"hey can you uh pick up the the milk on way home pleas"` | Casual | `"Hey, can you pick up milk on the way home? Thanks!"` |
| `"i need to cancel my appointment tomorrow morning"` | Formal | `"I would like to cancel my appointment tomorrow morning. Thank you."` |
| `"tell mom i i love her and will call later"` | Friendly | `"Tell Mom I love her and I'll call later! 💛"` |

---

## User Flow

1. **User records speech** → WhisperKit transcribes on ANE
2. **Raw text displayed** on screen
3. **User taps "Compose Message"** → Gemma loads via MLX on GPU
4. **Select tone:** Casual / Formal / Friendly
5. **Gemma generates** polished message → Gemma unloads from GPU
6. **Polished message shown** in editable preview
7. **User reviews:**
   - Edit manually → stays in preview
   - Regenerate → reloads Gemma, generates again
   - Satisfied → tap Send
8. **iOS Messages app opens** with pre-filled text

---

## UI Design (iPad-First)

### ContentView Modification

Add a **"Message"** button to the existing action bar (next to Copy/Share):

```swift
Button(action: {
    messageComposerVM.compose(from: transcriptionVM.transcribedText)
    messageComposerVM.showComposerSheet = true
}) {
    Label("Message", systemImage: "message.fill")
        .foregroundColor(.green)
}
.disabled(transcriptionVM.transcribedText == "Press record to start." || transcriptionVM.isTranscribing)
.sheet(isPresented: $messageComposerVM.showComposerSheet) {
    ComposerSheetView(viewModel: messageComposerVM)
}
```

### Composer Sheet Layout (iPad)

The sheet uses iPad-optimized sizing with large, accessible touch targets:

```
┌─────────────────────────────────────────────────┐
│           Compose Message                   [X] │
│                                                 │
│  Tone: [ Casual | Formal | Friendly ]           │
│         ═══════                                 │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │                                         │    │
│  │  Hey, can you pick up milk on the       │    │
│  │  way home? Thanks!                      │    │
│  │                                (54pt)   │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  [ 🔄 Regenerate ]          [ ✏️ Edit ]         │
│                                                 │
│  To: [ Phone number                        ]    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │          📩  Send Message               │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │          📋  Copy to Clipboard          │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

---

## Accessibility (iPad-First Design)

| Feature | Implementation |
|:---|:---|
| **Large text** | Composed message displayed at 54pt bold (matching transcription size) |
| **Large touch targets** | All buttons ≥ 60pt height; Send button full-width |
| **Minimal typing** | Tone via `Picker` segment (1 tap); phone number is the only text input |
| **Editable output** | TextEditor with same large font as main transcription view |
| **Fallback** | "Copy to Clipboard" always works even if SMS unavailable |
| **VoiceOver** | All elements have `.accessibilityLabel` and `.accessibilityHint` |
| **Loading state** | Spinner + "Composing message..." text + progress % during model load |
| **Background safety** | Inference gated on `@Environment(\.scenePhase)` — pauses if app backgrounds |

---

## Error Handling

| Scenario | Behavior |
|:---|:---|
| **First-time download (no WiFi)** | Show message: "Connect to WiFi to download the AI model (one-time, ~1.2 GB)" |
| **Model load failure** | Show inline alert; pre-fill composer with raw transcription for manual edit |
| **Generation failure** | Fall back to raw text in editor; user can manually polish |
| **Empty transcription** | "Compose Message" button stays disabled |
| **SMS not available** | Fall back to Share Sheet (same pattern as existing mail fallback) |
| **App backgrounded during inference** | Pause generation; resume when app returns to foreground |

---

## Implementation Phases

### Phase 1 — MLX Integration & Model Loading
- [ ] Add `mlx-swift-lm` SPM dependency (`MLXLLM`, `MLXLMCommon`)
- [ ] `GemmaService.swift` — load/generate/unload lifecycle
- [ ] Model download with progress callback
- [ ] Verify Gemma 4 2B IT 4-bit loads on target iPad

### Phase 2 — Composer UI
- [ ] `MessageComposerViewModel.swift` — state management
- [ ] Composer sheet: tone segmented picker, editable preview, regenerate
- [ ] "Compose Message" button in ContentView action bar
- [ ] Loading animation with progress percentage during model download/load

### Phase 3 — Send Integration
- [ ] `MessageComposeView.swift` — `MFMessageComposeViewController` wrapper
- [ ] Phone number input field
- [ ] Send → opens iOS Messages with pre-filled text
- [ ] Copy-to-clipboard fallback
- [ ] Share Sheet fallback for devices without SMS capability

### Phase 4 — Polish & Safety
- [ ] `@Environment(\.scenePhase)` guard to prevent background GPU work
- [ ] iPad-responsive sizing (large fonts, max-width constraints)
- [ ] Memory profiling (WhisperKit ANE + Gemma GPU concurrent)
- [ ] VoiceOver audit and accessibility labels
- [ ] Model cache management (clear cache option in Advanced settings)

---

## Dependencies

| Dependency | Type | Purpose |
|:---|:---|:---|
| `mlx-swift-lm` | SPM package (new) | On-device Gemma inference via MLX |
| `MLXLLM` | Library from mlx-swift-lm | Model loading and generation |
| `MLXLMCommon` | Library from mlx-swift-lm | Common LLM utilities |
| `MessageUI` | iOS framework (already imported) | SMS composition |
| WhisperKit | Existing SPM package | Speech transcription (unchanged) |
| **No cloud services** | — | 100% on-device, 100% offline |
| **No CocoaPods** | — | Pure SPM, matching existing project setup |
