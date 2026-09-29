class_name MenuStyle
extends RefCounted

## The menus' look (main screen, equipment, dialogs): dark panels with a
## warm brass edge, like the in-game backpack and cards.

const GOLD := Color(1.0, 0.82, 0.4)
const TEXT := Color(0.95, 0.93, 0.88)
const DIM := Color(0.72, 0.72, 0.76)
const PANEL := Color(0.07, 0.065, 0.06, 0.88)
const EDGE := Color(1.0, 0.82, 0.5, 0.55)


static func box(bg := PANEL, edge := EDGE, radius := 10, border := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func panel(bg := PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg))
	return p


static func label(text: String, size := 16, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A button: `main` ones big and warm, the rest dark with a brass edge.
static func button(text: String, size := 18, main := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var base := Color(0.62, 0.36, 0.12, 0.95) if main else Color(0.1, 0.095, 0.09, 0.9)
	var edge := Color(1.0, 0.85, 0.5, 0.9) if main else EDGE
	b.add_theme_stylebox_override("normal", box(base, edge, 12, 2 if main else 1))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.12), edge, 12, 2 if main else 1))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.2), edge, 12, 2 if main else 1))
	b.add_theme_stylebox_override("disabled", box(Color(0.1, 0.1, 0.1, 0.6), Color(1, 1, 1, 0.15), 12))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return b


## A small modal notice (e.g. "coming soon"): a title, a few lines, OK.
static func notice(parent: Node, title: String, lines: Array) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var p := panel(Color(0.08, 0.075, 0.07, 0.97))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(420, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.add_child(label(title, 22, GOLD))
	for line in lines:
		var l := label(str(line), 15, DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 390
		col.add_child(l)
	var ok := button("知道了", 16)
	ok.pressed.connect(shade.queue_free)
	col.add_child(ok)
	p.add_child(col)
	shade.add_child(p)
	p.position = -p.get_combined_minimum_size() / 2.0
	return shade
