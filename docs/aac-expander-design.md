# Design Document: On-Device Smart AAC Expander (SpeakEasy)

## Problem Statement

For individuals with dysarthria, the physical effort required to speak or type full, grammatically correct sentences is often exhausting. Traditional Augmentative and Alternative Communication (AAC) apps require users to laboriously type out every word or navigate complex menus to find pre-written phrases. We need an **intelligent shorthand expander** that allows users to input minimal keywords (e.g., "water please") and uses an **on-device** AI layer to generate natural, full sentences ready to be spoken aloud via Text-to-Speech (TTS).

---

## Feature Overview

The user speaks a highly abbreviated string of keywords (shorthand) into the SpeakEasy app. The fine-tuned WhisperKit transcribes this audio into raw text. By tapping **"Expand with AI"**, the app leverages **Gemma 4 2B (4-bit quantized)** locally via **LiteRTLM-Swift** to generate 3 natural sentence variations based on the transcribed input. 

**Iterative Refinement:** If the generated variations aren't quite right, the user can press record again and speak additional context. The new transcribed text is appended to the existing shorthand, and Gemma regenerates 3 new, refined variations. Once satisfied, the user selects the best option to be spoken aloud by the device's TTS engine.

```text
┌──────────────┐      ──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Spoken      │────▶│  WhisperKit  │────▶│  Gemma 4 2B      │────▶│  3 Sentence  │
│  Shorthand   │     │(Transcription)│     │  (LiteRT / GPU)  │     │  Variations  │
└──────────────┘      ──────┬───────┘     └────────┬─────────┘     └──────┬───────┘
                            │                      │                      │
                            │                      │                      ▼
                            │                      │               ┌──────────────┐
                            │                      │               │  AVSpeech    │
                            │                      │               │  Synthesizer │
                            │                      │               └──────────────┘
                            │                      ▼
                     ┌──────┴───────┐     ┌──────────────────┐
                     │  Additional  │     │  Regenerate      │
                     │  Context     │────▶│  with new context│
                     │  (Spoken)    │     └──────────────────┘
                     └──────────────┘
```

---

## On-Device Strategy: LiteRTLM-Swift

This feature shares the same underlying LiteRTLM-Swift architecture as the Message Composer. 

### Why LiteRT and On-Device?
- **Zero Latency Requirement:** In real-world conversations, users cannot wait for cloud API round-trips to communicate. On-device generation ensures the fastest possible response time.
- **Privacy:** Conversational intents and personal needs remain entirely on the device.
- **Offline Reliability:** Critical for daily communication outside of Wi-Fi zones or in hospitals with poor connectivity.
- **Shared Memory Base:** Once the Gemma model is cached on the device for the Message Composer, it is seamlessly reused for the AAC Expander without additional storage overhead.

---

## Architecture

### New Components

```
DysarthriaApp/
├── AACViewModel.swift                // NEW — State management for the expander
├── AACExpanderView.swift             // NEW — Main UI for input and expanded options
├── TextToSpeechService.swift         // NEW — AVSpeechSynthesizer wrapper
├── GemmaService.swift                // SHARED — Existing LiteRT LLM wrapper
└── ...
```

### 1. `TextToSpeechService.swift`

A simple wrapper around AVFoundation to handle playback of the generated text.

```pseudocode
CLASS TextToSpeechService:
    PROPERTIES:
        synthesizer = SystemTextToSpeechEngine()

    FUNCTION speak(text):
        CREATE utterance FROM text
        
        // Attempt to find a high-quality, young-sounding female voice (e.g., "Zoe")
        GET system_voices
        IF system_voices CONTAINS voice named "Zoe":
            SET utterance.voice = "Zoe"
        ELSE IF system_voices CONTAINS any female english voice:
            SET utterance.voice = first female english voice
        ELSE:
            SET utterance.voice = default english voice
            
        // Slightly slower rate is often preferred for clarity in conversational settings
        SET utterance.rate = DEFAULT_RATE * 0.9
        
        // Stop any ongoing speech before starting new
        IF synthesizer.is_speaking():
            synthesizer.stop()
            
        synthesizer.play(utterance)
```

### 2. `AACViewModel.swift`

Manages the input, coordinates with `GemmaService` for generation, and parses the output into discrete options.

```pseudocode
CLASS AACViewModel:
    STATE:
        shorthandInput = ""
        isGenerating = FALSE
        generatedOptions = []
        error = NULL

    SERVICES:
        gemmaService (Local LLM Manager)
        ttsService (Text To Speech)

    FUNCTION expand():
        IF shorthandInput IS EMPTY: RETURN
        
        SET isGenerating = TRUE
        CLEAR generatedOptions
        CLEAR error

        ASYNC DO:
            TRY:
                AWAIT gemmaService.loadModel()
                result_text = AWAIT gemmaService.expandAAC(shorthandInput)
                generatedOptions = parseOptions(result_text)
                gemmaService.unloadModel() // Free GPU memory
            CATCH:
                SET error = "Failed to generate options."
            
            SET isGenerating = FALSE
            
    // Called when the user speaks additional context to refine the variations
    FUNCTION appendContextAndRegenerate(newTranscription):
        IF newTranscription IS EMPTY: RETURN
        
        // Append the new spoken context to the existing shorthand
        shorthandInput = shorthandInput + " " + newTranscription
        
        // Automatically regenerate the options with the combined context
        expand()

    // Parses a numbered list from the LLM output into a list of strings
    FUNCTION parseOptions(llm_output):
        SPLIT llm_output BY newlines
        REMOVE empty lines
        REMOVE list formatting (e.g., "1.", "-", etc.)
        RETURN cleaned list of options
```

---

## Prompt Engineering

The system prompt for `GemmaService.expandAAC()` is designed to force the model to output *exactly three* conversational variations without any conversational filler or preambles.

```pseudocode
FUNCTION buildAACPrompt(shorthand):
    RETURN STRING FORMAT:
        "You are an Augmentative and Alternative Communication (AAC) assistant.
        A user has inputted a shorthand phrase. Expand this shorthand into three
        different natural, fully formed sentences that the user might want to say aloud.
        
        Rules:
        - Provide exactly 3 options.
        - Format as a numbered list (1., 2., 3.).
        - Do not include any conversational filler (e.g., 'Here are your options:').
        - Make the tone polite and conversational.

        Shorthand: {shorthand}"
```

### Examples

| Shorthand Input | Gemma Output (Parsed) |
|:---|:---|
| `"bus stuck late work"` | 1. "I'm going to be late for work because my bus is stuck in traffic."<br>2. "My bus is stuck right now, so I will be running late for work."<br>3. "I'll be late today. The bus got stuck." |
| `"thirsty want water"` | 1. "I am very thirsty. Could I please have a glass of water?"<br>2. "Can I get some water, please? I'm feeling thirsty."<br>3. "I would like something to drink. Water, please." |

---

## User Flow

1. **Input:** User navigates to the "Expander" tab and records spoken shorthand (e.g., "hungry order pizza"). WhisperKit transcribes this audio into text.
2. **Trigger:** User taps "Expand with AI".
3. **Generation:** Gemma loads on the GPU and generates 3 natural sentence options based on the transcription.
4. **Iterative Refinement (Optional):** 
   - If the generated options aren't quite what the user meant, they tap a **"Provide More Context"** microphone button and speak an additional detail (e.g., "pepperoni"). 
   - WhisperKit transcribes this new audio, appends it to the previous shorthand ("hungry order pizza pepperoni"), and automatically triggers a new Gemma generation pass.
5. **Selection:** Three refined, natural sentences appear as large, tappable cards.
6. **Action:** User taps the **"Speak"** button on their preferred card. The app immediately reads the sentence aloud using `AVSpeechSynthesizer`.

---

## UI Design & Accessibility (iPad-First)

| Feature | Implementation |
|:---|:---|
| **Large Touch Targets** | The generated options are presented as massive cards spanning the width of the screen, ensuring users with motor tremors can easily tap them. |
| **High Contrast State** | The loading state utilizes an animated pulsing ring (purple/accent color) to clearly indicate AI processing without relying on small text spinners. |
| **Quick Chips** | Below the text input, a row of customizable "Quick Chips" (e.g., `💧 thirsty`, `🏥 doc appt`) allows one-tap entry of common shorthand phrases. |
| **Audio Feedback** | A subtle haptic buzz and visual toast notification appear when the "Speak" button is pressed, confirming the action. |
| **Immediate Cleanup** | The `TextToSpeechService` calls `stopSpeaking(at: .immediate)` when a new phrase is triggered, preventing overlapping audio if the user taps multiple times. |

---

## Memory & Performance Management

- **Model Reuse:** The `GemmaService` caches the 1.2 GB model in memory while the app is active. If the user switches between the "Message Composer" and the "AAC Expander", the model does not need to be reloaded from disk.
- **GPU Unloading:** After the 3 variations are generated, the `modelContainer` is aggressively nilled out to free up the iPad's Unified Memory, ensuring iOS does not jettison the app if it is backgrounded.
- **Batched Generation:** Instead of generating options sequentially (which would take 3 separate inferences), the prompt forces the LLM to output all 3 options in a single generation pass, cutting wait time by roughly 66%.

---

## Interactive Web Prototype

A high-fidelity, interactive HTML/JS prototype of this workflow has been created to demonstrate the UI, the iterative refinement flow, and the TTS integration. 

You can test the prototype by opening the following file in your browser:
[`aac-demo/index.html`](./aac-demo/index.html)

*Note: The prototype simulates the Gemma inference delay and uses the browser's native `speechSynthesis` API to demonstrate the text-to-speech functionality.*
