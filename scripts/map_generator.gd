extends Node2D

## Design doc request: each run gets a freshly randomized layout instead of
## the old fixed one - a handful of water zones (mostly "common", a couple
## "rare"; see water_zone.gd), plus the altar and escape point no longer
## sitting at fixed coordinates. This node is the FIRST child of Main (see
## main.tscn) specifically so its _ready() runs before any sibling that
## reads these positions/groups in its own _ready() - Hotspot (picks a spot
## inside a common zone) and Ghost (reads EscapePoint's position).

const WATER_ZONE_SCENE := preload("res://scenes/water_zone.tscn")

## User feedback: the original 5 common + 2 rare zones left far too much of
## the map as dry, unfishable land - bumped both the count and radii so
## there's always water within easy reach wherever you are.
const COMMON_ZONE_COUNT := 9
const RARE_ZONE_COUNT := 3
const COMMON_RADIUS_MIN := 170.0
const COMMON_RADIUS_MAX := 280.0
const RARE_RADIUS_MIN := 100.0
const RARE_RADIUS_MAX := 160.0
const ZONE_MARGIN := 100.0
const ZONE_MIN_GAP := 25.0

## Design doc request: rare zones are placed without regard to the altar -
## no distance-from-altar logic here, just kept clear of the shared spawn
## point so the player never spawns inside solid water-zone collision.
const SPAWN_POS := Vector2(1200.0, 700.0)
const SPAWN_CLEAR_RADIUS := 220.0

const FIXED_POINT_MARGIN := 150.0
const FIXED_POINT_MIN_SEPARATION := 550.0

var water_zones: Array = []


func _ready() -> void:
	_generate_water_zones()
	_place_altar_and_escape()


func _generate_water_zones() -> void:
	for _i in range(COMMON_ZONE_COUNT):
		_spawn_zone(WaterZone.ZoneType.COMMON, randf_range(COMMON_RADIUS_MIN, COMMON_RADIUS_MAX))
	for _i in range(RARE_ZONE_COUNT):
		_spawn_zone(WaterZone.ZoneType.RARE, randf_range(RARE_RADIUS_MIN, RARE_RADIUS_MAX))


func _spawn_zone(type: int, radius: float) -> void:
	var pos := _pick_zone_position(radius)
	var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
	get_parent().add_child(zone)
	zone.setup(type, radius, pos)
	water_zones.append(zone)


func _pick_zone_position(radius: float) -> Vector2:
	var pos := Vector2.ZERO
	for _try in range(30):
		pos = Vector2(
			randf_range(ZONE_MARGIN + radius, Player.WORLD_WIDTH - ZONE_MARGIN - radius),
			randf_range(ZONE_MARGIN + radius, Player.WORLD_HEIGHT - ZONE_MARGIN - radius)
		)
		if pos.distance_to(SPAWN_POS) < SPAWN_CLEAR_RADIUS + radius:
			continue
		var overlaps := false
		for zone in water_zones:
			if pos.distance_to(zone.global_position) < radius + zone.radius + ZONE_MIN_GAP:
				overlaps = true
				break
		if not overlaps:
			break
	return pos


func _place_altar_and_escape() -> void:
	var altar: Node2D = get_parent().get_node("Altar")
	var escape_point: Node2D = get_parent().get_node("EscapePoint")

	altar.global_position = _pick_fixed_point_position([SPAWN_POS])
	escape_point.global_position = _pick_fixed_point_position([SPAWN_POS, altar.global_position])


func _pick_fixed_point_position(avoid: Array) -> Vector2:
	var pos := Vector2.ZERO
	for _try in range(30):
		pos = Vector2(
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_WIDTH - FIXED_POINT_MARGIN),
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_HEIGHT - FIXED_POINT_MARGIN)
		)
		var far_enough := true
		for p in avoid:
			if pos.distance_to(p) < FIXED_POINT_MIN_SEPARATION:
				far_enough = false
				break
		if far_enough and not _in_rare_zone(pos):
			break
	return pos


func _in_rare_zone(pos: Vector2) -> bool:
	for zone in water_zones:
		if zone.is_rare() and zone.contains(pos):
			return true
	return false
