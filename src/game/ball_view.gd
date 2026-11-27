class_name BallView
extends Node3D
## The ball mesh (procedural panel texture) and a soft shadow blob that helps read its height.

var mesh: MeshInstance3D
var blob: MeshInstance3D
var _axis := Vector3.RIGHT


func build() -> void:
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = C.BALL_R
	sm.height = C.BALL_R * 2.0
	sm.radial_segments = 20
	sm.rings = 10
	mesh.mesh = sm
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color("f8fafc"))
	var spots := [Vector2(8, 8), Vector2(24, 16), Vector2(40, 8), Vector2(56, 16), Vector2(16, 26), Vector2(48, 26), Vector2(32, 4)]
	for s in spots:
		for y in range(-4, 5):
			for x in range(-4, 5):
				if x * x + y * y <= 14:
					img.set_pixel(clampi(int(s.x) + x, 0, 63), clampi(int(s.y) + y, 0, 31), Color("111827"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.4
	mesh.material_override = m
	add_child(mesh)
	blob = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	var bimg := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			bimg.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0) * 0.55))
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = ImageTexture.create_from_image(bimg)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob.material_override = bm
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func show_at(p: Vector3, vel: Vector3, dt: float) -> void:
	mesh.position = p
	var h := Vector3(vel.x, 0, vel.z)
	var sp := h.length()
	if sp > 0.05:
		_axis = Vector3.UP.cross(h / sp)
		mesh.rotate(_axis.normalized(), -sp * dt / C.BALL_R)
	blob.position = Vector3(p.x, 0.012, p.z)
	var s := clampf(1.0 - (p.y - C.BALL_R) / 6.0, 0.35, 1.0)
	blob.scale = Vector3(s, 1, s)
