class_name CharacterLib
extends RefCounted
## Loads the CC0 Quaternius character and animation libraries once and prepares
## the body mesh for kit colouring (per-vertex region mask from the bind pose).

const CHAR_PATH := "res://assets/third_party/quaternius/character/Superhero_Male_FullBody.gltf"
const ANIM_PATHS := ["res://assets/third_party/quaternius/anim/UAL1_Standard.glb", "res://assets/third_party/quaternius/anim/UAL2_Standard.glb"]
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
	return _library


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
