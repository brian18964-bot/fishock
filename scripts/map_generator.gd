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

## User feedback follow-up: obstacles/trees/bushes were still at fixed
## main.tscn positions, so they could visually land inside a randomized
## water zone (a tree "growing" out of a lake). Scattered here too, kept
## clear of water and of each other - purely cosmetic (obstacles/tree
## trunks are already solid, so overlapping a rare zone's collision was
## never a functional bug, just an odd-looking one).
const PROP_NAMES := [
	"Obstacle1", "Obstacle2", "Obstacle3", "Obstacle4", "Obstacle5",
	"Tree1", "Tree2", "Tree3", "Tree4", "Tree5", "Tree6",
	"Bush1", "Bush2", "Bush3",
]
const PROP_MARGIN := 80.0
const PROP_MIN_SEPARATION := 90.0
const PROP_AVOID_SPAWN_RADIUS := 180.0

const DOCK_SCENE := preload("res://scenes/dock.tscn")
const DOCK_COUNT := 3
const DOCK_SHORE_MARGIN := 60.0

const GROUND_COVER_SCENE := preload("res://scenes/ground_cover.tscn")
const GROUND_COVER_COUNT := 80
const CRITTER_SCENE := preload("res://scenes/critter.tscn")
const CRITTER_COUNT := 10
const AMBIENT_ANIMAL_COUNT := 6

var water_zones: Array = []


func _ready() -> void:
	_generate_water_zones()
	_place_docks()
	_place_altar_and_escape()
	_scatter_props()
	_scatter_ground_cover()
	_scatter_critters()


func _generate_water_zones() -> void:
	for _i in range(COMMON_ZONE_COUNT):
		_spawn_zone(WaterZone.ZoneType.COMMON, randf_range(COMMON_RADIUS_MIN, COMMON_RADIUS_MAX))
	for _i in range(RARE_ZONE_COUNT):
		_spawn_zone(WaterZone.ZoneType.RARE, randf_range(RARE_RADIUS_MIN, RARE_RADIUS_MAX))


func _spawn_zone(type: int, radius: float) -> void:
	var pos := _pick_zone_position(radius)
	var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
	# Main is still mid-instantiation while this whole scene's _ready() chain
	# is running (map_generator is a static child of it) - add_child() on it
	# here fails outright ("Parent node is busy setting up children"), so
	# this has to be deferred. setup() only touches the zone's own already-
	# instantiated children, so it's safe to call before the zone is in the
	# tree at all.
	zone.setup(type, radius, pos)
	get_parent().add_child.call_deferred(zone)
	water_zones.append(zone)


## User request: docks out into a few common zones. Each picks one of the
## four directions whose shore point is on open land (inside the map, not in
## another zone) and lays the dock along it toward the zone's center.
func _place_docks() -> void:
	var commons: Array = water_zones.filter(func(z): return not z.is_rare())
	commons.shuffle()
	var placed := 0
	for zone in commons:
		if placed >= DOCK_COUNT:
			break
		var dirs := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
		dirs.shuffle()
		for d in dirs:
			var vertical: bool = d.x == 0.0
			var half: float = Dock.half_length(vertical)
			var shore: Vector2 = zone.global_position + d * (zone.radius + half * 0.6)
			if shore.x < DOCK_SHORE_MARGIN or shore.x > Player.WORLD_WIDTH - DOCK_SHORE_MARGIN \
					or shore.y < DOCK_SHORE_MARGIN or shore.y > Player.WORLD_HEIGHT - DOCK_SHORE_MARGIN:
				continue
			if _in_any_water(shore):
				continue
			var dock: Dock = DOCK_SCENE.instantiate()
			# Shore end 30% of the length past the edge, the rest over water.
			dock.position = zone.global_position + d * (zone.radius - half * 0.4)
			dock.setup(vertical, randf() < 0.5)
			get_parent().add_child.call_deferred(dock)
			placed += 1
			break


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


func _in_any_water(pos: Vector2) -> bool:
	for zone in water_zones:
		if zone.contains(pos):
			return true
	return false


func _scatter_props() -> void:
	var placed: Array = []
	for prop_name in PROP_NAMES:
		var prop: Node2D = get_parent().get_node_or_null(prop_name)
		if prop == null:
			continue
		var pos := _pick_prop_position(placed)
		prop.global_position = pos
		placed.append(pos)


## Decorative only, so no spacing rules beyond staying out of the water.
func _scatter_ground_cover() -> void:
	for _i in range(GROUND_COVER_COUNT):
		var pos := Vector2.ZERO
		for _try in range(15):
			pos = Vector2(
				randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
				randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
			)
			if not _in_any_water(pos):
				break
		var plant: Node2D = GROUND_COVER_SCENE.instantiate()
		plant.position = pos
		# Main is still mid-setup here; see _spawn_zone().
		get_parent().add_child.call_deferred(plant)


## User request: small animals to catch as bait, spread around the map
## (kept off the spawn point so the first few seconds aren't a chase).
func _scatter_critters() -> void:
	for _i in range(CRITTER_COUNT):
		var pos := _pick_prop_position([])
		var critter: Node2D = CRITTER_SCENE.instantiate()
		critter.position = pos
		# Main is still mid-setup here; see _spawn_zone().
		get_parent().add_child.call_deferred(critter)
	# User request: larger ambient animals (cows, a deer...) as scenery.
	for _i in range(AMBIENT_ANIMAL_COUNT):
		var animal: Critter = CRITTER_SCENE.instantiate()
		animal.ambient = true
		animal.position = _pick_prop_position([])
		get_parent().add_child.call_deferred(animal)


func _pick_prop_position(placed: Array) -> Vector2:
	var pos := Vector2.ZERO
	for _try in range(25):
		pos = Vector2(
			randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
		)
		if pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		if _in_any_water(pos):
			continue
		var too_close := false
		for p in placed:
			if pos.distance_to(p) < PROP_MIN_SEPARATION:
				too_close = true
				break
		if not too_close:
			break
	return pos
