class_name ArenaView
extends Node3D
## Indoor arena: pitch, boards, glass, goals with nets, stands with a crowd, lights.

var crowd_mat: ShaderMaterial
var near_stand: Node3D        # stand between the side cameras and the pitch
var excitement := 0.0

const BOARD_H := 1.1
const GLASS_H := 1.6
const PX_PER_M := 24.0


func build(home: TeamData, away: TeamData) -> void:
	_pitch()
	_boards()
	_goal(1.0)
	_goal(-1.0)
	_stands(home, away)
	_lights()


func _process(dt: float) -> void:
	excitement = maxf(0.0, excitement - dt * 0.35)
	if crowd_mat:
		crowd_mat.set_shader_parameter("excite", excitement)


func cheer(amount: float = 1.0) -> void:
	excitement = clampf(maxf(excitement, amount), 0.0, 1.0)


# ------------------------------------------------------------------ pitch

func _pitch() -> void:
	var w := int((C.HX * 2.0 + 0.0) * PX_PER_M)
	var h := int((C.HZ * 2.0) * PX_PER_M)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var g1 := Color("226b33")
	var g2 := Color("1c5c2b")
	var bands := 10
	for i in bands:
		var x0 := int(float(i) * w / bands)
		var x1 := int(float(i + 1) * w / bands)
		img.fill_rect(Rect2i(x0, 0, x1 - x0, h), g1 if i % 2 == 0 else g2)
	var line := Color(0.95, 0.97, 0.95)
	var lw := 3
	# halfway line
	img.fill_rect(Rect2i(w / 2 - lw / 2, 0, lw, h), line)
	# center circle & spot
	_circle(img, Vector2(w / 2.0, h / 2.0), 3.0 * PX_PER_M, lw, line)
	_disc(img, Vector2(w / 2.0, h / 2.0), 5, line)
	# penalty boxes
	for side: float in [0, 1]:
		var bx := 0 if side == 0 else w - int(C.BOX_DEPTH * PX_PER_M)
		var by := int((C.HZ - C.BOX_HW) * PX_PER_M)
		var bw := int(C.BOX_DEPTH * PX_PER_M)
		var bh := int(C.BOX_HW * 2.0 * PX_PER_M)
		_rect_outline(img, Rect2i(bx, by, bw, bh), lw, line)
		var sx := int((C.BOX_DEPTH - 1.8) * PX_PER_M) if side == 0 else w - int((C.BOX_DEPTH - 1.8) * PX_PER_M)
		_disc(img, Vector2(sx, h / 2.0), 4, line)
		# goal line inside the mouth
		var gx := 0 if side == 0 else w - lw
		img.fill_rect(Rect2i(gx, int((C.HZ - C.GOAL_HW) * PX_PER_M), lw, int(C.GOAL_HW * 2.0 * PX_PER_M)), line)
	# subtle boundary inset
	_rect_outline(img, Rect2i(int(0.4 * PX_PER_M), int(0.4 * PX_PER_M), w - int(0.8 * PX_PER_M), h - int(0.8 * PX_PER_M)), 2, Color(1, 1, 1, 0.35).blend(g1))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var pm := PlaneMesh.new()
	pm.size = Vector2(C.HX * 2.0, C.HZ * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	add_child(mi)
	# dark floor around everything
	var floor_m := PlaneMesh.new()
	floor_m.size = Vector2(140, 110)
	var fm := MeshInstance3D.new()
	fm.mesh = floor_m
	fm.position.y = -0.02
	fm.material_override = Looks.mat(Color("1e293b"), 1.0)
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

func _board(a: Vector2, b: Vector2, col: Color, ad: String = "") -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := d.length()
	var bm := BoxMesh.new()
	bm.size = Vector3(len + 0.05, BOARD_H, 0.18)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = Looks.mat(col, 0.5)
	# the board sits just outside the inner face
	var n := Vector2(-d.y, d.x).normalized()
	if n.dot(mid) < 0.0:
		n = -n
	var p := mid + n * 0.09
	mi.position = Vector3(p.x, BOARD_H * 0.5, p.y)
	mi.rotation.y = -atan2(d.y, d.x)
	add_child(mi)
	# yellow top rail
	var rail := BoxMesh.new()
	rail.size = Vector3(len + 0.05, 0.08, 0.22)
	var ri := MeshInstance3D.new()
	ri.mesh = rail
	ri.material_override = Looks.mat(Color("fbbf24"), 0.4)
	ri.position = Vector3(p.x, BOARD_H, p.y)
	ri.rotation.y = mi.rotation.y
	add_child(ri)
	# glass above the board
	var gm := BoxMesh.new()
	gm.size = Vector3(len + 0.05, GLASS_H, 0.04)
	var gi := MeshInstance3D.new()
	gi.mesh = gm
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.9, 1.0, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	gi.material_override = glass
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi.position = Vector3(p.x, BOARD_H + GLASS_H * 0.5, p.y)
	gi.rotation.y = mi.rotation.y
	add_child(gi)
	if ad != "" and len > 4.0:
		var lbl := Label3D.new()
		lbl.text = ad
		lbl.font_size = 96
		lbl.pixel_size = 0.006
		lbl.modulate = Color.WHITE
		lbl.outline_size = 0
		var inner := mid + n * -0.005
		lbl.position = Vector3(inner.x, BOARD_H * 0.5, inner.y)
		# face the pitch
		lbl.rotation.y = atan2(-n.x, -n.y)
		add_child(lbl)


func _boards() -> void:
	var cols := [Color("1d4ed8"), Color("b91c1c"), Color("0f766e"), Color("7c3aed")]
	var ads := ["OPENPITCHBOX", "NO THROW-INS", "SIX A SIDE", "FREE AS IN FOOTBALL"]
	var cx := C.HX - C.CORNER_R
	var cz := C.HZ - C.CORNER_R
	# long sides, split into segments for ads
	var segs := 4
	for side: float in [-1.0, 1.0]:
		for i in segs:
			var x0 := -cx + 2.0 * cx * i / segs
			var x1 := -cx + 2.0 * cx * (i + 1) / segs
			_board(Vector2(x0, side * C.HZ), Vector2(x1, side * C.HZ), cols[(i + (0 if side > 0 else 2)) % 4], ads[(i + (1 if side > 0 else 3)) % 4])
	# ends, both sides of the goal
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_board(Vector2(sx * C.HX, sz * C.GOAL_HW), Vector2(sx * C.HX, sz * cz), cols[1 if sz > 0 else 3])
		# header board above the goal
		var hb := BoxMesh.new()
		hb.size = Vector3(0.18, BOARD_H + GLASS_H - C.GOAL_H, C.GOAL_HW * 2.0 + 0.2)
		var hi := MeshInstance3D.new()
		hi.mesh = hb
		hi.material_override = Looks.mat(Color("0f172a"), 0.6)
		hi.position = Vector3(sx * (C.HX + C.GOAL_DEPTH + 0.1), C.GOAL_H + hb.size.y * 0.5, 0)
		add_child(hi)
	# rounded corners
	var steps := 6
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector2(sx * cx, sz * cz)
			for i in steps:
				var a0 := PI * 0.5 * i / steps
				var a1 := PI * 0.5 * (i + 1) / steps
				var p0 := c + Vector2(cos(a0) * sx, sin(a0) * sz) * C.CORNER_R
				var p1 := c + Vector2(cos(a1) * sx, sin(a1) * sz) * C.CORNER_R
				_board(p0, p1, Color("e2e8f0"))


# ------------------------------------------------------------------ goals

func _goal(sx: float) -> void:
	var white := Looks.mat(Color("f8fafc"), 0.3)
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
	# nets
	var net := _net_material()
	var back_x := sx * (C.HX + C.GOAL_DEPTH)
	_quad(Vector3(back_x, C.GOAL_H * 0.5, 0), Vector2(C.GOAL_HW * 2.0, C.GOAL_H), Vector3(0, PI * 0.5, 0), net)
	for sz: float in [-1.0, 1.0]:
		_quad(Vector3(sx * (C.HX + C.GOAL_DEPTH * 0.5), C.GOAL_H * 0.5, sz * C.GOAL_HW), Vector2(C.GOAL_DEPTH, C.GOAL_H), Vector3.ZERO, net)
	_quad(Vector3(sx * (C.HX + C.GOAL_DEPTH * 0.5), C.GOAL_H, 0), Vector2(C.GOAL_DEPTH, C.GOAL_HW * 2.0), Vector3(PI * 0.5, 0, 0), net)
	# goal floor
	var gf := PlaneMesh.new()
	gf.size = Vector2(C.GOAL_DEPTH, C.GOAL_HW * 2.0)
	var gi := MeshInstance3D.new()
	gi.mesh = gf
	gi.material_override = Looks.mat(Color("246b35"), 1.0)
	gi.position = Vector3(sx * (C.HX + C.GOAL_DEPTH * 0.5), 0.005, 0)
	add_child(gi)


func _net_material() -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in 32:
		img.set_pixel(i, 0, Color(1, 1, 1, 0.85))
		img.set_pixel(0, i, Color(1, 1, 1, 0.85))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(12, 12, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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

func _stands(home: TeamData, away: TeamData) -> void:
	var tier_m := Looks.mat(Color("334155"), 0.9)
	var rows := 7
	near_stand = Node3D.new()
	add_child(near_stand)
	var positions: Array = []
	var colors: Array = []
	var near_positions: Array = []
	var near_colors: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var palette := [home.color1, home.color2, away.color1, away.color2, Color("e5e7eb"), Color("374151"), Color("f59e0b"), Color("60a5fa")]
	# long sides
	for side: float in [-1.0, 1.0]:
		for r in rows:
			var z := side * (C.HZ + 1.2 + r * 0.9)
			var y := 0.4 + r * 0.55
			var step := BoxMesh.new()
			step.size = Vector3(C.HX * 2.0 + 6.0, y, 0.9)
			var si := MeshInstance3D.new()
			si.mesh = step
			si.material_override = tier_m
			si.position = Vector3(0, y * 0.5, z)
			if side > 0.0:
				near_stand.add_child(si)
			else:
				add_child(si)
			var x := -C.HX - 2.5
			while x < C.HX + 2.5:
				if rng.randf() < 0.85:
					var home_side := (x < 0.0) == (side > 0.0)
					var pal: Color = palette[rng.randi() % 2 + (0 if home_side else 2)] if rng.randf() < 0.6 else palette[4 + rng.randi() % 4]
					if side > 0.0:
						near_positions.append(Vector3(x + rng.randf_range(-0.1, 0.1), y + 0.32, z))
						near_colors.append(pal)
					else:
						positions.append(Vector3(x + rng.randf_range(-0.1, 0.1), y + 0.32, z))
						colors.append(pal)
				x += 0.55
	# ends (behind the goals)
	for sx: float in [-1.0, 1.0]:
		for r in rows - 2:
			var xx := sx * (C.HX + C.GOAL_DEPTH + 1.0 + r * 0.9)
			var y2 := 0.8 + r * 0.6
			var step2 := BoxMesh.new()
			step2.size = Vector3(0.9, y2, C.HZ * 2.0 + 2.0)
			var si2 := MeshInstance3D.new()
			si2.mesh = step2
			si2.material_override = tier_m
			si2.position = Vector3(xx, y2 * 0.5, 0)
			add_child(si2)
			var zz := -C.HZ
			while zz < C.HZ:
				if rng.randf() < 0.8:
					positions.append(Vector3(xx, y2 + 0.32, zz + rng.randf_range(-0.1, 0.1)))
					var pal2: Color = palette[(0 if sx < 0 else 2) + rng.randi() % 2] if rng.randf() < 0.7 else palette[4 + rng.randi() % 4]
					colors.append(pal2)
				zz += 0.55
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back;
uniform float excite = 0.0;
varying vec3 col;
void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float sp = INSTANCE_CUSTOM.y;
	float idle = max(0.0, sin(TIME * 2.0 * sp + ph)) * 0.04;
	float jump = max(0.0, sin(TIME * 9.0 * sp + ph)) * 0.35 * excite;
	VERTEX.y += idle + jump;
	col = COLOR.rgb;
}
void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
"""
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = sh
	add_child(_crowd_mesh(positions, colors, rng))
	near_stand.add_child(_crowd_mesh(near_positions, near_colors, rng))


func _crowd_mesh(positions: Array, colors: Array, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var fan := BoxMesh.new()
	fan.size = Vector3(0.34, 0.62, 0.3)
	mm.mesh = fan
	mm.instance_count = positions.size()
	for i in positions.size():
		mm.set_instance_transform(i, Transform3D(Basis(), positions[i]))
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, Color(rng.randf() * TAU, rng.randf_range(0.6, 1.4), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = crowd_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-40), deg_to_rad(200), 0)
	fill.light_energy = 0.35
	add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1220")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9fb3c8")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
