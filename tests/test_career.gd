extends RefCounted
## Career: schedule, tables, playoffs, promotion/relegation, upgrades, save/load.

var runner


func _new() -> Career:
	return Career.create(77)


func test_structure() -> void:
	var c := _new()
	runner.check(c.teams.size() == 64, "64 teams")
	for d in Career.DIVS:
		runner.check(c.divisions[d].size() == 16, "16 per division")
	runner.check(c.user_div() == 3, "user starts in Division 4")
	runner.check(c.user().rating() < c.team(c.divisions[0][0]).rating(), "user weaker than a Division 1 club")


func test_round_robin_complete() -> void:
	var c := _new()
	for d in Career.DIVS:
		var seen := {}
		for r in Career.ROUNDS:
			var in_round := {}
			for g in c.fixtures[d][r]:
				runner.check(not in_round.has(g[0]) and not in_round.has(g[1]), "team twice in a round")
				in_round[g[0]] = true
				in_round[g[1]] = true
				var key := "%d-%d" % [mini(g[0], g[1]), maxi(g[0], g[1])]
				runner.check(not seen.has(key), "pair repeated " + key)
				seen[key] = true
		runner.check(seen.size() == 120, "every pair once, got %d" % seen.size())


func _play_user(c: Career, gf: int, ga: int) -> void:
	var fx := c.next_user_fixture()
	var home: bool = fx[0] == c.user_team
	c.record_user_match({"score": [gf, ga] if home else [ga, gf]})


func test_full_season_flow() -> void:
	var c := _new()
	var guard := 0
	while c.phase != "offseason" and guard < 40:
		if c.next_user_fixture().is_empty():
			c.skip_without_user()
		else:
			_play_user(c, 3, 0)
		guard += 1
	runner.check(c.phase == "offseason", "season ended, phase " + c.phase)
	var tb: Dictionary = c.table[0]
	for tid in tb:
		runner.check(tb[tid]["p"] == 15, "15 games each")
	runner.check(c.history.size() == 1, "history entry")
	# winning every game: champions of Division 4 playoffs -> promoted
	runner.check(c.user_div() == 2, "user promoted to Division 3, now in %d" % (c.user_div() + 1))
	for d in Career.DIVS:
		runner.check(c.divisions[d].size() == 16, "division sizes stay 16")
	c.next_season()
	runner.check(c.phase == "league" and c.matchday == 0 and c.season == 2, "new season")


func test_losing_everything_keeps_user_in_div4() -> void:
	var c := _new()
	var guard := 0
	while c.phase != "offseason" and guard < 40:
		if c.next_user_fixture().is_empty():
			c.skip_without_user()
		else:
			_play_user(c, 0, 4)
		guard += 1
	runner.check(c.user_div() == 3, "still Division 4")
	runner.check(c.standings(3)[15] == c.user_team or c.user_div() == 3, "bottom")


func test_upgrades() -> void:
	var c := _new()
	var before: int = (c.user().players[5] as PlayerData).stat("sht")
	c.apply_upgrades(["", "", "", "", "", "sht"], 3)
	runner.check((c.user().players[5] as PlayerData).stat("sht") == mini(before + 3, 20), "stat +3")
	var s := c._award(4, 0, c.divisions[0][0])
	runner.check(s["level"] >= 3, "big win vs strong team gives a high level: %s" % s)
	var s2 := c._award(0, 3, c.divisions[3][0])
	runner.check(s2["level"] == 0, "defeat gives nothing")


func test_save_load_roundtrip() -> void:
	var c := _new()
	_play_user(c, 2, 1)
	var d := c.to_dict()
	var txt := JSON.stringify(d)
	var c2 := Career.from_dict(JSON.parse_string(txt))
	runner.check(c2.matchday == c.matchday and c2.user_team == c.user_team, "basic fields")
	runner.check(c2.standings(3) == c.standings(3), "same table")
	runner.check(c2.user().name == c.user().name, "team")
	runner.check(c2.next_user_fixture() == c.next_user_fixture(), "same next fixture")
	_play_user(c2, 1, 1)
	runner.check(c2.matchday == c.matchday + 1, "continues")


func test_many_seasons_stay_consistent() -> void:
	var c := _new()
	for season in 4:
		var guard := 0
		while c.phase != "offseason" and guard < 40:
			if c.next_user_fixture().is_empty():
				c.skip_without_user()
			else:
				_play_user(c, 2, 1)
				c.apply_upgrades([], c.last_summary.get("level", 0))
			guard += 1
		c.next_season()
	var all := {}
	for d in Career.DIVS:
		for tid in c.divisions[d]:
			runner.check(not all.has(tid), "team in two divisions")
			all[tid] = true
	runner.check(all.size() == 64, "all teams placed")
	print("    after 4 seasons user in %s, rating %.1f" % [Career.div_name(c.user_div()), c.user().rating()])
	runner.check(c.user_div() <= 1, "steady winner should climb")
