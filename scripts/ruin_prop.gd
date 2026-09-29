class_name RuinProp
extends StaticBody2D

## User request: a ruined town. One of its buildings, wrecked cars, street
## furniture or bits of junk (RuinsCatalog - tools/render_ruins.py): solid
## where its base stands (the footprint outline from the render), casting
## its own silhouette as a shadow, and - if it's tall enough to hide the
## player - fading while they're behind it, like a tree's canopy. Placed by
## TownBuilder; `entry` is set before it enters the tree.

const SPRITE_SCALE := 0.5
## Kinds big enough to hide someone behind them (not the thin lamps,
## poles and signs - fewer areas to check on a phone).
const FADES := ["building", "wreck"]

var entry: Dictionary = {}

var sprite: Sprite2D


func _ready() -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = Art.tex(entry.albedo)
	tex.normal_texture = Art.tex(entry.normal)
	var canopy := Node2D.new()
	canopy.name = "Canopy"
	sprite = Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = tex
	Art.place(sprite, entry.offset, SPRITE_SCALE)
	canopy.add_child(sprite)
	if entry.kind in FADES:
		var area := Area2D.new()
		area.name = "Area2D"
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var fade: Rect2 = entry.fade
		rect.size = fade.size
		shape.shape = rect
		shape.position = fade.get_center()
		area.add_child(shape)
		canopy.add_child(area)
		canopy.set_script(preload("res://scripts/foliage_occluder.gd"))
	add_child(canopy)
	var body := CollisionPolygon2D.new()
	body.polygon = PackedVector2Array(entry.footprint)
	add_child(body)
	SilhouetteShadow.attach(self, sprite)


## Its base, in world space (for keeping things apart).
func base_rect() -> Rect2:
	var r := RuinProp.footprint_rect(entry)
	return Rect2(r.position + position, r.size)


## The bounding box of an entry's footprint, relative to its origin.
static func footprint_rect(e: Dictionary) -> Rect2:
	var pts: Array = e.footprint
	var r := Rect2(pts[0] as Vector2, Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
