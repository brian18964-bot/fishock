class_name OilDrum
extends Area2D

## Design doc request: a world pickup that's carried by hand back to a fuel
## station and dumped in (see Player._deliver_oil_drum() /
## FuelStation.add_fuel()) rather than refilling the whole map on the spot.
## Disappears from the world while carried, and relocates elsewhere after a
## delay once delivered - same relocate pattern as Hotspot.

const RESPAWN_DELAY := 45.0
const MARGIN := 150.0
const FUEL_AMOUNT := 150.0

var active: bool = true
var carried: bool = false

var _respawn_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_relocate()


func _process(delta: float) -> void:
	visible = active and not carried
	monitoring = active and not carried
	if not active and not carried:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_relocate()


## Design doc request: picked up and carried rather than used in place -
## see Player._handle_action_input()'s oil-drum-zone branch.
func pick_up() -> void:
	carried = true


## Called once the carrying player deposits it at a fuel station. Goes back
## into the world after the usual relocate delay.
func deliver() -> void:
	carried = false
	active = false
	_respawn_timer = RESPAWN_DELAY


func _relocate() -> void:
	var pos := Vector2.ZERO
	for _try in range(20):
		pos = Vector2(
			randf_range(MARGIN, Player.WORLD_WIDTH - MARGIN),
			randf_range(MARGIN, Player.WORLD_HEIGHT - MARGIN)
		)
		if not _in_water(pos):
			break
	global_position = pos
	active = true


## Design doc request: a land item (roadside/carried) should never land
## inside a water zone - a common one would just look wrong, a rare one
## would spawn it inside solid, unreachable collision.
func _in_water(pos: Vector2) -> bool:
	for zone in get_tree().get_nodes_in_group("water_zones"):
		if zone.contains(pos):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_oil_drum"):
		body.set_in_oil_drum(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_oil_drum"):
		body.set_in_oil_drum(false, self)
