extends Node
## Global app state (autoload "Game"): settings, the open career, scene switching.

const SETTINGS_PATH := "user://settings.json"

var settings := {
	"volume": 0.8,
	"camera": 0,
	"length": 180,
	"difficulty": 1,
	"replays": true,
	"auto_switch": true,
	"fullscreen": false,
	"fouls": true,
	"markers": "all",
	"touch_opacity": 0.55,
	"touch_size": 1.0,
	"steering": "stick",      # touch screen: "stick" or "tilt"
	"pad_tilt": false,        # gamepads with motion sensors steer by tilting
	"phone_link": true,       # accept phones as controllers over Wi-Fi
	"graphics": "auto",       # auto / high / low
}
var remote: RemoteLink
var career = null          # Career, when one is open
var career_slot := 0
var _world: Array = []
var _current: Node = null


var _frame := 0
var _shot_path := ""
var _shot_frame := -1


var debug_flags := {}


func dbg(key: String) -> bool:
	## Debug switches for device testing: user://debug_flags.json, debug builds only.
	return OS.is_debug_build() and debug_flags.get(key, false)


func _ready() -> void:
	if OS.is_debug_build() and FileAccess.file_exists("user://debug_flags.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("user://debug_flags.json"))
		if d is Dictionary:
			debug_flags = d
			print("OPBX debug flags ", d)
			if d.has("quit_after_s"):
				get_tree().create_timer(float(d["quit_after_s"])).timeout.connect(func():
					print("OPBX clean quit")
					get_tree().quit())
	load_settings()
	_apply_window()
	apply_graphics()
	get_tree().quit_on_go_back = false
	start_phone_link()
	# debug capture: OP_SCREENSHOT=<png> OP_SCREENSHOT_FRAME=<n> saves frame n and quits
	_shot_path = OS.get_environment("OP_SCREENSHOT")
	var f := OS.get_environment("OP_SCREENSHOT_FRAME")
	_shot_frame = int(f) if f != "" else -1


func capture_in(frames: int) -> void:
	if _shot_path != "":
		_shot_frame = _frame + frames


var _fps_t := 0.0


func _process(dt: float) -> void:
	_frame += 1
	# debug builds on phones log the frame rate for profiling over adb logcat
	if OS.is_debug_build() and OS.has_feature("mobile"):
		if _current is MatchView and (_current as MatchView)._frame_no <= 2:
			print("OPBX game process frame %d" % (_current as MatchView)._frame_no)
		_fps_t += dt
		if _fps_t > 5.0:
			_fps_t = 0.0
			print("OPBX fps %d  process %.1f ms  physics %.1f ms  draw calls %d  primitives %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	if _shot_path != "" and _frame == _shot_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("screenshot saved: ", _shot_path)
		get_tree().quit()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var txt := FileAccess.get_file_as_string(SETTINGS_PATH)
	var d = JSON.parse_string(txt)
	if d is Dictionary:
		for k in d:
			settings[k] = d[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# phones always run full screen (immersive: no status or navigation bar)
	var full: bool = OS.has_feature("mobile") or settings.get("fullscreen", false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


func set_fullscreen(on: bool) -> void:
	settings["fullscreen"] = on
	save_settings()
	_apply_window()


func switch_to(node: Node) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	_current = node
	get_tree().root.add_child.call_deferred(node)


func show_menu(menu: Node = null) -> void:
	if menu == null:
		menu = MainMenu.new()
	switch_to(menu)


func play_match(cfg: Dictionary, on_done: Callable) -> void:
	## The calling screen is detached (not freed) so callbacks bound to it stay valid.
	## A loading card is drawn first: building the match and, on a phone's first run,
	## compiling its graphics pipelines can take a while, and a frozen menu looks like a hang.
	var caller := _current
	if caller and is_instance_valid(caller) and caller.is_inside_tree():
		caller.get_parent().remove_child(caller)
	_current = null
	var card := _loading_card()
	get_tree().root.add_child.call_deferred(card)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var mv := MatchView.new()
	mv.setup(cfg)
	mv.finished.connect(func(result):
		on_done.call(result)
		if caller and is_instance_valid(caller) and not caller.is_inside_tree():
			caller.queue_free())
	mv.first_frame.connect(func(): card.queue_free())
	switch_to(mv)


func _loading_card() -> Control:
	var c := ColorRect.new()
	c.color = UiTheme.BG
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.z_index = 100
	var l := UiTheme.label("Getting the pitch ready…", 28, UiTheme.TEXT)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	if OS.has_feature("mobile"):
		var s2 := UiTheme.label("The first match on a new phone takes longer: graphics are being prepared once.", 18, UiTheme.MUTED)
		s2.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		s2.grow_horizontal = Control.GROW_DIRECTION_BOTH
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.position.y -= 80
		c.add_child(s2)
	return c


func world_teams() -> Array:
	## The 64 clubs used for exhibition matches (custom CSV league if present).
	if _world.is_empty():
		var lg := LeagueIO.import_league() if LeagueIO.has_league() else {}
		if lg.has("teams"):
			_world = lg["teams"]
		else:
			_world = Career.create(2026).teams
	return _world


func reload_world() -> void:
	_world.clear()


func save_career() -> void:
	if career:
		career.save(career_slot)


func start_phone_link() -> void:
	## Lets phones running OpenPitchbox in controller mode join matches on this device.
	if remote:
		remote.queue_free()
		remote = null
	if not settings.get("phone_link", true) or DisplayServer.get_name() == "headless":
		return
	remote = RemoteLink.new()
	add_child(remote)
	if not remote.start_host():
		push_warning("phone link: port %d busy" % RemoteLink.PORT)


func apply_graphics() -> void:
	## Same settings on every platform; only the "auto" default differs (low on phones).
	var low := low_graphics()
	if dbg("no_apply_graphics"):
		return
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if low else Viewport.SCREEN_SPACE_AA_FXAA
	vp.scaling_3d_scale = 0.67 if low else 1.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)


func low_graphics() -> bool:
	var g: String = settings.get("graphics", "auto")
	if g == "auto":
		return OS.has_feature("mobile")
	return g == "low"


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button behaves like Esc / B
			var ev := InputEventAction.new()
			ev.action = "ui_cancel"
			ev.pressed = true
			Input.parse_input_event(ev)
			if _current is MainMenu:
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _current is MatchView and OS.has_feature("mobile"):
				(_current as MatchView).pause_from_app()
