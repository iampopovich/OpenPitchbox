class_name CharacterLib
extends RefCounted
## Loads the CC0 Quaternius character and animation libraries once and prepares
## the body mesh for kit colouring (per-vertex region mask from the bind pose).

const CHAR_PATH := "res://assets/third_party/quaternius/character/Superhero_Male_FullBody.gltf"
const ANIM_PATHS := ["res://assets/third_party/quaternius/anim/UAL1_Standard.glb", "res://assets/third_party/quaternius/anim/UAL2_Standard.glb"]
const CMU_PATH := "res://assets/third_party/cmu/cmu_football.glb"

# Motion-capture segments cut from CMU clips: name -> [source, start s, end s, loop, facing reference time]
# (the actor's facing at the reference time becomes +Z; default = start)
# (source times were measured with tools/blender/analyze_cmu.py; "contact" notes the ball strike)
const CMU_CLIPS := {
	"Kick_Shot": ["10_03", 0.92, 1.75, false],        # contact 1.17
	"Kick_Shot2": ["11_01", 3.17, 3.95, false],       # contact 3.42
	"Kick_Pass": ["10_02", 2.70, 3.40, false],        # contact 2.92
	"Kick_Volley": ["10_06", 3.20, 3.95, false],      # contact 3.42
	"Header_Jump": ["105_43", 0.62, 1.55, false],     # peak 1.0
	"Header_RunJump": ["127_21", 0.35, 1.30, false],  # peak 0.75
	"GK_Catch": ["143_20", 0.45, 1.25, false],        # hands up at 0.75
	"GK_Scoop": ["143_22", 2.05, 2.95, false],        # low pick-up at 2.5
	"GK_Throw": ["143_20", 2.90, 3.90, false],        # release about 3.25
	"Stumble": ["22_12", 0.0, 1.10, false],
	"GetUp": ["140_08", 3.10, 5.60, false, 5.60, -1.4],
	"Celebrate_Hop": ["83_61", 1.30, 3.00, false],
	"Celebrate_JumpTurn": ["105_46", 1.20, 2.30, false],
}
const HAIR_PATHS := {
	"parted": "res://assets/third_party/quaternius/character/Hair_SimpleParted.gltf",
	"buzzed": "res://assets/third_party/quaternius/character/Hair_Buzzed.gltf",
	"long": "res://assets/third_party/quaternius/character/Hair_Long.gltf",
	"beard": "res://assets/third_party/quaternius/character/Hair_Beard.gltf",
}

# Kit regions stored in vertex colour red channel (region / 8)
enum { R_SKIN, R_SHIRT, R_SHORTS, R_SOCKS, R_BOOTS, R_GLOVES }

static var _scene: PackedScene
static var _library: AnimationLibrary
static var _body_mesh: ArrayMesh
static var _body_shader: Shader
static var _hair := {}
static var _albedo: Texture2D
static var _normal: Texture2D
static var _rough: Texture2D


static func scene() -> PackedScene:
	if _scene == null:
		_scene = load(CHAR_PATH)
	return _scene


static func library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	for path in ANIM_PATHS:
		var ps: PackedScene = load(path)
		var inst := ps.instantiate()
		var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
		if ap:
			for name in ap.get_animation_list():
				if _library.has_animation(name):
					continue
				var a := ap.get_animation(name).duplicate() as Animation
				# locomotion and poses loop; one-shots do not
				var loops := ["Idle", "Jog_Fwd", "Sprint", "Walk", "Slide", "Dance", "Yes", "Idle_FoldArms", "Jump", "Swim_Fwd"]
				a.loop_mode = Animation.LOOP_LINEAR if loops.has(name) else Animation.LOOP_NONE
				_library.add_animation(name, a)
		inst.free()
	_add_cmu_clips()
	return _library


static func _add_cmu_clips() -> void:
	var ps: PackedScene = load(CMU_PATH)
	if ps == null:
		return
	var inst := ps.instantiate()
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	var sk := _find(inst, "Skeleton3D") as Skeleton3D
	if sk:
		_cmu_root = sk.get_bone_rest(sk.find_bone("root")).basis.get_rotation_quaternion()
	var by_src := {}
	if ap:
		for name in ap.get_animation_list():
			# actions are named "cmu_<id>"; the first one may keep its file name "<id>-..."
			var id: String = name.trim_prefix("cmu_").get_slice("-", 0)
			by_src[id] = ap.get_animation(name)
	for clip in CMU_CLIPS:
		var d: Array = CMU_CLIPS[clip]
		if by_src.has(d[0]):
			_library.add_animation(clip, _cut(by_src[d[0]], d[1], d[2], d[3], d[4] if d.size() > 4 else d[1], d[5] if d.size() > 5 else 0.0))
	inst.free()


static func _yaw_of(q: Quaternion) -> float:
	var f := Basis(q) * Vector3.BACK
	return atan2(f.x, f.z)


static var _ref_yaw := INF
static var _cmu_root := Quaternion.IDENTITY   # rest rotation of the parent of "pelvis" in the CMU rig


static func _reference_yaw() -> float:
	## Pelvis yaw of the Quaternius idle on the same skeleton = "facing +Z" for our model.
	if _ref_yaw == INF:
		_ref_yaw = 0.0
		var idle: Animation = _library.get_animation("Idle") if _library.has_animation("Idle") else null
		if idle:
			for t in idle.get_track_count():
				if idle.track_get_type(t) == Animation.TYPE_ROTATION_3D and str(idle.track_get_path(t)).ends_with(":pelvis"):
					var our_root := Quaternion.IDENTITY
					var inst := (load(CHAR_PATH) as PackedScene).instantiate()
					var sk := _find(inst, "Skeleton3D") as Skeleton3D
					if sk and sk.find_bone("root") >= 0:
						our_root = sk.get_bone_rest(sk.find_bone("root")).basis.get_rotation_quaternion()
					inst.free()
					_ref_yaw = _yaw_of(our_root * idle.rotation_track_interpolate(t, 0.0))
	return _ref_yaw


static func _cut(src: Animation, t0: float, t1: float, loop: bool, t_face: float, extra_yaw: float = 0.0) -> Animation:
	## Copies [t0, t1] of src into a new clip starting at 0. The CMU actor's facing lives in
	## the pelvis rotation: it is turned so that at t_face he faces like our idle pose. Ground
	## travel is removed (the match engine moves the player); height is kept.
	var a := Animation.new()
	a.length = t1 - t0
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var unyaw := Quaternion.IDENTITY
	var pelvis_origin := Vector3.ZERO
	for t in src.get_track_count():
		var ps := str(src.track_get_path(t))
		if ps.ends_with(":pelvis") and src.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var up_local := _cmu_root.inverse() * Vector3.UP
			unyaw = Quaternion(up_local, _reference_yaw() - _yaw_of(_cmu_root * src.rotation_track_interpolate(t, t_face)) + extra_yaw)
		if ps.ends_with(":pelvis") and src.track_get_type(t) == Animation.TYPE_POSITION_3D:
			pelvis_origin = src.position_track_interpolate(t, t_face)
	for t in src.get_track_count():
		var path := src.track_get_path(t)
		var type := src.track_get_type(t)
		var nt := a.add_track(type)
		a.track_set_path(nt, path)
		a.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
		var bone := str(path).get_slice(":", 1)
		for k in src.track_get_key_count(t):
			var kt := src.track_get_key_time(t, k)
			if kt < t0 - 0.0001 or kt > t1 + 0.0001:
				continue
			var v = src.track_get_key_value(t, k)
			if bone == "root" and type == Animation.TYPE_POSITION_3D:
				v = Vector3(0.0, (v as Vector3).y, 0.0)
			elif bone == "pelvis" and type == Animation.TYPE_POSITION_3D:
				# split into height (along world up, expressed in the parent frame) and ground drift
				var up_l := _cmu_root.inverse() * Vector3.UP
				var rel: Vector3 = (v as Vector3) - pelvis_origin
				var h := rel.dot(up_l)
				var drift: Vector3 = unyaw * (rel - up_l * h)
				v = pelvis_origin.project(up_l) + (pelvis_origin - pelvis_origin.project(up_l)) + up_l * h + drift * 0.3
			elif bone == "pelvis" and type == Animation.TYPE_ROTATION_3D:
				v = (unyaw * (v as Quaternion)).normalized()
			a.track_insert_key(nt, kt - t0, v)
	return a

static func hair_scene(key: String) -> PackedScene:
	if not _hair.has(key):
		_hair[key] = load(HAIR_PATHS[key])
	return _hair[key]


static func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


static func region_of(v: Vector3) -> int:
	## Bind pose (T-pose, metres, y up, arms along x).
	var ax := absf(v.x)
	if v.y < 0.085:
		return R_BOOTS
	if v.y < 0.46:
		return R_SOCKS
	if v.y < 0.66:
		return R_SKIN
	if v.y < 0.98 and ax < 0.3:
		return R_SHORTS
	if v.y < 1.5 and ax < 0.47:
		return R_SHIRT
	if ax > 0.72 and v.y > 1.2 and v.y < 1.6:
		return R_GLOVES
	return R_SKIN


static func body_mesh(src: ArrayMesh) -> ArrayMesh:
	if _body_mesh:
		return _body_mesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			cols[i] = Color(float(region_of(verts[i])) / 8.0, 0, 0, 1)
		arr[Mesh.ARRAY_COLOR] = cols
		# bind-pose height and lateral distance, so the shader can cut kit edges per pixel
		var uv2 := PackedVector2Array()
		uv2.resize(verts.size())
		for i in verts.size():
			uv2[i] = Vector2(verts[i].y, absf(verts[i].x))
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		var m := src.surface_get_material(s)
		if m is BaseMaterial3D:
			_albedo = (m as BaseMaterial3D).albedo_texture
			_normal = (m as BaseMaterial3D).normal_texture
			_rough = (m as BaseMaterial3D).roughness_texture
	_body_mesh = out
	return out


static func body_material(shirt: Color, shorts: Color, socks: Color, skin: Color, gloves: bool) -> ShaderMaterial:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap;
uniform vec3 skin_tone : source_color = vec3(0.8, 0.62, 0.5);
uniform vec3 shirt : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 shorts : source_color = vec3(1.0);
uniform vec3 socks : source_color = vec3(0.8, 0.1, 0.1);
uniform float gloves = 0.0;
varying vec2 bind;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { bind = UV2; }
int region_of(float y, float ax) {
	if (y < 0.085) return 4;
	if (y < 0.46) return 3;
	if (y < 0.66) return 0;
	if (y < 0.98 && ax < 0.3) return 2;
	if (y < 1.5 && ax < 0.47) return 1;
	if (ax > 0.72 && y > 1.2 && y < 1.6) return 5;
	return 0;
}
void fragment() {
	int region = region_of(bind.x, bind.y);
	vec3 tex = texture(albedo_tex, UV).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float shade = clamp(lum / 0.28, 0.6, 1.35);
	vec3 c = skin_tone * shade;
	float rough = texture(rough_tex, UV).r;
	vec3 nm = texture(normal_tex, UV).rgb;
	float weave = 0.94 + 0.06 * hash(floor(UV * 900.0));
	if (region == 1) { c = shirt * weave; rough = 0.82; nm = mix(nm, vec3(0.5, 0.5, 1.0), 0.6); }
	else if (region == 2) { c = shorts * weave; rough = 0.8; nm = mix(nm, vec3(0.5, 0.5, 1.0), 0.6); }
	else if (region == 3) { c = socks * weave; rough = 0.85; nm = mix(nm, vec3(0.5, 0.5, 1.0), 0.7); }
	else if (region == 4) { c = vec3(0.04); rough = 0.35; nm = vec3(0.5, 0.5, 1.0); }
	else if (region == 5 && gloves > 0.5) { c = vec3(0.92); rough = 0.7; }
	ALBEDO = c;
	ROUGHNESS = rough;
	NORMAL_MAP = nm;
	SPECULAR = 0.35;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _body_shader
	m.set_shader_parameter("albedo_tex", _albedo)
	m.set_shader_parameter("normal_tex", _normal)
	m.set_shader_parameter("rough_tex", _rough)
	m.set_shader_parameter("skin_tone", skin)
	m.set_shader_parameter("shirt", shirt)
	m.set_shader_parameter("shorts", shorts)
	m.set_shader_parameter("socks", socks)
	m.set_shader_parameter("gloves", 1.0 if gloves else 0.0)
	return m
