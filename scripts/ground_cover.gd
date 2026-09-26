extends Sprite2D

## Purely decorative ground plants (no collision, no hiding) scattered by
## map_generator.gd. Rendered from Quaternius' Stylized Nature MegaKit (CC0)
## via tools/render_sprite.py (settings recorded in its docstring). Never
## flipped for variety: flip_h mirrors the texture but not the normal map's
## X channel, which would light them from the wrong side.

const SPRITE_SCALE := 0.5

## offset: where the ground point sits relative to the texture center,
## -center_y * 27.108 px/unit. Clovers: 48x48 canvas, center_y 0.651. Path
## stones: 48x48 or 64x64, center_y 0 (flat, centered). Everything else:
## 64x64, center_y 0.635.
const DEFAULT_OFFSET := Vector2(0, -17.21)
const KIND_OFFSETS := {
	"clover": Vector2(0, -17.65),
	"path_stone": Vector2.ZERO,
}
## Models from Quaternius' nature collections, each with its own tight
## camera: (center_x, -center_y) * 27.108. Checked before KIND_OFFSETS.
const VARIANT_OFFSETS := {
	"shrub": Vector2(0.41, -3.01),
	"shrub_flowers": Vector2(0.41, -3.55),
	"flower_bush_1": Vector2(-0.22, -8.0),
	"flower_bush_2": Vector2(-0.08, -2.36),
	"flower_bush_3": Vector2(-0.08, -2.77),
	"flower_petal_6": Vector2(0.54, -0.87),
	"flower_single_3": Vector2(-0.16, -9.49),
	"flower_single_4": Vector2(5.37, -8.57),
	"flower_clump_1": Vector2(-0.22, -16.05),
	"flower_clump_2": Vector2(1.6, -8.81),
	"flower_clump_3": Vector2(1.6, -8.81),
	"flower_clump_4": Vector2(1.6, -8.81),
	"flower_clump_5": Vector2(1.6, -8.81),
	"grass_large": Vector2(0.98, -10.55),
	"grass_small": Vector2(-0.81, -6.02),
}

## Picked kind-first, then variant, so kinds with many models (five petal
## cards) don't crowd out kinds with fewer.
const KINDS := {
	"clover": ["clover_1", "clover_2"],
	"flower_group": ["flower_group_1", "flower_group_2"],
	"flower_single": ["flower_single_1", "flower_single_2", "flower_single_3", "flower_single_4"],
	"flower_clump": ["flower_clump_1", "flower_clump_2", "flower_clump_3", "flower_clump_4", "flower_clump_5"],
	"flower_petal": ["flower_petal_1", "flower_petal_2", "flower_petal_3", "flower_petal_4", "flower_petal_5", "flower_petal_6"],
	"grass": ["grass_wispy", "grass_wispy_2", "grass", "tall_grass", "grass_large", "grass_small"],
	"mushroom": ["mushroom", "mushroom_laetiporus"],
	"shrub": ["shrub", "shrub_flowers"],
	"flower_bush": ["flower_bush_1", "flower_bush_2", "flower_bush_3"],
	"plant": ["plant_1", "plant_2", "plant_big_1"],
	"path_stone": ["rock_path_1", "rock_path_2", "rock_path_3",
		"rock_path_square_1", "rock_path_square_2", "rock_path_square_3", "rock_path_round_thin", "rock_path_round_wide",
		"rock_path_square_thin", "rock_path_square_wide"],
	"pebble": ["pebble_round", "pebble_round_2", "pebble_round_3", "pebble_round_4", "pebble_round_5",
		"pebble_square", "pebble_square_2", "pebble_square_3", "pebble_square_4", "pebble_square_5", "pebble_square_6"],
}

const TEXTURES := {
	"clover_1": ["res://assets/sprites/ground_cover/clover_1_55deg_albedo.png", "res://assets/sprites/ground_cover/clover_1_55deg_normal.png"],
	"clover_2": ["res://assets/sprites/ground_cover/clover_2_55deg_albedo.png", "res://assets/sprites/ground_cover/clover_2_55deg_normal.png"],
	"flower_group_1": ["res://assets/sprites/ground_cover/flower_group_1_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_group_1_55deg_normal.png"],
	"flower_group_2": ["res://assets/sprites/ground_cover/flower_group_2_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_group_2_55deg_normal.png"],
	"flower_single_1": ["res://assets/sprites/ground_cover/flower_single_1_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_single_1_55deg_normal.png"],
	"flower_single_2": ["res://assets/sprites/ground_cover/flower_single_2_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_single_2_55deg_normal.png"],
	"flower_petal_1": ["res://assets/sprites/ground_cover/flower_petal_1_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_petal_1_55deg_normal.png"],
	"flower_petal_2": ["res://assets/sprites/ground_cover/flower_petal_2_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_petal_2_55deg_normal.png"],
	"flower_petal_3": ["res://assets/sprites/ground_cover/flower_petal_3_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_petal_3_55deg_normal.png"],
	"flower_petal_4": ["res://assets/sprites/ground_cover/flower_petal_4_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_petal_4_55deg_normal.png"],
	"flower_petal_5": ["res://assets/sprites/ground_cover/flower_petal_5_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_petal_5_55deg_normal.png"],
	"grass_wispy": ["res://assets/sprites/ground_cover/grass_wispy_55deg_albedo.png", "res://assets/sprites/ground_cover/grass_wispy_55deg_normal.png"],
	"grass_wispy_2": ["res://assets/sprites/ground_cover/grass_wispy_2_55deg_albedo.png", "res://assets/sprites/ground_cover/grass_wispy_2_55deg_normal.png"],
	"grass": ["res://assets/sprites/ground_cover/grass_55deg_albedo.png", "res://assets/sprites/ground_cover/grass_55deg_normal.png"],
	"mushroom": ["res://assets/sprites/ground_cover/mushroom_55deg_albedo.png", "res://assets/sprites/ground_cover/mushroom_55deg_normal.png"],
	"mushroom_laetiporus": ["res://assets/sprites/ground_cover/mushroom_laetiporus_55deg_albedo.png", "res://assets/sprites/ground_cover/mushroom_laetiporus_55deg_normal.png"],
	"plant_1": ["res://assets/sprites/ground_cover/plant_1_55deg_albedo.png", "res://assets/sprites/ground_cover/plant_1_55deg_normal.png"],
	"plant_2": ["res://assets/sprites/ground_cover/plant_2_55deg_albedo.png", "res://assets/sprites/ground_cover/plant_2_55deg_normal.png"],
	"plant_big_1": ["res://assets/sprites/ground_cover/plant_big_1_55deg_albedo.png", "res://assets/sprites/ground_cover/plant_big_1_55deg_normal.png"],
	"rock_path_1": ["res://assets/sprites/ground_cover/rock_path_1_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_1_55deg_normal.png"],
	"rock_path_2": ["res://assets/sprites/ground_cover/rock_path_2_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_2_55deg_normal.png"],
	"rock_path_3": ["res://assets/sprites/ground_cover/rock_path_3_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_3_55deg_normal.png"],
	"rock_path_square_1": ["res://assets/sprites/ground_cover/rock_path_square_1_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_square_1_55deg_normal.png"],
	"rock_path_square_2": ["res://assets/sprites/ground_cover/rock_path_square_2_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_square_2_55deg_normal.png"],
	"rock_path_square_3": ["res://assets/sprites/ground_cover/rock_path_square_3_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_square_3_55deg_normal.png"],
	"rock_path_round_thin": ["res://assets/sprites/ground_cover/rock_path_round_thin_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_round_thin_55deg_normal.png"],
	"rock_path_round_wide": ["res://assets/sprites/ground_cover/rock_path_round_wide_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_round_wide_55deg_normal.png"],
	"rock_path_square_thin": ["res://assets/sprites/ground_cover/rock_path_square_thin_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_square_thin_55deg_normal.png"],
	"rock_path_square_wide": ["res://assets/sprites/ground_cover/rock_path_square_wide_55deg_albedo.png", "res://assets/sprites/ground_cover/rock_path_square_wide_55deg_normal.png"],
	"tall_grass": ["res://assets/sprites/ground_cover/tall_grass_55deg_albedo.png", "res://assets/sprites/ground_cover/tall_grass_55deg_normal.png"],
	"pebble_round": ["res://assets/sprites/ground_cover/pebble_round_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_round_55deg_normal.png"],
	"pebble_square": ["res://assets/sprites/ground_cover/pebble_square_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_square_55deg_normal.png"],
	"pebble_square_2": ["res://assets/sprites/ground_cover/pebble_square_2_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_square_2_55deg_normal.png"],
	"pebble_square_3": ["res://assets/sprites/ground_cover/pebble_square_3_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_square_3_55deg_normal.png"],
	"pebble_square_4": ["res://assets/sprites/ground_cover/pebble_square_4_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_square_4_55deg_normal.png"],
	"pebble_square_5": ["res://assets/sprites/ground_cover/pebble_square_5_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_square_5_55deg_normal.png"],
	"pebble_square_6": ["res://assets/sprites/ground_cover/pebble_square_6_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_square_6_55deg_normal.png"],
	"pebble_round_2": ["res://assets/sprites/ground_cover/pebble_round_2_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_round_2_55deg_normal.png"],
	"pebble_round_3": ["res://assets/sprites/ground_cover/pebble_round_3_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_round_3_55deg_normal.png"],
	"pebble_round_4": ["res://assets/sprites/ground_cover/pebble_round_4_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_round_4_55deg_normal.png"],
	"pebble_round_5": ["res://assets/sprites/ground_cover/pebble_round_5_55deg_albedo.png", "res://assets/sprites/ground_cover/pebble_round_5_55deg_normal.png"],
	"shrub": ["res://assets/sprites/ground_cover/shrub_55deg_albedo.png", "res://assets/sprites/ground_cover/shrub_55deg_normal.png"],
	"shrub_flowers": ["res://assets/sprites/ground_cover/shrub_flowers_55deg_albedo.png", "res://assets/sprites/ground_cover/shrub_flowers_55deg_normal.png"],
	"flower_bush_1": ["res://assets/sprites/ground_cover/flower_bush_1_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_bush_1_55deg_normal.png"],
	"flower_bush_2": ["res://assets/sprites/ground_cover/flower_bush_2_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_bush_2_55deg_normal.png"],
	"flower_bush_3": ["res://assets/sprites/ground_cover/flower_bush_3_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_bush_3_55deg_normal.png"],
	"flower_petal_6": ["res://assets/sprites/ground_cover/flower_petal_6_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_petal_6_55deg_normal.png"],
	"flower_single_3": ["res://assets/sprites/ground_cover/flower_single_3_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_single_3_55deg_normal.png"],
	"flower_single_4": ["res://assets/sprites/ground_cover/flower_single_4_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_single_4_55deg_normal.png"],
	"flower_clump_1": ["res://assets/sprites/ground_cover/flower_clump_1_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_clump_1_55deg_normal.png"],
	"flower_clump_2": ["res://assets/sprites/ground_cover/flower_clump_2_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_clump_2_55deg_normal.png"],
	"flower_clump_3": ["res://assets/sprites/ground_cover/flower_clump_3_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_clump_3_55deg_normal.png"],
	"flower_clump_4": ["res://assets/sprites/ground_cover/flower_clump_4_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_clump_4_55deg_normal.png"],
	"flower_clump_5": ["res://assets/sprites/ground_cover/flower_clump_5_55deg_albedo.png", "res://assets/sprites/ground_cover/flower_clump_5_55deg_normal.png"],
	"grass_large": ["res://assets/sprites/ground_cover/grass_large_55deg_albedo.png", "res://assets/sprites/ground_cover/grass_large_55deg_normal.png"],
	"grass_small": ["res://assets/sprites/ground_cover/grass_small_55deg_albedo.png", "res://assets/sprites/ground_cover/grass_small_55deg_normal.png"],
}


## Map theme (map_generator.gd): kind -> weight, or one forced kind (shore
## reeds, pebbles). Both empty = every kind equally likely. Set before the
## plant enters the tree.
var kind_weights: Dictionary = {}
var kind_override := ""
## Optional subset of the kind's variants (a stone path keeps one style).
var variant_choices: Array = []


## The user's-request shore plants (NatureCatalog.COVER): reeds, lily pads
## floating on the water, driftwood - asked for by family as kind_override.
const CATALOG_KINDS := ["reeds", "lilypad", "driftwood"]
## Lily pads lie on the water: above its surface (-5), under ripples,
## docks and everything else.
const ON_WATER_Z := -4


func _ready() -> void:
	# Lies on the ground: takes cast shadows (see LightTwin).
	light_mask = LightTwin.GROUND_LAYER
	if kind_override in CATALOG_KINDS:
		var entry: Dictionary = NatureCatalog.of_families(NatureCatalog.COVER, [kind_override]).pick_random()
		var ctex := CanvasTexture.new()
		ctex.diffuse_texture = Art.tex(entry.albedo)
		ctex.normal_texture = Art.tex(entry.normal)
		texture = ctex
		Art.place(self, entry.offset, SPRITE_SCALE)
		if kind_override == "lilypad":
			z_index = ON_WATER_Z
		return
	var kind: String = kind_override if kind_override != "" else _pick_kind()
	var variant: String = variant_choices.pick_random() if not variant_choices.is_empty() else KINDS[kind].pick_random()
	var tex := CanvasTexture.new()
	tex.diffuse_texture = Art.tex(TEXTURES[variant][0])
	tex.normal_texture = Art.tex(TEXTURES[variant][1])
	texture = tex
	Art.place(self, VARIANT_OFFSETS.get(variant, KIND_OFFSETS.get(kind, DEFAULT_OFFSET)), SPRITE_SCALE)


func _pick_kind() -> String:
	if kind_weights.is_empty():
		return KINDS.keys().pick_random()
	var total := 0.0
	for k in kind_weights:
		total += kind_weights[k]
	var roll := randf() * total
	for k in kind_weights:
		roll -= kind_weights[k]
		if roll <= 0.0:
			return k
	return kind_weights.keys()[0]
