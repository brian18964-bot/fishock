class_name MenuStyle
extends RefCounted

## The menus' shared helpers - now wearing the UI kit (UiKit: iron and gold
## frames, red and gray buttons, the kai font). Kept so older pages and
## dialogs read the same; new code uses UiKit directly.

const GOLD := UiKit.GOLD
const TEXT := UiKit.TEXT
const DIM := UiKit.DIM
const PANEL := Color(0.05, 0.05, 0.06, 0.92)
const EDGE := Color(0.62, 0.46, 0.17, 0.8)


static func box(bg := PANEL, edge := EDGE, radius := 6, border := 1) -> StyleBoxFlat:
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


static func panel(_bg := PANEL) -> PanelContainer:
	return UiKit.panel()


static func label(text: String, size := 16, color := TEXT) -> Label:
	return UiKit.label(text, size, color)


## A button: `main` ones red lacquer, the rest gray.
static func button(text: String, size := 18, main := false) -> Button:
	return UiKit.button(text, size, "red" if main else "gray")


## A small modal notice (e.g. "coming soon"): a titled window, a few lines,
## OK. Its column (for callers adding buttons) is get_child(0).get_child(0).
static func notice(parent: Node, title: String, lines: Array) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var made := UiKit.window(title)
	var p: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	p.custom_minimum_size = Vector2(440, 0)
	col.add_theme_constant_override("separation", 10)
	for line in lines:
		var l := UiKit.label(str(line), 16, TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		col.add_child(l)
	var ok := button("知道了", 16)
	ok.custom_minimum_size = Vector2(140, 42)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(shade.queue_free)
	col.add_child(ok)
	shade.add_child(p)
	# Centred on the screen (grows both ways as buttons are added).
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return shade
