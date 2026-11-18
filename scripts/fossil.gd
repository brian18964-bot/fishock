class_name Fossil
extends StaticBody2D

## The desert's bones and cacti - what stands out on the sand and is in the way (user request: the
## desert map's dressing - the dinosaur skeleton we had, and from the user's "Des" pack, made ours
## by tools/make_dino_fossil.py and tools/make_desert_props.py: a mammoth sunk to its knees, two
## cacti, a deer's skull). This is one's place and its solid ground; RunView3D shows its model
## (_trees_and_rocks). What stands above the sand is in the way - ribs, raised legs, a neck, a
## trunk - as circles (its .json, metres in the model's frame), turned `yaw` (as the 3D model is)
## and made solid here, for the player's body and for Solids (the ghosts, the willow).

const DIR := "res://assets/models/desert/"
## Each kind: its files (DIR + name + .glb / .json).
const KINDS := {"dino": "dino_fossil", "mammoth": "mammoth_fossil", "saguaro": "saguaro", "cholla": "cholla", "skull": "skull"}
## The big ones: on flat sand (RunView3D keeps the dunes off them).
const BIG := ["dino", "mammoth"]
const DATA := DIR + "dino_fossil.json"
const MODEL := DIR + "dino_fossil.glb"
const PX := 27.108

## Which (KINDS) and its turn (rad, about the up axis - the 3D model's rotation.y). Set before it
## enters the tree.
var kind := "dino"
var yaw := 0.0
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


func _ready() -> void:
	add_to_group("solids")
	add_to_group("fossils")
	for c in info(kind).get("circles", []):
		var at := offset(float(c[0]), float(c[1]), yaw)
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
