class_name VirtualPads
extends RefCounted
## Shared state of input devices that are not polled from the engine directly:
## the on-screen touch controls, the mouse player and phones used as remote controllers.
## Each entry: {"move": Vector2 (screen space, length <= 1), "pass", "shoot", "lob", "aerial",
## "switch", "pause": bool}.

static var pads := {}
static var remote_seen := {}     # "remote0".. -> last packet time (msec)
static var mouse_anchor := Vector2(-1, -1)   # screen position of the mouse player's footballer


static func blank() -> Dictionary:
	return {"move": Vector2.ZERO, "pass": false, "shoot": false, "lob": false, "aerial": false, "switch": false, "pause": false}


static func get_pad(dev: String) -> Dictionary:
	if not pads.has(dev):
		pads[dev] = blank()
	return pads[dev]


static func set_button(dev: String, b: String, on: bool) -> void:
	get_pad(dev)[b] = on


static func set_move(dev: String, v: Vector2) -> void:
	get_pad(dev)["move"] = v.limit_length(1.0)


static func release_all(dev: String) -> void:
	pads[dev] = blank()


static func remote_connected(dev: String) -> bool:
	return Time.get_ticks_msec() - int(remote_seen.get(dev, -100000)) < 3000


static func touch_available() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_environment("OP_TOUCH") != ""


static func tilt_vector() -> Vector2:
	## Phone held in landscape: tilting away/towards = up/down, left/right = left/right.
	var g := Input.get_gravity()
	if g.length() < 1.0:
		return Vector2.ZERO
	g = g.normalized()
	var v := Vector2(g.y, g.x)  # landscape (sensor_landscape keeps x along the long edge)
	if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_REVERSE_LANDSCAPE:
		v = -v
	v -= Vector2(0.0, 0.35)      # neutral grip: phone tipped ~20° towards the player
	var dead := 0.08
	if v.length() < dead:
		return Vector2.ZERO
	return (v * 2.4).limit_length(1.0)
