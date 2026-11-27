class_name MatchHud
extends CanvasLayer
## Scoreboard, banners, shot power bar, pause menu and full-time summary.

signal resume_requested
signal replay_requested
signal camera_requested
signal quit_requested
signal continue_requested

var root: Control
var score_lbl: Label
var clock_lbl: Label
var name0: Label
var name1: Label
var banner: Label
var banner_t := 0.0
var hint_t := 0.0
var sub_banner: Label
var replay_lbl: Label
var power: ProgressBar
var hint: Label
var pause_layer: ColorRect
var pause_panel: PanelContainer
var cam_btn: Button
var ft_panel: PanelContainer
var quit_text := "Quit match"


func build(sim: MatchSim, title: String, shirt: Array) -> void:
	layer = 5
	root = Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# compact broadcast-style scoreboard, top left
	var board := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.82)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	board.add_theme_stylebox_override("panel", sb)
	board.position = Vector2(18, 14)
	root.add_child(board)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	board.add_child(hb)
	var t0: TeamData = sim.teams[0]
	var t1: TeamData = sim.teams[1]
	hb.add_child(UiTheme.chip(shirt[0], Vector2(5, 22)))
	name0 = UiTheme.label(t0.short, 20, Color.WHITE)
	hb.add_child(name0)
	score_lbl = UiTheme.label("0 - 0", 22, Color.WHITE)
	score_lbl.custom_minimum_size = Vector2(56, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(score_lbl)
	name1 = UiTheme.label(t1.short, 20, Color.WHITE)
	hb.add_child(name1)
	hb.add_child(UiTheme.chip(shirt[1], Vector2(5, 22)))
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.15)
	sep.custom_minimum_size = Vector2(1, 22)
	hb.add_child(sep)
	clock_lbl = UiTheme.label("3:00", 20, UiTheme.ACCENT2)
	clock_lbl.custom_minimum_size = Vector2(52, 0)
	hb.add_child(clock_lbl)
	# banners
	banner = UiTheme.label("", 52, Color.WHITE)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color("052e16"))
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(-500, -230)
	banner.size = Vector2(1000, 70)
	root.add_child(banner)
	sub_banner = UiTheme.label("", 22, UiTheme.ACCENT2)
	sub_banner.add_theme_constant_override("outline_size", 8)
	sub_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_banner.set_anchors_preset(Control.PRESET_CENTER)
	sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_banner.position = Vector2(-500, -165)
	sub_banner.size = Vector2(1000, 50)
	root.add_child(sub_banner)
	replay_lbl = UiTheme.label("● REPLAY", 20, Color("f87171"))
	replay_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	replay_lbl.position = Vector2(-150, 16)
	replay_lbl.visible = false
	root.add_child(replay_lbl)
	power = ProgressBar.new()
	power.show_percentage = false
	power.custom_minimum_size = Vector2(90, 12)
	power.size = Vector2(90, 12)
	power.max_value = 1.0
	power.visible = false
	root.add_child(power)
	hint = UiTheme.label("", 18, UiTheme.MUTED)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-640, -40)
	hint.size = Vector2(1280, 30)
	root.add_child(hint)
	_build_pause()


func _build_pause() -> void:
	# dimmed full-screen layer with the menu card exactly in the middle
	pause_layer = ColorRect.new()
	pause_layer.color = Color(0, 0, 0, 0.45)
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.visible = false
	root.add_child(pause_layer)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(cc)
	pause_panel = PanelContainer.new()
	cc.add_child(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pause_panel.add_child(vb)
	var pt := UiTheme.title("Paused")
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pt)
	vb.add_child(UiTheme.button("Resume", func(): resume_requested.emit()))
	vb.add_child(UiTheme.button("Instant replay", func(): replay_requested.emit()))
	cam_btn = UiTheme.button("Camera", func(): camera_requested.emit())
	vb.add_child(cam_btn)
	vb.add_child(UiTheme.button(quit_text, func(): quit_requested.emit()))


func set_quit_text(t: String) -> void:
	quit_text = t
	var vb := pause_panel.get_child(0)
	(vb.get_child(vb.get_child_count() - 1) as Button).text = t


func show_pause(on: bool, cam_name: String) -> void:
	pause_layer.visible = on
	cam_btn.text = "Camera: " + cam_name
	if on:
		(pause_panel.get_child(0).get_child(1) as Button).grab_focus()


func flash(text: String, sub: String = "", secs: float = 2.0) -> void:
	banner.text = text
	sub_banner.text = sub
	banner_t = secs
	banner.modulate.a = 1.0
	sub_banner.modulate.a = 1.0


func update_hud(sim: MatchSim, dt: float) -> void:
	score_lbl.text = "%d - %d" % [sim.score[0], sim.score[1]]
	if sim.overtime:
		clock_lbl.text = "GOLDEN"
	elif sim.length <= 0.0:
		clock_lbl.text = "PRACTICE"
	else:
		var s := int(ceil(sim.clock))
		clock_lbl.text = "%d:%02d" % [s / 60, s % 60]
	if hint.text != "":
		hint_t += dt
		hint.modulate.a = clampf(1.0 - (hint_t - 8.0), 0.0, 1.0)
	if banner_t > 0.0:
		banner_t -= dt
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		banner.modulate.a = a
		sub_banner.modulate.a = a
		if banner_t <= 0.0:
			banner.text = ""
			sub_banner.text = ""


func show_power(screen_pos: Vector2, v: float) -> void:
	power.visible = v >= 0.0
	if v >= 0.0:
		power.value = v
		power.position = screen_pos + Vector2(-45, 20)


func show_fulltime(sim: MatchSim, extra: String = "") -> void:
	ft_panel = PanelContainer.new()
	ft_panel.set_anchors_preset(Control.PRESET_CENTER)
	ft_panel.position = Vector2(-330, -300)
	ft_panel.custom_minimum_size = Vector2(660, 0)
	root.add_child(ft_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	ft_panel.add_child(vb)
	var t0: TeamData = sim.teams[0]
	var t1: TeamData = sim.teams[1]
	var head := UiTheme.title("%s  %d - %d  %s" % [t0.short, sim.score[0], sim.score[1], t1.short])
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	var names := UiTheme.label("%s  vs  %s" % [t0.name, t1.name], 20, UiTheme.MUTED)
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(names)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	vb.add_child(grid)
	var total_poss: float = maxf(1.0, sim.stats[0]["poss"] + sim.stats[1]["poss"])
	var rows := [
		["Shots", sim.stats[0]["shots"], sim.stats[1]["shots"]],
		["On target", sim.stats[0]["on_target"], sim.stats[1]["on_target"]],
		["Possession", "%d%%" % roundi(sim.stats[0]["poss"] * 100.0 / total_poss), "%d%%" % roundi(sim.stats[1]["poss"] * 100.0 / total_poss)],
		["Tackles", sim.stats[0]["tackles"], sim.stats[1]["tackles"]],
		["Saves", sim.stats[0]["saves"], sim.stats[1]["saves"]],
		["Fouls", sim.stats[0]["fouls"], sim.stats[1]["fouls"]],
		["Cards (Y/R)", "%d / %d" % [sim.stats[0]["yellow"], sim.stats[0]["red"]], "%d / %d" % [sim.stats[1]["yellow"], sim.stats[1]["red"]]],
	]
	for r in rows:
		var a := UiTheme.label(str(r[1]), 24)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.custom_minimum_size = Vector2(120, 0)
		grid.add_child(a)
		var m := UiTheme.label(r[0], 22, UiTheme.MUTED)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.custom_minimum_size = Vector2(200, 0)
		grid.add_child(m)
		grid.add_child(UiTheme.label(str(r[2]), 24))
	var scorers := ""
	for g in sim.goals_log:
		var sc: int = g["scorer"]
		var nm := "?"
		if sc >= 0:
			nm = (sim.players[sc] as SimPlayer).data.name
		var line := "%s  %s%s" % [(sim.teams[g["team"]] as TeamData).short, nm, " (og)" if g["own"] else ""]
		if g["assist"] >= 0:
			line += "  — assist " + (sim.players[g["assist"]] as SimPlayer).data.name
		scorers += line + "\n"
	if scorers != "":
		var sl := UiTheme.label(scorers.strip_edges(), 18, UiTheme.TEXT)
		vb.add_child(sl)
	if extra != "":
		vb.add_child(UiTheme.label(extra, 20, UiTheme.ACCENT2))
	var b := UiTheme.button("Continue", func(): continue_requested.emit())
	vb.add_child(b)
	b.grab_focus()
