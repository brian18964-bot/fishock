class_name TownBuilder
extends RefCounted

## User request: a post-apocalyptic town - "a town nature has taken back,
## fishing in its flooded streets" - laid out like real ones (after games
## like Project Zomboid and ruined-city environment packs): a grid of
## streets with a main street through the middle, the gas station (the
## spawn point) on it; shops and concrete blocks along the main street,
## small wooden houses on the side streets; empty, overgrown lots between
## them fenced with chain-link; cars left where they stopped - jammed in a
## line as if fleeing, or abandoned at the kerb - a checkpoint of barriers
## and barrels across one crossing; lamps, poles, hydrants, signs, bus
## stops, dumpsters and trash along the pavements. The ponds are where the
## streets flooded: roads run on under the water.
##
## Built by MapGenerator for a theme with "town": the streets are painted
## into a world map the ground shader lays asphalt and paving from
## (red road, green pavement, blue road paint); buildings, wrecks and
## junk are RuinProps (RuinsCatalog). blocked() tells the generator's
## other scatterers where not to put a tree.

const RUIN_SCENE := preload("res://scripts/ruin_prop.gd")
const MAIN_WIDTH := 78.0
const SIDE_WIDTH := 58.0
const PAVEMENT := 18.0
const MASK_SCALE := 0.5            # mask texels per world px
const CLEAR_OF_FIXED := 130.0      # around the gas station, altar, escape, cage
const WATER_MARGIN := 14.0
## Along the main street: shops and blocks; elsewhere: houses mostly.
const MAIN_BUILDINGS := {"shop": 3.0, "block": 3.0, "facade": 1.0}
const SIDE_BUILDINGS := {"house": 3.0, "house_dark": 2.0, "house_ruin": 1.5, "shop": 0.6, "facade": 0.6}
const CARS := ["hatchback", "van", "van_ivy", "sports", "sports_ivy"]

var gen: Node          # MapGenerator
var world := Vector2(2400.0, 1350.0)
## [start, end, width] per road: horizontal ones at y, vertical at x.
var h_roads: Array = []
var v_roads: Array = []
var road_rects: Array[Rect2] = []
var walk_rects: Array[Rect2] = []
var paved_rects: Array[Rect2] = []  # paved but not pavement (the forecourt)
var _taken: Array[Rect2] = []      # footprints placed so far (grown a little)
var _behind: Array[Rect2] = []     # what the buildings' walls and roofs cover
var _fixed: Array[Vector2] = []
var props: Array = []


func _init(generator: Node) -> void:
	gen = generator
	world = Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT)


func build(parent: Node) -> void:
	_fixed = [MapGenerator.SPAWN_POS]
	for name in ["Altar", "EscapePoint", "GhostCage"]:
		var n: Node2D = parent.get_node_or_null(name)
		if n != null:
			_fixed.append(n.global_position)
	_lay_streets()
	_open_gas_station(parent)
	_signal_crossings(parent)
	_line_streets_with_buildings(parent)
	_abandon_cars(parent)
	_furnish_pavements(parent)
	_set_up_checkpoint(parent)
	_build_playground(parent)
	_fill_empty_lots(parent)


## Where the generator shouldn't put a tree or a rock: roads and anything
## built.
func blocked(pos: Vector2, margin: float) -> bool:
	for r in road_rects:
		if r.grow(margin).has_point(pos):
			return true
	for r in _taken:
		if r.grow(margin).has_point(pos):
			return true
	# A tree or bush behind a building would poke out over its roof.
	for r in _behind:
		if r.has_point(pos):
			return true
	return false


# --- Streets -------------------------------------------------------------------

func _lay_streets() -> void:
	var spawn := MapGenerator.SPAWN_POS
	# The main street just south of the gas station; one north, maybe one south.
	h_roads.append([0.0, world.x, spawn.y + 95.0, MAIN_WIDTH])
	h_roads.append([0.0, world.x, randf_range(210.0, 300.0), SIDE_WIDTH])
	if randf() < 0.65:
		h_roads.append([0.0, world.x, randf_range(1130.0, 1220.0), SIDE_WIDTH])
	var ys: Array = h_roads.map(func(r): return r[2])
	ys.sort()
	var x := randf_range(230.0, 380.0)
	while x < world.x - 150.0:
		# Not straight through the gas station.
		if absf(x - spawn.x) < 150.0:
			x = spawn.x + 150.0 * signf(x - spawn.x + 0.01)
		var bounds: Array = [0.0] + ys + [world.y]
		for i in bounds.size() - 1:
			# Some stretches are gone (collapsed, or never were).
			if randf() < 0.82:
				v_roads.append([bounds[i], bounds[i + 1], x, SIDE_WIDTH])
		x += randf_range(500.0, 660.0)
	for r in h_roads:
		road_rects.append(Rect2(r[0], r[2] - r[3] / 2.0, r[1] - r[0], r[3]))
		walk_rects.append(Rect2(r[0], r[2] - r[3] / 2.0 - PAVEMENT, r[1] - r[0], r[3] + PAVEMENT * 2.0))
	for r in v_roads:
		road_rects.append(Rect2(r[2] - r[3] / 2.0, r[0], r[3], r[1] - r[0]))
		walk_rects.append(Rect2(r[2] - r[3] / 2.0 - PAVEMENT, r[0], r[3] + PAVEMENT * 2.0, r[1] - r[0]))


## The street map for the ground shader.
func street_map() -> ImageTexture:
	var size := Vector2i(world * MASK_SCALE)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for r in walk_rects + paved_rects:
		img.fill_rect(_mask_rect(r), Color(0, 1, 0, 1))
	for r in road_rects:
		img.fill_rect(_mask_rect(r), Color(1, 0, 0, 1))
	# Paint: dashes down the middle of the main street, zebra crossings
	# where the side streets meet it.
	var main: Array = h_roads[0]
	var x := 10.0
	while x < world.x:
		img.fill_rect(_mask_rect(Rect2(x, main[2] - 1.5, 26.0, 3.0)), Color(1, 0, 1, 1))
		x += 48.0
	for v in v_roads:
		if absf(v[0] - main[2]) < 1.0 or absf(v[1] - main[2]) < 1.0:
			for side in [-1.0, 1.0]:
				var y0: float = main[2] + side * (main[3] / 2.0 + 10.0)
				var bx: float = v[2] - v[3] / 2.0 + 4.0
				while bx < v[2] + v[3] / 2.0 - 6.0:
					img.fill_rect(_mask_rect(Rect2(bx, y0 - 8.0, 5.0, 16.0)), Color(1, 0, 1, 1))
					bx += 10.0
	return ImageTexture.create_from_image(img)


func _mask_rect(r: Rect2) -> Rect2i:
	return Rect2i(Vector2i(r.position * MASK_SCALE), Vector2i((r.size * MASK_SCALE).ceil()))


# --- Placing things ---------------------------------------------------------------

## Is a footprint (world rect) clear to build on?
func _clear(rect: Rect2, keep_off_roads := true, near_spawn := false) -> bool:
	if rect.position.x < 8.0 or rect.position.y < 8.0 or rect.end.x > world.x - 8.0 or rect.end.y > world.y - 8.0:
		return false
	if keep_off_roads:
		for r in walk_rects:
			if r.intersects(rect):
				return false
	for r in _taken:
		if r.intersects(rect):
			return false
	for p in _fixed:
		if near_spawn and p == MapGenerator.SPAWN_POS:
			continue
		if rect.grow(CLEAR_OF_FIXED).has_point(p):
			return false
	for pt in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y),
			rect.get_center()]:
		if gen._shore_distance(pt) < WATER_MARGIN or gen._near_walkway(pt, 20.0) or gen._near_entrance(pt, 40.0):
			return false
	# Nothing standing in the water.
	for zone in gen.water_zones:
		if zone.contains(rect.get_center()):
			return false
	return true


func _spawn(parent: Node, e: Dictionary, pos: Vector2) -> Node2D:
	var prop: StaticBody2D = RUIN_SCENE.new()
	prop.entry = e
	prop.position = pos
	parent.add_child.call_deferred(prop)
	props.append(prop)
	return prop


## Tries to put `e` with its base's bounding box at `rect_at` (a function
## of the base rect giving the node position); records it if it fits.
func _try_place(parent: Node, e: Dictionary, pos: Vector2, keep_off_roads := true, pad := 4.0,
		near_spawn := false) -> bool:
	var fp := RuinProp.footprint_rect(e)
	var rect := Rect2(fp.position + pos, fp.size)
	if not _clear(rect.grow(pad), keep_off_roads, near_spawn):
		return false
	if e.kind == "building" and _hangs_over_road(e, pos):
		return false
	_taken.append(rect.grow(pad))
	if e.kind == "building":
		_behind.append(_above(e, pos))
	_spawn(parent, e, pos)
	return true


## Would a building's walls and roof, rising up the screen from its base,
## cover a road (the pavement's fine) or a pond? A building at a street's
## end, backing onto one, or standing just below the water.
func _hangs_over_road(e: Dictionary, pos: Vector2) -> bool:
	var above := _above(e, pos)
	for r in road_rects:
		if r.intersects(above.grow(-2.0)):
			return true
	# Nor hide a pond behind it.
	for fx in [0.1, 0.5, 0.9]:
		for fy in [0.0, 0.5]:
			if _in_water(above.position + above.size * Vector2(fx, fy)):
				return true
	return false


## The ground a building at `pos` hides: from the top of its sprite down
## to the back of its base.
static func _above(e: Dictionary, pos: Vector2) -> Rect2:
	var fade: Rect2 = e.fade
	var fp := RuinProp.footprint_rect(e)
	return Rect2(pos.x + fade.position.x, pos.y + fade.position.y, fade.size.x, fp.position.y - fade.position.y)


func _pick(families: Dictionary) -> String:
	var total := 0.0
	for f in families:
		total += families[f]
	var roll := randf() * total
	for f in families:
		roll -= families[f]
		if roll <= 0.0:
			return f
	return families.keys()[0]


func _entry(family: String, yaw: int) -> Dictionary:
	var best: Dictionary = {}
	for e in RuinsCatalog.ENTRIES:
		if e.family == family and (best.is_empty() or _yaw_gap(e.yaw, yaw) < _yaw_gap(best.yaw, yaw)):
			best = e
	return best


static func _yaw_gap(a: int, b: int) -> int:
	var d := absi(a - b) % 360
	return mini(d, 360 - d)


# --- Landmarks -------------------------------------------------------------------

## User request: the town's old gas station (the user's model) stands
## behind the spawn point's oil drums - the refuel point is its forecourt -
## fronting the main street.
func _open_gas_station(parent: Node) -> void:
	var e := _entry("gas_station", 270)
	var fp := RuinProp.footprint_rect(e)
	var spawn := MapGenerator.SPAWN_POS
	var pos := Vector2(spawn.x - fp.get_center().x, spawn.y - 26.0 - fp.end.y)
	if _try_place(parent, e, pos, true, 4.0, true):
		# Its concrete forecourt, out to the main street.
		var main: Array = h_roads[0]
		var top := pos.y + fp.position.y - 10.0
		paved_rects.append(Rect2(pos.x + fp.position.x - 24.0, top, fp.size.x + 48.0,
			main[2] - main[3] / 2.0 - top))


## Traffic signals where the side streets cross the main street: one on
## the far corner, its arm out over the main street; one on the near
## corner, its arm over the side street.
func _signal_crossings(parent: Node) -> void:
	var main: Array = h_roads[0]
	for v in v_roads:
		if absf(v[0] - main[2]) >= 1.0 and absf(v[1] - main[2]) >= 1.0:
			continue
		var dx: float = v[3] / 2.0 + PAVEMENT * 0.5
		var dy: float = main[3] / 2.0 + PAVEMENT * 0.5
		if absf(v[1] - main[2]) < 1.0 or randf() < 0.5:
			_try_place(parent, _entry("traffic_light", 270), Vector2(v[2] + dx, main[2] + dy), false, 2.0)
		if absf(v[1] - main[2]) < 1.0:
			_try_place(parent, _entry("traffic_light", 180), Vector2(v[2] - dx, main[2] - dy), false, 2.0)


# --- Buildings --------------------------------------------------------------------

## Each side of each street, lot after lot: a building fronting the
## pavement, or now and then an empty lot.
func _line_streets_with_buildings(parent: Node) -> void:
	for i in h_roads.size():
		var r: Array = h_roads[i]
		var families := MAIN_BUILDINGS if i == 0 else SIDE_BUILDINGS
		for side in [-1, 1]:
			# North side faces down the screen (yaw 0), south side up (180).
			var yaw := 0 if side < 0 else 180
			var edge: float = r[2] + side * (r[3] / 2.0 + PAVEMENT + 6.0)
			_fill_frontage(parent, families, yaw, true, edge, side, r[0], r[1])
	for r in v_roads:
		for side in [-1, 1]:
			# West side faces right (90), east side left (270).
			var yaw := 90 if side < 0 else 270
			var edge: float = r[2] + side * (r[3] / 2.0 + PAVEMENT + 6.0)
			_fill_frontage(parent, SIDE_BUILDINGS, yaw, false, edge, side, r[0], r[1])


func _fill_frontage(parent: Node, families: Dictionary, yaw: int, horizontal: bool, edge: float, side: int,
		from: float, to: float) -> void:
	var t := from + randf_range(20.0, 90.0)
	while t < to - 40.0:
		# User feedback: not too much at once - plenty of empty lots.
		if randf() < (0.3 if families == MAIN_BUILDINGS else 0.45):
			t += randf_range(110.0, 220.0)  # an empty lot
			continue
		var e := _entry(_pick(families), yaw)
		if e.yaw != yaw:
			continue  # not drawn facing this way (the lone facade)
		var fp := RuinProp.footprint_rect(e)
		var pos: Vector2
		if horizontal:
			# Front of the base against the pavement's edge. South of the
			# street it's the back, and in this view the walls and roof
			# rise up the screen over the street - set back so they only
			# hang over the pavement: a back yard instead.
			var y := edge - fp.end.y if side < 0 else edge - fp.position.y + _overhang(e)
			pos = Vector2(t - fp.position.x, y)
			t += fp.size.x
		else:
			var x := edge - fp.end.x if side < 0 else edge - fp.position.x
			pos = Vector2(x, t - fp.position.y)
			t += fp.size.y
		if _try_place(parent, e, pos):
			t += randf_range(20.0, 70.0) if families == MAIN_BUILDINGS else randf_range(50.0, 140.0)
		else:
			t += 30.0 - (fp.size.x if horizontal else fp.size.y)


## How far a building's walls and roof reach up the screen past the back of
## its base, less the pavement they may cover.
static func _overhang(e: Dictionary) -> float:
	var fade: Rect2 = e.fade
	return maxf(0.0, RuinProp.footprint_rect(e).position.y - fade.position.y - PAVEMENT)


# --- Cars --------------------------------------------------------------------------

## Queues of cars nose to tail, as if everyone tried to leave at once;
## others left at the kerb, a few slewed across the road.
func _abandon_cars(parent: Node) -> void:
	for r in h_roads:
		_jam(parent, r, true)
	for r in v_roads:
		if randf() < 0.35:
			_jam(parent, r, false)


func _jam(parent: Node, r: Array, horizontal: bool) -> void:
	var length: float = r[1] - r[0]
	var queues := int(length / 800.0) + (1 if randf() < 0.5 else 0)
	for _q in queues:
		var lane: float = randf_range(-0.22, 0.22) * r[3]
		var heading := (90 if randf() < 0.5 else 270) if horizontal else (0 if randf() < 0.5 else 180)
		var t := randf_range(r[0] + 40.0, r[1] - 40.0)
		for _c in randi_range(1, 3):
			var yaw: int = heading + ([0, 0, 0, 30, -30, 60].pick_random() if randf() < 0.45 else 0)
			var e := _entry(CARS.pick_random(), (yaw + 360) % 360)
			var pos := Vector2(t, r[2] + lane) if horizontal else Vector2(r[2] + lane, t)
			var fp := RuinProp.footprint_rect(e)
			if gen._shore_distance(pos) > 8.0 and not _in_water(pos):
				_try_place(parent, e, pos, false, 2.0)
			t += (fp.size.x if horizontal else fp.size.y) + randf_range(6.0, 30.0)
			if t > r[1] - 30.0:
				break


func _in_water(pos: Vector2) -> bool:
	for zone in gen.water_zones:
		if zone.contains(pos):
			return true
	return false


# --- Street furniture -----------------------------------------------------------

## Lamps along both pavements, a line of utility poles, hydrants, benches
## and mailboxes, bus stops on the main street, signs at the corners.
func _furnish_pavements(parent: Node) -> void:
	for i in h_roads.size():
		var r: Array = h_roads[i]
		for side in [-1, 1]:
			var y: float = r[2] + side * (r[3] / 2.0 + PAVEMENT * 0.5)
			var lamp_yaw := 0 if side < 0 else 180
			_along(parent, r[0], r[1], 260.0, func(t): return Vector2(t, y), lamp_yaw, side)
		if i == 0:
			for _b in randi_range(1, 2):
				var bx := randf_range(200.0, world.x - 200.0)
				_try_place(parent, _entry("bus_stop", 0), Vector2(bx, r[2] - r[3] / 2.0 - PAVEMENT - 10.0), false)
	for r in v_roads:
		for side in [-1, 1]:
			var x: float = r[2] + side * (r[3] / 2.0 + PAVEMENT * 0.5)
			var lamp_yaw := 90 if side < 0 else 270
			_along(parent, r[0], r[1], 300.0, func(t): return Vector2(x, t), lamp_yaw, side)
		# A sign at the corner where it meets a cross street.
		for end in [r[0], r[1]]:
			if end > 1.0 and end < world.y - 1.0 and randf() < 0.35:
				var e := _entry(["stop_sign", "warn_sign"].pick_random(), [0, 90, 270].pick_random())
				_try_place(parent, e, Vector2(r[2] + r[3] / 2.0 + PAVEMENT * 0.5, end - 50.0 * signf(end - world.y / 2.0)), false)


func _along(parent: Node, from: float, to: float, step: float, at: Callable, lamp_yaw: int, side: int) -> void:
	var t := from + randf_range(30.0, step)
	while t < to - 20.0:
		var pos: Vector2 = at.call(t)
		var roll := randf()
		var family := ""
		if roll < 0.48:
			family = "street_lamp" if randf() < 0.8 else "street_lamp_bent"
		elif roll < 0.62:
			family = "utility_pole"
		elif roll < 0.68:
			family = "hydrant"
		elif roll < 0.76:
			family = "bench" if randf() < 0.6 else "bench_broken"
		elif roll < 0.81:
			family = "mailbox"
		elif roll < 0.9:
			family = ["trash", "barrels", "tires"].pick_random()
		if family != "":
			# Lamps, benches and mailboxes face the street.
			var yaw := lamp_yaw if family.begins_with("street_lamp") or family.begins_with("bench") \
				or family == "mailbox" else randi_range(0, 3) * 90
			if not _in_water(pos) and gen._shore_distance(pos) > 6.0:
				_try_place(parent, _entry(family, yaw), pos, false, 2.0)
		t += step * randf_range(0.7, 1.2)


## One crossing on the main street closed off: a row of concrete barriers,
## cones and barrels - the town was sealed once.
func _set_up_checkpoint(parent: Node) -> void:
	var main: Array = h_roads[0]
	var crossings := v_roads.filter(func(v): return absf(v[0] - main[2]) < 1.0 or absf(v[1] - main[2]) < 1.0)
	var x: float = crossings.pick_random()[2] + randf_range(-160.0, 160.0) if not crossings.is_empty() \
		else randf_range(400.0, world.x - 400.0)
	var y0: float = main[2] - main[3] / 2.0 + 10.0
	var y := y0
	while y < main[2] + main[3] / 2.0:
		_try_place(parent, _entry("barrier", 90), Vector2(x, y), false, 0.0)
		y += 30.0
	for k in 4:
		var e := _entry(["cones", "barrels"].pick_random(), [0, 120, 240].pick_random())
		_try_place(parent, e, Vector2(x + randf_range(-60.0, 60.0), y0 + randf_range(-10.0, main[3])), false, 2.0)


## Round 8 (user request: the abandoned playground the user found, used
## in the town): one empty lot off the streets turned into a playground
## left to the weeds - the slide, swings, roundabout, sandpit and seesaw
## in a loose cluster round a middle, a broken bench or two by it.
const PLAYGROUND := ["pg_slide", "pg_swings", "pg_roundabout", "pg_sandpit", "pg_seesaw"]
## Where round the middle each piece goes (world px), jittered a little.
const PLAYGROUND_SPOTS := [Vector2(-95, -40), Vector2(70, -55), Vector2(-20, 35), Vector2(105, 45), Vector2(-110, 70)]


func _build_playground(parent: Node) -> int:
	for _try in 60:
		var mid := Vector2(randf_range(220.0, world.x - 220.0), randf_range(200.0, world.y - 160.0))
		# The whole park's ground clear first, so it isn't left half built.
		if not _clear(Rect2(mid - Vector2(170, 130), Vector2(340, 250)), true):
			continue
		var placed := 0
		var spots := PLAYGROUND_SPOTS.duplicate()
		spots.shuffle()
		for i in PLAYGROUND.size():
			var family: String = PLAYGROUND[i]
			var yaws := RuinsCatalog.ENTRIES.filter(func(e): return e.family == family).map(func(e): return e.yaw)
			if yaws.is_empty():
				continue
			var e := _entry(family, yaws.pick_random())
			var at: Vector2 = mid + spots[i] + Vector2(randf_range(-10, 10), randf_range(-8, 8))
			if _try_place(parent, e, at, true, 3.0):
				placed += 1
		for k in 2:
			var bench := _entry("bench_broken" if randf() < 0.6 else "bench", [0, 90, 180, 270].pick_random())
			_try_place(parent, bench, mid + Vector2(randf_range(-160, 160), randf_range(90, 120)), true, 2.0)
		return placed
	return 0


## The lots behind and between the buildings: chain-link fences, rubble,
## a dumpster, junk from the wrecks - weeds and trees come later (the
## generator's own scatter, kept off everything placed here).
func _fill_empty_lots(parent: Node) -> void:
	var tries := 0
	var placed := 0
	while placed < 12 and tries < 400:
		tries += 1
		var pos := Vector2(randf_range(60.0, world.x - 60.0), randf_range(60.0, world.y - 60.0))
		var family: String = ["fence", "fence", "fence_broken", "rubble", "rubble", "dumpster", "trash", "bike",
			"bike_ivy", "seat", "seat_ivy", "engine", "tires", "barrels"].pick_random()
		var e := _entry(family, randi_range(0, 11) * 30)
		if _try_place(parent, e, pos, true, 6.0):
			placed += 1

