class_name LeadersScreen
extends Screen
## League leaders: goals, assists, tackles, saves.

var scope := 0   # 0 = my division, 1 = all divisions


func _ready() -> void:
	var c: Career = Game.career
	base("League leaders", "season %d" % c.season, 1160.0)
	content.add_child(Screen.cycler("Scope", [Career.div_name(c.user_div()), "All divisions"], scope, func(i):
		var s := LeadersScreen.new()
		s.scope = i
		Game.show_menu(s), 380))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for key in ["goals", "assists", "tackles", "saves"]:
		var p := Screen.panel()
		p.custom_minimum_size = Vector2(560, 0)
		grid.add_child(p)
		var vb := VBoxContainer.new()
		p.add_child(vb)
		var cap := UiTheme.label(key.to_upper(), 18, UiTheme.ACCENT2)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(cap)
		var rows := c.leaders(key, c.user_div() if scope == 0 else -1, 5)
		if rows.is_empty():
			vb.add_child(UiTheme.label("—", 18, UiTheme.MUTED))
		for r in rows:
			var line := Screen.hbox(6)
			var mine: bool = r[1] == c.user()
			var col := UiTheme.ACCENT2 if mine else UiTheme.TEXT
			line.add_child(Screen.cell((r[0] as PlayerData).name, 230, col, 18))
			line.add_child(Screen.cell((r[1] as TeamData).name, 240, UiTheme.MUTED, 18))
			line.add_child(Screen.cell(str(r[2]), 50, col, 18, HORIZONTAL_ALIGNMENT_RIGHT))
			vb.add_child(line)
	footer.add_child(UiTheme.button("Back", back, 200))
	focus_first()


func back() -> void:
	Game.show_menu(CareerHub.new())
