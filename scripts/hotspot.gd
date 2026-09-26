class_name Hotspot
extends Node2D

## Design doc §5.2: ripples to mark itself, and relocates once something's
## been caught from it. Design doc request: now that the map has defined
## water zones, it always lands inside a random common one (never a rare
## zone or dry land) - a Hotspot is meant to be a walk-up-and-cast spot.
## User request: marked by rings spreading out over the water (the same
## ripples as a cast makes, reaching out to about where casts count) with
## little splashes in the middle, like fish rising - not a square.

const RADIUS := 70.0
const RESPAWN_DELAY := 1.5
const RING_GAP := 0.8
const RING_RADIUS := 64.0
const RING_LIFE := 2.4
const SPLASH_GAP := Vector2(0.6, 1.6)
const SPLASH_SPREAD := 26.0

var active: bool = true

var _respawn_timer: float = 0.0
var _ring_timer := 0.0
var _splash_timer := 0.0


func _ready() -> void:
	_relocate()


func _process(delta: float) -> void:
	visible = active
	if active:
		_ring_timer -= delta
		if _ring_timer <= 0.0:
			_ring_timer = RING_GAP
			Ripple.spawn(get_parent(), global_position, RING_RADIUS, 0.9, RING_LIFE)
		_splash_timer -= delta
		if _splash_timer <= 0.0:
			_splash_timer = randf_range(SPLASH_GAP.x, SPLASH_GAP.y)
			var at := global_position + Vector2(randf_range(-1, 1), randf_range(-1, 1) * 0.8) * SPLASH_SPREAD
			Ripple.spawn(get_parent(), at, randf_range(10.0, 18.0), 1.2, 0.9)
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
		# The map's water zones are added in a deferred batch after this
		# runs at startup: wait for them. (This used to park it at the map's
		# center - on dry land at the spawn point - until something was
		# caught from it, which never happened.)
		active = false
		_respawn_timer = 0.1
		return

	var zone: WaterZone = common_zones[randi() % common_zones.size()]
	global_position = zone.random_point(40.0)
	active = true
