extends Node
## Entry point.
## Debug: OP_AUTOPLAY=1 starts a CPU vs CPU match; OP_SCREEN=<name> opens a screen
## (menu, setup, practice, options, slots, new, hub, upgrade, squad, leaders, history, editor).


func _ready() -> void:
	if OS.get_environment("OP_AUTOPLAY") != "":
		var pair := TeamFactory.quick_pair(int(OS.get_environment("OP_SEED")) if OS.get_environment("OP_SEED") != "" else 3)
		var cam := int(OS.get_environment("OP_CAMERA")) if OS.get_environment("OP_CAMERA") != "" else 0
		Game.play_match({"teams": pair, "humans": [], "length": 120.0, "camera": cam, "seed": 5}, func(_r): get_tree().quit())
		return
	var screen := OS.get_environment("OP_SCREEN")
	if screen != "":
		_debug_screen(screen)
		return
	Game.show_menu()


func _debug_screen(name: String) -> void:
	if name in ["hub", "upgrade", "squad", "leaders", "history", "editor"]:
		var c := Career.create(99)
		# play a few rounds so tables and stats have content
		for i in 4:
			var fx := c.next_user_fixture()
			var home: bool = fx[0] == c.user_team
			c.record_user_match({"score": [2, 1] if home else [1, 2], "pstats": []})
		c.history.append({"season": 0, "champion": c.divisions[0][0], "champion_name": c.team(c.divisions[0][0]).name,
			"user_div": 3, "user_pos": 5, "user_playoff": "lost in the semi-final"})
		Game.career = c
		Game.career_slot = 2
	match name:
		"careermatch":
			# full loop: hub -> match (CPU only, 15 s) -> record -> upgrade screen
			var c := Career.create(5, {"devices": [], "length": 15.0})
			Game.career = c
			Game.career_slot = 2
			var hub := CareerHub.new()
			Game.show_menu(hub)
			await get_tree().process_frame
			await get_tree().process_frame
			hub._play(c.next_user_fixture())
		"setup":
			Game.show_menu(MatchSetup.new())
		"practice":
			var s := MatchSetup.new()
			s.practice = true
			Game.show_menu(s)
		"options":
			Game.show_menu(OptionsScreen.new())
		"slots":
			Game.show_menu(CareerSlots.new())
		"new":
			Game.show_menu(NewCareer.new())
		"hub":
			Game.show_menu(CareerHub.new())
		"upgrade":
			Game.show_menu(UpgradeScreen.new())
		"squad":
			Game.show_menu(SquadScreen.new())
		"leaders":
			Game.show_menu(LeadersScreen.new())
		"history":
			Game.show_menu(HistoryScreen.new())
		"editor":
			var ed := TeamEditor.new()
			ed.team = Game.career.user()
			ed.first_time = true
			Game.show_menu(ed)
		_:
			Game.show_menu()
