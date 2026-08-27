# Design Document: Smart Home Intent Parsing (SpeakEasy)

## Problem Statement

Traditional voice assistants (Siri, Alexa, Google Assistant) are notoriously difficult for individuals with dysarthria to use. These systems rely on rigid grammatical structures and standard acoustic models. If a user pauses too long, stutters, or uses non-standard phrasing (e.g., "turn... uh... light off please kitchen"), the assistant will fail, often resulting in frustrating loops of "I didn't quite catch that."

By combining our highly accurate dysarthria-tuned WhisperKit transcription with the reasoning capabilities of Gemma 4 2B, SpeakEasy can bypass traditional voice assistants entirely. We can extract structured intent from messy, fragmented speech and execute the command directly via iOS HomeKit.

---

## Feature Overview

1. **Record:** The user speaks a natural or fragmented command into SpeakEasy.
2. **Transcribe:** WhisperKit handles the dysarthric acoustic patterns and outputs a raw text string.
3. **Parse Intent:** The raw text is passed to Gemma 4 2B on-device. Gemma acts as a Natural Language Understanding (NLU) engine, mapping the messy text into a strict JSON intent payload.
4. **Execute:** The app reads the JSON and silently executes the command using the `HomeKit` framework or iOS App Intents.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Audio       │────▶│  WhisperKit  │────▶│  Gemma 4 2B      │────▶│  Apple       │
│  Input       │     │  Raw Text    │     │  (JSON Output)   │     │  HomeKit     │
└──────────────┘     └──────────────┘     └──────────────────┘     └──────────────┘
```

---

## Architecture & Integration

### New Components

```
DysarthriaApp/
├── HomeAutomationViewModel.swift     // NEW — Orchestrates Intent Extraction and Execution
├── IntentParser.swift                // NEW — Handles JSON parsing from LLM output
├── HomeKitService.swift              // NEW — Wrapper for HMHomeManager
└── ...
```

### 1. `HomeKitService.swift`

This service interfaces directly with the user's Apple Home environment. It searches for devices matching the extracted room and device type.

```swift
import HomeKit

class HomeKitService: NSObject, HMHomeManagerDelegate {
    let homeManager = HMHomeManager()
    
    func execute(intent: SmartHomeIntent) async throws {
        guard let primaryHome = homeManager.primaryHome else {
            throw HomeKitError.noHomeConfigured
        }
        
        // Find matching room
        guard let room = primaryHome.rooms.first(where: { 
            $0.name.lowercased().contains(intent.room) 
        }) else { throw HomeKitError.roomNotFound }
        
        // Find matching accessory in that room
        guard let accessory = room.accessories.first(where: { 
            $0.name.lowercased().contains(intent.device) 
        }) else { throw HomeKitError.deviceNotFound }
        
        // Execute Action (e.g., Turn On/Off)
        if let characteristic = findPowerCharacteristic(in: accessory) {
            let targetState = intent.action == "turn_on" ? true : false
            try await characteristic.writeValue(targetState)
        }
    }
    
    // ... characteristic helper methods ...
}
```

### 2. `IntentParser.swift`

This struct defines the expected schema for Gemma to output.

```swift
struct SmartHomeIntent: Codable {
    let action: String    // e.g., "turn_on", "turn_off", "set_temperature", "unlock"
    let device: String    // e.g., "lights", "tv", "thermostat", "door_lock"
    let room: String      // e.g., "kitchen", "living room", "bedroom"
    let value: Int?       // Optional, e.g., 68 (for temperature)
}
```

---

## Prompt Engineering

To use an LLM as a reliable programmatic parser, we must use a highly restrictive prompt that forces a strict JSON schema.

```swift
func buildIntentPrompt(transcription: String) -> String {
    """
    You are a smart home intent parser. Read the user's messy transcription \
    and extract their intent into a strict JSON format.
    
    Valid actions: "turn_on", "turn_off", "set_temperature", "unlock"
    
    You must return ONLY valid JSON matching this schema:
    {
      "action": "string",
      "device": "string",
      "room": "string",
      "value": integer or null
    }
    
    Do not include markdown blocks, explanations, or any other text.
    
    Transcription: "\(transcription)"
    """
}
```

### Examples

| Raw Transcription | Gemma Output (JSON) |
|:---|:---|
| `"turn uh light on please kitchen"` | `{"action": "turn_on", "device": "lights", "room": "kitchen", "value": null}` |
| `"can you make it colder in the bedroom"` | `{"action": "set_temperature", "device": "thermostat", "room": "bedroom", "value": 68}` |
| `"shut the living room tv off it's too loud"` | `{"action": "turn_off", "device": "tv", "room": "living room", "value": null}` |

---

## User Flow & UI Design

1. **Input:** The user is on the main transcription screen and records their voice.
2. **Recognition:** The app identifies action verbs ("turn", "shut", "open") in the raw WhisperKit text and subtly surfaces a "Smart Home Action?" button.
3. **Extraction:** User taps the button. A glassmorphic modal appears indicating "Processing Intent..." as Gemma runs on the GPU.
4. **Execution:** The JSON is parsed, and the HomeKit action fires.
5. **Visual Feedback:** A HomeKit-style tile (e.g., "Kitchen Lights") briefly appears on screen, transitioning from a dark state to a bright active state to confirm the physical action took place.

### Accessibility Considerations
- **Forgiving Input:** Users do not need to memorize specific trigger phrases (like "Hey Siri, set Kitchen Lights to 100%"). They can speak naturally and conversationally.
- **Visual State Confirmation:** Relying purely on audio confirmation (Siri saying "Done") can be disorienting. Large, colorful UI tiles confirm the app correctly understood and executed the command.
- **Fallback Editing:** If the intent parsing fails or misidentifies the room, the NLU output can be presented to the user to manually correct via simple dropdowns before execution.
