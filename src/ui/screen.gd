class_name Screen
extends Control
## Base for menu screens: background, title row, scrollable content, keyboard/gamepad friendly.

var content: VBoxContainer
var header: HBoxContainer
var footer: HBoxContainer


func _init() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)


func base(title_text: String, subtitle: String = "") -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	outer.add_child(header)
	header.add_child(UiTheme.title(title_text))
	if subtitle != "":
		var s := UiTheme.label(subtitle, 22, UiTheme.MUTED)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		header.add_child(s)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	outer.add_child(footer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	Game.show_menu()


func focus_first() -> void:
	var b := _find_focusable(self)
	if b:
		b.grab_focus.call_deferred()


func _find_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).visible:
			return c
		var r := _find_focusable(c)
		if r:
			return r
	return null


static func cycler(label: String, values: Array, index: int, on_change: Callable, min_w: float = 420.0) -> Button:
	## A button that cycles through values (Enter/A = next, Left/Right = prev/next).
	var b := Button.new()
	b.custom_minimum_size = Vector2(min_w, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("i", clampi(index, 0, values.size() - 1))
	var refresh := func():
		b.text = "%s:  ◂ %s ▸" % [label, str(values[b.get_meta("i")])]
	refresh.call()
	var step := func(d: int):
		var i: int = (int(b.get_meta("i")) + d + values.size()) % values.size()
		b.set_meta("i", i)
		refresh.call()
		on_change.call(i)
	b.pressed.connect(func(): step.call(1))
	b.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event()
		elif e.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event())
	return b


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func cell(text: String, w: float, color: Color = UiTheme.TEXT, size: int = 20, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UiTheme.label(text, size, color)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = align
	l.clip_text = true
	return l
