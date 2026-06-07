# Design Document: Ambient Smart Replies (SpeakEasy)

## Problem Statement

Conversations move quickly. For individuals with dysarthria, formulating and dictating (or typing) a response takes significant time and physical effort. This delay often results in the user feeling left behind in social interactions, as the conversation moves on before they can interject. 

Traditional AAC apps require the user to initiate every piece of communication. We need a system that **ambiently listens** to the conversation partner and proactively prepares contextually relevant responses. By reducing the physical effort to a single screen tap, users can participate in conversations at a natural pace.

---

## Feature Overview

**Ambient Smart Replies ("Listener Mode")** flips the communication paradigm. 

When enabled, the app uses **WhisperKit** to actively transcribe the *conversation partner's* speech in real-time. Once the app detects an end-of-utterance (e.g., a pause after a question), it passes the transcript to the on-device **Gemma 4 2B** model via **MLX Swift**. Gemma generates 3 highly probable, natural replies. The user simply taps the best reply to immediately speak it aloud via the device's TTS engine.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Partner's   │────▶│  WhisperKit  │────▶│  Gemma 4 2B      │────▶│  AVSpeech    │
│  Speech      │     │  (ANE)       │     │  (MLX / GPU)     │     │  Synthesizer │
└──────────────┘     └──────┬───────┘     └──────────────────┘     └──────────────┘
                            │ (End of utterance detected)
                            ▼
                     ┌──────────────┐
                     │  3 Context   │
                     │  Replies     │
                     └──────────────┘
```

---

## Architecture & Integration

This feature represents the most complex orchestration in the SpeakEasy app, as it requires both machine learning frameworks (WhisperKit and MLX Swift) to run in a continuous loop.

### New Components

```
DysarthriaApp/
├── AmbientListeningViewModel.swift   // NEW — Orchestrates WhisperKit and Gemma
├── EndOfSpeechDetector.swift         // NEW — VAD/Silence detection logic
├── SmartReplyView.swift              // NEW — UI for partner transcript and quick replies
└── ...
```

### 1. `EndOfSpeechDetector.swift`

Unlike the core transcription feature (which uses manual Start/Stop buttons), Listener Mode requires automatic detection of when the partner has finished speaking to trigger generation.

```swift
import AVFoundation

class EndOfSpeechDetector {
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5 // 1.5 seconds of silence
    var onSpeechEnded: ((String) -> Void)?
    
    func speechDetected() {
        silenceTimer?.invalidate()
    }
    
    func silenceDetected(currentTranscript: String) {
        guard !currentTranscript.isEmpty else { return }
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { _ in
            self.onSpeechEnded?(currentTranscript)
        }
    }
}
```

### 2. `AmbientListeningViewModel.swift`

Coordinates the continuous transcription loop and LLM handoff.

```swift
@MainActor
class AmbientListeningViewModel: ObservableObject {
    @Published var partnerTranscript: String = "..."
    @Published var isListening: Bool = false
    @Published var suggestedReplies: [String] = []
    @Published var aiState: AIState = .idle
    
    enum AIState {
        case idle, listening, processing, ready
    }

    let whisperKit: WhisperKitWrapper
    let gemmaService: GemmaService
    let endOfSpeechDetector = EndOfSpeechDetector()

    // ... Initialization ...

    func toggleListening() {
        isListening.toggle()
        if isListening {
            startAmbientListening()
        } else {
            whisperKit.stopRecording()
            aiState = .idle
        }
    }

    private func startAmbientListening() {
        aiState = .listening
        suggestedReplies.removeAll()
        
        // Callback from WhisperKit audio stream
        endOfSpeechDetector.onSpeechEnded = { [weak self] finalTranscript in
            guard let self = self else { return }
            self.generateReplies(for: finalTranscript)
        }
    }

    private func generateReplies(for transcript: String) {
        aiState = .processing
        whisperKit.pauseRecording() // Pause mic during generation to save resources

        Task {
            do {
                try await gemmaService.loadModel()
                let result = try await gemmaService.generateSmartReplies(context: transcript)
                self.suggestedReplies = parseReplies(result)
                self.aiState = .ready
            } catch {
                print("Failed to generate replies")
                self.aiState = .listening
            }
            // Resume listening after user makes a choice or dismisses
        }
    }
}
```

---

## Hardware Coexistence (ANE + GPU)

This feature pushes the iPad's Unified Memory architecture to its limits.

1. **Continuous ANE:** WhisperKit runs continuously on the Apple Neural Engine (~150MB footprint).
2. **Burst GPU:** When silence is detected, Gemma 4 2B (1.2GB footprint) is loaded into the Metal GPU.
3. **Sequential Mitigation:** To prevent thermal throttling and battery drain, `whisperKit.pauseRecording()` is called the moment `gemmaService` begins generation. The Neural Engine effectively idles while the GPU spikes for ~1.5 seconds to generate the replies.

---

## Prompt Engineering

The prompt is designed to act as a direct conversational participant responding to the inputted transcript.

```swift
func buildSmartReplyPrompt(partnerText: String) -> String {
    """
    You are assisting a person with a speech impairment in a conversation. 
    The other person just said: "\(partnerText)"

    Generate 3 distinct, natural, and brief responses the user could say back.
    Include a mix of affirmative, negative, or clarifying responses.

    Rules:
    - Provide exactly 3 options.
    - Format as a numbered list (1., 2., 3.).
    - Keep responses under 10 words each.
    - Do not include conversational filler.
    """
}
```

### Examples

| Partner Speech (WhisperKit) | Gemma Output (Parsed) |
|:---|:---|
| *"Do you want chicken or fish for dinner tonight?"* | 1. "Chicken sounds great."<br>2. "I would prefer fish."<br>3. "Whatever you want is fine." |
| *"Are you experiencing any pain in your chest right now?"* | 1. "No, I feel fine."<br>2. "Yes, a little bit."<br>3. "No chest pain, just tired." |

---

## User Flow & UI Design

1. **Activation:** User toggles "Listening Mode" ON at the top of the screen.
2. **Ambient Display:** The screen displays a live transcription bubble (styled like a chat message) showing what the partner is saying.
3. **Trigger:** The partner stops speaking. The UI visually shifts: a loading indicator replaces the "Listening" icon.
4. **Suggestions:** Three large, tappable buttons fade in containing the AI-generated replies.
5. **Action:** 
   - The user taps a reply to speak it aloud instantly.
   - The UI clears the suggestions, and WhisperKit resumes listening automatically for the partner's next statement.

### Accessibility Considerations
- **Hands-Free:** No tapping is required until the user is ready to speak.
- **Large Typography:** The partner's transcript is displayed at a large font size, acting as a real-time closed-captioning tool for users who may also have hearing difficulties.
- **Visual Status:** A clear visual hierarchy (Listening ➔ Processing ➔ Ready) using distinct icons and animations ensures the user always knows what state the AI is in.
