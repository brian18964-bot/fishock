class_name SnowTracks
extends Node3D

## User request (the snowy map): where the traveller walks the snow keeps their footprints, the
## left and right foot in turn, and after a while they smooth over and the snow is as it was.
## RunView3D feeds it the feet's place each frame (walk); the prints are one MultiMesh of small
## flat quads (shaders/footprint.gdshader) in a ring - the oldest are overwritten when it's full.

## Prints kept at most, how far each sits off the line walked (m, at a print's full size).
const MAX := 256
const HALF_GAP := 0.2
## Seconds a print stays whole, then how long it takes to fade away.
const HOLD := 14.0
const FADE := 26.0
## A hop this long (m) is a teleport, not a step.
const JUMP := 4.0
const LIFT := 0.014
## The prints' quad (m) before a character's scale.
const QUAD := 0.4
## Each character's foot (user request: the prints in the shape of the traveller's own feet):
## kind (shaders/footprint.gdshader), size (1 = the quad), the way apart (m) and a tail dragged
## between the steps. (slim: a hoof's long and narrow, 0 round.)
const FEET := {
	"cat": {"kind": 1, "size": 0.84, "stride": 0.52},
	"dog": {"kind": 2, "size": 0.68, "stride": 0.44},
	"dog3": {"kind": 2, "size": 1.15, "stride": 0.66},
	"bear": {"kind": 3, "size": 1.8, "stride": 0.85},
	"bear2": {"kind": 3, "size": 1.6, "stride": 0.8},
	"deer": {"kind": 4, "size": 1.4, "stride": 0.9, "slim": 1.0},
	"deer2": {"kind": 4, "size": 1.15, "stride": 0.78, "slim": 1.0},
	"sheep": {"kind": 4, "size": 1.1, "stride": 0.6, "slim": 0.0},
	"sheep2": {"kind": 4, "size": 1.1, "stride": 0.6, "slim": 0.0},
	"owl": {"kind": 5, "size": 1.0, "stride": 0.5},
	"owl2": {"kind": 5, "size": 1.1, "stride": 0.55},
	"croc": {"kind": 6, "size": 1.3, "stride": 0.7, "drag": true},
}
## (a character not in the table: a boot's)
const BOOT := {"kind": 0, "size": 1.0, "stride": 0.7}

var _mm: MultiMesh
var _age := PackedFloat32Array()
var _side := PackedFloat32Array()
var _kind := PackedFloat32Array()
var _next := 0
var _last := Vector3.INF
var _left := false
var _tick := 0.0
var _foot: Dictionary = BOOT
var _foot_key := ""
var _mat: ShaderMaterial


func _ready() -> void:
	name = "SnowTracks"
	top_level = true
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	var quad := PlaneMesh.new()
	quad.size = Vector2(QUAD, QUAD)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/footprint.gdshader")
	quad.material = _mat
	_mm.mesh = quad
	dress(_foot_key)
	_mm.instance_count = MAX
	_age.resize(MAX)
	_side.resize(MAX)
	_kind.resize(MAX)
	for i in MAX:
		_age[i] = -1.0
		_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50.0, 0)))
		_mm.set_instance_custom_data(i, Color(0, 1, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Prints"
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The prints in the shape of character `id`'s feet (FEET).
func dress(id: String) -> void:
	_foot_key = id
	_foot = FEET.get(id, BOOT)
	if _mat != null:
		_mat.set_shader_parameter("kind", int(_foot.kind))
		_mat.set_shader_parameter("slim", float(_foot.get("slim", 1.0)))


## The traveller's feet at `feet` (3D, on the ground), `on_snow`: it's open ground (not a deck, a
## stone or the water's edge).
func walk(feet: Vector3, on_snow: bool) -> void:
	if not on_snow or _last == Vector3.INF:
		_last = feet
		return
	var d := Vector3(feet.x - _last.x, 0.0, feet.z - _last.z)
	if d.length() > JUMP:
		_last = feet
		return
	var stride: float = _foot.stride
	if d.length() < stride:
		return
	var dir := d.normalized()
	var gap := HALF_GAP * float(_foot.size)
	var side := Vector3(-dir.z, 0.0, dir.x) * (gap if _left else -gap)
	var at := Vector3(feet.x, feet.y + LIFT, feet.z)
	if _foot.get("drag", false):
		# (the tail between the last step and this)
		_put(at - dir * stride * 0.5, dir, 1.0, 1.0, Vector3(0.5 * float(_foot.size), 1.0, stride / QUAD))
	_put(at + side, dir, -1.0 if _left else 1.0, 0.0, Vector3.ONE * float(_foot.size))
	_left = not _left
	_last = feet


func _put(at: Vector3, dir: Vector3, foot: float, drag: float, scale3: Vector3) -> void:
	var i := _next
	_next = (_next + 1) % MAX
	_age[i] = 0.0
	_side[i] = foot
	_kind[i] = drag
	# (the toe along the way walked: the quad's -z end)
	var basis := Basis(Vector3.UP, atan2(-dir.x, -dir.z)).scaled_local(scale3)
	_mm.set_instance_transform(i, Transform3D(basis, at))
	_mm.set_instance_custom_data(i, Color(1.0, foot, drag, 0.0))


## How much of print `i` is left (1 whole .. 0 gone).
static func left_of(age: float) -> float:
	if age < 0.0:
		return 0.0
	return clampf(1.0 - (age - HOLD) / FADE, 0.0, 1.0)


## How many prints are showing.
func count() -> int:
	var n := 0
	for a in _age:
		if left_of(a) > 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	for i in MAX:
		if _age[i] >= 0.0:
			_age[i] += delta
	_tick += delta
	if _tick < 0.25 and delta < 1.0:
		return
	_tick = 0.0
	for i in MAX:
		if _age[i] < 0.0:
			continue
		var k := left_of(_age[i])
		if k <= 0.0:
			_age[i] = -1.0
			_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50.0, 0)))
		_mm.set_instance_custom_data(i, Color(k, _side[i], _kind[i], 0.0))
