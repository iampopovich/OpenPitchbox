class_name InputBot
extends Node
## Debug: drives keyboard 1 through real InputEventKey events (the same path a person uses)
## and reports what the match engine did with them. Enabled with OP_INPUT_BOT=<seconds>.

var view: MatchView
var t := 0.0
var limit := 40.0
var held := {}
var counts := {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 11
	limit = float(OS.get_environment("OP_INPUT_BOT"))


func _key(code: Key, down: bool) -> void:
	if held.get(code, false) == down:
		return
	held[code] = down
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _tap(code: Key) -> void:
	_key(code, true)
	get_tree().create_timer(0.08).timeout.connect(func(): _key(code, false))


func _process(dt: float) -> void:
	if view == null or view.sim == null:
		return
	t += dt
	for e in view.sim.events:
		var k: String = e["type"]
		if k == "kick":
			k = "kick_" + str(e["kind"])
		if e.has("by") and e["by"] >= 0 and (view.sim.players[e["by"]] as SimPlayer).human >= 0:
			counts["human_" + k] = int(counts.get("human_" + k, 0)) + 1
		elif k in ["switch", "goal", "foul"]:
			counts[k] = int(counts.get(k, 0)) + 1
	var h := view.sim.human_of(0)
	if h.is_empty() or h["player"] < 0:
		return
	var p := view.sim.players[h["player"]] as SimPlayer
	var bf := view.sim.ball_flat()
	var has := view.sim.ball.owner == p.index
	# steer: toward the ball without it, toward the goal with it (screen space, broadcast camera)
	var target := view.sim.goal_pos(0) if has else bf
	var d := target - p.pos
	_key(KEY_D, d.x > 0.5)
	_key(KEY_A, d.x < -0.5)
	_key(KEY_S, d.y > 0.5)
	_key(KEY_W, d.y < -0.5)
	if int(t * 10.0) % 7 == 0 and rng.randf() < 0.3:
		if has:
			var r := rng.randf()
			if p.pos.distance_to(view.sim.goal_pos(0)) < 13.0 or r < 0.25:
				_tap(KEY_K)
			elif r < 0.6:
				_tap(KEY_J)
			elif r < 0.8:
				_tap(KEY_L)
			else:
				_tap(KEY_I)
		else:
			var r2 := rng.randf()
			if p.pos.distance_to(bf) < 2.0 and view.sim.possession_team() == 1 and r2 < 0.5:
				_tap(KEY_K)
			elif r2 < 0.2:
				_tap(KEY_Q)
	if t >= limit:
		var keys := counts.keys()
		keys.sort()
		var parts: Array = []
		for k in keys:
			parts.append("%s=%d" % [k, counts[k]])
		print("INPUT-BOT ", " ".join(parts), " score=", view.sim.score)
		get_tree().quit()
