# Mac OS Setup, Compile & Test Guide

The source code for the iOS Dysarthria application is located in the `app/ios-app/DysarthriaApp/` folder. Because creating an Xcode project (`.xcodeproj`) programmatically on Windows is not robust, you need to set up a new Xcode project on your Mac and drag these files in.

Follow these steps on your Mac to build, compile, and test the app:

## Step 1: Copy Code to Your Mac
1. Transfer the entire `app/ios-app/DysarthriaApp/` directory from your Windows machine to your Mac (via Git, USB, or cloud storage).

## Step 2: Create a New Xcode Project
1. Open **Xcode** (ensure it is version 15.0 or later).
2. Go to **File -> New -> Project**.
3. Under the **iOS** tab, select **App** and click **Next**.
4. Fill in the project details:
   - **Product Name:** `DysarthriaApp`
   - **Interface:** `SwiftUI`
   - **Language:** `Swift`
5. Click **Next** and save the project to your preferred location.

## Step 3: Replace the Default Files
1. In Xcode's Project Navigator (left sidebar), delete the default `ContentView.swift` and `DysarthriaApp.swift` files (select them and press Delete -> Move to Trash).
2. Open Finder and locate the `DysarthriaApp` folder you transferred from Windows.
3. Select the 4 Swift files (`AudioRecorder.swift`, `ContentView.swift`, `DysarthriaApp.swift`, `TranscriptionViewModel.swift`).
4. **Drag and drop** them into the `DysarthriaApp` folder in your Xcode Project Navigator.
5. Check the box for **"Copy items if needed"** and ensure your app target is selected under "Add to targets". Click **Finish**.

## Step 4: Add the WhisperKit Dependency
1. In Xcode, go to **File -> Add Package Dependencies...**
2. In the top right search bar, enter the URL for the Argmax open-source Swift repo:
   `https://github.com/argmaxinc/argmax-oss-swift`
3. Click **Add Package** (bottom right).
4. When prompted to select products, check the box for **`WhisperKit`** (or `ArgmaxOSS`) and ensure it is added to your `DysarthriaApp` target. Click **Add Package**.

## Step 5: Configure Permissions (Info.plist)
The app needs permission to access the device's microphone.
1. Click on your project root (`DysarthriaApp`) in the left sidebar.
2. Select your `DysarthriaApp` **Target**, and go to the **Info** tab at the top.
3. Under **Custom iOS Target Properties**, hover over an item and click the **`+`** button.
4. Add the key: **`Privacy - Microphone Usage Description`** (`NSMicrophoneUsageDescription`).
5. Set the Value to: `"This app requires microphone access to record and transcribe dysarthric speech."`

## Step 6: Compile and Test
1. **Select a Target Device:** At the top center of Xcode, select an iPad Simulator (e.g., iPad Pro 11-inch) or an iPhone Simulator, or plug in your physical device.
   *Note: Testing on a physical Apple Silicon device (iPad with M-series chip or iPhone 12+) is highly recommended so that the Apple Neural Engine (ANE) handles inference.*
2. Press **`Cmd + R`** or click the **Play** button (▶️) in the top-left to compile and run the app.
3. **First Run Behavior:** 
   - When the app starts, it will say "Downloading/Loading openai_whisper-small.en...". WhisperKit will automatically download the ~150MB CoreML model over the internet.
   - Once the UI turns green and says "Model ready", tap the **Microphone** icon.
   - Accept the Microphone permission.
   - Speak a sentence, then tap the red stop square.
   - The app will print "Transcribing..." and display your transcription.

## Step 7 (Future): Migrating to the Custom Model
Once your `gemma4-kaggle` fine-tuned model is converted to CoreML (as described in `implementation_plan.md`):
1. Drag the `./Models/CustomDysarthriaModel` folder directly into Xcode.
2. Go to your target's **Build Phases** -> **Copy Bundle Resources** and ensure the folder is listed there.
3. Open `TranscriptionViewModel.swift` and update the initialization block to point to your new bundle path.
