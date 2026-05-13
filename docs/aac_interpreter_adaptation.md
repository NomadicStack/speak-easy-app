# Dysarthria Communication Interpreter - Prompt Adaptation

This document details the transition from a generic AAC expander to a specialized Communication Interpreter for users with dysarthria.

## 1. AI Prompt Evolution

### Original Role
The app acted as a generic "Augmentative and Alternative Communication (AAC) assistant" that expanded shorthand into three polite, conversational sentences.

### Adapted Role (Current)
The model is now defined as a **Speech-to-Intent Interpreter**. Its primary task is to decode noisy, fragmented transcripts from a user with dysarthria into clear, polished communication.

**Phonetic Awareness:**
The prompt explicitly instructs the model to perform **Phonetic Decoding**. Instead of just looking at spelling, it is told: *"If a word looks wrong, think of what it SOUNDS like."* This allows it to bridge the gap for common transcription errors (e.g., "wada" for "water").

### Core Rules:
1. **Phonetic Decoding**: Prioritize auditory similarity over literal spelling for noisy input.
2. **Be the Voice**: Write in the first person ("I", "Me", "My") from the user's perspective.
3. **Intent Mapping**: Use context (User Name and Contacts) to infer the most likely communicative intent.
4. **No Meta-Talk**: Output ONLY the 3 sentences as a numbered list. No preamble.

## 2. Output Structure

The output strategy has evolved from simple variations to specific **Intent-Based Styles**.

**Current Output Strategy (3 Distinct Options):**
1. **DIRECT**: Short, high-speed, and urgent (e.g., "I need water.").
2. **NATURAL**: A complete, polite, and natural-sounding sentence for face-to-face conversation.
3. **MESSAGING**: Optimized specifically for SMS, utilizing contact names from the context (e.g., "Hey Dad, could you bring me some water?").

## 3. Context Injection

To improve interpretation accuracy, the app now injects runtime context into the prompt:
- **USER NAME**: Persisted via `@AppStorage` in Developer Settings.
- **KEY CONTACTS**: Automatically formatted from the `ContactManager` list (e.g., "Sarah: 555-0123").

*Note: Location context was implemented and subsequently removed per user request to simplify the interface and focus on intent interpretation.*

## 4. Technical Implementation Details

### GemmaService.swift
The `expandAAC` method is optimized for **Gemma 2-2B (Gemma 4)** using the `<|turn>user` and `<|turn>model` markers.

### Model Optimization
To ensure the 2B model remains focused and efficient:
- **Temperature**: Set to `0.6` to prioritize reliable decoding over creative generation.
- **Max Tokens**: Capped at `512` to speed up generation and prevent repetitive output.

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
