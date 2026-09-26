extends "res://scripts/foliage_occluder.gd"

## Bush variants pre-rendered from Quaternius' Stylized Nature MegaKit (CC0)
## through tools/render_sprite.py, at the same pixel density as the dead
## trees. Scaled from true model size (bushes x1.9, the big plant x1.2, the
## fern x0.41 since it's authored far larger than the rest of the pack) so
## each is about the old 50px placeholder and still big enough to hide in.

## offset: where the ground point lands relative to the texture center,
## -center_y * 27.108 px/unit. Bushes/fern: 112x112 renders, center_y 0.555.
## Big plant: 120x120, center_y 1.873.
const BUSH_OFFSET := Vector2(0, -15.04)
const BIG_PLANT_OFFSET := Vector2(0, -50.77)
const SPRITE_SCALE := 0.5

## hide_rect: node-local area counting as "inside the bush", from each
## model's projected bounds.
const VARIANTS := [
	{"albedo": "res://assets/sprites/bush/bush_55deg_albedo.png",
	 "normal": "res://assets/sprites/bush/bush_55deg_normal.png",
	 "offset": BUSH_OFFSET, "hide_rect": Rect2(-24, -33, 50, 48)},
	{"albedo": "res://assets/sprites/bush/bush_flowers_55deg_albedo.png",
	 "normal": "res://assets/sprites/bush/bush_flowers_55deg_normal.png",
	 "offset": BUSH_OFFSET, "hide_rect": Rect2(-24, -33, 50, 48)},
	{"albedo": "res://assets/sprites/bush/fern_55deg_albedo.png",
	 "normal": "res://assets/sprites/bush/fern_55deg_normal.png",
	 "offset": BUSH_OFFSET, "hide_rect": Rect2(-25, -21, 51, 39)},
	{"albedo": "res://assets/sprites/bush/plant_big_2_55deg_albedo.png",
	 "normal": "res://assets/sprites/bush/plant_big_2_55deg_normal.png",
	 "offset": BIG_PLANT_OFFSET, "hide_rect": Rect2(-23, -52, 48, 50)},
]


## Map theme (map_generator.gd): NatureCatalog bush families this map's
## bushes come from; empty = the original four. Set before it enters the tree.
var families: Array = []


func _ready() -> void:
	super()
	var pool: Array = NatureCatalog.of_families(NatureCatalog.BUSHES, families) if not families.is_empty() else VARIANTS
	if pool.is_empty():
		pool = VARIANTS
	var variant: Dictionary = pool.pick_random()

	var tex := CanvasTexture.new()
	tex.diffuse_texture = Art.tex(variant.albedo)
	tex.normal_texture = Art.tex(variant.normal)
	var sprite: Sprite2D = visual
	sprite.texture = tex
	Art.place(sprite, variant.offset, SPRITE_SCALE)

	# Per instance: a .tscn shape resource would be shared by every bush.
	var rect: Rect2 = variant.hide_rect
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = area.get_node("CollisionShape2D")
	collision.shape = shape
	collision.position = rect.get_center()
