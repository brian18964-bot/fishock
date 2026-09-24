extends Node2D

## Design doc request: each run gets a freshly randomized layout instead of
## the old fixed one - a handful of water zones (mostly "common", a couple
## "rare"; see water_zone.gd), plus the altar and escape point no longer
## sitting at fixed coordinates. This node is the FIRST child of Main (see
## main.tscn) specifically so its _ready() runs before any sibling that
## reads these positions/groups in its own _ready() - Hotspot (picks a spot
## inside a common zone) and Ghost (reads EscapePoint's position).

const WATER_ZONE_SCENE := preload("res://scenes/water_zone.tscn")

## User request: 3-4 common zones and a single rare one per run, each an
## irregular pond - a main circle plus a few overlapping lobes (see
## WaterZone) - kept apart so each is its own lake with a shore to dress.
const COMMON_ZONE_COUNT := Vector2i(3, 4)
const RARE_ZONE_COUNT := 1
const COMMON_RADIUS_MIN := 130.0
const COMMON_RADIUS_MAX := 175.0
const COMMON_EXTRA_LOBES := Vector2i(2, 4)
const RARE_RADIUS_MIN := 90.0
const RARE_RADIUS_MAX := 115.0
const RARE_EXTRA_LOBES := Vector2i(1, 2)
const ZONE_MARGIN := 60.0
const ZONE_MIN_GAP := 90.0

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
const DOCK_STAIRS_CHANCE := 0.5
const DOCK_BOAT_CHANCE := 0.4

const GROUND_COVER_SCENE := preload("res://scenes/ground_cover.tscn")
const TREE_SCENE := preload("res://scenes/tree.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const BUSH_SCENE := preload("res://scenes/bush.tscn")

## User request: each run is dressed in one of a few looks, all from the
## existing art. A theme sets how many extra trees/rocks/bushes/plants get
## scattered and which kinds (tree families, rock variants - obstacle.gd
## VARIANTS indices, 3-7 are the boulders - and ground-cover kinds), and how
## the pond shores are dressed: per shore sample, the chance of a reed
## clump, pebbles, a boulder or a tree, plus the chance a pond gets a
## boardwalk along its bank.
const THEMES := {
	"forest": {
		"trees": 26, "rocks": 3, "bushes": 8, "ground": 120,
		"tree_families": {"leafy": 3.0, "pine": 3.0, "oak": 3.0, "birch": 2.0, "maple": 2.0, "twisted": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 4.0, "clover": 2.0, "plant": 3.0, "shrub": 3.0, "flower_group": 2.0,
			"flower_single": 2.0, "flower_clump": 2.0, "flower_bush": 2.0, "flower_petal": 1.0, "mushroom": 2.0},
		"shore": {"reeds": 0.7, "pebbles": 0.15, "boulder": 0.04, "tree": 0.14},
		"shore_trees": {"leafy": 1.0, "birch": 1.0, "maple": 1.0, "oak": 1.0},
		"boardwalk": 0.6,
	},
	"deadwood": {
		"trees": 22, "rocks": 6, "bushes": 3, "ground": 90,
		"tree_families": {"dead": 3.0, "bare": 3.0, "twisted": 2.0},
		"rock_pool": [0, 1, 2, 3, 4, 5],
		"ground_kinds": {"grass": 2.0, "mushroom": 3.0, "pebble": 3.0, "path_stone": 1.0, "plant": 1.0, "shrub": 1.0},
		"shore": {"reeds": 0.45, "pebbles": 0.35, "boulder": 0.07, "tree": 0.1},
		"shore_trees": {"dead": 1.0, "bare": 2.0},
		"boardwalk": 0.45,
	},
	"rocky": {
		"trees": 8, "rocks": 18, "bushes": 2, "ground": 100,
		"tree_families": {"pine": 2.0, "dead": 1.0, "bare": 1.0},
		"rock_pool": [0, 1, 2, 3, 4, 5, 6, 7],
		"ground_kinds": {"pebble": 4.0, "path_stone": 3.0, "grass": 2.0, "clover": 1.0},
		"shore": {"reeds": 0.25, "pebbles": 0.55, "boulder": 0.18, "tree": 0.03},
		"shore_trees": {"pine": 1.0},
		"boardwalk": 0.3,
	},
}
const SHORE_SPACING := 26.0
const SHORE_CLEAR_OF_SPAWN := 160.0

var theme_name := ""
var theme: Dictionary = {}
var _walk_rects: Array[Rect2] = []
const CRITTER_SCENE := preload("res://scenes/critter.tscn")
const CRITTER_COUNT := 10
const AMBIENT_ANIMAL_COUNT := 6

var water_zones: Array = []


func _ready() -> void:
	theme_name = THEMES.keys().pick_random()
	theme = THEMES[theme_name]
	_generate_water_zones()
	_place_docks()
	_place_altar_and_escape()
	_scatter_props()
	_dress_shores()
	_scatter_themed_props()
	_scatter_ground_cover()
	_scatter_critters()


func _generate_water_zones() -> void:
	# The rare one first: it's smaller and solid, so it gets its pick.
	for _i in range(RARE_ZONE_COUNT):
		_spawn_zone(WaterZone.ZoneType.RARE, randf_range(RARE_RADIUS_MIN, RARE_RADIUS_MAX), RARE_EXTRA_LOBES)
	for _i in range(randi_range(COMMON_ZONE_COUNT.x, COMMON_ZONE_COUNT.y)):
		_spawn_zone(WaterZone.ZoneType.COMMON, randf_range(COMMON_RADIUS_MIN, COMMON_RADIUS_MAX), COMMON_EXTRA_LOBES)


## Lobes spread around the main circle, overlapping it, for a wobbly shore.
func _make_lobes(radius: float, count_range: Vector2i) -> Array[Vector3]:
	var lobes: Array[Vector3] = []
	var n := randi_range(count_range.x, count_range.y)
	var base := randf() * TAU
	for k in n:
		var a := base + (k + randf_range(-0.25, 0.25)) / n * TAU
		var dist := radius * randf_range(0.55, 0.85)
		var r := radius * randf_range(0.45, 0.72)
		lobes.append(Vector3(cos(a) * dist, sin(a) * dist, r))
	return lobes


func _spawn_zone(type: int, radius: float, lobe_range: Vector2i) -> void:
	var lobes := _make_lobes(radius, lobe_range)
	var bounds := radius
	for lobe in lobes:
		bounds = maxf(bounds, Vector2(lobe.x, lobe.y).length() + lobe.z)
	var pos := _pick_zone_position(bounds)
	var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
	# Main is still mid-instantiation while this whole scene's _ready() chain
	# is running (map_generator is a static child of it) - add_child() on it
	# here fails outright ("Parent node is busy setting up children"), so
	# this has to be deferred. setup() only touches the zone's own already-
	# instantiated children, so it's safe to call before the zone is in the
	# tree at all.
	zone.setup(type, radius, pos, lobes)
	get_parent().add_child.call_deferred(zone)
	water_zones.append(zone)


## User request: docks out into a few common zones, some with stairs off
## the water end and some with a rowboat moored alongside. Each picks one of
## the four directions whose shore point (where a ray from the zone's origin
## leaves the water) is on open land - inside the map, not in another zone -
## and lays the dock across it, pointing back toward the zone's origin.
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
			var edge: Vector2 = zone.shore_point(d)
			var shore: Vector2 = edge + d * half * 0.6
			if shore.x < DOCK_SHORE_MARGIN or shore.x > Player.WORLD_WIDTH - DOCK_SHORE_MARGIN \
					or shore.y < DOCK_SHORE_MARGIN or shore.y > Player.WORLD_HEIGHT - DOCK_SHORE_MARGIN:
				continue
			if _in_any_water(shore):
				continue
			# The water end must reach past the shallows, or the dock is pointless.
			if not zone.is_deep(edge - d * half * 1.4, 10.0):
				continue
			var dock: Dock = DOCK_SCENE.instantiate()
			# Shore end 30% of the length past the edge, the rest over water.
			dock.position = edge - d * half * 0.4
			var kind: String = ["long_rope", "long", "wide"].pick_random()
			dock.setup(vertical, kind)
			get_parent().add_child.call_deferred(dock)
			_walk_rects.append(dock.walk_rect)
			if randf() < DOCK_BOAT_CHANCE:
				# Moored alongside the water half, bow out toward open water.
				var side := Vector2(d.y, -d.x) * (1.0 if randf() < 0.5 else -1.0)
				var boat: Dock = DOCK_SCENE.instantiate()
				boat.position = dock.position - d * half * 0.35 \
						+ side * (Dock.half_width(vertical, kind) + Dock.boat_half_beam(vertical) + 3.0)
				boat.setup_boat(_dir_name(-d))
				get_parent().add_child.call_deferred(boat)
			if randf() < DOCK_STAIRS_CHANCE:
				# Steps off the water end, leading on toward the center.
				var stairs: Dock = DOCK_SCENE.instantiate()
				stairs.position = dock.position - d * (half + Dock.stairs_half_length(vertical))
				stairs.setup_stairs(_dir_name(-d))
				get_parent().add_child.call_deferred(stairs)
				_walk_rects.append(stairs.walk_rect)
			placed += 1
			break


func _dir_name(v: Vector2) -> String:
	if absf(v.x) < 0.5:
		return "down" if v.y > 0.0 else "up"
	return "right" if v.x > 0.0 else "left"


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
		# Clear of all water now: a common pond's middle is too deep to wade.
		if far_enough and _shore_distance(pos) > 50.0:
			break
	return pos


## Distance to the nearest water (0 when inside it).
func _shore_distance(pos: Vector2) -> float:
	var best := INF
	for zone in water_zones:
		best = minf(best, zone.distance_to_edge(pos))
	return best


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
		# Scene props haven't run _ready yet (this node is Main's first
		# child), so the theme still decides what they become.
		_theme_prop(prop)


func _theme_prop(prop: Node) -> void:
	if "family_weights" in prop:
		prop.family_weights = theme.tree_families
	elif "variant_pool" in prop:
		prop.variant_pool = theme.rock_pool


## The theme's extra trees, rocks and bushes, spaced like the scene props.
func _scatter_themed_props() -> void:
	var placed: Array = []
	for spec in [[TREE_SCENE, theme.trees], [OBSTACLE_SCENE, theme.rocks], [BUSH_SCENE, theme.bushes]]:
		for _i in spec[1]:
			var prop: Node2D = spec[0].instantiate()
			prop.position = _pick_prop_position(placed)
			placed.append(prop.position)
			_theme_prop(prop)
			get_parent().add_child.call_deferred(prop)


## User request: pond edges dressed from the existing art - reed clumps
## (some standing in the shallows), pebbles, the odd boulder and trees along
## the bank, kept off docks and the spawn point; and, now and then, a
## boardwalk laid along a straight-ish stretch of bank.
func _dress_shores() -> void:
	var odds: Dictionary = theme.shore
	for zone in water_zones:
		for sample in zone.shore_samples(SHORE_SPACING):
			var p: Vector2 = sample[0]
			var n: Vector2 = sample[1]
			if p.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN or not _inside_map(p, 24.0) or _near_walkway(p, 26.0):
				continue
			var roll := randf()
			if roll < odds.reeds:
				for _k in randi_range(2, 4):
					var q := p + n * randf_range(-10.0, 12.0) + n.orthogonal() * randf_range(-10.0, 10.0)
					_add_ground_cover(q, "grass")
			elif roll < odds.reeds + odds.pebbles:
				for _k in randi_range(1, 3):
					_add_ground_cover(p + n * randf_range(-4.0, 16.0) + n.orthogonal() * randf_range(-12.0, 12.0), "pebble")
			elif roll < odds.reeds + odds.pebbles + odds.boulder:
				var rock_pos := p + n * randf_range(26.0, 40.0)
				# On an inward bend "outward" can point into another lobe.
				if _shore_distance(rock_pos) < 20.0 or not _inside_map(rock_pos, 40.0):
					continue
				var rock: Node2D = OBSTACLE_SCENE.instantiate()
				rock.position = rock_pos
				rock.variant_pool = theme.rock_pool
				get_parent().add_child.call_deferred(rock)
			elif roll < odds.reeds + odds.pebbles + odds.boulder + odds.tree:
				var pos := p + n * randf_range(40.0, 70.0)
				if _shore_distance(pos) < 25.0 or not _inside_map(pos, 40.0):
					continue
				var tree: Node2D = TREE_SCENE.instantiate()
				tree.position = pos
				tree.family_weights = theme.shore_trees
				get_parent().add_child.call_deferred(tree)
		if not zone.is_rare() and randf() < theme.boardwalk:
			_add_boardwalk(zone)


## A dock piece laid along the bank where the shore faces nearly straight
## up/down/left/right, straddling the waterline.
func _add_boardwalk(zone: WaterZone) -> void:
	var samples: Array = zone.shore_samples(SHORE_SPACING)
	samples.shuffle()
	for sample in samples:
		var p: Vector2 = sample[0]
		var n: Vector2 = sample[1]
		var along_x := absf(n.y) > 0.92  # shore faces up/down: runs sideways
		if not along_x and absf(n.x) < 0.92:
			continue
		var pos := p + n * 6.0
		if pos.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN or not _inside_map(pos, 70.0) or _near_walkway(pos, 70.0):
			continue
		var walk: Dock = DOCK_SCENE.instantiate()
		walk.position = pos
		walk.setup(not along_x, ["long", "long_rope"].pick_random())
		get_parent().add_child.call_deferred(walk)
		_walk_rects.append(walk.walk_rect)
		return


func _add_ground_cover(pos: Vector2, kind: String) -> void:
	var plant: Node2D = GROUND_COVER_SCENE.instantiate()
	plant.position = pos
	plant.kind_override = kind
	get_parent().add_child.call_deferred(plant)


func _inside_map(pos: Vector2, margin: float) -> bool:
	return pos.x > margin and pos.y > margin and pos.x < Player.WORLD_WIDTH - margin and pos.y < Player.WORLD_HEIGHT - margin


func _near_walkway(pos: Vector2, margin: float) -> bool:
	for r in _walk_rects:
		if r.grow(margin).has_point(pos):
			return true
	return false


## Decorative only, so no spacing rules beyond staying out of the water.
func _scatter_ground_cover() -> void:
	for _i in range(theme.ground):
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
		plant.kind_weights = theme.ground_kinds
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
	var fallback := Vector2(-1, -1)
	for _try in range(60):
		var pos := Vector2(
			randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
		)
		if pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		# Clear of the water with room for a rock's footprint or a trunk.
		if _shore_distance(pos) < 30.0:
			continue
		if fallback.x < 0.0:
			fallback = pos
		var too_close := false
		for p in placed:
			if pos.distance_to(p) < PROP_MIN_SEPARATION:
				too_close = true
				break
		if not too_close:
			return pos
	# Crowded: staying out of the water beats the spacing rule.
	return fallback if fallback.x >= 0.0 else Vector2(PROP_MARGIN, PROP_MARGIN)
