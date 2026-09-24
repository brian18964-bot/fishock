class_name Hotspot
extends Node2D

## Design doc §5.2: ripples to mark itself, and relocates once something's
## been caught from it. Design doc request: now that the map has defined
## water zones, it always lands inside a random common one (never a rare
## zone or dry land) - a Hotspot is meant to be a walk-up-and-cast spot.

const RADIUS := 70.0
const RESPAWN_DELAY := 1.5

var active: bool = true

var _respawn_timer: float = 0.0
var _pulse_time: float = 0.0

@onready var ripple: ColorRect = $Ripple


func _ready() -> void:
	_relocate()


func _process(delta: float) -> void:
	visible = active
	if active:
		_pulse_time += delta
		var s := 1.0 + sin(_pulse_time * 2.0) * 0.15
		ripple.scale = Vector2(s, s)
	else:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_relocate()


func consume() -> void:
	active = false
	_respawn_timer = RESPAWN_DELAY


## Design doc request: a rotten-offering sacrifice can summon an exclusive
## fishing ground on the spot instead of waiting out the normal respawn -
## just an immediate relocate, since a Hotspot already carries boosted
## rare/heart odds (§5.2/§5.3).
func force_relocate() -> void:
	_relocate()


func _relocate() -> void:
	var common_zones := get_tree().get_nodes_in_group("water_zones_common")
	if common_zones.is_empty():
		# Defensive fallback (e.g. this scene tested standalone, without
		# MapGenerator ever running) so this never gets stuck uninitialized.
		global_position = Vector2(Player.WORLD_WIDTH * 0.5, Player.WORLD_HEIGHT * 0.5)
		active = true
		return

	var zone: WaterZone = common_zones[randi() % common_zones.size()]
	global_position = zone.random_point(40.0)
	active = true
