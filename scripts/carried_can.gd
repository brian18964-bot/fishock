extends Node2D

## The gas can in the player's hand while an oil drum is carried (OilDrum).
## User feedback: it sat stiffly beside the player - now it hangs from the
## hand at the side, on the side of whichever way the player faces (in
## front of the body or behind it), swinging with the stride and settling
## when they stop.

const HAND_HEIGHT := -6.0     # px above the node origin (the feet are at +10)
const HAND_OUT := 7.0         # px out from the body's middle
const SWING := 0.45           # rad, at a full stride
## Sheet column (PlayerVisual.dir) -> facing on screen.
const DIR_VECTORS := [Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1),
	Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)]

var _sway := 0.0
var _vel := 0.0

@onready var _player: Player = get_parent()
@onready var _body: PlayerVisual = _player.get_node("Body")
@onready var _can: Sprite2D = $Can


func _process(delta: float) -> void:
	if not visible:
		return
	var facing: Vector2 = DIR_VECTORS[_body.dir].normalized()
	# The right hand: to the facing's right, on screen (y down).
	var side := Vector2(-facing.y, facing.x)
	position = Vector2(side.x * HAND_OUT, HAND_HEIGHT + side.y * HAND_OUT * 0.5)
	# Behind the body when that hand is the far one.
	z_index = -1 if side.y < -0.2 else 1
	var moving := _player.velocity.length() > 8.0
	# One swing forward and back per stride (the run clip: 8 frames, two
	# steps), plus a little bob.
	var target := sin(_body._phase / PlayerVisual.FRAMES * TAU) * SWING if moving else 0.0
	# A spring, so it swings on a little and settles when they stop.
	_vel += ((target - _sway) * 60.0 - _vel * 7.0) * delta
	_sway += _vel * delta
	# Swinging back and forth along the facing - seen side-on it's a swing,
	# face-on mostly a bob.
	rotation = _sway * absf(facing.x)
	_can.position.y = 10.0 + absf(sin(_body._phase / PlayerVisual.FRAMES * TAU)) * (1.2 if moving else 0.0)

