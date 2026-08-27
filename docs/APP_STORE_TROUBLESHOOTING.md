# App Store Connect Upload Troubleshooting Guide: SpeakEasy

This guide documents the specific App Store Connect distribution errors encountered when publishing **SpeakEasy**, why they happened, and how they were resolved using an automated build phase post-processing script.

---

## Table of Contents
1. [Error 1: Missing Plist Key (CFBundleShortVersionString)](#error-1-missing-plist-key-cfbundleshortversionstring)
2. [Error 2: Invalid Bundle Structure (Nested .dylib Binaries)](#error-2-invalid-bundle-structure-nested-dylib-binaries)
3. [Error 3: ITMS-90208: Invalid Bundle (GemmaModelConstraintProvider.framework MinimumOSVersion)](#error-3-itms-90208-invalid-bundle-gemmamodelconstraintproviderframework-minimumosversion)
4. [The Automated Solution: Build Script & Xcode Integration](#the-automated-solution-build-script--xcode-integration)
5. [Standard Workflow for Successful Archiving & Distribution](#standard-workflow-for-successful-archiving--distribution)

---

## Error 1: Missing Plist Key (CFBundleShortVersionString)

### Symptoms
When attempting to upload or validate an archive in App Store Connect, the process fails with:
```text
The bundle 'Payload/SpeakEasy.app/Frameworks/CLiteRTLM.framework' is missing plist key. 
The Info.plist file is missing the required key: CFBundleShortVersionString.
(Server Response Code: 90057)
```

### Root Cause
The `CLiteRTLM.framework` is embedded automatically by Xcode as a dynamic binary dependency of the Swift Package Manager (SPM) dependency `LiteRT-LM` (`google-ai-edge/LiteRT-LM`). 
Because it is built and shipped as precompiled binaries, its `Info.plist` is generated dynamically and lacks standard marketing version keys (`CFBundleShortVersionString` and sometimes `CFBundleVersion`). Apple's App Store validation checks all embedded framework bundles and rejects any bundle missing these keys.

### Solution
We inject the missing plist keys at build/archive time right before code-signing occurs:
1. Locate the built `Info.plist` inside the framework bundle.
2. Read the binary's build version (`CFBundleVersion`) or fall back to `1.0` if not present.
3. Inject the keys using macOS's built-in `/usr/libexec/PlistBuddy` tool:
   ```bash
   /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "CLiteRTLM.framework/Info.plist"
   ```

---

## Error 2: Invalid Bundle Structure (Nested .dylib Binaries)

### Symptoms
After patching the plist key and archiving, the App Store Connect upload fails with:
```text
Invalid bundle structure. The “SpeakEasy.app/Frameworks/CLiteRTLM.framework/libGemmaModelConstraintProvider.dylib” binary file is not permitted. 
Your app cannot contain standalone executables or libraries, other than a valid CFBundleExecutable of supported bundles.
(Server Response Code: 90171)
```

### Root Cause
The `CLiteRTLM` framework package bundles a helper dynamic library `libGemmaModelConstraintProvider.dylib` directly inside its top-level folder (`CLiteRTLM.framework/libGemmaModelConstraintProvider.dylib`). 

Apple's security and bundle structure rules prohibit standalone dynamic library binaries (`.dylib` files) from being nested inside framework subdirectories, and they **also** prohibit raw `.dylib` files from sitting loosely inside the `Frameworks/` folder. Everything inside `Frameworks/` must be a valid, supported bundle structure (i.e., a `.framework` folder with its own `Info.plist` and executable binary).

### Solution
We resolve this by converting the loose `.dylib` library into an Apple-compliant framework bundle:
1. **Create the Framework Bundle:**
   We create a directory named `GemmaModelConstraintProvider.framework` inside `Frameworks/` and move the binary inside it as `GemmaModelConstraintProvider`.
2. **Inject Info.plist:**
   We write a standard `Info.plist` file inside `GemmaModelConstraintProvider.framework` detailing its identifier and executable name to satisfy the bundle criteria.
3. **Update Binary linkage:**
   We run `install_name_tool -change` on the `CLiteRTLM` executable to look for `@rpath/GemmaModelConstraintProvider.framework/GemmaModelConstraintProvider` instead of `@rpath/libGemmaModelConstraintProvider.dylib`.
4. **Re-sign:**
   Both framework bundles are re-signed with the target certificate identity.

---

## Error 3: ITMS-90208: Invalid Bundle (GemmaModelConstraintProvider.framework MinimumOSVersion)

### Symptoms
When attempting to upload the build to App Store Connect, the process fails or you receive an email from Apple stating:
```text
ITMS-90208: Invalid Bundle - The bundle SpeakEasy.app/Frameworks/GemmaModelConstraintProvider.framework does not support the minimum OS Version specified in the Info.plist.
```

### Root Cause
When we wrapped the loose dynamic library `libGemmaModelConstraintProvider.dylib` into `GemmaModelConstraintProvider.framework`, the generated `Info.plist` initially had its `MinimumOSVersion` key hardcoded to `13.0`.
However, the precompiled binary was compiled targeting a minimum OS of `26.2`. Apple's validation engine compares the binary's actual compile-time minimum target (defined in its Mach-O header load commands like `LC_BUILD_VERSION`) against the `MinimumOSVersion` declared in the framework's `Info.plist`. If the plist declares a version lower than the binary's actual compiled minimum version, Apple rejects the bundle.

### Solution
We updated the [patch-and-resign-frameworks.sh](file:///Users/dalaimingat/Desktop/mydev/DysarthriaApp/scripts/patch-and-resign-frameworks.sh) build phase script to automatically inspect Mach-O binaries:
1. It uses `otool -l` to extract the `minos` or `version` compilation target from the binary's `LC_BUILD_VERSION` or `LC_VERSION_MIN_IPHONEOS` commands.
2. It dynamically injects the correct version into `Info.plist` during bundle creation.
3. For all other embedded frameworks, it checks if the `MinimumOSVersion` key matches the binary's minimum version and dynamically updates the plist if they differ, ensuring that all frameworks are fully compliant.

---

## The Automated Solution: Build Script & Xcode Integration

These fixes are automated inside the [patch-and-resign-frameworks.sh](file:///Users/dalaimingat/Desktop/mydev/DysarthriaApp/scripts/patch-and-resign-frameworks.sh) shell script.

### Xcode Integration
The script is run during Xcode's build pipeline via a Run Script phase called **Re-sign Frameworks**:
1. Open Xcode and select the project target `DysarthriaApp`.
2. Go to **Build Phases** tab.
3. Locate the **Re-sign Frameworks** script phase.
4. The script content runs:
   ```bash
   /bin/sh "${SRCROOT}/scripts/patch-and-resign-frameworks.sh"
   ```
5. `alwaysOutOfDate` is set to `1` (configured in `project.pbxproj`) to ensure the post-processing script runs on every archive/build, even if no source code files changed.

---

## Standard Workflow for Successful Archiving & Distribution

Follow these steps to generate a clean, validated build for App Store Connect:

1. **Clean the Build Directory (Crucial):**
   In Xcode, go to the menu bar and choose **Product** > **Clean Build Folder** (or press `Cmd + Shift + K`).
   > [!IMPORTANT]
   > Cleaning is necessary because older, incorrect dylib copies from previous failed builds may still linger inside the derived data or build folders, triggering validation errors even after fixes are applied.

2. **Archive the App:**
   - In the scheme selector (top bar), choose **Any iOS Device (arm64)** as the target.
   - Go to **Product** > **Archive** in the menu bar.
   - Wait for the compilation to finish.

3. **Manage Archives & Upload:**
   - When the **Organizer** window opens, you will see the new archive.
   - **Delete older archives:** To avoid uploading an old, unpatched build, right-click and delete archives built prior to the fix.
   - Select the newest archive, click **Distribute App** (or **Validate App**), and follow the upload prompts.

---

## Warning: Upload Symbols Failed (Missing dSYM for CLiteRTLM.framework / libGemmaModelConstraintProvider.dylib)

### Symptoms
During the App Store Connect upload/validation process, Xcode displays one or more warning logs:
```text
Upload Symbols Failed
The archive did not include a dSYM for the CLiteRTLM.framework with the UUIDs [CC0F5A59-0507-354B-BCC9-12A8EBB27CC4].
The archive did not include a dSYM for the libGemmaModelConstraintProvider.dylib with the UUIDs [48BD08F2-1C71-3F91-8D1F-57645E1F69B8].
```

### Root Cause
Both `CLiteRTLM` (the framework) and `libGemmaModelConstraintProvider.dylib` (the dynamic helper library) are precompiled binary components supplied inside the official `LiteRT-LM` package. 
Because the precompiled binary releases do not distribute debug symbols (`.dSYM` folders) in their release assets, Xcode cannot locate or extract symbols for these binaries to include in the archive's `dSYMs` folder.

### Impact and Resolution
*   **No Action Required:** This is a **warning**, not a blocker. It will **not** prevent your upload from completing successfully, nor will it result in your app being rejected by Apple App Review. The build will still be successfully uploaded and made available on TestFlight and the App Store.
*   **Technical Limitation:** The only consequence is that if a crash occurs *inside* either the `CLiteRTLM` framework binary or the `libGemmaModelConstraintProvider` library, Apple's crash reports will show raw memory addresses for those frames rather than C++ method names (the rest of your application's Swift code will remain fully symbolicated). This is normal behavior when using precompiled closed-source or binary distributions.

---

## Upload Completed But Build is Not Showing Up on App Store Connect

### Symptoms
Xcode shows a successful upload confirmation, but when you log in to App Store Connect, the build does not appear in the **Builds** section of your App Store page or the build selection dialog.

### Explanation (Processing Phase)
Apple performs automatic server-side processing and validation on every newly uploaded build. This phase checks for code signature validity, entitlement constraints, API usages, and assets.

This processing typically takes **5 to 30 minutes** (sometimes up to an hour depending on Apple's queues). During this time:
1. The build will **not** show up on your App Store "Prepare for Submission" page.
2. The build **will** show up under the **TestFlight** tab at the top of the page with a status of **Processing** (along with a yellow indicator).
3. Once processing is complete, you will receive an **email confirmation** stating that the build is ready for testing. At that point, it will become selectable under the App Store tab.

### What to check:
1. **Check the TestFlight Tab:** Go to App Store Connect -> My Apps -> SpeakEasy -> **TestFlight**. Look for your version number (e.g., `1.0`) and check if the build is listed as *Processing*.
2. **Check your Email:** If Apple finds a server-side validation issue during processing (e.g., a missing privacy entitlement or plist config), they will reject the build and send a detailed email to your developer Apple ID. If this happens, the build will disappear entirely from the portal, and you must apply the fix from the email and upload a new build with an incremented build number (e.g. Build `2`).

---

## Error: ITMS-90426: Invalid Swift Support - The SwiftSupport folder is missing

### Symptoms
After uploading a build, you receive a rejection email from Apple:
```text
ITMS-90426: Invalid Swift Support - The SwiftSupport folder is missing. 
Rebuild your app using the current public (GM) version of Xcode and resubmit it.
```

### Root Cause
By default, Xcode does not include the Swift standard libraries and the `SwiftSupport` directory inside the exported IPA package if the app's Minimum Deployment Target is set to iOS 13 or later (since the Swift runtime is built into iOS 13+).
However, if the app contains custom dynamic libraries (like `libGemmaModelConstraintProvider.dylib` or other precompiled modules), App Store Connect's automated validation engine still incorrectly requires a `SwiftSupport` folder to be present in the bundle.

### Solution
We resolve this by forcing Xcode to always embed the Swift standard libraries:
1. We set the build settings **Always Embed Swift Standard Libraries** (`ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES`) to **YES** and **Embedded Content Contains Swift** (`EMBEDDED_CONTENT_CONTAINS_SWIFT`) to **YES** in both the **Project** settings and the **Target** settings in Xcode.
2. We increment the build number (e.g., to Build `4`).
3. Re-archive the project and upload the new build.
