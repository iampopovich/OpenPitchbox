extends SceneTree
## Debug: strong (15) vs weak (4) teams, per-match score, shots, saves, possession.

func _initialize() -> void:
	for seed in 6:
		var pair := TeamFactory.quick_pair(300 + seed, 15.0, 4.0)
		var sim := MatchSim.new()
		sim.setup(pair[0], pair[1], {"seed": seed, "length": 120.0})
		var guard := 0
		while sim.phase != C.PH_FULLTIME and guard < 60 * 60 * 5:
			sim.tick()
			guard += 1
		var s0: Dictionary = sim.stats[0]
		var s1: Dictionary = sim.stats[1]
		print("seed %d  %d-%d  shots %d/%d  saves %d/%d  poss %d/%d  tackles %d/%d" % [seed, sim.score[0], sim.score[1], s0["shots"], s1["shots"], s0["saves"], s1["saves"], s0["poss"], s1["poss"], s0["tackles"], s1["tackles"]])
	quit()
