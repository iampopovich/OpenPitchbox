class_name MatchSim
extends RefCounted
## The match engine. Pure logic, fixed step (C.TICK), seeded RNG: the same
## setup + the same inputs give the same match. Rendering reads its state.

# Aerial kinds (SimPlayer.anim while ST_AERIAL)
enum { AER_VOLLEY, AER_HEADER, AER_BICYCLE }

var teams: Array = []          # [TeamData, TeamData]
var players: Array = []        # Array[SimPlayer], 12 entries (team 0: 0..5, team 1: 6..11)
var ball := SimBall.new()
var rng := RandomNumberGenerator.new()

var phase: int = C.PH_KICKOFF
var phase_t: float = 0.0
var clock: float = 180.0       # seconds of play left (<= 0 and length <= 0 = untimed)
var length: float = 180.0
var overtime := false
var needs_winner := false
var ended_after_goal := false
var score := [0, 0]
var kickoff_team := 0
var difficulty := [1, 1]       # 0 easy .. 3 pro, per team
var practice := false
var roleplay := false
var auto_switch := true
var humans: Array = []         # [{id, team, player, input, switch_cd}]
var events: Array = []         # cleared every tick: [{type: String, ...}]
var tick_n: int = 0
var time_played: float = 0.0

var stats: Array = []          # per team {shots, on_target, tackles, saves, poss}
var pstats: Array = []         # per player {goals, assists, shots, tackles, saves}
var goals_log: Array = []      # [{team, scorer, assist, own, time}]

var pass_target: int = -1
var pass_from: int = -1
var pass_t: float = 0.0
var shot_id: int = 0
var touch_id: int = 0          # bumps on every touch; a keeper gets one try per touch
var shot_by: int = -1
var shot_live: bool = false
var ball_path := PackedVector3Array()
var chase_order: Array = [[], []]

# Replay ring buffer
const REPLAY_TICKS := int(C.REPLAY_SECONDS * 60.0) + 120
var replay_buf: Array = []
var replay_head: int = 0

const PATH_N := 40
const PATH_DT := 0.05

const DIFF := [
	{"react": 0.50, "shoot": 0.35, "tackle": 0.35, "aim": 1.6, "steal": 0.6, "gk": -0.10, "onetouch": 0.1, "pace": 0.88},
	{"react": 0.33, "shoot": 0.55, "tackle": 0.8, "aim": 1.15, "steal": 0.85, "gk": 0.0, "onetouch": 0.25, "pace": 0.95},
	{"react": 0.22, "shoot": 0.75, "tackle": 1.3, "aim": 0.9, "steal": 1.05, "gk": 0.04, "onetouch": 0.4, "pace": 1.0},
	{"react": 0.14, "shoot": 0.9, "tackle": 1.9, "aim": 0.75, "steal": 1.2, "gk": 0.08, "onetouch": 0.55, "pace": 1.0},
]


# ------------------------------------------------------------------ setup

func setup(t0: TeamData, t1: TeamData, opts: Dictionary = {}) -> void:
	teams = [t0, t1]
	rng.seed = int(opts.get("seed", 12345))
	length = float(opts.get("length", 180.0))
	clock = length
	needs_winner = bool(opts.get("needs_winner", false))
	difficulty = opts.get("difficulty", [1, 1]).duplicate()
	practice = bool(opts.get("practice", false))
	roleplay = bool(opts.get("roleplay", false))
	auto_switch = bool(opts.get("auto_switch", true))
	players.clear()
	pstats.clear()
	for t in 2:
		for s in 6:
			var p := SimPlayer.new()
			p.index = players.size()
			p.team = t
			p.slot = s
			p.data = teams[t].players[s]
			p.role = teams[t].role_of(s)
			if practice and t == 1 and s != 0:
				p.active = false
				p.pos = Vector2(0, 99)
			players.append(p)
			pstats.append({"goals": 0, "assists": 0, "shots": 0, "tackles": 0, "saves": 0})
	stats = []
	for t in 2:
		stats.append({"shots": 0, "on_target": 0, "tackles": 0, "saves": 0, "poss": 0})
	humans.clear()
	for h in opts.get("humans", []):
		humans.append({"id": int(h["id"]), "team": int(h["team"]), "player": -1, "input": InputFrame.new(), "switch_cd": 0.0})
	replay_buf.clear()
	replay_head = 0
	start_kickoff(int(opts.get("kickoff", 0)))


func attack_dir(team: int) -> float:
	return 1.0 if team == 0 else -1.0


func goal_pos(team: int) -> Vector2:
	## The goal `team` attacks.
	return Vector2(attack_dir(team) * C.HX, 0.0)


func own_goal(team: int) -> Vector2:
	return Vector2(-attack_dir(team) * C.HX, 0.0)


func ball_flat() -> Vector2:
	return Vector2(ball.pos.x, ball.pos.z)


func level(team: int) -> Dictionary:
	return DIFF[clampi(int(difficulty[team]), 0, 3)]


func team_has_human(team: int) -> bool:
	for h in humans:
		if h["team"] == team:
			return true
	return false


func human_of(id: int) -> Dictionary:
	for h in humans:
		if h["id"] == id:
			return h
	return {}


func possession_team() -> int:
	if ball.owner < 0:
		return -1
	return (players[ball.owner] as SimPlayer).team


func team_players(team: int, outfield_only: bool = false) -> Array:
	var out: Array = []
	for p in players:
		var sp := p as SimPlayer
		if sp.team == team and sp.active and (not outfield_only or not sp.is_gk()):
			out.append(sp)
	return out


func keeper(team: int) -> SimPlayer:
	return players[team * 6]


# ------------------------------------------------------------------ kickoff / positions

func formation_spot(p: SimPlayer, kickoff: bool) -> Vector2:
	var dirx := attack_dir(p.team)
	if p.is_gk():
		return own_goal(p.team) + Vector2(dirx * C.GK_LINE_OFFSET, 0)
	var s: Array = teams[p.team].slots()[p.slot - 1]
	var depth: float = s[1]
	var width: float = s[2]
	if kickoff:
		depth = minf(depth * 0.85, -0.1)
	return Vector2(dirx * depth * C.HX, width * C.HZ * 0.7)


func start_kickoff(team: int) -> void:
	kickoff_team = team
	phase = C.PH_KICKOFF
	phase_t = C.KICKOFF_DELAY
	ball.reset(Vector2.ZERO)
	pass_target = -1
	pass_from = -1
	shot_live = false
	var kicker: SimPlayer = null
	var best_depth := -99.0
	for p in players:
		var sp := p as SimPlayer
		if not sp.active:
			continue
		sp.vel = Vector2.ZERO
		sp.set_state(C.ST_RUN, 0.0)
		sp.buf_action = C.ACT_NONE
		sp.charge_t = -1.0
		sp.touch_cd = 0.0
		sp.pos = formation_spot(sp, true)
		sp.facing = Vector2(attack_dir(sp.team), 0)
		if sp.team == team and not sp.is_gk():
			var d: float = teams[team].slots()[sp.slot - 1][1]
			if d > best_depth:
				best_depth = d
				kicker = sp
		if sp.team != team and sp.pos.length() < 3.5:
			sp.pos = sp.pos.normalized() * 3.5 if sp.pos.length() > 0.01 else Vector2(-attack_dir(team) * 3.5, 0)
	if kicker != null:
		kicker.pos = Vector2(-attack_dir(team) * C.DRIBBLE_OFFSET, 0)
		ball.owner = kicker.index
		ball.last_touch = kicker.index
		kicker.steal_guard = 1.0
	_assign_humans_kickoff(kicker)
	events.append({"type": "whistle"})


func _assign_humans_kickoff(kicker: SimPlayer) -> void:
	for p in players:
		(p as SimPlayer).human = -1
	for h in humans:
		h["player"] = -1
	for h in humans:
		var team: int = h["team"]
		var choice: SimPlayer = null
		if kicker != null and kicker.team == team and kicker.human < 0:
			choice = kicker
		else:
			choice = _nearest_free_outfield(team, ball_flat())
		if choice != null:
			_give_control(h, choice)


func _nearest_free_outfield(team: int, at: Vector2) -> SimPlayer:
	var best: SimPlayer = null
	var bd := INF
	for sp in team_players(team, true):
		var p := sp as SimPlayer
		if p.human >= 0:
			continue
		var d := p.pos.distance_squared_to(at)
		if d < bd:
			bd = d
			best = p
	return best


func _give_control(h: Dictionary, p: SimPlayer) -> void:
	var cur: int = h["player"]
	if cur >= 0:
		(players[cur] as SimPlayer).human = -1
	h["player"] = p.index
	p.human = h["id"]
	p.charge_t = -1.0


# ------------------------------------------------------------------ main tick

func tick(inputs: Dictionary = {}) -> void:
	events.clear()
	tick_n += 1
	var dt := C.TICK
	for h in humans:
		if inputs.has(h["id"]):
			h["input"] = inputs[h["id"]]
	match phase:
		C.PH_KICKOFF:
			phase_t -= dt
			_keep_ball_with_owner()
			if phase_t <= 0.0:
				phase = C.PH_PLAY
		C.PH_PLAY:
			_play_tick(dt)
			time_played += dt
			if not overtime and length > 0.0:
				clock -= dt
				if clock <= 0.0 and phase == C.PH_PLAY:
					clock = 0.0
					if needs_winner and score[0] == score[1]:
						overtime = true
						events.append({"type": "overtime"})
					else:
						_full_time()
		C.PH_GOAL:
			phase_t -= dt
			_goal_tick(dt)
			if phase_t <= 0.0:
				if ended_after_goal:
					_full_time()
				else:
					var conceding := 1 if goals_log.back()["team"] == 0 else 0
					start_kickoff(conceding)
		C.PH_FULLTIME:
			for p in players:
				(p as SimPlayer).vel *= 0.9
	if phase != C.PH_FULLTIME:
		_record()


func _full_time() -> void:
	phase = C.PH_FULLTIME
	events.append({"type": "fulltime"})


func winner() -> int:
	if score[0] > score[1]:
		return 0
	if score[1] > score[0]:
		return 1
	return -1


func _play_tick(dt: float) -> void:
	for p in players:
		var sp := p as SimPlayer
		if not sp.active:
			continue
		sp.touch_cd = maxf(0.0, sp.touch_cd - dt)
		sp.steal_guard = maxf(0.0, sp.steal_guard - dt)
		if sp.buf_action != C.ACT_NONE:
			sp.buf_t -= dt
			if sp.buf_t <= 0.0:
				sp.buf_action = C.ACT_NONE
	pass_t -= dt
	if pass_t <= 0.0:
		pass_target = -1
	if ball.owner < 0:
		ball_path = ball.predict(PATH_N, PATH_DT)
	_compute_chase_order()
	for h in humans:
		h["switch_cd"] = maxf(0.0, h["switch_cd"] - dt)
		_human_control(h, dt)
	for p in players:
		var sp := p as SimPlayer
		if not sp.active:
			continue
		if sp.is_gk():
			_keeper_ai(sp, dt)
		elif sp.human < 0:
			TeamAI.think(self, sp, dt)
	for p in players:
		var sp := p as SimPlayer
		if sp.active:
			_update_state(sp, dt)
	_integrate_players(dt)
	# ball
	if ball.owner >= 0:
		_keep_ball_with_owner()
	else:
		for e in ball.step(dt):
			events.append({"type": e, "speed": ball.vel.length()})
	if ball.in_goal != 0:
		_goal_scored(0 if ball.in_goal > 0 else 1)
		return
	_aerials()
	_slides()
	_keeper_saves()
	_acquire()
	_steals(dt)
	var pt := possession_team()
	if pt >= 0:
		stats[pt]["poss"] += 1
	_auto_switch()


func _compute_chase_order() -> void:
	for t in 2:
		var arr: Array = []
		for sp in team_players(t, true):
			var p := sp as SimPlayer
			if p.state == C.ST_DOWN or p.state == C.ST_RECOVER:
				arr.append([99.0 + p.pos.distance_to(ball_flat()), p.index])
			else:
				arr.append([intercept_time(p), p.index])
		arr.sort_custom(func(a, b): return a[0] < b[0])
		var order: Array = []
		for a in arr:
			order.append(a[1])
		chase_order[t] = order


func chase_rank(p: SimPlayer) -> int:
	return chase_order[p.team].find(p.index)


func intercept_time(p: SimPlayer) -> float:
	if ball.owner >= 0:
		return p.pos.distance_to(ball_flat()) / p.max_speed()
	var sp := p.max_speed()
	for k in ball_path.size():
		var t := (k + 1) * PATH_DT
		var bp := ball_path[k]
		if bp.y > 2.0:
			continue
		if Vector2(bp.x, bp.z).distance_to(p.pos) <= sp * t + C.CONTROL_DIST:
			return t
	return PATH_N * PATH_DT + p.pos.distance_to(ball_flat()) / sp


func intercept_point(p: SimPlayer) -> Vector2:
	if ball.owner >= 0:
		var o := players[ball.owner] as SimPlayer
		return o.pos + o.vel * 0.25
	var sp := p.max_speed()
	for k in ball_path.size():
		var t := (k + 1) * PATH_DT
		var bp := ball_path[k]
		if bp.y > 2.0:
			continue
		var f := Vector2(bp.x, bp.z)
		if f.distance_to(p.pos) <= sp * t + C.CONTROL_DIST:
			return f
	if ball_path.size() > 0:
		var last := ball_path[ball_path.size() - 1]
		return Vector2(last.x, last.z)
	return ball_flat()


# ------------------------------------------------------------------ humans

func _human_control(h: Dictionary, dt: float) -> void:
	var idx: int = h["player"]
	if idx < 0:
		return
	var p := players[idx] as SimPlayer
	var inp: InputFrame = h["input"]
	if not p.can_act() or p.state == C.ST_HOLD:
		p.charge_t = -1.0
		return
	var has_ball := ball.owner == p.index
	var mv := inp.move.limit_length(1.0)
	var mul := C.CARRY_SPEED_MUL if has_ball else 1.0
	p.steer(mv * p.max_speed() * mul, dt)
	var dir := mv.normalized() if mv.length() > 0.2 else p.facing
	if has_ball:
		if inp.pass_pressed:
			var t := choose_pass_target(p, dir)
			if t >= 0:
				pass_to(p, players[t])
			else:
				kick(p, C.v3(dir * 12.0, 0.3), "pass")
		elif inp.lob_pressed:
			var lt := choose_pass_target(p, dir, true)
			if lt >= 0:
				lob_to(p, (players[lt] as SimPlayer).pos + (players[lt] as SimPlayer).vel * 0.6, lt)
			else:
				lob_to(p, p.pos + dir * 14.0, -1)
		elif inp.aerial_pressed:
			flick_up(p, dir)
		elif inp.shoot_pressed:
			p.charge_t = 0.0
		if p.charge_t >= 0.0 and ball.owner == p.index:
			p.charge_t += dt
			if not inp.shoot_held or p.charge_t >= C.SHOT_CHARGE_TIME:
				shoot(p, mv, minf(p.charge_t / C.SHOT_CHARGE_TIME, 1.0))
				p.charge_t = -1.0
		return
	p.charge_t = -1.0
	var bf := ball_flat()
	var near := p.pos.distance_to(bf)
	var loose := ball.owner < 0
	var airborne := loose and ball.pos.y > C.AERIAL_MIN_Y
	var to_me := p.pos - bf
	var incoming := loose and (pass_target == p.index or (near < 7.0 and Vector2(ball.vel.x, ball.vel.z).dot(to_me) > 0.0))
	var opp_has := ball.owner >= 0 and (players[ball.owner] as SimPlayer).team != p.team
	if inp.aerial_pressed or ((inp.shoot_pressed or inp.lob_pressed) and airborne and near < 4.0):
		if airborne and near < 5.0:
			p.buffer(C.ACT_AERIAL, dir)
		else:
			_start_aerial_anim(p, dir)
	elif inp.shoot_pressed:
		if incoming and not opp_has:
			p.buffer(C.ACT_SHOOT, mv)
		elif not (ball.owner >= 0 and not opp_has):
			start_slide(p, dir)
	elif inp.pass_pressed:
		if incoming:
			p.buffer(C.ACT_PASS, dir)
		elif not roleplay:
			_switch_to_nearest(h)
	elif inp.lob_pressed:
		if incoming:
			p.buffer(C.ACT_LOB, dir)
	if inp.switch_pressed and not roleplay:
		_switch_to_nearest(h)


func _switch_to_nearest(h: Dictionary) -> void:
	var team: int = h["team"]
	var best: SimPlayer = null
	var bd := INF
	var bf := ball_flat()
	for sp in team_players(team, true):
		var p := sp as SimPlayer
		if p.human >= 0 and p.index != h["player"]:
			continue
		if p.index == h["player"]:
			continue
		var d := intercept_time(p)
		if d < bd:
			bd = d
			best = p
	if best != null:
		_give_control(h, best)
		h["switch_cd"] = 0.4
		events.append({"type": "switch", "human": h["id"]})


func _auto_switch() -> void:
	if roleplay:
		return
	for h in humans:
		var idx: int = h["player"]
		if idx < 0:
			continue
		var p := players[idx] as SimPlayer
		var team: int = h["team"]
		# control follows the ball when a team-mate receives it
		if ball.owner >= 0 and ball.owner != idx:
			var o := players[ball.owner] as SimPlayer
			if o.team == team and o.human < 0 and not o.is_gk():
				_give_control(h, o)
				continue
		if not auto_switch or h["switch_cd"] > 0.0:
			continue
		# defending: hand control to whoever is clearly first to the ball
		if possession_team() != team and ball.owner != idx:
			var first: int = chase_order[team][0] if chase_order[team].size() > 0 else -1
			if first >= 0 and first != idx:
				var f := players[first] as SimPlayer
				if f.human < 0 and intercept_time(f) + 0.6 < intercept_time(p):
					_give_control(h, f)
					h["switch_cd"] = 0.9


# ------------------------------------------------------------------ actions

func kick(p: SimPlayer, v: Vector3, kind: String) -> void:
	ball.owner = -1
	if v.length() > C.BALL_MAX_SPEED:
		v = v.normalized() * C.BALL_MAX_SPEED
	ball.vel = v
	ball.pos.y = maxf(ball.pos.y, C.BALL_R)
	ball.last_touch = p.index
	touch_id += 1
	p.touch_cd = C.TOUCH_COOLDOWN
	p.buf_action = C.ACT_NONE
	if p.state == C.ST_RUN or p.state == C.ST_HOLD:
		p.set_state(C.ST_KICK, 0.22)
	if kind != "shot":
		shot_live = false
	events.append({"type": "kick", "kind": kind, "power": v.length(), "by": p.index})


func _noise_dir(d: Vector2, sigma_deg: float) -> Vector2:
	return d.rotated(deg_to_rad(rng.randfn(0.0, sigma_deg)))


func shoot(p: SimPlayer, hint: Vector2, power01: float, aim_z: float = 999.0, first_time: bool = false) -> void:
	var g := goal_pos(p.team)
	var from := ball_flat()
	if aim_z > 100.0:
		if hint.length() > 0.3 and absf(hint.normalized().y) > 0.3:
			aim_z = clampf(hint.normalized().y * 1.5, -1.0, 1.0) * (C.GOAL_HW - 0.4)
		else:
			var gk := keeper(1 - p.team)
			var side := -signf(gk.pos.y - from.y * 0.3)
			if side == 0.0:
				side = 1.0 if rng.randf() < 0.5 else -1.0
			aim_z = side * (C.GOAL_HW - 0.55)
	var target := Vector2(g.x, aim_z)
	var d := target - from
	var dist := d.length()
	var s01 := C.stat01(p.data.stat("sht"))
	var speed := lerpf(C.SHOT_MIN, C.SHOT_MAX, s01 * 0.55 + power01 * 0.45)
	var sigma := lerpf(8.0, 2.2, s01) * (1.0 + dist / 22.0)
	if p.human < 0:
		sigma *= level(p.team)["aim"]
	if first_time:
		sigma *= 1.15
		speed *= 1.05
	var dir := _noise_dir(d.normalized(), sigma)
	var t := dist / speed
	var h := rng.randf_range(0.25, 1.9)
	var vy := (h - ball.pos.y + 0.5 * C.GRAVITY * t * t) / maxf(t, 0.05)
	vy += rng.randfn(0.0, lerpf(1.2, 0.3, s01))
	kick(p, Vector3(dir.x * speed, vy, dir.y * speed), "shot")
	_register_shot(p)


func _register_shot(p: SimPlayer) -> void:
	shot_id += 1
	shot_by = p.index
	shot_live = true
	stats[p.team]["shots"] += 1
	pstats[p.index]["shots"] += 1
	if p.anim == 0 and p.state == C.ST_KICK:
		p.anim = 1


func pass_to(p: SimPlayer, q: SimPlayer, first_time: bool = false) -> void:
	var from := ball_flat()
	var lead_t := from.distance_to(q.pos) / 15.0
	var aim := q.pos + q.vel * lead_t * 0.85
	aim.x = clampf(aim.x, -C.HX + 0.6, C.HX - 0.6)
	aim.y = clampf(aim.y, -C.HZ + 0.6, C.HZ - 0.6)
	var d := aim - from
	var dist := d.length()
	var speed := clampf(C.PASS_MIN + dist * 0.75, C.PASS_MIN, C.PASS_MAX)
	var sigma := lerpf(7.0, 1.4, C.stat01(p.data.stat("pas")))
	if first_time:
		sigma *= 1.2
	var dir := _noise_dir(d.normalized(), sigma)
	kick(p, Vector3(dir.x * speed, 0.4, dir.y * speed), "pass")
	pass_target = q.index
	pass_from = p.index
	pass_t = 3.0


func lob_to(p: SimPlayer, at: Vector2, receiver: int) -> void:
	at.x = clampf(at.x, -C.HX + 1.0, C.HX - 1.0)
	at.y = clampf(at.y, -C.HZ + 1.0, C.HZ - 1.0)
	var from := ball_flat()
	var d := at - from
	var dist := maxf(d.length(), 2.0)
	var t := clampf(dist / C.LOB_SPEED_H, 0.75, 1.6)
	var vh := dist / t * (1.0 + C.BALL_AIR_DRAG * t * 0.5)
	var vy := (1.4 - ball.pos.y) / t + 0.5 * C.GRAVITY * t
	var sigma := lerpf(8.0, 2.0, C.stat01(p.data.stat("pas")))
	var dir := _noise_dir(d.normalized(), sigma)
	vh *= 1.0 + rng.randfn(0.0, 0.05)
	kick(p, Vector3(dir.x * vh, vy, dir.y * vh), "lob")
	if receiver >= 0:
		pass_target = receiver
		pass_from = p.index
		pass_t = t + 1.5


func flick_up(p: SimPlayer, dir: Vector2) -> void:
	## Pops the ball up in front of the carrier: sets up a volley or a bicycle kick.
	kick(p, C.v3(dir * 1.6 + p.vel * 0.5, 5.2), "flick")
	p.touch_cd = 0.2


func start_slide(p: SimPlayer, dir: Vector2) -> void:
	p.facing = dir.normalized() if dir.length() > 0.1 else p.facing
	p.set_state(C.ST_SLIDE, C.SLIDE_TIME)
	p.slide_done = false
	p.vel = p.facing * C.SLIDE_SPEED
	events.append({"type": "slide", "by": p.index})


func _start_aerial_anim(p: SimPlayer, dir: Vector2) -> void:
	var g := goal_pos(p.team) - p.pos
	var kind := AER_VOLLEY
	if p.facing.dot(g.normalized()) < -0.2:
		kind = AER_BICYCLE
	if dir.length() > 0.1:
		p.facing = dir.normalized()
	p.set_state(C.ST_AERIAL, C.AERIAL_TIME, kind)


func choose_pass_target(p: SimPlayer, dir: Vector2, prefer_forward: bool = false) -> int:
	var best := -1
	var best_s := -INF
	var dirx := attack_dir(p.team)
	for sq in team_players(p.team):
		var q := sq as SimPlayer
		if q.index == p.index:
			continue
		var to := q.pos - p.pos
		var dist := to.length()
		if dist < 2.0:
			continue
		var align := to.normalized().dot(dir.normalized()) if dir.length() > 0.1 else 0.0
		if dir.length() > 0.1 and align < 0.2:
			continue
		if q.is_gk() and align < 0.85:
			continue
		var s := align * 3.0 + _lane_open(p.pos, q.pos, p.team) * 0.45 - dist * 0.05
		s += to.x * dirx * (0.08 if prefer_forward else 0.03)
		if s > best_s:
			best_s = s
			best = q.index
	return best


func _lane_open(a: Vector2, b: Vector2, team: int) -> float:
	## Distance (capped at 4) from the closest opponent to the segment a-b.
	var m := 4.0
	for so in team_players(1 - team):
		var o := so as SimPlayer
		var q := Geometry2D.get_closest_point_to_segment(o.pos, a, b)
		m = minf(m, q.distance_to(o.pos))
	return m


func lane_open(a: Vector2, b: Vector2, team: int) -> float:
	return _lane_open(a, b, team)


# ------------------------------------------------------------------ state machine / movement

func _update_state(p: SimPlayer, dt: float) -> void:
	match p.state:
		C.ST_SLIDE:
			p.state_t -= dt
			var k := clampf(p.state_t / C.SLIDE_TIME, 0.0, 1.0)
			p.vel = p.facing * C.SLIDE_SPEED * sqrt(k)
			if p.state_t <= 0.0:
				p.set_state(C.ST_RECOVER, C.SLIDE_RECOVER)
				p.vel *= 0.2
		C.ST_RECOVER, C.ST_DOWN:
			p.state_t -= dt
			p.vel *= 0.85
			if p.state_t <= 0.0:
				p.set_state(C.ST_RUN, 0.0)
		C.ST_AERIAL:
			p.state_t -= dt
			p.vel *= 0.9
			if p.state_t <= 0.0:
				if p.anim == AER_BICYCLE:
					p.set_state(C.ST_DOWN, 0.45)
				else:
					p.set_state(C.ST_RUN, 0.0)
		C.ST_DIVE:
			p.state_t -= dt
			p.vel *= 0.93
			if p.state_t <= 0.0:
				p.set_state(C.ST_DOWN, 0.4)
		C.ST_KICK:
			p.state_t -= dt
			p.vel *= 0.92
			if p.state_t <= 0.0:
				p.set_state(C.ST_RUN, 0.0)
		C.ST_CELEBRATE:
			p.state_t -= dt


func _integrate_players(dt: float) -> void:
	for sp in players:
		var p := sp as SimPlayer
		if not p.active:
			continue
		p.pos += p.vel * dt
		if p.state != C.ST_SLIDE and p.state != C.ST_DIVE:
			p.update_facing(dt)
		_clamp_player(p)
	# separation
	for i in players.size():
		var a := players[i] as SimPlayer
		if not a.active:
			continue
		for j in range(i + 1, players.size()):
			var b := players[j] as SimPlayer
			if not b.active:
				continue
			var d := b.pos - a.pos
			var mind := C.PLAYER_R * 1.9
			var l2 := d.length_squared()
			if l2 < mind * mind and l2 > 0.000001:
				var l := sqrt(l2)
				var push := d / l * (mind - l) * 0.5
				a.pos -= push
				b.pos += push


func _clamp_player(p: SimPlayer) -> void:
	var r := C.PLAYER_R
	p.pos.x = clampf(p.pos.x, -C.HX + r, C.HX - r)
	p.pos.y = clampf(p.pos.y, -C.HZ + r, C.HZ - r)
	var cx := C.HX - C.CORNER_R
	var cz := C.HZ - C.CORNER_R
	if absf(p.pos.x) > cx and absf(p.pos.y) > cz:
		var c := Vector2(signf(p.pos.x) * cx, signf(p.pos.y) * cz)
		var d := p.pos - c
		var lim := C.CORNER_R - r
		if d.length() > lim:
			p.pos = c + d.normalized() * lim


func _keep_ball_with_owner() -> void:
	if ball.owner < 0:
		return
	var p := players[ball.owner] as SimPlayer
	if p.state == C.ST_HOLD:
		var hp := p.pos + p.facing * 0.38
		ball.pos = Vector3(hp.x, 1.05, hp.y)
		ball.vel = Vector3.ZERO
		return
	var target := p.pos + p.facing * C.DRIBBLE_OFFSET
	# dribbling into the goal mouth releases the ball so it can roll in
	if absf(target.x) > C.HX - 0.25 and absf(target.y) < C.GOAL_HW - 0.2:
		ball.owner = -1
		ball.vel = Vector3(p.vel.x * 1.2 + signf(target.x) * 2.0, 0.0, p.vel.y)
		p.touch_cd = 0.3
		return
	target.x = clampf(target.x, -C.HX + C.BALL_R, C.HX - C.BALL_R)
	target.y = clampf(target.y, -C.HZ + C.BALL_R, C.HZ - C.BALL_R)
	ball.pos.x = lerpf(ball.pos.x, target.x, 0.55)
	ball.pos.z = lerpf(ball.pos.z, target.y, 0.55)
	ball.pos.y = C.BALL_R
	ball.vel = Vector3(p.vel.x, 0.0, p.vel.y)
	ball.spin += p.vel.length() * C.TICK / C.BALL_R


# ------------------------------------------------------------------ ball contests

func _acquire() -> void:
	if ball.owner >= 0:
		return
	var bf := ball_flat()
	var best: SimPlayer = null
	var bd := INF
	for sp in players:
		var p := sp as SimPlayer
		if not p.can_touch() or p.is_gk():
			continue
		if p.state == C.ST_SLIDE:
			continue
		if ball.pos.y > C.CONTROL_MAX_Y:
			continue
		var d := p.pos.distance_to(bf)
		if d < C.CONTROL_DIST and d < bd:
			bd = d
			best = p
	if best == null:
		return
	var p := best
	# buffered first-time action
	if p.buf_action == C.ACT_SHOOT:
		ball.owner = p.index
		shoot(p, p.buf_dir, 0.75, 999.0, true)
		return
	if p.buf_action == C.ACT_PASS:
		var t := choose_pass_target(p, p.buf_dir)
		if t >= 0:
			ball.owner = p.index
			pass_to(p, players[t], true)
			return
	if p.buf_action == C.ACT_LOB:
		var lt := choose_pass_target(p, p.buf_dir, true)
		ball.owner = p.index
		if lt >= 0:
			lob_to(p, (players[lt] as SimPlayer).pos, lt)
		else:
			lob_to(p, p.pos + p.buf_dir.normalized() * 14.0, -1)
		return
	var rel := (Vector2(ball.vel.x, ball.vel.z) - p.vel).length()
	var limit := 15.0 + p.data.stat("pas") * 0.4
	if rel < limit:
		_gain(p)
	else:
		# too hot to trap: bounces off the player
		var n := (bf - p.pos).normalized()
		var v := Vector2(ball.vel.x, ball.vel.z)
		var vn := v.dot(n)
		if vn < 0.0:
			v -= n * vn * 1.4
		v *= 0.55
		ball.vel = Vector3(v.x, absf(ball.vel.y) * 0.3 + 1.0, v.y)
		ball.last_touch = p.index
		touch_id += 1
		p.touch_cd = 0.2
		shot_live = false
		events.append({"type": "deflect", "by": p.index})


func _gain(p: SimPlayer) -> void:
	var prev := possession_team()
	ball.owner = p.index
	if ball.last_touch >= 0 and (players[ball.last_touch] as SimPlayer).team != p.team:
		pass_from = -1
	ball.last_touch = p.index
	ball.vel = Vector3.ZERO
	p.steal_guard = 0.35
	shot_live = false
	if pass_target == p.index:
		pass_target = -1
	if prev != p.team:
		events.append({"type": "control", "by": p.index})


func _steals(dt: float) -> void:
	if ball.owner < 0:
		return
	var c := players[ball.owner] as SimPlayer
	if c.state == C.ST_HOLD or c.steal_guard > 0.0:
		return
	var bf := ball_flat()
	for so in players:
		var o := so as SimPlayer
		if o.team == c.team or not o.can_act() or o.is_gk() or o.touch_cd > 0.0:
			continue
		if o.pos.distance_to(bf) > C.STEAL_DIST:
			continue
		var mult: float = 1.0 if o.human >= 0 else float(level(o.team)["steal"])
		var att := float(o.data.stat("tkl")) + 5.0
		var dfn := float(c.data.stat("pas") + c.data.stat("spd")) * 0.5 + 5.0
		var rate := C.STEAL_RATE * mult * att / dfn
		if rng.randf() < 1.0 - exp(-rate * dt):
			c.touch_cd = 0.4
			_gain(o)
			o.steal_guard = 0.5
			stats[o.team]["tackles"] += 1
			pstats[o.index]["tackles"] += 1
			events.append({"type": "tackle", "by": o.index})
			return


func _slides() -> void:
	for sp in players:
		var p := sp as SimPlayer
		if p.state != C.ST_SLIDE or p.slide_done:
			continue
		var hp := p.pos + p.facing * 0.5
		# ball
		var bf := ball_flat()
		var owner_team := possession_team()
		if ball.pos.y < 0.6 and hp.distance_to(bf) < C.SLIDE_REACH and owner_team != p.team:
			if ball.owner >= 0:
				var c := players[ball.owner] as SimPlayer
				c.knock_down()
				stats[p.team]["tackles"] += 1
				pstats[p.index]["tackles"] += 1
			p.slide_done = true
			var dir := p.facing.rotated(rng.randf_range(-0.45, 0.45))
			var spd := 7.0 + p.data.stat("tkl") * 0.25
			ball.owner = -1
			ball.vel = Vector3(dir.x * spd, 1.2, dir.y * spd)
			ball.last_touch = p.index
			touch_id += 1
			shot_live = false
			events.append({"type": "tackle", "by": p.index, "slide": true})
			continue
		# bodies
		for so in players:
			var o := so as SimPlayer
			if o.team == p.team or not o.active or o.state == C.ST_DOWN or o.is_gk():
				continue
			if o.pos.distance_to(hp) < 0.75:
				o.knock_down()
				p.slide_done = true
				events.append({"type": "trip", "by": p.index})
				if ball.owner == o.index:
					ball.owner = -1
					ball.vel = C.v3(p.facing * 4.0, 1.0)


func _aerials() -> void:
	if ball.owner >= 0:
		return
	var bf := ball_flat()
	for sp in players:
		var p := sp as SimPlayer
		if p.buf_action != C.ACT_AERIAL or not p.can_act() or p.touch_cd > 0.0:
			continue
		if ball.pos.y < C.AERIAL_MIN_Y or ball.pos.y > C.AERIAL_MAX_Y:
			continue
		if p.pos.distance_to(bf) > C.AERIAL_REACH:
			continue
		var g := goal_pos(p.team)
		var to_goal := (g - p.pos).normalized()
		var kind := AER_VOLLEY
		if ball.pos.y >= C.HEADER_MIN_Y and p.facing.dot(to_goal) > -0.3:
			kind = AER_HEADER
		elif p.facing.dot(to_goal) < 0.15:
			kind = AER_BICYCLE
		var s01 := C.stat01(p.data.stat("sht"))
		var speed: float
		var vy: float
		var aim_z := clampf(p.buf_dir.y, -1.0, 1.0) * (C.GOAL_HW - 0.4) if absf(p.buf_dir.y) > 0.3 else rng.randf_range(-1.0, 1.0) * (C.GOAL_HW - 0.6)
		var d := Vector2(g.x, aim_z) - bf
		var sigma := lerpf(16.0, 6.0, s01) * (1.0 + d.length() / 18.0)
		if p.human < 0:
			sigma *= level(p.team)["aim"]
		match kind:
			AER_HEADER:
				speed = lerpf(13.0, 19.0, s01)
				vy = rng.randf_range(-3.0, 1.5)
			AER_BICYCLE:
				speed = lerpf(18.0, 26.0, s01)
				vy = rng.randf_range(-1.0, 3.5)
				sigma *= 1.25
			_:
				speed = lerpf(19.0, 28.0, s01)
				vy = rng.randf_range(-0.5, 3.5)
		var is_shot := d.length() < 18.0
		if not is_shot:
			# far from goal: an aerial is a clearance up the pitch
			sigma = 30.0
			speed = rng.randf_range(13.0, 19.0)
			vy = rng.randf_range(4.0, 7.0)
		var dir := _noise_dir(d.normalized(), sigma)
		p.facing = to_goal if kind != AER_BICYCLE else -to_goal
		kick(p, Vector3(dir.x * speed, vy, dir.y * speed), "aerial")
		p.set_state(C.ST_AERIAL, C.AERIAL_TIME, kind)
		if is_shot:
			_register_shot(p)
		events.append({"type": "aerial", "kind": kind, "by": p.index})
		return


# ------------------------------------------------------------------ keeper

func _shot_threat(gk: SimPlayer) -> Dictionary:
	if ball.owner >= 0:
		return {}
	var gx := own_goal(gk.team).x
	var vx := ball.vel.x
	if vx * signf(gx) <= 2.0:
		return {}
	var t := (gx - ball.pos.x) / vx
	if t < 0.0 or t > 1.6:
		return {}
	var z := ball.pos.z + ball.vel.z * t
	var y := ball.pos.y + ball.vel.y * t - 0.5 * C.GRAVITY * t * t
	if absf(z) > C.GOAL_HW + 0.8 or y > C.GOAL_H + 0.6:
		return {}
	return {"t": t, "z": z, "y": maxf(y, 0.0)}


func _keeper_ai(p: SimPlayer, dt: float) -> void:
	var dirx := attack_dir(p.team)
	var g := own_goal(p.team)
	if p.state == C.ST_HOLD:
		p.vel *= 0.8
		p.gk_hold_t -= dt
		p.facing = Vector2(dirx, 0)
		if p.gk_hold_t <= 0.0:
			p.set_state(C.ST_RUN, 0.0)
			var t := choose_pass_target(p, Vector2(dirx, 0))
			if t < 0:
				t = choose_pass_target(p, Vector2.ZERO)
			if t >= 0:
				var q := players[t] as SimPlayer
				if q.pos.distance_to(p.pos) > 16.0:
					lob_to(p, q.pos, t)
				else:
					pass_to(p, q)
			else:
				lob_to(p, p.pos + Vector2(dirx * 18.0, rng.randf_range(-5, 5)), -1)
		return
	if not p.can_act():
		return
	var lvl := level(p.team)
	var bf := ball_flat()
	var home := g + Vector2(dirx * C.GK_LINE_OFFSET, 0)
	var target := home
	var mul := 1.0
	var threat := _shot_threat(p)
	if not threat.is_empty():
		target = Vector2(home.x, clampf(threat["z"], -C.GOAL_HW + 0.25, C.GOAL_HW - 0.25))
		mul = 1.35
		var gap := target.distance_to(p.pos)
		if gap > 0.5 and threat["t"] < 0.55 and p.gk_tried_shot != touch_id:
			var side := 1 if (target - p.pos).y > 0 else -1
			p.set_state(C.ST_DIVE, C.GK_DIVE_TIME, side)
			p.vel = (target - p.pos).normalized() * minf(gap / maxf(threat["t"], 0.15), 9.0)
			p.facing = Vector2(dirx, 0)
			return
	else:
		var in_box := absf(bf.x - g.x) < C.BOX_DEPTH and absf(bf.y) < C.BOX_HW
		var owner_opp := ball.owner >= 0 and (players[ball.owner] as SimPlayer).team != p.team
		if ball.owner < 0 and in_box and ball.ground_speed() < 10.0 and ball.pos.y < 2.2:
			target = intercept_point(p)
			mul = 1.2
		elif owner_opp and in_box and bf.distance_to(g) < 7.0:
			target = home.lerp(bf, 0.55)
		else:
			var to := bf - g
			var off := clampf(to.length() * 0.1, C.GK_LINE_OFFSET, 2.3)
			target = g + to.normalized() * off
			target.y = clampf(target.y, -C.GOAL_HW + 0.2, C.GOAL_HW - 0.2)
		# stay in the box
		target.x = g.x + dirx * clampf((target.x - g.x) * dirx, C.PLAYER_R, C.BOX_DEPTH - 0.5)
		target.y = clampf(target.y, -C.BOX_HW + 0.5, C.BOX_HW - 0.5)
	var to_t := target - p.pos
	var desired := to_t * 6.0
	p.steer(desired, dt, mul * float(lvl["pace"]) if p.human < 0 else mul)
	var look := bf - p.pos
	if look.length() > 0.1 and p.vel.length() < 1.5:
		p.facing = p.facing.lerp(look.normalized(), 0.2).normalized()


func _keeper_saves() -> void:
	if ball.owner >= 0:
		return
	for t in 2:
		var p := keeper(t)
		if not p.active or not (p.state == C.ST_RUN or p.state == C.ST_DIVE):
			continue
		if p.touch_cd > 0.0:
			continue
		var bf := ball_flat()
		var d := bf.distance_to(p.pos)
		var reach := C.GK_REACH + (C.GK_DIVE_REACH * 0.7 if p.state == C.ST_DIVE else 0.0)
		var max_y := 2.55 if p.state == C.ST_DIVE else 2.45
		if d > reach or ball.pos.y > max_y:
			continue
		var g := own_goal(t)
		if absf(p.pos.x - g.x) > C.BOX_DEPTH + 0.5:
			continue
		var speed := ball.vel.length()
		var k01 := C.stat01(p.data.stat("kep"))
		var toward_goal := ball.vel.x * signf(g.x) > 2.0
		if speed < 9.0 or not toward_goal and speed < 16.0:
			_catch(p)
			continue
		if p.gk_tried_shot == touch_id:
			continue
		p.gk_tried_shot = touch_id
		var chance := 0.6 + k01 * 0.38 - (speed - 20.0) * 0.02 - (d / reach) * 0.2
		if p.human < 0:
			chance += float(level(t)["gk"])
		chance = clampf(chance, 0.08, 0.96)
		if rng.randf() < chance:
			stats[t]["saves"] += 1
			pstats[p.index]["saves"] += 1
			if shot_live and shot_by >= 0 and (players[shot_by] as SimPlayer).team != t:
				stats[1 - t]["on_target"] += 1
			if speed < 14.0 + p.data.stat("kep") * 0.45 and d < 1.1:
				_catch(p)
				events.append({"type": "save", "by": p.index, "catch": true})
			else:
				var dirx := attack_dir(t)
				var out := Vector3(dirx * speed * rng.randf_range(0.25, 0.45), rng.randf_range(2.5, 6.0), rng.randf_range(-7.0, 7.0))
				ball.vel = out
				ball.last_touch = p.index
				p.touch_cd = 0.4
				shot_live = false
				events.append({"type": "save", "by": p.index, "catch": false})
		else:
			events.append({"type": "miss_save", "by": p.index})


func _catch(p: SimPlayer) -> void:
	ball.owner = p.index
	ball.last_touch = p.index
	ball.vel = Vector3.ZERO
	pass_target = -1
	pass_from = -1
	shot_live = false
	p.set_state(C.ST_HOLD, 0.0)
	p.gk_hold_t = C.GK_HOLD_TIME
	events.append({"type": "catch", "by": p.index})


# ------------------------------------------------------------------ goals

func _goal_scored(team: int) -> void:
	score[team] += 1
	var scorer := ball.last_touch
	var own := scorer >= 0 and (players[scorer] as SimPlayer).team != team
	var assist := -1
	if not own and pass_from >= 0 and pass_from != scorer and (players[pass_from] as SimPlayer).team == team:
		assist = pass_from
	if scorer >= 0 and not own:
		pstats[scorer]["goals"] += 1
		if shot_live:
			stats[team]["on_target"] += 1
	if assist >= 0:
		pstats[assist]["assists"] += 1
	goals_log.append({"team": team, "scorer": scorer, "assist": assist, "own": own, "time": time_played})
	phase = C.PH_GOAL
	phase_t = C.GOAL_PAUSE
	ended_after_goal = overtime or (length > 0.0 and clock <= 0.0)
	events.append({"type": "goal", "team": team, "scorer": scorer, "own": own})
	# celebration
	for sp in players:
		var p := sp as SimPlayer
		p.buf_action = C.ACT_NONE
		p.charge_t = -1.0
		if p.state != C.ST_DOWN:
			p.set_state(C.ST_RUN, 0.0)
	if scorer >= 0 and not own:
		var s := players[scorer] as SimPlayer
		s.set_state(C.ST_CELEBRATE, C.GOAL_PAUSE, rng.randi_range(0, 2))


func set_celebration(kind: int) -> void:
	if goals_log.is_empty():
		return
	var sc: int = goals_log.back()["scorer"]
	if sc >= 0 and (players[sc] as SimPlayer).state == C.ST_CELEBRATE:
		(players[sc] as SimPlayer).anim = clampi(kind, 0, 2)


func _goal_tick(dt: float) -> void:
	ball.step(dt)
	var last: Dictionary = goals_log.back()
	var scorer: int = last["scorer"]
	var team: int = last["team"]
	var spot := Vector2.ZERO
	if scorer >= 0:
		spot = (players[scorer] as SimPlayer).pos
	for sp in players:
		var p := sp as SimPlayer
		if not p.active:
			continue
		match p.state:
			C.ST_CELEBRATE:
				var away := Vector2(attack_dir(p.team) * 0.4, signf(p.pos.y) if p.pos.y != 0.0 else 1.0).normalized()
				p.steer(away * p.max_speed() * 0.8, dt)
				p.state_t -= dt
			C.ST_RUN:
				if p.team == team and not p.is_gk() and scorer >= 0:
					var to := spot - p.pos
					p.steer(to.normalized() * p.max_speed() * 0.8 if to.length() > 1.6 else Vector2.ZERO, dt)
				else:
					p.steer(Vector2.ZERO, dt)
			_:
				_update_state(p, dt)
		p.pos += p.vel * dt
		p.update_facing(dt)
		_clamp_player(p)


# ------------------------------------------------------------------ replay

func _record() -> void:
	var snap := PackedFloat32Array()
	snap.resize(5 + players.size() * 7)
	snap[0] = ball.pos.x
	snap[1] = ball.pos.y
	snap[2] = ball.pos.z
	snap[3] = ball.spin
	snap[4] = float(phase)
	var i := 5
	for sp in players:
		var p := sp as SimPlayer
		snap[i] = p.pos.x
		snap[i + 1] = p.pos.y
		snap[i + 2] = p.facing.angle()
		snap[i + 3] = float(p.state)
		snap[i + 4] = float(p.anim)
		snap[i + 5] = p.vel.length()
		snap[i + 6] = p.state_t
		i += 7
	if replay_buf.size() < REPLAY_TICKS:
		replay_buf.append(snap)
	else:
		replay_buf[replay_head] = snap
		replay_head = (replay_head + 1) % REPLAY_TICKS


func replay_frames(seconds_before_now: float) -> Array:
	## Chronological snapshots covering the last `seconds_before_now` seconds.
	var out: Array = []
	var n := replay_buf.size()
	var want := mini(n, int(seconds_before_now * 60.0))
	var start := (replay_head - want + n) % n if n == REPLAY_TICKS else n - want
	for k in want:
		out.append(replay_buf[(start + k) % n])
	return out
