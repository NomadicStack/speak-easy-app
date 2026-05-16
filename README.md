# SpeakEasy (Dysarthria Transcription App)

SpeakEasy is a specialized iOS application designed to provide high-accuracy speech-to-text transcription for individuals with dysarthria. By leveraging **WhisperKit** and Apple's Neural Engine, the app aims to bridge the communication gap for those with slurred or labored speech.

## 🚀 Key Features

- **Local Inference:** All transcription happens on-device using WhisperKit. No audio data ever leaves the device, ensuring total privacy.
- **Accessibility-First Design:** 
  - Massive, high-contrast typography (up to 54pt Bold).
  - Responsive iPad and iPhone layouts.
  - Large touch targets for easier interaction.
- **Contextual Priming:** An "Advanced Context" feature allows users to provide hints (keywords or prompts) to the AI model to improve recognition of slurred speech.
- **Native Integration:** Easily copy or share transcriptions via the native iOS share sheet.
- **Professional UI:** A clean, modern interface branded for a positive user experience.

## 💾 Storage & Privacy

To provide 100% offline transcription and protect user privacy, SpeakEasy bundles a custom fine-tuned AI model directly within the app.

- **App Size:** ~500 MB (base) + 1.4 GB (Gemma 2B)
- **Model Size:** 
    - Transcription: ~468 MB (Custom Whisper)
    - Smart Speak: ~1.4 GB (Gemma 2B IT GPU)
- **Data Privacy:** Because the model is stored locally, your voice recordings are never uploaded to the cloud or shared with third parties.

## 🛠 Tech Stack

- **Language:** Swift 5.10+
- **Framework:** SwiftUI
- **AI Engine:** [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML)
- **Minimum iOS:** 17.0+
- **Recommended Hardware:** iPhone 12+ or iPad with M-series chip (for Apple Neural Engine support).

## 📂 Project Structure

- `DysarthriaApp/`: Source code for the iOS application.
  - `AudioRecorder.swift`: Handles PCM audio capture at 16kHz.
  - `TranscriptionViewModel.swift`: Manages WhisperKit loading and inference.
  - `ContentView.swift`: The main user interface.
- `docs/`: Technical documentation and implementation plans.
  - `design.md`: UI/UX philosophy and architectural goals.
  - `implementation.md`: Detailed implementation log and technical breakdown.

## 🏁 Getting Started

### Prerequisites
- macOS with Xcode 15.0 or later.
- A physical iOS device is highly recommended for performance testing.

### Setup
1. Clone the repository.
2. Open `DysarthriaApp.xcodeproj` in Xcode.
3. Add the WhisperKit dependency via Swift Package Manager:
   - URL: `https://github.com/argmaxinc/argmax-oss-swift`
4. Configure Microphone permissions in `Info.plist` (`NSMicrophoneUsageDescription`).
5. Build and Run (**Cmd + R**).

## 📝 Recent Updates (May 2026)
- **Transcription Stability:** Fixed "No transcription returned" issues by implementing unique recording filenames and disabling problematic `promptTokens`.
- **Improved Silence Handling:** Optimized the model to handle recordings with leading silence more gracefully.
- **Smart Storage Management:** Implemented a "one-in, one-out" cleanup strategy to keep the app lightweight while preserving audio for user corrections.
- **iPad Optimization:** Enhanced audio routing and deactivation for better reliability on iPad hardware.
- **Rebranded to SpeakEasy:** Improved the clinical feel of the app with a friendlier UI.
- **Massive Typography:** Optimized font sizes for visibility and accessibility.
- **Advanced Context:** Added an expandable section for AI prompting.
- **iPad Landscape Support:** Implemented a dedicated sidebar navigation rail and two-column AAC layout for horizontal iPad use.
- **Wrapping Quick Chips:** Upgraded AAC shortcuts to a multi-line wrapping grid in landscape mode for better accessibility.

## ⚖️ License
[Insert License Here - e.g., MIT]

---
*Developed for the Dysarthria Transcription Project.*
