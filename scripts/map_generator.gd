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
const WILLOW_BESIDE_ALTAR := Vector2(72.0, 16.0)

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
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const TREE_SCENE := preload("res://scenes/tree.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const FLIP_ROCK_SCENE := preload("res://scenes/flip_rock.tscn")
## User request: rocks the player can turn over for bait, per run.
const FLIP_ROCKS := Vector2i(8, 10)
const BUSH_SCENE := preload("res://scenes/bush.tscn")

## User request: each run is dressed in one of a few looks, all from the
## existing art. A theme sets how many extra trees/rocks/bushes/plants get
## scattered and which kinds (tree families, rock variants - obstacle.gd
## VARIANTS indices, 3-7 are the boulders - and ground-cover kinds).
## User feedback: a forest is one look, not every tree at once - it comes
## in single-colour variants; dead wood gets stone footpaths; the rock pile
## is mostly rocks with a few dead trees.
const THEMES := {
	"forest_pine": {
		"floor": ["forest_floor", "grass", 0.35],
		"trees": 28, "rocks": 3, "bushes": 6, "ground": 110,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 4.0, "clover": 2.0, "plant": 2.0, "mushroom": 3.0, "shrub": 2.0},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 1.5, "wolf": 1.0, "husky": 1.0},
	},
	"forest_birch": {
		"floor": ["grass_light", "grass", 0.3],
		"trees": 26, "rocks": 2, "bushes": 6, "ground": 120,
		"tree_families": {"birch": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 3.0, "flower_group": 2.0, "flower_single": 2.0, "flower_clump": 2.0,
			"flower_petal": 1.0, "shrub": 2.0, "plant": 1.0},
		"animals": {"deer": 2.0, "stag": 1.0, "fox": 1.5, "shiba": 1.0, "white_horse": 1.0},
	},
	"forest_maple": {
		"floor": ["grass", "leaf_litter", 0.45],
		"trees": 24, "rocks": 3, "bushes": 6, "ground": 110,
		"tree_families": {"maple": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 3.0, "clover": 2.0, "flower_bush": 2.0, "mushroom": 2.0, "shrub": 2.0, "plant": 1.0},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 1.5, "shiba": 1.0, "wolf": 0.5},
	},
	"forest_green": {
		"floor": ["grass", "dirt", 0.2],
		"trees": 26, "rocks": 3, "bushes": 8, "ground": 120,
		"tree_families": {"oak": 1.0, "leafy": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 4.0, "clover": 2.0, "plant": 3.0, "shrub": 3.0, "flower_single": 1.0, "mushroom": 1.0},
		"animals": {"cow": 1.5, "bull": 1.0, "horse": 1.0, "deer": 1.0, "shiba": 1.0, "husky": 1.0},
	},
	"deadwood": {
		"floor": ["dirt", "gravel", 0.2],
		"trees": 22, "rocks": 5, "bushes": 2, "ground": 80,
		"tree_families": {"dead": 1.0, "bare": 1.0},
		"rock_pool": [0, 1, 2, 3, 4],
		"ground_kinds": {"grass": 2.0, "mushroom": 3.0, "pebble": 2.0, "plant": 1.0},
		"paths": true,
		"animals": {"wolf": 2.0, "fox": 1.5, "stag": 1.0, "husky": 0.5},
	},
	"rocky": {
		"floor": ["gravel", "dirt", 0.4],
		"trees": 6, "rocks": 26, "bushes": 1, "ground": 100,
		"tree_families": {"dead": 1.0, "bare": 1.0},
		"rock_pool": [0, 1, 2, 3, 4, 5, 6, 7],
		"ground_kinds": {"pebble": 5.0, "grass": 2.0, "clover": 1.0},
		"animals": {"alpaca": 2.0, "donkey": 1.5, "fox": 1.0, "wolf": 1.0},
	},
	# User decision: a tropical look - palms, flowers and sandy ground.
	"tropical": {
		"floor": ["sand", "grass", 0.25],
		"trees": 22, "rocks": 3, "bushes": 5, "ground": 120,
		"tree_families": {"palm": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 2.0, "flower_group": 2.0, "flower_single": 2.0, "flower_clump": 2.0,
			"flower_petal": 2.0, "flower_bush": 1.0, "plant": 2.0, "pebble": 1.0},
		"animals": {"horse": 1.0, "white_horse": 1.0, "alpaca": 1.0, "donkey": 1.0, "shiba": 1.0},
	},
	# User decision: dinosaurs only turn up here, a rare prehistoric look -
	# palms and conifers, ferny plants, boulders.
	"prehistoric": {
		"floor": ["moss_soil", "dirt", 0.3],
		"trees": 20, "rocks": 12, "bushes": 4, "ground": 110,
		"tree_families": {"palm": 2.0, "pine": 1.0, "leafy": 0.5},
		"rock_pool": [0, 1, 2, 3, 4, 5, 6, 7],
		"ground_kinds": {"plant": 5.0, "grass": 3.0, "mushroom": 1.0, "pebble": 2.0, "shrub": 1.0},
		"animals": {"stegosaurus": 1.0, "apatosaurus": 1.0, "parasaurolophus": 1.0, "triceratops": 1.0,
			"trex": 0.6, "velociraptor": 1.0},
	},
}
## Forest looks share one pick with the other styles. User decision: the
## three main styles ~28% each, tropical 12%, prehistoric (dinosaurs) 4%.
const STYLES := {
	"forest": {"weight": 28.0, "themes": ["forest_pine", "forest_birch", "forest_maple", "forest_green"]},
	"deadwood": {"weight": 28.0, "themes": ["deadwood"]},
	"rocky": {"weight": 28.0, "themes": ["rocky"]},
	"tropical": {"weight": 12.0, "themes": ["tropical"]},
	"prehistoric": {"weight": 4.0, "themes": ["prehistoric"]},
}

## User feedback: the water's edge is grass, small shrubs, pebbles and
## boardwalks (no big trees or boulders there), with bugs and frogs about.
## Per shore sample: chance of a grass clump / low shrub / pebbles.
const SHORE_ODDS := {"grass": 0.5, "shrub": 0.16, "pebbles": 0.2}
const SHORE_HIDE_BUSH_CHANCE := 0.25  # of shrubs: a bush you can hide in
const BOARDWALK_CHANCE := 0.8
const SHORE_CRITTERS := ["frog", "frog", "spider", "wasp"]
const SHORE_CRITTER_COUNT := 5

## Dead-wood footpaths: stepping stones every PATH_STEP px, meandering.
const PATH_STEP := 17.0
const PATH_CLEARANCE := 24.0
const PATH_STYLES := [
	["rock_path_1", "rock_path_2", "rock_path_3", "rock_path_round_thin", "rock_path_round_wide"],
	["rock_path_square_1", "rock_path_square_2", "rock_path_square_3", "rock_path_square_thin", "rock_path_square_wide"],
]
const SHORE_SPACING := 26.0
const SHORE_CLEAR_OF_SPAWN := 160.0

## Testing hook: set before Main loads to force a theme (screenshot tools).
static var forced_theme := ""

var theme_name := ""
var theme: Dictionary = {}
var _walk_rects: Array[Rect2] = []
## Just outside each walkway's way on - kept clear of trees and rocks.
var _entrances: Array[Vector2] = []
const ENTRANCE_CLEARANCE := 60.0
var _path_points: Array[Vector2] = []
const CRITTER_SCENE := preload("res://scenes/critter.tscn")
## User decision: 6 catchable critters by day, more come out at night.
const CRITTER_COUNT := 6
const NIGHT_CRITTER_COUNT := 6
## User decision: ambient animals follow the map style, ~8 per map.
const AMBIENT_ANIMAL_COUNT := 8

var water_zones: Array = []


func _ready() -> void:
	theme_name = forced_theme if forced_theme != "" else _pick_theme()
	theme = THEMES[theme_name]
	var ground: CanvasItem = get_parent().get_node_or_null("GroundBackground")
	if ground != null:
		ground.material = _ground_material()
	GameState.night_fell.connect(_on_night_fell)
	_generate_water_zones()
	_place_docks()
	_place_altar_and_escape()
	if theme.get("paths", false):
		_lay_stone_paths()
	# Shores (and their boardwalks) before the trees and rocks, so those can
	# keep clear of every walkway entrance.
	_dress_shores()
	_scatter_props()
	_scatter_themed_props()
	_scatter_flip_rocks()
	_scatter_ground_cover()
	_scatter_critters()


## User request: the ground itself follows the style - "floor" is
## [texture A, texture B, share of B] from assets/sprites/ground (made by
## tools/make_ground.py), blended by shaders/ground.gdshader.
func _ground_material() -> ShaderMaterial:
	var spec: Array = theme.floor
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	for slot in [["a", spec[0]], ["b", spec[1]]]:
		mat.set_shader_parameter("albedo_" + slot[0], load("res://assets/sprites/ground/%s_albedo.png" % slot[1]))
		mat.set_shader_parameter("normal_" + slot[0], load("res://assets/sprites/ground/%s_normal.png" % slot[1]))
	mat.set_shader_parameter("blend_b", spec[2])
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var macro := NoiseTexture2D.new()
	macro.width = 256
	macro.height = 256
	macro.seamless = true
	macro.noise = noise
	mat.set_shader_parameter("macro", macro)
	return mat


func _pick_theme() -> String:
	var total := 0.0
	for style in STYLES.values():
		total += style.weight
	var roll := randf() * total
	for style in STYLES.values():
		roll -= style.weight
		if roll <= 0.0:
			return style.themes.pick_random()
	return STYLES.forest.themes.pick_random()


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
			var stairs_too := randf() < DOCK_STAIRS_CHANCE
			# In from the land end only (and on through to the stairs).
			dock.add_walls([d, -d] if stairs_too else [d])
			_add_entrance(dock.walk_rect, d)
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
			if stairs_too:
				# Steps off the water end, leading on toward the center.
				var stairs: Dock = DOCK_SCENE.instantiate()
				stairs.position = dock.position - d * (half + Dock.stairs_half_length(vertical))
				stairs.setup_stairs(_dir_name(-d))
				stairs.add_walls([d, -d])
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
	# User request: Willow, the harmless NPC, stands beside the altar; the
	# big ghost's cage is a fixed point of its own, away from the rest.
	var willow: Node2D = get_parent().get_node_or_null("Willow")
	if willow != null:
		willow.global_position = altar.global_position + WILLOW_BESIDE_ALTAR
	var cage: Node2D = get_parent().get_node_or_null("GhostCage")
	if cage != null:
		cage.global_position = _pick_fixed_point_position([SPAWN_POS, altar.global_position, escape_point.global_position])


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


func _add_entrance(rect: Rect2, side: Vector2) -> void:
	var c := rect.get_center()
	_entrances.append(c + side * (absf(side.x) * rect.size.x + absf(side.y) * rect.size.y) * 0.5 + side * 20.0)


func _near_entrance(pos: Vector2, margin: float) -> bool:
	for e in _entrances:
		if e.distance_to(pos) < margin:
			return true
	return false


## How far up the bank a point is: negative in the water.
func _land_score(pos: Vector2) -> float:
	var d := _shore_distance(pos)
	return -d if _in_any_water(pos) else d


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


## Spots taken by the themed props (the flip rocks keep clear of them too).
var _themed_spots: Array = []


func _scatter_flip_rocks() -> void:
	for _i in randi_range(FLIP_ROCKS.x, FLIP_ROCKS.y):
		var rock: Node2D = FLIP_ROCK_SCENE.instantiate()
		rock.position = _pick_prop_position(_themed_spots)
		_themed_spots.append(rock.position)
		rock.variant_pool = theme.rock_pool
		get_parent().add_child.call_deferred(rock)


func _theme_prop(prop: Node) -> void:
	if "family_weights" in prop:
		prop.family_weights = theme.tree_families
	elif "variant_pool" in prop:
		prop.variant_pool = theme.rock_pool


## The theme's extra trees, rocks and bushes, spaced like the scene props.
func _scatter_themed_props() -> void:
	var placed: Array = _themed_spots
	for spec in [[TREE_SCENE, theme.trees], [OBSTACLE_SCENE, theme.rocks], [BUSH_SCENE, theme.bushes]]:
		for _i in spec[1]:
			var prop: Node2D = spec[0].instantiate()
			prop.position = _pick_prop_position(placed)
			placed.append(prop.position)
			_theme_prop(prop)
			get_parent().add_child.call_deferred(prop)


## User request: pond edges dressed from the existing art. User feedback:
## grass clumps (some standing in the shallows), low shrubs and pebbles,
## kept off docks, paths and the spawn point; most common ponds also get a
## boardwalk along a straight stretch of bank; frogs and bugs about.
func _dress_shores() -> void:
	for zone in water_zones:
		for sample in zone.shore_samples(SHORE_SPACING):
			var p: Vector2 = sample[0]
			var n: Vector2 = sample[1]
			if p.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN or not _inside_map(p, 24.0) \
					or _near_walkway(p, 26.0) or _near_path(p, PATH_CLEARANCE):
				continue
			var roll := randf()
			if roll < SHORE_ODDS.grass:
				for _k in randi_range(2, 4):
					_add_ground_cover(p + n * randf_range(-10.0, 12.0) + n.orthogonal() * randf_range(-10.0, 10.0), "grass")
			elif roll < SHORE_ODDS.grass + SHORE_ODDS.shrub:
				var pos := p + n * randf_range(10.0, 26.0)
				if _shore_distance(pos) < 6.0:
					continue
				if randf() < SHORE_HIDE_BUSH_CHANCE:
					var bush: Node2D = BUSH_SCENE.instantiate()
					bush.position = pos + n * 10.0
					get_parent().add_child.call_deferred(bush)
				else:
					_add_ground_cover(pos, ["shrub", "flower_bush"].pick_random())
			elif roll < SHORE_ODDS.grass + SHORE_ODDS.shrub + SHORE_ODDS.pebbles:
				for _k in randi_range(1, 3):
					_add_ground_cover(p + n * randf_range(-4.0, 16.0) + n.orthogonal() * randf_range(-12.0, 12.0), "pebble")
		if not zone.is_rare() and randf() < BOARDWALK_CHANCE:
			_add_boardwalk(zone)
	_add_shore_critters()


## Catchable frogs and bugs hanging about the water's edge.
func _add_shore_critters() -> void:
	var zones: Array = water_zones.filter(func(z): return not z.is_rare())
	if zones.is_empty():
		return
	for _i in SHORE_CRITTER_COUNT:
		var zone: WaterZone = zones.pick_random()
		var samples: Array = zone.shore_samples(60.0)
		if samples.is_empty():
			continue
		var sample: Array = samples.pick_random()
		var pos: Vector2 = sample[0] + sample[1] * randf_range(14.0, 30.0)
		if _shore_distance(pos) < 6.0 or pos.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN:
			continue
		var critter: Critter = CRITTER_SCENE.instantiate()
		critter.species = SHORE_CRITTERS.pick_random()
		critter.position = pos
		get_parent().add_child.call_deferred(critter)


## User feedback: dead wood gets proper footpaths - a meandering line of
## stepping stones in one style from the spawn clearing to the bank of
## each common pond, not stray stones.
func _lay_stone_paths() -> void:
	for zone in water_zones:
		if zone.is_rare():
			continue
		var style: Array = PATH_STYLES.pick_random()
		var dir: Vector2 = (zone.global_position - SPAWN_POS).normalized()
		var start := SPAWN_POS + dir * 70.0
		# End on the bank just short of the water, facing the spawn.
		var end: Vector2 = zone.shore_point(-dir) - dir * 12.0
		var length := start.distance_to(end)
		if length < 60.0:
			continue
		var side := dir.orthogonal()
		var amp := randf_range(18.0, 45.0)
		var waves := randf_range(1.0, 2.5)
		var phase := randf() * TAU
		var steps := int(length / PATH_STEP)
		for i in range(steps + 1):
			var t := float(i) / steps
			# Meander, pinned straight at both ends.
			var sway := sin(t * PI * waves + phase) * amp * sin(t * PI)
			var p := start.lerp(end, t) + side * sway
			if _shore_distance(p) < 4.0 or not _inside_map(p, 20.0):
				continue
			_path_points.append(p)
			var stone: Node2D = GROUND_COVER_SCENE.instantiate()
			stone.position = p + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
			stone.kind_override = "path_stone"
			stone.variant_choices = style
			get_parent().add_child.call_deferred(stone)


func _near_path(pos: Vector2, margin: float) -> bool:
	for p in _path_points:
		if p.distance_to(pos) < margin:
			return true
	return false


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
		if pos.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN or not _inside_map(pos, 70.0) or _near_walkway(pos, 70.0) \
				or _near_path(pos, 40.0):
			continue
		var walk: Dock = DOCK_SCENE.instantiate()
		walk.position = pos
		walk.setup(not along_x, ["long", "long_rope"].pick_random())
		# One way on: whichever end sits further up the bank.
		var axis := Vector2.RIGHT if along_x else Vector2.DOWN
		var reach: float = Dock.half_length(not along_x)
		var end_a := pos + axis * reach
		var end_b := pos - axis * reach
		var way_on := axis if _land_score(end_a) >= _land_score(end_b) else -axis
		walk.add_walls([way_on])
		_add_entrance(walk.walk_rect, way_on)
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
			if not _in_any_water(pos) and not _near_path(pos, 14.0):
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
	# User request: larger ambient animals (cows, a deer...) as scenery,
	# the kinds picked by the map style.
	for _i in range(AMBIENT_ANIMAL_COUNT):
		var animal: Critter = CRITTER_SCENE.instantiate()
		animal.ambient = true
		animal.species = _weighted_pick(theme.animals)
		animal.position = _pick_prop_position([])
		get_parent().add_child.call_deferred(animal)


## Extra catchable critters come out at nightfall, away from the player.
func _on_night_fell() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	for _i in range(NIGHT_CRITTER_COUNT):
		var pos := _pick_prop_position([])
		for _try in range(6):
			if player == null or pos.distance_to(player.global_position) > 250.0:
				break
			pos = _pick_prop_position([])
		var critter: Node2D = CRITTER_SCENE.instantiate()
		critter.position = pos
		get_parent().add_child(critter)


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return weights.keys()[0]


func _pick_prop_position(placed: Array) -> Vector2:
	var fallback := Vector2(-1, -1)
	for _try in range(60):
		var pos := Vector2(
			randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
		)
		if pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		# Clear of the water with room for a rock's footprint or a trunk,
		# and off any footpath.
		if _shore_distance(pos) < 30.0 or _near_path(pos, PATH_CLEARANCE + 10.0):
			continue
		# User bug report: rocks were landing across a boardwalk's way on.
		if _near_entrance(pos, ENTRANCE_CLEARANCE) or _near_walkway(pos, 30.0):
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
