#!/bin/sh
# Screenshots for the README (media/*.webp source PNGs in docs/img/readme_*.png)
cd ~/development/OpenPitchbox || exit 1
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0
run() { name=$1; shift; env "$@" OP_SCREENSHOT=$PWD/docs/img/readme_$name.png timeout 90 godot --path . --display-driver wayland 2>&1 | grep -E 'SCRIPT ERROR' | head -2; }
run match OP_AUTOPLAY=1 OP_SEED=4 OP_SCREENSHOT_FRAME=900
run end OP_AUTOPLAY=1 OP_SEED=4 OP_CAMERA=1 OP_SCREENSHOT_FRAME=1500
run touch OP_TOUCH=1 OP_AUTOPLAY=1 OP_HUMAN=1 OP_DEVICE=touch OP_SEED=7 OP_SCREENSHOT_FRAME=700
run hub OP_SCREEN=hub OP_SCREENSHOT_FRAME=30
run editor OP_SCREEN=editor OP_SCREENSHOT_FRAME=40
run upgrade OP_SCREEN=upgrade OP_SCREENSHOT_FRAME=30
run menu OP_SCREEN=menu OP_SCREENSHOT_FRAME=30
echo done
