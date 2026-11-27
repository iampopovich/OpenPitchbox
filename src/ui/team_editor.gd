class_name TeamEditor
extends Screen
## Edit club name, kit, formation, player names, numbers, looks and positions, with a 3D preview.

var team: TeamData
var first_time := false
var sel := 0
var preview_root: Node3D
var player_box: VBoxContainer

const COLOR_NAMES := ["Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Navy", "White", "Teal", "Magenta", "Lime", "Brown", "Grey", "Crimson", "Ocean", "Gold"]


func _ready() -> void:
	base("Edit team", "you start with a random Division 4 club — make it yours" if first_time else "", 1120.0)
	var row := Screen.hbox(28)
	content.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(540, 0)
	row.add_child(left)
	var name_edit := LineEdit.new()
	name_edit.text = team.name
	name_edit.max_length = 28
	name_edit.custom_minimum_size = Vector2(540, 44)
	name_edit.text_changed.connect(func(t):
		team.name = t if t.strip_edges() != "" else team.name)
	left.add_child(_labeled("Club name", name_edit))
	var short_edit := LineEdit.new()
	short_edit.text = team.short
	short_edit.max_length = 3
	short_edit.custom_minimum_size = Vector2(120, 44)
	short_edit.text_changed.connect(func(t):
		if t.strip_edges() != "":
			team.short = t.to_upper())
	left.add_child(_labeled("Short name", short_edit))
	left.add_child(Screen.cycler("Shirt", COLOR_NAMES, _color_index(team.color1), func(i):
		team.color1 = TeamFactory.KIT_COLORS[i]
		_rebuild_preview(), 0))
	left.add_child(Screen.cycler("Shorts / trim", COLOR_NAMES, _color_index(team.color2), func(i):
		team.color2 = TeamFactory.KIT_COLORS[i]
		_rebuild_preview(), 0))
	left.add_child(Screen.cycler("Formation", TeamData.FORMATION_ORDER, maxi(0, TeamData.FORMATION_ORDER.find(team.formation)), func(i):
		team.formation = TeamData.FORMATION_ORDER[i]
		_rebuild_player_box(), 0))
	player_box = VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 8)
	left.add_child(player_box)
	var right := VBoxContainer.new()
	row.add_child(right)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(540, 400)
	svc.stretch = true
	right.add_child(svc)
	var sv := SubViewport.new()
	sv.size = Vector2i(540, 400)
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	preview_root = Node3D.new()
	sv.add_child(preview_root)
	var cam := Camera3D.new()
	cam.fov = 32
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.5, 6.6), Vector3(0, 1.0, 0), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(25), 0)
	light.shadow_enabled = true
	sv.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111827")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("aab4c0")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 6)
	floor_mi.mesh = pm
	floor_mi.material_override = Looks.mat(Color("1f5a2c"), 0.95)
	sv.add_child(floor_mi)
	right.add_child(UiTheme.label("Slot order = positions: the first player is the keeper.", 16, UiTheme.MUTED))
	_rebuild_player_box()
	footer.add_child(UiTheme.primary(UiTheme.button("Done", back, 240)))
	focus_first()


func _labeled(text: String, ctrl: Control) -> Control:
	## Text field row styled like a cycler row: caption left, editable value right.
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1e293b")
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22
	sb.content_margin_right = 10
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size.y = 48
	var h := Screen.hbox(12)
	box.add_child(h)
	var l := UiTheme.label(text, 21, UiTheme.MUTED)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	ctrl.custom_minimum_size = Vector2(300, 40)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ctrl is LineEdit:
		(ctrl as LineEdit).alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0, 0, 0, 0)
		flat.content_margin_right = 12
		flat.content_margin_left = 12
		var foc := flat.duplicate() as StyleBoxFlat
		foc.bg_color = Color("14532d")
		foc.border_color = UiTheme.ACCENT
		foc.set_border_width_all(2)
		foc.set_corner_radius_all(6)
		ctrl.add_theme_stylebox_override("normal", flat)
		ctrl.add_theme_stylebox_override("focus", foc)
	h.add_child(ctrl)
	return box


func _color_index(c: Color) -> int:
	var best := 0
	var bd := 99.0
	for i in TeamFactory.KIT_COLORS.size():
		var k: Color = TeamFactory.KIT_COLORS[i]
		var d := absf(k.r - c.r) + absf(k.g - c.g) + absf(k.b - c.b)
		if d < bd:
			bd = d
			best = i
	return best


func _rebuild_player_box() -> void:
	for ch in player_box.get_children():
		ch.queue_free()
	var names: Array = []
	for i in 6:
		names.append("%s  %s" % [team.role_of(i), (team.players[i] as PlayerData).name])
	player_box.add_child(Screen.cycler("Player", names, sel, func(i):
		sel = i
		_rebuild_player_box(), 0))
	var pd: PlayerData = team.players[sel]
	var ne := LineEdit.new()
	ne.text = pd.name
	ne.max_length = 24
	ne.custom_minimum_size = Vector2(370, 44)
	ne.text_changed.connect(func(t):
		if t.strip_edges() != "":
			pd.name = t)
	player_box.add_child(_labeled("Name", ne))
	var nums: Array = []
	for n in range(1, 100):
		nums.append(n)
	player_box.add_child(Screen.cycler("Number", nums, pd.number - 1, func(i):
		pd.number = i + 1
		_rebuild_preview(), 0))
	player_box.add_child(Screen.cycler("Skin", ["1", "2", "3", "4", "5", "6"], pd.skin, func(i):
		pd.skin = i
		_rebuild_preview(), 0))
	player_box.add_child(Screen.cycler("Hair", Looks.HAIR_NAMES, pd.hair % Looks.HAIR_NAMES.size(), func(i):
		pd.hair = i
		_rebuild_preview(), 0))
	player_box.add_child(Screen.cycler("Hair colour", ["Black", "Dark brown", "Brown", "Blond", "Red", "Grey"], pd.hair_color, func(i):
		pd.hair_color = i
		_rebuild_preview(), 0))
	player_box.add_child(Screen.cycler("Beard", Looks.BEARD_NAMES, mini(pd.beard, 1), func(i):
		pd.beard = i
		_rebuild_preview(), 0))
	var stats := "  ".join(C.STAT_KEYS.map(func(k): return "%s %d" % [k.to_upper(), pd.stat(k)]))
	player_box.add_child(UiTheme.label(stats, 18, UiTheme.MUTED))
	if sel > 0:
		player_box.add_child(UiTheme.button("Swap with the slot above (%s)" % team.role_of(sel - 1), func():
			var tmp = team.players[sel - 1]
			team.players[sel - 1] = team.players[sel]
			team.players[sel] = tmp
			sel -= 1
			_rebuild_player_box(), 0))
	_rebuild_preview()


func _rebuild_preview() -> void:
	if preview_root == null:
		return
	for ch in preview_root.get_children():
		ch.queue_free()
	for i in 6:
		var v := PlayerView.new()
		preview_root.add_child(v)
		var gk := Color("22c55e") if i == 0 else Color(0, 0, 0, 0)
		v.build(team.color1, team.color2, team.players[i], gk)
		var x := (i - 2.5) * 0.72
		v.pose(Vector2(x, 0), PI * 0.5, C.ST_RUN, 0, 0.0, 0.0, 0.0)
		v.rotation.y = 0.0 if i != sel else 0.4
		v.set_controller(0 if i == sel else -1)
		v.tag.visible = false


func back() -> void:
	if Game.career:
		Game.save_career()
		Game.show_menu(CareerHub.new())
	else:
		Game.show_menu()
