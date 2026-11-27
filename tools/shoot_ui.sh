#!/bin/sh
# Screenshot every menu screen into docs/img/ui_<name>.png
cd ~/development/OpenPitchbox || exit 1
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0
for s in ${@:-menu setup options slots new hub upgrade squad leaders history editor}; do
  OP_SCREEN=$s OP_SCREENSHOT=$PWD/docs/img/ui_$s.png OP_SCREENSHOT_FRAME=30 timeout 60 godot --path . --display-driver wayland 2>&1 | grep -E 'SCRIPT ERROR|at: .*gd' | head -3
done
echo shots done
