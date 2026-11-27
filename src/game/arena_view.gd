class_name ArenaView
extends Node3D
## Indoor arena: turf pitch (shader), LED boards and glass, goals with nets,
## concrete stands with a crowd, roof light banks, lighting and post-processing.

var crowd_mat: ShaderMaterial
var near_stand: Node3D        # stand between the side cameras and the pitch
var excitement := 0.0
var nets: Array = []
var _net_t := {}

const BOARD_H := 1.0
const GLASS_H := 1.6
const LINE_PX_PER_M := 20.0


func build(home: TeamData, away: TeamData) -> void:
	_pitch()
	_boards()
	_goal(1.0)
	_goal(-1.0)
	_stands(home, away)
	_roof()
	_lights()


func _process(dt: float) -> void:
	for n in nets:
		var id := (n as MeshInstance3D).get_instance_id()
		if _net_t.has(id):
			_net_t[id] += dt
			((n as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("hit_t", _net_t[id])
	excitement = maxf(0.0, excitement - dt * 0.35)
	if crowd_mat:
		crowd_mat.set_shader_parameter("excite", excitement)


func cheer(amount: float = 1.0) -> void:
	excitement = clampf(maxf(excitement, amount), 0.0, 1.0)


# ------------------------------------------------------------------ pitch

func _line_texture() -> ImageTexture:
	## White line markings on transparent, sampled by the turf shader.
	var w := int(C.HX * 2.0 * LINE_PX_PER_M)
	var h := int(C.HZ * 2.0 * LINE_PX_PER_M)
	var img := Image.create(w, h, false, Image.FORMAT_LA8)
	img.fill(Color(0, 0, 0, 0))
	var line := Color(1, 1, 1, 1)
	var lw := 2
	img.fill_rect(Rect2i(w / 2 - 1, 0, lw, h), line)
	_circle(img, Vector2(w / 2.0, h / 2.0), 3.0 * LINE_PX_PER_M, lw, line)
	_disc(img, Vector2(w / 2.0, h / 2.0), 3, line)
	for side in [0, 1]:
		var bw := int(C.BOX_DEPTH * LINE_PX_PER_M)
		var bx := 0 if side == 0 else w - bw
		var by := int((C.HZ - C.BOX_HW) * LINE_PX_PER_M)
		var bh := int(C.BOX_HW * 2.0 * LINE_PX_PER_M)
		_rect_outline(img, Rect2i(bx, by, bw, bh), lw, line)
		var sx := int((C.BOX_DEPTH - 1.8) * LINE_PX_PER_M)
		_disc(img, Vector2(sx if side == 0 else w - sx, h / 2.0), 3, line)
		var gx := 0 if side == 0 else w - lw
		img.fill_rect(Rect2i(gx, int((C.HZ - C.GOAL_HW) * LINE_PX_PER_M), lw, int(C.GOAL_HW * 2.0 * LINE_PX_PER_M)), line)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _pitch() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D lines : filter_linear_mipmap_anisotropic;
uniform vec3 grass_a : source_color = vec3(0.17, 0.33, 0.15);
uniform vec3 grass_b : source_color = vec3(0.15, 0.29, 0.13);
uniform vec2 size = vec2(40.0, 24.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 w = wpos.xz;
	float band = step(0.5, fract((w.x + size.x * 0.5) / 4.0));
	vec3 g = mix(grass_a, grass_b, band);
	float n = vnoise(w * 0.6) * 0.5 + vnoise(w * 3.1) * 0.3 + hash(floor(w * 60.0)) * 0.2;
	g *= 0.86 + n * 0.26;
	float wear = smoothstep(0.55, 0.0, length(w) / 6.0) * 0.07;
	g = mix(g, vec3(0.3, 0.33, 0.2), wear);
	vec2 uv = (w + size * 0.5) / size;
	float l = texture(lines, uv).a;
	ALBEDO = mix(g, vec3(0.86, 0.88, 0.84), l * 0.92);
	ROUGHNESS = mix(0.95, 0.8, l);
	SPECULAR = 0.2;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("lines", _line_texture())
	m.set_shader_parameter("size", Vector2(C.HX * 2.0, C.HZ * 2.0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(C.HX * 2.0 + C.GOAL_DEPTH * 2.0 + 0.4, C.HZ * 2.0 + 0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	add_child(mi)
	var floor_m := PlaneMesh.new()
	floor_m.size = Vector2(160, 120)
	var fm := MeshInstance3D.new()
	fm.mesh = floor_m
	fm.position.y = -0.02
	fm.material_override = Looks.mat(Color("202326"), 1.0)
	add_child(fm)


func _circle(img: Image, c: Vector2, r: float, lw: int, col: Color) -> void:
	var steps := int(r * 8.0)
	for i in steps:
		var a := TAU * i / steps
		var p := c + Vector2(cos(a), sin(a)) * r
		img.fill_rect(Rect2i(int(p.x) - lw / 2, int(p.y) - lw / 2, lw, lw), col)


func _disc(img: Image, c: Vector2, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var px := int(c.x) + x
				var py := int(c.y) + y
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, col)


func _rect_outline(img: Image, r: Rect2i, lw: int, col: Color) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, lw), col)
	img.fill_rect(Rect2i(r.position.x, r.end.y - lw, r.size.x, lw), col)
	img.fill_rect(Rect2i(r.position.x, r.position.y, lw, r.size.y), col)
	img.fill_rect(Rect2i(r.end.x - lw, r.position.y, lw, r.size.y), col)


# ------------------------------------------------------------------ boards

func _board(a: Vector2, b: Vector2, ad: String = "", ad_col: Color = Color.WHITE) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := d.length()
	var n := Vector2(-d.y, d.x).normalized()
	if n.dot(mid) < 0.0:
		n = -n
	var yaw := -atan2(d.y, d.x)
	var p := mid + n * 0.1
	# board body (dark) with a lighter kick plate
	_box_at(Vector3(len + 0.04, BOARD_H, 0.2), Vector3(p.x, BOARD_H * 0.5, p.y), yaw, Looks.mat(Color("15181d"), 0.6))
	_box_at(Vector3(len + 0.04, 0.18, 0.22), Vector3(p.x, 0.09, p.y), yaw, Looks.mat(Color("d4d4d4"), 0.7))
	_box_at(Vector3(len + 0.04, 0.06, 0.24), Vector3(p.x, BOARD_H, p.y), yaw, Looks.mat(Color("2b2f36"), 0.5))
	# glass with thin posts
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.8, 0.9, 1.0, 0.07)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05
	gm.metallic_specular = 0.9
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gi := _box_at(Vector3(len + 0.04, GLASS_H, 0.03), Vector3(p.x, BOARD_H + GLASS_H * 0.5, p.y), yaw, gm)
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# LED advert, glowing softly on the dark board
	if ad != "" and len > 4.0:
		var lbl := Label3D.new()
		lbl.text = ad
		lbl.font_size = 80
		lbl.pixel_size = 0.0055
		lbl.modulate = ad_col
		lbl.outline_size = 0
		lbl.shaded = false
		var inner := mid + n * -0.004
		lbl.position = Vector3(inner.x, BOARD_H * 0.58, inner.y)
		lbl.rotation.y = atan2(-n.x, -n.y)
		add_child(lbl)


func _box_at(size: Vector3, at: Vector3, yaw: float, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	mi.rotation.y = yaw
	add_child(mi)
	return mi


func _boards() -> void:
	var ads := ["OPENPITCHBOX", "NO THROW-INS", "SIX A SIDE", "FREE AS IN FOOTBALL"]
	var ad_cols := [Color("e5e7eb"), Color("fbbf24"), Color("7dd3fc"), Color("86efac")]
	var cx := C.HX - C.CORNER_R
	var cz := C.HZ - C.CORNER_R
	var segs := 4
	for side: float in [-1.0, 1.0]:
		for i in segs:
			var x0 := -cx + 2.0 * cx * i / segs
			var x1 := -cx + 2.0 * cx * (i + 1) / segs
			var k := (i + (0 if side > 0 else 2)) % 4
			_board(Vector2(x0, side * C.HZ), Vector2(x1, side * C.HZ), ads[k], ad_cols[k])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_board(Vector2(sx * C.HX, sz * C.GOAL_HW), Vector2(sx * C.HX, sz * cz))
		# wall above and around the goal
		_box_at(Vector3(0.2, BOARD_H + GLASS_H - C.GOAL_H, C.GOAL_HW * 2.0 + 0.2), Vector3(sx * (C.HX + C.GOAL_DEPTH + 0.1), C.GOAL_H + (BOARD_H + GLASS_H - C.GOAL_H) * 0.5, 0), 0.0, Looks.mat(Color("15181d"), 0.6))
		_box_at(Vector3(0.2, C.GOAL_H, C.GOAL_HW * 2.0 + 0.2), Vector3(sx * (C.HX + C.GOAL_DEPTH + 0.25), C.GOAL_H * 0.5, 0), 0.0, Looks.mat(Color("15181d"), 0.6))
	var steps := 6
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector2(sx * cx, sz * cz)
			for i in steps:
				var a0 := PI * 0.5 * i / steps
				var a1 := PI * 0.5 * (i + 1) / steps
				_board(c + Vector2(cos(a0) * sx, sin(a0) * sz) * C.CORNER_R, c + Vector2(cos(a1) * sx, sin(a1) * sz) * C.CORNER_R)


# ------------------------------------------------------------------ goals

func _goal(sx: float) -> void:
	var white := Looks.mat(Color("eeeeee"), 0.35)
	for pz: float in [-C.GOAL_HW, C.GOAL_HW]:
		var post := CylinderMesh.new()
		post.top_radius = C.POST_R
		post.bottom_radius = C.POST_R
		post.height = C.GOAL_H
		var pi := MeshInstance3D.new()
		pi.mesh = post
		pi.material_override = white
		pi.position = Vector3(sx * C.HX, C.GOAL_H * 0.5, pz)
		add_child(pi)
	var bar := CylinderMesh.new()
	bar.top_radius = C.POST_R
	bar.bottom_radius = C.POST_R
	bar.height = C.GOAL_HW * 2.0 + C.POST_R * 2.0
	var bi := MeshInstance3D.new()
	bi.mesh = bar
	bi.material_override = white
	bi.position = Vector3(sx * C.HX, C.GOAL_H, 0)
	bi.rotation.x = PI * 0.5
	add_child(bi)
	# net: short roof, then a sloping back down to a ground bar, side panels follow the profile
	var net := MeshInstance3D.new()
	net.mesh = _net_mesh(sx)
	net.material_override = _net_shader_material()
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	nets.append(net)
	# stanchions: roof bars, sloping back bars, ground bar
	var tube := Looks.mat(Color("d9d9d9"), 0.4)
	for pz: float in [-C.GOAL_HW, C.GOAL_HW]:
		_bar(Vector3(sx * C.HX, C.GOAL_H, pz), Vector3(sx * (C.HX + C.NET_TOP_DEPTH), C.GOAL_H - 0.05, pz), 0.025, tube)
		_bar(Vector3(sx * (C.HX + C.NET_TOP_DEPTH), C.GOAL_H - 0.05, pz), Vector3(sx * (C.HX + C.GOAL_DEPTH), 0.02, pz), 0.025, tube)
		_bar(Vector3(sx * C.HX, 0.02, pz), Vector3(sx * (C.HX + C.GOAL_DEPTH), 0.02, pz), 0.025, tube)
	_bar(Vector3(sx * (C.HX + C.GOAL_DEPTH), 0.02, -C.GOAL_HW), Vector3(sx * (C.HX + C.GOAL_DEPTH), 0.02, C.GOAL_HW), 0.03, tube)


func _bar(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	add_child(mi)
	var mid := (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	mi.transform = Transform3D(Basis(side, up, fwd), mid)


func _net_profile(t: float) -> Vector2:
	## Net profile from the crossbar (t=0) over the roof and down the back (t=1): (depth, height).
	var roof := C.NET_TOP_DEPTH
	var back := Vector2(C.GOAL_DEPTH - C.NET_TOP_DEPTH, C.GOAL_H).length()
	var total := roof + back
	var d := t * total
	if d <= roof:
		return Vector2(d, C.GOAL_H - sin(d / roof * PI) * 0.05)
	var k := (d - roof) / back
	var p := Vector2(roof, C.GOAL_H).lerp(Vector2(C.GOAL_DEPTH, 0.0), k)
	# slight outward belly, like a hanging net
	p.x += sin(k * PI) * 0.12
	return p


func _net_mesh(sx: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 24
	var nv := 16
	var mesh_size := 0.12   # metres per net cell
	var total := C.NET_TOP_DEPTH + Vector2(C.GOAL_DEPTH - C.NET_TOP_DEPTH, C.GOAL_H).length()
	# roof + back panel: u across the goal (z), v along the profile
	for j in nv:
		for i in nu:
			var quad: Array = []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var u := float(i + c[0]) / nu
				var v := float(j + c[1]) / nv
				var pr := _net_profile(v)
				var z := lerpf(-C.GOAL_HW, C.GOAL_HW, u)
				var sag := sin(u * PI) * 0.06 * sin(v * PI)
				quad.append([Vector3(sx * (C.HX + pr.x + sag), pr.y - sag * 0.5, z), Vector2(z / mesh_size, v * total / mesh_size), v])
			_quad_tris(st, quad)
	# side panels: polygon under the profile, filled down to the ground
	for pz: float in [-C.GOAL_HW, C.GOAL_HW]:
		for j in nv:
			for i in 8:
				var quad2: Array = []
				for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
					var v2 := float(j + c[0]) / nv
					var h := float(i + c[1]) / 8.0
					var pr2 := _net_profile(v2)
					var y := pr2.y * h
					var x := sx * (C.HX + pr2.x)
					quad2.append([Vector3(x, y, pz), Vector2((x * sx) / mesh_size, y / mesh_size), 0.5])
				_quad_tris(st, quad2)
	st.generate_normals()
	return st.commit()


func _quad_tris(st: SurfaceTool, q: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_uv(q[idx][1])
		st.set_uv2(Vector2(q[idx][2], 0))
		st.add_vertex(q[idx][0])


static var _net_shader: Shader


func _net_shader_material() -> ShaderMaterial:
	if _net_shader == null:
		_net_shader = Shader.new()
		_net_shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec3 hit_pos = vec3(0.0, -10.0, 0.0);
uniform float hit_t = 10.0;
uniform float hit_amp = 0.0;
varying vec3 wpos;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(w, hit_pos);
	float wave = exp(-d * d * 1.6) * sin(hit_t * 22.0 - d * 6.0) * exp(-hit_t * 3.5) * hit_amp;
	// bulge outward (away from the pitch) where the ball hit
	VERTEX.x += sign(w.x) * (wave * 0.25 + exp(-d * d * 2.5) * exp(-hit_t * 5.0) * hit_amp * 0.35);
	wpos = w;
}
void fragment() {
	vec2 g = abs(fract(UV) - 0.5);
	float line = step(0.40, max(g.x, g.y));
	if (line < 0.5) { discard; }
	ALBEDO = vec3(0.88);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _net_shader
	return m


func net_hit(pos: Vector3, strength: float) -> void:
	for n in nets:
		var mi := n as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		if signf(pos.x) == signf(mi.get_aabb().get_center().x):
			mat.set_shader_parameter("hit_pos", pos)
			mat.set_shader_parameter("hit_amp", strength)
			_net_t[mi.get_instance_id()] = 0.0


func _net_material() -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in 32:
		img.set_pixel(i, 0, Color(1, 1, 1, 0.9))
		img.set_pixel(0, i, Color(1, 1, 1, 0.9))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(0.85, 0.85, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(14, 14, 1)
	return m


func _quad(at: Vector3, size: Vector2, rot: Vector3, m: Material) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ stands

func _fan_mesh() -> ArrayMesh:
	## A seated spectator: torso (instance colour) + head (skin), merged into one mesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torso := CapsuleMesh.new()
	torso.radius = 0.17
	torso.height = 0.62
	torso.radial_segments = 8
	torso.rings = 2
	st.append_from(torso, 0, Transform3D(Basis().scaled(Vector3(1, 1, 0.75)), Vector3(0, 0, 0)))
	var tmesh := st.commit()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var headm := SphereMesh.new()
	headm.radius = 0.11
	headm.height = 0.24
	headm.radial_segments = 8
	headm.rings = 4
	st2.append_from(headm, 0, Transform3D(Basis(), Vector3(0, 0.42, 0)))
	st2.commit(tmesh)
	return tmesh


func _stands(home: TeamData, away: TeamData) -> void:
	near_stand = Node3D.new()
	add_child(near_stand)
	var concrete := Looks.mat(Color("4a4d52"), 0.95)
	var seats := Looks.mat(Color("1e2a3a"), 0.8)
	var rows := 9
	var far_pos: Array = []
	var far_col: Array = []
	var near_pos: Array = []
	var near_col: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cloth := [Color("2b2b2b"), Color("3d3d46"), Color("5b6573"), Color("7a5c48"), Color("cfcfcf"), Color("2f4a6b"), Color("6b2f2f"), Color("44553c")]
	for side: float in [-1.0, 1.0]:
		var parent: Node3D = near_stand if side > 0.0 else self
		for r in rows:
			var z := side * (C.HZ + 1.6 + r * 0.85)
			var y := 0.5 + r * 0.5
			var step := BoxMesh.new()
			step.size = Vector3(C.HX * 2.0 + 8.0, y, 0.85)
			var si := MeshInstance3D.new()
			si.mesh = step
			si.material_override = concrete if r % 2 == 0 else seats
			si.position = Vector3(0, y * 0.5, z)
			parent.add_child(si)
			var x := -C.HX - 3.5
			while x < C.HX + 3.5:
				if rng.randf() < 0.8:
					var home_end := (x < 0.0)
					var col: Color
					if rng.randf() < 0.25:
						col = (home.color1 if home_end else away.color1).lerp(Color(0.3, 0.3, 0.3), 0.35)
					else:
						col = cloth[rng.randi() % cloth.size()]
					var pos := Vector3(x + rng.randf_range(-0.08, 0.08), y + 0.33, z)
					if side > 0.0:
						near_pos.append(pos)
						near_col.append(col)
					else:
						far_pos.append(pos)
						far_col.append(col)
				x += 0.52
	for sx: float in [-1.0, 1.0]:
		for r in rows - 3:
			var xx := sx * (C.HX + C.GOAL_DEPTH + 1.2 + r * 0.85)
			var y2 := 1.0 + r * 0.55
			var step2 := BoxMesh.new()
			step2.size = Vector3(0.85, y2, C.HZ * 2.0 + 2.0)
			var si2 := MeshInstance3D.new()
			si2.mesh = step2
			si2.material_override = concrete if r % 2 == 0 else seats
			si2.position = Vector3(xx, y2 * 0.5, 0)
			add_child(si2)
			var zz := -C.HZ
			while zz < C.HZ:
				if rng.randf() < 0.75:
					var col2: Color = (home.color1 if sx < 0 else away.color1).lerp(Color(0.3, 0.3, 0.3), 0.3) if rng.randf() < 0.55 else cloth[rng.randi() % cloth.size()]
					far_pos.append(Vector3(xx, y2 + 0.33, zz + rng.randf_range(-0.08, 0.08)))
					far_col.append(col2)
				zz += 0.52
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform float excite = 0.0;
varying vec3 col;
varying float is_head;
void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float sp = INSTANCE_CUSTOM.y;
	float idle = max(0.0, sin(TIME * 1.6 * sp + ph)) * 0.02;
	float jump = max(0.0, sin(TIME * 8.0 * sp + ph)) * 0.3 * excite;
	VERTEX.y += idle + jump;
	col = COLOR.rgb;
	is_head = step(0.3, VERTEX.y - idle - jump);
}
void fragment() {
	vec3 skin = vec3(0.62, 0.46, 0.36);
	ALBEDO = mix(col, skin, is_head);
	ROUGHNESS = 0.9;
}
"""
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = sh
	var fan := _fan_mesh()
	add_child(_crowd_mesh(fan, far_pos, far_col, rng))
	near_stand.add_child(_crowd_mesh(fan, near_pos, near_col, rng))


func _crowd_mesh(fan: Mesh, positions: Array, colors: Array, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = fan
	mm.instance_count = positions.size()
	for i in positions.size():
		var p: Vector3 = positions[i]
		var yaw := atan2(-p.x, -p.z) + PI   # face the pitch centre
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), p))
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, Color(rng.randf() * TAU, rng.randf_range(0.6, 1.4), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = crowd_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _roof() -> void:
	## Light banks above the long sides (emissive, picked up by glow).
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1, 1, 1)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.97, 0.9)
	em.emission_energy_multiplier = 3.0
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var x := -C.HX + 4.0 + i * (C.HX * 2.0 - 8.0) / 5.0
			var b := _box_at(Vector3(2.6, 0.25, 0.9), Vector3(x, 16.0, side * (C.HZ + 4.0)), 0.0, em)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-62), deg_to_rad(22), 0)
	key.light_energy = 0.85
	key.light_color = Color(1.0, 0.97, 0.92)
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 80.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-55), deg_to_rad(202), 0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.85, 0.9, 1.0)
	add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07090c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("aab4c0")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
