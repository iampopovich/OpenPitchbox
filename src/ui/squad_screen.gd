class_name SquadScreen
extends Screen
## Squad attributes and statistics (season / career).

var show_career := false


func _ready() -> void:
	var c: Career = Game.career
	var t := c.user()
	base("Squad", "%s · %s · rating %.1f" % [t.name, UiTheme.stars_text(t.stars()), t.rating()], 960.0)
	content.add_child(Screen.cycler("Statistics", ["This season", "Career"], 1 if show_career else 0, func(i):
		var s := SquadScreen.new()
		s.show_career = i == 1
		Game.show_menu(s), 360))
	var head := Screen.hbox(6)
	for col in [["Pos", 60], ["#", 46], ["Name", 260], ["SPD", 60], ["SHT", 60], ["PAS", 60], ["TKL", 60], ["KEP", 60], ["Apps", 64], ["Gls", 56], ["Ast", 56], ["Tkl", 56], ["Svs", 56]]:
		head.add_child(Screen.cell(col[0], col[1], UiTheme.MUTED, 18, HORIZONTAL_ALIGNMENT_LEFT if col[0] == "Name" else HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(head)
	for i in 6:
		var pd: PlayerData = t.players[i]
		var st: Dictionary = pd.career if show_career else pd.season
		var row := Screen.hbox(6)
		row.add_child(Screen.cell(t.role_of(i), 60, UiTheme.ACCENT2, 20, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(Screen.cell(str(pd.number), 46, UiTheme.TEXT, 20, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(Screen.cell(pd.name, 260))
		for k in C.STAT_KEYS:
			var v := pd.stat(k)
			var col := UiTheme.ACCENT if v >= 15 else (UiTheme.TEXT if v >= 8 else UiTheme.MUTED)
			row.add_child(Screen.cell(str(v), 60, col, 20, HORIZONTAL_ALIGNMENT_CENTER))
		for k in ["apps", "goals", "assists", "tackles", "saves"]:
			row.add_child(Screen.cell(str(st.get(k, 0)), 64 if k == "apps" else 56, UiTheme.TEXT, 20, HORIZONTAL_ALIGNMENT_CENTER))
		content.add_child(row)
	var note := UiTheme.label("Attributes go from 1 to 20. Upgrades are earned after every match.", 18, UiTheme.MUTED)
	content.add_child(note)
	footer.add_child(UiTheme.button("Back", back, 200))
	focus_first()


func back() -> void:
	Game.show_menu(CareerHub.new())
