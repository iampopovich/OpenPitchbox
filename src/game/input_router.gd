class_name InputRouter
extends RefCounted
## Polls every input device into InputFrames. Devices: "kb1", "kb2", "joy0".."joy3",
## "touch" (on-screen controls / tilt), "mouse" and "remote0".."remote3" (phones over Wi-Fi).
## Stick values are screen-space (x right, y down); the match converts them with the camera.

const DEVICES := ["kb1", "kb2", "joy0", "joy1", "joy2", "joy3", "touch", "mouse", "remote0", "remote1", "remote2", "remote3"]
const DEVICE_NAMES := {"kb1": "Keyboard (WASD)", "kb2": "Keyboard (arrows)", "joy0": "Gamepad 1", "joy1": "Gamepad 2", "joy2": "Gamepad 3", "joy3": "Gamepad 4",
	"touch": "Touch screen", "mouse": "Mouse", "remote0": "Phone 1", "remote1": "Phone 2", "remote2": "Phone 3", "remote3": "Phone 4"}

const KB := {
	"kb1": {"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"pass": [KEY_J], "shoot": [KEY_K, KEY_SPACE], "lob": [KEY_L], "aerial": [KEY_I], "switch": [KEY_Q, KEY_U]},
	"kb2": {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"pass": [KEY_COMMA, KEY_KP_1], "shoot": [KEY_PERIOD, KEY_KP_2], "lob": [KEY_SLASH, KEY_KP_3], "aerial": [KEY_SEMICOLON, KEY_KP_5], "switch": [KEY_APOSTROPHE, KEY_KP_0]},
}

var _prev := {}     # device -> {button: bool}
var _pending := {}  # device -> edges accumulated since the last consume


static func connected_devices() -> Array:
	var out: Array = []
	if not OS.has_feature("mobile") or DisplayServer.has_hardware_keyboard():
		out.append_array(["kb1", "kb2"])
	for j in Input.get_connected_joypads():
		if j < 4:
			out.append("joy%d" % j)
	if VirtualPads.touch_available():
		out.append("touch")
	if not OS.has_feature("mobile"):
		out.append("mouse")
	for i in 4:
		if VirtualPads.remote_connected("remote%d" % i):
			out.append("remote%d" % i)
	return out


static func default_device() -> String:
	## What player 1 uses when nobody chose: a gamepad if one is plugged in, otherwise
	## the touch screen on phones and the keyboard on computers.
	if not Input.get_connected_joypads().is_empty():
		return "joy%d" % Input.get_connected_joypads()[0]
	if OS.has_feature("mobile") or (VirtualPads.touch_available() and not DisplayServer.has_hardware_keyboard()):
		return "touch"
	return "kb1"


static func device_label(dev: String) -> String:
	if dev.begins_with("joy"):
		var id := int(dev.substr(3))
		var n := Input.get_joy_name(id)
		return "Gamepad %d%s" % [id + 1, (" (" + n + ")") if n != "" else ""]
	return DEVICE_NAMES.get(dev, dev)


func _held(dev: String) -> Dictionary:
	var h := {"pass": false, "shoot": false, "lob": false, "aerial": false, "switch": false, "pause": false}
	var mv := Vector2.ZERO
	if KB.has(dev):
		var k: Dictionary = KB[dev]
		if Input.is_physical_key_pressed(k["left"]):
			mv.x -= 1
		if Input.is_physical_key_pressed(k["right"]):
			mv.x += 1
		if Input.is_physical_key_pressed(k["up"]):
			mv.y -= 1
		if Input.is_physical_key_pressed(k["down"]):
			mv.y += 1
		for b in ["pass", "shoot", "lob", "aerial", "switch"]:
			for key in k[b]:
				if Input.is_physical_key_pressed(key):
					h[b] = true
		h["pause"] = Input.is_physical_key_pressed(KEY_ESCAPE) if dev == "kb1" else false
	elif dev == "touch" or dev.begins_with("remote"):
		var pad := VirtualPads.get_pad(dev)
		mv = pad["move"]
		for b in ["pass", "shoot", "lob", "aerial", "switch", "pause"]:
			h[b] = pad[b]
	elif dev == "mouse":
		# run towards the cursor; LMB pass, RMB shoot (hold for power), wheel click lob,
		# side buttons volley / switch
		var anchor := VirtualPads.mouse_anchor
		var vp := Engine.get_main_loop() as SceneTree
		if anchor.x >= 0.0 and vp:
			var d := vp.root.get_mouse_position() - anchor
			var full := 160.0
			if d.length() > 24.0:
				mv = d / full
		h["pass"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		h["shoot"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		h["lob"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		h["aerial"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_XBUTTON1) or Input.is_physical_key_pressed(KEY_SHIFT)
		h["switch"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_XBUTTON2) or Input.is_physical_key_pressed(KEY_TAB)
	elif dev.begins_with("joy"):
		var id := int(dev.substr(3))
		mv = Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X), Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
		if mv.length() < 0.22:
			mv = Vector2.ZERO
		if Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_LEFT):
			mv.x = -1
		if Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_RIGHT):
			mv.x = 1
		if Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP):
			mv.y = -1
		if Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN):
			mv.y = 1
		h["pass"] = Input.is_joy_button_pressed(id, JOY_BUTTON_A)
		h["shoot"] = Input.is_joy_button_pressed(id, JOY_BUTTON_B) or Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		h["aerial"] = Input.is_joy_button_pressed(id, JOY_BUTTON_X)
		h["lob"] = Input.is_joy_button_pressed(id, JOY_BUTTON_Y)
		h["switch"] = Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(id, JOY_BUTTON_RIGHT_SHOULDER) \
			or Input.is_joy_button_pressed(id, JOY_BUTTON_TOUCHPAD)
		h["pause"] = Input.is_joy_button_pressed(id, JOY_BUTTON_START)
		# motion sensors (DualSense, DualShock 4, Switch Pro, Joy-Con): optional tilt steering
		if Game.settings.get("pad_tilt", false) and mv == Vector2.ZERO:
			mv = _joy_tilt(id)
	h["move"] = mv.limit_length(1.0)
	return h


## Call once per rendered frame: records edges so a quick tap between ticks is not lost.
func poll(devices: Array) -> void:
	for dev in devices:
		var h := _held(dev)
		var prev: Dictionary = _prev.get(dev, {})
		var pend: Dictionary = _pending.get(dev, {})
		for b in ["pass", "shoot", "lob", "aerial", "switch", "pause"]:
			if h[b] and not prev.get(b, false):
				pend[b + "_p"] = true
			if not h[b] and prev.get(b, false):
				pend[b + "_r"] = true
		pend["held"] = h
		_pending[dev] = pend
		_prev[dev] = h


## Builds the frame for one tick and clears the edges. `to_world` converts the stick.
func consume(dev: String, to_world: Callable) -> InputFrame:
	var f := InputFrame.new()
	var pend: Dictionary = _pending.get(dev, {})
	var h: Dictionary = pend.get("held", {})
	if h.is_empty():
		return f
	var mv: Vector2 = h["move"]
	if mv.length() > 0.0:
		var w: Vector2 = to_world.call(mv)
		f.move = w.normalized() * mv.length() if w.length() > 0.001 else Vector2.ZERO
	f.pass_held = h["pass"]
	f.shoot_held = h["shoot"]
	f.lob_held = h["lob"]
	f.aerial_held = h["aerial"]
	f.switch_held = h["switch"]
	f.pass_pressed = pend.get("pass_p", false)
	f.shoot_pressed = pend.get("shoot_p", false)
	f.lob_pressed = pend.get("lob_p", false)
	f.aerial_pressed = pend.get("aerial_p", false)
	f.switch_pressed = pend.get("switch_p", false)
	f.shoot_released = pend.get("shoot_r", false)
	f.any_pressed = f.pass_pressed or f.shoot_pressed or f.lob_pressed or f.aerial_pressed
	_pending[dev] = {"held": h}
	return f


func pause_pressed(dev: String) -> bool:
	var pend: Dictionary = _pending.get(dev, {})
	if pend.get("pause_p", false):
		pend.erase("pause_p")
		return true
	return false


func any_button_pressed(devices: Array) -> bool:
	for dev in devices:
		var pend: Dictionary = _pending.get(dev, {})
		for b in ["pass_p", "shoot_p", "lob_p", "aerial_p"]:
			if pend.get(b, false):
				return true
	return false


func peek_button(dev: String, b: String) -> bool:
	return (_pending.get(dev, {}) as Dictionary).get(b + "_p", false)


static var _tilt_on := {}


static func _joy_tilt(id: int) -> Vector2:
	if not _tilt_on.get(id, false):
		if Input.has_joy_motion_sensors(id):
			Input.set_joy_motion_sensors_enabled(id, true)
			_tilt_on[id] = true
		else:
			return Vector2.ZERO
	var g := Input.get_joy_gravity(id)
	if g.length() < 0.1:
		return Vector2.ZERO
	g = g.normalized()
	var v := Vector2(-g.x, -g.z)
	return Vector2.ZERO if v.length() < 0.1 else (v * 2.2).limit_length(1.0)
