class_name CampWildlife
extends Node3D

## Now and then (user request: rarely - a small surprise) an animal from
## the runs' own sheets (Critter.SPECIES) walks along the far bank, a dark
## shape against the lake: in from one end of `path`, across, and fading
## out at the other. The sheets are seen from 55deg above, so the side-on
## row (left, mirrored for right) reads as a walking silhouette.

const KINDS := ["deer", "stag", "fox", "wolf"]
## Seconds between them.
const GAP := Vector2(55.0, 130.0)
const FIRST := Vector2(20.0, 45.0)
const SPEED := 0.9
const FADE := 1.5
## The sheets' density (pixels a metre, as the runs draw them).
const PIXEL := 1.0 / 44.7
const SHADE := Color(0.015, 0.02, 0.03, 0.92)

## Points (the camp's ground) it walks along, either way round.
var path: PackedVector3Array

var _sprite: Sprite3D
var _wait := 0.0
var _walking := false
var _pos := 0.0
var _length := 0.0
var _backward := false
var _phase := 0.0
var _data := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(FIRST.x, FIRST.y)
	_sprite = Sprite3D.new()
	_sprite.name = "Silhouette"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.pixel_size = PIXEL
	_sprite.visible = false
	add_child(_sprite)
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
	if _pos >= _length:
		_walking = false
		_sprite.visible = false
		_wait = _rng.randf_range(GAP.x, GAP.y)
		return
	var along := _length - _pos if _backward else _pos
	position = _point_at(along)
	var fade := clampf(minf(_pos, _length - _pos) / (FADE * SPEED), 0.0, 1.0)
	_sprite.modulate = Color(SHADE.r, SHADE.g, SHADE.b, SHADE.a * fade)
	var frames: int = _data.get("frames", 12)
	_phase += delta * float(_data.get("move_fps", 14.0)) * 0.8
	# Walk clip (0), the side-on row (2: left); mirrored going right.
	_sprite.frame = (0 * Critter.ROWS + 2) * frames + int(_phase) % frames
	# The sheet's row faces left; going right, mirrored.
	var ahead := _point_at(clampf(along + (-0.2 if _backward else 0.2), 0.0, _length)) - position
	_sprite.flip_h = ahead.x > 0.0


## An animal on its way (now, whatever the wait).
func start(kind: String) -> void:
	_data = Critter.SPECIES[kind]
	var tex: Texture2D = load(_data.albedo)
	_sprite.texture = tex
	var cells: int = _data.get("frames", 12) * _data.clips * Critter.ROWS
	_sprite.hframes = _data.cols
	_sprite.vframes = ceili(float(cells) / _data.cols)
	_sprite.pixel_size = PIXEL * _data.get("size", 1.0)
	var off: Vector2 = _data.offset
	_sprite.offset = Vector2(off.x, -off.y)
	_backward = _rng.randf() < 0.5
	_pos = 0.0
	_phase = 0.0
	_walking = true
	_sprite.visible = true
	_sprite.modulate = Color(SHADE.r, SHADE.g, SHADE.b, 0.0)


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
