extends Node2D

## Dead-tree, pine, leafy and twisted tree variants pre-rendered from Quaternius' Stylized Nature
## MegaKit (CC0) through the same 55deg orthographic pipeline as the oil
## barrel (see tools/render_sprite.py), all at true scale and the same pixel
## density. One variant is picked per tree each run.

## offset: where the trunk base lands relative to the texture center,
## -center_y * 27.108 px/unit. Dead trees: 270x360 renders, center_y 5.265.
## Pines and leafy trees: 200x216 renders, center_y 2.70.
## Twisted trees: 384x424 renders, center (0.125, 6.37); the lopsided one:
## 384x376, center (4.58, 5.295). offset.x = +center_x * 27.108: the canvas
## shifted right, so the texture moves right to bring the trunk onto the node.
const DEAD_TREE_OFFSET := Vector2(0, -142.73)
const TREE_OFFSET := Vector2(0, -73.19)
const TWISTED_OFFSET := Vector2(3.39, -172.68)
const TWISTED_LEANING_OFFSET := Vector2(124.15, -143.54)
const SPRITE_SCALE := 0.5

## fade_rect: the branch area (node-local px) where the player counts as
## "behind" the tree, from each model's projected bounds; stops just above
## the trunk base so standing in front of the tree doesn't trigger it.
const VARIANTS := [
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-52, -118, 86, 108)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-54, -156, 113, 146)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-32, -94, 91, 84)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-35, -98, 83, 88)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_normal.png"),
	 "family": "dead", "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-46, -112, 108, 102)},
	{"albedo": preload("res://assets/sprites/pine/pine_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_1_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-41, -87, 88, 77)},
	{"albedo": preload("res://assets/sprites/pine/pine_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_2_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-39, -64, 78, 54)},
	{"albedo": preload("res://assets/sprites/pine/pine_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_3_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-39, -87, 79, 77)},
	{"albedo": preload("res://assets/sprites/pine/pine_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_4_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-29, -64, 49, 54)},
	{"albedo": preload("res://assets/sprites/pine/pine_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_5_55deg_normal.png"),
	 "family": "pine", "offset": TREE_OFFSET, "fade_rect": Rect2(-33, -64, 67, 54)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_1_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-24, -88, 52, 78)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_2_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-30, -67, 61, 57)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_3_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-27, -85, 55, 75)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_4_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-30, -66, 59, 56)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_5_55deg_normal.png"),
	 "family": "leafy", "offset": TREE_OFFSET, "fade_rect": Rect2(-26, -70, 50, 60)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_1_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-51, -177, 129, 167)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_2_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-59, -188, 141, 178)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_3_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-61, -166, 154, 156)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_4_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_LEANING_OFFSET, "fade_rect": Rect2(-30, -161, 184, 151)},
	{"albedo": preload("res://assets/sprites/twisted_tree/twisted_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/twisted_tree/twisted_tree_5_55deg_normal.png"),
	 "family": "twisted", "offset": TWISTED_OFFSET, "fade_rect": Rect2(-90, -175, 143, 165)},
]

@onready var sprite: Sprite2D = $Canopy/Visual
@onready var fade_shape: CollisionShape2D = $Canopy/Area2D/CollisionShape2D


func _ready() -> void:
	apply_variant(_pick_variant())


## Family first, then a variant within it, so families with many models
## (ten bare trees) don't crowd out the ones with few.
static func _pick_variant() -> int:
	var families := {}
	for i in VARIANTS.size():
		families.get_or_add(VARIANTS[i].family, []).append(i)
	return families.values().pick_random().pick_random()


func apply_variant(index: int) -> void:
	var variant: Dictionary = VARIANTS[index]

	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.albedo
	tex.normal_texture = variant.normal
	sprite.texture = tex
	sprite.offset = variant.offset
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	# Built per instance: a shape resource from the .tscn would be shared by
	# every tree, so resizing it for one variant would resize all of them.
	var rect: Rect2 = variant.fade_rect
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	fade_shape.shape = shape
	fade_shape.position = rect.get_center()
