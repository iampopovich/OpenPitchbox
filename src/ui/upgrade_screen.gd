class_name UpgradeScreen
extends Screen
## After a career match: result, earned level, one stat upgrade per player.

var c: Career
var choices: Array = ["", "", "", "", "", ""]
var buttons: Array = []
var level := 0


func _ready() -> void:
	c = Game.career
	var s: Dictionary = c.last_summary
	level = int(s.get("level", 0))
	var sc: Array = s.get("score", [0, 0])
	base("Full time", "%s %d - %d %s" % [c.team(s.get("home", 0)).name, sc[0], sc[1], c.team(s.get("away", 0)).name], 1100.0)
	content.add_child(UiTheme.label("Performance points: %.1f   →   team level +%d" % [float(s.get("points", 0.0)), level], 26, UiTheme.ACCENT2))
	var expl := UiTheme.label("Points come from goals scored and conceded, the result and the strength of the opponent. Each player raises one attribute by the level.", 18, UiTheme.MUTED)
	expl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(expl)
	var t := c.user()
	if level <= 0:
		content.add_child(UiTheme.label("No upgrades this time.", 22))
	elif c.opts.get("auto_upgrade", false):
		c.apply_upgrades([], level)
		Game.save_career()
		level = 0
		content.add_child(UiTheme.label("Upgrades applied automatically.", 22))
		_squad_lines(t)
	else:
		for i in 6:
			var pd: PlayerData = t.players[i]
			var role := t.role_of(i)
			choices[i] = Career.auto_stat(pd, role)
			var row := Screen.hbox(8)
			row.add_child(Screen.cell("%s  %s" % [role, pd.name], 300, UiTheme.TEXT, 20))
			var bs: Array = []
			for k in C.STAT_KEYS:
				var b := Button.new()
				b.custom_minimum_size = Vector2(150, 42)
				b.toggle_mode = true
				var key: String = k
				var idx := i
				b.pressed.connect(func(): _pick(idx, key))
				row.add_child(b)
				bs.append(b)
			buttons.append(bs)
			content.add_child(row)
		_refresh()
		footer.add_child(UiTheme.button("Auto pick", func():
			for i in 6:
				choices[i] = Career.auto_stat(t.players[i], t.role_of(i))
			_refresh(), 220))
	footer.add_child(UiTheme.primary(UiTheme.button("Continue", _done, 240)))
	focus_first()
	if OS.get_environment("OP_SHOT_ON") == "upgrade":
		Game.capture_in(20)


func _squad_lines(t: TeamData) -> void:
	for i in 6:
		var pd: PlayerData = t.players[i]
		var txt := "%s  %-22s" % [t.role_of(i), pd.name]
		for k in C.STAT_KEYS:
			txt += "   %s %d" % [k.to_upper(), pd.stat(k)]
		content.add_child(UiTheme.label(txt, 18))


func _pick(i: int, key: String) -> void:
	choices[i] = key
	_refresh()


func _refresh() -> void:
	var t := c.user()
	for i in buttons.size():
		var pd: PlayerData = t.players[i]
		for j in C.STAT_KEYS.size():
			var k: String = C.STAT_KEYS[j]
			var b: Button = buttons[i][j]
			var v := pd.stat(k)
			var picked: bool = choices[i] == k
			b.button_pressed = picked
			b.text = "%s %d%s" % [k.to_upper(), v, (" → %d" % mini(v + level, C.STAT_MAX)) if picked else ""]
			b.modulate = Color(1, 1, 1) if picked else Color(0.75, 0.75, 0.8)


func _done() -> void:
	if level > 0:
		c.apply_upgrades(choices, level)
	Game.save_career()
	Game.show_menu(CareerHub.new())


func back() -> void:
	_done()
