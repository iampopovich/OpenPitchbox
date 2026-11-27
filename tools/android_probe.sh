#!/bin/sh
# Start a practice match on the phone with debug flags and report load/first-frame timings.
# usage: sh tools/android_probe.sh '{"no_crowd": true}'
FLAGS=${1:-"{}"}
PKG=io.github.iampopovich.openpitchbox
LOG=$HOME/.hermes/cache/scratch/godot_probe.txt
adb shell am force-stop $PKG
echo "$FLAGS" | adb shell "run-as $PKG sh -c 'cat > files/debug_flags.json'"
(timeout 110 adb logcat -T 1 -s godot:I > $LOG &)
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 12
adb shell input tap 1168 612
sleep 3
adb shell input tap 1300 1014
sleep 75
grep -a -E "OPBX (debug|load|match frame [12] (dt|script)|fps)" $LOG | head -9
