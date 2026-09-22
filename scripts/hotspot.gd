class_name Hotspot
extends Node2D

## Design doc §5.2: only spawns away from fixed lights, ripples to mark
## itself, and relocates once something's been caught from it.

const RADIUS := 70.0
const RESPAWN_DELAY := 1.5
const MARGIN := 150.0
const MIN_DIST_FROM_FIXED_LIGHT := 300.0

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
	var altar := get_tree().current_scene.get_node("Altar")
	var escape_point := get_tree().current_scene.get_node("EscapePoint")
	var pos := Vector2.ZERO
	for _i in range(20):
		pos = Vector2(
			randf_range(MARGIN, Player.WORLD_WIDTH - MARGIN),
			randf_range(MARGIN, Player.WORLD_HEIGHT - MARGIN)
		)
		var far_from_altar := pos.distance_to(altar.global_position) > MIN_DIST_FROM_FIXED_LIGHT
		var far_from_escape := pos.distance_to(escape_point.global_position) > MIN_DIST_FROM_FIXED_LIGHT
		if far_from_altar and far_from_escape:
			break
	global_position = pos
	active = true
