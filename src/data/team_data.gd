class_name TeamData
extends RefCounted
## A club: name, kit, formation and six players.
## players[0] is the goalkeeper, players[1..5] fill the formation slots in order.

var id: int = 0
var name: String = "Team"
var short: String = "TEA"
var color1: Color = Color(0.85, 0.1, 0.1)
var color2: Color = Color(1, 1, 1)
var formation: String = "2-2-1"
var players: Array = []   # Array[PlayerData], size 6

# Formation slots: [role, depth (-1 own goal .. +1 opponent goal), width (-1..1)]
const FORMATIONS := {
	"2-2-1": [["DEF", -0.62, -0.38], ["DEF", -0.62, 0.38], ["MID", -0.18, -0.52], ["MID", -0.18, 0.52], ["FWD", 0.38, 0.0]],
	"1-2-2": [["DEF", -0.65, 0.0], ["MID", -0.28, -0.5], ["MID", -0.28, 0.5], ["FWD", 0.3, -0.3], ["FWD", 0.3, 0.3]],
	"2-1-2": [["DEF", -0.62, -0.36], ["DEF", -0.62, 0.36], ["MID", -0.22, 0.0], ["FWD", 0.3, -0.32], ["FWD", 0.3, 0.32]],
	"3-1-1": [["DEF", -0.64, -0.5], ["DEF", -0.7, 0.0], ["DEF", -0.64, 0.5], ["MID", -0.2, 0.0], ["FWD", 0.36, 0.0]],
	"1-3-1": [["DEF", -0.66, 0.0], ["MID", -0.25, -0.6], ["MID", -0.3, 0.0], ["MID", -0.25, 0.6], ["FWD", 0.36, 0.0]],
}
const FORMATION_ORDER := ["2-2-1", "1-2-2", "2-1-2", "3-1-1", "1-3-1"]


func slots() -> Array:
	return FORMATIONS.get(formation, FORMATIONS["2-2-1"])


func role_of(index: int) -> String:
	if index == 0:
		return "GK"
	return slots()[index - 1][0]


func rating() -> float:
	## Average role-weighted rating, 1..20
	if players.is_empty():
		return 1.0
	var total := 0.0
	for i in players.size():
		var w := 1.3 if i == 0 else 1.0
		total += (players[i] as PlayerData).overall(role_of(i)) * w
	return total / (players.size() + 0.3)


func stars() -> float:
	## 0.5 .. 5 stars in half steps
	var r := (rating() - 2.0) / 15.0 * 5.0
	return clampf(roundf(r * 2.0) / 2.0, 0.5, 5.0)


func to_dict() -> Dictionary:
	var ps: Array = []
	for p in players:
		ps.append((p as PlayerData).to_dict())
	return {
		"id": id, "name": name, "short": short,
		"color1": color1.to_html(false), "color2": color2.to_html(false),
		"formation": formation, "players": ps,
	}


static func from_dict(d: Dictionary) -> TeamData:
	var t := TeamData.new()
	t.id = int(d.get("id", 0))
	t.name = str(d.get("name", "Team"))
	t.short = str(d.get("short", t.name.substr(0, 3).to_upper()))
	t.color1 = Color.from_string(str(d.get("color1", "cc2222")), Color.RED)
	t.color2 = Color.from_string(str(d.get("color2", "ffffff")), Color.WHITE)
	t.formation = str(d.get("formation", "2-2-1"))
	if not FORMATIONS.has(t.formation):
		t.formation = "2-2-1"
	for pd in d.get("players", []):
		t.players.append(PlayerData.from_dict(pd))
	while t.players.size() < 6:
		var p := PlayerData.new()
		p.number = t.players.size() + 1
		t.players.append(p)
	if t.players.size() > 6:
		t.players.resize(6)
	return t


func clone() -> TeamData:
	return TeamData.from_dict(to_dict())
