# Implementation Report: Smart Speak (AAC Expander)

## 1. Architecture Overview
The feature follows a **Model-View-ViewModel-Service (MVVM-S)** architecture, unified under the **SpeakEasy** brand.

### Components
- **`AACExpanderView`**: High-accessibility UI with massive touch targets.
- **`ContactManager`**: Smart routing service for name-based messaging.
- **`GemmaService`**: LiteRT wrapper with a manual `nil` backend patch for Gemma 4 compatibility.
- **`MessageService`**: Unified system SMS integration.

## 2. Key Features & Workflows

### Smart Contact Routing
Automatically routes messages based on shorthand context:
1. User speaks: *"late Dad"*
2. `ContactManager` detects "Dad".
3. Messaging icon defaults to Dad's saved number.

### Custom Navigation (Accessibility)
Replaced standard `TabView` with a custom **Large-Scale TabBar**:
- 24pt/32pt font and icon sizes.
- Oversized hit targets for users with motor tremors.

## 3. Technical Optimizations

### Gemma 4 Signature Patch
The `.litertlm` bundle for Gemma 4 contains 3 vision signatures which causes a crash in LiteRT-LM. 
**Fix:** Patched `LiteRTLMEngine.swift` to pass `nil` to vision/audio backends, loading only the LLM text core. (See `docs/GEMMA4_PATCH_GUIDE.md`).

### Simulation Layer
A **Simulated AI Mode** bypasses real LLM loading for developer testing on Mac Simulators, providing mock 3-sentence expansions with 1.5s latency.

## 4. Intelligence & Context Tuning

### Emoji Interpretation
The system prompt has been optimized to treat emojis as high-signal intent markers.
- **Rule:** Emojis are prioritized over fragmented text for intent detection.
- **Few-Shot Examples:** The prompt includes explicit mappings (e.g., `🏀` -> "I want to play basketball") to guide the model when text is absent.

### Quick Chip Logic
Refined the interaction between UI shortcuts and the LLM:
- **Full Phrase Preservation:** Selecting a shortcut adds the entire label (emoji + text) to the shorthand input.
- **Visual Segregation:** The UI maintains a "First-Word-Large" style for visibility while passing the full string to the AI for maximum context.

## 5. Resource Management
- **Gated Onboarding:** The 2.6GB Gemma 4 download is now exclusively gated to the Smart Speak tab, keeping the Transcribe tab lightweight.
- **Memory Entitlement:** Uses `com.apple.developer.kernel.increased-memory-limit` for stable performance on iPad Pro M4.
