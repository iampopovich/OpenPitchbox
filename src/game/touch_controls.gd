class_name TouchControls
extends Control
## On-screen controls for touch screens: a floating stick (or phone tilt) on the left half,
## four action buttons in a thumb arc on the right, switch and pause buttons.
## Writes into VirtualPads under `device` ("touch" in a match, "remote" in controller mode).
## Multi-touch: every finger is tracked by its index.

signal pause_pressed

const ACTIONS := [
	# id, label, anchor offset from the bottom-right corner (in button radii), colour
	["shoot", "SHOOT", Vector2(-1.35, -1.25), Color("dc2626")],
	["pass", "PASS", Vector2(-3.55, -0.95), Color("16a34a")],
	["lob", "LOB", Vector2(-1.15, -3.45), Color("ca8a04")],
	["aerial", "VOLLEY", Vector2(-3.35, -3.2), Color("2563eb")],
]

var device := "touch"
var opacity := 0.55
var scale_k := 1.0
var tilt := false
var radius := 62.0                 # action button radius (px, before scale)
var stick_r := 90.0
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var fingers := {}                  # finger index -> action id
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	opacity = float(Game.settings.get("touch_opacity", 0.55))
	scale_k = float(Game.settings.get("touch_size", 1.0))
	tilt = Game.settings.get("steering", "stick") == "tilt"
	_font = ThemeDB.fallback_font
	VirtualPads.release_all(device)


func _exit_tree() -> void:
	VirtualPads.release_all(device)


func _r() -> float:
	var short := minf(size.x, size.y)
	return radius * scale_k * clampf(short / 720.0, 0.75, 1.6)


func _button_center(i: int) -> Vector2:
	var r := _r()
	var off: Vector2 = ACTIONS[i][2]
	return Vector2(size.x, size.y) + off * r + Vector2(-_safe_right(), -r * 0.2)


func _safe_right() -> float:
	# keep the buttons clear of a display cut-out in landscape
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or scr.x <= 0:
		return 0.0
	return float(scr.x - safe.end.x) * size.x / float(scr.x)


func _small_buttons() -> Array:
	## [id, label, center]: switch player above the stick zone, pause top centre.
	var r := _r()
	return [["switch", "SWITCH", Vector2(size.x - _safe_right() - r * 5.6, size.y - r * 1.0)],
		["pause", "II", Vector2(size.x * 0.5, r * 0.55)]]


func _hit(pos: Vector2) -> String:
	var r := _r()
	for i in ACTIONS.size():
		if pos.distance_to(_button_center(i)) < r * 1.15:
			return ACTIONS[i][0]
	for sb: Array in _small_buttons():
		if pos.distance_to(sb[2]) < r * 0.75:
			return sb[0]
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var a := _hit(t.position)
			if Game.dbg("log_events"):
				var cs := []
				for i in ACTIONS.size():
					cs.append([ACTIONS[i][0], _button_center(i).round()])
				print("OPBX touch %s -> '%s' size %s r %.0f buttons %s" % [t.position.round(), a, size, _r(), cs])
			if a != "":
				fingers[t.index] = a
				if a == "pause":
					pause_pressed.emit()
				else:
					VirtualPads.set_button(device, a, true)
				Input.vibrate_handheld(18)
				get_viewport().set_input_as_handled()
			elif t.position.x < size.x * 0.5 and stick_finger < 0 and not tilt:
				stick_finger = t.index
				stick_origin = t.position
				stick_pos = t.position
				get_viewport().set_input_as_handled()
		else:
			if fingers.has(t.index):
				var a2: String = fingers[t.index]
				fingers.erase(t.index)
				if a2 != "pause" and not fingers.values().has(a2):
					VirtualPads.set_button(device, a2, false)
				get_viewport().set_input_as_handled()
			if t.index == stick_finger:
				stick_finger = -1
				VirtualPads.set_move(device, Vector2.ZERO)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == stick_finger:
			stick_pos = d.position
			var v := stick_pos - stick_origin
			var sr := stick_r * scale_k
			if v.length() > sr:
				# floating stick: the base follows the finger when it runs away
				stick_origin = stick_pos - v.normalized() * sr
				v = stick_pos - stick_origin
			var m := v / sr
			VirtualPads.set_move(device, m if m.length() > 0.12 else Vector2.ZERO)
			queue_redraw()
			get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if tilt and visible:
		VirtualPads.set_move(device, VirtualPads.tilt_vector())
		queue_redraw()


func _draw() -> void:
	var r := _r()
	var a := opacity
	# stick
	if tilt:
		var c := Vector2(r * 2.2, size.y - r * 2.2)
		draw_arc(c, r * 1.2, 0, TAU, 48, Color(1, 1, 1, a * 0.35), 3.0, true)
		var mv: Vector2 = VirtualPads.get_pad(device)["move"]
		draw_circle(c + mv * r * 1.2, r * 0.35, Color(1, 1, 1, a * 0.6))
		_text(c + Vector2(0, r * 1.75), "TILT", r * 0.3, Color(1, 1, 1, a))
	elif stick_finger >= 0:
		var sr := stick_r * scale_k
		draw_circle(stick_origin, sr, Color(1, 1, 1, a * 0.18))
		draw_arc(stick_origin, sr, 0, TAU, 48, Color(1, 1, 1, a * 0.5), 3.0, true)
		draw_circle(stick_pos, sr * 0.45, Color(1, 1, 1, a * 0.7))
	else:
		var hint := Vector2(r * 2.3, size.y - r * 2.3)
		draw_arc(hint, stick_r * scale_k, 0, TAU, 48, Color(1, 1, 1, a * 0.22), 2.0, true)
		_text(hint, "MOVE", r * 0.28, Color(1, 1, 1, a * 0.5))
	var held := VirtualPads.get_pad(device)
	for i in ACTIONS.size():
		var id: String = ACTIONS[i][0]
		var col: Color = ACTIONS[i][3]
		var c2 := _button_center(i)
		var on: bool = held.get(id, false)
		draw_circle(c2, r * (0.95 if on else 1.0), Color(col, a * (0.95 if on else 0.6)))
		draw_arc(c2, r, 0, TAU, 48, Color(1, 1, 1, a * 0.8), 2.5, true)
		_text(c2, ACTIONS[i][1], r * 0.3, Color(1, 1, 1, minf(1.0, a + 0.3)))
	for sb: Array in _small_buttons():
		var on2: bool = held.get(sb[0], false)
		draw_circle(sb[2], r * 0.62, Color(0.1, 0.12, 0.16, a * (0.95 if on2 else 0.65)))
		draw_arc(sb[2], r * 0.62, 0, TAU, 40, Color(1, 1, 1, a * 0.7), 2.0, true)
		_text(sb[2], sb[1], r * 0.24, Color(1, 1, 1, minf(1.0, a + 0.3)))


func _text(c: Vector2, s: String, px: float, col: Color) -> void:
	var fs := int(px)
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(_font, c + Vector2(-w * 0.5, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
