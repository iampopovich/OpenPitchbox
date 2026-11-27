class_name CareerSlots
extends Screen
## Three career save slots.


func _ready() -> void:
	base("Career", "64 clubs · 4 divisions · the Pitchbox Cup")
	for slot in 3:
		var sum := Career.slot_summary(slot)
		var row := Screen.hbox()
		content.add_child(row)
		row.add_child(Screen.cell("Slot %d" % (slot + 1), 110, UiTheme.ACCENT2, 24))
		if sum == "":
			row.add_child(UiTheme.button("New career", func(): _new(slot), 520))
		else:
			row.add_child(UiTheme.button("Continue: " + sum, func(): _open(slot), 520))
			var del := UiTheme.button("Delete", func(): _delete(slot), 140)
			row.add_child(del)
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

