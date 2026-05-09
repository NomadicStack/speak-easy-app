# Implementation Report: Smart Speak (AAC Expander)

This document summarizes the technical implementation of the **Smart Speak** feature within the DysarthriaApp.

## 1. Architecture Overview

The feature follows a **Model-View-ViewModel-Service (MVVM-S)** architecture to ensure a clean separation of concerns and easy future integration with real MLX/Gemma models.

### Components
- **`AACExpanderView.swift` (View):** The user interface for the "Smart Speak" tab, optimized for voice-first interaction.
- **`AACViewModel.swift` (ViewModel):** Manages the state, coordinates expansion logic, and enforces the **strict 3-sentence limit**.
- **`GemmaService.swift` (Service):** Wraps the LLM inference logic. Currently uses a simulation layer but is structured for MLX Swift.
- **`TextToSpeechService.swift` (Service):** Manages audio output using Apple's `AVSpeechSynthesizer` with a preference for high-quality voices (e.g., "Zoe").

## 2. Key Features & Workflows

### Voice-First Automatic Expansion
The workflow is streamlined to minimize physical effort:
1. **Record:** User taps the Microphone button and speaks shorthand.
2. **Auto-Transcribe:** On stop, the fine-tuned Whisper model transcribes the audio.
3. **Auto-Expand:** The system immediately triggers the AI expansion once transcription is complete. No extra button tap is required.
4. **Strict Output:** The system always provides **exactly 3 variations** as natural sentence variations.

### Iterative Refinement & Duplication Protection
Users can refine their intent by recording additional keywords. 
- **Duplication Fix:** To prevent the previous transcription from repeating when appending, the app explicitly clears the transcription engine's memory before each new recording in the Smart Speak tab.
- **Clean Appending:** New keywords are cleanly appended to the existing shorthand (e.g., "thirsty" + "water" = "thirsty water") before regeneration.

### High-Contrast UI
- **Refined Font Sizes:** Text is displayed in a balanced, high-contrast style (Title/Headline for shorthand, Title3/Body for variations) to ensure accessibility without overwhelming the screen.
- **Integrated TTS:** Every card is tappable for immediate text-to-speech output.

## 3. Integration with Transcription Engine

The feature leverages the **shared fine-tuned Whisper model** via `TranscriptionViewModel`.

- **Data Orchestration:** `ContentView` monitors the `isTranscribing` state. When a transcription finishes while the user is in the "Smart Speak" tab, it automatically captures the result and triggers the `AACViewModel.expand()` process.
- **State Isolation:** While the transcription model is shared, its *text state* is isolated during recording in the Smart Speak tab to ensure "incremental" appending works correctly.

## 4. Current State: Simulation Logic

A **Simulation Layer** in `GemmaService` allows for immediate testing:
- **Keyword Matching:** Recognizes patterns like "water", "bus", "thirsty", "food", etc.
- **Structured Response:** Returns valid variations that match the requested conversational tone and list format.
- **Latency Simulation:** Mimics the processing time of a real LLM to validate loading UI.

## 5. Future LLM Integration (MLX Swift)

The implementation is designed for a drop-in transition to real AI:
1. **Dependency:** Add `MLX Swift`.
2. **Implementation:** Update `GemmaService.loadModel()` and replace the simulation with a real inference call using the pre-configured system prompt.
3. **Resource Management:** `unloadModel()` is already called after every expansion to free up GPU memory.
