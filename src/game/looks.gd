class_name Looks
extends RefCounted
## Palettes and shared materials for the procedural characters.

const SKIN := [Color("f1c7a5"), Color("e0ac7e"), Color("c68642"), Color("a0662f"), Color("7a4a24"), Color("4a2c17")]
const HAIR_COLOR := [Color("1b1b1b"), Color("4a2c17"), Color("8d5524"), Color("d6b370"), Color("b33a1f"), Color("9ca3af")]
const HAIR_NAMES := ["Short", "Bald", "Afro", "Mohawk", "Long", "Spiky"]
const BEARD_NAMES := ["None", "Stubble", "Full", "Goatee"]
const HUMAN_COLORS := [Color("38bdf8"), Color("f43f5e"), Color("a3e635"), Color("fbbf24")]

static var _cache := {}


static func mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var key := "%s_%.2f" % [c.to_html(), rough]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_cache[key] = m
	return m


static func unshaded(c: Color) -> StandardMaterial3D:
	var key := "u_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	_cache[key] = m
	return m
