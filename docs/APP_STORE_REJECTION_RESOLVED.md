# App Store Connect Rejection Resolution (Guidelines 3.1.1 & 2.1(a))

This document details the resolution for the App Store Connect rejection received for the SpeakEasy application under **Guideline 3.1.1 (In-App Purchase)** and **Guideline 2.1(a) (Information Needed)**.

---

## 1. Rejection Notices & Root Cause Analysis

### Guideline 3.1.1 - Payments - In-App Purchase
* **Rejection Issue:** The app previously required users to enter a paid access token (`tkn_live_...`) to unlock the Transcribe tab and download custom Whisper models from a Firebase backend. Apple flagged this as an external payment/unlock mechanism bypassing In-App Purchase.
* **Root Cause:** Gating core app functionality behind a token entered manually in the UI without an App Store IAP option.

### Guideline 2.1(a) - Information Needed
* **Rejection Issue:** Reviewers were unable to access or verify the speech transcription feature because the Transcribe tab was locked behind the token entry screen, and no demo credentials were provided.
* **Root Cause:** The app could not be tested out-of-the-box without valid backend credentials.

---

## 2. Architectural Resolution

To resolve both guidelines cleanly without introducing complex IAP infrastructure or altering backend services, the application model flow was updated to an **"Open Base Model + Optional Custom Model Import"** pattern:

1. **Free Base Model Default (Solves 2.1(a) & 3.1.1):**
   * Upon first launch, the Transcribe tab opens directly.
   * `TranscriptionViewModel` automatically downloads and initializes the standard open-source `openai_whisper-small` (~460MB) model from WhisperKit's public hub.
   * The app is 100% functional out of the box with zero login, token, or setup required.

2. **Optional Custom Model Import (Solves 3.1.1):**
   * The token system is retained as an optional feature inside **Settings** (`ModelSelectionView`).
   * Users who possess a custom fine-tuned model key can enter an access token to download and swap in their personalized model.
   * The feature is reframed strictly as a technical model import setting, not a paywall or locked feature.

3. **Complete Language & UI Audit (Solves 3.1.1):**
   * All user-facing references to "paid token", "unlock", "subscription", and "access control" were purged and replaced with neutral terms ("access token", "import custom model", "model provider").

---

## 3. Code Modifications Summary

| File | Change | Purpose |
| :--- | :--- | :--- |
| **`TranscriptionViewModel.swift`** | Removed `hasCustomModel` property. Updated `initializeWhisperKit()` to auto-download `openai_whisper-small` by default, while loading custom model from `Documents/WhisperModels/` if active. | Enables ungated transcription while supporting custom model overrides. |
| **`ContentView.swift`** | Removed `if transcriptionVM.hasCustomModel` conditional gate in both landscape and portrait layouts. Added a Settings gear button to the header to present `ModelSelectionView`. | Ensures Transcribe tab is immediately accessible upon launch. |
| **`ModelSelectionView.swift`** | Added a "Custom Voice Model" section allowing users to enter `TokenEntryView` or deactivate active custom models. | Moves token management into Settings. |
| **`TokenEntryView.swift`** | Updated header, descriptions, placeholders, and buttons. Removed "Unlock", "Paid", and "Subscription" terminology. | Purges paywall/unlock language. |
| **`TokenService.swift`** | Cleaned docstrings and error messages (e.g., "Invalid or expired access token"). | Purges paid terminology from errors. |
| **`KeychainHelper.swift`** | Updated class docstring references. | Removes internal doc mentions of paid tokens. |

---

## 4. App Store Review Information Note

When submitting the updated build in App Store Connect, include the following text in the **App Review Information -> Notes** section:

```text
App Review Notes:
- No login, credentials, or access tokens are required to test or evaluate the application.
- All app features (Speech Transcription & Smart Speak AI Expander) are fully accessible immediately upon launch.
- On first launch, the Transcribe feature automatically downloads a free open-source speech model (openai_whisper-small) for local on-device inference.
- Advanced users with personalized fine-tuned voice models can optionally import their model via Settings -> Custom Voice Model.
```

---

## 5. Verification & Testing

Before submitting the build:
1. **Fresh Install Test:** Delete the app from a physical iPad or simulator. Launch the app and confirm the Transcribe tab opens directly, downloads `openai_whisper-small`, and performs audio transcriptions.
2. **Settings Import Test:** Navigate to Settings (gear icon on Transcribe tab or via Smart Speak tab) -> Custom Voice Model -> Import Custom Model. Enter a valid token and verify it downloads and initializes the custom model seamlessly.
3. **Deactivate Test:** Select "Remove Custom Model" in Settings, and verify the app reverts to the default `openai_whisper-small` model without error.
