class_name GuideArrow
extends Node2D

## User request (round 7, round 8): the eyes and the binoculars show the
## way - to the 渡石, the altar, the nearest ghost (`track`: a moving
## target), the nearest water - for a while, then fading out.
## User request: not so loud - an arrow lying on the ground round the
## character's feet (drawn squashed as the ground is), faint, its colour
## soft; chevrons drifting out along it; the place's name and how far by
## its head, small; a faint ring on the place itself. Unlit (so it reads in
## the dark) but see-through. A child of the player, at its feet, under it.

## Where it starts out from the feet (world px), its length, the head's
## width and length, the shaft's width; how flat the ground's drawn.
const START := 15.0
const LENGTH := 24.0
const HEAD := 15.0
const HEAD_LENGTH := 10.0
const SHAFT := 5.0
const SQUASH := 0.819
const ALPHA := 0.42
## How much of its colour (the rest grey).
const SOFT := 0.5
const FONT := 8
## World px to a 公尺 shown.
const PX_PER_M := 16.0
const FADE := 0.6

var target := Vector2.ZERO
var follow: Node2D
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
	z_index = -1
	show_behind_parent = true
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
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
	queue_redraw()


## A point of the ground round the feet: `along` the way, `across` it.
func _ground(dir: Vector2, along: float, across: float) -> Vector2:
	var p := dir * along + dir.orthogonal() * across
	return Vector2(p.x, p.y * SQUASH)


func _draw() -> void:
	var fade := clampf(time_left / FADE, 0.0, 1.0)
	var to := to_local(target)
	# (the way on the ground: the screen's way, unsquashed)
	var flat := Vector2(to.x, to.y / SQUASH)
	var dir := flat.normalized() if flat.length() > 1.0 else Vector2.UP
	var soft := color.lerp(Color(0.75, 0.75, 0.75), 1.0 - SOFT)
	var c := Color(soft, ALPHA * fade)
	var tip := START + LENGTH
	var neck := tip - HEAD_LENGTH
	var arrow := PackedVector2Array([
		_ground(dir, START, SHAFT * 0.5), _ground(dir, neck, SHAFT * 0.5), _ground(dir, neck, HEAD * 0.5),
		_ground(dir, tip, 0.0), _ground(dir, neck, -HEAD * 0.5), _ground(dir, neck, -SHAFT * 0.5),
		_ground(dir, START, -SHAFT * 0.5)])
	# A soft halo, then the arrow itself.
	var halo := PackedVector2Array()
	var middle := _ground(dir, (START + tip) * 0.5, 0.0)
	for p in arrow:
		halo.append(middle + (p - middle) * 1.18)
	draw_colored_polygon(halo, Color(soft, ALPHA * 0.3 * fade))
	draw_colored_polygon(arrow, c)
	# Chevrons drifting out ahead of it.
	for i in 2:
		var k := fmod(_t * 0.7 + i * 0.5, 1.0)
		var at := tip + 4.0 + 14.0 * k
		var a := ALPHA * 0.8 * sin(k * PI) * fade
		draw_polyline(PackedVector2Array([_ground(dir, at - 4.0, 4.5), _ground(dir, at, 0.0), _ground(dir, at - 4.0, -4.5)]),
			Color(soft, a), 1.6, true)
	# The name and how far, small, past the head.
	var meters := roundi(target.distance_to(global_position) / PX_PER_M)
	var text := "%s %d 公尺" % [label, meters] if meters > 2 else label
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT)
	var half := size * 0.5
	var head_at := _ground(dir, tip + 20.0, 0.0)
	var push := absf(dir.x) * half.x + absf(dir.y) * half.y * 0.6
	var centre := head_at + Vector2(dir.x, dir.y * SQUASH) * push
	var text_at := centre + Vector2(-half.x, FONT * 0.35)
	draw_string_outline(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, 2, Color(0, 0, 0, 0.45 * fade))
	draw_string(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color(soft.lerp(Color.WHITE, 0.3), 0.7 * fade))
	# On the place itself: a faint ring on the ground, opening out.
	var k := fmod(_t * 0.6, 1.0)
	draw_set_transform(to, 0.0, Vector2(1.0, SQUASH))
	draw_arc(Vector2.ZERO, 10.0 + 22.0 * k, 0.0, TAU, 40, Color(soft, ALPHA * (1.0 - k) * fade), 1.5, true)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 28, Color(soft, ALPHA * 0.8 * fade), 1.2, true)
	draw_set_transform(Vector2.ZERO)
