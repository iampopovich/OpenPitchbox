#!/bin/sh
# Touch test on the phone: start practice, hold the stick to the right, press PASS and SHOOT.
PKG=io.github.iampopovich.openpitchbox
LOG=$HOME/.hermes/cache/scratch/godot_touch.txt
adb shell am force-stop $PKG
echo '{"log_events": true}' | adb shell "run-as $PKG sh -c 'cat > files/debug_flags.json'"
echo '{}' | adb shell "run-as $PKG sh -c 'cat > files/settings.json'"
(timeout 90 adb logcat -T 1 -s godot:I > $LOG &)
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 12
adb shell input tap 1168 612
sleep 3
adb shell input tap 1300 1014
sleep 12
adb shell input swipe 400 800 700 800 4000 &
sleep 2
adb exec-out screencap -p > $HOME/development/OpenPitchbox/docs/img/phone_touch_hold.png
sleep 3
for i in 1 2 3; do adb shell input tap 2010 973; sleep 1.5; adb shell input tap 2214 940; sleep 1.5; done
sleep 4
grep -a -E "OPBX human" $LOG | head -30
