class_name GuideArrow
extends Node2D

## User request (round 7, round 8): the eyes and the binoculars show the
## way - to the 渡石, the altar, the nearest ghost (`track`: a moving
## target), the nearest water. An arrow round the
## player pointing at the place, its name and how far beside it, and a
## ring pulsing on the place itself (seen when it's on screen) - for a
## while, then fading out. Drawn over the night on a layer of its own, in
## screen pixels (the darkness doesn't dim it, the camera's zoom doesn't
## blow it up), following `follow` (the player).

## User request: an arrow that reads as one - a shaft and a head, not a
## lone triangle - with chevrons running out along it, outlined so it
## shows on any ground; set out past the character (an ellipse round its
## middle, BODY world px across and up - so the character never covers
## it, however close the camera is - and GAP screen px more). Its size (screen px): LENGTH
## tip to tail, HEAD wide, SHAFT thick.
const BODY := Vector2(7, 10)
const GAP := 8.0
const LENGTH := 40.0
const HEAD := 30.0
const HEAD_LENGTH := 20.0
const SHAFT := 10.0
const FONT := 19
## World px to a 公尺 shown.
const PX_PER_M := 16.0
const FADE := 0.6

var target := Vector2.ZERO
var follow: Node2D
## Where on `follow` it's centred (world px off its origin - the
## character's middle).
var lift := Vector2.ZERO
var label := ""
var color := Color.WHITE
## Where the target is now, asked each frame (a Vector2, or null to keep
## the last); unset for a place that doesn't move.
var track: Callable
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
	track = Callable()
	visible = true


func active() -> bool:
	return time_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if time_left <= 0.0:
		visible = false
		return
	time_left -= delta
	if track.is_valid():
		var at = track.call()
		if at is Vector2:
			target = at
	if follow != null:
		position = follow.get_viewport().get_canvas_transform() * (follow.global_position + lift)
	queue_redraw()


## The target on screen, from this node.
func _target_local() -> Vector2:
	if follow == null:
		return to_local(target)
	return follow.get_viewport().get_canvas_transform() * target - position


func _draw() -> void:
	var alpha := clampf(time_left / FADE, 0.0, 1.0)
	var to := _target_local()
	var dir := to.normalized() if to.length() > 1.0 else Vector2.UP
	var side := dir.orthogonal()
	var radius := _radius(dir)
	var tail := dir * radius
	var tip := dir * (radius + LENGTH)
	var neck := tip - dir * HEAD_LENGTH
	var c := Color(color, alpha)
	var ink := Color(0.02, 0.03, 0.05, alpha * 0.85)
	# Chevrons running out from the character the way to go.
	for i in 3:
		var k := fmod(_t * 1.2 + i / 3.0, 1.0)
		var at := dir * (radius * 0.55 + (radius * 0.45) * k)
		var a := alpha * sin(k * PI) * 0.7
		var wing := side * 7.0
		draw_polyline(PackedVector2Array([at - dir * 6.0 + wing, at, at - dir * 6.0 - wing]), Color(color, a), 3.0)
	var arrow := PackedVector2Array([
		tail + side * SHAFT * 0.5, neck + side * SHAFT * 0.5, neck + side * HEAD * 0.5, tip,
		neck - side * HEAD * 0.5, neck - side * SHAFT * 0.5, tail - side * SHAFT * 0.5])
	var outline := arrow.duplicate()
	outline.append(arrow[0])
	draw_polyline(outline, ink, 5.0, true)
	draw_colored_polygon(arrow, c)
	draw_polyline(outline, Color(color.lerp(Color.WHITE, 0.6), alpha), 1.5, true)
	var meters := roundi(target.distance_to(follow.global_position) / PX_PER_M) if follow != null else 0
	var text := "%s %d 公尺" % [label, meters] if meters > 2 else label
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT)
	# The name past the head, pushed out as far as its box reaches the
	# arrow's way (so it never sits on the arrow or the character).
	var half := size * 0.5
	var push := absf(dir.x) * half.x + absf(dir.y) * half.y
	var centre := tip + dir * (push + 8.0)
	var text_at := centre + Vector2(-half.x, FONT * 0.35)
	draw_string_outline(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, 5, Color(0, 0, 0, alpha * 0.85))
	draw_string(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color(color.lerp(Color.WHITE, 0.45), alpha))
	# On the place itself: a ring that keeps opening out.
	var k := fmod(_t * 0.8, 1.0)
	draw_arc(to, 16.0 + 44.0 * k, 0.0, TAU, 40, Color(color, alpha * (1.0 - k)), 3.0)
	draw_arc(to, 12.0, 0.0, TAU, 28, Color(color, alpha * 0.7), 2.0)


## How far out from the character the arrow starts the way `dir` (screen
## px): clear of it at the camera's zoom.
func _radius(dir: Vector2) -> float:
	var zoom := follow.get_viewport().get_canvas_transform().get_scale().x if follow != null else 2.6
	var e := BODY * zoom
	# (the ellipse's radius the way `dir` goes)
	return e.x * e.y / sqrt(pow(e.y * dir.x, 2) + pow(e.x * dir.y, 2)) + GAP
