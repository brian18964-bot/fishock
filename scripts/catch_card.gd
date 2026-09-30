class_name CatchCard
extends CanvasLayer

## User request: the fish need a look of their own - landing one shows it:
## a card with its picture (FishData.icon), its name, size and value, a
## legend's name in gold. It rises in, holds a moment and fades.
## User request (playtest): up near the top, see-through enough to watch
## the water behind it, gone sooner - and showing the catch's length,
## weight and tank trait.
## User request (HUD): in the clear space over the right stick, with tags -
## NEW for a first catch of its kind or a trait not seen on it before,
## BIGGER for a new record size.

const HOLD := 1.3
const LEGEND_GOLD := Color(1.0, 0.82, 0.35)

var _panel: PanelContainer
var _pic: TextureRect
var _name: Label
var _info: Label
var _measure: Label
var _tags: HBoxContainer
var _tween: Tween


func _init() -> void:
	layer = 7


func _ready() -> void:
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.05, 0.6)
	box.border_color = Color(1.0, 0.85, 0.55, 0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_pic = TextureRect.new()
	_pic.custom_minimum_size = Vector2(120, 60)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_pic)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_measure = Label.new()
	_measure.add_theme_font_size_override("font_size", 13)
	_measure.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_measure.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(_name)
	_tags = HBoxContainer.new()
	_tags.add_theme_constant_override("separation", 4)
	_tags.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_tags)
	text.add_child(head)
	text.add_child(_info)
	text.add_child(_measure)
	row.add_child(text)
	_panel.add_child(row)
	_panel.modulate.a = 0.0
	add_child(_panel)


func show_catch(fish: Dictionary, legend: bool) -> void:
	var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
	if tex == null:
		return
	_pic.texture = tex
	_name.text = fish.get("name", "魚")
	_name.add_theme_color_override("font_color", LEGEND_GOLD if legend else Color.WHITE)
	var size: String = Inventory.SIZE_NAMES.get(fish.get("size", "small"), "")
	_info.text = "%s%s型・價值 %.0f" % ["傳說・" if legend else "", size, float(fish.get("value", 0.0))]
	var extra := FishData.size_text(fish)
	if fish.has("tank_trait"):
		extra += "・" + FishData.trait_name(fish.tank_trait)
	_measure.text = extra
	_measure.visible = extra != ""
	for c in _tags.get_children():
		c.free()
	if fish.get("is_new", false):
		_tags.add_child(_tag("NEW", Color(0.35, 0.8, 0.45)))
	elif fish.get("new_trait", false):
		_tags.add_child(_tag("NEW 特性", Color(0.35, 0.7, 0.9)))
	if fish.get("bigger", false):
		_tags.add_child(_tag("BIGGER", Color(0.95, 0.6, 0.2)))
	_panel.reset_size()
	var view := get_viewport().get_visible_rect().size
	# Right-aligned over the right stick (under the energy panel).
	var at := Vector2(view.x - _panel.size.x - 12.0, view.y * 0.2)
	if _tween != null:
		_tween.kill()
	_panel.position = at + Vector2(0, 16)
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "position", at, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3)


## A small coloured badge (NEW, BIGGER).
static func _tag(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(4)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", box)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
	p.add_child(l)
	return p
