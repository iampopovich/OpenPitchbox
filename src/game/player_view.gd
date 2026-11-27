class_name PlayerView
extends Node3D
## Procedural big-headed footballer built from primitives and animated from SimPlayer state.

var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var ring: MeshInstance3D
var tag: Label3D
var number_label: Label3D
var phase := 0.0
var team_color := Color.RED

const HIP_Y := 0.9


func build(kit1: Color, kit2: Color, pd: PlayerData, gk_kit: Color = Color(0, 0, 0, 0)) -> void:
	var c1 := kit1
	var c2 := kit2
	var is_gk := gk_kit.a > 0.0
	if is_gk:
		c1 = gk_kit
		c2 = Color("111827")
	team_color = c1
	var skin: Color = Looks.SKIN[clampi(pd.skin, 0, Looks.SKIN.size() - 1)]
	var hair_c: Color = Looks.HAIR_COLOR[clampi(pd.hair_color, 0, Looks.HAIR_COLOR.size() - 1)]
	body = Node3D.new()
	body.position.y = HIP_Y
	add_child(body)
	# torso
	_mesh(body, _capsule(0.22, 0.66), Looks.mat(c1), Vector3(0, 0.3, 0))
	# collar stripe
	_mesh(body, _cyl(0.17, 0.05), Looks.mat(c2), Vector3(0, 0.6, 0))
	# shorts
	_mesh(body, _cyl(0.21, 0.24), Looks.mat(c2), Vector3(0, -0.02, 0))
	# head
	head = Node3D.new()
	head.position = Vector3(0, 0.98, 0)
	body.add_child(head)
	_mesh(head, _sphere(0.31), Looks.mat(skin, 0.6), Vector3.ZERO)
	_mesh(head, _sphere(0.045), Looks.mat(Color("111111"), 0.3), Vector3(-0.11, 0.04, -0.27))
	_mesh(head, _sphere(0.045), Looks.mat(Color("111111"), 0.3), Vector3(0.11, 0.04, -0.27))
	_mesh(head, _sphere(0.05), Looks.mat(skin.darkened(0.12), 0.6), Vector3(0, -0.04, -0.3))
	_mesh(head, _sphere(0.07), Looks.mat(skin, 0.6), Vector3(-0.31, 0, 0))
	_mesh(head, _sphere(0.07), Looks.mat(skin, 0.6), Vector3(0.31, 0, 0))
	_build_hair(pd.hair, hair_c)
	_build_beard(pd.beard, hair_c)
	# neck
	_mesh(body, _cyl(0.09, 0.2), Looks.mat(skin, 0.6), Vector3(0, 0.7, 0))
	# arms
	arm_l = _limb(body, Vector3(-0.29, 0.55, 0), 0.075, 0.55, c1, skin)
	arm_r = _limb(body, Vector3(0.29, 0.55, 0), 0.075, 0.55, c1, skin)
	if is_gk:
		_mesh(arm_l, _sphere(0.1), Looks.mat(Color("f8fafc")), Vector3(0, -0.6, 0))
		_mesh(arm_r, _sphere(0.1), Looks.mat(Color("f8fafc")), Vector3(0, -0.6, 0))
	# legs
	leg_l = _leg(body, Vector3(-0.11, -0.08, 0), skin, c1)
	leg_r = _leg(body, Vector3(0.11, -0.08, 0), skin, c1)
	# number on the back
	number_label = Label3D.new()
	number_label.text = str(pd.number)
	number_label.font_size = 64
	number_label.pixel_size = 0.004
	number_label.modulate = c2
	number_label.outline_size = 8
	number_label.outline_modulate = c1.darkened(0.5)
	number_label.position = Vector3(0, 0.36, 0.235)
	number_label.rotation.y = 0.0
	body.add_child(number_label)
	# controller ring + tag
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.03
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 72
	tag.pixel_size = 0.006
	tag.outline_size = 12
	tag.position = Vector3(0, 2.55, 0)
	tag.no_depth_test = true
	tag.visible = false
	add_child(tag)


func _build_hair(style: int, c: Color) -> void:
	var m := Looks.mat(c, 0.9)
	match style:
		0:
			var mi := _mesh(head, _sphere(0.325), m, Vector3(0, 0.07, 0.03))
			mi.scale = Vector3(1, 0.8, 1)
		1:
			pass
		2:
			_mesh(head, _sphere(0.4), m, Vector3(0, 0.12, 0.06))
		3:
			_mesh(head, _box(Vector3(0.09, 0.2, 0.55)), m, Vector3(0, 0.3, 0.02))
		4:
			var mi2 := _mesh(head, _sphere(0.33), m, Vector3(0, 0.06, 0.04))
			mi2.scale = Vector3(1, 0.85, 1)
			_mesh(head, _capsule(0.2, 0.55), m, Vector3(0, -0.12, 0.17))
		5:
			for i in 5:
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.1
				cone.height = 0.24
				var a := (i - 2) * 0.45
				var mi3 := _mesh(head, cone, m, Vector3(sin(a) * 0.2, 0.28 + cos(a) * 0.02, 0.05 + absf(a) * 0.05))
				mi3.rotation.z = -a * 0.8


func _build_beard(style: int, c: Color) -> void:
	var m := Looks.mat(c, 0.95)
	match style:
		1:
			var mi := _mesh(head, _sphere(0.3), Looks.mat(c.lerp(Color(0.6, 0.45, 0.35), 0.5), 0.95), Vector3(0, -0.07, -0.02))
			mi.scale = Vector3(1.02, 0.75, 1.02)
		2:
			var mi2 := _mesh(head, _sphere(0.27), m, Vector3(0, -0.14, -0.08))
			mi2.scale = Vector3(1.05, 0.8, 1)
		3:
			_mesh(head, _sphere(0.08), m, Vector3(0, -0.24, -0.24))


func _limb(parent: Node3D, at: Vector3, r: float, l: float, sleeve: Color, skin: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	_mesh(pivot, _capsule(r + 0.015, l * 0.45), Looks.mat(sleeve), Vector3(0, -l * 0.2, 0))
	_mesh(pivot, _capsule(r, l * 0.7), Looks.mat(skin, 0.6), Vector3(0, -l * 0.55, 0))
	return pivot


func _leg(parent: Node3D, at: Vector3, skin: Color, sock: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	_mesh(pivot, _capsule(0.09, 0.5), Looks.mat(skin, 0.6), Vector3(0, -0.25, 0))
	_mesh(pivot, _cyl(0.085, 0.32), Looks.mat(sock), Vector3(0, -0.6, 0))
	_mesh(pivot, _box(Vector3(0.13, 0.09, 0.26)), Looks.mat(Color("111111"), 0.4), Vector3(0, -0.79, -0.05))
	return pivot


func _mesh(parent: Node3D, m: Mesh, mt: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	mi.position = at
	parent.add_child(mi)
	return mi


static var _mesh_cache := {}


func _capsule(r: float, h: float) -> Mesh:
	var key := "cap%.3f_%.3f" % [r, h]
	if not _mesh_cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 12
		m.rings = 4
		_mesh_cache[key] = m
	return _mesh_cache[key]


func _cyl(r: float, h: float) -> Mesh:
	var key := "cyl%.3f_%.3f" % [r, h]
	if not _mesh_cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 12
		_mesh_cache[key] = m
	return _mesh_cache[key]


func _sphere(r: float) -> Mesh:
	var key := "sph%.3f" % r
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 16
		m.rings = 8
		_mesh_cache[key] = m
	return _mesh_cache[key]


func _box(s: Vector3) -> Mesh:
	var key := "box%s" % s
	if not _mesh_cache.has(key):
		var m := BoxMesh.new()
		m.size = s
		_mesh_cache[key] = m
	return _mesh_cache[key]


func set_controller(human_slot: int) -> void:
	## human_slot: -1 = AI, 0..3 = P1..P4
	if human_slot < 0:
		ring.visible = false
		tag.visible = false
		return
	var c: Color = Looks.HUMAN_COLORS[human_slot % 4]
	ring.visible = true
	ring.material_override = Looks.unshaded(c)
	tag.visible = true
	tag.text = "P%d" % (human_slot + 1)
	tag.modulate = c
	tag.outline_modulate = Color(0, 0, 0, 0.8)


## Applies a pose. state/anim/state_t come from SimPlayer (or a replay snapshot).
func pose(pos: Vector2, facing_angle: float, state: int, anim: int, speed: float, state_t: float, dt: float) -> void:
	position = Vector3(pos.x, 0, pos.y)
	var f := Vector2.from_angle(facing_angle)
	rotation.y = atan2(-f.x, -f.y)
	var run := clampf(speed / 6.5, 0.0, 1.0)
	phase += dt * (3.0 + speed * 2.1)
	var swing := sin(phase) * run * 0.95
	var hip := HIP_Y + absf(sin(phase)) * 0.05 * run
	var b_rx := -0.12 * run
	var b_rz := 0.0
	var al := Vector3(-swing * 0.8, 0, -0.12)
	var ar := Vector3(swing * 0.8, 0, 0.12)
	var ll := Vector3(swing, 0, 0)
	var lr := Vector3(-swing, 0, 0)
	var head_rx := 0.0
	match state:
		C.ST_SLIDE:
			hip = 0.38
			b_rx = 1.15
			ll = Vector3(1.45, 0, 0)
			lr = Vector3(0.9, 0, 0)
			al = Vector3(0.3, 0, -0.9)
			ar = Vector3(0.3, 0, 0.9)
			head_rx = -0.8
		C.ST_DOWN, C.ST_RECOVER:
			var k := clampf(state_t / C.DOWN_TIME, 0.0, 1.0)
			hip = lerpf(0.75, 0.25, k)
			b_rx = lerpf(0.3, 1.45, k)
			ll = Vector3(lerpf(0.2, 1.4, k), 0, 0)
			lr = Vector3(lerpf(0.1, 1.2, k), 0, 0)
			al = Vector3(0, 0, -1.2 * k)
			ar = Vector3(0, 0, 1.2 * k)
			head_rx = -0.9 * k
		C.ST_AERIAL:
			var p := 1.0 - clampf(state_t / C.AERIAL_TIME, 0.0, 1.0)
			var jump := sin(p * PI)
			match anim:
				MatchSim.AER_HEADER:
					hip += jump * 0.55
					b_rx = -0.35 * jump
					head_rx = -0.6 * jump
					ll = Vector3(-0.4 * jump, 0, 0)
					lr = Vector3(0.3 * jump, 0, 0)
					al = Vector3(0, 0, -0.9 * jump)
					ar = Vector3(0, 0, 0.9 * jump)
				MatchSim.AER_BICYCLE:
					hip += jump * 0.75
					b_rx = lerpf(0.0, 2.7, minf(p * 1.6, 1.0))
					ll = Vector3(lerpf(0.2, 2.6, minf(p * 2.0, 1.0)), 0, 0)
					lr = Vector3(0.8, 0, 0)
					al = Vector3(0, 0, -1.4)
					ar = Vector3(0, 0, 1.4)
				_:
					hip += jump * 0.25
					b_rx = 0.35 * jump
					ll = Vector3(lerpf(-0.6, 1.8, minf(p * 2.5, 1.0)), 0, 0)
					lr = Vector3(-0.1, 0, 0)
					al = Vector3(0, 0, -1.0)
					ar = Vector3(0, 0, 1.0)
		C.ST_DIVE:
			var side := 1.0 if anim > 0 else -1.0
			var p2 := 1.0 - clampf(state_t / C.GK_DIVE_TIME, 0.0, 1.0)
			# world dive side is along z; the character faces x, so roll around the body axis
			hip = 0.75 + sin(minf(p2 * 1.5, 1.0) * PI) * 0.35
			b_rz = side * lerpf(0.4, 1.35, minf(p2 * 2.0, 1.0))
			al = Vector3(0, 0, -2.8)
			ar = Vector3(0, 0, 2.8)
			ll = Vector3(0.2, 0, 0)
			lr = Vector3(-0.1, 0, 0)
		C.ST_KICK:
			var p3 := 1.0 - clampf(state_t / 0.22, 0.0, 1.0)
			lr = Vector3(lerpf(-0.7, 1.3, p3), 0, 0)
			ll = Vector3(-0.15, 0, 0)
			al = Vector3(0.2, 0, -0.6)
			ar = Vector3(-0.3, 0, 0.6)
			b_rx = 0.12
		C.ST_HOLD:
			al = Vector3(1.2, 0, -0.1)
			ar = Vector3(1.2, 0, 0.1)
		C.ST_CELEBRATE:
			var t := Time.get_ticks_msec() / 1000.0
			match anim:
				0:
					al = Vector3(0, 0, -2.9 + sin(t * 9.0) * 0.2)
					ar = Vector3(0, 0, 2.9 - sin(t * 9.0) * 0.2)
				1:
					al = Vector3(0, 0, -1.55)
					ar = Vector3(0, 0, 1.55)
					b_rz = sin(t * 3.0) * 0.35
				_:
					hip = 0.5
					b_rx = 0.45
					ll = Vector3(-1.5, 0, 0)
					lr = Vector3(-1.5, 0, 0)
					al = Vector3(0, 0, -2.6)
					ar = Vector3(0, 0, 2.6)
					head_rx = -0.5
	body.position.y = hip
	body.rotation = Vector3(b_rx, 0, b_rz)
	head.rotation.x = head_rx
	arm_l.rotation = al
	arm_r.rotation = ar
	leg_l.rotation = ll
	leg_r.rotation = lr
	ring.rotation.y += dt * 2.0
