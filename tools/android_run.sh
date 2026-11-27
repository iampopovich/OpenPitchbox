#!/bin/sh
# Build the debug APK, install it on the connected phone and start it.
cd ~/development/OpenPitchbox || exit 1
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$HOME/.android/debug.keystore GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
mkdir -p build/android
timeout 580 godot --headless --export-debug "Android" build/android/OpenPitchbox.apk 2>&1 | grep -A6 "ERROR" | head -20
adb install -r build/android/OpenPitchbox.apk 2>&1 | tail -1
adb logcat -c
adb shell am force-stop io.github.iampopovich.openpitchbox
adb shell monkey -p io.github.iampopovich.openpitchbox -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo started
