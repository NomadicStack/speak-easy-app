# Dysarthria Communication Interpreter - Prompt Adaptation

This document details the transition from a generic AAC expander to a specialized Communication Interpreter for users with dysarthria.

## 1. AI Prompt Evolution

### Original Role
The app acted as a generic "Augmentative and Alternative Communication (AAC) assistant" that expanded shorthand into three polite, conversational sentences.

### Adapted Role (Current)
The model is now defined as a **Communication Interpreter**. Its primary task is to transform fragmented, noisy speech transcripts from a Whisper model into clear, polished messages while adhering to specific core rules:
- **Interpret**: Actively look for intent in fragments.
- **Do Not Hallucinate**: Ask for clarification if input is truly unintelligible.
- **Be Concise**: Prioritize high-speed, direct communication.
- **No Chat**: Output only the polished results without conversational filler.

## 2. Output Structure

Initially, the adaptation introduced specific categories (**CASUAL**, **CLEAR**, **SHORT**). Based on user feedback, these labels were removed to provide a cleaner interface. 

**Current Output Strategy:**
- Provide exactly **three** natural, fully formed variations.
- No category prefixes (e.g., "CASUAL:").
- Presented as a numbered list for robust internal parsing.

## 3. Context Injection

To improve interpretation accuracy, the app now injects runtime context into the prompt:
- **USER NAME**: Persisted via `@AppStorage` in Developer Settings.
- **KEY CONTACTS**: Automatically formatted from the `ContactManager` list (e.g., "Sarah: 555-0123").

*Note: Location context was implemented and subsequently removed per user request to simplify the interface and focus on intent interpretation.*

## 4. Technical Implementation Details

### GemmaService.swift
The `expandAAC` method was modified to accept `userName` and `contacts` parameters. The prompt uses the `<|turn>user` and `<|turn>model` markers optimized for Gemma 4.

### AACViewModel.swift
- Added persistent storage for `user_name`.
- Refined `parseOptions` to handle numbered lists and strip any potential labels or markdown artifacts.
- Improved error handling for cases where the model might return non-standard formatting.

### Audio & Messaging Fixes
To support the new prompt-driven workflow, critical stability fixes were applied:
- **Audio Session**: Switched to a dynamic category management strategy. TTS uses `.playback` with `.spokenAudio` mode, while Recording uses `.playAndRecord`. This resolved the `AVAudioBuffer` error and improved speech clarity.
- **Message Dispatch**: If no contact is identified in the shorthand, the app now opens the message composer with an empty recipient field, allowing for manual input instead of falling back to a default "buddy" name.

## 5. Developer Settings
The user-specific configuration (Name) has been moved to **Advanced > Developer Settings** within the Model Selection view to keep the primary interface focused on communication.
