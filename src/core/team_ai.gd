class_name TeamAI
extends RefCounted
## Outfield decision making for players without a human controller.
## Team shape: a block that slides with the ball, roles keep their lanes and depth,
## one player presses, one covers, the rest hold zones and mark runners inside them.

const SPACING := 8.0         # wanted distance between team-mates in the shape


static func think(sim: MatchSim, p: SimPlayer, dt: float) -> void:
	if not p.can_act():
		return
	var lvl := sim.level(p.team)
	p.think_t -= dt
	var owner := sim.ball.owner
	if owner == p.index:
		_carrier(sim, p, dt, lvl)
		return
	var team_has := owner >= 0 and (sim.players[owner] as SimPlayer).team == p.team
	var opp_has := owner >= 0 and not team_has
	var bf := sim.ball_flat()
	var target: Vector2
	var mul := 0.8
	var spread := true
	var is_presser: bool = sim.presser[p.team] == p.index
	var is_cover: bool = sim.cover[p.team] == p.index
	if team_has:
		target = attack_spot(sim, p)
	elif sim.pass_target == p.index and owner < 0:
		target = sim.intercept_point(p)
		mul = 1.0
		spread = false
		_maybe_first_time(sim, p, lvl)
	elif owner < 0 and sim.pass_target >= 0 and (sim.players[sim.pass_target] as SimPlayer).team == p.team:
		# a team-mate is about to receive: keep the shape instead of running at the ball
		target = attack_spot(sim, p)
	elif is_presser:
		target = sim.intercept_point(p)
		mul = float(lvl["pace"])
		spread = false
		if opp_has:
			var c := sim.players[owner] as SimPlayer
			var d := p.pos.distance_to(c.pos)
			var from_behind := (c.pos - p.pos).dot(c.facing) > 0.2
			if d < 1.8 and d > 0.7 and p.facing.dot((c.pos - p.pos).normalized()) > 0.6 and (not from_behind or sim.rng.randf() < 0.03):
				if sim.rng.randf() < float(lvl["tackle"]) * dt:
					sim.start_slide(p, c.pos + c.vel * 0.15 - p.pos)
					return
	elif is_cover and p.pos.distance_to(bf) < 18.0:
		# cover: goal-side of the ball, 5 m behind the presser, on the inside lane
		var g := sim.own_goal(p.team)
		target = bf + (g - bf).normalized() * minf(5.0, bf.distance_to(g) * 0.45)
		target.y = lerpf(target.y, 0.0, 0.25)
		mul = 0.85
	else:
		target = defend_spot(sim, p)
	if spread:
		target = _spread(sim, p, target)
	# aerial chance: high loose ball dropping near this player
	if owner < 0 and sim.ball.pos.y > 0.7 and p.buf_action == C.ACT_NONE:
		var d2 := p.pos.distance_to(bf)
		if d2 < 2.2 and sim.ball.vel.y < 1.0 and sim.rng.randf() < 0.08:
			var near_goal := p.pos.distance_to(sim.goal_pos(p.team)) < 14.0
			var near_own := p.pos.distance_to(sim.own_goal(p.team)) < 12.0
			if near_goal or near_own:
				p.buffer(C.ACT_AERIAL, Vector2.ZERO)
	_move_to(p, target, dt, mul)


static func _move_to(p: SimPlayer, target: Vector2, dt: float, mul: float) -> void:
	var to := target - p.pos
	var l := to.length()
	var desired := Vector2.ZERO
	if l > 0.35:
		desired = to / l * minf(l * 2.5, p.max_speed() * mul)
	p.steer(desired, dt)


static func _maybe_first_time(sim: MatchSim, p: SimPlayer, lvl: Dictionary) -> void:
	if p.buf_action != C.ACT_NONE:
		return
	var dg := p.pos.distance_to(sim.goal_pos(p.team))
	var db := p.pos.distance_to(sim.ball_flat())
	if dg < 11.0 and db < 4.0 and sim.rng.randf() < float(lvl["onetouch"]) * 0.2:
		p.buffer(C.ACT_SHOOT, Vector2.ZERO)


static func _spread(sim: MatchSim, p: SimPlayer, spot: Vector2) -> Vector2:
	## Pushes a shape position away from team-mates so the team never bunches.
	var push := Vector2.ZERO
	for so in sim.team_players(p.team, true):
		var q := so as SimPlayer
		if q.index == p.index:
			continue
		var d := spot - q.pos
		var l := d.length()
		if l < SPACING and l > 0.01:
			push += d / l * (SPACING - l) * 0.8
	spot += push
	spot.x = clampf(spot.x, -C.HX + 1.0, C.HX - 1.0)
	spot.y = clampf(spot.y, -C.HZ + 1.0, C.HZ - 1.0)
	return spot


static func _depth_limits(role: String, attacking: bool) -> Vector2:
	if attacking:
		match role:
			"DEF":
				return Vector2(-0.82, 0.2)
			"MID":
				return Vector2(-0.45, 0.6)
			_:
				return Vector2(0.15, 0.82)
	match role:
		"DEF":
			return Vector2(-0.9, -0.1)
		"MID":
			return Vector2(-0.78, 0.3)
		_:
			return Vector2(-0.35, 0.55)


static func attack_spot(sim: MatchSim, p: SimPlayer) -> Vector2:
	var s: Array = sim.teams[p.team].slots()[p.slot - 1]
	var role: String = s[0]
	var dirx := sim.attack_dir(p.team)
	var bf := sim.ball_flat()
	var ball_d := bf.x * dirx / C.HX
	var lim := _depth_limits(role, true)
	var x_rel := clampf(float(s[1]) * 0.5 + ball_d * 0.55 + 0.22, lim.x, lim.y)
	# width: stretch the pitch when we have the ball
	var w: float = float(s[2])
	var z := w * C.HZ * 0.8
	if role == "FWD":
		z = w * C.HZ * 0.6 + bf.y * 0.15 + sin(sim.time_played * 0.6 + p.index) * 1.5
		x_rel += sin(sim.time_played * 0.45 + p.index * 1.7) * 0.06
	var spot := Vector2(dirx * x_rel * C.HX, z)
	# the closest team-mate offers a short, open option to the carrier
	if sim.ball.owner >= 0:
		var c := sim.players[sim.ball.owner] as SimPlayer
		if _closest_mate(sim, c) == p.index:
			var side := signf(p.pos.y - c.pos.y)
			if side == 0.0:
				side = 1.0
			var a := c.pos + Vector2(dirx * 6.0, side * 6.0)
			if sim.lane_open(c.pos, a, p.team) > 1.2:
				spot = a
			else:
				spot = c.pos + Vector2(-dirx * 2.0, side * 6.5)
	return spot


static func _closest_mate(sim: MatchSim, c: SimPlayer) -> int:
	var best := -1
	var bd := INF
	for so in sim.team_players(c.team, true):
		var q := so as SimPlayer
		if q.index == c.index or q.human >= 0:
			continue
		var d := q.pos.distance_squared_to(c.pos)
		if d < bd:
			bd = d
			best = q.index
	return best


static func defend_spot(sim: MatchSim, p: SimPlayer) -> Vector2:
	var s: Array = sim.teams[p.team].slots()[p.slot - 1]
	var role: String = s[0]
	var dirx := sim.attack_dir(p.team)
	var bf := sim.ball_flat()
	var ball_d := bf.x * dirx / C.HX
	var lim := _depth_limits(role, false)
	var x_rel := clampf(float(s[1]) * 0.45 + ball_d * 0.5 - 0.15, lim.x, lim.y)
	if role != "FWD":
		# stay goal-side of the ball
		x_rel = maxf(minf(x_rel, ball_d - 0.1), lim.x)
	# the block shifts towards the ball side but keeps its width
	var z := float(s[2]) * C.HZ * 0.55 + bf.y * 0.3
	var spot := Vector2(dirx * x_rel * C.HX, z)
	# mark a runner inside this zone (not the carrier: the presser has him)
	var best: SimPlayer = null
	var bd := 5.0
	for so in sim.team_players(1 - p.team, true):
		var o := so as SimPlayer
		if o.index == sim.ball.owner or o.pos.distance_to(bf) < 5.0:
			continue
		var d := o.pos.distance_to(spot)
		if d < bd:
			bd = d
			best = o
	if best != null:
		var g := sim.own_goal(p.team)
		var mark := best.pos + (g - best.pos).normalized() * 1.6
		spot = spot.lerp(mark, 0.6)
	return spot


static func _carrier(sim: MatchSim, p: SimPlayer, dt: float, lvl: Dictionary) -> void:
	if sim.penalty_lock:
		# penalty: compose, then shoot
		p.steer(Vector2.ZERO, dt)
		if p.think_t <= 0.0:
			sim.shoot(p, Vector2.ZERO, sim.rng.randf_range(0.75, 1.0))
		return
	var g := sim.goal_pos(p.team)
	var to_goal := g - p.pos
	var dist_goal := to_goal.length()
	var dirx := sim.attack_dir(p.team)
	# dribble direction: to goal, away from opponents and boards
	var dir := to_goal.normalized()
	var pressure := 99.0
	for so in sim.team_players(1 - p.team):
		var o := so as SimPlayer
		var d := o.pos - p.pos
		var l := d.length()
		if l < pressure and d.dot(dir) > -0.5:
			pressure = l
		if l < 4.0 and l > 0.01:
			dir -= d / l * (4.0 - l) * 0.35
	if absf(p.pos.y) > C.HZ - 2.0:
		dir.y -= signf(p.pos.y) * 0.6
	if dir.length() < 0.1:
		dir = Vector2(dirx, 0)
	dir = dir.normalized()
	p.steer(dir * p.max_speed() * C.CARRY_SPEED_MUL * float(lvl["pace"]), dt)
	if p.think_t > 0.0:
		return
	p.think_t = float(lvl["react"]) * sim.rng.randf_range(0.7, 1.3)
	var rng := sim.rng
	# shoot
	var shoot_range := 9.5 + p.data.stat("sht") * 0.3
	var angle_ok := absf(p.pos.y) < 8.0 or dist_goal < 9.0
	if dist_goal < shoot_range and angle_ok:
		var want := float(lvl["shoot"]) * (1.3 - dist_goal / shoot_range)
		if pressure < 2.0:
			want += 0.25
		if rng.randf() < want:
			sim.shoot(p, Vector2.ZERO, rng.randf_range(0.7, 1.0))
			return
	# pass: forward and open first, the safe ball under pressure
	var t := sim.choose_pass_target(p, Vector2.ZERO, true)
	if t >= 0:
		var q := sim.players[t] as SimPlayer
		var open := sim.lane_open(p.pos, q.pos, p.team)
		var gain := (q.pos.x - p.pos.x) * dirx
		var wide := absf(p.pos.y) > C.HZ * 0.45 and (p.pos.x * dirx) > C.HX * 0.45
		if wide and absf(q.pos.y) < C.GOAL_HW * 2.0 and (q.pos.x * dirx) > C.HX * 0.5 and rng.randf() < 0.3:
			sim.lob_to(p, q.pos + q.vel * 0.7, t)
			return
		if pressure < 3.0 and rng.randf() < 0.8:
			if open < 0.8 and not q.is_gk() and rng.randf() < 0.4:
				sim.lob_to(p, q.pos, t)
			else:
				sim.pass_to(p, q)
			return
		if gain > 2.0 and open > 1.6 and rng.randf() < 0.55:
			sim.pass_to(p, q)
			return
	# deep in own half under pressure: clear it
	if (p.pos.x * dirx) < -C.HX * 0.6 and pressure < 1.5 and rng.randf() < 0.5:
		sim.lob_to(p, p.pos + Vector2(dirx * 18.0, rng.randf_range(-6.0, 6.0)), -1)
