class_name CareerHub
extends Screen
## Career home: next fixture, league table / playoff bracket, squad and records.

var c: Career
var view_div := -1


func _ready() -> void:
	c = Game.career
	if view_div < 0:
		view_div = c.user_div()
	base(c.user().name, "Season %d · %s · %s" % [c.season, Career.div_name(c.user_div()), c.stage_label()], 1120.0)
	var row := Screen.hbox(28)
	content.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_fixture_panel(left)
	# secondary destinations in a compact 2×2 grid under the fixture card
	var nav := GridContainer.new()
	nav.columns = 2
	nav.add_theme_constant_override("h_separation", 10)
	nav.add_theme_constant_override("v_separation", 10)
	left.add_child(nav)
	var links := [
		["Squad", func(): Game.show_menu(SquadScreen.new())],
		["Edit team", func():
			var ed := TeamEditor.new()
			ed.team = c.user()
			Game.show_menu(ed)],
		["Leaders", func(): Game.show_menu(LeadersScreen.new())],
		["History", func(): Game.show_menu(HistoryScreen.new())],
	]
	for l: Array in links:
		var nb := UiTheme.button(l[0], l[1], 195)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(nb)
	var status := UiTheme.label("", 16, UiTheme.MUTED)
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(400, 0)
	left.add_child(status)
	footer.add_child(UiTheme.button("Save & exit", back, 220))
	footer.add_child(UiTheme.button("Export league CSV", func():
		var path := LeagueIO.export_league(c.teams, c.divisions)
		status.text = "Written to " + path, 260))
	right.add_child(Screen.cycler("Table", [Career.div_name(0), Career.div_name(1), Career.div_name(2), Career.div_name(3)], view_div, func(i):
		var h := CareerHub.new()
		h.view_div = i
		Game.show_menu(h), 360))
	right.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if c.phase == "playoffs" or c.phase == "offseason":
		_bracket(right, view_div)
	_table(right, view_div)
	focus_first()


func back() -> void:
	Game.save_career()
	Game.career = null
	Game.show_menu()


func _fixture_panel(parent: Control) -> void:
	var p := Screen.panel()
	parent.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	if c.phase == "offseason":
		vb.add_child(UiTheme.label("Season %d is over" % c.season, 26, UiTheme.ACCENT2))
		for line in c.news:
			var l := UiTheme.label(line, 20)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(370, 0)
			vb.add_child(l)
		vb.add_child(UiTheme.button("Start season %d" % (c.season + 1), func():
			c.next_season()
			Game.save_career()
			Game.show_menu(CareerHub.new()), 370))
		return
	var fx := c.next_user_fixture()
	if fx.is_empty():
		var msg := "You are out of the playoffs." if c.phase == "playoffs" else "No match this round."
		vb.add_child(UiTheme.label(msg, 22))
		vb.add_child(UiTheme.button("Continue (simulate %s)" % c.stage_label().to_lower(), func():
			c.skip_without_user()
			Game.save_career()
			Game.show_menu(CareerHub.new()), 370))
		return
	var h := c.team(fx[0])
	var a := c.team(fx[1])
	var cap := UiTheme.label("NEXT · " + c.stage_label().to_upper(), 16, UiTheme.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	var vs := Screen.hbox(10)
	vs.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(vs)
	for i: int in 2:
		var t: TeamData = [h, a][i]
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 168
		col.add_theme_constant_override("separation", 4)
		var bar := UiTheme.chip(t.color1, Vector2(44, 6))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(bar)
		var nm := UiTheme.label(t.name, 19, Color.WHITE if t == c.user() else UiTheme.TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(nm)
		var rt := UiTheme.label("%s  %.1f" % [UiTheme.stars_text(t.stars()), t.rating()], 16, UiTheme.MUTED)
		rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rt)
		vs.add_child(col)
		if i == 0:
			var v := UiTheme.label("vs", 20, UiTheme.MUTED)
			v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vs.add_child(v)
	if fx[2]:
		var ko := UiTheme.label("Knockout: golden goal if level", 16, UiTheme.ACCENT2)
		ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ko)
	vb.add_child(UiTheme.primary(UiTheme.button("Play match", func(): _play(fx), 370)))


func _play(fx: Array) -> void:
	var user_home: bool = fx[0] == c.user_team
	var humans: Array = []
	var id := 0
	for dev in c.opts.get("devices", ["kb1"]):
		humans.append({"id": id, "team": 0 if user_home else 1, "device": dev})
		id += 1
	var diff := int(c.opts.get("difficulty", 1))
	var d := [diff, diff]
	d[0 if user_home else 1] = 1
	var cfg := {
		"teams": [c.team(fx[0]), c.team(fx[1])], "humans": humans, "length": float(c.opts.get("length", 180.0)),
		"difficulty": d, "needs_winner": fx[2], "roleplay": c.opts.get("roleplay", false),
		"camera": Game.settings.get("camera", 0), "seed": randi(), "replays": Game.settings.get("replays", true),
		"title": "%s · %s" % [Career.div_name(c.user_div()), c.stage_label()], "quit_text": "Forfeit (lose 0-3)",
	}
	Game.play_match(cfg, func(result):
		c.record_user_match(result)
		Game.save_career()
		Game.show_menu(UpgradeScreen.new()))


func _table(parent: Control, d: int) -> void:
	var p := Screen.panel()
	parent.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	p.add_child(vb)
	var head := Screen.hbox(6)
	for col in [["#", 36], ["Club", 250], ["P", 40], ["W", 40], ["D", 40], ["L", 40], ["GF", 46], ["GA", 46], ["Pts", 52]]:
		head.add_child(Screen.cell(col[0], col[1], UiTheme.MUTED, 15, HORIZONTAL_ALIGNMENT_CENTER if col[0] != "Club" else HORIZONTAL_ALIGNMENT_LEFT))
	vb.add_child(head)
	var st := c.standings(d)
	for i in st.size():
		var tid: int = st[i]
		var r: Dictionary = c.table[d].get(tid, {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0})
		var line := Screen.hbox(6)
		var col := UiTheme.TEXT
		if tid == c.user_team:
			col = UiTheme.ACCENT2
		var pos_col := UiTheme.ACCENT if i < 8 else (Color("f87171") if i >= 14 and d < 3 else UiTheme.MUTED)
		line.add_child(Screen.cell(str(i + 1), 36, pos_col, 16, HORIZONTAL_ALIGNMENT_CENTER))
		line.add_child(Screen.cell(c.team(tid).name, 250, col, 16))
		for k in ["p", "w", "d", "l", "gf", "ga", "pts"]:
			line.add_child(Screen.cell(str(r[k]), 52 if k == "pts" else (46 if k in ["gf", "ga"] else 40), col, 16, HORIZONTAL_ALIGNMENT_CENTER))
		vb.add_child(line)
	var legend := UiTheme.label("green: playoff places (top 8)   red: relegation", 15, UiTheme.MUTED)
	vb.add_child(legend)


func _bracket(parent: Control, d: int) -> void:
	var po: Dictionary = c.playoffs[d]
	var p := Screen.panel()
	parent.add_child(p)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	vb.add_child(UiTheme.label(("%s playoffs" % Career.div_name(d)) if d > 0 else Career.CUP_NAME, 22, UiTheme.ACCENT2))
	var stages: Array = po["stages"]
	for i in stages.size():
		var txt: String = Career.STAGE_NAMES[i] + ":  "
		var parts: Array = []
		for m in stages[i]:
			parts.append("%s %d-%d %s" % [c.team(m[0]).short, m[2], m[3], c.team(m[1]).short])
		txt += "   ".join(parts)
		var l := UiTheme.label(txt, 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	if c.phase == "playoffs" and stages.size() < 3:
		var pairs := c._stage_pairs(d)
		var parts2: Array = []
		for g in pairs:
			parts2.append("%s v %s" % [c.team(g[0]).short, c.team(g[1]).short])
		var l2 := UiTheme.label("Next " + Career.STAGE_NAMES[stages.size()].to_lower() + ":  " + "   ".join(parts2), 17, UiTheme.MUTED)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l2)
