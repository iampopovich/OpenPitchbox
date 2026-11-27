class_name PlayerData
extends RefCounted
## A squad member: identity, looks, attributes and statistics.

var name: String = "Player"
var number: int = 1
var stats: Dictionary = {"spd": 5, "sht": 5, "pas": 5, "tkl": 5, "kep": 5}
# Looks: indices into palettes defined by the renderer (see game/looks.gd)
var skin: int = 0
var hair: int = 0
var hair_color: int = 0
var beard: int = 0
# Statistics: "season" resets every season, "career" accumulates
var season: Dictionary = {}
var career: Dictionary = {}

const COUNTERS := ["apps", "goals", "assists", "shots", "tackles", "saves"]


func _init() -> void:
	reset_season()
	for k in COUNTERS:
		career[k] = 0


func stat(key: String) -> int:
	return int(stats.get(key, 5))


func add_stat(key: String, amount: int) -> int:
	var before := stat(key)
	stats[key] = clampi(before + amount, C.STAT_MIN, C.STAT_MAX)
	return stats[key] - before


func overall(role: String) -> float:
	match role:
		"GK":
			return stat("kep") * 0.7 + stat("pas") * 0.15 + stat("spd") * 0.15
		"DEF":
			return stat("tkl") * 0.4 + stat("spd") * 0.25 + stat("pas") * 0.2 + stat("sht") * 0.15
		"MID":
			return stat("pas") * 0.35 + stat("spd") * 0.25 + stat("tkl") * 0.2 + stat("sht") * 0.2
		_:
			return stat("sht") * 0.45 + stat("spd") * 0.3 + stat("pas") * 0.15 + stat("tkl") * 0.1


func reset_season() -> void:
	for k in COUNTERS:
		season[k] = 0


func count(key: String, amount: int = 1) -> void:
	season[key] = int(season.get(key, 0)) + amount
	career[key] = int(career.get(key, 0)) + amount


func to_dict() -> Dictionary:
	return {
		"name": name, "number": number, "stats": stats.duplicate(),
		"skin": skin, "hair": hair, "hair_color": hair_color, "beard": beard,
		"season": season.duplicate(), "career": career.duplicate(),
	}


static func from_dict(d: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	p.name = str(d.get("name", "Player"))
	p.number = int(d.get("number", 1))
	var s: Dictionary = d.get("stats", {})
	for k in C.STAT_KEYS:
		p.stats[k] = clampi(int(s.get(k, 5)), C.STAT_MIN, C.STAT_MAX)
	p.skin = int(d.get("skin", 0))
	p.hair = int(d.get("hair", 0))
	p.hair_color = int(d.get("hair_color", 0))
	p.beard = int(d.get("beard", 0))
	var se: Dictionary = d.get("season", {})
	var ca: Dictionary = d.get("career", {})
	for k in COUNTERS:
		p.season[k] = int(se.get(k, 0))
		p.career[k] = int(ca.get(k, 0))
	return p
