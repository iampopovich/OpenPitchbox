class_name Looks
extends RefCounted
## Palettes and shared materials for the procedural characters.

const SKIN := [Color("e8c1a0"), Color("d6a681"), Color("b98763"), Color("94654a"), Color("6e4733"), Color("4b3024")]
const HAIR_COLOR := [Color("161412"), Color("3b2a1e"), Color("6b4a2f"), Color("b89a6a"), Color("8a3b22"), Color("8c8c8c")]
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


static func fabric(c: Color) -> StandardMaterial3D:
	## Matte jersey cloth with a soft sheen at grazing angles.
	var key := "f_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.82
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	_cache[key] = m
	return m


static func skin(c: Color) -> StandardMaterial3D:
	var key := "s_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.8
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
