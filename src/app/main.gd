extends Node
## Entry point.
## Debug: OP_AUTOPLAY=1 starts a CPU vs CPU match; OP_SCREEN=<name> opens a screen
## (menu, setup, practice, options, slots, new, hub, upgrade, squad, leaders, history, editor).


func _ready() -> void:
	if OS.get_environment("OP_AUTOPLAY") != "":
		var pair := TeamFactory.quick_pair(int(OS.get_environment("OP_SEED")) if OS.get_environment("OP_SEED") != "" else 3)
		var cam := int(OS.get_environment("OP_CAMERA")) if OS.get_environment("OP_CAMERA") != "" else 0
		var humans: Array = [{"id": 0, "team": 0, "device": OS.get_environment("OP_DEVICE") if OS.get_environment("OP_DEVICE") != "" else "kb1"}] if OS.get_environment("OP_HUMAN") != "" else []
		Game.play_match({"teams": pair, "humans": humans, "length": 120.0, "camera": cam, "seed": 5}, func(_r): get_tree().quit())
		return
	var screen := OS.get_environment("OP_SCREEN")
	if screen != "":
		_debug_screen(screen)
		return
	Game.show_menu()


func _debug_screen(name: String) -> void:
	if name in ["hub", "upgrade", "squad", "leaders", "history", "editor"]:
		var c := Career.create(99)
		# play a few rounds so tables and stats have content
		for i in 4:
			var fx := c.next_user_fixture()
			var home: bool = fx[0] == c.user_team
			c.record_user_match({"score": [2, 1] if home else [1, 2], "pstats": []})
		c.history.append({"season": 0, "champion": c.divisions[0][0], "champion_name": c.team(c.divisions[0][0]).name,
			"user_div": 3, "user_pos": 5, "user_playoff": "lost in the semi-final"})
		Game.career = c
		Game.career_slot = 2
	match name:
		"clips":
			_clip_sheet(OS.get_environment("OP_CLIP"))
		"careermatch":
			# full loop: hub -> match (CPU only, 15 s) -> record -> upgrade screen
			var c := Career.create(5, {"devices": [], "length": 15.0})
			Game.career = c
			Game.career_slot = 2
			var hub := CareerHub.new()
			Game.show_menu(hub)
			await get_tree().process_frame
			await get_tree().process_frame
			hub._play(c.next_user_fixture())
		"setup":
			Game.show_menu(MatchSetup.new())
		"practice":
			var s := MatchSetup.new()
			s.practice = true
			Game.show_menu(s)
		"options":
			Game.show_menu(OptionsScreen.new())
		"slots":
			Game.show_menu(CareerSlots.new())
		"new":
			Game.show_menu(NewCareer.new())
		"hub":
			Game.show_menu(CareerHub.new())
		"upgrade":
			Game.show_menu(UpgradeScreen.new())
		"squad":
			Game.show_menu(SquadScreen.new())
		"leaders":
			Game.show_menu(LeadersScreen.new())
		"history":
			Game.show_menu(HistoryScreen.new())
		"editor":
			var ed := TeamEditor.new()
			ed.team = Game.career.user()
			ed.first_time = true
			Game.show_menu(ed)
		_:
			Game.show_menu()


func _clip_sheet(clip: String) -> void:
	## Five frames of one animation clip side by side (OP_SCREEN=clips OP_CLIP=<name>).
	var root3 := Node3D.new()
	get_tree().root.add_child.call_deferred(root3)
	await get_tree().process_frame
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.3, 7.5), Vector3(0, 0.9, 0), Vector3.UP)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	l.shadow_enabled = true
	root3.add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1e293b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	root3.add_child(env)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 10)
	fl.mesh = pm
	fl.material_override = Looks.mat(Color("2b6b35"))
	root3.add_child(fl)
	var pd := PlayerData.new()
	for i in 5:
		var v := PlayerView.new()
		root3.add_child(v)
		v.build(Color("d62828"), Color("f8fafc"), pd)
		v.position = Vector3((i - 2) * 1.5, 0, 0)
		v.rotation.y = deg_to_rad(60)
		var st := OS.get_environment("OP_STATE")
		if st == "dive":
			v.set_meta("dbg", [C.ST_DIVE, 1, C.GK_DIVE_TIME * (1.0 - i / 4.0)])
		elif st == "bicycle":
			v.set_meta("dbg", [C.ST_AERIAL, MatchSim.AER_BICYCLE, C.AERIAL_TIME * (1.0 - i / 4.0)])
		elif st == "down":
			v.set_meta("dbg", [C.ST_DOWN, 0, C.DOWN_TIME * (1.0 - i / 4.0)])
		else:
			v.freeze_clip(clip, i / 4.0)
	var lbl := Label3D.new()
	lbl.text = clip
	lbl.font_size = 64
	lbl.pixel_size = 0.005
	lbl.position = Vector3(0, 2.4, 0)
	root3.add_child(lbl)


func _process(_dt: float) -> void:
	for n in get_tree().root.get_children():
		for v in n.get_children():
			if v is PlayerView and v.has_meta("dbg"):
				var d: Array = v.get_meta("dbg")
				var pv := v as PlayerView
				var keep := pv.position
				pv.pose(Vector2(keep.x, keep.z), PI * 0.5 - (0.0 if d[0] == C.ST_DIVE else deg_to_rad(60)), d[0], d[1], 0.0, d[2], 0.016)
				if d[0] == C.ST_DIVE:
					continue
				var len := pv.anim.current_animation_length
				pv.anim.seek(len * clampf(1.0 - d[2] / maxf(_dur(d[0]), 0.01), 0.0, 1.0), true)
				pv.anim.speed_scale = 0.0


func _dur(st: int) -> float:
	match st:
		C.ST_DIVE:
			return C.GK_DIVE_TIME
		C.ST_AERIAL:
			return C.AERIAL_TIME
	return C.DOWN_TIME
