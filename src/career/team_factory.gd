class_name TeamFactory
extends RefCounted
## Fictional clubs and players. Everything is generated from a seed.

const CITIES := [
	"Arden", "Bayside", "Kestrel", "Norvik", "Calder", "Port Lucan", "Valmora", "Brightwater",
	"Oskarberg", "Rimini Bay", "Santa Lira", "Ternhaven", "Duskmoor", "Ironford", "Lakemont", "Westmarch",
	"Kaskara", "Monteverde", "Novaya Gavan", "Ashby", "Corran", "Esperanza", "Fjellvik", "Gorsk",
	"Harbourne", "Istria", "Jadeport", "Kilbride", "Lowenstadt", "Marisco", "Nordholm", "Oakridge",
	"Pradera", "Quarry Hill", "Redwater", "Solano", "Thornbury", "Ulmeria", "Vostok", "Wexmoor",
	"Yarrow", "Zelena", "Almadra", "Borodin", "Castellon", "Drakensfeld", "Elmira", "Falkenrath",
	"Granada Nova", "Holloway", "Ingleby", "Jurmala Sands", "Kingsreach", "Lisandra", "Mirovsk", "Newhaven",
	"Orsova", "Palmeira", "Ravensholm", "Silverdale", "Tamarind", "Umbra", "Valdora", "Windmere",
]
const SUFFIXES := [
	"United", "Rovers", "Athletic", "FC", "Dynamo", "Wanderers", "Rangers", "City", "Sporting", "Olympic",
	"Albion", "Town", "Real", "Strikers", "Comets", "Harriers", "Spartans", "Lions", "Wolves", "Pirates",
]
const FIRST := [
	"Alex", "Bruno", "Carlos", "Dmitri", "Eli", "Femi", "Gio", "Hugo", "Ivan", "Jonas", "Kenji", "Luca",
	"Marco", "Nico", "Oscar", "Pavel", "Quinn", "Rafa", "Sami", "Tomas", "Umar", "Viktor", "Wes", "Xavi",
	"Yusuf", "Zane", "Arin", "Bodhi", "Cyril", "Dario", "Emil", "Felix", "Goran", "Hamza", "Ilya", "Joel",
	"Kofi", "Leon", "Mateo", "Nils", "Omar", "Piet", "Rio", "Stefan", "Teo", "Ugo", "Vlad", "Yann",
]
const LAST := [
	"Abara", "Berg", "Costa", "Dahl", "Eriksen", "Ferro", "Gallo", "Horvat", "Ivanov", "Jansen", "Kowal",
	"Lindqvist", "Moreau", "Novak", "Okafor", "Petrov", "Quispe", "Rossi", "Silva", "Tanaka", "Ueda",
	"Varga", "Weller", "Xu", "Yilmaz", "Zoric", "Almeida", "Brandt", "Chen", "Duarte", "Engel", "Fischer",
	"Garcia", "Haas", "Iqbal", "Jovic", "Kim", "Lopez", "Mendes", "Nakamura", "Orlov", "Popescu", "Reyes",
	"Sato", "Torres", "Vidal", "Wojcik", "Zielinski", "Mbeki", "Haddad", "Kovac", "Lund", "Murphy", "Nagy",
]
const KIT_COLORS := [
	Color("d62828"), Color("1d4ed8"), Color("15803d"), Color("facc15"), Color("f97316"), Color("7c3aed"),
	Color("0f172a"), Color("f8fafc"), Color("0891b2"), Color("be185d"), Color("65a30d"), Color("92400e"),
	Color("64748b"), Color("e11d48"), Color("0369a1"), Color("a16207"),
]

const SKIN_TONES := 6
const HAIR_STYLES := 4
const HAIR_COLORS := 6
const BEARDS := 2

const ROLE_FOCUS := {
	"GK": ["kep", "kep", "pas"],
	"DEF": ["tkl", "tkl", "spd"],
	"MID": ["pas", "spd", "tkl"],
	"FWD": ["sht", "sht", "spd"],
}


static func make_player(rng: RandomNumberGenerator, role: String, mean: float, number: int) -> PlayerData:
	var p := PlayerData.new()
	p.name = "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
	p.number = number
	# every player has a profile: one clear strength and one weakness around the team level
	var strong: String = C.STAT_KEYS[rng.randi() % 4]
	var weak: String = C.STAT_KEYS[rng.randi() % 4]
	for k in C.STAT_KEYS:
		var v := mean + rng.randfn(0.0, 2.2)
		if k == strong:
			v += 3.0
		elif k == weak:
			v -= 2.5
		if k == "kep" and role != "GK":
			v = mean * 0.45 + rng.randfn(0.0, 1.0)
		elif role == "GK" and k != "kep" and k != "pas":
			v = mean * 0.7 + rng.randfn(0.0, 1.0)
		p.stats[k] = clampi(int(roundf(v)), C.STAT_MIN, C.STAT_MAX)
	for k in ROLE_FOCUS[role]:
		p.stats[k] = clampi(p.stats[k] + 1, C.STAT_MIN, C.STAT_MAX)
	p.skin = rng.randi() % SKIN_TONES
	p.hair = rng.randi() % HAIR_STYLES
	p.hair_color = rng.randi() % HAIR_COLORS
	p.beard = rng.randi() % BEARDS if rng.randf() < 0.4 else 0
	return p


static func make_team(rng: RandomNumberGenerator, id: int, name: String, mean: float) -> TeamData:
	var t := TeamData.new()
	t.id = id
	t.name = name
	t.short = short_name(name)
	var c1: Color = KIT_COLORS[rng.randi() % KIT_COLORS.size()]
	var c2: Color = KIT_COLORS[rng.randi() % KIT_COLORS.size()]
	var guard := 0
	while c2.is_equal_approx(c1) or _too_close(c1, c2):
		c2 = KIT_COLORS[rng.randi() % KIT_COLORS.size()]
		guard += 1
		if guard > 20:
			c2 = Color.WHITE if c1.get_luminance() < 0.6 else Color.BLACK
			break
	t.color1 = c1
	t.color2 = c2
	t.formation = TeamData.FORMATION_ORDER[rng.randi() % 3]
	var numbers := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 17, 19, 23]
	for i in 6:
		var role := t.role_of(i)
		var num: int = 1 if i == 0 else numbers[1 + rng.randi() % (numbers.size() - 1)]
		t.players.append(make_player(rng, role, mean, num))
	return t


static func _too_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.45


static func short_name(name: String) -> String:
	var letters := name.replace(" ", "").to_upper()
	return letters.substr(0, 3)


static func club_names(rng: RandomNumberGenerator, n: int) -> Array:
	var cities := CITIES.duplicate()
	# Fisher-Yates with our rng for determinism
	for i in range(cities.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = cities[i]
		cities[i] = cities[j]
		cities[j] = tmp
	var out: Array = []
	for i in n:
		var city: String = cities[i % cities.size()]
		var suf: String = SUFFIXES[rng.randi() % SUFFIXES.size()]
		out.append("%s %s" % [city, suf] if rng.randf() < 0.85 else "%s %s" % [suf, city])
	return out


static func quick_pair(seed: int, mean0: float = 9.0, mean1: float = 9.0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var names := club_names(rng, 2)
	return [make_team(rng, 0, names[0], mean0), make_team(rng, 1, names[1], mean1)]
