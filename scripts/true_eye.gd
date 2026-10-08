class_name TrueEye
extends Node2D

## User request: an eye item used, a 'true eye' opens over the character's
## head for a moment, the way a skill's cast shows - it opens, looks the
## way of the place it's showing, a faint ring goes out from it, and it
## shuts and fades. Softer than the user's reference (not so full a
## colour), each in its item's own iris and pupil (tools/true_eye.py draws
## them); unlit, so the night doesn't swallow it.

const FX := "res://assets/sprites/fx/true_eye_%s.png"
const FRAMES := 6
## Over the head (world px off the player), how big (of the drawn frame),
## and the whole of it (s): opening from .. to, shutting from .. to.
const LIFT := Vector2(0, -28)
const SCALE := 0.2
const TIME := 1.6
const OPEN_AT := Vector2(0.1, 0.32)
const SHUT_AT := Vector2(1.16, 1.36)
## The iris's furthest look (frame px, across and up/down).
const LOOK := Vector2(24.0, 7.0)
const ALPHA := 0.88
const TINTS := {"eyeball": Color(0.72, 0.52, 0.36), "eye_altar": Color(0.95, 0.74, 0.4), "eye_ghost": Color(0.62, 0.58, 0.95)}

var kind := "eyeball"
## Which way the place is (unit, the world's), or ZERO.
var look_dir := Vector2.ZERO
var _t := 0.0
var _white: Sprite2D
var _iris: Sprite2D
var _lids: Sprite2D


## Opens one over `on` (the player) for eye item `item`, looking toward
## `toward` (world).
static func cast(on: Node2D, item: String, toward: Vector2) -> TrueEye:
	var eye := TrueEye.new()
	eye.name = "TrueEye"
	eye.kind = item
	var d := toward - on.global_position
	eye.look_dir = d.normalized() if d.length() > 1.0 else Vector2.ZERO
	var old := on.get_node_or_null("TrueEye")
	if old != null:
		old.name = "TrueEyeGone"
		old.queue_free()
	on.add_child(eye)
	return eye


func _ready() -> void:
	z_as_relative = false
	z_index = 60
	position = LIFT
	scale = Vector2.ONE * SCALE
	modulate.a = 0.0
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	_white = Sprite2D.new()
	_white.texture = load(FX % "white")
	_white.hframes = FRAMES
	_white.material = unlit
	# (the iris drawn only inside the white)
	_white.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_white)
	_iris = Sprite2D.new()
	_iris.texture = load(FX % ("iris_" + kind)) if ResourceLoader.exists(FX % ("iris_" + kind)) else load(FX % "iris_eyeball")
	_iris.material = unlit
	_white.add_child(_iris)
	_lids = Sprite2D.new()
	_lids.texture = load(FX % "lids")
	_lids.hframes = FRAMES
	_lids.material = unlit
	add_child(_lids)
	_pose()


func _process(delta: float) -> void:
	_t += delta
	if _t >= TIME:
		queue_free()
		return
	_pose()
	queue_redraw()


## How open it is now (0 shut .. 1).
func openness() -> float:
	if _t < OPEN_AT.x or _t >= SHUT_AT.y:
		return 0.0
	if _t < OPEN_AT.y:
		return (_t - OPEN_AT.x) / (OPEN_AT.y - OPEN_AT.x)
	if _t < SHUT_AT.x:
		return 1.0
	return 1.0 - (_t - SHUT_AT.x) / (SHUT_AT.y - SHUT_AT.x)


func _pose() -> void:
	var frame := clampi(roundi(openness() * (FRAMES - 1)), 0, FRAMES - 1)
	_white.frame = frame
	_lids.frame = frame
	modulate.a = ALPHA * minf(_t / 0.12, 1.0) * clampf((TIME - _t) / 0.24, 0.0, 1.0)
	var look := smoothstep(OPEN_AT.y, OPEN_AT.y + 0.3, _t)
	_iris.position = Vector2(look_dir.x * LOOK.x, look_dir.y * LOOK.y) * look
	# A small pop as it comes, and a drift up as it goes.
	scale = Vector2.ONE * SCALE * (0.85 + 0.15 * smoothstep(0.0, 0.25, _t))
	position = LIFT + Vector2(0, -8.0 * smoothstep(SHUT_AT.x, TIME, _t))


## Behind it: a soft glow of its colour, and once it's open a faint ring
## going out (the cast).
func _draw() -> void:
	var tint: Color = TINTS.get(kind, Color.WHITE)
	var glow := smoothstep(0.0, OPEN_AT.y, _t) * (1.0 - smoothstep(SHUT_AT.x, TIME, _t))
	draw_texture_rect(UiKit.glow(), Rect2(Vector2(-150, -110), Vector2(300, 220)), false, Color(tint, 0.28 * glow))
	var k := clampf((_t - OPEN_AT.y) / 0.75, 0.0, 1.0)
	if k > 0.0 and k < 1.0:
		draw_arc(Vector2(0, 4), 70.0 + 170.0 * k, 0.0, TAU, 48, Color(tint, 0.4 * (1.0 - k)), 7.0, true)
