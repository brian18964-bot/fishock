class_name SnowTracks
extends Node3D

## User request (the snowy map): where the traveller walks the snow keeps their footprints, the
## left and right foot in turn, and after a while they smooth over and the snow is as it was.
## RunView3D feeds it the feet's place each frame (walk); the prints are one MultiMesh of small
## flat quads (shaders/footprint.gdshader) in a ring - the oldest are overwritten when it's full.

## Prints kept at most, the way apart (m), how far each sits off the line walked (m).
const MAX := 72
const STRIDE := 0.7
const HALF_GAP := 0.13
## Seconds a print stays whole, then how long it takes to fade away.
const HOLD := 14.0
const FADE := 26.0
## A hop this long (m) is a teleport, not a step.
const JUMP := 4.0
const LIFT := 0.014

var _mm: MultiMesh
var _age := PackedFloat32Array()
var _side := PackedFloat32Array()
var _next := 0
var _last := Vector3.INF
var _left := false
var _tick := 0.0


func _ready() -> void:
	name = "SnowTracks"
	top_level = true
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.24, 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/footprint.gdshader")
	quad.material = mat
	_mm.mesh = quad
	_mm.instance_count = MAX
	_age.resize(MAX)
	_side.resize(MAX)
	for i in MAX:
		_age[i] = -1.0
		_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50.0, 0)))
		_mm.set_instance_custom_data(i, Color(0, 1, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Prints"
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


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
	if d.length() < STRIDE:
		return
	var dir := d.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * (HALF_GAP if _left else -HALF_GAP)
	_put(Vector3(feet.x, feet.y + LIFT, feet.z) + side, dir, -1.0 if _left else 1.0)
	_left = not _left
	_last = feet


func _put(at: Vector3, dir: Vector3, foot: float) -> void:
	var i := _next
	_next = (_next + 1) % MAX
	_age[i] = 0.0
	_side[i] = foot
	# (the toe along the way walked: the quad's -z end)
	var basis := Basis(Vector3.UP, atan2(-dir.x, -dir.z))
	_mm.set_instance_transform(i, Transform3D(basis, at))
	_mm.set_instance_custom_data(i, Color(1.0, foot, 0.0, 0.0))


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
		_mm.set_instance_custom_data(i, Color(k, _side[i], 0.0, 0.0))
