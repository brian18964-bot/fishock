class_name CampWildlife
extends Node3D

## Now and then (user request: rarely - a small surprise) an animal walks
## along the far bank at the foot of the forest across the lake, a dark
## shape: fading in somewhere along `path`, walking a stretch of it (WALK
## m), fading out. (User decision: the game is 3D now - the runs' own
## animal models, RunView3D.CREATURES, walking their own Walk clip.)

const KINDS := ["deer", "stag", "fox", "wolf"]
## Seconds between them.
const GAP := Vector2(55.0, 130.0)
const FIRST := Vector2(20.0, 45.0)
const SPEED := 1.1
## How far one walks (m), and how much bigger than life it's drawn - so far
## off it would be a speck.
const WALK := Vector2(10.0, 16.0)
const SIZE := 1.5
const FADE := 1.5
const SHADE := Color(0.015, 0.02, 0.03, 0.92)

## Points (the camp's ground) it walks along, either way round.
var path: PackedVector3Array

var _model: Node3D
var _kind := ""
var _mat: StandardMaterial3D
var _wait := 0.0
var _walking := false
var _pos := 0.0
var _length := 0.0
## The stretch walked: where it starts along `path`, how long.
var _from := 0.0
var _span := 0.0
var _backward := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(FIRST.x, FIRST.y)
	# One dark see-through material over every part: a silhouette.
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(SHADE.r, SHADE.g, SHADE.b, 0.0)
	for k in range(1, path.size()):
		_length += path[k].distance_to(path[k - 1])


func _process(delta: float) -> void:
	if path.size() < 2:
		return
	if not _walking:
		_wait -= delta
		if _wait <= 0.0:
			start(KINDS[_rng.randi() % KINDS.size()])
		return
	_pos += SPEED * delta
	if _pos >= _span:
		_walking = false
		if _model != null:
			_model.visible = false
		_wait = _rng.randf_range(GAP.x, GAP.y)
		return
	var along := _from + (_span - _pos if _backward else _pos)
	position = _point_at(along)
	var fade := clampf(minf(_pos, _span - _pos) / (FADE * SPEED), 0.0, 1.0)
	_mat.albedo_color.a = SHADE.a * fade
	var ahead := _point_at(clampf(along + (-0.2 if _backward else 0.2), 0.0, _length)) - position
	if Vector2(ahead.x, ahead.z).length() > 0.001:
		rotation.y = atan2(ahead.x, ahead.z)


## An animal on its way (now, whatever the wait).
func start(kind: String) -> void:
	if kind != _kind:
		if _model != null:
			_model.queue_free()
		_model = _build(kind)
		_kind = kind
	_backward = _rng.randf() < 0.5
	_span = minf(_rng.randf_range(WALK.x, WALK.y), _length)
	_from = _rng.randf_range(0.0, _length - _span)
	_pos = 0.0
	_walking = true
	_mat.albedo_color.a = 0.0
	if _model != null:
		_model.visible = true
	position = _point_at(_from + (_span if _backward else 0.0))


func _build(kind: String) -> Node3D:
	var path_glb: String = RunView3D.CREATURE_DIR + kind + ".glb"
	if not ResourceLoader.exists(path_glb):
		return null
	var model: Node3D = (load(path_glb) as PackedScene).instantiate()
	model.name = "Animal"
	add_child(model)
	var box := RunView3D._aabb(model)
	var k := float(RunView3D.CREATURES[kind][0]) * SIZE / maxf(box.size.y, 0.001)
	model.scale = Vector3.ONE * k
	model.position = Vector3(-(box.position.x + box.size.x * 0.5) * k, -box.position.y * k,
		-(box.position.z + box.size.z * 0.5) * k)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var anim := aps[0] as AnimationPlayer
		for clip in ["Walk", "walk", "Gallop"]:
			if anim.has_animation(clip):
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				anim.play(clip)
				break
	return model


func walking() -> bool:
	return _walking


func _point_at(d: float) -> Vector3:
	var left := d
	for k in range(1, path.size()):
		var seg := path[k].distance_to(path[k - 1])
		if left <= seg:
			return path[k - 1].lerp(path[k], left / maxf(seg, 0.0001))
		left -= seg
	return path[path.size() - 1]
