# Gemma 4 iPad Loading Patch Guide (Legacy Reference)

> [!NOTE]
> **Superseded by Official Google LiteRT-LM SDK:**
> As of the migration to Google's official [`google-ai-edge/LiteRT-LM`](https://github.com/google-ai-edge/LiteRT-LM) Swift API, this manual patch is no longer necessary. The official `EngineConfig` architecture natively configures text and multimodal backends cleanly without requiring manual DerivedData source patching.

This document records the historical manual patch previously required to run the **Gemma 4 E2B IT** model on iPadOS when using the legacy `LiteRTLM-Swift` community library.

## 🚨 The Problem (Historical)
When attempting to load the `.litertlm` bundle for Gemma 4 with the legacy wrapper, the app would crash or fail to initialize with this error in the console:

`INVALID_ARGUMENT: The Vision Encoder model must have exactly one signature but got 3`

### Root Cause
Gemma 4 is a multimodal model (Text, Vision, Audio). Its `.litertlm` file contains 3 different vision encoder signatures. However, the legacy wrapper was automatically passing `"cpu"` to all multimodal backends, triggering this mismatch.

## ✅ The Solution (Historical Legacy Patch)
When previously using `LiteRTLM-Swift` for **text-only** AAC expansion, the crash was bypassed by explicitly disabling multimodal loaders in DerivedData:

1.  Locate the library source in your **DerivedData**:
    `[Xcode-DerivedData]/SourcePackages/checkouts/LiteRTLM-Swift/Sources/LiteRTLMSwift/LiteRTLMEngine.swift`
2.  Find the `load()` method and the call to `litert_lm_engine_settings_create`.
3.  Change the vision and audio backend parameters from `backendStr` to `nil`.

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
