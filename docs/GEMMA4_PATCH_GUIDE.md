# Gemma 4 iPad Loading Patch Guide

This document records the manual patch required to run the **Gemma 4 E2B IT** model on iPadOS using the `LiteRTLM-Swift` library.

## 🚨 The Problem
When attempting to load the `.litertlm` bundle for Gemma 4, the app would crash or fail to initialize with this error in the console:

`INVALID_ARGUMENT: The Vision Encoder model must have exactly one signature but got 3`

### Root Cause
Gemma 4 is a multimodal model (Text, Vision, Audio). Its `.litertlm` file contains 3 different vision encoder signatures. However, the current LiteRT-LM engine expects exactly **one** vision signature if the vision backend is initialized. The library was automatically passing `"cpu"` to all backends, triggering this mismatch.

## ✅ The Solution (The Patch)
Since this app currently uses Gemma 4 for **text-only** AAC expansion, we can bypass the crash by explicitly disabling the multimodal (Vision/Audio) loaders.

### Patch Instructions
If you perform a "Reset Package Cache" in Xcode, this patch will be lost. To re-apply it:

1.  Locate the library source in your **DerivedData**:
    `[Xcode-DerivedData]/SourcePackages/checkouts/LiteRTLM-Swift/Sources/LiteRTLMSwift/LiteRTLMEngine.swift`
2.  Find the `load()` method and the call to `litert_lm_engine_settings_create`.
3.  Change the vision and audio backend parameters from `backendStr` to `nil`.

**Original Code:**
```swift
guard let settings = litert_lm_engine_settings_create(
    path, backendStr, backendStr, backendStr
)
```

**Patched Code:**
```swift
guard let settings = litert_lm_engine_settings_create(
    path, backendStr, nil, nil // Bypasses vision signature mismatch
)
```

## 🛠 Hardware Note
This model requires significant memory.
*   **Device:** iPad Pro M1/M2/M4 or iPad Air M1/M2 (minimum 8GB RAM).
*   **Entitlement:** The `increased-memory-limit` capability must be enabled in `DysarthriaApp.entitlements`.
*   **RAM:** Loading uses ~4GB of RAM. If the app is killed immediately after "Loading model...", ensure no other heavy apps are open.
