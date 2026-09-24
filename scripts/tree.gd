extends Node2D

## Dead-tree variants pre-rendered from Quaternius' Stylized Nature MegaKit
## (CC0) through the same 55deg orthographic pipeline as the oil barrel (see
## tools/render_sprite.py). All five share one render camera, so the trunk
## base sits on the same texture pixel in every sprite and relative sizes are
## true to the models. One variant is picked per tree each run.

## Where the trunk base lands in the 270x360 renders, measured from the
## texture center (render camera center_y 5.265 units, 27.108 px/unit).
const SPRITE_OFFSET := Vector2(0, -142.73)
const SPRITE_SCALE := 0.5

## fade_rect: the branch area (node-local px) where the player counts as
## "behind" the tree, from each model's projected bounds; stops just above
## the trunk base so standing in front of the tree doesn't trigger it.
const VARIANTS := [
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_1_55deg_normal.png"),
	 "fade_rect": Rect2(-52, -118, 86, 108)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_2_55deg_normal.png"),
	 "fade_rect": Rect2(-54, -156, 113, 146)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_3_55deg_normal.png"),
	 "fade_rect": Rect2(-32, -94, 91, 84)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_4_55deg_normal.png"),
	 "fade_rect": Rect2(-35, -98, 83, 88)},
	{"albedo": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_albedo.png"),
	 "normal": preload("res://assets/sprites/dead_tree/dead_tree_5_55deg_normal.png"),
	 "fade_rect": Rect2(-46, -112, 108, 102)},
]

@onready var sprite: Sprite2D = $Canopy/Visual
@onready var fade_shape: CollisionShape2D = $Canopy/Area2D/CollisionShape2D


func _ready() -> void:
	var variant: Dictionary = VARIANTS[randi() % VARIANTS.size()]

	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.albedo
	tex.normal_texture = variant.normal
	sprite.texture = tex
	sprite.offset = SPRITE_OFFSET
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	# Built per instance: a shape resource from the .tscn would be shared by
	# every tree, so resizing it for one variant would resize all of them.
	var rect: Rect2 = variant.fade_rect
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	fade_shape.shape = shape
	fade_shape.position = rect.get_center()
