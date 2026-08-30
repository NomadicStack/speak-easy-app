# Custom Model Import & Access Token Setup Guide

This guide details how to configure, deploy, and operate the Custom Model Import system for the SpeakEasy dysarthria iPad application. By default, SpeakEasy operates out of the box using the free open-source `openai_whisper-small` model. Users who have had custom speech models trained and fine-tuned for their voice can enter an access token via Settings to download and swap in their personalized WhisperKit model.

---

## 1. Architecture Overview

```mermaid
sequenceDiagram
    participant User as iPad User
    participant iOS as iOS App (SpeakEasy)
    participant KC as iOS Keychain
    participant CF as Cloud Function (GET /downloadModel)
    participant FS as Firestore (paid_tokens)
    participant GCS as Cloud Storage (gs://...)

    Note over iOS: Default: Runs openai_whisper-small out-of-the-box
    User->>iOS: Enter Access Token in Settings
    iOS->>CF: Request with Authorization: Bearer <token>
    CF->>FS: Query document named <token>
    alt Token Invalid/Revoked
        FS-->>CF: Return null or inactive
        CF-->>iOS: HTTP 403 Forbidden
        iOS->>User: Show "Invalid or expired access token"
    else Token Active
        FS-->>CF: Return token metadata (active)
        CF->>GCS: Check file exists & generate signed URL (5m expiry)
        CF-->>iOS: HTTP 200 (downloadUrl, modelName, fileSize)
        iOS->>KC: Securely persist token
        iOS->>GCS: Download Model ZIP archive (progress tracked)
        GCS-->>iOS: ZIP file downloaded
        iOS->>iOS: Extract via ZIPFoundation to Documents/WhisperModels/
        iOS->>iOS: Purge base model cache (Conserves disk space)
        iOS->>iOS: Initialize WhisperKit with Custom Model
        iOS->>User: Display "Active: Custom (ModelName)" Badge
    end
```

---

## 2. Firebase Backend Setup

All backend configuration and source code are located in the `backend/` directory.

### Prerequisites
- Node.js 18 or 20 installed.
- Firebase CLI installed (`npm install -g firebase-tools`).

### Deployment Steps
1. Log in to Firebase:
   ```bash
   firebase login
   ```
2. Link the project (replace with your Firebase project ID):
   ```bash
   firebase use --add YOUR_PROJECT_ID
   ```
3. Install Cloud Function dependencies:
   ```bash
   cd backend/functions
   npm install
   ```
4. Deploy security rules and functions:
   ```bash
   cd backend
   firebase deploy --only firestore:rules,functions
   ```

---

## 3. Database Schema

Tokens are stored in the Firestore collection `paid_tokens`. The document ID should match the token string for fast lookup.

### Firestore Document Structure (`paid_tokens/{token}`)

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `paid_token` | String | (Optional fallback) The token string | `"tkn_live_789xYz..."` |
| `token_status` | String | State of token. Must be `"active"` to download | `"active"` or `"revoked"` |
| `model_storage_path` | String | GCS URI or relative path to the zipped model | `"gs://speakeasy-models/models/user_abc123.zip"` |
| `model_name` | String | Friendly name for the user's voice model | `"John-Doe-Dysarthria-v1"` |

---

## 4. Preparing & Uploading Models

Custom models fine-tuned for a specific user must be packed into a ZIP archive and uploaded to Cloud Storage before the user can activate their token.

### Packing WhisperKit Models
Ensure the ZIP contains the model folder structure. The model configuration file `config.json` must be present.

Example directory structure inside the ZIP:
```text
CustomDysarthriaModel/
  ├── config.json
  ├── vocabulary.txt
  ├── MelSpectrogram.mlmodelc/
  ├── AudioEncoder.mlmodelc/
  └── TextDecoder.mlmodelc/
```
*Note: If the zip structure is flattened (files at root), the app will automatically handle it and initialize correctly.*

Compress the folder:
```bash
zip -r John-Doe-Dysarthria-v1.zip CustomDysarthriaModel/
```

### Uploading to Storage
Upload the resulting ZIP file to your Cloud Storage bucket (e.g., to a `models/` folder). Note the storage path, and set the corresponding `model_storage_path` in the Firestore token document.

---

## 5. iOS Integration (Part 2 Tasks on macOS)

When moving to macOS to build and run the iPad app, perform the following integration steps:

### A. Add ZIPFoundation SPM Dependency
ZIPFoundation is used to extract the model archive locally:
1. Open `DysarthriaApp.xcodeproj` in Xcode.
2. Go to **File** > **Add Packages...**
3. Paste the URL: `https://github.com/weichsel/ZIPFoundation.git`
4. Select the latest version and add it to the `DysarthriaApp` target.

### B. Configure Backend URL
In `DysarthriaApp/TokenService.swift`, modify the `backendUrlString` property with your live Firebase Cloud Function URL:
```swift
private let backendUrlString = "https://<region>-<project-id>.cloudfunctions.net/downloadModel"
```

### C. Compile and Verify
1. Build the application in Xcode.
2. On launch, the **Transcribe** tab immediately opens and initializes the default `openai_whisper-small` model.
3. Open **Settings** (gear icon) -> **Speech Recognition Model** -> **Import Custom Model**.
4. Enter a valid token created in Firestore and tap **Import & Download Model**.
5. Verify the download progress bar, archive extraction, and that the purple badge `✨ Custom (ModelName)` appears.

---

## 6. Token Revocation & Deactivation

- To temporarily deactivate access on future installs, change `token_status` in Firestore to `"revoked"` or `"disabled"`.
- To delete a user's custom model and revert to the default open-source model:
  - Inside the app, navigate to **Settings** -> **Speech Recognition Model** -> tap **Revert to Base Model (Whisper Small)**.
  - This deletes the token from Keychain, purges `Documents/WhisperModels/`, and automatically re-downloads/activates the base `openai_whisper-small` model.

---

## 7. Production Model Provisioning & Token Creation Walkthrough

Follow these visual steps in the Firebase Console to issue a new model to a user:

### Step A: Upload the ZIP Model
1. Go to the [Firebase Storage Console](https://console.firebase.google.com/project/speak-easy-6eb6e/storage).
2. Inside your default storage bucket, click **Create folder** and name it `models`.
3. Enter the `models` folder.
4. Click **Upload file** and select the custom user's Whisper model ZIP archive (e.g. `john_doe_whisper.zip`).
5. Once uploaded, the file path is: `models/john_doe_whisper.zip`.

### Step B: Create the Token in Firestore
1. Go to the [Firestore Database Console](https://console.firebase.google.com/project/speak-easy-6eb6e/firestore).
2. If the collection does not exist yet, click **Start collection** and name it `paid_tokens`.
3. Click **Add document** and set:
   * **Document ID**: `tkn_live_doe789` *(This is the token string you will email to the patient).*
   * **Fields**:
     * `token_status` (String): `active`
     * `model_storage_path` (String): `models/john_doe_whisper.zip` *(Relative or full gs:// paths are both supported).*
     * `model_name` (String): `John Doe Voice Profile` *(This friendly name displays in the app on download completion).*

---

## 8. Future Maintenance & Operations Guide

This section outlines standard procedures for maintaining the access control system and performing updates.

### A. Releasing Voice Model Updates (v2, v3, etc.)
If a patient's model is retrained and a new version needs to be deployed:
1. Package and upload the new ZIP file to Cloud Storage at a new path (e.g., `models/john_doe_whisper_v2.zip`).
2. Open the Firestore document for the user's token and update:
   * `model_storage_path` to the new path (`models/john_doe_whisper_v2.zip`).
   * `model_name` to reflect the new version (e.g. `John Doe Profile v2`).
3. To force the user's iPad to fetch the new model:
   * Ask the user/caregiver to tap **Deactivate and Delete Model Data** at the bottom of the active token screen.
   * Re-enter the same token. The app will immediately pull and unzip the new `v2` model.

### B. Revoking Subscriber Access
* To disable access, set `token_status` in the Firestore document to `"revoked"` or `"inactive"`.
* **Note**: Because the app runs offline-first for accessibility safety, the local model remains functional on the user's device even after a token is revoked. However, the user will not be able to re-download or activate the model on a new device.

### C. Updating Firebase Cloud Function Packages
To keep the backend secure and upgrade dependencies:
1. Navigate to the functions directory:
   ```bash
   cd backend/functions
   ```
2. Update packages to the latest compatible versions:
   ```bash
   npm install --save firebase-functions@latest firebase-admin@latest
   ```
3. Redeploy the functions to production:
   ```bash
   firebase deploy --only functions --force
   ```

### D. Billing Alerts & Cost Monitoring
To ensure your production costs stay within the free tier limits:
1. Go to the [Google Cloud Billing Console](https://console.cloud.google.com/billing).
2. Go to **Budgets & Alerts** and click **Create Budget**.
3. Set a threshold budget (e.g., $10.00/month) and configure email notifications to alert you if the resource downloads or Firestore reads spike abnormally.


---

## 9. Troubleshooting Common Production Issues

This section documents common deployment issues encountered during live testing and their solutions.

### Issue A: Client Receives HTTP 403 Forbidden (Google Frontend Block)
* **Symptom**: The client receives an HTML page instead of JSON, stating: *"Your client does not have permission to get URL / from this server."*
* **Cause**: The Cloud Function/Cloud Run service was deployed as private (requiring IAM authentication) instead of allowing public invocations.
* **Solution**:
  1. Open the [Google Cloud Run Console](https://console.cloud.google.com/run).
  2. Select the service named `downloadModel`.
  3. Under the **Permissions** tab, click **Add Principal** (or **Grant Access**).
  4. In **New principals**, enter `allUsers`.
  5. In **Role**, search for and select **Cloud Run Invoker** (`roles/run.invoker`).
  6. Save and confirm the prompt to make the resource public.

### Issue B: Client Receives HTTP 500 Internal Server Error (Failed to Generate Signed URL)
* **Symptom**: App throws a server error (HTTP 500). Cloud Function logs show `Permission 'iam.serviceAccounts.signBlob' denied` or `Failed to generate download URL`.
* **Cause**: The service account running the Cloud Function does not have permission to cryptographically sign GCS URLs.
* **Solution**:
  1. Open the [Google Cloud IAM Console](https://console.cloud.google.com/iam-admin/iam).
  2. Identify the service account running your function:
     * **2nd Gen Functions (Cloud Run)**: Default Compute Engine service account (`[PROJECT_NUMBER]-compute@developer.gserviceaccount.com`).
     * **1st Gen Functions**: App Engine default service account (`[PROJECT_ID]@appspot.gserviceaccount.com`).
  3. Click **Edit (pencil icon)** next to that service account.
  4. Click **Add Another Role** and select **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`).
  5. Click **Save** (allow 1–2 minutes for IAM propagation).



