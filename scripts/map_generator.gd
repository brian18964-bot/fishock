class_name MapGenerator
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
## The middle of the map: the full map's, or a smaller one's (Campaign).
static var SPAWN_POS := Vector2(1200.0, 700.0)
const SPAWN_CLEAR_RADIUS := 220.0

const FIXED_POINT_MARGIN := 150.0
const FIXED_POINT_MIN_SEPARATION := 550.0
const WILLOW_BESIDE_ALTAR := Vector2(72.0, 16.0)
## How far out the willow stands from the altar's middle (Willow.FRONT
## and its own breadth).
const WILLOW_RING := 66.0

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
## User request (3D): nothing in anything, nothing crowded. Every solid
## thing placed keeps this much ground (px) between its base and the next
## one's - room to walk between; trees keep their branches clear of each
## other's and of the camp, the altar, the stones and the bank.
const PROP_GAP := 34.0
## Branches clear of the water's edge by this much more (the rod's swing).
const BANK_CLEAR := 40.0
const PROP_AVOID_SPAWN_RADIUS := 180.0

const DOCK_SCENE := preload("res://scenes/dock.tscn")
## Every common pond gets one, and this share of them a second.
const SECOND_DOCK_CHANCE := 0.5
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
const NOT_FLIPPABLE := ["pillar", "grave", "lantern", "shrine", "well", "lp_grave", "lp_lantern", "lp_shrine", "lp_well",
	"bones"]
const BUSH_SCENE := preload("res://scenes/bush.tscn")

## User decision: one place for now - the lakeside pine forest (in 3D,
## RunView3D), polished before the next opens. How many extra trees,
## rocks, bushes and plants it scatters and which kinds. User request: not
## crowded - few small things.
const THEME := "forest_pine"
const THEMES := {
	"forest_pine": {
		"look": "detailed",
		"floor": ["forest_floor", "grass", 0.35],
		"trees": 28, "rocks": 3, "bushes": 4, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"plant": 1.0},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 1.5, "wolf": 1.0, "husky": 1.0},
	},}
## User feedback: the water's edge is grass, small shrubs, pebbles and
## boardwalks (no big trees or boulders there), with bugs and frogs about.
## Per shore sample: chance of a grass clump / low shrub / pebbles.
const SHORE_ODDS := {"grass": 0.0, "shrub": 0.0, "pebbles": 0.0}
## User request (water plants): per shore sample, on top of the above - a
## reed clump at the waterline, lily pads out on the water, a washed-up
## log. Themes override with "shore_extras".
const SHORE_EXTRAS := {"reeds": 0.0, "lilypad": 0.05, "driftwood": 0.0}
const SHORE_HIDE_BUSH_CHANCE := 0.25  # of shrubs: a bush you can hide in
const SHORE_CRITTERS := ["frog", "frog", "spider", "wasp"]
const SHORE_CRITTER_COUNT := 5

const SHORE_SPACING := 26.0
const SHORE_CLEAR_OF_SPAWN := 160.0


var theme_name := ""
var theme: Dictionary = {}
var _walk_rects: Array[Rect2] = []
## Just outside each walkway's way on - kept clear of trees and rocks.
var _entrances: Array[Vector2] = []
const ENTRANCE_CLEARANCE := 60.0
const CRITTER_SCENE := preload("res://scenes/critter.tscn")
## User decision: 6 catchable critters by day, more come out at night.
const CRITTER_COUNT := 6
const NIGHT_CRITTER_COUNT := 6
## User decision: ambient animals follow the map style, ~8 per map.
const AMBIENT_ANIMAL_COUNT := 8

var water_zones: Array = []


func _ready() -> void:
	theme_name = THEME
	theme = THEMES[theme_name].duplicate(true)
	_fit_theme()
	# User request (the campaign): maps of three sizes - the floor, the
	# camp and the player's start go where this one's middle is.
	var ground: CanvasItem = get_parent().get_node_or_null("GroundBackground")
	if ground is Control:
		ground.size = Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT)
	for start in ["Player", "FuelStation"]:
		var node: Node2D = get_parent().get_node_or_null(start)
		if node != null:
			node.position = SPAWN_POS
	if ground != null:
		ground.material = _ground_material()
	var darkness := get_parent().get_node_or_null("Darkness")
	if darkness != null and "tint" in darkness:
		darkness.tint = theme.get("tint", Color.WHITE)
	WaterZone.theme_water = theme.get("water", {})
	FishData.waters = FishData.waters_for_theme(theme_name)
	GameState.night_fell.connect(_on_night_fell)
	_generate_water_zones()
	_place_docks()
	_place_altar_and_escape()
	_take_fixed_points()
	# Docks and shores before the trees and rocks, so those can keep clear
	# of every walkway entrance.
	_dress_shores()
	_scatter_props()
	_scatter_themed_props()
	_scatter_flip_rocks()
	_scatter_ground_cover()
	_scatter_critters()


## A smaller map (the campaign's) gets fewer trees, rocks, plants and
## animals, so it's as thick with them as the full one; a level without
## beasts has none of the hunters, and one may bring its own (rules.beasts).
func _fit_theme() -> void:
	var share := Campaign.area_share()
	for key in ["trees", "rocks", "bushes", "ground"]:
		theme[key] = int(roundf(float(theme.get(key, 0)) * share))
	theme["animal_count"] = maxi(2, int(roundf(float(theme.get("animal_count", AMBIENT_ANIMAL_COUNT)) * share)))
	var animals: Dictionary = theme.animals.duplicate()
	if not Campaign.rules.hunters:
		for kind in animals.keys():
			if Critter.SPECIES.get(kind, {}).has("chase_speed"):
				animals.erase(kind)
	var beasts: Dictionary = Campaign.rules.beasts
	for kind in beasts:
		animals[kind] = float(beasts[kind])
	if animals.is_empty():
		animals = {"fox": 1.0, "deer": 1.0}
	theme["animals"] = animals


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



func _generate_water_zones() -> void:
	WaterZone.sea_backing = []
	# The rare one first: it's smaller and solid, so it gets its pick.
	var ponds: Array = Campaign.rules.ponds
	var k := _pond_scale()
	for _i in range(int(ponds[1])):
		_spawn_zone(WaterZone.ZoneType.RARE, randf_range(RARE_RADIUS_MIN, RARE_RADIUS_MAX) * k, RARE_EXTRA_LOBES)
	var commons := int(ponds[0])
	if commons < 0:
		commons = randi_range(COMMON_ZONE_COUNT.x, COMMON_ZONE_COUNT.y)
	for _i in range(commons):
		_spawn_zone(WaterZone.ZoneType.COMMON, randf_range(COMMON_RADIUS_MIN, COMMON_RADIUS_MAX) * k, COMMON_EXTRA_LOBES)


## Ponds (and the room kept round the start) shrink a little on a smaller
## map (the campaign's), so they fit with land to walk round them.
static func _pond_scale() -> float:
	var k := sqrt(Campaign.area_share())
	# (the 3D run's bigger map: its ponds bigger with it)
	return k if k > 1.0 else clampf(k, 0.72, 1.0)


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
	# User bug report: the spawn point ended up under water (about 1 map in
	# 25) - when no spot was found, the last random one was used anyway. Now
	# a pond that doesn't fit shrinks and tries again, and is left out if it
	# still doesn't.
	var pos := Vector2.INF
	for _shrink in 3:
		var bounds := radius
		for lobe in lobes:
			bounds = maxf(bounds, Vector2(lobe.x, lobe.y).length() + lobe.z)
		pos = _pick_zone_position(bounds)
		if pos != Vector2.INF:
			break
		radius *= 0.85
		for k in lobes.size():
			lobes[k] = Vector3(lobes[k].x * 0.85, lobes[k].y * 0.85, lobes[k].z * 0.85)
	if pos == Vector2.INF:
		return
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
	# User request: every common pond gets a dock out into deep water (some
	# get two, on different sides) - no boardwalks lying along the bank.
	var jobs := []
	for zone in commons:
		jobs.append(zone)
	for zone in commons:
		if randf() < SECOND_DOCK_CHANCE:
			jobs.append(zone)
	var used := {}
	for zone in jobs:
		var dirs := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
		dirs.shuffle()
		for d in dirs:
			if d in used.get(zone, []):
				continue
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
			used.get_or_add(zone, []).append(d)
			break



func _dir_name(v: Vector2) -> String:
	if absf(v.x) < 0.5:
		return "down" if v.y > 0.0 else "up"
	return "right" if v.x > 0.0 else "left"


## A spot for a pond this big, clear of the spawn point and the other
## ponds; Vector2.INF if there's none.
func _pick_zone_position(radius: float) -> Vector2:
	for _try in range(60):
		var pos := Vector2(
			randf_range(ZONE_MARGIN + radius, Player.WORLD_WIDTH - ZONE_MARGIN - radius),
			randf_range(ZONE_MARGIN + radius, Player.WORLD_HEIGHT - ZONE_MARGIN - radius)
		)
		if pos.distance_to(SPAWN_POS) < SPAWN_CLEAR_RADIUS * _pond_scale() + radius:
			continue
		var overlaps := false
		for zone in water_zones:
			if pos.distance_to(zone.global_position) < radius + zone.radius + ZONE_MIN_GAP:
				overlaps = true
				break
		if not overlaps:
			return pos
	return Vector2.INF


func _place_altar_and_escape() -> void:
	var altar: Node2D = get_parent().get_node("Altar")
	var escape_point: Node2D = get_parent().get_node("EscapePoint")

	altar.global_position = _pick_fixed_point_position([SPAWN_POS])
	escape_point.global_position = _pick_fixed_point_position([SPAWN_POS, altar.global_position])
	# User request: Willow, the harmless NPC, stands beside the altar; the
	# big ghost's cage is a fixed point of its own, away from the rest.
	var willow: Node2D = get_parent().get_node_or_null("Willow")
	if willow != null:
		willow.global_position = altar.global_position + Willow.FRONT
	var cage: Node2D = get_parent().get_node_or_null("GhostCage")
	if cage != null:
		cage.global_position = _pick_fixed_point_position([SPAWN_POS, altar.global_position, escape_point.global_position])


func _pick_fixed_point_position(avoid: Array) -> Vector2:
	# Clear of all water (a common pond's middle is too deep to wade) and
	# far from the other fixed points. If nothing meets both, the spot that
	# comes closest - never one at the water's edge (it used to take the
	# last random try, which could be in a pond).
	var best := Vector2(Player.WORLD_WIDTH * 0.5, FIXED_POINT_MARGIN)
	var best_score := -INF
	# Closer together on a smaller map (the campaign's).
	var separation := FIXED_POINT_MIN_SEPARATION * minf(1.0, sqrt(Campaign.area_share()))
	for _try in range(60):
		var pos := Vector2(
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_WIDTH - FIXED_POINT_MARGIN),
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_HEIGHT - FIXED_POINT_MARGIN)
		)
		var spread := INF
		for p in avoid:
			spread = minf(spread, pos.distance_to(p))
		var shore := _shore_distance(pos)
		if spread >= separation and shore > 50.0:
			return pos
		var score := minf(spread / separation, 1.0) + (1.0 if shore > 50.0 else -2.0)
		if score > best_score:
			best_score = score
			best = pos
	return best


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
	for prop_name in PROP_NAMES:
		var prop: Node2D = get_parent().get_node_or_null(prop_name)
		if prop == null:
			continue
		# Scene props haven't run _ready yet (this node is Main's first
		# child), so the theme still decides what they become.
		_theme_prop(prop)
		var size := _footprint(prop)
		var pos := _pick_prop_position(size[0], size[1])
		if pos.x < 0.0:
			# (no room left that keeps clear of everything: not placed)
			prop.queue_free()
			continue
		prop.global_position = pos
		_taken.append([pos, size[0], size[1]])
	# The fuel can lying about (picked up and carried home).
	var can := get_parent().get_node_or_null("OilDrum") as Node2D
	if can != null:
		var at := _pick_prop_position(16.0, 0.0)
		if at.x >= 0.0:
			can.global_position = at
			_taken.append([at, 16.0, 0.0])


## The camp, the altar (and the willow's walk round it), the rune stones
## and the big ghost's lair: kept clear by everything.
func _take_fixed_points() -> void:
	var camp := get_parent().get_node_or_null("FuelStation") as Node2D
	if camp != null:
		for b in FuelStation.solids_local():
			var r: Vector2 = b[1]
			var reach := maxf(r.x, r.y) * (1.0 if is_equal_approx(r.x, r.y) else 1.42)
			_taken.append([camp.global_position + b[0], reach, reach + 40.0])
		# (and the player's start, with room to turn round)
		_taken.append([camp.global_position, 30.0, 0.0])
	var altar := get_parent().get_node_or_null("Altar") as Node2D
	if altar != null:
		var walk: float = WILLOW_RING + 16.0
		_taken.append([altar.global_position, walk, walk])
	var escape := get_parent().get_node_or_null("EscapePoint") as Node2D
	if escape != null:
		_taken.append([escape.global_position, 50.0, 60.0])
	var cage := get_parent().get_node_or_null("GhostCage") as Node2D
	if cage != null:
		_taken.append([cage.global_position, 60.0, 60.0])


## A prop's [base radius, branch reach] (px), its kind already chosen.
func _footprint(prop: Node) -> Array:
	if prop is MapTree:
		var t := prop as MapTree
		if not t.picked:
			t.pick(randi())
		return [float(MapTree.KINDS[t.kind]) * t.tree_scale * MapTree.PX, MapTree.canopy_of(t.kind, t.tree_scale)]
	if prop is Obstacle:
		var biggest := 0.0
		for k in Obstacle.KINDS:
			biggest = maxf(biggest, maxf(k.base.x, k.base.y) * 0.5)
		return [biggest, 0.0]
	if prop is FlipRock:
		# (and where it rolls to when it's turned)
		return [Obstacle.KINDS[1].base.x * 0.5 * FlipRock.SIZE + FlipRock.ROLL_DISTANCE.y, 0.0]
	if "families" in prop:
		return [24.0, 0.0]
	return [20.0, 0.0]


## Everything solid placed so far: [centre, base radius, branch reach]
## (px; reach 0 for what has no branches). See _fits().
var _taken: Array = []


func _scatter_flip_rocks() -> void:
	var count: Array = Campaign.rules.rocks
	for _i in randi_range(int(count[0]), int(count[1])):
		var rock: Node2D = FLIP_ROCK_SCENE.instantiate()
		var size := _footprint(rock)
		var at := _pick_prop_position(size[0], size[1])
		if at.x < 0.0:
			rock.free()
			continue
		rock.position = at
		_taken.append([at, size[0], size[1]])
		# Small stones to turn over - not the standing slabs or the props.
		rock.variant_pool = theme.rock_pool.filter(func(e): return not (e is String and e in NOT_FLIPPABLE))
		get_parent().add_child.call_deferred(rock)


func _theme_prop(prop: Node) -> void:
	if "family_weights" in prop:
		prop.family_weights = theme.tree_families
	elif "variant_pool" in prop:
		prop.variant_pool = theme.rock_pool
		prop.modulate = theme.get("rock_tint", Color.WHITE)
	elif "families" in prop:
		prop.families = theme.get("bush_families", [])


## The theme's extra trees, rocks and bushes, spaced like the scene props.
func _scatter_themed_props() -> void:
	for spec in [[TREE_SCENE, theme.trees], [OBSTACLE_SCENE, theme.rocks], [BUSH_SCENE, theme.bushes]]:
		for _i in spec[1]:
			var prop: Node2D = spec[0].instantiate()
			_theme_prop(prop)
			var size := _footprint(prop)
			var at := _pick_prop_position(size[0], size[1])
			if at.x < 0.0:
				prop.free()
				continue
			prop.position = at
			_taken.append([at, size[0], size[1]])
			get_parent().add_child.call_deferred(prop)


## User request: pond edges dressed from the existing art. User feedback:
## grass clumps (some standing in the shallows), low shrubs and pebbles,
## kept off docks, paths and the spawn point; most common ponds also get a
## dock out into deep water (see _place_docks); frogs and bugs about.
func _dress_shores() -> void:
	for zone in water_zones:
		for sample in zone.shore_samples(SHORE_SPACING):
			var p: Vector2 = sample[0]
			var n: Vector2 = sample[1]
			if p.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN or not _inside_map(p, 24.0) \
					or _near_walkway(p, 26.0):
				continue
			# Where zones overlap (the sea's), a zone's own shore can lie
			# out in the other's water.
			if water_zones.any(func(z): return z != zone and z.depth(p) > 2.0):
				continue
			var extras: Dictionary = theme.get("shore_extras", SHORE_EXTRAS)
			if not zone.is_rare() and randf() < extras.get("lilypad", 0.0):
				var pad := p - n * randf_range(16.0, 44.0) + n.orthogonal() * randf_range(-10.0, 10.0)
				if zone.contains(pad) and not _near_walkway(pad, 20.0):
					_add_ground_cover(pad, "lilypad")
			if randf() < extras.get("reeds", 0.0):
				_add_ground_cover(p + n * randf_range(-10.0, 6.0) + n.orthogonal() * randf_range(-6.0, 6.0), "reeds")
			if randf() < extras.get("driftwood", 0.0):
				var log_pos := p + n * randf_range(8.0, 20.0)
				if _shore_distance(log_pos) > 4.0:
					_add_ground_cover(log_pos, "driftwood")
			var roll := randf()
			var odds: Dictionary = theme.get("shore", SHORE_ODDS)
			if roll < odds.grass:
				for _k in randi_range(2, 4):
					_add_ground_cover(p + n * randf_range(-10.0, 12.0) + n.orthogonal() * randf_range(-10.0, 10.0), "grass")
			elif roll < odds.grass + odds.shrub:
				var pos := p + n * randf_range(10.0, 26.0)
				if _shore_distance(pos) < 6.0:
					continue
				if randf() < SHORE_HIDE_BUSH_CHANCE and _fits(pos + n * 10.0, 24.0, 0.0):
					var bush: Node2D = BUSH_SCENE.instantiate()
					bush.position = pos + n * 10.0
					_taken.append([bush.position, 24.0, 0.0])
					_theme_prop(bush)
					get_parent().add_child.call_deferred(bush)
				else:
					_add_ground_cover(pos, "shrub")
			elif roll < odds.grass + odds.shrub + odds.pebbles:
				for _k in randi_range(1, 3):
					_add_ground_cover(p + n * randf_range(-4.0, 16.0) + n.orthogonal() * randf_range(-12.0, 12.0), "pebble")
	_add_shore_critters()


## Catchable frogs and bugs hanging about the water's edge.
func _add_shore_critters() -> void:
	var zones: Array = water_zones.filter(func(z): return not z.is_rare())
	if zones.is_empty():
		return
	for _i in theme.get("shore_critter_count", SHORE_CRITTER_COUNT):
		var zone: WaterZone = zones.pick_random()
		var samples: Array = zone.shore_samples(60.0)
		if samples.is_empty():
			continue
		var sample: Array = samples.pick_random()
		var pos: Vector2 = sample[0] + sample[1] * randf_range(14.0, 30.0)
		if _shore_distance(pos) < 6.0 or pos.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN:
			continue
		var critter: Critter = CRITTER_SCENE.instantiate()
		critter.species = theme.get("shore_critters", SHORE_CRITTERS).pick_random()
		critter.position = pos
		get_parent().add_child.call_deferred(critter)



func _add_ground_cover(pos: Vector2, kind: String) -> void:
	var plant: Node2D = GROUND_COVER_SCENE.instantiate()
	plant.position = pos
	# The theme's look's own version of a generic plant (see THEMES).
	plant.kind_override = theme.get("cover", {}).get(kind, kind)
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
	for _i in range(int(Campaign.rules.critters)):
		var pos := _pick_prop_position(12.0, 0.0)
		if pos.x < 0.0:
			continue
		var critter: Node2D = CRITTER_SCENE.instantiate()
		critter.position = pos
		# Main is still mid-setup here; see _spawn_zone().
		get_parent().add_child.call_deferred(critter)
	# User request: larger ambient animals (cows, a deer...) as scenery,
	# the kinds picked by the map style.
	for _i in range(theme.get("animal_count", AMBIENT_ANIMAL_COUNT)):
		var animal: Critter = CRITTER_SCENE.instantiate()
		animal.ambient = true
		animal.species = _weighted_pick(theme.animals)
		var spot := _pick_prop_position(26.0, 0.0)
		if spot.x < 0.0:
			animal.free()
			continue
		animal.position = spot
		get_parent().add_child.call_deferred(animal)


## Extra catchable critters come out at nightfall, away from the player.
func _on_night_fell() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	for _i in range(int(roundf(NIGHT_CRITTER_COUNT * Campaign.area_share()))):
		var pos := _pick_prop_position(12.0, 0.0)
		for _try in range(6):
			if player == null or pos.distance_to(player.global_position) > 250.0:
				break
			pos = _pick_prop_position(12.0, 0.0)
		if pos.x < 0.0:
			continue
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


## Somewhere for a thing of base radius `base` and branch reach `reach`
## (px): on land, off the paths and the docks' ways on, clear of
## everything placed (_fits); (-1, -1) if there's no such place.
func _pick_prop_position(base: float, reach: float) -> Vector2:
	for _try in range(80):
		var pos := Vector2(
			randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
		)
		if pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		# Clear of the water with room for its base - and its branches
		# clear of the bank, where the rod swings.
		var shore := _shore_distance(pos)
		if shore < maxf(30.0, base + 8.0) or (reach > 0.0 and shore < reach + BANK_CLEAR):
			continue
		# User bug report: rocks were landing across a boardwalk's way on.
		if _near_entrance(pos, ENTRANCE_CLEARANCE) or _near_walkway(pos, maxf(30.0, reach)):
			continue
		if _fits(pos, base, reach):
			return pos
	return Vector2(-1, -1)


## Whether a thing at `pos` (base radius, branch reach; px) keeps clear of
## everything placed: bases PROP_GAP apart; branches clear of branches.
func _fits(pos: Vector2, base: float, reach: float) -> bool:
	for t in _taken:
		var d := pos.distance_to(t[0])
		if d < base + float(t[1]) + PROP_GAP:
			return false
		if reach > 0.0 and float(t[2]) > 0.0 and d < reach + float(t[2]):
			return false
	return true
