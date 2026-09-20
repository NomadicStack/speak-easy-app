# User Manual: SpeakEasy

SpeakEasy is an accessible communication app designed for people with dysarthria. It uses on-device AI to transcribe speech, expand short phrases into full natural sentences, and collect personalized voice training data.

---

## 1. Getting Started

### Transcription (Voice-to-Text)
- **What it is:** Converts your spoken words into text on the screen using on-device speech recognition.
- **On-Demand Model Download:**
  - Speech transcription requires the Whisper base model (~460 MB). To save storage, this model is **not** downloaded automatically on install.
  - When you first open the **Transcribe** tab without a model, you will see a clean **"Whisper Base Model Required"** card.
  - Tap **"Download Base Model (~460 MB)"** to start downloading. Transcription controls and statistics remain hidden until the model is ready.
  - *(Note: Voice Studio data collection works 100% offline without needing this model.)*
- **Model Badge:**
  - Above the text area, a clean badge displays **`Base`** (when using the standard Whisper base model) or **`Custom`** (when using a personalized fine-tuned model).
- **How to use:** 
  1. Open the **Transcribe** tab.
  2. Tap the large **Blue Microphone**.
  3. Speak clearly. Tap the **Stop** button when finished.
  4. Your text will appear in large, easy-to-read font.
- **Options:** You can **Copy** the text or **Share** it using the icons above the text area.
- **Corrections:** If the transcription is inaccurate, tap the **"Incorrect?" (Pencil)** icon to manually edit the text:
  - **Save:** Tap **"Save Correction"** to store your changes as training data to help improve future recognition accuracy.
  - **Cancel:** Tap **"Cancel"** to discard your edits and return to the original transcription.
  - **Distraction-Free Editing:** In landscape mode, the app automatically hides background buttons and stats while you edit so you have maximum screen space to type.

### Smart Speak (AI Sentences)
- **What it is:** Takes a short phrase (shorthand) and turns it into 3 natural, conversational sentences.
- **How to use:**
  1. Tap the **Smart Speak** tab.
  2. If it's your first time, follow the prompts to download the **AI Brain** (Gemma 4, ~2.6 GB).
  3. Speak a short phrase (e.g., *"thirsty water"*) or tap a **Quick Chip** (e.g., 💧 *thirsty*).
  4. The AI will generate 3 sentence options automatically.
  5. **Listen:** Tap the **Purple Speaker** icon to hear any sentence read aloud.
  6. **Message:** Tap the **Blue Message** icon to send that sentence as an SMS/iMessage.
- **Refinement:** If the sentences aren't quite right, tap the microphone again and speak additional words (e.g., *"juice"*). The app will combine them (*"thirsty water juice"*) and re-generate.

---

## 2. Voice Studio (Personalized Voice Training)

Voice Studio allows you to record speech samples across structured phrase decks. These recordings are packaged with standard metadata to train a custom speech recognition model tailored to your voice.

### Completely Independent & Offline
- Voice Studio works **100% offline** and does **not** require downloading Whisper (~460 MB) or Gemma (~2.6 GB). You can begin recording voice samples immediately after installing the app.

### Training Decks
- **Example Decks:** Pre-loaded with curated phrases for common communication needs:
  - *Daily Essentials* (common requests and needs)
  - *Quick Phrases* (greetings, yes/no, affirmations)
  - *Emergency & Medical* (urgent needs and alerts)
  - *Numbers & Alphabet* (phonetic and numerical clarity)
- **Custom Decks:**
  1. Tap **"New Deck"** or **"Manage Decks"** in Voice Studio.
  2. Enter a title and select an icon from the visual icon picker.
  3. Enter your custom phrases (one per line).
  4. Tap **"Save Deck"**.
- **Deck Status & Locking:**
  - Each deck card displays its total phrases, number of recorded samples, and completion status.
  - Once a deck's recordings are exported for training, the deck is **locked** against editing to ensure the audio files match the training transcript.

### Active Recording Studio
1. **Enter Studio:** Tap any deck to begin a recording session.
2. **Listen to Prompt:** Tap the **"Listen to Prompt"** (speaker) button to hear the phrase spoken aloud via Text-to-Speech before you record.
3. **Record:** Tap the oversized **Blue Microphone** button. The button turns **Red** and displays a live audio level meter. Speak the phrase, then tap the button again to stop.
4. **Review & Redo:**
   - Tap **"Play Back"** to listen to your recorded audio.
   - Tap **"Redo"** if you wish to re-record the phrase.
   - Tap **"Next"** (or **"Finish"** on the last card) to advance.
5. **Fatigue Break Reminder:** To prevent vocal strain during longer sessions, the studio automatically displays a gentle break reminder at the halfway point (*"Halfway there! Take a breath or pause if you feel tired."*).

### Exporting Voice Data
When you complete a deck session, you will see a celebration summary with a list of all recorded phrases and their audio durations.

- **One-Click Email Export:**
  - If you configure a recipient email in Settings, tap **"Send Voice Data via Email"** to instantly open a pre-addressed email draft with your ZIP archive and `metadata.csv` attached.
  - If no recipient is configured, the email draft opens with an empty recipient field so you can enter the address manually.
- **AirDrop & File Saving:**
  - Tap **"AirDrop or Save Archive"** to share the ZIP archive directly via AirDrop, save it to the Files app, or transfer via cloud storage.

### Voice Studio Settings
Tap the **Gear Icon** in the top right of Voice Studio to configure:
- **Data Collection Recipient Email:** The default destination email where voice training archives should be sent (e.g., clinician, researcher, or speech therapist).
- **Speaker Profile:** Your name or participant ID, included in exported filenames and metadata.
- **Caregiver / CC (Optional):** An optional email address to automatically receive a carbon copy (CC) of all exports.

---

## 3. Managing Contacts

You can save common contacts (like Mom, Dad, or a Caregiver) to send messages even faster.

1. In the **Smart Speak** tab, tap the **Purple Brain Icon** (Settings).
2. Expand **"Manage Contacts"**.
3. **Primary Caregiver:** Set the main phone number for fallback messages.
4. **Other Contacts:** Add a Name and Number.
5. **Smart Routing:** If you mention a contact's name in your speech (e.g., *"Dad thirsty"*), the **Blue Message** button will automatically address the text to **Dad**.

---

## 4. Managing Quick Chips

Quick Chips are large tiles that let you quickly add common phrases to your shorthand.

1. In the **Smart Speak** tab, tap the **Purple Brain Icon** (Settings).
2. Expand **"Manage Quick Chips"**.
3. **Add:** Type a new shortcut (like *"🍎 hungry"*) and tap **"Add Shortcut"**.
4. **Edit:** Tap any shortcut name to change its text.
5. **Delete:** Tap the **Red Trash Icon** next to any shortcut to remove it instantly.
6. **Board Layout:** Shortcuts are arranged in a grid like a communication board. Tap the icons to build your message.

---

## 5. Navigation & Layout

### Side Navigation (iPad Landscape)
- When using an iPad in landscape mode, you will see a slim navigation bar on the left with icons.
- **Expand:** Tap the **Menu Icon** (three lines) at the top to see the full names of each tab.
- **Compact:** Tap the menu icon again to shrink the bar and give more space to your text.

### Shorthand & Text Input
- **Portrait:** The input box is slim to leave more room for shortcuts.
- **Landscape:** The input box is taller and will automatically wrap your text as you speak or tap chips.
- **Keyboard Stability:** The app is engineered so opening the on-screen keyboard never dismisses open dialogs, settings sheets, or editors.

---

## 6. Settings & Model Management

Tapping the **Purple Brain Icon** in Smart Speak or accessing the app settings opens your configuration options:

### Speech Recognition Model (Whisper)
- **Base Model Status:** Check whether the base Whisper model is installed.
- **Download Model:** Download the ~460 MB base model on demand if not already present.
- **Remove Base Model:** Tap **"Remove Base Model"** to delete the model file from your device and reclaim ~460 MB of storage space at any time.
- **Custom Model:** Switch to a personalized fine-tuned model if one has been installed on your device.

### AI Brain (Gemma 4)
- **Gemma 4 Model:** View and download the Gemma 4 model (~2.6 GB). Required for Smart Speak sentence expansion.
- **Simulate AI:** Found under **"Advanced"**. Enabling this allows you to test Smart Speak without downloading the 2.6 GB model (useful for testing on simulators or devices with limited storage).
- **Clear Cache:** Deletes downloaded AI models to free up storage space.

### Voice Training & Data Export Configuration
- **Data Collection Recipient Email:** Configure where Voice Studio archives and corrections are sent.
- **Caregiver CC Email:** Configure an optional caregiver email address to be CC'd on all submissions.
- **Pending Live Corrections Batch:**
  - View how many transcription corrections have been saved from the Transcribe tab.
  - Tap **"Send Corrections Batch"** to package and email them in a Whisper-ready format.
  - Tap **"Clear Pending Corrections"** to discard saved corrections.

---

## 7. Feedback & Data Management

You can also submit feedback directly from the **Transcribe** tab:

### Configuring Feedback
1. In the **Transcribe** tab, tap **"Advanced & Stats"**.
2. Expand the **"Feedback Configuration"** section.
3. **Recipient Email:** Set the email address where feedback reports should be sent.
4. **Your Email:** Provide your own email address for follow-up communications.

### Sending Reports & Automatic Cleanup
- When you have saved corrections, a **"Send Feedback Report"** button will appear in the "Advanced & Stats" section.
- Tapping this will open an email draft with a text report and all associated audio files attached.
- **Automatic Cleanup:** To save storage space on your device, all audio files and correction logs are **automatically deleted** after you successfully send the email. This ensures you only send new data in your next report.

---

## 8. Accessibility Tips

- **Large Targets:** Every button is oversized for easy tapping with tremors or limited fine motor control.
- **High-Visibility Navigation:** Navigation tabs are extra large with prominent icons and clear text.
- **Vocal Fatigue Safeguards:** Voice Studio prompts you to rest halfway through recording sessions.
- **Voice-First Design:** In Smart Speak, AI expansion starts automatically when you stop recording—no extra "Expand" button needed.
- **Color Coding:** 
  - **Blue:** Transcription and Voice Studio features.
  - **Purple:** AI Brain and Smart Speak sentence expansion.
  - **Orange:** Fatigue break reminders and pending correction batches.
  - **Green:** Completion confirmations and progression buttons.

