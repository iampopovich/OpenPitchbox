class_name PlayerView
extends Node3D
## A footballer: CC0 Quaternius rigged character in kit colours, skeletal animations
## (locomotion, slide, falls, celebrations) plus procedural overlays for football moves.

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var overlay: PoseOverlay
var ring: MeshInstance3D
var tag: Label3D
var marker: MeshInstance3D
var team_marker := false        # small kit-coloured marker over every player
var team_color := Color.WHITE
var number_label: Label3D
var cur := ""
var b := {}                    # bone name -> index
var arm_side := {}             # bone name -> +1/-1 (which side of the body, model x)
var ov_w := 0.0
var last_state := -1
var last_anim := -1
var oneshot := ""
var oneshot_t := 0.0
var oneshot_min := 0.0
var tilt := 0.0                 # sideways body tilt (keeper dive), reset every frame
var catch_low := false          # set by the match view before a keeper catch

# Native ground speeds of the source animations (m/s), used to match feet to motion
const JOG_SPEED := 3.3
const SPRINT_SPEED := 6.0


func build(kit1: Color, kit2: Color, pd: PlayerData, gk_kit: Color = Color(0, 0, 0, 0)) -> void:
	var is_gk := gk_kit.a > 0.0
	var shirt := gk_kit if is_gk else kit1
	var shorts := Color("1f2937") if is_gk else kit2
	var socks := shorts if is_gk else kit1
	team_color = shirt
	var skin: Color = Looks.SKIN[clampi(pd.skin, 0, Looks.SKIN.size() - 1)]
	var hair_c: Color = Looks.HAIR_COLOR[clampi(pd.hair_color, 0, Looks.HAIR_COLOR.size() - 1)]
	model = CharacterLib.scene().instantiate()
	add_child(model)
	skel = CharacterLib._find(model, "Skeleton3D") as Skeleton3D
	for c in skel.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.name.begins_with("SuperHero"):
				mi.mesh = CharacterLib.body_mesh(mi.mesh)
				mi.material_override = CharacterLib.body_material(shirt, shorts, socks, skin, is_gk)
			elif mi.name.begins_with("Eyebrows"):
				_tint(mi, hair_c)
	var styles := ["parted", "", "buzzed", "long"]
	var style: String = styles[clampi(pd.hair, 0, 99) % styles.size()]
	if style != "":
		_attach_hair(style, hair_c)
	if pd.beard > 0:
		_attach_hair("beard", hair_c)
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", CharacterLib.library())
	overlay = PoseOverlay.new()
	skel.add_child(overlay)
	for n in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		b[n] = skel.find_bone(n)
	for n in ["upperarm_l", "upperarm_r", "thigh_l", "thigh_r"]:
		var gp := skel.get_bone_global_rest(b[n]).origin
		arm_side[n] = 1.0 if gp.x >= 0.0 else -1.0
	_play("Idle", 0.0)
	number_label = Label3D.new()
	number_label.text = str(pd.number)
	number_label.font_size = 64
	number_label.pixel_size = 0.0028
	number_label.modulate = shorts if not is_gk else Color.WHITE
	number_label.outline_size = 6
	number_label.outline_modulate = shirt.darkened(0.6)
	add_child(number_label)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	ring.scale = Vector3(1, 0.08, 1)
	ring.position.y = 0.02
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.24
	cone.bottom_radius = 0.0
	cone.height = 0.42
	cone.radial_segments = 3
	marker.mesh = cone
	marker.position = Vector3(0, 2.2, 0)
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 64
	tag.pixel_size = 0.006
	tag.outline_size = 8
	tag.position = Vector3(0, 2.72, 0)
	tag.no_depth_test = true
	tag.visible = false
	add_child(tag)


func _tint(mi: MeshInstance3D, c: Color) -> void:
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s)
		if m is BaseMaterial3D:
			var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.albedo_color = Color(c.r * 2.2, c.g * 2.2, c.b * 2.2)
			mi.set_surface_override_material(s, d)


func _attach_hair(key: String, c: Color) -> void:
	var inst := CharacterLib.hair_scene(key).instantiate()
	var meshes: Array = []
	_collect(inst, meshes)
	for m in meshes:
		var mi := m as MeshInstance3D
		var skin_res := mi.skin
		mi.get_parent().remove_child(mi)
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.skin = skin_res
		_tint(mi, c)
	inst.free()


func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for ch in n.get_children():
		_collect(ch, out)


func _play(name: String, blend: float = 0.18) -> void:
	if name == cur or not anim.has_animation(name):
		return
	cur = name
	anim.play(name, blend)


func set_controller(human_slot: int) -> void:
	## human_slot: -1 = AI, 0..3 = P1..P4
	if human_slot < 0:
		ring.visible = false
		tag.visible = false
		marker.visible = team_marker
		if team_marker:
			marker.material_override = _marker_mat(team_color)
			marker.scale = Vector3(0.5, 0.5, 0.5)
		return
	marker.scale = Vector3.ONE
	var c: Color = Looks.HUMAN_COLORS[human_slot % 4]
	ring.visible = true
	ring.material_override = Looks.unshaded(c)
	marker.visible = true
	marker.material_override = _marker_mat(c)
	tag.visible = true
	tag.text = "P%d" % (human_slot + 1)
	tag.modulate = c
	tag.outline_modulate = Color(0, 0, 0, 0.8)


## Applies a pose. state/anim/state_t come from SimPlayer (or a replay snapshot).
## Motion-capture one-shots are started on state changes; locomotion loops fill the rest.
func pose(pos: Vector2, facing_angle: float, state: int, anim_id: int, speed: float, state_t: float, dt: float) -> void:
	position = Vector3(pos.x, 0, pos.y)
	var f := Vector2.from_angle(facing_angle)
	var yaw := atan2(f.x, f.y)
	var X := Vector3.RIGHT
	var rots: Array = []
	var want_w := 0.0
	var y_off := 0.0
	if state != last_state or anim_id != last_anim:
		_enter(state, anim_id, last_state)
		last_state = state
		last_anim = anim_id
	oneshot_t += dt
	match state:
		C.ST_DIVE:
			# side dive: the arms-up frame of the catch clip, whole body tipped onto its side
			# around the feet and lifted, so the limbs keep a natural mocap shape
			var side := 1.0 if anim_id > 0 else -1.0
			var p3 := 1.0 - clampf(state_t / C.GK_DIVE_TIME, 0.0, 1.0)
			var lay := smoothstep(0.0, 0.35, p3)
			if cur != "Idle":
				_play("Idle", 0.08)
			anim.speed_scale = 0.0
			var land := smoothstep(0.62, 0.95, p3)
			tilt = -side * _dive_sign() * lay * lerpf(1.35, 1.5, land)
			y_off = sin(minf(p3 * 1.3, 1.0) * PI) * 0.45 + lay * lerpf(0.35, 0.14, land)
			var reach := smoothstep(0.0, 0.25, p3)
			rots = [[b["upperarm_l"], Vector3.BACK, -2.6 * reach], [b["upperarm_r"], Vector3.BACK, 2.6 * reach],
				[b["lowerarm_l"], Vector3.BACK, -0.2 * reach], [b["lowerarm_r"], Vector3.BACK, 0.2 * reach],
				[b["thigh_l"], Vector3.BACK, 0.12 * reach], [b["thigh_r"], Vector3.BACK, -0.12 * reach]]
			want_w = 1.0
		C.ST_AERIAL:
			if anim_id == MatchSim.AER_BICYCLE:
				var p := 1.0 - clampf(state_t / C.AERIAL_TIME, 0.0, 1.0)
				y_off = sin(p * PI) * 0.55
				rots = [[b["pelvis"], X, -1.75 * sin(minf(p * 1.25, 1.0) * PI * 0.5)], [b["thigh_r"], X, -lerpf(0.3, 1.6, minf(p * 2.0, 1.0))]]
				want_w = 1.0
			elif anim_id == MatchSim.AER_HEADER:
				var p2 := 1.0 - clampf(state_t / C.AERIAL_TIME, 0.0, 1.0)
				rots = [[b["neck_01"], X, 0.5 * sin(p2 * PI) - 0.35 * maxf(0.0, p2 - 0.5)]]
				want_w = 1.0
		C.ST_RUN, C.ST_KICK, C.ST_HOLD, C.ST_RECOVER:
			if oneshot == "" or (oneshot_t > oneshot_min and speed > 2.5) or not anim.is_playing():
				oneshot = ""
				if state != C.ST_HOLD:
					_locomotion(speed)
	rotation.y = yaw
	ov_w = move_toward(ov_w, want_w, dt * 10.0) if dt > 0.0 else want_w
	overlay.set_rot(rots if not rots.is_empty() else overlay.rotations, ov_w)
	model.rotation.z = tilt
	tilt = 0.0
	model.position.y = y_off
	_place_number()
	ring.rotation.y += dt * 2.0
	if marker.visible:
		var t := Time.get_ticks_msec() / 1000.0
		marker.position.y = (2.2 if marker.scale.x > 0.9 else 2.1) + (sin(t * 5.0) * 0.06 if marker.scale.x > 0.9 else 0.0)
		marker.rotation.y += dt * 2.5
		tag.position.y = marker.position.y + 0.45


func _locomotion(speed: float) -> void:
	var loco := "Idle"
	var spd := 1.0
	if speed > 0.5:
		if speed < 4.3:
			loco = "Jog_Fwd"
			spd = clampf(speed / JOG_SPEED, 0.6, 1.5)
		else:
			loco = "Sprint"
			spd = clampf(speed / SPRINT_SPEED, 0.75, 1.4)
	_play(loco, 0.22)
	anim.speed_scale = spd


func _shot(clip: String, blend: float, min_t: float, spd: float = 1.0) -> void:
	if not anim.has_animation(clip):
		return
	cur = ""
	_play(clip, blend)
	anim.speed_scale = spd
	oneshot = clip
	oneshot_t = 0.0
	oneshot_min = min_t


func _enter(state: int, anim_id: int, prev: int) -> void:
	match state:
		C.ST_KICK:
			if prev == C.ST_HOLD:
				_shot("GK_Throw", 0.12, 0.5, 1.2)
			elif anim_id == 1:
				_shot("Kick_Shot" if randf() < 0.6 else "Kick_Shot2", 0.08, 0.45, 1.25)
			else:
				_shot("Kick_Pass", 0.08, 0.35, 1.25)
		C.ST_SLIDE:
			_shot("Slide", 0.08, 0.4, 1.3)
		C.ST_RECOVER:
			_shot("Slide_Exit", 0.1, 0.2, 1.2)
		C.ST_DOWN:
			_shot("Hit_Knockback", 0.08, 99.0, 1.2)
			get_tree().create_timer(0.45).timeout.connect(func():
				if last_state == C.ST_DOWN:
					_shot("GetUp", 0.25, 99.0, 2.4))
		C.ST_AERIAL:
			match anim_id:
				MatchSim.AER_HEADER:
					_shot("Header_Jump", 0.08, 99.0, 1.4)
				MatchSim.AER_BICYCLE:
					_shot("Jump", 0.08, 99.0, 1.0)
				_:
					_shot("Kick_Volley", 0.08, 99.0, 1.3)
		C.ST_DIVE:
			oneshot = "GK_Dive"
		C.ST_HOLD:
			_shot("GK_Scoop" if catch_low else "GK_Catch", 0.1, 99.0, 1.2)
		C.ST_CELEBRATE:
			_shot(["Celebrate_Hop", "Celebrate_JumpTurn", "Dance"][clampi(anim_id, 0, 2)], 0.2, 99.0, 1.0)


func _dive_sign() -> float:
	# converts a world-z dive side into the model's roll direction for the current facing
	return signf(cos(rotation.y)) if absf(cos(rotation.y)) > 0.1 else 1.0


func _place_number() -> void:
	var bi: int = b["spine_03"]
	if bi < 0:
		return
	var gp := skel.global_transform * skel.get_bone_global_pose(bi).origin
	var back := -global_basis.z
	number_label.global_position = gp + back * 0.17 + Vector3(0, 0.02, 0)
	number_label.global_rotation = Vector3(0, rotation.y + PI, 0)


static var _marker_cache := {}


static func _marker_mat(c: Color) -> StandardMaterial3D:
	if not _marker_cache.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		m.render_priority = 10
		_marker_cache[c] = m
	return _marker_cache[c]


func hands_pos() -> Vector3:
	var hl := skel.find_bone("hand_l")
	var hr := skel.find_bone("hand_r")
	var a := skel.global_transform * skel.get_bone_global_pose(hl).origin
	var c := skel.global_transform * skel.get_bone_global_pose(hr).origin
	return (a + c) * 0.5 + global_basis.z * 0.1


func freeze_clip(clip: String, t01: float) -> void:
	## Debug: shows one frame of a clip (used by the clip contact sheet).
	_shot(clip, 0.0, 99.0, 1.0)
	anim.seek(anim.current_animation_length * t01, true)
	anim.speed_scale = 0.0
