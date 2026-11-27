extends RefCounted
## Match engine: physics, rules, invariants, determinism, balance.

var runner


func _sim(seed: int, opts: Dictionary = {}) -> MatchSim:
	var pair := TeamFactory.quick_pair(seed)
	var sim := MatchSim.new()
	var o := {"seed": seed, "length": 180.0}
	o.merge(opts, true)
	sim.setup(pair[0], pair[1], o)
	return sim


func _invariants(sim: MatchSim) -> String:
	var b := sim.ball.pos
	if is_nan(b.x) or is_nan(b.y) or is_nan(b.z):
		return "ball NaN"
	if absf(b.z) > C.HZ + 0.01 or absf(b.x) > C.HX + C.GOAL_DEPTH + 0.01 or b.y < C.BALL_R - 0.01:
		return "ball left the arena: %s" % b
	if absf(b.x) > C.HX + 0.01 and (absf(b.z) > C.GOAL_HW + 0.01 or b.y > C.GOAL_H + 0.01):
		return "ball behind the boards: %s" % b
	for sp in sim.players:
		var p := sp as SimPlayer
		if not p.active:
			continue
		if is_nan(p.pos.x) or absf(p.pos.x) > C.HX or absf(p.pos.y) > C.HZ:
			return "player %d off pitch %s" % [p.index, p.pos]
	return ""


func test_ball_rolls_and_stops() -> void:
	var b := SimBall.new()
	b.reset(Vector2.ZERO)
	b.vel = Vector3(6, 0, 0)
	for i in 600:
		b.step(C.TICK)
	runner.check(b.ground_speed() < 0.01, "ball should stop, speed %f" % b.ground_speed())
	runner.check(b.pos.x > 3.0 and b.pos.x < 8.0, "rolled %f m" % b.pos.x)


func test_side_board_rebounds() -> void:
	var b := SimBall.new()
	b.reset(Vector2(0, 10))
	b.vel = Vector3(0, 0, 15)
	var hit := false
	for i in 60:
		if b.step(C.TICK).has("wall"):
			hit = true
	runner.check(hit, "no wall event")
	runner.check(b.vel.z < 0.0, "should travel back, vz=%f" % b.vel.z)
	runner.check(absf(b.pos.z) <= C.HZ, "inside")


func test_shot_into_empty_goal_scores() -> void:
	var b := SimBall.new()
	b.reset(Vector2(10, 0.5))
	b.vel = Vector3(25, 2.0, 0.3)
	for i in 120:
		b.step(C.TICK)
		if b.in_goal != 0:
			break
	runner.check(b.in_goal == 1, "expected goal at +x, got %d (pos %s)" % [b.in_goal, b.pos])


func test_shot_over_bar_comes_back() -> void:
	var b := SimBall.new()
	b.reset(Vector2(14, 0))
	b.vel = Vector3(24, 12.0, 0)
	for i in 180:
		b.step(C.TICK)
	runner.check(b.in_goal == 0, "no goal over the bar")
	runner.check(b.pos.x < C.HX, "ball came back into play: %s" % b.pos)


func test_wide_shot_hits_end_board() -> void:
	var b := SimBall.new()
	b.reset(Vector2(14, 6))
	b.vel = Vector3(24, 1.0, 0)
	for i in 120:
		b.step(C.TICK)
	runner.check(b.in_goal == 0, "no goal from wide")
	runner.check(b.vel.x < 0.0 or b.pos.x < C.HX, "rebounded")


func test_corner_keeps_ball_inside() -> void:
	var b := SimBall.new()
	b.reset(Vector2(15, 7))
	b.vel = Vector3(20, 0, 14)
	for i in 240:
		b.step(C.TICK)
		var cx := C.HX - C.CORNER_R
		var cz := C.HZ - C.CORNER_R
		if absf(b.pos.x) > cx and absf(b.pos.z) > cz and absf(b.pos.x) <= C.HX:
			var d := Vector2(absf(b.pos.x) - cx, absf(b.pos.z) - cz).length()
			if d > C.CORNER_R - C.BALL_R + 0.01:
				runner.check(false, "ball outside the rounded corner")
				return


func test_post_deflects() -> void:
	var b := SimBall.new()
	b.reset(Vector2(15, C.GOAL_HW))
	b.vel = Vector3(20, 0.5, 0)
	var post := false
	for i in 60:
		if b.step(C.TICK).has("post"):
			post = true
			break
	runner.check(post, "should hit the post")


func test_ai_match_runs_to_full_time() -> void:
	var sim := _sim(7)
	var ticks := 0
	var limit := 60 * 60 * 6
	while sim.phase != C.PH_FULLTIME and ticks < limit:
		sim.tick()
		ticks += 1
		var bad := _invariants(sim)
		if bad != "":
			runner.check(false, "tick %d: %s" % [ticks, bad])
			return
	runner.check(sim.phase == C.PH_FULLTIME, "match did not finish")
	var goals: int = sim.score[0] + sim.score[1]
	print("    score %d-%d, shots %d/%d, saves %d/%d" % [sim.score[0], sim.score[1], sim.stats[0]["shots"], sim.stats[1]["shots"], sim.stats[0]["saves"], sim.stats[1]["saves"]])
	runner.check(goals <= 16, "too many goals: %d" % goals)
	runner.check(sim.stats[0]["shots"] + sim.stats[1]["shots"] >= 4, "teams should shoot")


func test_balance_over_seeds() -> void:
	var total_goals := 0
	var total_shots := 0
	var total_saves := 0
	var draws := 0
	var n := 8
	for seed in n:
		var sim := _sim(100 + seed, {"length": 120.0})
		var guard := 0
		while sim.phase != C.PH_FULLTIME and guard < 60 * 60 * 5:
			sim.tick()
			guard += 1
		total_goals += sim.score[0] + sim.score[1]
		total_shots += sim.stats[0]["shots"] + sim.stats[1]["shots"]
		total_saves += sim.stats[0]["saves"] + sim.stats[1]["saves"]
		if sim.score[0] == sim.score[1]:
			draws += 1
	var avg := float(total_goals) / n
	print("    avg goals %.2f, shots %.1f, saves %.1f, draws %d/%d" % [avg, float(total_shots) / n, float(total_saves) / n, draws, n])
	runner.check(avg >= 1.0 and avg <= 9.0, "2-minute matches should average 1..9 goals, got %.2f" % avg)
	runner.check(total_saves > 0, "keepers should save something")


func test_determinism() -> void:
	var a := _sim(42, {"length": 60.0})
	var b := _sim(42, {"length": 60.0})
	for i in 3600:
		a.tick()
		b.tick()
	runner.check(a.score == b.score, "scores differ")
	runner.check(a.ball.pos.is_equal_approx(b.ball.pos), "ball differs %s vs %s" % [a.ball.pos, b.ball.pos])


func test_strong_team_wins_more() -> void:
	var wins := 0
	var losses := 0
	for seed in 6:
		var pair := TeamFactory.quick_pair(300 + seed, 15.0, 4.0)
		var sim := MatchSim.new()
		sim.setup(pair[0], pair[1], {"seed": seed, "length": 120.0})
		var guard := 0
		while sim.phase != C.PH_FULLTIME and guard < 60 * 60 * 5:
			sim.tick()
			guard += 1
		if sim.score[0] > sim.score[1]:
			wins += 1
		elif sim.score[0] < sim.score[1]:
			losses += 1
	print("    strong vs weak: %d wins, %d losses" % [wins, losses])
	runner.check(wins >= 4 and losses <= 1, "ratings should matter")


func test_golden_goal_decides() -> void:
	var sim := _sim(9, {"length": 20.0, "needs_winner": true})
	var guard := 0
	while sim.phase != C.PH_FULLTIME and guard < 60 * 60 * 10:
		sim.tick()
		guard += 1
	runner.check(sim.phase == C.PH_FULLTIME, "finished")
	runner.check(sim.winner() >= 0, "a cup match needs a winner: %s" % [sim.score])


func test_practice_has_only_keeper() -> void:
	var sim := _sim(3, {"practice": true, "length": 0.0})
	var active := 0
	for sp in sim.players:
		if (sp as SimPlayer).team == 1 and (sp as SimPlayer).active:
			active += 1
	runner.check(active == 1, "practice: one opponent (keeper), got %d" % active)
	for i in 600:
		sim.tick()
	runner.check(_invariants(sim) == "", _invariants(sim))


func test_human_shot_after_kickoff() -> void:
	var sim := _sim(5, {"humans": [{"id": 0, "team": 0}]})
	var h := sim.human_of(0)
	runner.check(h["player"] >= 0, "human got a player")
	# run toward goal and shoot
	var shot := false
	for i in 400:
		var f := InputFrame.new()
		f.move = Vector2(1, 0)
		if i == 150:
			f.shoot_pressed = true
			f.shoot_held = true
		elif i > 150 and i < 160:
			f.shoot_held = true
		sim.tick({0: f})
		for e in sim.events:
			if e["type"] == "kick" and e["kind"] == "shot":
				shot = true
	runner.check(shot, "human should be able to shoot")


func test_buffered_first_time_shot() -> void:
	var sim := _sim(11)
	sim.phase = C.PH_PLAY
	var p := sim.players[5] as SimPlayer
	sim.ball.owner = -1
	sim.ball.pos = Vector3(8, C.BALL_R, 0)
	sim.ball.vel = Vector3(6, 0, 0)
	p.pos = Vector2(10.5, 0)
	p.vel = Vector2.ZERO
	p.human = 0
	p.buffer(C.ACT_SHOOT, Vector2.ZERO)
	var fired := false
	for i in 40:
		sim.tick()
		for e in sim.events:
			if e["type"] == "kick" and e["kind"] == "shot" and e["by"] == p.index:
				fired = true
		if fired:
			break
	runner.check(fired, "buffered shot should fire on first touch")


func test_bicycle_kick_from_high_ball() -> void:
	var sim := _sim(12)
	sim.phase = C.PH_PLAY
	var p := sim.players[5] as SimPlayer
	p.human = 0
	p.pos = Vector2(14, 0)
	p.facing = Vector2(-1, 0)
	p.vel = Vector2.ZERO
	sim.ball.owner = -1
	sim.ball.pos = Vector3(13.2, 1.2, 0)
	sim.ball.vel = Vector3(0, 0.5, 0)
	for sp in sim.players:
		if sp != p:
			(sp as SimPlayer).active = false
	p.buffer(C.ACT_AERIAL, Vector2.ZERO)
	var kind := -1
	for i in 10:
		sim.tick()
		for e in sim.events:
			if e["type"] == "aerial":
				kind = e["kind"]
	runner.check(kind == MatchSim.AER_BICYCLE, "expected bicycle kick, got %d" % kind)
	runner.check(sim.ball.vel.x > 10.0, "ball goes toward the goal: %s" % sim.ball.vel)


func test_replay_buffer() -> void:
	var sim := _sim(13)
	for i in 900:
		sim.tick()
	var frames := sim.replay_frames(4.0)
	runner.check(frames.size() == 240, "4 s of frames, got %d" % frames.size())


func test_team_keeps_shape() -> void:
	## Teams must not collapse onto the ball: spacing and crowding limits.
	var nn_sum := 0.0
	var nn_n := 0
	var crowd := 0.0
	var samples := 0
	for seed in 2:
		var sim := _sim(500 + seed, {"length": 90.0})
		var k := 0
		while sim.phase != C.PH_FULLTIME and k < 60 * 60 * 4:
			sim.tick()
			k += 1
			if k % 30 != 0 or sim.phase != C.PH_PLAY:
				continue
			samples += 1
			var bf := sim.ball_flat()
			for sp in sim.players:
				var a := sp as SimPlayer
				if a.is_gk():
					continue
				if a.pos.distance_to(bf) < 5.0:
					crowd += 1.0
				var nn := 99.0
				for sq in sim.players:
					var b := sq as SimPlayer
					if b != a and b.team == a.team and not b.is_gk():
						nn = minf(nn, a.pos.distance_to(b.pos))
				nn_sum += nn
				nn_n += 1
	var mean_nn := nn_sum / nn_n
	var mean_crowd := crowd / samples
	print("    nearest team-mate %.2f m, players near ball %.2f" % [mean_nn, mean_crowd])
	runner.check(mean_nn >= 4.5, "team-mates too close: %.2f m" % mean_nn)
	runner.check(mean_crowd <= 3.8, "too many players around the ball: %.2f" % mean_crowd)


func test_back_net_slopes() -> void:
	## A high shot into the top of the goal is stopped by the sloping net before the back bar.
	var b := SimBall.new()
	b.reset(Vector2(15, 0))
	b.pos.y = 2.0
	b.vel = Vector3(22, 0.5, 0)
	var max_x := 0.0
	for i in 90:
		b.step(C.TICK)
		if b.pos.y > 1.6:
			max_x = maxf(max_x, b.pos.x)
	runner.check(b.in_goal == 1, "goal")
	runner.check(max_x < C.HX + C.GOAL_DEPTH - 0.35, "high ball stopped by the slope, reached %.2f" % max_x)


func test_foul_from_behind_gives_free_kick_and_card() -> void:
	var sim := _sim(21)
	sim.phase = C.PH_PLAY
	var victim := sim.players[5] as SimPlayer
	var tackler := sim.players[7] as SimPlayer
	victim.pos = Vector2(0, 0)
	victim.facing = Vector2(1, 0)
	victim.vel = Vector2(4, 0)
	sim.ball.owner = victim.index
	victim.steal_guard = 0.0
	tackler.pos = Vector2(-1.2, 0)
	tackler.facing = Vector2(1, 0)
	sim.start_slide(tackler, Vector2(1, 0))
	var foul := {}
	for i in 30:
		sim.tick()
		for e in sim.events:
			if e["type"] == "foul":
				foul = e
		if not foul.is_empty():
			break
	runner.check(not foul.is_empty(), "foul expected")
	runner.check(foul.get("card", "") != "", "card for a tackle from behind")
	runner.check(sim.phase == C.PH_SETPIECE and sim.sp_team == 0, "free kick to the fouled team")


func test_penalty_in_box() -> void:
	var sim := _sim(22)
	sim.phase = C.PH_PLAY
	var victim := sim.players[5] as SimPlayer
	sim._foul(sim.players[8], victim, false)
	victim.pos = Vector2(C.HX - 2.0, 1.0)
	sim.phase = C.PH_PLAY
	sim.ball.owner = -1
	sim._foul(sim.players[8], victim, false)
	runner.check(sim.sp_penalty, "foul in the box gives a penalty")
	runner.check(absf(sim.ball.pos.x - (C.HX - C.PENALTY_SPOT)) < 0.01, "ball on the spot")
	var guard := 0
	var shot := false
	while guard < 400 and not shot:
		sim.tick()
		guard += 1
		for e in sim.events:
			if e["type"] == "kick" and e["kind"] == "shot":
				shot = true
	runner.check(shot, "AI takes the penalty")


# ---- regressions from play-testing

func test_fast_ball_beside_post_is_no_goal() -> void:
	## A hard shot that hits the end board just outside the post must bounce out, not
	## be pulled into the net (ball moves ~0.57 m per tick at full speed).
	for dz: float in [0.12, 0.2, 0.35, 0.6]:
		var b := SimBall.new()
		b.reset(Vector2(C.HX - 6.0, C.GOAL_HW + dz))
		b.vel = Vector3(C.BALL_MAX_SPEED, 0.6, 0.0)
		for i in 90:
			b.step(C.TICK)
			if b.in_goal != 0:
				break
		runner.check(b.in_goal == 0, "board %.2f m outside the post counted as a goal" % dz)
		runner.check(b.vel.x < 0.0, "ball should rebound off the board (dz %.2f)" % dz)


func test_fast_ball_over_bar_is_no_goal() -> void:
	for h: float in [C.GOAL_H + 0.1, C.GOAL_H + 0.4]:
		var b := SimBall.new()
		b.reset(Vector2(C.HX - 3.0, 0.0))
		b.pos.y = h
		b.vel = Vector3(C.BALL_MAX_SPEED, 0.5, 0.0)
		for i in 60:
			b.step(C.TICK)
			if b.in_goal != 0:
				break
		runner.check(b.in_goal == 0, "ball over the bar at %.2f m counted as a goal" % h)


func test_keeper_body_always_stops_ball_at_him() -> void:
	## A shot straight at the keeper never goes through him.
	var through := 0
	for seed in 40:
		var sim := _sim(100 + seed)
		sim.phase = C.PH_PLAY
		var gk := sim.keeper(1)
		var g := sim.own_goal(1)
		gk.pos = Vector2(g.x - C.GK_LINE_OFFSET, 0.3)
		gk.vel = Vector2.ZERO
		gk.state = C.ST_RUN
		for sp in sim.players:
			var q := sp as SimPlayer
			if q != gk:
				q.active = false
		sim.ball.owner = -1
		sim.ball.last_touch = 3
		sim.touch_id += 1
		sim.ball.pos = Vector3(g.x - 10.0, 0.9, 0.3)
		sim.ball.vel = Vector3(28.0, 0.8, 0.0)
		for i in 60:
			sim.tick()
			if sim.phase == C.PH_GOAL:
				through += 1
				break
	runner.check(through == 0, "%d of 40 shots at the keeper's body went in" % through)


func test_lob_reaches_receiver() -> void:
	## A lob to a standing team-mate is controlled by him (chest/feet), not lost behind him.
	var ok := 0
	for seed in 10:
		var sim := _sim(200 + seed)
		sim.phase = C.PH_PLAY
		var a := sim.players[2] as SimPlayer
		var r := sim.players[3] as SimPlayer
		for sp in sim.players:
			var q := sp as SimPlayer
			if q != a and q != r:
				q.active = false
		a.pos = Vector2(-8, 0)
		r.pos = Vector2(6, 3)
		a.vel = Vector2.ZERO
		r.vel = Vector2.ZERO
		sim.ball.reset(a.pos + Vector2(0.5, 0))
		sim.ball.owner = a.index
		sim.lob_to(a, r.pos, r.index)
		for i in 180:
			sim.tick()
			if sim.ball.owner == r.index:
				ok += 1
				break
	runner.check(ok >= 9, "lobs controlled by the receiver: %d/10" % ok)


func test_kick_winds_up_before_ball_leaves() -> void:
	var sim := _sim(13)
	sim.phase = C.PH_PLAY
	var p := sim.players[3] as SimPlayer
	sim.ball.reset(p.pos + p.facing * 0.5)
	sim.ball.owner = p.index
	p.state = C.ST_RUN
	sim.pass_to(p, sim.players[4])
	runner.check(sim.ball.owner == p.index, "ball should stay at the foot during the backswing")
	var left_at := -1
	for i in 20:
		sim.tick()
		if sim.ball.owner != p.index:
			left_at = i
			break
	runner.check(left_at >= 3 and left_at <= 9, "ball left after %d ticks" % left_at)


func test_one_presser_per_team() -> void:
	## Without the ball a team sends one player at it; the rest keep their places.
	var chasers := 0
	var samples := 0
	var sim := _sim(21)
	for i in 60 * 60:
		sim.tick()
		if sim.phase != C.PH_PLAY or i % 30 != 0 or sim.ball.owner < 0:
			continue
		var t := 1 - (sim.players[sim.ball.owner] as SimPlayer).team
		var bf := sim.ball_flat()
		for sp in sim.team_players(t, true):
			var q := sp as SimPlayer
			if q.pos.distance_to(bf) < 3.0:
				chasers += 1
		samples += 1
	var avg := float(chasers) / maxf(samples, 1)
	print("    defenders within 3 m of the carrier: %.2f" % avg)
	runner.check(avg < 1.6, "too many defenders on the ball: %.2f" % avg)


func test_speed_stat_matters() -> void:
	var slow := PlayerData.new()
	slow.stats["spd"] = 5
	var fast := PlayerData.new()
	fast.stats["spd"] = 17
	var a := SimPlayer.new()
	a.data = slow
	var b := SimPlayer.new()
	b.data = fast
	runner.check(b.max_speed() - a.max_speed() > 2.0, "speed 17 vs 5 should differ by > 2 m/s (%.2f)" % (b.max_speed() - a.max_speed()))
