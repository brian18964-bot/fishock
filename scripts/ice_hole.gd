class_name IceHole
extends Node2D

## User request (the snowy map): a hole cut in the ice at the water's edge. Cast within RADIUS
## of one and the fish come sooner (the wait cut to WAIT_MULT). Placed by MapGenerator on the
## frozen fringe; RunView3D draws it (a dark hole in a pale rim, a little breath over it).

const RADIUS := 60.0
const WAIT_MULT := 0.65


func _ready() -> void:
	add_to_group("ice_holes")


## Is `at` (2D px) near enough to one for its fish?
static func near(tree: SceneTree, at: Vector2) -> bool:
	for h in tree.get_nodes_in_group("ice_holes"):
		if (h as Node2D).global_position.distance_to(at) <= RADIUS:
			return true
	return false
