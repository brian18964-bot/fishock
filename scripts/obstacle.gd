extends StaticBody2D

## Rock obstacles pre-rendered from Quaternius' Stylized Nature MegaKit (CC0)
## via tools/render_sprite.py, all x1.45 so they're about the old 60px
## placeholder box; boulders from Quaternius' nature collection, x3.5 (that
## pack's rocks are pebble-sized) to land in the same size range. One variant per obstacle each run; collision and the
## light occluder are an octagon fitted to that rock's measured ground
## footprint, so it blocks movement and casts its shadow from its base.

const SPRITE_SCALE := 0.5

## offset: ground point relative to the texture center, (center_x, -center_y)
## * 27.108.
## footprint: the rock's base in node-local px (from the model's bottom
## quarter, depth foreshortened by sin 55deg).
const VARIANTS := [
	{"albedo": "res://assets/sprites/rock/rock_medium_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/rock_medium_55deg_normal.png",
	 "offset": Vector2(0, -18.16), "footprint": Rect2(-34, -19, 60, 40)},
	{"albedo": "res://assets/sprites/rock/rock_medium_2_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/rock_medium_2_55deg_normal.png",
	 "offset": Vector2(0, -20.33), "footprint": Rect2(-32.7, -26.1, 65.4, 52.2)},
	{"albedo": "res://assets/sprites/rock/rock_medium_3_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/rock_medium_3_55deg_normal.png",
	 "offset": Vector2(0, -20.33), "footprint": Rect2(-31.3, -24.1, 62.6, 48.2)},
	{"albedo": "res://assets/sprites/rock/boulder_1_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/boulder_1_55deg_normal.png",
	 "offset": Vector2(-1.55, -17.81), "footprint": Rect2(-16.1, -17.2, 32.2, 34.5)},
	{"albedo": "res://assets/sprites/rock/boulder_2_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/boulder_2_55deg_normal.png",
	 "offset": Vector2(0.0, -18.76), "footprint": Rect2(-25.0, -20.9, 50.0, 41.8)},
	{"albedo": "res://assets/sprites/rock/boulder_3_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/boulder_3_55deg_normal.png",
	 "offset": Vector2(3.96, -21.96), "footprint": Rect2(-16.9, -17.4, 33.9, 34.9)},
	{"albedo": "res://assets/sprites/rock/boulder_4_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/boulder_4_55deg_normal.png",
	 "offset": Vector2(1.36, -33.72), "footprint": Rect2(-19.7, -15.8, 39.4, 31.6)},
	{"albedo": "res://assets/sprites/rock/boulder_5_55deg_albedo.png",
	 "normal": "res://assets/sprites/rock/boulder_5_55deg_normal.png",
	 "offset": Vector2(0.0, -24.15), "footprint": Rect2(-30.6, -25.6, 61.2, 51.2)},
]

## Plus the user's packs (NatureCatalog.ROCKS), after these.
static var _all: Array = []


static func variants() -> Array:
	if _all.is_empty():
		_all = VARIANTS + NatureCatalog.ROCKS
	return _all


## A theme's rock pool: VARIANTS indices, and/or NatureCatalog rock family
## names standing for every rock of that family.
static func resolve_pool(pool: Array) -> Array:
	var out := []
	var all := variants()
	for entry in pool:
		if entry is String:
			for i in range(VARIANTS.size(), all.size()):
				if all[i].family == entry:
					out.append(i)
		else:
			out.append(entry)
	return out


@onready var sprite: Sprite2D = $Visual
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var occluder: LightOccluder2D = $LightOccluder2D


## Map theme (map_generator.gd): VARIANTS indices and/or catalog rock
## families to choose from (resolve_pool). Empty = any of VARIANTS. Set
## before the rock enters the tree.
var variant_pool: Array = []


func _ready() -> void:
	var pool := resolve_pool(variant_pool)
	apply_variant(pool.pick_random() if not pool.is_empty() else randi() % VARIANTS.size())


func apply_variant(index: int) -> void:
	var variant: Dictionary = variants()[index]

	var tex := CanvasTexture.new()
	tex.diffuse_texture = Art.tex(variant.albedo)
	tex.normal_texture = Art.tex(variant.normal)
	sprite.texture = tex
	Art.place(sprite, variant.offset, SPRITE_SCALE)

	var outline := _octagon(variant.footprint)
	collision.polygon = outline
	# User request: shadows take the rock's own shape (SilhouetteShadow)
	# instead of a wedge extruded from its footprint.
	occluder.occluder = null
	SilhouetteShadow.attach(self, sprite)


func _octagon(r: Rect2) -> PackedVector2Array:
	var c := r.get_center()
	var e := r.size / 2.0
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		pts.append(c + Vector2(cos(a) * e.x, sin(a) * e.y))
	return pts
