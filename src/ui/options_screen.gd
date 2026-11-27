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
	if not OS.has_feature("mobile"):
		content.add_child(Screen.cycler("Display", ["Window", "Fullscreen"], 1 if st.get("fullscreen", false) else 0, func(i): Game.set_fullscreen(i == 1)))
	content.add_child(Screen.cycler("Graphics", ["Auto", "High", "Low (phones)"], ["auto", "high", "low"].find(st.get("graphics", "auto")), func(i):
		_setv("graphics", ["auto", "high", "low"][i])
		Game.apply_graphics()))
	content.add_child(Screen.section("Touch and motion"))
	var ops := ["30%", "45%", "55%", "70%", "85%"]
	var opv := [0.3, 0.45, 0.55, 0.7, 0.85]
	content.add_child(Screen.cycler("Touch buttons opacity", ops, _nearest(opv, float(st.get("touch_opacity", 0.55))), func(i): _setv("touch_opacity", opv[i])))
	var szs := ["Small", "Medium", "Large", "Extra large"]
	var szv := [0.8, 1.0, 1.2, 1.4]
	content.add_child(Screen.cycler("Touch buttons size", szs, _nearest(szv, float(st.get("touch_size", 1.0))), func(i): _setv("touch_size", szv[i])))
	content.add_child(Screen.cycler("Touch steering", ["Thumb stick", "Tilt the phone"], 1 if st.get("steering", "stick") == "tilt" else 0, func(i): _setv("steering", "tilt" if i == 1 else "stick")))
	content.add_child(Screen.cycler("Gamepad motion steering", ["Off", "On (DualSense, Switch Pro…)"], 1 if st.get("pad_tilt", false) else 0, func(i): _setv("pad_tilt", i == 1)))
	content.add_child(Screen.cycler("Phones as controllers (Wi-Fi)", ["On", "Off"], 0 if st.get("phone_link", true) else 1, func(i):
		_setv("phone_link", i == 0)
		Game.start_phone_link()))
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
	var extra := UiTheme.label("Mouse: point to run · left click pass · right click shoot · wheel click lob · Shift volley · Tab switch.\nTouch: left thumb moves, buttons on the right. Phones: open “Use phone as controller” on the phone, same Wi-Fi.", 17, UiTheme.MUTED)
	for r: int in rows.size():
		for col: int in 4:
			var cl := UiTheme.label(rows[r][col], 18, UiTheme.MUTED if r == 0 or col == 0 else UiTheme.TEXT)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if col == 0 else HORIZONTAL_ALIGNMENT_CENTER
			cl.custom_minimum_size.x = 170 if col == 0 else 120
			grid.add_child(cl)
	content.add_child(grid)
	content.add_child(extra)
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


static func _nearest(vals: Array, v: float) -> int:
	var best := 0
	for i in vals.size():
		if absf(float(vals[i]) - v) < absf(float(vals[best]) - v):
			best = i
	return best
