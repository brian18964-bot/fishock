class_name Obstacle
extends StaticBody2D

## A rock in the way (user decision: the game is 3D now - RunView3D shows
## it as a rock model; this is its place and its solid base only, no
## picture). Its base is an ellipse (radii, node px), and the 3D rock is
## sized to that same ellipse (user request: nothing walks into anything).
## One of KINDS each run (the theme's rock_pool indices).

## The rock models (assets/models/proto3d) and their bases' sizes (px
## across, deep) - about a metre and a half to two across.
const KINDS := [
	{"model": "rock_medium", "base": Vector2(52, 38)},
	{"model": "rock_medium_2", "base": Vector2(58, 44)},
	{"model": "rock_medium", "base": Vector2(46, 40)},
]

@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

## Map theme (map_generator.gd): KINDS indices to choose from (empty: any).
## Set before the rock enters the tree.
var variant_pool: Array = []
## This much bigger. Set before it enters the tree.
var size := 1.0
## What it is (KINDS) and its base's radii (px).
var model := ""
var radii := Vector2.ZERO


func _ready() -> void:
	add_to_group("solids")
	var pool := variant_pool.filter(func(v): return v is int and v >= 0 and v < KINDS.size())
	apply_kind(pool.pick_random() if not pool.is_empty() else randi() % KINDS.size())
	var occ := get_node_or_null("LightOccluder2D")
	if occ != null:
		occ.queue_free()
	var visual := get_node_or_null("Visual")
	if visual != null:
		visual.queue_free()


func apply_kind(index: int) -> void:
	var kind: Dictionary = KINDS[index]
	model = kind.model
	radii = kind.base * 0.5 * size
	collision.polygon = ellipse(radii)


func solids() -> Array:
	return [[global_position, radii]]


## An ellipse of `r` as a polygon round the origin.
static func ellipse(r: Vector2, sides := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := i * TAU / sides
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
