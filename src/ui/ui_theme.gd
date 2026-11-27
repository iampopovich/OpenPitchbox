class_name UiTheme
extends RefCounted
## Shared look for menus and HUD.

const BG := Color("0b1220")
const PANEL := Color("111c2e")
const ACCENT := Color("22c55e")
const ACCENT2 := Color("facc15")
const TEXT := Color("e5e7eb")
const MUTED := Color("94a3b8")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PANEL, 0.94)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(16)
	panel.border_color = Color("1f2d44")
	panel.set_border_width_all(2)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("1e293b")
	btn.set_corner_radius_all(8)
	btn.set_content_margin_all(10)
	btn.content_margin_left = 22
	btn.content_margin_right = 22
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color("334155")
	var focus := btn.duplicate() as StyleBoxFlat
	focus.bg_color = Color("14532d")
	focus.border_color = ACCENT
	focus.set_border_width_all(3)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("166534")
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("0f172a")
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("475569"))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "LineEdit", btn)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "OptionButton", btn)
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("1e293b")
	bar_bg.set_corner_radius_all(4)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = ACCENT2
	bar_fg.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	_theme = t
	return t


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String) -> Label:
	var l := label(text, 44, Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color("052e16"))
	return l


static func button(text: String, cb: Callable, min_w: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 48)
	b.pressed.connect(cb)
	return b


static func chip(c: Color, size: Vector2 = Vector2(18, 18)) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = size
	return r


static func stars_text(s: float) -> String:
	var full := int(floor(s))
	var half := s - full >= 0.5
	var out := ""
	for i in full:
		out += "★"
	if half:
		out += "½"
	return out
