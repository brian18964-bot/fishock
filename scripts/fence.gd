class_name Fence
extends StaticBody2D

## User request (the countryside): a wooden post-and-rail fence along a side of a field - a run of
## it from its middle `half` px each way along `yaw`, solid (low enough to see over, too high to
## step over); the fields' fences leave gaps to walk through (MapGenerator._fence_field). This is
## its place and its solid ground; RunView3D shows it (FarmBuild.fences).
##
## Solids (the ghosts, the willow - they move by hand) see it as a row of small circles.

## (its thickness, px; how far apart the circles Solids see along it)
const THICK := 8.0
const STEP := 14.0

## Half its length (px) and its heading (rad, on the map: 0 along +x).
var half := 60.0
var yaw := 0.0
var seed_value := 0
var _bases: Array = []


func _ready() -> void:
	add_to_group("solids")
	add_to_group("fences")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half * 2.0, THICK)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.rotation = yaw
	add_child(col)
	var along := Vector2(cos(yaw), sin(yaw))
	var n := maxi(1, ceili(half * 2.0 / STEP))
	for i in n + 1:
		var t := float(i) / float(n) - 0.5
		_bases.append([along * (t * half * 2.0), Vector2(THICK * 0.6, THICK * 0.6)])


func solids() -> Array:
	var out := []
	for b in _bases:
		out.append([global_position + (b[0] as Vector2), b[1]])
	return out


## Its two ends (px, world).
func ends() -> Array:
	var along := Vector2(cos(yaw), sin(yaw)) * half
	return [global_position - along, global_position + along]
