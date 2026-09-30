class_name DroppedItem
extends Node2D

## User request (for multiplayer to come): things from the bag can be put
## down on the ground - lures, batteries, spare gear - for a teammate (or
## yourself) to pick up again. Fish put down are DroppedFish (they rot,
## and the big ghost goes for them); this is everything else. It sits
## where it was left, its picture and name over it, and the player
## standing by it is offered 撿起 (Player.interaction()).

const PICK_RANGE := 34.0
const ICON_SIZE := 30.0

var item_id := ""
var count := 1
var _t := 0.0
var _sprite: Sprite2D
var _label: Label


static func make(id: String, n: int) -> DroppedItem:
	var d := DroppedItem.new()
	d.item_id = id
	d.count = n
	return d


func _ready() -> void:
	add_to_group("dropped_items")
	_sprite = Sprite2D.new()
	_sprite.texture = Items.icon(item_id)
	if _sprite.texture != null:
		var t := _sprite.texture
		_sprite.scale = Vector2.ONE * ICON_SIZE / maxf(t.get_width(), t.get_height()) * (1.6 if t.get_width() > t.get_height() * 2 else 1.0)
	_sprite.rotation = randf_range(-0.4, 0.4)
	add_child(_sprite)
	_label = Label.new()
	_label.text = title()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-40, -30)
	_label.size = Vector2(80, 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func title() -> String:
	return Items.name_of(item_id) + (" ×%d" % count if count > 1 else "")


func _process(delta: float) -> void:
	# A slow glint so it can be found in the dark.
	_t += delta
	_sprite.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.3, 1.0), (sin(_t * 2.5) + 1.0) * 0.25)


func pick_up() -> Dictionary:
	remove_from_group("dropped_items")
	queue_free()
	return {"id": item_id, "count": count}
