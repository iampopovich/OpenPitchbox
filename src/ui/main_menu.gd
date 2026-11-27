class_name MainMenu
extends Screen
## Title screen.


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	var t := UiTheme.title("OpenPitchbox")
	t.add_theme_font_size_override("font_size", 72)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := UiTheme.label("indoor six-a-side football", 22, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(Control.new())
	vb.add_child(UiTheme.button("Career", func(): Game.show_menu(CareerSlots.new())))
	vb.add_child(UiTheme.button("Exhibition", func(): Game.show_menu(MatchSetup.new())))
	vb.add_child(UiTheme.button("Practice", func():
		var s := MatchSetup.new()
		s.practice = true
		Game.show_menu(s)))
	vb.add_child(UiTheme.button("Options", func(): Game.show_menu(OptionsScreen.new())))
	vb.add_child(UiTheme.button("Quit", func(): get_tree().quit()))
	var ver := UiTheme.label("MIT licensed · github.com/iampopovich/OpenPitchbox", 16, UiTheme.MUTED)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(20, -34)
	add_child(ver)
	focus_first()


func back() -> void:
	pass
