extends Sprite2D

## Purely decorative ground plants (no collision, no hiding) scattered by
## map_generator.gd. Rendered from Quaternius' Stylized Nature MegaKit (CC0)
## via tools/render_sprite.py: clovers and loose petals x1.5, flower groups
## at true size. Never flipped for variety: flip_h mirrors the texture but
## not the normal map's X channel, which would light them from the wrong side.

const SPRITE_SCALE := 0.5

## offset: where the ground point sits relative to the texture center.
## Clovers: 48x48 canvas, center_y 0.651. Flowers: 64x64, center_y 0.635.
## Both at 27.108 px/unit, so offset.y = -center_y * 27.108.
const CLOVER_OFFSET := Vector2(0, -17.65)
const FLOWER_OFFSET := Vector2(0, -17.21)

const VARIANTS := [
	{"albedo": preload("res://assets/sprites/ground_cover/clover_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/clover_1_55deg_normal.png"),
	 "offset": CLOVER_OFFSET},
	{"albedo": preload("res://assets/sprites/ground_cover/clover_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/clover_2_55deg_normal.png"),
	 "offset": CLOVER_OFFSET},
	{"albedo": preload("res://assets/sprites/ground_cover/flower_group_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/flower_group_1_55deg_normal.png"),
	 "offset": FLOWER_OFFSET},
	{"albedo": preload("res://assets/sprites/ground_cover/flower_group_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/flower_group_2_55deg_normal.png"),
	 "offset": FLOWER_OFFSET},
	{"albedo": preload("res://assets/sprites/ground_cover/flower_petal_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/flower_petal_1_55deg_normal.png"),
	 "offset": FLOWER_OFFSET},
	{"albedo": preload("res://assets/sprites/ground_cover/flower_petal_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/flower_petal_2_55deg_normal.png"),
	 "offset": FLOWER_OFFSET},
	{"albedo": preload("res://assets/sprites/ground_cover/flower_petal_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/flower_petal_3_55deg_normal.png"),
	 "offset": FLOWER_OFFSET},
]


func _ready() -> void:
	var variant: Dictionary = VARIANTS[randi() % VARIANTS.size()]
	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.albedo
	tex.normal_texture = variant.normal
	texture = tex
	offset = variant.offset
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
