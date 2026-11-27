class_name Screen
extends Control
## Base for menu screens: background, title row, scrollable content, keyboard/gamepad friendly.

var content: VBoxContainer
var header: HBoxContainer
var footer: HBoxContainer


func _init() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)


func base(title_text: String, subtitle: String = "", column_w: float = 720.0) -> void:
	## Layout: centred title block on top, one centred content column (fixed reading width,
	## vertically centred when it is short, scrolls when it is long) and a centred action bar
	## pinned to the bottom: Back on the left, the primary action on the right.
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	margin.add_child(outer)
	header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	var t := UiTheme.title(title_text)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(t)
	if subtitle != "":
		var s := UiTheme.label(subtitle, 20, UiTheme.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titles.add_child(s)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(wrap)
	# keep the wrapper as tall as the viewport so a short column sits in the middle
	scroll.resized.connect(func(): wrap.custom_minimum_size.y = scroll.size.y)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.custom_minimum_size = Vector2(column_w, 0)
	content.add_theme_constant_override("separation", 10)
	wrap.add_child(content)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	outer.add_child(footer)
	_tidy.call_deferred()


func _tidy() -> void:
	## Plain text placed straight into the column is centred and wraps inside it.
	for c in content.get_children():
		if c is Label and not c.has_meta("keep_align"):
			(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Back always sits on the left of the action bar, the primary action on the right
	for c in footer.get_children():
		if c is Button and (c as Button).text in ["Back", "Cancel"]:
			footer.move_child(c, 0)


static func section(text: String) -> Control:
	## Section heading: centred caption between two hairlines.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.custom_minimum_size = Vector2(0, 40)
	for i in 3:
		if i == 1:
			var l := UiTheme.label(text.to_upper(), 18, UiTheme.ACCENT2)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(l)
		else:
			var line := ColorRect.new()
			line.color = Color("334155")
			line.custom_minimum_size = Vector2(0, 1)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(line)
	return h


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


static func cycler(label: String, values: Array, index: int, on_change: Callable, min_w: float = 0.0) -> Button:
	## A settings row: name on the left, ◂ value ▸ on the right, full column width.
	## Enter/A = next, Left/Right = previous/next.
	var b := Button.new()
	b.custom_minimum_size = Vector2(min_w, UiTheme.button_h())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if min_w <= 0.0 else Control.SIZE_SHRINK_CENTER
	b.set_meta("i", clampi(index, 0, values.size() - 1))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var name_l := UiTheme.label(label, 21, UiTheme.MUTED)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var val_l := UiTheme.label("", 21, UiTheme.TEXT)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for l: Label in [name_l, val_l]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
	# inner padding matches the button style
	row.offset_left = 22
	row.offset_right = -22
	var refresh := func():
		val_l.text = "◂  %s  ▸" % str(values[b.get_meta("i")])
		b.tooltip_text = "%s: %s" % [label, str(values[b.get_meta("i")])]
	refresh.call()
	b.focus_entered.connect(func(): name_l.add_theme_color_override("font_color", Color.WHITE))
	b.focus_exited.connect(func(): name_l.add_theme_color_override("font_color", UiTheme.MUTED))
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
