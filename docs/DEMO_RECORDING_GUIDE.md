# SpeakEasy — iPad Demo Recording Guide (Landscape)

This document provides a shot-by-shot script for **7 distinct demo recordings** of the SpeakEasy app on an iPad in **landscape mode**. These recordings showcase the core features, progressing from basic navigation and transcription to advanced AI intent interpretation using Smart Speak.

---

## Pre-Recording Checklist

- [ ] **iPad in Landscape** — lock orientation before launching.
- [ ] **Second Device Ready** — a phone or laptop with dysarthria audio recordings queued up, speaker facing the iPad mic.
- [ ] **AI Brain Downloaded** — Gemma 4 model downloaded and selected (or "Simulate AI" enabled).
- [ ] **User Name Set** — Settings → Advanced → Developer Settings → e.g., `Alex`.
- [ ] **Quiet Room** — minimize background noise for optimal WhisperKit transcription.
- [ ] **Screen Recording On** — iPad Control Center or QuickTime via Mac.
- [ ] **Do Not Disturb** — enabled to prevent notifications.

---

## The 7 Demo Recordings

### Recording 01: App Tour, Navigation & Layout
**Filename:** `01-app-tour.mp4`  
**Goal:** Showcase the accessible landscape layout, collapsible sidebar, navigate both tabs, and give a quick peek at the settings.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 1.1 | Tap the SpeakEasy icon. App opens in landscape. | **Transcribe** tab is active. A slim **sidebar rail** on the left (icon-only, ~100pt). Main content area shows the large transcription view. |
| 1.2 | Tap the **Menu icon** (☰) at the top of the rail. | Rail **expands** with a spring animation revealing labels: "SpeakEasy", "Transcribe", "Smart Speak". |
| 1.3 | Tap the **Smart Speak** label/icon on the rail. | Switches to Smart Speak — the 2-column layout appears (left: input + chips, right: expanded options). |
| 1.4 | Tap the **Purple Brain Icon** (top-right of the left column). | **Settings sheet** slides up. |
| 1.5 | Briefly scroll to show the sections (AI Brain, Contacts, Shortcuts, Advanced) without interacting deeply. | A quick visual overview of the app's configuration capabilities. |
| 1.6 | Tap **"Done"**. Tap **Transcribe** on the rail, then collapse the rail (☰). | Settings closes, returns to the clean Transcribe view. |

---

### Recording 02: Basic Transcription
**Filename:** `02-transcription.mp4`  
**Goal:** Demonstrate the core speech-to-text accuracy by transcribing 2 sample dysarthria audio recordings from a second device.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 2.1 | From the Transcribe view, tap the **Blue Microphone** button. | Button turns **red**. |
| 2.2 | **Play dysarthria recording #1** from the second device near the iPad mic. Tap Stop. | "Transcribing..." spinner appears. The transcription displays in **64pt bold** text. |
| 2.3 | Tap **Record** again. **Play dysarthria recording #2**. Tap Stop. | The second transcription is **appended** directly below the first. |
| 2.4 | Tap the **"Share"** button (square-and-arrow-up icon) in the middle row. | The iOS Share Sheet appears over the text. Dismiss it. |

---

### Recording 03: Transcription Correction & Feedback Loop
**Filename:** `03-transcription-correct.mp4`  
**Goal:** Show how users can correct misheard words in a distraction-free mode and send a feedback report to improve the model.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 3.1 | With a transcription already on screen, tap **"Incorrect?"** (pencil icon). | UI enters **Focus Editing Mode**. Sidebar and action buttons hide; the text editor expands to full width with no margins. |
| 3.2 | Edit the text using the keyboard to correct a word. Tap **"Save Correction"**. | Corrected text is saved, and the standard UI reappears smoothly. |
| 3.3 | Tap the **"Advanced & Stats"** disclosure group. Expand **"Feedback Configuration"**. | Shows Usage Stats (Total Transcriptions, Corrections) and email fields. |
| 3.4 | Tap **"Send Feedback Report"**. | A Mail composer opens with pre-filled text and the audio `.wav` files attached. Dismiss the composer. |

---

### Recording 04: Smart Speak — Voice Shorthand, TTS & Messaging
**Filename:** `04-SmartSpeak-transcribe-gen-message-tts-sms.mp4`  
**Goal:** Demonstrate transcribing dysarthria audio to generate 3 polished sentences, then reading the result out loud and sending an SMS easily.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 4.1 | In Smart Speak, tap the **Blue Microphone**. Play a dysarthric recording. Tap Stop. | WhisperKit transcribes the shorthand into the left box. AI automatically generates 3 sentence cards on the right. |
| 4.2 | Tap the **Purple Speaker** icon on one of the result cards. | The sentence is **read aloud** via Text-to-Speech. |
| 4.3 | Tap the **Blue Message** icon on another card. | The Messages composer opens, pre-filled with the AI-generated sentence. Dismiss it. |

---

### Recording 05: Smart Speak — Quick Chips & Smart Contact Routing
**Filename:** `05-SmartSpeak-transcribe-quickchips-gen-message-sms.mp4`  
**Goal:** Show how to add a contact, create a Quick Chip for them, and use chips to generate sentences and automatically route an SMS.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 5.1 | Open Settings (Brain Icon). Expand **"Manage Contacts"**. | Add a contact: Name = `Dad`, Number = `555-0101`. |
| 5.2 | Expand **"Manage Quick Chips"**. Add a shortcut: `👨 Dad`. Tap Done. | The new "👨 Dad" tile appears in the Quick Chips grid. |
| 5.3 | Tap a **💧 thirsty** chip, then tap the new **👨 Dad** chip. | Shorthand builds to "💧 thirsty 👨 Dad". AI generates sentences addressing Dad (e.g., "Hey Dad, could you bring me some water?"). |
| 5.4 | Tap the **Blue Message** icon on the best result. | The Messages composer opens with Dad's number **automatically filled** in the "To:" field along with the text. Dismiss it. |

---

### Recording 06: Smart Speak — Combining Words & Emojis
**Filename:** `06-SmartSpeak-quickchip-emoji-and-word-gen-message-tts.mp4`  
**Goal:** Show the AI interpreting a mix of spoken words and pure emoji chips to easily generate complex sentences, then reading them aloud.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 6.1 | Open Settings. Add two new quick chips: `🏀` and `⚽️`. Tap Done. | The emoji chips appear in the grid. |
| 6.2 | Tap the mic, speak or play the word: *"play"*. Tap Stop. | Shorthand box shows: "play". |
| 6.3 | Tap the `🏀` chip and then the `⚽️` chip. | Shorthand updates to: "play 🏀 ⚽️". AI interprets the combo and generates sentences like: "Do you want to play basketball or soccer?". |
| 6.4 | Tap the **Purple Speaker** on the best result. | TTS reads the generated sentence aloud. |

---

### Recording 07: Smart Speak — Pure Emoji Interpretation
**Filename:** `07-SmartSpeak-quickchip-emoji-gen-message-tts.mp4`  
**Goal:** Demonstrate the AI's ability to understand intent purely from emoji Quick Chips, generating text without any spoken words.

| Step | Action | What the Viewer Sees |
|:-----|:-------|:---------------------|
| 7.1 | Clear the shorthand. Tap an existing **😴 tired** chip, then a **📺 watch** chip. | Shorthand input shows only: "😴 tired 📺 watch". |
| 7.2 | Wait for AI generation. | The AI interprets the pure emoji sequence and generates natural options (e.g., "I'm feeling tired. Can we just watch something on TV?"). |
| 7.3 | Tap the **Purple Speaker** on a result. | TTS reads the sentence aloud, proving full intent translation from emojis to speech. |
