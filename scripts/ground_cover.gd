extends Sprite2D

## Purely decorative ground plants (no collision, no hiding) scattered by
## map_generator.gd. Rendered from Quaternius' Stylized Nature MegaKit (CC0)
## via tools/render_sprite.py (settings recorded in its docstring). Never
## flipped for variety: flip_h mirrors the texture but not the normal map's
## X channel, which would light them from the wrong side.

const SPRITE_SCALE := 0.5

## offset: where the ground point sits relative to the texture center.
## Clovers: 48x48 canvas, center_y 0.651. Everything else: 64x64,
## center_y 0.635. Both at 27.108 px/unit, so offset.y = -center_y * 27.108.
const CLOVER_OFFSET := Vector2(0, -17.65)
const FLOWER_OFFSET := Vector2(0, -17.21)

## Picked kind-first, then variant, so kinds with many models (five petal
## cards) don't crowd out kinds with fewer.
const KINDS := {
	"clover": ["clover_1", "clover_2"],
	"flower_group": ["flower_group_1", "flower_group_2"],
	"flower_single": ["flower_single_1", "flower_single_2"],
	"flower_petal": ["flower_petal_1", "flower_petal_2", "flower_petal_3", "flower_petal_4", "flower_petal_5"],
	"grass": ["grass_wispy", "grass_wispy_2", "grass"],
	"mushroom": ["mushroom", "mushroom_laetiporus"],
	"pebble": ["pebble_round", "pebble_round_2", "pebble_round_3", "pebble_round_4", "pebble_round_5",
		"pebble_square", "pebble_square_2", "pebble_square_3", "pebble_square_4", "pebble_square_5", "pebble_square_6"],
}

const TEXTURES := {
	"clover_1": [preload("res://assets/sprites/ground_cover/clover_1_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/clover_1_55deg_normal.png")],
	"clover_2": [preload("res://assets/sprites/ground_cover/clover_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/clover_2_55deg_normal.png")],
	"flower_group_1": [preload("res://assets/sprites/ground_cover/flower_group_1_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_group_1_55deg_normal.png")],
	"flower_group_2": [preload("res://assets/sprites/ground_cover/flower_group_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_group_2_55deg_normal.png")],
	"flower_single_1": [preload("res://assets/sprites/ground_cover/flower_single_1_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_single_1_55deg_normal.png")],
	"flower_single_2": [preload("res://assets/sprites/ground_cover/flower_single_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_single_2_55deg_normal.png")],
	"flower_petal_1": [preload("res://assets/sprites/ground_cover/flower_petal_1_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_petal_1_55deg_normal.png")],
	"flower_petal_2": [preload("res://assets/sprites/ground_cover/flower_petal_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_petal_2_55deg_normal.png")],
	"flower_petal_3": [preload("res://assets/sprites/ground_cover/flower_petal_3_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_petal_3_55deg_normal.png")],
	"flower_petal_4": [preload("res://assets/sprites/ground_cover/flower_petal_4_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_petal_4_55deg_normal.png")],
	"flower_petal_5": [preload("res://assets/sprites/ground_cover/flower_petal_5_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/flower_petal_5_55deg_normal.png")],
	"grass_wispy": [preload("res://assets/sprites/ground_cover/grass_wispy_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/grass_wispy_55deg_normal.png")],
	"grass_wispy_2": [preload("res://assets/sprites/ground_cover/grass_wispy_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/grass_wispy_2_55deg_normal.png")],
	"grass": [preload("res://assets/sprites/ground_cover/grass_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/grass_55deg_normal.png")],
	"mushroom": [preload("res://assets/sprites/ground_cover/mushroom_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/mushroom_55deg_normal.png")],
	"mushroom_laetiporus": [preload("res://assets/sprites/ground_cover/mushroom_laetiporus_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/mushroom_laetiporus_55deg_normal.png")],
	"pebble_round": [preload("res://assets/sprites/ground_cover/pebble_round_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_round_55deg_normal.png")],
	"pebble_square": [preload("res://assets/sprites/ground_cover/pebble_square_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_square_55deg_normal.png")],
	"pebble_square_2": [preload("res://assets/sprites/ground_cover/pebble_square_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_square_2_55deg_normal.png")],
	"pebble_square_3": [preload("res://assets/sprites/ground_cover/pebble_square_3_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_square_3_55deg_normal.png")],
	"pebble_square_4": [preload("res://assets/sprites/ground_cover/pebble_square_4_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_square_4_55deg_normal.png")],
	"pebble_square_5": [preload("res://assets/sprites/ground_cover/pebble_square_5_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_square_5_55deg_normal.png")],
	"pebble_square_6": [preload("res://assets/sprites/ground_cover/pebble_square_6_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_square_6_55deg_normal.png")],
	"pebble_round_2": [preload("res://assets/sprites/ground_cover/pebble_round_2_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_round_2_55deg_normal.png")],
	"pebble_round_3": [preload("res://assets/sprites/ground_cover/pebble_round_3_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_round_3_55deg_normal.png")],
	"pebble_round_4": [preload("res://assets/sprites/ground_cover/pebble_round_4_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_round_4_55deg_normal.png")],
	"pebble_round_5": [preload("res://assets/sprites/ground_cover/pebble_round_5_55deg_albedo.png"), preload("res://assets/sprites/ground_cover/pebble_round_5_55deg_normal.png")],
}


func _ready() -> void:
	var kind: String = KINDS.keys().pick_random()
	var variant: String = KINDS[kind].pick_random()
	var tex := CanvasTexture.new()
	tex.diffuse_texture = TEXTURES[variant][0]
	tex.normal_texture = TEXTURES[variant][1]
	texture = tex
	offset = CLOVER_OFFSET if kind == "clover" else FLOWER_OFFSET
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
