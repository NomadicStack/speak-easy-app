# First-Time App Store Publishing Guide: SpeakEasy

Welcome to your first time publishing an iOS app! This guide is designed to walk you through the entire process of publishing **SpeakEasy** to the Apple App Store, from setting up your developer account to submitting the app for Apple's review.

---

## Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [Step 1: Apple Developer Account Setup](#step-1-apple-developer-account-setup)
3. [Step 2: Certificates, Identifiers, and Profiles](#step-2-certificates-identifiers-and-profiles)
4. [Step 3: Creating the App in App Store Connect](#step-3-creating-the-app-in-app-store-connect)
5. [Step 4: Xcode Project Configuration (on macOS)](#step-4-xcode-project-configuration-on-macos)
6. [Step 5: Archiving and Uploading the App](#step-5-archiving-and-uploading-the-app)
7. [Step 6: TestFlight Beta Testing](#step-6-testflight-beta-testing)
8. [Step 7: Preparing App Store Listing Metadata](#step-7-preparing-app-store-listing-metadata)
9. [Step 8: Final Submission & Review](#step-8-final-submission--review)

---

## 1. Prerequisites
Before beginning, ensure you have:
*   A **Mac computer** running macOS 14.0 or later with **Xcode 15.0** (or newer) installed.
*   A physical **iPad** (running iPadOS 17.0+) for final verification before submission.
*   Your project code transferred from Windows to your Mac (via Git repository or USB drive).
*   An active **Firebase project** (`speak-easy-6eb6e`) upgraded to the **Blaze Plan** (pay-as-you-go) so that the Cloud Functions can serve model downloads.

---

## Step 1: Apple Developer Account Setup

To publish apps on the App Store, you must join the **Apple Developer Program**.

1.  Go to the [Apple Developer Enrollment Page](https://developer.apple.com/programs/enroll/).
2.  Log in with your personal Apple ID (or create a new business Apple ID if publishing as an organization).
3.  Choose your enrollment type:
    *   **Individual / Sole Proprietor:** Fastest setup; your name will appear as the developer on the App Store.
    *   **Organization:** Requires a D-U-N-S Number (company registration id) to verify your legal status; your company name will appear as the developer.
4.  Pay the **$99 USD annual program fee**.
5.  Wait for Apple's verification email (usually takes 24–48 hours for individuals, slightly longer for organizations).

---

## Step 2: Certificates, Identifiers, and Profiles

This step sets up the digital signatures that verify you are the authorized creator of the app. 

> [!TIP]
> **Xcode Automatic Signing:** Xcode can manage all certificates and profiles automatically for you! We highly recommend using Automatic Signing (detailed in Step 4). However, it is important to understand what these assets are.

### A. The Three Key Concepts:
1.  **Certificate:** Identifies *who* you are. A "Distribution Certificate" permits you to submit apps to the App Store.
2.  **App ID (Identifier):** Identifies *what* your app is. It is represented by a unique string called a **Bundle Identifier** (e.g., `com.my.SpeakEasy2`).
3.  **Provisioning Profile:** Bridges your developer certificate with your App ID. It acts as a security pass telling iOS that your specific app is authorized to run.

---

## Step 3: Creating the App in App Store Connect

**App Store Connect** is the portal where you manage your app listings, screenshots, pricing, and reviews.

1.  Go to [App Store Connect](https://appstoreconnect.apple.com) and log in.
2.  Click on **My Apps**, then click the **`+`** button (top-left) and select **New App**.
3.  Fill out the form:
    *   **Platform:** Check **iOS** (which includes iPadOS).
    *   **Name:** `SpeakEasy` (If this name is already taken, you can use a subtitle or variations like `SpeakEasy AAC` or `SpeakEasy Speech Helper`).
    *   **Primary Language:** English (or your preferred language).
    *   **Bundle ID:** Select the App ID matching your project (e.g., `com.my.SpeakEasy2`).
    *   **SKU:** A unique internal ID for your app (e.g., `speakeasy_release_v1`).
    *   **User Access:** Limit access or select "Full Access" (default).
4.  Click **Create**. You will be redirected to the app's details page.

---

## Step 4: Xcode Project Configuration (on macOS)

Now, move to your Mac to configure the code signing settings inside Xcode.

1.  Open **Xcode** on your Mac.
2.  Add your developer Apple ID to Xcode:
    *   Go to **Xcode** > **Settings** (or **Preferences** on older Xcode versions) > **Accounts**.
    *   Click the **`+`** button at the bottom left, select **Apple ID**, and sign in with your developer credentials.
3.  Open the project file `DysarthriaApp.xcodeproj` in Xcode.
4.  In the left sidebar, click the root **`DysarthriaApp`** project node.
5.  Select the **`DysarthriaApp`** target in the center pane, then click the **Signing & Capabilities** tab.
6.  Configure Signing:
    *   Check the box for **Automatically manage signing**.
    *   Under **Team**, select your Apple Developer Team account from the dropdown.
    *   Under **Bundle Identifier**, ensure it matches the identifier you registered (e.g., `com.my.SpeakEasy2`).
7.  Verify Info.plist Permission strings:
    *   Click the **Info** tab in the center pane.
    *   Look for **Privacy - Microphone Usage Description** (`NSMicrophoneUsageDescription`).
    *   Verify the description says: *"This app requires microphone access to record and transcribe dysarthric speech."* (Apple will reject the app if this description is blank or too short).

---

## Step 5: Archiving and Uploading the App

An "Archive" is the final release build of your app packed into an `.ipa` file.

> [!NOTE]
> If you encounter App Store Connect validation or upload errors (such as missing plist keys or invalid bundle structures due to SPM dependencies like `LiteRTLM-Swift`), please consult the [App Store Troubleshooting Guide](file:///Users/dalaimingat/Desktop/mydev/DysarthriaApp/docs/APP_STORE_TROUBLESHOOTING.md).

1.  At the top of Xcode (in the scheme bar next to the Play/Stop buttons), select the active device target.
2.  From the dropdown, select **Any iOS Device (arm64)**. *(You cannot archive if a Simulator is selected)*.
3.  In the menu bar, go to **Product** > **Archive**.
4.  Xcode will compile the code in release mode. This may take a few minutes.
5.  Once compilation finishes, the **Organizer** window will open, showing your new archive.
6.  Click **Distribute App** in the right sidebar.
7.  Select **App Store Connect** and click **Next**.
8.  Select **Upload** (to submit directly) and click **Next**.
9.  Leave the default distribution options checked (Re-sign, strip Swift symbols) and click **Next**.
10. Select your signing method (choose **Automatically Manage Signing**) and click **Next**.
11. Review the details page (verify the app icon displays and the bundle ID is correct) and click **Upload**.
12. Once the upload finishes, a success dialog will appear. Click **Done**.

---

## Step 6: TestFlight Beta Testing

Before releasing the app to the public, use **TestFlight** to test it on a physical device.

1.  Go to [App Store Connect](https://appstoreconnect.apple.com) -> **My Apps** -> select **SpeakEasy**.
2.  Click on the **TestFlight** tab at the top.
3.  Under the **Builds** section (left sidebar), click **iOS**. You should see your uploaded build processing. Once processing is complete (takes 10-20 minutes), the build is ready.
4.  **Set up Internal Testers:**
    *   Click **App Store Connect Users** in the left sidebar.
    *   Click the **`+`** button next to Testers and add your own Apple ID/email.
    *   Install the **TestFlight** app from the App Store on your physical iPad.
    *   Open your email invitation on your iPad, accept the invite, and install the app.
5.  **Test the Model Download:**
    *   Open the newly installed app on your iPad.
    *   Go to the activation screen.
    *   Enter your test token (e.g., `tkn_test_999` if running the emulator or your production test token).
    *   Verify that the download starts, the progress bar moves, and the models unzip and load successfully.

---

## Step 7: Preparing App Store Listing Metadata

While the build is in TestFlight, fill out the App Store listing information in App Store Connect.

### A. Screenshots (Crucial Step)
You must upload screenshots of your app running on real devices. Since SpeakEasy is an iPad-first app:
*   You must provide screenshots for the **12.9-inch iPad Pro (6th Gen)** (2048 x 2732 or 2732 x 2048).
*   You must also provide screenshots for the **12.9-inch iPad Pro (2nd Gen)** (2048 x 2732).
*   *Tip:* You can capture these screenshots by running the app in the iPad simulator and pressing **Cmd + S** to save screenshots to your Mac desktop.

### B. Promotional Information
*   **Name:** `SpeakEasy`
*   **Subtitle:** `Dysarthria Speech Helper & AAC` (Up to 30 characters).
*   **Description:** Provide a detailed description explaining what the app does. Mention that transcription and AI processing are completed 100% on-device for user privacy.
*   **Keywords:** `speech, dysarthria, AAC, accessibility, voice assistant, text-to-speech, speech therapy`
*   **Support URL:** A simple webpage where users can get help or contact support (e.g., a GitHub Pages link).

### C. App Privacy Questionnaire (Mandatory)
Apple requires you to declare what data your app collects. Fill out the questionnaire as follows:
1.  **Data Collection:** Select **"No, we do not collect data from this app"**.
2.  **Privacy Policy URL:** Provide a URL to your privacy policy.
    *   *Drafting Tip:* State clearly: *"SpeakEasy records audio to perform local on-device speech-to-text transcription. Audio files and transcribed text are processed directly on the iPad's hardware and are never uploaded, collected, or transmitted to any remote servers. The app operates 100% offline."*

---

## Step 8: Final Submission & Review

Once testing is successful and metadata is complete, submit the app for review.

1.  In App Store Connect, go to **App Store** > **1.0 Prepare for Submission** (left sidebar).
2.  Scroll down to the **Build** section.
3.  Click **Select a build before you submit**, choose the build you uploaded and tested in TestFlight, and click **Done**.
4.  **App Review Information:**
    *   **Contact Information:** Enter your name and phone number.
    *   **Sign-in Information:** Since the app requires a token, check **Sign-in required** and provide a valid test token (e.g. `tkn_live_test`) so the Apple App Review team can log in, download the models, and test the transcription.
    *   **Notes:** Add a note explaining: *"This application utilizes local on-device machine learning models (WhisperKit and Gemma) for accessibility. Once the user enters the provided token, the app downloads a ~500MB CoreML model zip file from the backend and initializes locally on the hardware. Please use the provided test token to activate the voice model."*
5.  Click **Save**, then click **Add for Review** (top right).
6.  Click **Submit to App Review**.

Apple's review team will test your app. The review process typically takes **24 to 48 hours**. You will receive an email once the app is approved or if they request changes!
