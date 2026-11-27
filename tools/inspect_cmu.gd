extends SceneTree
## Debug: lists the bone tracks of the CMU clip file and the root/pelvis yaw over time.

func _initialize() -> void:
	var ps: PackedScene = load("res://assets/third_party/cmu/cmu_football.glb")
	var inst := ps.instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var names := ap.get_animation_list()
	var a := ap.get_animation(names[0])
	for t in mini(a.get_track_count(), 6):
		print("track ", t, " ", a.track_get_path(t), " type ", a.track_get_type(t))
	for nm in names:
		if not (nm.contains("140_08") or nm.contains("105_43")):
			continue
		var an := ap.get_animation(nm)
		for t in an.get_track_count():
			var p := str(an.track_get_path(t))
			if an.track_get_type(t) == Animation.TYPE_ROTATION_3D and (p.ends_with(":root") or p.ends_with(":pelvis")):
				var line := nm + " " + p + ":"
				var tt := 0.0
				while tt < an.length:
					var f := Basis(an.rotation_track_interpolate(t, tt)) * Vector3.BACK
					line += " %.1f:%d" % [tt, int(rad_to_deg(atan2(f.x, f.z)))]
					tt += 0.5
				print(line)
	inst.free()
	quit()
