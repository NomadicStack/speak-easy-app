#!/bin/sh
# This script:
# 1. Wraps standalone dynamic libraries (like libGemmaModelConstraintProvider.dylib) into
#    valid .framework bundles with Info.plist configurations to comply with App Store rules.
# 2. Updates binary linkages using install_name_tool to ensure correct load paths.
# 3. Patches missing Info.plist keys (like CFBundleShortVersionString) in embedded frameworks.
# 4. Re-signs all frameworks in the application bundle.

set -e

echo "=== Start Framework Patch & Re-sign ==="

if [ -d "${CODESIGNING_FOLDER_PATH}/Frameworks" ]; then
    echo "Frameworks folder found: ${CODESIGNING_FOLDER_PATH}/Frameworks"
    
    # 1. Wrap nested dylib into a framework and update linkage
    find "${CODESIGNING_FOLDER_PATH}/Frameworks" -name "*.framework" | while read -r framework; do
        framework_name=$(basename "$framework" .framework)
        framework_binary="${framework}/${framework_name}"
        
        # Look for the constraint provider dylib inside CLiteRTLM.framework
        dylib_path="${framework}/libGemmaModelConstraintProvider.dylib"
        if [ -f "$dylib_path" ]; then
            echo "Found nested libGemmaModelConstraintProvider.dylib inside CLiteRTLM.framework"
            
            # Define new framework path
            new_framework_name="GemmaModelConstraintProvider"
            new_framework_dir="${CODESIGNING_FOLDER_PATH}/Frameworks/${new_framework_name}.framework"
            
            echo "-> Creating ${new_framework_name}.framework bundle..."
            mkdir -p "$new_framework_dir"
            
            # Move and rename binary
            new_binary_path="${new_framework_dir}/${new_framework_name}"
            mv "$dylib_path" "$new_binary_path"
            
            # Extract minimum OS version from the binary itself
            min_os=$(otool -l "$new_binary_path" | grep -A 5 "LC_BUILD_VERSION" | grep "minos" | awk '{print $2}' | head -n 1)
            if [ -z "$min_os" ]; then
                min_os=$(otool -l "$new_binary_path" | grep -A 5 "LC_VERSION_MIN_IPHONEOS" | grep "version" | awk '{print $2}' | head -n 1)
            fi
            if [ -z "$min_os" ]; then
                min_os="13.0"
            fi
            echo "-> Extracted MinimumOSVersion: ${min_os}"

            # Create Info.plist for the new framework
            cat <<EOF > "${new_framework_dir}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${new_framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>com.google.${new_framework_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${new_framework_name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>MinimumOSVersion</key>
    <string>${min_os}</string>
</dict>
</plist>
EOF
            
            # Update the dylib's install name (identification name) to match its new framework path
            echo "-> Updating install name for ${new_framework_name}"
            install_name_tool -id "@rpath/${new_framework_name}.framework/${new_framework_name}" "$new_binary_path"
            
            # Update CLiteRTLM binary linkage to point to the new framework instead of the loose dylib
            if [ -f "$framework_binary" ]; then
                echo "-> Updating CLiteRTLM linkage references to point to new framework bundle"
                install_name_tool -change "@rpath/libGemmaModelConstraintProvider.dylib" "@rpath/${new_framework_name}.framework/${new_framework_name}" "$framework_binary"
                
                # Add @loader_path/.. to the CLiteRTLM binary's RPATH so it searches SpeakEasy.app/Frameworks/
                if ! otool -l "$framework_binary" | grep -q "path @loader_path/.."; then
                    echo "-> Adding @loader_path/.. RPATH to CLiteRTLM binary"
                    install_name_tool -add_rpath "@loader_path/.." "$framework_binary"
                fi
            fi
        fi
    done

    # 2. Patch missing Plist keys in all frameworks
    find "${CODESIGNING_FOLDER_PATH}/Frameworks" -name "*.framework" | while read -r framework; do
        plist="${framework}/Info.plist"
        if [ -f "$plist" ]; then
            echo "Checking Info.plist for: $(basename "$framework")"
            
            # Check and add CFBundleShortVersionString if missing
            if ! /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" >/dev/null 2>&1; then
                version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist" 2>/dev/null || echo "1.0")
                echo "-> CFBundleShortVersionString is missing. Adding value: $version"
                /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$plist"
            fi
            
            # Check and add CFBundleVersion if missing
            if ! /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist" >/dev/null 2>&1; then
                echo "-> CFBundleVersion is missing. Adding value: 1.0"
                /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1.0" "$plist"
            fi

            # Check and add/update MinimumOSVersion if it doesn't match the binary's minimum OS version
            framework_name=$(basename "$framework" .framework)
            framework_binary="${framework}/${framework_name}"
            if [ -f "$framework_binary" ]; then
                min_os=$(otool -l "$framework_binary" | grep -A 5 "LC_BUILD_VERSION" | grep "minos" | awk '{print $2}' | head -n 1)
                if [ -z "$min_os" ]; then
                    min_os=$(otool -l "$framework_binary" | grep -A 5 "LC_VERSION_MIN_IPHONEOS" | grep "version" | awk '{print $2}' | head -n 1)
                fi
                if [ -n "$min_os" ]; then
                    existing_min_os=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$plist" 2>/dev/null || echo "")
                    if [ "$existing_min_os" != "$min_os" ]; then
                        echo "-> MinimumOSVersion in plist ($existing_min_os) does not match binary minos ($min_os). Updating to $min_os"
                        /usr/libexec/PlistBuddy -c "Delete :MinimumOSVersion" "$plist" 2>/dev/null || true
                        /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string $min_os" "$plist"
                    fi
                fi
            fi
        else
            echo "No Info.plist found inside $(basename "$framework")"
        fi
    done
    
    # 3. Re-sign all dynamic libraries and frameworks
    echo "Re-signing frameworks..."
    identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
    if [ -z "$identity" ]; then
        echo "No EXPANDED_CODE_SIGN_IDENTITY found. Falling back to ad-hoc signing (-)"
        identity="-"
    fi

    find "${CODESIGNING_FOLDER_PATH}/Frameworks" -name "*.framework" | while read -r binary; do
        echo "-> Re-signing: $(basename "$binary") using identity: $identity"
        codesign --force --sign "$identity" --timestamp=none --generate-entitlement-der "$binary"
    done
else
    echo "No Frameworks folder found at ${CODESIGNING_FOLDER_PATH}/Frameworks. Skipping."
fi

echo "=== Framework Patch & Re-sign Completed ==="
