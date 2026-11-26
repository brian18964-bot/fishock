class_name Ruin
extends StaticBody2D

## User request (the ruined human world - its first map, the city): the empty buildings standing
## along the city's streets, in the way and to find one's bearings by. This is one's place and its
## solid ground (a rectangle, `size` px, square to the map); RunView3D shows it (_ruins: for now a
## shell of our own making - walls, storeys, broken windows, a broken top - till the user's own
## models come). A heap of rubble ("rubble") where one has come down: lower, still in the way.
##
## Solids (the ghosts, the willow - they move by hand) see it as a row of circles along its length.

## The kinds: a shop of a storey or two, a block of flats, the tall office block (one a map, to
## find one's way by), a heap where one fell.
const KINDS := ["shop", "flat", "tower", "rubble"]
## (a storey's height, m; how many each kind has - mine for now)
const STOREY := 3.0
const STOREYS := {"shop": Vector2i(1, 2), "flat": Vector2i(2, 3), "tower": Vector2i(5, 7), "rubble": Vector2i(0, 0)}
## (a heap's height, m)
const RUBBLE_HIGH := 1.4

var kind := "shop"
## Its footprint (px, x across the map, y down it), its middle at `position`.
var size := Vector2(300, 240)
var storeys := 1
## Its own dice (RunView3D's look of it: its colour, which windows are out, its broken top).
var seed_value := 0
var _bases: Array = []


func _ready() -> void:
	add_to_group("solids")
	add_to_group("ruins")
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	# (for Solids: circles along its length, each as wide as it is, overlapping)
	var long_x := size.x >= size.y
	var short := minf(size.x, size.y)
	var length := maxf(size.x, size.y)
	var n := maxi(1, ceili(length / short * 1.4))
	for i in n:
		var t := (float(i) + 0.5) / float(n) - 0.5
		var at := Vector2(t * (length - short * 0.5), 0.0) if long_x else Vector2(0.0, t * (length - short * 0.5))
		var r := short * 0.5 * 1.1
		_bases.append([at, Vector2(r, r)])


func solids() -> Array:
	var out := []
	for b in _bases:
		out.append([global_position + (b[0] as Vector2), b[1]])
	return out


## Its height (m).
func height() -> float:
	return RUBBLE_HIGH if kind == "rubble" else float(storeys) * STOREY


## The rectangle it stands on (px, world).
func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


## Circles covering it - [centre, radius] - for what's placed round it to keep clear of
## (MapGenerator's _taken).
func footprint_circles() -> Array:
	var out := []
	var long_x := size.x >= size.y
	var short := minf(size.x, size.y)
	var length := maxf(size.x, size.y)
	var n := maxi(1, ceili(length / short * 1.4))
	for i in n:
		var t := (float(i) + 0.5) / float(n) - 0.5
		var at := Vector2(t * (length - short), 0.0) if long_x else Vector2(0.0, t * (length - short))
		out.append([position + at, short * 0.5 * 1.42])
	return out
