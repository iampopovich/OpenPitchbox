class_name MatchView
extends Node3D
## Runs a MatchSim at 60 Hz and presents it: 3D scene, camera, HUD, sound, replays.
## Config keys: teams [TeamData, TeamData], humans [{id, team, device}], length, difficulty [a, b],
## needs_winner, practice, roleplay, seed, camera, replays, title, quit_text.

signal finished(result: Dictionary)

var cfg: Dictionary = {}
var sim: MatchSim
var arena: ArenaView
var ball_view: BallView
var views: Array = []
var cam: CameraRig
var hud: MatchHud
var sfx: Sfx
var router := InputRouter.new()
var devices: Array = []
var human_device := {}       # human id -> device

var paused := false
var in_replay := false
var replay_frames: Array = []
var replay_pos := 0.0
var replay_pending := false
var replay_cam_saved := 0
var done := false

var kits: Array = []          # per team [shirt, shorts, keeper shirt]
var prev_ball := Vector3.ZERO
var prev_pos: Array = []


func setup(config: Dictionary) -> void:
	cfg = config


func _ready() -> void:
	sim = MatchSim.new()
	var humans: Array = []
	for h in cfg.get("humans", []):
		humans.append({"id": h["id"], "team": h["team"]})
		human_device[int(h["id"])] = h["device"]
		devices.append(h["device"])
	if not devices.has("kb1"):
		devices.append("kb1")   # Esc pauses even without a keyboard player
	sim.setup(cfg["teams"][0], cfg["teams"][1], {
		"seed": cfg.get("seed", randi()),
		"length": cfg.get("length", 180.0),
		"difficulty": cfg.get("difficulty", [1, 1]),
		"needs_winner": cfg.get("needs_winner", false),
		"practice": cfg.get("practice", false),
		"roleplay": cfg.get("roleplay", false),
		"auto_switch": Game.settings.get("auto_switch", true),
		"humans": humans,
		"kickoff": cfg.get("kickoff", 0),
	})
	arena = ArenaView.new()
	add_child(arena)
	arena.build(cfg["teams"][0], cfg["teams"][1])
	ball_view = BallView.new()
	add_child(ball_view)
	ball_view.build()
	_pick_kits()
	for sp in sim.players:
		var p := sp as SimPlayer
		var v := PlayerView.new()
		add_child(v)
		var k: Array = kits[p.team]
		v.build(k[0], k[1], p.data, k[2] if p.is_gk() else Color(0, 0, 0, 0))
		v.visible = p.active
		views.append(v)
		prev_pos.append(p.pos)
	cam = CameraRig.new()
	add_child(cam)
	cam.mode = int(cfg.get("camera", 0))
	cam.end_dir = -1.0 if (humans.size() > 0 and humans[0]["team"] == 1) else 1.0
	cam.current = true
	cam.snap_to(sim.ball.pos)
	hud = MatchHud.new()
	add_child(hud)
	hud.build(sim, cfg.get("title", "Exhibition"), [kits[0][0], kits[1][0]])
	if cfg.has("quit_text"):
		hud.set_quit_text(cfg["quit_text"])
	hud.resume_requested.connect(_toggle_pause)
	hud.replay_requested.connect(_manual_replay)
	hud.camera_requested.connect(_cycle_camera)
	hud.quit_requested.connect(_quit)
	hud.continue_requested.connect(_continue)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.set_volume(float(Game.settings.get("volume", 0.8)) if Game else 0.8)
	prev_ball = sim.ball.pos
	hud.flash("KICK-OFF", "%s  vs  %s" % [sim.teams[0].name, sim.teams[1].name], 1.6)
	if humans.size() > 0:
		hud.hint.text = _hint_text(human_device[humans[0]["id"]])


static func color_dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _pick_kits() -> void:
	## Away team switches to its second kit (or white/black) when shirts clash.
	var t0: TeamData = sim.teams[0]
	var t1: TeamData = sim.teams[1]
	var a1 := t1.color1
	var a2 := t1.color2
	if color_dist(t0.color1, a1) < 0.6:
		a1 = t1.color2
		a2 = t1.color1
		if color_dist(t0.color1, a1) < 0.6:
			a1 = Color("f8fafc") if t0.color1.get_luminance() < 0.6 else Color("111827")
	kits = [[t0.color1, t0.color2], [a1, a2]]
	var gk_options := [Color("22c55e"), Color("a855f7"), Color("f97316"), Color("0ea5e9"), Color("111827"), Color("fde047")]
	var used: Array = [t0.color1, a1]
	for t in 2:
		var best: Color = gk_options[0]
		var bd := -1.0
		for c in gk_options:
			var d := 99.0
			for u in used:
				d = minf(d, color_dist(c, u))
			if d > bd:
				bd = d
				best = c
		used.append(best)
		kits[t].append(best)


func _hint_text(dev: String) -> String:
	if dev == "kb1":
		return "WASD move · J pass · K/Space shoot (hold = power) · L lob · I volley/bicycle · Q switch · Esc pause · C camera"
	if dev == "kb2":
		return "Arrows move · , pass · . shoot · / lob · ; volley/bicycle · ' switch"
	return "A pass · B shoot · Y lob · X volley/bicycle · LB/RB switch · Start pause · Back camera"


func _physics_process(_delta: float) -> void:
	if paused or in_replay or done:
		return
	prev_ball = sim.ball.pos
	for i in sim.players.size():
		prev_pos[i] = (sim.players[i] as SimPlayer).pos
	var inputs := {}
	for h in sim.humans:
		var dev: String = human_device[h["id"]]
		inputs[h["id"]] = router.consume(dev, cam.screen_to_world)
	# celebration choice
	if sim.phase == C.PH_GOAL and sim.phase_t > C.GOAL_PAUSE - 1.2 and not sim.goals_log.is_empty():
		var team: int = sim.goals_log.back()["team"]
		for h in sim.humans:
			if h["team"] != team:
				continue
			var f: InputFrame = inputs[h["id"]]
			if f.pass_pressed:
				sim.set_celebration(0)
			elif f.shoot_pressed:
				sim.set_celebration(1)
			elif f.lob_pressed:
				sim.set_celebration(2)
	sim.tick(inputs)
	_handle_events()
	if replay_pending and sim.phase == C.PH_GOAL and sim.phase_t <= C.GOAL_PAUSE - 1.3:
		replay_pending = false
		_start_replay(sim.replay_frames(4.6))


func _handle_events() -> void:
	for e in sim.events:
		match e["type"]:
			"kick":
				var pw: float = e["power"]
				sfx.play("kick_hard" if pw > 20.0 else "kick", -4.0 + clampf(pw / 30.0, 0.0, 1.0) * 6.0, randf_range(0.92, 1.08))
			"bounce":
				if e["speed"] > 3.0:
					sfx.play("bounce", -14.0 + clampf(e["speed"] / 20.0, 0.0, 1.0) * 8.0)
			"wall":
				if e["speed"] > 4.0:
					sfx.play("wall", -10.0 + clampf(e["speed"] / 25.0, 0.0, 1.0) * 8.0, randf_range(0.9, 1.1))
			"post":
				sfx.play("post", 0.0)
				arena.cheer(0.5)
			"net":
				if e["speed"] > 2.0:
					sfx.play("net", -6.0)
			"tackle", "trip":
				sfx.play("tackle", -3.0, randf_range(0.9, 1.1))
			"save":
				sfx.play("catch" if e["catch"] else "groan", -2.0)
				arena.cheer(0.4)
			"catch":
				sfx.play("catch", -6.0)
			"whistle":
				sfx.play("whistle", -4.0)
			"overtime":
				hud.flash("GOLDEN GOAL", "Next goal wins", 2.5)
				sfx.play("whistle", -2.0)
			"goal":
				var team: int = e["team"]
				var sc: int = e["scorer"]
				var who := ""
				if sc >= 0:
					who = (sim.players[sc] as SimPlayer).data.name
					if e["own"]:
						who += " (own goal)"
				hud.flash("GOAL!", "%s — %s" % [who, (sim.teams[team] as TeamData).name], 2.6)
				sfx.play("cheer", 0.0)
				sfx.play("goal_jingle", -3.0)
				arena.cheer(1.0)
				cam.shake = 1.0
				replay_pending = bool(cfg.get("replays", true))
			"fulltime":
				sfx.play("whistle_end", -2.0)
				hud.flash("FULL TIME", "", 1.5)
				_show_fulltime()


func _show_fulltime() -> void:
	done = true
	await get_tree().create_timer(1.6).timeout
	hud.banner.text = ""
	hud.sub_banner.text = ""
	hud.show_fulltime(sim, cfg.get("fulltime_note", ""))
	if OS.get_environment("OP_AUTOCONTINUE") != "":
		_continue()
	if OS.get_environment("OP_SHOT_ON") == "fulltime":
		Game.capture_in(60)


func _process(dt: float) -> void:
	router.poll(devices)
	for dev in devices:
		if router.pause_pressed(dev) and not done:
			if in_replay:
				_end_replay()
			else:
				_toggle_pause()
	if Input.is_action_just_pressed("ui_cancel") and paused:
		_toggle_pause()
	if not paused and not done and _camera_key():
		_cycle_camera()
	if in_replay:
		replay_pos += dt * 60.0 * 0.6
		if router.any_button_pressed(devices) and replay_pos > 30.0:
			_end_replay()
		elif replay_pos >= replay_frames.size() - 1:
			_end_replay()
		else:
			_pose_from_snapshot(replay_frames[int(replay_pos)], dt)
	else:
		var f := Engine.get_physics_interpolation_fraction() if not (paused or done) else 1.0
		_pose_from_sim(f, dt)
	arena.near_stand.visible = cam.mode != CameraRig.CAM_LOW
	var bp := ball_view.mesh.position
	cam.follow(Vector3(bp.x, 0, bp.z), dt)
	hud.update_hud(sim, dt)
	_update_power()


var _cam_key_prev := false


func _camera_key() -> bool:
	var down := Input.is_physical_key_pressed(KEY_C)
	for j in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(j, JOY_BUTTON_BACK):
			down = true
	var edge := down and not _cam_key_prev
	_cam_key_prev = down
	return edge


func _pose_from_sim(f: float, dt: float) -> void:
	var bp := prev_ball.lerp(sim.ball.pos, f)
	ball_view.show_at(bp, sim.ball.vel, dt)
	for i in sim.players.size():
		var p := sim.players[i] as SimPlayer
		var v := views[i] as PlayerView
		if not p.active:
			continue
		var pos: Vector2 = (prev_pos[i] as Vector2).lerp(p.pos, f)
		v.pose(pos, p.facing.angle(), p.state, p.anim, p.vel.length(), p.state_t, dt)
		var slot := -1
		if p.human >= 0:
			slot = _human_slot(p.human)
		v.set_controller(slot)


func _human_slot(id: int) -> int:
	for i in sim.humans.size():
		if sim.humans[i]["id"] == id:
			return int(sim.humans[i]["id"])
	return -1


func _pose_from_snapshot(s: PackedFloat32Array, dt: float) -> void:
	var bp := Vector3(s[0], s[1], s[2])
	var prev := ball_view.mesh.position
	ball_view.show_at(bp, (bp - prev) / maxf(dt, 0.001) * 0.6, dt)
	var i := 5
	for k in sim.players.size():
		var v := views[k] as PlayerView
		v.pose(Vector2(s[i], s[i + 1]), s[i + 2], int(s[i + 3]), int(s[i + 4]), s[i + 5], s[i + 6], dt * 0.6)
		v.set_controller(-1)
		i += 7


func _update_power() -> void:
	var shown := false
	for h in sim.humans:
		var idx: int = h["player"]
		if idx < 0:
			continue
		var p := sim.players[idx] as SimPlayer
		if p.charge_t >= 0.0 and not in_replay:
			var sp := cam.unproject_position(views[idx].position + Vector3(0, 2.3, 0))
			hud.show_power(sp, minf(p.charge_t / C.SHOT_CHARGE_TIME, 1.0))
			shown = true
	if not shown:
		hud.show_power(Vector2.ZERO, -1.0)


func _start_replay(frames: Array) -> void:
	if frames.size() < 30:
		return
	replay_frames = frames
	replay_pos = 0.0
	in_replay = true
	hud.replay_lbl.visible = true
	replay_cam_saved = cam.mode
	cam.mode = CameraRig.CAM_LOW if cam.mode != CameraRig.CAM_LOW else CameraRig.CAM_BROADCAST
	var s: PackedFloat32Array = frames[0]
	cam.snap_to(Vector3(s[0], 0, s[2]))
	if OS.get_environment("OP_SHOT_ON") == "replay":
		Game.capture_in(90)


func _end_replay() -> void:
	in_replay = false
	hud.replay_lbl.visible = false
	cam.mode = replay_cam_saved
	if paused:
		hud.show_pause(true, CameraRig.NAMES[cam.mode])


func _manual_replay() -> void:
	hud.show_pause(false, "")
	_start_replay(sim.replay_frames(6.0))


func _toggle_pause() -> void:
	if done:
		return
	paused = not paused
	hud.show_pause(paused, CameraRig.NAMES[cam.mode])
	if not paused and in_replay:
		_end_replay()


func _cycle_camera() -> void:
	cam.mode = (cam.mode + 1) % 4
	hud.flash("", "Camera: " + CameraRig.NAMES[cam.mode], 1.0)
	if paused:
		hud.show_pause(true, CameraRig.NAMES[cam.mode])
	if Game:
		Game.settings["camera"] = cam.mode
		Game.save_settings()


func _quit() -> void:
	paused = false
	done = true
	finished.emit(_result(true))


func _continue() -> void:
	finished.emit(_result(false))


func _result(aborted: bool) -> Dictionary:
	return {
		"aborted": aborted,
		"score": sim.score.duplicate(),
		"winner": sim.winner(),
		"stats": sim.stats.duplicate(true),
		"pstats": sim.pstats.duplicate(true),
		"goals": sim.goals_log.duplicate(true),
		"overtime": sim.overtime,
	}
