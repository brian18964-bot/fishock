class_name GuideArrow
extends Node2D

## User request (round 7): the eyeball shows the way to the altar, the
## binoculars where the 渡石 (the escape point) is. An arrow round the
## player pointing at the place, its name and how far beside it, and a
## ring pulsing on the place itself (seen when it's on screen) - for a
## while, then fading out. Drawn over the night on a layer of its own, in
## screen pixels (the darkness doesn't dim it, the camera's zoom doesn't
## blow it up), following `follow` (the player).

## How far out from the player the arrow sits (screen px), and its size.
const RADIUS := 70.0
const SIZE := 18.0
const FONT := 19
## World px to a 公尺 shown.
const PX_PER_M := 16.0
const FADE := 0.6

var target := Vector2.ZERO
var follow: Node2D
## Where on `follow` it's centred (world px over its feet).
var lift := Vector2(0, -14)
var label := ""
var color := Color.WHITE
## Seconds left showing.
var time_left := 0.0
var _t := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var custom: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if custom != "":
		_font = load(custom)


## Points at `at` (world) for `seconds`, named `what`.
func show_to(at: Vector2, what: String, tint: Color, seconds: float) -> void:
	target = at
	label = what
	color = tint
	time_left = seconds
	visible = true


func active() -> bool:
	return time_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if time_left <= 0.0:
		visible = false
		return
	time_left -= delta
	if follow != null:
		position = follow.get_viewport().get_canvas_transform() * (follow.global_position + lift)
	queue_redraw()


## The target on screen, from this node.
func _target_local() -> Vector2:
	if follow == null:
		return to_local(target)
	return follow.get_viewport().get_canvas_transform() * target - position


func _draw() -> void:
	var alpha := clampf(time_left / FADE, 0.0, 1.0) * (0.85 + 0.15 * sin(_t * 5.0))
	var to := _target_local()
	var dir := to.normalized() if to.length() > 1.0 else Vector2.UP
	var tip := dir * (RADIUS + SIZE)
	var base := dir * RADIUS
	var side := dir.orthogonal() * SIZE * 0.6
	var c := Color(color, alpha)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), c)
	draw_polyline(PackedVector2Array([tip, base + side, base - side, tip]), Color(0, 0, 0, alpha * 0.6), 1.5)
	var meters := roundi(target.distance_to(follow.global_position) / PX_PER_M) if follow != null else 0
	var text := "%s %d 公尺" % [label, meters] if meters > 2 else label
	var at := dir * (RADIUS + SIZE + 18.0)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x
	var text_at := at - Vector2(w * 0.5, -FONT * 0.35)
	draw_string_outline(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, 5, Color(0, 0, 0, alpha * 0.85))
	draw_string(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color(color.lerp(Color.WHITE, 0.45), alpha))
	# On the place itself: a ring that keeps opening out.
	var k := fmod(_t * 0.8, 1.0)
	draw_arc(to, 16.0 + 44.0 * k, 0.0, TAU, 40, Color(color, alpha * (1.0 - k)), 3.0)
	draw_arc(to, 12.0, 0.0, TAU, 28, Color(color, alpha * 0.7), 2.0)
