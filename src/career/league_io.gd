class_name LeagueIO
extends RefCounted
## League files for editing in a spreadsheet: teams.csv + players.csv.
## teams.csv:   id,division,name,short,color1,color2,formation
## players.csv: team_id,slot,name,number,spd,sht,pas,tkl,kep,skin,hair,hair_color,beard
## Slot 0 is the goalkeeper; slots 1..5 follow the formation.

const DIR := "user://league"

const TEAM_COLS := ["id", "division", "name", "short", "color1", "color2", "formation"]
const PLAYER_COLS := ["team_id", "slot", "name", "number", "spd", "sht", "pas", "tkl", "kep", "skin", "hair", "hair_color", "beard"]


static func folder() -> String:
	return ProjectSettings.globalize_path(DIR)


static func export_league(teams: Array, divisions: Array, dir: String = DIR) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var tf := FileAccess.open(dir + "/teams.csv", FileAccess.WRITE)
	var pf := FileAccess.open(dir + "/players.csv", FileAccess.WRITE)
	if tf == null or pf == null:
		return ""
	tf.store_csv_line(PackedStringArray(TEAM_COLS))
	pf.store_csv_line(PackedStringArray(PLAYER_COLS))
	for t in teams:
		var td := t as TeamData
		var div := 1
		for d in divisions.size():
			if divisions[d].has(td.id):
				div = d + 1
		tf.store_csv_line(PackedStringArray([str(td.id), str(div), td.name, td.short, td.color1.to_html(false), td.color2.to_html(false), td.formation]))
		for i in td.players.size():
			var p := td.players[i] as PlayerData
			pf.store_csv_line(PackedStringArray([str(td.id), str(i), p.name, str(p.number),
				str(p.stat("spd")), str(p.stat("sht")), str(p.stat("pas")), str(p.stat("tkl")), str(p.stat("kep")),
				str(p.skin), str(p.hair), str(p.hair_color), str(p.beard)]))
	return ProjectSettings.globalize_path(dir)


static func has_league(dir: String = DIR) -> bool:
	return FileAccess.file_exists(dir + "/teams.csv") and FileAccess.file_exists(dir + "/players.csv")


static func _read(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	var head := f.get_csv_line()
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < 2:
			continue
		var row := {}
		for i in mini(head.size(), line.size()):
			row[head[i].strip_edges()] = line[i].strip_edges()
		rows.append(row)
	return rows


## Returns {"teams": Array[TeamData] (index == id), "divisions": [[ids]...]} or {"error": text}.
static func import_league(dir: String = DIR) -> Dictionary:
	if not has_league(dir):
		return {"error": "teams.csv / players.csv not found in " + ProjectSettings.globalize_path(dir)}
	var trows := _read(dir + "/teams.csv")
	var prows := _read(dir + "/players.csv")
	var by_id := {}
	var div_of := {}
	for r in trows:
		var t := TeamData.new()
		t.id = int(r.get("id", by_id.size()))
		t.name = str(r.get("name", "Team %d" % t.id)).substr(0, 28)
		t.short = str(r.get("short", t.name.substr(0, 3))).to_upper().substr(0, 3)
		t.color1 = Color.from_string(str(r.get("color1", "cc2222")), Color.RED)
		t.color2 = Color.from_string(str(r.get("color2", "ffffff")), Color.WHITE)
		t.formation = str(r.get("formation", "2-2-1"))
		if not TeamData.FORMATIONS.has(t.formation):
			t.formation = "2-2-1"
		for i in 6:
			var p := PlayerData.new()
			p.number = i + 1
			t.players.append(p)
		by_id[t.id] = t
		div_of[t.id] = clampi(int(r.get("division", 1)), 1, 4) - 1
	for r in prows:
		var tid := int(r.get("team_id", -1))
		if not by_id.has(tid):
			continue
		var slot := clampi(int(r.get("slot", 0)), 0, 5)
		var p := (by_id[tid] as TeamData).players[slot] as PlayerData
		p.name = str(r.get("name", p.name)).substr(0, 24)
		p.number = clampi(int(r.get("number", p.number)), 1, 99)
		for k in C.STAT_KEYS:
			p.stats[k] = clampi(int(r.get(k, 5)), C.STAT_MIN, C.STAT_MAX)
		p.skin = clampi(int(r.get("skin", 0)), 0, Looks.SKIN.size() - 1)
		p.hair = clampi(int(r.get("hair", 0)), 0, Looks.HAIR_NAMES.size() - 1)
		p.hair_color = clampi(int(r.get("hair_color", 0)), 0, Looks.HAIR_COLOR.size() - 1)
		p.beard = clampi(int(r.get("beard", 0)), 0, Looks.BEARD_NAMES.size() - 1)
	var ids: Array = by_id.keys()
	ids.sort()
	if ids.size() != 64:
		return {"error": "a league needs exactly 64 teams, found %d" % ids.size()}
	var teams: Array = []
	var remap := {}
	for i in ids.size():
		var t: TeamData = by_id[ids[i]]
		remap[t.id] = i
		t.id = i
		teams.append(t)
	var divisions: Array = [[], [], [], []]
	for old in ids:
		divisions[div_of[old]].append(remap[old])
	for d in 4:
		if divisions[d].size() != 16:
			return {"error": "every division needs 16 teams (division %d has %d)" % [d + 1, divisions[d].size()]}
	return {"teams": teams, "divisions": divisions}
