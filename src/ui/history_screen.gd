class_name HistoryScreen
extends Screen
## Past seasons: champions and how the user's club did.


func _ready() -> void:
	var c: Career = Game.career
	base("History", c.user().name)
	if c.history.is_empty():
		content.add_child(UiTheme.label("No finished seasons yet.", 22, UiTheme.MUTED))
	for h in c.history:
		var line := "Season %d   ·   %s champions: %s   ·   you: %s, %s place, %s" % [
			int(h["season"]), Career.CUP_NAME, str(h["champion_name"]), Career.div_name(int(h["user_div"])),
			_ord(int(h["user_pos"])), str(h["user_playoff"])]
		var l := UiTheme.label(line, 20, UiTheme.ACCENT2 if int(h["champion"]) == c.user_team else UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(l)
	footer.add_child(UiTheme.button("Back", back, 200))
	focus_first()


static func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	match n % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
	return "%dth" % n


func back() -> void:
	Game.show_menu(CareerHub.new())
