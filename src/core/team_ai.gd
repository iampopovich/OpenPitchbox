class_name TeamAI
extends RefCounted
## Outfield decision making for players without a human controller.


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
	var mul := 0.85
	var rank := sim.chase_rank(p)
	if team_has:
		target = support_spot(sim, p)
	elif sim.pass_target == p.index and owner < 0:
		target = sim.intercept_point(p)
		mul = 1.0
		_maybe_first_time(sim, p, lvl)
	elif rank == 0:
		target = sim.intercept_point(p)
		mul = float(lvl["pace"])
		if opp_has:
			var c := sim.players[owner] as SimPlayer
			var d := p.pos.distance_to(c.pos)
			if d < 1.8 and d > 0.7 and p.facing.dot((c.pos - p.pos).normalized()) > 0.6:
				if sim.rng.randf() < float(lvl["tackle"]) * dt:
					sim.start_slide(p, c.pos + c.vel * 0.15 - p.pos)
					return
	elif rank == 1 and owner >= 0:
		var g := sim.own_goal(p.team)
		target = bf + (g - bf).normalized() * minf(4.0, bf.distance_to(g) * 0.4)
		mul = 0.95
	else:
		target = defend_spot(sim, p)
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
	if l > 0.25:
		desired = to / l * minf(l * 3.0, p.max_speed() * mul)
	p.steer(desired, dt)


static func _maybe_first_time(sim: MatchSim, p: SimPlayer, lvl: Dictionary) -> void:
	if p.buf_action != C.ACT_NONE:
		return
	var dg := p.pos.distance_to(sim.goal_pos(p.team))
	var db := p.pos.distance_to(sim.ball_flat())
	if dg < 11.0 and db < 4.0 and sim.rng.randf() < float(lvl["onetouch"]) * 0.2:
		p.buffer(C.ACT_SHOOT, Vector2.ZERO)


static func support_spot(sim: MatchSim, p: SimPlayer) -> Vector2:
	var s: Array = sim.teams[p.team].slots()[p.slot - 1]
	var dirx := sim.attack_dir(p.team)
	var bf := sim.ball_flat()
	var ball_depth := bf.x * dirx / C.HX
	var x_rel: float = float(s[1]) * 0.55 + ball_depth * 0.45 + 0.25
	if s[0] == "FWD":
		x_rel = maxf(x_rel, 0.45) + sin(sim.time_played * 0.7 + p.index) * 0.08
	x_rel = clampf(x_rel, -0.85, 0.82)
	var z: float = float(s[2]) * C.HZ * 0.8
	z = lerpf(z, bf.y, 0.2)
	var spot := Vector2(dirx * x_rel * C.HX, z)
	# do not crowd the carrier
	var away := spot - bf
	if away.length() < 4.5:
		spot = bf + (away.normalized() if away.length() > 0.01 else Vector2(0, 1)) * 4.5
	spot.x = clampf(spot.x, -C.HX + 1.0, C.HX - 1.0)
	spot.y = clampf(spot.y, -C.HZ + 1.0, C.HZ - 1.0)
	return spot


static func defend_spot(sim: MatchSim, p: SimPlayer) -> Vector2:
	var s: Array = sim.teams[p.team].slots()[p.slot - 1]
	var dirx := sim.attack_dir(p.team)
	var bf := sim.ball_flat()
	var ball_depth := bf.x * dirx / C.HX
	var x_rel: float = float(s[1]) * 0.6 + ball_depth * 0.4 - 0.12
	x_rel = clampf(x_rel, -0.88, 0.6)
	var z: float = lerpf(float(s[2]) * C.HZ * 0.7, bf.y, 0.35)
	var spot := Vector2(dirx * x_rel * C.HX, z)
	# mark the nearest attacker in the zone a little
	var best: SimPlayer = null
	var bd := 6.0
	for so in sim.team_players(1 - p.team, true):
		var o := so as SimPlayer
		var d := o.pos.distance_to(spot)
		if d < bd:
			bd = d
			best = o
	if best != null:
		var g := sim.own_goal(p.team)
		var mark := best.pos + (g - best.pos).normalized() * 1.2
		spot = spot.lerp(mark, 0.45)
	return spot


static func _carrier(sim: MatchSim, p: SimPlayer, dt: float, lvl: Dictionary) -> void:
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
	var shoot_range := 12.0 + p.data.stat("sht") * 0.3
	var angle_ok := absf(p.pos.y) < 8.0 or dist_goal < 9.0
	if dist_goal < shoot_range and angle_ok:
		var want := float(lvl["shoot"]) * (1.6 - dist_goal / shoot_range)
		if pressure < 2.0:
			want += 0.25
		if rng.randf() < want:
			sim.shoot(p, Vector2.ZERO, rng.randf_range(0.7, 1.0))
			return
	# pass
	var t := sim.choose_pass_target(p, Vector2.ZERO, true)
	if t >= 0:
		var q := sim.players[t] as SimPlayer
		var open := sim.lane_open(p.pos, q.pos, p.team)
		var gain := (q.pos.x - p.pos.x) * dirx
		var wide := absf(p.pos.y) > C.HZ * 0.45 and (p.pos.x * dirx) > C.HX * 0.45
		if wide and absf(q.pos.y) < C.GOAL_HW * 2.0 and (q.pos.x * dirx) > C.HX * 0.5 and rng.randf() < 0.25:
			sim.lob_to(p, q.pos + q.vel * 0.7, t)
			return
		if pressure < 2.0 and rng.randf() < 0.6:
			if open < 0.8 and not q.is_gk() and rng.randf() < 0.4:
				sim.lob_to(p, q.pos, t)
			else:
				sim.pass_to(p, q)
			return
		if gain > 4.0 and open > 2.0 and rng.randf() < 0.3:
			sim.pass_to(p, q)
			return
	# deep in own half under pressure: clear it
	if (p.pos.x * dirx) < -C.HX * 0.6 and pressure < 1.5 and rng.randf() < 0.5:
		sim.lob_to(p, p.pos + Vector2(dirx * 18.0, rng.randf_range(-6.0, 6.0)), -1)
