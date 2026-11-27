class_name MatchSetup
extends Screen
## Exhibition / practice setup: teams, who controls which side, length, difficulty, camera.

var practice := false
var teams: Array = []
var home_i := 0
var away_i := 1
var assign := {}          # device -> 0 CPU, 1 home, 2 away
var length_i := 1
var diff_i := 1
var cam_i := 0
var roleplay := false
var home_info: Label
var away_info: Label

const LENGTHS := [120.0, 180.0, 300.0, 600.0]
const LENGTH_NAMES := ["2 min", "3 min", "5 min", "10 min"]
const DIFFS := ["Easy", "Normal", "Hard", "Pro"]


func _ready() -> void:
	base("Practice" if practice else "Exhibition", "the opposition only fields a keeper" if practice else "")
	teams = Game.world_teams().duplicate()
	if Game.career:
		teams.insert(0, Game.career.user())
	away_i = mini(1, teams.size() - 1)
	length_i = maxi(0, LENGTHS.find(float(Game.settings.get("length", 180))))
	diff_i = int(Game.settings.get("difficulty", 1))
	cam_i = int(Game.settings.get("camera", 0))
	var names: Array = []
	for t in teams:
		names.append((t as TeamData).name)
	var row := Screen.hbox(30)
	content.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	left.add_child(Screen.cycler("Home", names, home_i, func(i):
		home_i = i
		_refresh()))
	home_info = UiTheme.label("", 18, UiTheme.MUTED)
	left.add_child(home_info)
	if not practice:
		var right := VBoxContainer.new()
		row.add_child(right)
		right.add_child(Screen.cycler("Away", names, away_i, func(i):
			away_i = i
			_refresh()))
		away_info = UiTheme.label("", 18, UiTheme.MUTED)
		right.add_child(away_info)
	content.add_child(UiTheme.label("Controllers", 26, UiTheme.ACCENT2))
	var devs := InputRouter.connected_devices()
	for dev in devs:
		assign[dev] = 1 if dev == "kb1" else 0
		var sides := ["CPU", "Home"] if practice else ["CPU", "Home", "Away"]
		content.add_child(Screen.cycler(InputRouter.device_label(dev), sides, assign[dev], func(i): assign[dev] = i, 560))
	content.add_child(UiTheme.label("Match", 26, UiTheme.ACCENT2))
	if not practice:
		content.add_child(Screen.cycler("Length", LENGTH_NAMES, length_i, func(i): length_i = i))
		content.add_child(Screen.cycler("Difficulty", DIFFS, diff_i, func(i): diff_i = i))
	content.add_child(Screen.cycler("Camera", CameraRig.NAMES, cam_i, func(i): cam_i = i))
	content.add_child(Screen.cycler("Mode", ["Team (switch players)", "Role-play (one player)"], 0, func(i): roleplay = i == 1))
	footer.add_child(UiTheme.button("Kick off", _start, 260))
	footer.add_child(UiTheme.button("Back", back, 200))
	_refresh()
	focus_first()


func _refresh() -> void:
	var h: TeamData = teams[home_i]
	home_info.text = "%s  %s  %s" % [UiTheme.stars_text(h.stars()), h.formation, "rating %.1f" % h.rating()]
	if away_info:
		var a: TeamData = teams[away_i]
		away_info.text = "%s  %s  %s" % [UiTheme.stars_text(a.stars()), a.formation, "rating %.1f" % a.rating()]


func _start() -> void:
	var humans: Array = []
	var id := 0
	for dev in assign:
		if assign[dev] > 0:
			humans.append({"id": id, "team": assign[dev] - 1, "device": dev})
			id += 1
	var home: TeamData = teams[home_i]
	var away: TeamData = teams[away_i] if not practice else teams[(home_i + 1) % teams.size()]
	if away == home:
		away = home.clone()
		away.name += " B"
	Game.settings["length"] = LENGTHS[length_i]
	Game.settings["difficulty"] = diff_i
	Game.settings["camera"] = cam_i
	Game.save_settings()
	var d := [diff_i, diff_i]
	for h in humans:
		d[h["team"]] = 1   # human teams get normal-level team-mates
	var cfg := {
		"teams": [home, away], "humans": humans, "length": 0.0 if practice else LENGTHS[length_i],
		"difficulty": d, "practice": practice, "roleplay": roleplay, "camera": cam_i, "seed": randi(),
		"replays": Game.settings.get("replays", true), "title": "Practice" if practice else "Exhibition",
	}
	var again := func(_r): Game.show_menu(MatchSetup.new() if not practice else _practice_screen())
	Game.play_match(cfg, again)


func _practice_screen() -> MatchSetup:
	var s := MatchSetup.new()
	s.practice = true
	return s
