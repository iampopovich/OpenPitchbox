extends SceneTree
## Debug: traces one lob to a standing receiver tick by tick.

func _initialize() -> void:
	var pair := TeamFactory.quick_pair(201)
	var sim := MatchSim.new()
	sim.setup(pair[0], pair[1], {"seed": 201})
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
	for i in 150:
		sim.tick()
		if i % 4 == 0 or sim.ball.owner == r.index:
			var b := sim.ball.pos
			print("t%3d owner %2d ball (%.1f %.2f %.1f) recv (%.1f %.1f) d %.2f tgt %d st %d" % [i, sim.ball.owner, b.x, b.y, b.z, r.pos.x, r.pos.y, r.pos.distance_to(Vector2(b.x, b.z)), sim.pass_target, r.state])
		if sim.ball.owner == r.index:
			break
	quit()
