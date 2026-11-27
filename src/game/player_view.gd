class_name PlayerView
extends Node3D
## Procedural footballer with realistic proportions (about 1.8 m): jointed limbs
## (hips/knees, shoulders/elbows), animated from SimPlayer state.

var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var ring: MeshInstance3D
var tag: Label3D
var number_label: Label3D
var phase := 0.0

const HIP_Y := 0.95
const THIGH := 0.46
const SHIN := 0.44
const UPPER_ARM := 0.3
const FOREARM := 0.27


func build(kit1: Color, kit2: Color, pd: PlayerData, gk_kit: Color = Color(0, 0, 0, 0)) -> void:
	var c1 := kit1
	var c2 := kit2
	var is_gk := gk_kit.a > 0.0
	if is_gk:
		c1 = gk_kit
		c2 = Color("1f2937")
	var skin: Color = Looks.SKIN[clampi(pd.skin, 0, Looks.SKIN.size() - 1)]
	var hair_c: Color = Looks.HAIR_COLOR[clampi(pd.hair_color, 0, Looks.HAIR_COLOR.size() - 1)]
	var shirt := Looks.fabric(c1)
	var shorts := Looks.fabric(c2)
	var skin_m := Looks.skin(skin)
	body = Node3D.new()
	body.position.y = HIP_Y
	add_child(body)
	# pelvis + shorts
	_mesh(body, _cyl(0.15, 0.13, 0.2), shorts, Vector3(0, 0.02, 0))
	# torso: tapered shirt, shoulders
	var torso := _mesh(body, _cyl(0.19, 0.15, 0.5), shirt, Vector3(0, 0.33, 0))
	torso.scale = Vector3(1.0, 1.0, 0.68)
	var sh := _mesh(body, _sphere(0.1), shirt, Vector3(-0.17, 0.55, 0))
	sh.scale = Vector3(1.0, 0.8, 0.9)
	var sh2 := _mesh(body, _sphere(0.1), shirt, Vector3(0.17, 0.55, 0))
	sh2.scale = Vector3(1.0, 0.8, 0.9)
	var collar := _mesh(body, _cyl(0.075, 0.08, 0.04), Looks.fabric(c2), Vector3(0, 0.6, 0))
	collar.scale = Vector3(1, 1, 0.8)
	# neck + head
	_mesh(body, _cyl(0.05, 0.055, 0.12), skin_m, Vector3(0, 0.64, 0))
	head = Node3D.new()
	head.position = Vector3(0, 0.79, 0)
	body.add_child(head)
	var skull := _mesh(head, _sphere(0.105), skin_m, Vector3.ZERO)
	skull.scale = Vector3(0.92, 1.12, 1.0)
	var jaw := _mesh(head, _sphere(0.08), skin_m, Vector3(0, -0.06, -0.025))
	jaw.scale = Vector3(1.0, 0.9, 1.0)
	_mesh(head, _sphere(0.02), Looks.skin(skin.darkened(0.08)), Vector3(0, -0.01, -0.1))
	_mesh(head, _sphere(0.012), Looks.mat(Color("1a1a1a"), 0.3), Vector3(-0.035, 0.02, -0.088))
	_mesh(head, _sphere(0.012), Looks.mat(Color("1a1a1a"), 0.3), Vector3(0.035, 0.02, -0.088))
	_mesh(head, _sphere(0.025), skin_m, Vector3(-0.098, 0.0, 0))
	_mesh(head, _sphere(0.025), skin_m, Vector3(0.098, 0.0, 0))
	_build_hair(pd.hair, hair_c)
	_build_beard(pd.beard, hair_c)
	# arms: shoulder pivot -> upper arm (sleeve) -> elbow pivot -> forearm -> hand
	arm_l = _pivot(body, Vector3(-0.21, 0.54, 0))
	arm_r = _pivot(body, Vector3(0.21, 0.54, 0))
	for a in [arm_l, arm_r]:
		_mesh(a, _cyl(0.058, 0.05, UPPER_ARM * 0.55), shirt, Vector3(0, -UPPER_ARM * 0.27, 0))
		_mesh(a, _capsule(0.042, UPPER_ARM), skin_m if not is_gk else shirt, Vector3(0, -UPPER_ARM * 0.5, 0))
	fore_l = _pivot(arm_l, Vector3(0, -UPPER_ARM, 0))
	fore_r = _pivot(arm_r, Vector3(0, -UPPER_ARM, 0))
	for f in [fore_l, fore_r]:
		_mesh(f, _capsule(0.037, FOREARM), skin_m if not is_gk else shirt, Vector3(0, -FOREARM * 0.5, 0))
		var hand := _mesh(f, _sphere(0.045 if not is_gk else 0.06), skin_m if not is_gk else Looks.fabric(Color("f1f5f9")), Vector3(0, -FOREARM - 0.03, 0))
		hand.scale = Vector3(0.8, 1.1, 0.6)
	# legs: hip pivot -> thigh -> knee pivot -> shin + sock -> boot
	leg_l = _pivot(body, Vector3(-0.09, -0.04, 0))
	leg_r = _pivot(body, Vector3(0.09, -0.04, 0))
	for l in [leg_l, leg_r]:
		_mesh(l, _cyl(0.08, 0.075, THIGH * 0.42), shorts, Vector3(0, -THIGH * 0.18, 0))
		_mesh(l, _capsule(0.068, THIGH), skin_m, Vector3(0, -THIGH * 0.5, 0))
	shin_l = _pivot(leg_l, Vector3(0, -THIGH, 0))
	shin_r = _pivot(leg_r, Vector3(0, -THIGH, 0))
	for s in [shin_l, shin_r]:
		_mesh(s, _capsule(0.055, SHIN * 0.5), skin_m, Vector3(0, -0.07, 0))
		_mesh(s, _cyl(0.058, 0.048, SHIN * 0.75), Looks.fabric(c1 if not is_gk else c2), Vector3(0, -SHIN * 0.55, 0))
		_mesh(s, _box(Vector3(0.09, 0.07, 0.24)), Looks.mat(Color("101010"), 0.35), Vector3(0, -SHIN - 0.02, -0.05))
	# number on the back
	number_label = Label3D.new()
	number_label.text = str(pd.number)
	number_label.font_size = 48
	number_label.pixel_size = 0.0032
	number_label.modulate = c2
	number_label.outline_size = 6
	number_label.outline_modulate = c1.darkened(0.6)
	number_label.position = Vector3(0, 0.36, 0.11)
	body.add_child(number_label)
	# controller ring + tag
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
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 56
	tag.pixel_size = 0.005
	tag.outline_size = 10
	tag.position = Vector3(0, 2.25, 0)
	tag.no_depth_test = true
	tag.visible = false
	add_child(tag)


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _build_hair(style: int, c: Color) -> void:
	var m := Looks.mat(c, 0.95)
	match style:
		0:
			var mi := _mesh(head, _sphere(0.11), m, Vector3(0, 0.035, 0.008))
			mi.scale = Vector3(0.95, 0.95, 1.03)
		1:
			pass
		2:
			var mi2 := _mesh(head, _sphere(0.135), m, Vector3(0, 0.05, 0.015))
			mi2.scale = Vector3(1.0, 0.95, 1.0)
		3:
			_mesh(head, _sphere(0.108), Looks.mat(c.lerp(Color(0.4, 0.3, 0.25), 0.4), 0.95), Vector3(0, 0.02, 0.005))
			_mesh(head, _box(Vector3(0.035, 0.05, 0.2)), m, Vector3(0, 0.12, 0.0))
		4:
			var mi4 := _mesh(head, _sphere(0.112), m, Vector3(0, 0.03, 0.01))
			mi4.scale = Vector3(1.0, 1.0, 1.04)
			var tail := _mesh(head, _capsule(0.07, 0.24), m, Vector3(0, -0.06, 0.07))
			tail.scale = Vector3(1.3, 1, 0.6)
		5:
			var mi5 := _mesh(head, _sphere(0.11), m, Vector3(0, 0.04, 0.008))
			mi5.scale = Vector3(0.96, 1.05, 1.03)
			for i in 5:
				var a := (i - 2) * 0.4
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.03
				cone.height = 0.06
				var sp := _mesh(head, cone, m, Vector3(sin(a) * 0.06, 0.135, -0.02 + absf(a) * 0.03))
				sp.rotation.z = -a * 0.7


func _build_beard(style: int, c: Color) -> void:
	var m := Looks.mat(c, 0.95)
	match style:
		1:
			var mi := _mesh(head, _sphere(0.084), Looks.mat(c.lerp(Color(0.55, 0.42, 0.33), 0.55), 0.95), Vector3(0, -0.065, -0.02))
			mi.scale = Vector3(1.0, 0.85, 1.0)
		2:
			var mi2 := _mesh(head, _sphere(0.085), m, Vector3(0, -0.075, -0.025))
			mi2.scale = Vector3(1.02, 0.9, 1.0)
		3:
			_mesh(head, _sphere(0.03), m, Vector3(0, -0.12, -0.075))


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
		m.radial_segments = 14
		m.rings = 6
		_mesh_cache[key] = m
	return _mesh_cache[key]


func _cyl(top: float, bottom: float, h: float) -> Mesh:
	var key := "cyl%.3f_%.3f_%.3f" % [top, bottom, h]
	if not _mesh_cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = 16
		_mesh_cache[key] = m
	return _mesh_cache[key]


func _sphere(r: float) -> Mesh:
	var key := "sph%.3f" % r
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 18
		m.rings = 10
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
## Rotation conventions (x axis): positive swings a limb forward (-Z); knees bend with negative values.
func pose(pos: Vector2, facing_angle: float, state: int, anim: int, speed: float, state_t: float, dt: float) -> void:
	position = Vector3(pos.x, 0, pos.y)
	var f := Vector2.from_angle(facing_angle)
	rotation.y = atan2(-f.x, -f.y)
	var run := clampf(speed / 6.5, 0.0, 1.0)
	phase += dt * (2.0 + speed * 1.75)
	var s := sin(phase)
	var swing := s * (0.12 + 0.68 * run)
	var hip := HIP_Y - 0.03 * run + absf(cos(phase)) * 0.045 * run
	var b_rx := -0.14 * run
	var b_rz := 0.0
	var al := Vector3(-swing * 0.75, 0, -0.08)
	var ar := Vector3(swing * 0.75, 0, 0.08)
	var el := 0.35 + 0.9 * run
	var fl := Vector3(el, 0, 0)
	var fr := Vector3(el, 0, 0)
	var ll := Vector3(swing, 0, 0)
	var lr := Vector3(-swing, 0, 0)
	# knee folds most while the leg swings back through
	var kl := Vector3(-(0.08 + run * (0.35 + 1.1 * maxf(0.0, -cos(phase)))), 0, 0)
	var kr := Vector3(-(0.08 + run * (0.35 + 1.1 * maxf(0.0, cos(phase)))), 0, 0)
	var head_rx := 0.0
	match state:
		C.ST_SLIDE:
			hip = 0.3
			b_rx = 1.0
			ll = Vector3(1.5, 0, 0)
			kl = Vector3(-0.05, 0, 0)
			lr = Vector3(0.6, 0, 0.2)
			kr = Vector3(-1.4, 0, 0)
			al = Vector3(0.2, 0, -0.9)
			ar = Vector3(-0.4, 0, 0.7)
			fl = Vector3(0.3, 0, 0)
			fr = Vector3(0.3, 0, 0)
			head_rx = -0.7
		C.ST_DOWN, C.ST_RECOVER:
			var k := clampf(state_t / C.DOWN_TIME, 0.0, 1.0)
			hip = lerpf(0.8, 0.16, k)
			b_rx = lerpf(0.2, 1.5, k)
			ll = Vector3(lerpf(0.3, 1.45, k), 0, 0)
			lr = Vector3(lerpf(0.6, 1.2, k), 0, 0)
			kl = Vector3(lerpf(-1.0, -0.2, k), 0, 0)
			kr = Vector3(lerpf(-1.4, -0.6, k), 0, 0)
			al = Vector3(0, 0, -1.0 * k)
			ar = Vector3(0, 0, 1.0 * k)
			fl = Vector3(0.3, 0, 0)
			fr = Vector3(0.3, 0, 0)
			head_rx = -0.8 * k
		C.ST_AERIAL:
			var p := 1.0 - clampf(state_t / C.AERIAL_TIME, 0.0, 1.0)
			var jump := sin(p * PI)
			match anim:
				MatchSim.AER_HEADER:
					hip += jump * 0.5
					b_rx = 0.25 * jump - 0.35 * maxf(0.0, p - 0.4)
					head_rx = 0.6 * jump
					ll = Vector3(-0.3 * jump, 0, 0)
					lr = Vector3(0.4 * jump, 0, 0)
					kl = Vector3(-1.1 * jump, 0, 0)
					kr = Vector3(-0.8 * jump, 0, 0)
					al = Vector3(0.3, 0, -0.8 * jump)
					ar = Vector3(0.3, 0, 0.8 * jump)
				MatchSim.AER_BICYCLE:
					hip += jump * 0.8
					b_rx = lerpf(0.0, 2.6, minf(p * 1.6, 1.0))
					ll = Vector3(lerpf(0.2, 2.7, minf(p * 2.0, 1.0)), 0, 0)
					kl = Vector3(lerpf(-1.2, 0.0, minf(p * 2.0, 1.0)), 0, 0)
					lr = Vector3(1.2, 0, 0)
					kr = Vector3(-1.3, 0, 0)
					al = Vector3(0, 0, -1.3)
					ar = Vector3(0, 0, 1.3)
				_:
					hip += jump * 0.2
					b_rx = 0.45 * jump
					ll = Vector3(lerpf(-0.6, 1.7, minf(p * 2.5, 1.0)), 0, -0.3)
					kl = Vector3(lerpf(-1.4, -0.05, minf(p * 2.5, 1.0)), 0, 0)
					lr = Vector3(-0.1, 0, 0)
					kr = Vector3(-0.3, 0, 0)
					al = Vector3(0, 0, -1.1)
					ar = Vector3(0, 0, 1.1)
		C.ST_DIVE:
			var side := 1.0 if anim > 0 else -1.0
			var p2 := 1.0 - clampf(state_t / C.GK_DIVE_TIME, 0.0, 1.0)
			hip = 0.7 + sin(minf(p2 * 1.5, 1.0) * PI) * 0.35
			b_rz = side * lerpf(0.4, 1.4, minf(p2 * 2.0, 1.0))
			al = Vector3(0, 0, -2.9)
			ar = Vector3(0, 0, 2.9)
			fl = Vector3(0.1, 0, 0)
			fr = Vector3(0.1, 0, 0)
			ll = Vector3(0.2, 0, -0.2 * side)
			lr = Vector3(-0.1, 0, -0.2 * side)
			kl = Vector3(-0.4, 0, 0)
			kr = Vector3(-0.2, 0, 0)
		C.ST_KICK:
			var p3 := 1.0 - clampf(state_t / 0.22, 0.0, 1.0)
			lr = Vector3(lerpf(-0.8, 1.3, p3), 0, 0)
			kr = Vector3(lerpf(-1.5, -0.05, minf(p3 * 1.5, 1.0)), 0, 0)
			ll = Vector3(-0.1, 0, 0)
			kl = Vector3(-0.3, 0, 0)
			al = Vector3(0.4, 0, -0.5)
			ar = Vector3(-0.4, 0, 0.5)
			b_rx = 0.1
		C.ST_HOLD:
			al = Vector3(1.0, 0, -0.15)
			ar = Vector3(1.0, 0, 0.15)
			fl = Vector3(0.6, 0, 0)
			fr = Vector3(0.6, 0, 0)
		C.ST_CELEBRATE:
			var t := Time.get_ticks_msec() / 1000.0
			match anim:
				0:
					al = Vector3(0, 0, -2.9 + sin(t * 9.0) * 0.15)
					ar = Vector3(0, 0, 2.9 - sin(t * 9.0) * 0.15)
					fl = Vector3(0.2, 0, 0)
					fr = Vector3(0.2, 0, 0)
				1:
					al = Vector3(0, 0, -1.5)
					ar = Vector3(0, 0, 1.5)
					fl = Vector3(0.05, 0, 0)
					fr = Vector3(0.05, 0, 0)
					b_rz = sin(t * 3.0) * 0.3
				_:
					hip = 0.42
					b_rx = 0.35
					ll = Vector3(0.2, 0, 0)
					lr = Vector3(0.2, 0, 0)
					kl = Vector3(-1.9, 0, 0)
					kr = Vector3(-1.9, 0, 0)
					al = Vector3(0, 0, -2.6)
					ar = Vector3(0, 0, 2.6)
					head_rx = -0.4
	body.position.y = hip
	body.rotation = Vector3(b_rx, 0, b_rz)
	head.rotation.x = head_rx
	arm_l.rotation = al
	arm_r.rotation = ar
	fore_l.rotation = fl
	fore_r.rotation = fr
	leg_l.rotation = ll
	leg_r.rotation = lr
	shin_l.rotation = kl
	shin_r.rotation = kr
	ring.rotation.y += dt * 2.0
