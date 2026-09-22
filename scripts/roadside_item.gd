class_name RoadsideItem
extends Area2D

## Design doc request: roadside piles you rummage through (hold the action
## key for a short progress bar - see Player._handle_rummage()) for a
## chance at bait. "Flavor" only - bait is still a single generic count,
## the worm/bug/frog names are just what the message calls the find.
## Relocates elsewhere after each use, same pattern as Hotspot/OilDrum.

const RESPAWN_DELAY := 25.0
const MARGIN := 150.0
const FIND_CHANCE := 0.6
const BAIT_FLAVORS := ["蚯蚓", "蟲子", "青蛙"]

var active: bool = true

var _respawn_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_relocate()


func _process(delta: float) -> void:
	visible = active
	if not active:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_relocate()


## Resolves one completed rummage: consumes this pile (it relocates after
## RESPAWN_DELAY) and rolls whether it yielded bait.
func resolve() -> Dictionary:
	active = false
	_respawn_timer = RESPAWN_DELAY
	if randf() < FIND_CHANCE:
		var flavor: String = BAIT_FLAVORS[randi() % BAIT_FLAVORS.size()]
		return {"found": true, "flavor": flavor}
	return {"found": false}


func _relocate() -> void:
	global_position = Vector2(
		randf_range(MARGIN, Player.WORLD_WIDTH - MARGIN),
		randf_range(MARGIN, Player.WORLD_HEIGHT - MARGIN)
	)
	active = true


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_roadside"):
		body.set_in_roadside(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_roadside"):
		body.set_in_roadside(false, self)
