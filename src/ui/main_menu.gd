class_name MainMenu
extends Control
## Title screen.


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var sub := UiTheme.label("indoor six-a-side arcade football", 22, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(Control.new())
	var first := UiTheme.button("Quick match", _quick)
	vb.add_child(first)
	vb.add_child(UiTheme.button("Quit", func(): get_tree().quit()))
	first.grab_focus.call_deferred()


func _quick() -> void:
	var pair := TeamFactory.quick_pair(randi())
	Game.play_match({"teams": pair, "humans": [{"id": 0, "team": 0, "device": "kb1"}], "length": 180.0,
		"camera": Game.settings.get("camera", 0)}, func(_r): Game.show_menu())
