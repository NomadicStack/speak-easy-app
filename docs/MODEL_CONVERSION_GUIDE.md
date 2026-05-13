# Custom Model Conversion Guide

This document details the process for converting fine-tuned Whisper weights to CoreML for use in the SpeakEasy iOS app.

## 🛠 Environment Setup

The conversion requires a stable Python environment. Avoid experimental versions (e.g., Python 3.14+) as key dependencies like `torch` and `coremltools` may not be compatible.

1.  **Install Python 3.12:**
    ```bash
    brew install python@3.12
    ```

2.  **Create and Activate Virtual Environment:**
    ```bash
    /opt/homebrew/bin/python3.12 -m venv venv312
    source venv312/bin/activate
    ```

3.  **Install Dependencies:**
    The `whisperkittools` package is currently installed directly from the Argmax GitHub repository:
    ```bash
    pip install git+https://github.com/argmaxinc/whisperkittools.git
    ```

## 📝 Pre-Conversion Fixes

Before converting, ensure the model configuration is optimized for CoreML inference.

### 1. Enable KV Caching
The Text Decoder accuracy often fails (0% accuracy) if `use_cache` is disabled.
*   **File:** `model/config.json`
*   **Change:** Set `"use_cache": true`

## 🚀 Conversion Process

Use the `whisperkit-generate-model` CLI to perform the conversion.

```bash
# Generate the CoreML artifacts
whisperkit-generate-model \
    --model-version ./model \
    --output-dir ./Models/CustomDysarthriaModel
```

### Conversion Artifacts
The tool generates a hidden folder `._model` containing:
*   `AudioEncoder.mlmodelc`
*   `TextDecoder.mlmodelc`
*   `MelSpectrogram.mlmodelc`

## 📦 Xcode Integration

1.  **Prepare the Bundle Folder:**
    Move the compiled components and metadata into a clean folder for Xcode, then **delete the hidden `._model` folder** to avoid doubling the app's size on the device.
    ```bash
    mkdir -p Models/CustomDysarthriaModel
    cp -r Models/CustomDysarthriaModel/._model/*.mlmodelc Models/CustomDysarthriaModel/
    cp model/config.json model/tokenizer.json model/tokenizer_config.json Models/CustomDysarthriaModel/
    
    # CRITICAL: Delete the hidden folder to avoid duplicating 400MB+ in the app bundle
    rm -rf Models/CustomDysarthriaModel/._model
    ```

2.  **Add to Xcode:**
    Drag the `CustomDysarthriaModel` folder into the Xcode project navigator. Ensure "Copy Bundle Resources" is checked.

3.  **App Implementation:**
    The app loads the model using `WhisperKitConfig`:
    ```swift
    let modelURL = Bundle.main.url(forResource: "CustomDysarthriaModel", withExtension: nil)!
    let config = WhisperKitConfig(
        model: "CustomDysarthriaModel",
        modelFolder: modelURL.deletingLastPathComponent().path,
        tokenizerFolder: modelURL
    )
    ```

## 🔄 Testing & Swapping Models

To compare different model versions, you can swap the contents of the `CustomDysarthriaModel` folder.

### 1. Create a Backup
Always backup the current model before replacing it.
```bash
mkdir -p model_backups
cp -r DysarthriaApp/Models/CustomDysarthriaModel model_backups/CustomDysarthriaModel_v1
```

### 2. Swap Models
To switch to a different version:
```bash
# Clear active model
rm -rf DysarthriaApp/Models/CustomDysarthriaModel/*

# Restore from backup
cp -r model_backups/CustomDysarthriaModel_v2/* DysarthriaApp/Models/CustomDysarthriaModel/
```

## 🧹 Cleanup & Optimization

### Avoiding Redundant Copies
The conversion process can leave large files in multiple locations. To save disk space:
1.  **Delete the hidden `._model` folder:** As noted above, always remove this after copying to prevent doubling the app bundle size.
2.  **Remove root-level duplicates:** Once you have moved the `CustomDysarthriaModel` folder into the `DysarthriaApp/Models/` project directory, you should delete any copies remaining at the project root:
    ```bash
    # Remove the temporary conversion output to free up ~500MB
    rm -rf ./Models
    ```

## ✅ Verification
Always ensure the conversion logs show:
*   `torch2coreml PSNR > 35`
*   `argmax accuracy = 100%`
*   `ANE support coverage = 100%` (for Audio Encoder)
