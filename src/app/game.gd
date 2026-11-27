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
}
var career = null          # Career, when one is open
var career_slot := 0
var _world: Array = []
var _current: Node = null


var _frame := 0
var _shot_path := ""
var _shot_frame := -1


func _ready() -> void:
	load_settings()
	_apply_window()
	# debug capture: OP_SCREENSHOT=<png> OP_SCREENSHOT_FRAME=<n> saves frame n and quits
	_shot_path = OS.get_environment("OP_SCREENSHOT")
	var f := OS.get_environment("OP_SCREENSHOT_FRAME")
	_shot_frame = int(f) if f != "" else -1


func capture_in(frames: int) -> void:
	if _shot_path != "":
		_shot_frame = _frame + frames


func _process(_dt: float) -> void:
	_frame += 1
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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)


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
	var caller := _current
	if caller and is_instance_valid(caller) and caller.is_inside_tree():
		caller.get_parent().remove_child(caller)
	_current = null
	var mv := MatchView.new()
	mv.setup(cfg)
	mv.finished.connect(func(result):
		on_done.call(result)
		if caller and is_instance_valid(caller) and not caller.is_inside_tree():
			caller.queue_free())
	switch_to(mv)


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
