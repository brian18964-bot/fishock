class_name Fossil
extends StaticBody2D

## The desert's dinosaur bones (user request: the desert map's dressing - the dinosaur skeleton
## model we had: tools/make_dino_fossil.py made ours from it, lying on its side half sunk in the
## sand). This is its place and its solid ground; RunView3D shows the model (_fossils). What stands
## above the sand is in the way - the ribs, the raised legs, the neck and tail - as circles
## (dino_fossil.json, metres in the model's frame), turned `yaw` (as the 3D model is) and made
## solid here, for the player's body and for Solids (the ghosts, the willow).

const DATA := "res://assets/models/desert/dino_fossil.json"
const MODEL := "res://assets/models/desert/dino_fossil.glb"
const PX := 27.108

## Its turn (rad, about the up axis - the 3D model's rotation.y). Set before it enters the tree.
var yaw := 0.0
var _bases: Array = []
static var _info: Dictionary = {}


static func info() -> Dictionary:
	if _info.is_empty() and FileAccess.file_exists(DATA):
		var got = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if got is Dictionary:
			_info = got
	return _info


## How far its bones reach from its middle (px) - kept clear by what's placed round it.
static func reach_px() -> float:
	return float(info().get("reach", 5.0)) * PX


## A model-frame point (m: x, z) turned by `yaw`, as a 2D offset (px).
static func offset(x: float, z: float, turn: float) -> Vector2:
	var v := Basis(Vector3.UP, turn) * Vector3(x, 0.0, z)
	return Vector2(v.x, v.z) * PX


func _ready() -> void:
	add_to_group("solids")
	add_to_group("fossils")
	for c in info().get("circles", []):
		var at := offset(float(c[0]), float(c[1]), yaw)
		var r := float(c[2]) * PX
		var shape := CircleShape2D.new()
		shape.radius = r
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = at
		add_child(col)
		_bases.append([at, Vector2(r, r)])


func solids() -> Array:
	var out := []
	for b in _bases:
		out.append([global_position + (b[0] as Vector2), b[1]])
	return out
