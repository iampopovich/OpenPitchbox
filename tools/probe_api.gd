extends SceneTree
## Debug: prints which optional engine APIs exist in this Godot build.

func _initialize() -> void:
	for m in ["has_joy_motion_sensors", "set_joy_motion_sensors_enabled", "get_joy_gravity", "get_joy_accelerometer", "get_gravity", "vibrate_handheld"]:
		print("Input.", m, " ", ClassDB.class_has_method("Input", m))
	for m in ["has_hardware_keyboard", "is_touchscreen_available", "get_display_safe_area", "screen_get_orientation"]:
		print("DisplayServer.", m, " ", ClassDB.class_has_method("DisplayServer", m))
	print("JOY_BUTTON_TOUCHPAD ", JOY_BUTTON_TOUCHPAD)
	quit()
