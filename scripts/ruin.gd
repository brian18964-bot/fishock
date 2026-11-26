class_name Ruin
extends StaticBody2D

## User request (the ruined human world - its first map, the city): the empty buildings standing
## along the city's streets, in the way and to find one's bearings by. This is one's place and its
## solid ground (a rectangle, `size` px, square to the map); RunView3D shows it (_ruins: for now a
## shell of our own making - walls, storeys, broken windows, a broken top - till the user's own
## models come). A heap of rubble ("rubble") where one has come down: lower, still in the way.
##
## Solids (the ghosts, the willow - they move by hand) see it as a row of circles along its length.
##
## User request (the user's models, made ours - tools/make_city_assets.py): a whole block may hold
## one of the low buildings instead (`model`: a strip of shops, a long house, houses with porches):
## its footprint the model's, turned `model_yaw` (a quarter turn or more) and scaled `model_scale`
## to the block (MODEL_SCALE) - model_footprint().

## The kinds: a shop of a storey or two, a block of flats, the tall office block (one a map, to
## find one's way by), a heap where one fell.
const KINDS := ["shop", "flat", "tower", "rubble", "model"]
## (a storey's height, m; how many each kind has - mine for now)
const STOREY := 3.0
const STOREYS := {"shop": Vector2i(1, 2), "flat": Vector2i(2, 3), "tower": Vector2i(5, 7), "rubble": Vector2i(0, 0), "model": Vector2i(1, 1)}
## (a model building: how small and how big against its own size - its doors stay about as tall as a
## traveller; the models' footprints and heights, m - tools/make_city_assets.py)
const MODEL_SCALE := Vector2(0.6, 0.85)
const MODELS_DIR := "res://assets/models/city/"
const MODELS_INFO := "res://assets/models/city/city_assets.json"
static var _info: Dictionary = {}
## (a heap's height, m)
const RUBBLE_HIGH := 1.4

var kind := "shop"
## Its footprint (px, x across the map, y down it), its middle at `position`.
var size := Vector2(300, 240)
var storeys := 1
## Its own dice (RunView3D's look of it: its colour, which windows are out, its broken top).
var seed_value := 0
## (a model building's: which, how turned (rad), how big)
var model := ""
var model_yaw := 0.0
var model_scale := 1.0
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
	if model != "":
		return float((info(model).get("size", [1, 1, 1]) as Array)[2]) * model_scale
	return RUBBLE_HIGH if kind == "rubble" else float(storeys) * STOREY


## The city's models' sizes (m: across, deep, high - as made, before turning or scaling).
static func info(name: String) -> Dictionary:
	if _info.is_empty() and FileAccess.file_exists(MODELS_INFO):
		var got = JSON.parse_string(FileAccess.get_file_as_string(MODELS_INFO))
		_info = got if got is Dictionary else {}
	return _info.get(name, {})


## A model's footprint (px) turned `yaw` (quarter turns) and scaled `scale`.
static func model_footprint(name: String, yaw: float, scale: float) -> Vector2:
	var s: Array = info(name).get("size", [1, 1, 1])
	var w := float(s[0]) * scale * Fossil.PX
	var d := float(s[1]) * scale * Fossil.PX
	var quarter := posmod(roundi(yaw / (PI * 0.5)), 2) == 1
	return Vector2(d, w) if quarter else Vector2(w, d)


func model_path() -> String:
	return MODELS_DIR + model + ".glb"


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
