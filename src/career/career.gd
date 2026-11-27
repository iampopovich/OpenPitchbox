class_name Career
extends RefCounted
## Multi-season career: 64 clubs in 4 divisions of 16, 15-matchday league, top-8 playoffs,
## promotion/relegation, Division 1 playoff = the Pitchbox Cup, RPG-style squad upgrades.

const DIVS := 4
const PER_DIV := 16
const ROUNDS := 15
const DIV_MEANS := [13.5, 10.5, 8.0, 5.5]     # Division 1 .. Division 4
const STAGE_NAMES := ["Quarter-final", "Semi-final", "Final"]
const CUP_NAME := "Pitchbox Cup"

var seed: int = 1
var rng := RandomNumberGenerator.new()
var teams: Array = []           # Array[TeamData], index == id
var divisions: Array = []       # [div][16 team ids], div 0 = Division 1
var user_team: int = 0
var season: int = 1
var phase: String = "league"    # league | playoffs | offseason
var matchday: int = 0
var fixtures: Array = []        # [div][matchday] -> [[home, away], ...]
var results: Array = []         # [div][matchday] -> [[home, away, gh, ga], ...]
var table: Array = []           # [div] -> {team_id: {p,w,d,l,gf,ga,pts}}
var playoffs: Array = []        # [div] -> {seeds: [8], stages: [[[a, b, ga, gb]...], ...]}
var stage: int = 0              # playoff stage 0..2
var history: Array = []
var opts := {"length": 180.0, "difficulty": 1, "devices": ["kb1"], "auto_upgrade": false, "roleplay": false}
var last_summary := {}          # set after each user match (for the upgrade screen)
var news: Array = []            # end-of-season lines


# ------------------------------------------------------------------ creation

static func create(p_seed: int, options: Dictionary = {}, league: Dictionary = {}) -> Career:
	var c := Career.new()
	c.seed = p_seed
	c.rng.seed = p_seed
	for k in options:
		c.opts[k] = options[k]
	if league.has("teams"):
		# a custom league from CSV: use it as is, the user picks up a random Division 4 club
		c.teams = league["teams"]
		c.divisions = league["divisions"]
		c.user_team = c.divisions[DIVS - 1][c.rng.randi() % PER_DIV]
		c.start_season()
		return c
	var names := TeamFactory.club_names(c.rng, DIVS * PER_DIV)
	var id := 0
	for d in DIVS:
		var ids: Array = []
		for i in PER_DIV:
			var mean: float = DIV_MEANS[d] + c.rng.randf_range(-1.2, 1.2)
			var t := TeamFactory.make_team(c.rng, id, names[id], mean)
			c.teams.append(t)
			ids.append(id)
			id += 1
		c.divisions.append(ids)
	# the user starts with a random, below-average club in Division 4
	var pick: int = c.divisions[DIVS - 1][c.rng.randi() % PER_DIV]
	var weak := TeamFactory.make_team(c.rng, pick, c.teams[pick].name, 4.5)
	c.teams[pick] = weak
	c.user_team = pick
	c.start_season()
	return c


func start_season() -> void:
	phase = "league"
	matchday = 0
	stage = 0
	fixtures.clear()
	results.clear()
	table.clear()
	playoffs.clear()
	for d in DIVS:
		fixtures.append(_round_robin(divisions[d]))
		var rr: Array = []
		for r in ROUNDS:
			rr.append([])
		results.append(rr)
		var tb := {}
		for tid in divisions[d]:
			tb[tid] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
		table.append(tb)
		playoffs.append({"seeds": [], "stages": []})
	for t in teams:
		for p in (t as TeamData).players:
			(p as PlayerData).reset_season()


func _round_robin(ids: Array) -> Array:
	## Circle method: 16 teams -> 15 rounds of 8 matches, alternating home/away.
	var arr := ids.duplicate()
	# shuffle so the schedule differs every season
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	var n := arr.size()
	var rounds: Array = []
	for r in n - 1:
		var games: Array = []
		for i in n / 2:
			var a = arr[i]
			var b = arr[n - 1 - i]
			if (r + i) % 2 == 0:
				games.append([a, b])
			else:
				games.append([b, a])
		rounds.append(games)
		# rotate all but the first
		var last = arr.pop_back()
		arr.insert(1, last)
	return rounds


# ------------------------------------------------------------------ queries

func team(id: int) -> TeamData:
	return teams[id]


func user() -> TeamData:
	return teams[user_team]


func division_of(id: int) -> int:
	for d in DIVS:
		if divisions[d].has(id):
			return d
	return -1


func user_div() -> int:
	return division_of(user_team)


static func div_name(d: int) -> String:
	return "Division %d" % (d + 1)


func standings(d: int) -> Array:
	## Team ids sorted by points, goal difference, goals for, name.
	var ids: Array = divisions[d].duplicate()
	var tb: Dictionary = table[d]
	ids.sort_custom(func(a, b):
		var zero := {"pts": 0, "gf": 0, "ga": 0}
		var ra: Dictionary = tb.get(a, zero)
		var rb: Dictionary = tb.get(b, zero)
		if ra["pts"] != rb["pts"]:
			return ra["pts"] > rb["pts"]
		var gda: int = ra["gf"] - ra["ga"]
		var gdb: int = rb["gf"] - rb["ga"]
		if gda != gdb:
			return gda > gdb
		if ra["gf"] != rb["gf"]:
			return ra["gf"] > rb["gf"]
		return teams[a].name < teams[b].name)
	return ids


func user_alive_in_playoffs() -> bool:
	if phase != "playoffs":
		return false
	var po: Dictionary = playoffs[user_div()]
	if not po["seeds"].has(user_team):
		return false
	# alive if not eliminated in any finished stage
	for st in po["stages"]:
		for m in st:
			if m.size() >= 4 and (m[0] == user_team or m[1] == user_team):
				var won: bool = (m[2] > m[3]) == (m[0] == user_team)
				if not won:
					return false
	return true


func next_user_fixture() -> Array:
	## [home, away, needs_winner] or [] when the user has nothing to play right now.
	if phase == "league":
		for g in fixtures[user_div()][matchday]:
			if g[0] == user_team or g[1] == user_team:
				return [g[0], g[1], false]
	elif phase == "playoffs" and user_alive_in_playoffs():
		var po: Dictionary = playoffs[user_div()]
		var pairs := _stage_pairs(user_div())
		for g in pairs:
			if g[0] == user_team or g[1] == user_team:
				return [g[0], g[1], true]
	return []


func stage_label() -> String:
	if phase == "league":
		return "Round %d / %d" % [matchday + 1, ROUNDS]
	if phase == "playoffs":
		return STAGE_NAMES[stage]
	return "Season over"


# ------------------------------------------------------------------ results

func sim_score(a: int, b: int, needs_winner: bool) -> Array:
	var ra := team(a).rating()
	var rb := team(b).rating()
	var diff := ra - rb + 0.4  # small home edge
	var la := 2.1 * exp(diff * 0.095)
	var lb := 2.1 * exp(-diff * 0.095)
	var ga := _poisson(la)
	var gb := _poisson(lb)
	if needs_winner and ga == gb:
		var p := 1.0 / (1.0 + exp(-diff * 0.25))
		if rng.randf() < p:
			ga += 1
		else:
			gb += 1
	_credit_sim_stats(a, ga, gb)
	_credit_sim_stats(b, gb, ga)
	return [ga, gb]


func _poisson(l: float) -> int:
	var L := exp(-l)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= L:
			break
		k += 1
		if k > 15:
			break
	return k


func _credit_sim_stats(tid: int, gf: int, ga: int) -> void:
	var t: TeamData = teams[tid]
	for p in t.players:
		(p as PlayerData).count("apps")
	for g in gf:
		var s := _weighted_player(t, "sht", true)
		s.count("goals")
		if rng.randf() < 0.6:
			var a := _weighted_player(t, "pas", true)
			if a != s:
				a.count("assists")
	var gk: PlayerData = t.players[0]
	gk.count("saves", maxi(0, int(rng.randi_range(1, 5)) - ga / 2))
	for i in rng.randi_range(2, 7):
		_weighted_player(t, "tkl", true).count("tackles")


func _weighted_player(t: TeamData, key: String, outfield: bool) -> PlayerData:
	var total := 0.0
	for i in range(1 if outfield else 0, 6):
		total += pow(float((t.players[i] as PlayerData).stat(key)), 1.5)
	var r := rng.randf() * total
	for i in range(1 if outfield else 0, 6):
		r -= pow(float((t.players[i] as PlayerData).stat(key)), 1.5)
		if r <= 0.0:
			return t.players[i]
	return t.players[5]


func _apply_table(d: int, h: int, a: int, gh: int, ga: int) -> void:
	var tb: Dictionary = table[d]
	var rh: Dictionary = tb[h]
	var ra: Dictionary = tb[a]
	rh["p"] += 1
	ra["p"] += 1
	rh["gf"] += gh
	rh["ga"] += ga
	ra["gf"] += ga
	ra["ga"] += gh
	if gh > ga:
		rh["w"] += 1
		ra["l"] += 1
		rh["pts"] += 3
	elif gh < ga:
		ra["w"] += 1
		rh["l"] += 1
		ra["pts"] += 3
	else:
		rh["d"] += 1
		ra["d"] += 1
		rh["pts"] += 1
		ra["pts"] += 1


## Records the user's match (from MatchView result) and simulates the rest of the matchday/stage.
## `result` needs "score" [home, away] and optionally "pstats" (12 entries, home 0..5, away 6..11).
func record_user_match(result: Dictionary) -> Dictionary:
	var fx := next_user_fixture()
	if fx.is_empty():
		return {}
	var h: int = fx[0]
	var a: int = fx[1]
	var gh: int = result["score"][0]
	var ga: int = result["score"][1]
	if result.get("aborted", false):
		# walking off counts as a 0-3 defeat
		gh = 0 if h == user_team else 3
		ga = 3 if h == user_team else 0
	var ps: Array = result.get("pstats", [])
	for side in 2:
		var t: TeamData = teams[h if side == 0 else a]
		for i in 6:
			var pd: PlayerData = t.players[i]
			pd.count("apps")
			if ps.size() == 12 and not result.get("aborted", false):
				var st: Dictionary = ps[side * 6 + i]
				for k in ["goals", "assists", "shots", "tackles", "saves"]:
					pd.count(k, int(st.get(k, 0)))
	var user_home := h == user_team
	var gf := gh if user_home else ga
	var gagainst := ga if user_home else gh
	var opp := a if user_home else h
	var summary := _award(gf, gagainst, opp)
	summary["home"] = h
	summary["away"] = a
	summary["score"] = [gh, ga]
	if phase == "league":
		results[user_div()][matchday].append([h, a, gh, ga])
		_apply_table(user_div(), h, a, gh, ga)
		_finish_league_round()
	else:
		_finish_playoff_stage([h, a, gh, ga])
	last_summary = summary
	return summary


func skip_without_user() -> void:
	## Advances when the user has no match (eliminated / not qualified).
	if phase == "league":
		_finish_league_round()
	elif phase == "playoffs":
		_finish_playoff_stage([])


func _finish_league_round() -> void:
	for d in DIVS:
		for g in fixtures[d][matchday]:
			if g[0] == user_team or g[1] == user_team:
				continue
			var sc := sim_score(g[0], g[1], false)
			results[d][matchday].append([g[0], g[1], sc[0], sc[1]])
			_apply_table(d, g[0], g[1], sc[0], sc[1])
	matchday += 1
	if matchday >= ROUNDS:
		_start_playoffs()


func _start_playoffs() -> void:
	phase = "playoffs"
	stage = 0
	for d in DIVS:
		var top: Array = standings(d).slice(0, 8)
		playoffs[d] = {"seeds": top, "stages": []}


func _stage_pairs(d: int) -> Array:
	var po: Dictionary = playoffs[d]
	if stage == 0:
		var s: Array = po["seeds"]
		return [[s[0], s[7]], [s[3], s[4]], [s[1], s[6]], [s[2], s[5]]]
	var prev: Array = po["stages"][stage - 1]
	var winners: Array = []
	for m in prev:
		winners.append(m[0] if m[2] > m[3] else m[1])
	var out: Array = []
	for i in range(0, winners.size(), 2):
		out.append([winners[i], winners[i + 1]])
	return out


func _finish_playoff_stage(user_result: Array) -> void:
	for d in DIVS:
		var pairs := _stage_pairs(d)
		var done: Array = []
		for g in pairs:
			if not user_result.is_empty() and g[0] == user_result[0] and g[1] == user_result[1]:
				done.append(user_result)
			else:
				var sc := sim_score(g[0], g[1], true)
				done.append([g[0], g[1], sc[0], sc[1]])
		playoffs[d]["stages"].append(done)
	stage += 1
	if stage >= 3:
		_end_season()


func playoff_winner(d: int) -> int:
	var st: Array = playoffs[d]["stages"]
	if st.size() < 3:
		return -1
	var f: Array = st[2][0]
	return f[0] if f[2] > f[3] else f[1]


func playoff_finalists(d: int) -> Array:
	var st: Array = playoffs[d]["stages"]
	if st.size() < 3:
		return []
	return [st[2][0][0], st[2][0][1]]


func _end_season() -> void:
	phase = "offseason"
	news.clear()
	var ud := user_div()
	var user_pos := standings(ud).find(user_team) + 1
	var champion := playoff_winner(0)
	var up: Array = []      # [div] -> ids moving up from div
	var down: Array = []    # [div] -> ids moving down from div
	for d in DIVS:
		up.append(playoff_finalists(d) if d > 0 else [])
		var st := standings(d)
		down.append([st[PER_DIV - 1], st[PER_DIV - 2]] if d < DIVS - 1 else [])
	# a finalist that also finished bottom-two cannot happen (finalists are top 8)
	var entry := {
		"season": season, "champion": champion, "champion_name": teams[champion].name,
		"user_div": ud, "user_pos": user_pos, "user_playoff": _user_playoff_text(ud),
	}
	history.append(entry)
	news.append("%s won the %s!" % [teams[champion].name, CUP_NAME])
	if champion == user_team:
		news.append("YOU ARE THE CHAMPIONS!")
	for d in DIVS:
		for tid in up[d]:
			divisions[d].erase(tid)
			divisions[d - 1].append(tid)
			if tid == user_team:
				news.append("Promoted to %s!" % div_name(d - 1))
		for tid in down[d]:
			divisions[d].erase(tid)
			divisions[d + 1].append(tid)
			if tid == user_team:
				news.append("Relegated to %s." % div_name(d + 1))
	_ai_offseason()


func _user_playoff_text(d: int) -> String:
	var po: Dictionary = playoffs[d]
	if not po["seeds"].has(user_team):
		return "missed the playoffs"
	var reached := 0
	for i in po["stages"].size():
		for m in po["stages"][i]:
			if m[0] == user_team or m[1] == user_team:
				reached = i
				var won: bool = (m[2] > m[3]) == (m[0] == user_team)
				if i == 2 and won:
					return "won the playoffs" if d > 0 else "won the " + CUP_NAME
	return "lost in the " + STAGE_NAMES[reached].to_lower()


func _ai_offseason() -> void:
	## AI squads drift toward their (new) division's level.
	for d in DIVS:
		for tid in divisions[d]:
			if tid == user_team:
				continue
			var t: TeamData = teams[tid]
			for i in 6:
				var pd: PlayerData = t.players[i]
				for k in C.STAT_KEYS:
					var target: float = DIV_MEANS[d]
					if k == "kep" and i != 0:
						target *= 0.45
					var v := float(pd.stat(k))
					var delta := 0
					if v < target - 1.0 and rng.randf() < 0.6:
						delta = 1
					elif v > target + 1.5 and rng.randf() < 0.5:
						delta = -1
					elif rng.randf() < 0.2:
						delta = rng.randi_range(-1, 1)
					pd.add_stat(k, delta)


func next_season() -> void:
	season += 1
	start_season()


# ------------------------------------------------------------------ progression

func _award(gf: int, ga: int, opp: int) -> Dictionary:
	var ur := user().rating()
	var orr := team(opp).rating()
	var pts := gf * 0.8 - ga * 0.4
	if gf > ga:
		pts += 1.2
	elif gf == ga:
		pts += 0.4
	pts += (orr - ur) * 0.25
	var level := clampi(int(floor(pts / 1.8)), 0, 4)
	return {"points": snappedf(pts, 0.1), "level": level, "opp_rating": orr, "user_rating": ur}


static func auto_stat(pd: PlayerData, role: String) -> String:
	var prio: Array = {
		"GK": ["kep", "kep", "pas", "spd"],
		"DEF": ["tkl", "spd", "pas", "tkl"],
		"MID": ["pas", "spd", "tkl", "sht"],
		"FWD": ["sht", "spd", "sht", "pas"],
	}[role]
	var best: String = prio[0]
	var bv := 999.0
	for i in prio.size():
		var k: String = prio[i]
		var v := pd.stat(k) + i * 2.0
		if pd.stat(k) < C.STAT_MAX and v < bv:
			bv = v
			best = k
	return best


func apply_upgrades(choices: Array, level: int) -> void:
	## choices[i] = stat key for player i (6 entries). Empty string = auto.
	var t := user()
	for i in 6:
		var key: String = choices[i] if i < choices.size() else ""
		if key == "":
			key = auto_stat(t.players[i], t.role_of(i))
		(t.players[i] as PlayerData).add_stat(key, level)


# ------------------------------------------------------------------ leaders

func leaders(key: String, d: int = -1, n: int = 10) -> Array:
	## [[PlayerData, TeamData, value], ...] sorted desc, for one division or all (-1).
	var rows: Array = []
	for dd in DIVS:
		if d >= 0 and dd != d:
			continue
		for tid in divisions[dd]:
			var t: TeamData = teams[tid]
			for p in t.players:
				var v := int((p as PlayerData).season.get(key, 0))
				if v > 0:
					rows.append([p, t, v])
	rows.sort_custom(func(x, y): return x[2] > y[2])
	return rows.slice(0, n)


# ------------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	var ts: Array = []
	for t in teams:
		ts.append((t as TeamData).to_dict())
	var tbl: Array = []
	for d in DIVS:
		var o := {}
		for k in table[d]:
			o[str(k)] = table[d][k]
		tbl.append(o)
	return {
		"version": 1, "seed": seed, "rng_state": str(rng.state), "teams": ts, "divisions": divisions,
		"user_team": user_team, "season": season, "phase": phase, "round": matchday, "stage": stage,
		"fixtures": fixtures, "results": results, "table": tbl, "playoffs": playoffs,
		"history": history, "opts": opts, "news": news,
	}


static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	c.seed = int(d.get("seed", 1))
	c.rng.seed = c.seed
	if d.has("rng_state"):
		c.rng.state = int(str(d["rng_state"]))
	for td in d["teams"]:
		c.teams.append(TeamData.from_dict(td))
	c.divisions = _int_nested(d["divisions"])
	c.user_team = int(d["user_team"])
	c.season = int(d["season"])
	c.phase = str(d["phase"])
	c.matchday = int(d["round"])
	c.stage = int(d.get("stage", 0))
	c.fixtures = _int_nested(d["fixtures"])
	c.results = _int_nested(d["results"])
	c.table = []
	for o in d["table"]:
		var tb := {}
		for k in o:
			var row := {}
			for f in o[k]:
				row[f] = int(o[k][f])
			tb[int(k)] = row
		c.table.append(tb)
	c.playoffs = []
	for po in d["playoffs"]:
		c.playoffs.append({"seeds": _int_nested(po["seeds"]), "stages": _int_nested(po["stages"])})
	c.history = d.get("history", [])
	for k in d.get("opts", {}):
		c.opts[k] = d["opts"][k]
	c.news = d.get("news", [])
	return c


static func _int_nested(v):
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_int_nested(x))
		return out
	if v is float:
		return int(v)
	return v


static func slot_path(slot: int) -> String:
	return "user://career_%d.json" % slot


func save(slot: int) -> bool:
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


static func load_slot(slot: int) -> Career:
	if not FileAccess.file_exists(slot_path(slot)):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not d is Dictionary:
		return null
	return Career.from_dict(d)


static func slot_summary(slot: int) -> String:
	if not FileAccess.file_exists(slot_path(slot)):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not d is Dictionary:
		return "corrupt save"
	var ut: int = int(d["user_team"])
	var name := str(d["teams"][ut]["name"])
	var div := 0
	for i in d["divisions"].size():
		if d["divisions"][i].has(float(ut)) or d["divisions"][i].has(ut):
			div = i
	return "%s — season %d, %s" % [name, int(d["season"]), div_name(div)]
