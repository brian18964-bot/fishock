class_name OffhandProp
extends Node2D

## User request: the off hand's thing (Profile.offhand() - a knife, the
## hatchet, the machete, the pistol or the net) shows on the character: in
## the right hand while the rod's on the back - and swung with it (Player
## .swing(), PlayerVisual's swing sheet) - and hung at the right hip while
## fishing, eased between the two over DRAW_TIME as the rod's drawn or put
## back. Its picture is the thing's own (Items.icon), turned along the hand
## (the fist's axis - a pistol's along the fingers) or down the thigh at
## the hip, foreshortened as they are; behind the body when they are.
## Where: the sheet's data for the frame showing (PlayerVisual.hand_cell(),
## belt_cell()). A swing also leaves its stroke in the air, the way it's
## aimed (it reads at a phone's size): a blade's arc (a chop's from high to
## low), the net's low sweep, the pistol's flash and its shot.

const SPRITE_SCALE := PlayerVisual.SPRITE_SCALE
const DRAW_TIME := 0.22
## The data's directions' length on screen when seen square-on (sheet px:
## render_player.py DIR_LEN x SCALE x DENSITY).
const DIR_FULL := 0.25 * 1.4337 * 27.108
## Per thing: where it's held in its picture (u, v of the picture), the
## way it points there (deg; 0: to the right), how long it is from the
## hand (sheet px), and which of the hand's axes it lies along.
const PROPS := {
	"knife": {"grip": Vector2(0.12, 0.55), "deg": 0.0, "length": 15.0, "axis": "fist"},
	"machete": {"grip": Vector2(0.1, 0.45), "deg": 0.0, "length": 24.0, "axis": "fist"},
	"hatchet": {"grip": Vector2(0.2, 0.15), "deg": 28.0, "length": 18.0, "axis": "fist"},
	"glock": {"grip": Vector2(0.22, 0.7), "deg": 0.0, "length": 10.0, "axis": "fingers"},
	"net": {"grip": Vector2(0.04, 0.31), "deg": 2.0, "length": 30.0, "axis": "fist"},
}
## Hung at the hip it's a little smaller (seen past the body's side).
const BELT_SCALE := 0.85
## The stroke: its radius from the body's middle (world px), how wide it
## sweeps (rad), and the shot's length.
const STROKE_RADIUS := 11.0
const STROKE_SWEEP := 2.2
const SHOT_LENGTH := 90.0
const STROKE := Color(1.0, 0.97, 0.88)

var _id := ""
var _tex: Texture2D
var _was_hand := true
var _from: Array = []
var _blend := 0.0
## What's drawn: [position, axis (unit), length (px), behind] - read by
## the tests.
var shown: Array = []

@onready var _player: Player = get_parent()
@onready var _body: PlayerVisual = _player.get_node("Body")


func _process(delta: float) -> void:
	var id := Profile.offhand()
	if id != _id:
		_id = id
		_tex = Items.icon(id) if PROPS.has(id) else null
	var hand := _player.offhand_in_hand() or _body.acting >= 0
	var cell := _place(hand)
	if hand != _was_hand and not shown.is_empty():
		_from = shown.duplicate()
		_blend = DRAW_TIME
	_was_hand = hand
	_blend = maxf(_blend - delta, 0.0)
	if not cell.is_empty() and _blend > 0.0 and not _from.is_empty():
		var t := 1.0 - _blend / DRAW_TIME
		t = t * t * (3.0 - 2.0 * t)
		cell = [(_from[0] as Vector2).lerp(cell[0], t), (_from[1] as Vector2).slerp(cell[1], t),
			lerpf(_from[2], cell[2], t), cell[3]]
	shown = cell
	visible = _tex != null and not cell.is_empty() and not _body.struggling
	if visible:
		z_index = -1 if cell[3] else 2
	queue_redraw()


## Where it goes this frame: [position, axis, length, behind] ([] without
## the sheet's data).
func _place(hand: bool) -> Array:
	if not PROPS.has(_id):
		return []
	var spec: Dictionary = PROPS[_id]
	var at: Array = _body.hand_cell() if hand else _body.belt_cell()
	if at.is_empty():
		return []
	var pos := _body.position + Vector2(at[0], at[1]) * SPRITE_SCALE
	var axis := Vector2(at[2], at[3])
	if hand and spec.axis == "fingers":
		axis = Vector2(at[4], at[5])
	var fore := clampf(axis.length() / DIR_FULL, 0.3, 1.0)
	var length: float = spec.length * SPRITE_SCALE * fore * (1.0 if hand else BELT_SCALE)
	var behind: bool = bool(at[6] if hand else at[4])
	return [pos, axis.normalized() if axis.length() > 0.01 else Vector2.DOWN, length, behind]


func _draw() -> void:
	_draw_stroke()
	if not visible or shown.is_empty() or _tex == null:
		return
	var spec: Dictionary = PROPS[_id]
	var size := Vector2(_tex.get_size())
	var grip: Vector2 = spec.grip * size
	# The picture's own length from the grip along its axis, to its far end.
	var dir := Vector2.RIGHT.rotated(deg_to_rad(spec.deg))
	var reach := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		reach = maxf(reach, (corner - grip).dot(dir))
	var axis: Vector2 = shown[1]
	var k: float = shown[2] / maxf(reach, 1.0)
	# Pointing left, it's flipped so its edge (its top in the picture) stays up.
	var flip := -1.0 if axis.x < 0.0 else 1.0
	var turn := axis.angle() - dir.angle() * flip
	draw_set_transform(shown[0], turn, Vector2(k, k * flip))
	draw_texture(_tex, -grip)
	draw_set_transform(Vector2.ZERO)


## The swing's stroke in the air (see above), over the swing's blow.
func _draw_stroke() -> void:
	if _player.swing_left <= 0.0:
		return
	var t := 1.0 - _player.swing_left / Player.SWING_TIME
	var aim: Vector2 = _player.aim_dir
	var middle := _body.position + Vector2(0, -8)
	var a := clampf(1.0 - absf(t - 0.45) / 0.3, 0.0, 1.0)
	if a <= 0.0:
		return
	match _player.swing_kind:
		"shoot":
			var muzzle := middle + aim * 10.0
			draw_circle(muzzle, 3.5 * a, Color(1.0, 0.85, 0.4, a))
			draw_line(muzzle, muzzle + aim * SHOT_LENGTH * minf(1.0, t * 2.5), Color(1.0, 0.9, 0.6, a * 0.7), 1.0)
		_:
			var low: bool = _player.swing_kind == "scoop"
			var centre := middle + (Vector2(0, 5) if low else Vector2.ZERO)
			var from := aim.angle() - STROKE_SWEEP * 0.5
			var reach := clampf((t - 0.15) / 0.5, 0.0, 1.0)
			if _player.swing_kind == "chop":
				# high to low: the arc swept down through the aim
				from = aim.angle() - STROKE_SWEEP * 0.5 * signf(aim.x if absf(aim.x) > 0.1 else 1.0)
			var to := from + STROKE_SWEEP * reach * (1.0 if _player.swing_kind != "chop" or aim.x >= -0.1 else -1.0)
			for i in 3:
				var r := STROKE_RADIUS + i * 2.0
				draw_arc(centre, r, from, to, 18, Color(STROKE, a * (0.75 - i * 0.22)), 2.0 - i * 0.5)
