extends Sprite2D

## Purely decorative ground plants (no collision, no hiding) scattered by
## map_generator.gd. Clover renders from Quaternius' Stylized Nature MegaKit
## (CC0) via tools/render_sprite.py, scaled x1.5 so they read at game size.
## Never flipped for variety: flip_h mirrors the texture but not the normal
## map's X channel, which would light them from the wrong side.

## Ground point in the 48x48 renders (center_y 0.651 units, 27.108 px/unit).
const SPRITE_OFFSET := Vector2(0, -17.65)
const SPRITE_SCALE := 0.5

const VARIANTS := [
	{"albedo": preload("res://assets/sprites/ground_cover/clover_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/clover_1_55deg_normal.png")},
	{"albedo": preload("res://assets/sprites/ground_cover/clover_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/ground_cover/clover_2_55deg_normal.png")},
]


func _ready() -> void:
	var variant: Dictionary = VARIANTS[randi() % VARIANTS.size()]
	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.albedo
	tex.normal_texture = variant.normal
	texture = tex
	offset = SPRITE_OFFSET
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
