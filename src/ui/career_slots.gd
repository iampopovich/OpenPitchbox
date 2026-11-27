class_name CareerSlots
extends Screen
## Three career save slots.


func _ready() -> void:
	base("Career", "64 clubs · 4 divisions · the Pitchbox Cup")
	for slot in 3:
		var sum := Career.slot_summary(slot)
		var row := Screen.hbox()
		content.add_child(row)
		row.add_child(Screen.cell("SLOT %d" % (slot + 1), 84, UiTheme.MUTED, 18))
		var main_b: Button
		if sum == "":
			main_b = UiTheme.button("+  New career", func(): _new(slot), 0)
		else:
			main_b = UiTheme.primary(UiTheme.button(sum, func(): _open(slot), 0))
		main_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_b.custom_minimum_size.y = 58
		row.add_child(main_b)
		if sum != "":
			row.add_child(UiTheme.button("Delete", func(): _delete(slot), 140))
		else:
			var gap := Control.new()          # keeps the rows the same width
			gap.custom_minimum_size = Vector2(140, 0)
			row.add_child(gap)
	footer.add_child(UiTheme.button("Back", back, 200))
	focus_first()


func _new(slot: int) -> void:
	var s := NewCareer.new()
	s.slot = slot
	Game.show_menu(s)


func _open(slot: int) -> void:
	var c := Career.load_slot(slot)
	if c == null:
		return
	Game.career = c
	Game.career_slot = slot
	Game.show_menu(CareerHub.new())


func _delete(slot: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.slot_path(slot)))
	Game.show_menu(CareerSlots.new())

