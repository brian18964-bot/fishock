extends "res://scripts/foliage_occluder.gd"

## A bush to hide in (user decision: the game is 3D now - RunView3D shows
## it as a fern, as wide as the hiding place here; no picture).

## How far round it counts as in it (px).
const RADIUS := 24.0

## (map_generator.gd sets it; one kind of bush now)
var families: Array = []
var radius := RADIUS


func _ready() -> void:
	super()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision: CollisionShape2D = area.get_node("CollisionShape2D")
	collision.shape = shape
	collision.position = Vector2.ZERO
