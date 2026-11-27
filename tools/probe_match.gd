extends SceneTree
## Debug: match statistics breakdown. godot --headless --script res://tools/probe_match.gd


func _initialize() -> void:
	var kinds := {}
	var goals_by := {}
	var saves := 0
	var miss := 0
	var total_goals := 0
	for seed in 4:
		var pair := TeamFactory.quick_pair(100 + seed)
		var sim := MatchSim.new()
		sim.setup(pair[0], pair[1], {"seed": seed, "length": 120.0})
		var last_kind := ""
		var guard := 0
		while sim.phase != C.PH_FULLTIME and guard < 60 * 60 * 5:
			sim.tick()
			guard += 1
			for e in sim.events:
				match e["type"]:
					"kick":
						kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
						last_kind = e["kind"]
					"aerial":
						kinds["aerial_" + str(e["kind"])] = kinds.get("aerial_" + str(e["kind"]), 0) + 1
					"goal":
						goals_by[last_kind] = goals_by.get(last_kind, 0) + 1
						total_goals += 1
					"save":
						saves += 1
					"miss_save":
						miss += 1
	print("kicks: ", kinds)
	print("goals after: ", goals_by, " total ", total_goals)
	print("saves ", saves, " missed saves ", miss)
	# over the bar trace
	var b := SimBall.new()
	b.reset(Vector2(14, 0))
	b.vel = Vector3(24, 9.0, 0)
	for i in 180:
		var ev := b.step(C.TICK)
		if ev.size() > 0 or i % 10 == 0:
			print(i, " ", b.pos, " ", b.vel, " ", ev, " goal=", b.in_goal)
		if b.in_goal != 0:
			break
	quit()
