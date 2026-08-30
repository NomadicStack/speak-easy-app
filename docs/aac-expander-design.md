# Design Document: On-Device Smart AAC Expander (SpeakEasy)

## Problem Statement

For individuals with dysarthria, the physical effort required to speak or type full, grammatically correct sentences is often exhausting. Traditional Augmentative and Alternative Communication (AAC) apps require users to laboriously type out every word or navigate complex menus to find pre-written phrases. We need an **intelligent shorthand expander** that allows users to input minimal keywords (e.g., "water please") and uses an **on-device** AI layer to generate natural, full sentences ready to be spoken aloud via Text-to-Speech (TTS).

---

## Feature Overview

The user speaks a highly abbreviated string of keywords (shorthand) into the SpeakEasy app. The fine-tuned WhisperKit transcribes this audio into raw text. The app leverages **Gemma 4 2B** locally via Google's official **LiteRT-LM** (`LiteRTLM`) to automatically generate 3 natural sentence variations based on the transcribed input.

**Iterative Refinement:** Users can record additional context, which is appended to the existing shorthand to regenerate more accurate variations.

### Key Workflows
- **Smart Contact Routing:** Mentions of names (e.g., "Dad", "Mom") in shorthand are automatically detected to route text messages to the correct recipient.
- **Unified Branding:** Consistent "SpeakEasy" header design across all features.
- **High Accessibility:** Oversized touch targets and huge fonts (up to 44pt) for users with motor impairments.

---

## On-Device Strategy: Google LiteRT-LM

### Hardware Optimization (iPad Pro M4)
- **Memory Management:** Uses the `increased-memory-limit` entitlement to access 5GB+ of the iPad's 8GB RAM.
- **Backend:** Metal GPU acceleration with automatic CPU fallback.

---

## Architecture

### Components

```
DysarthriaApp/
├── ContactManager.swift              // NEW — Named contact persistence & routing
├── MessageService.swift              // NEW — System SMS integration
├── AACViewModel.swift                // State management for expansion
├── AACExpanderView.swift             // High-accessibility UI for Smart Speak
├── GemmaService.swift                // LiteRT LLM wrapper with Simulation support
└── ...
```

### 1. `ContactManager.swift`
Handles the logic for detecting names in shorthand and mapping them to phone numbers.

### 2. `MessageService.swift`
Wraps `MFMessageComposeViewController` for safe, on-device messaging.

---

## UI Design & Accessibility (iPad-First)

| Feature | Implementation |
|:---|:---|
| **Custom TabBar** | Massive 24pt/32pt navigation targets spanning half the screen width. |
| **Oversized Text** | 44pt Bold shorthand display and 28pt response cards for high visibility. |
| **Smart Icons** | Side-by-side Speak (Purple) and Message (Blue) icons for quick actions. |
| **Gated Onboarding** | AI model download is gated to the Smart Speak tab to keep transcription lightweight. |

---

## Memory & Performance Management

- **GPU Unloading:** aggressively nilled out after generation to free unified memory.
- **Simulation Mode:** Developer toggle to bypass LLM loading for testing on resource-constrained environments (Simulators).
