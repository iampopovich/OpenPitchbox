class_name NewCareer
extends Screen
## New career options: co-op controllers, difficulty, length, upgrades.

var slot := 0
var devices := {}
var diff_i := 1
var length_i := 1
var auto_up := false
var roleplay := false
var use_custom := false


func _ready() -> void:
	base("New career", "you take over a struggling Division 4 club")
	content.add_child(UiTheme.label("Who plays (co-op on your team)", 24, UiTheme.ACCENT2))
	for dev in InputRouter.connected_devices():
		devices[dev] = dev == "kb1"
		content.add_child(Screen.cycler(InputRouter.device_label(dev), ["Off", "Playing"], 1 if devices[dev] else 0, func(i): devices[dev] = i == 1, 560))
	content.add_child(UiTheme.label("Rules", 24, UiTheme.ACCENT2))
	content.add_child(Screen.cycler("Difficulty", MatchSetup.DIFFS, diff_i, func(i): diff_i = i))
	content.add_child(Screen.cycler("Match length", MatchSetup.LENGTH_NAMES, length_i, func(i): length_i = i))
	content.add_child(Screen.cycler("Player upgrades", ["Choose myself", "Automatic"], 0, func(i): auto_up = i == 1))
	content.add_child(Screen.cycler("Mode", ["Team (switch players)", "Role-play (one player)"], 0, func(i): roleplay = i == 1))
	if LeagueIO.has_league():
		content.add_child(Screen.cycler("League", ["Built-in clubs", "Custom CSV league"], 0, func(i): use_custom = i == 1))
	footer.add_child(UiTheme.button("Start", _create, 240))
	footer.add_child(UiTheme.button("Back", func(): Game.show_menu(CareerSlots.new()), 200))
	focus_first()


func _create() -> void:
	var devs: Array = []
	for d in devices:
		if devices[d]:
			devs.append(d)
	if devs.is_empty():
		devs = ["kb1"]
	var opts := {"length": MatchSetup.LENGTHS[length_i], "difficulty": diff_i, "devices": devs,
		"auto_upgrade": auto_up, "roleplay": roleplay}
	var league := {}
	if use_custom:
		league = LeagueIO.import_league()
		if league.has("error"):
			league = {}
	var c := Career.create(randi(), opts, league)
	Game.career = c
	Game.career_slot = slot
	Game.save_career()
	var ed := TeamEditor.new()
	ed.team = c.user()
	ed.first_time = true
	Game.show_menu(ed)


func back() -> void:
	Game.show_menu(CareerSlots.new())
