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
var _glow: TextureRect
var _pic: FishSlot
var _kicker: Label
var _name: Label
var _info: Label
var _measure: Label
var _tags: HBoxContainer
var _tween: Tween


func _init() -> void:
	layer = 7


## Dressed as an MMO's loot toast (user request): a dark frame, the fish in
## a slot ringed by its rarity, its name in that colour; a legend glows.
func _ready() -> void:
	_glow = TextureRect.new()
	_glow.texture = UiKit.glow()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate = Color(1.0, 0.55, 0.12, 0.0)
	add_child(_glow)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.frame_box(true))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.self_modulate = Color(1, 1, 1, 0.9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_pic = FishSlot.new()
	_pic.custom_minimum_size = Vector2(64, 64)
	_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pic)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	_kicker = UiKit.label("", 12, UiKit.GOLD)
	text.add_child(_kicker)
	_name = UiKit.label("", 21, Color.WHITE, true, 4)
	_info = UiKit.label("", 13, UiKit.TEXT)
	_measure = UiKit.label("", 13, UiKit.USE)
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
	var shown := fish.duplicate()
	if legend:
		shown["legend"] = true
	var rarity := UiKit.fish_rarity(shown)
	_pic.fish = shown
	_pic.queue_redraw()
	_name.text = fish.get("name", "魚")
	_name.add_theme_color_override("font_color", UiKit.rarity_color(rarity))
	_kicker.text = "傳說漁獲！" if rarity == "legend" else ("%s漁獲" % UiKit.rarity_name(rarity))
	_kicker.add_theme_color_override("font_color", UiKit.rarity_color(rarity) if rarity != "common" else UiKit.DIM)
	var size: String = Inventory.SIZE_NAMES.get(fish.get("size", "small"), "")
	_info.text = "%s型・價值 %.0f" % [size, float(fish.get("value", 0.0))]
	var extra := FishData.size_text(fish)
	if fish.has("tank_trait"):
		extra += "・" + FishData.trait_name(fish.tank_trait)
	_measure.text = extra
	_measure.visible = extra != ""
	for c in _tags.get_children():
		c.free()
	if fish.get("is_new", false):
		_tags.add_child(_tag("NEW", Color(0.3, 0.78, 0.35)))
	elif fish.get("new_trait", false):
		_tags.add_child(_tag("NEW 特性", Color(0.35, 0.65, 0.95)))
	if fish.get("bigger", false):
		_tags.add_child(_tag("BIGGER", Color(0.95, 0.55, 0.18)))
	_panel.reset_size()
	var view := get_viewport().get_visible_rect().size
	# Right-aligned over the right stick (under the energy panel).
	var at := Vector2(view.x - _panel.size.x - 10.0, view.y * 0.2)
	if _tween != null:
		_tween.kill()
	_panel.position = at + Vector2(0, 16)
	_panel.modulate.a = 0.0
	_glow.size = _panel.size * Vector2(1.4, 2.2)
	_glow.position = at + _panel.size * 0.5 - _glow.size * 0.5
	_glow.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "position", at, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)
	if rarity == "legend":
		_tween.parallel().tween_property(_glow, "modulate:a", 0.55, 0.3)
	_tween.tween_interval(HOLD + (1.2 if rarity == "legend" else 0.0))
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	_tween.parallel().tween_property(_glow, "modulate:a", 0.0, 0.3)


## A small plaque (NEW, BIGGER).
static func _tag(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = col.darkened(0.25)
	box.border_color = col.lightened(0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", box)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(UiKit.label(text, 11, Color.WHITE, true, 3))
	return p


## The fish in a slot ringed by its rarity.
class FishSlot extends Control:
	var fish := {}

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_slot(self, r, UiKit.fish_rarity(fish))
		var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
		if tex == null:
			return
		var room := r.grow(-5.0)
		var k := minf(room.size.x / tex.get_width(), room.size.y / tex.get_height())
		var sz := Vector2(tex.get_size()) * k
		draw_texture_rect(tex, Rect2(room.get_center() - sz / 2.0, sz), false)
