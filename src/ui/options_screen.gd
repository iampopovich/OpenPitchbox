class_name OptionsScreen
extends Screen
## Settings, controls reference and league files.


func _ready() -> void:
	base("Options")
	var st := Game.settings
	var vols := ["Off", "20%", "40%", "60%", "80%", "100%"]
	content.add_child(Screen.cycler("Volume", vols, int(round(float(st.get("volume", 0.8)) * 5.0)), func(i): _setv("volume", i / 5.0)))
	content.add_child(Screen.cycler("Default camera", CameraRig.NAMES, int(st.get("camera", 0)), func(i): _setv("camera", i)))
	content.add_child(Screen.cycler("Goal replays", ["On", "Off"], 0 if st.get("replays", true) else 1, func(i): _setv("replays", i == 0)))
	content.add_child(Screen.cycler("Auto switch on defence", ["On", "Off"], 0 if st.get("auto_switch", true) else 1, func(i): _setv("auto_switch", i == 0)))
	content.add_child(Screen.cycler("Player markers", ["All players", "Controlled only"], 0 if st.get("markers", "all") == "all" else 1, func(i): _setv("markers", "all" if i == 0 else "human")))
	content.add_child(Screen.cycler("Fouls and cards", ["On", "Off (classic arcade)"], 0 if st.get("fouls", true) else 1, func(i): _setv("fouls", i == 0)))
	content.add_child(Screen.cycler("Display", ["Window", "Fullscreen"], 1 if st.get("fullscreen", false) else 0, func(i): Game.set_fullscreen(i == 1)))
	content.add_child(UiTheme.label("Controls", 26, UiTheme.ACCENT2))
	var help := """Gamepad:  stick move · A pass · B shoot (hold for power) / slide tackle · Y lob · X volley / header / bicycle kick
          LB/RB switch player · Start pause · Back camera
Keyboard 1:  WASD · J pass · K or Space shoot · L lob · I volley/bicycle · Q switch · Esc pause · C camera
Keyboard 2:  arrows · , pass · . shoot · / lob · ; volley/bicycle · ' switch
Press pass/shoot/lob BEFORE the ball reaches you for a first-time action.
With the ball, the volley button flicks it up for a volley or a bicycle kick.
After scoring: pass / shoot / lob picks the celebration."""
	var hl := UiTheme.label(help, 18, UiTheme.TEXT)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hl)
	content.add_child(UiTheme.label("League files", 26, UiTheme.ACCENT2))
	var info := UiTheme.label("Export the exhibition league, edit teams.csv / players.csv in any spreadsheet, then reload.\nFolder: " + LeagueIO.folder(), 18, UiTheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var status := UiTheme.label("", 18, UiTheme.ACCENT)
	var r := Screen.hbox()
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
