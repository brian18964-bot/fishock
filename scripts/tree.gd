extends Node2D

## Dead-tree, pine and leafy-tree variants pre-rendered from Quaternius' Stylized Nature
## MegaKit (CC0) through the same 55deg orthographic pipeline as the oil
## barrel (see tools/render_sprite.py), all at true scale and the same pixel
## density. One variant is picked per tree each run.

## offset: where the trunk base lands relative to the texture center,
## -center_y * 27.108 px/unit. Dead trees: 270x360 renders, center_y 5.265.
## Pines and leafy trees: 200x216 renders, center_y 2.70.
const DEAD_TREE_OFFSET := Vector2(0, -142.73)
const TREE_OFFSET := Vector2(0, -73.19)
const SPRITE_SCALE := 0.5

## fade_rect: the branch area (node-local px) where the player counts as
## "behind" the tree, from each model's projected bounds; stops just above
## the trunk base so standing in front of the tree doesn't trigger it.
const VARIANTS := [
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_normal.png"),
	 "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-52, -118, 86, 108)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_normal.png"),
	 "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-54, -156, 113, 146)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_normal.png"),
	 "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-32, -94, 91, 84)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_normal.png"),
	 "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-35, -98, 83, 88)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_normal.png"),
	 "offset": DEAD_TREE_OFFSET, "fade_rect": Rect2(-46, -112, 108, 102)},
	{"albedo": preload("res://assets/sprites/pine/pine_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_1_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-41, -87, 88, 77)},
	{"albedo": preload("res://assets/sprites/pine/pine_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_2_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-39, -64, 78, 54)},
	{"albedo": preload("res://assets/sprites/pine/pine_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_3_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-39, -87, 79, 77)},
	{"albedo": preload("res://assets/sprites/pine/pine_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_4_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-29, -64, 49, 54)},
	{"albedo": preload("res://assets/sprites/pine/pine_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/pine/pine_5_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-33, -64, 67, 54)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_1_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-24, -88, 52, 78)},
	{"albedo": preload("res://assets/sprites/leafy_tree/leafy_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/leafy_tree/leafy_tree_2_55deg_normal.png"),
	 "offset": TREE_OFFSET, "fade_rect": Rect2(-30, -67, 61, 57)},
]

@onready var sprite: Sprite2D = $Canopy/Visual
@onready var fade_shape: CollisionShape2D = $Canopy/Area2D/CollisionShape2D


func _ready() -> void:
	var variant: Dictionary = VARIANTS[randi() % VARIANTS.size()]

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
