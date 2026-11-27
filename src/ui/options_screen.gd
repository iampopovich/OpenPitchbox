class_name OptionsScreen
extends Screen
## Settings, controls reference and league files.


func _ready() -> void:
	base("Options", "", 760.0)
	var st := Game.settings
	var vols := ["Off", "20%", "40%", "60%", "80%", "100%"]
	content.add_child(Screen.cycler("Volume", vols, int(round(float(st.get("volume", 0.8)) * 5.0)), func(i): _setv("volume", i / 5.0)))
	content.add_child(Screen.cycler("Default camera", CameraRig.NAMES, int(st.get("camera", 0)), func(i): _setv("camera", i)))
	content.add_child(Screen.cycler("Goal replays", ["On", "Off"], 0 if st.get("replays", true) else 1, func(i): _setv("replays", i == 0)))
	content.add_child(Screen.cycler("Auto switch on defence", ["On", "Off"], 0 if st.get("auto_switch", true) else 1, func(i): _setv("auto_switch", i == 0)))
	content.add_child(Screen.cycler("Player markers", ["All players", "Controlled only"], 0 if st.get("markers", "all") == "all" else 1, func(i): _setv("markers", "all" if i == 0 else "human")))
	content.add_child(Screen.cycler("Fouls and cards", ["On", "Off (classic arcade)"], 0 if st.get("fouls", true) else 1, func(i): _setv("fouls", i == 0)))
	content.add_child(Screen.cycler("Display", ["Window", "Fullscreen"], 1 if st.get("fullscreen", false) else 0, func(i): Game.set_fullscreen(i == 1)))
	content.add_child(Screen.section("Controls"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	var rows := [
		["", "Keyboard 1", "Keyboard 2", "Gamepad"],
		["Move", "W A S D", "Arrows", "Left stick"],
		["Pass", "J", ",", "A"],
		["Shoot / slide", "K, Space", ".", "B"],
		["Lob", "L", "/", "Y"],
		["Volley / bicycle", "I", ";", "X"],
		["Switch player", "Q", "'", "LB / RB"],
		["Pause · camera", "Esc · C", "", "Start · Back"],
	]
	for r: int in rows.size():
		for col: int in 4:
			var cl := UiTheme.label(rows[r][col], 18, UiTheme.MUTED if r == 0 or col == 0 else UiTheme.TEXT)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if col == 0 else HORIZONTAL_ALIGNMENT_CENTER
			cl.custom_minimum_size.x = 170 if col == 0 else 120
			grid.add_child(cl)
	content.add_child(grid)
	var tip := UiTheme.label("Press pass, shoot or lob before the ball arrives for a first-time action. Hold shoot for power.", 17, UiTheme.MUTED)
	content.add_child(tip)
	content.add_child(Screen.section("League files"))
	var info := UiTheme.label("Export the exhibition league, edit teams.csv / players.csv in any spreadsheet, then reload.\nFolder: " + LeagueIO.folder(), 18, UiTheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var status := UiTheme.label("", 18, UiTheme.ACCENT)
	var r := Screen.hbox(16)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_child(UiTheme.button("Export league CSV", func():
		var c := Career.create(2026)
		var lg := Game.world_teams()
		var path := LeagueIO.export_league(lg, c.divisions)
		status.text = "Written to " + path if path != "" else "Export failed"))
	r.add_child(UiTheme.button("Reload league", func():
		Game.reload_world()
		if LeagueIO.has_league():
			var res := LeagueIO.import_league()
			status.text = res["error"] if res.has("error") else "Custom league loaded (64 teams)"
		else:
			status.text = "No custom league: using the built-in clubs"))
	content.add_child(r)
	content.add_child(status)
	footer.add_child(UiTheme.button("Back", back, 200))
	focus_first()


func _setv(k: String, v) -> void:
	Game.settings[k] = v
	Game.save_settings()
