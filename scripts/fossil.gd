class_name Fossil
extends StaticBody2D

## The desert's bones and cacti - what stands out on the sand and is in the way (user request: the
## desert map's dressing - the dinosaur skeleton we had, and from the user's "Des" pack, made ours
## by tools/make_dino_fossil.py and tools/make_desert_props.py: a mammoth sunk to its knees, two
## cacti, a deer's skull). This is one's place and its solid ground; RunView3D shows its model
## (_trees_and_rocks). What stands above the sand is in the way - ribs, raised legs, a neck, a
## trunk - as circles (its .json, metres in the model's frame), turned `yaw` (as the 3D model is)
## and made solid here, for the player's body and for Solids (the ghosts, the willow).
##
## User request: the bones lie in the sand, not standing - and the user's second batch's skeletons
## (an elephant, a crocodile, a big cat; tools/make_desert_props.py) - "each game, each skeleton
## covered by the sand to a different depth". So a skeleton here is `bury` sunk (cover(): a share of
## SINK of its height under the sand) and, most, a drift heaped over part of it (`drift`, drawn out
## downwind: RunView3D raises the ground by sand_at() and sinks the model by sink()); what's left
## less than CLEAR above the sand there (its circles' heights - the .json's fourth) is walked over.

const DIR := "res://assets/models/desert/"
## Each kind: its files (DIR + name + .glb / .json).
const KINDS := {"dino": "dino_fossil", "mammoth": "mammoth_fossil", "elephant": "elephant_bones", "crocodile": "crocodile_bones",
	"wildcat": "wildcat_bones", "saguaro": "saguaro", "cholla": "cholla", "skull": "skull"}
## The big ones: on flat sand (RunView3D keeps the dunes off them).
const BIG := ["dino", "mammoth", "elephant", "crocodile", "wildcat"]
## What the sand buries (the cacti stand on it).
const BONES := ["dino", "mammoth", "elephant", "crocodile", "wildcat", "skull"]
## How much of its height the sand may have (bury 1).
const SINK := 0.6
## Less than this (m) left above the sand: walked over, not in the way.
const CLEAR := 0.2
## A drift's length downwind (Foliage.WIND_DIR), to its width.
const DRIFT_STRETCH := 1.5
const DATA := DIR + "dino_fossil.json"
const MODEL := DIR + "dino_fossil.glb"
const PX := 27.108

## Which (KINDS) and its turn (rad, about the up axis - the 3D model's rotation.y). Set before it
## enters the tree.
var kind := "dino"
var yaw := 0.0
## How deep the sand has it (0..1: none .. SINK of its height) - cover().
var bury := 0.0
## The drift heaped over part of it: its middle (x, z: m, the model's frame), its radius across the
## wind and its height (m); none if its height is 0.
var drift := Vector4.ZERO
var _bases: Array = []
static var _infos: Dictionary = {}


static func info(which := "dino") -> Dictionary:
	if not _infos.has(which):
		var path: String = DIR + str(KINDS.get(which, "dino_fossil")) + ".json"
		var got = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_infos[which] = got if got is Dictionary else {}
	return _infos[which]


static func model_of(which: String) -> String:
	return DIR + str(KINDS.get(which, "dino_fossil")) + ".glb"


## How far its bones (or arms) reach from its middle (px) - kept clear by what's placed round it.
static func reach_px(which := "dino") -> float:
	return float(info(which).get("reach", 5.0)) * PX


## A model-frame point (m: x, z) turned by `yaw`, as a 2D offset (px).
static func offset(x: float, z: float, turn: float) -> Vector2:
	var v := Basis(Vector3.UP, turn) * Vector3(x, 0.0, z)
	return Vector2(v.x, v.z) * PX


## This game's sand over it (randf - the map's seed): any depth; most with a drift over one end
## or a side, its own size - lower than its slope would hold, and never over all of what still
## stands out of the sand (some of it always shows).
func cover() -> void:
	if not kind in BONES:
		return
	bury = randf()
	drift = Vector4.ZERO
	if kind == "skull" or randf() < 0.25:
		return
	var size: Array = info(kind).get("size", [1.0, 1.0, 1.0])
	var w := float(size[0])
	var l := float(size[1])
	var h := float(size[2])
	var r := maxf(l * randf_range(0.3, 0.5), 1.2)
	var up := minf(minf(h * randf_range(0.4, 1.0), r * 0.32), 0.8 * (h - sink()))
	drift = Vector4(randf_range(-0.4, 0.4) * w, randf_range(-0.45, 0.45) * l, r, up)


## How far under the sand its model sits (m).
func sink() -> float:
	return bury * SINK * float(info(kind).get("size", [0.0, 0.0, 0.0])[2])


func drift_centre() -> Vector2:
	return global_position + offset(drift.x, drift.y, yaw)


## The drift's height (m) at `p` (2D): a smooth heap, longer downwind.
func sand_at(p: Vector2) -> float:
	if drift.w <= 0.0:
		return 0.0
	var rel := (p - drift_centre()) / PX
	var w := Foliage.WIND_DIR.normalized()
	var d := Vector2(rel.dot(w) / DRIFT_STRETCH, rel.dot(w.orthogonal())).length() / drift.z
	return drift.w * (1.0 - smoothstep(0.0, 1.0, d))


## How far its drift reaches from its middle (px; 0 - none).
func sand_reach_px() -> float:
	if drift.w <= 0.0:
		return 0.0
	return drift_centre().distance_to(global_position) + drift.z * DRIFT_STRETCH * PX


func _ready() -> void:
	add_to_group("solids")
	add_to_group("fossils")
	var under := sink()
	for c in info(kind).get("circles", []):
		var at := offset(float(c[0]), float(c[1]), yaw)
		# (what the sand has hidden there is under the feet, not in the way)
		if (c as Array).size() > 3 and float(c[3]) - under - sand_at(global_position + at) < CLEAR:
			continue
		var r := float(c[2]) * PX
		var shape := CircleShape2D.new()
		shape.radius = r
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = at
		add_child(col)
		_bases.append([at, Vector2(r, r)])


func big() -> bool:
	return kind in BIG


func solids() -> Array:
	var out := []
	for b in _bases:
		out.append([global_position + (b[0] as Vector2), b[1]])
	return out
