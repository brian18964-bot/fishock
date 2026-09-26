class_name SoundToggle
extends CanvasLayer

## User request (sound, designed blind - it can't be auditioned here): a
## way to turn it off. A small speaker at the top right, under the time;
## tap it (or press M) to mute or unmute. Remembered (Sfx.muted).

const CENTER := Vector2(936, 88)
const RADIUS := 15.0
const INK := Color(1.0, 0.96, 0.88, 0.75)

var _view: Node2D


func _ready() -> void:
	layer = 4
	_view = Node2D.new()
	_view.draw.connect(_draw_icon)
	add_child(_view)


func contains(pos: Vector2) -> bool:
	return pos.distance_to(CENTER) <= RADIUS + 6.0


func _input(event: InputEvent) -> void:
	var hit := false
	if event is InputEventScreenTouch and event.pressed and contains(event.position):
		hit = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not DisplayServer.is_touchscreen_available() and contains(event.position):
		# (Touch screens also send an emulated click; the touch counted.)
		hit = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		hit = true
	if hit:
		Sfx.muted = not Sfx.muted
		_view.queue_redraw()
		get_viewport().set_input_as_handled()


func _draw_icon() -> void:
	var c := CENTER
	_view.draw_circle(c, RADIUS, Color(0.08, 0.07, 0.05, 0.45))
	var body := PackedVector2Array([c + Vector2(-8, -3), c + Vector2(-4, -3), c + Vector2(1, -8),
		c + Vector2(1, 8), c + Vector2(-4, 3), c + Vector2(-8, 3)])
	_view.draw_colored_polygon(body, INK)
	if Sfx.muted:
		_view.draw_line(c + Vector2(4, -4), c + Vector2(10, 4), INK, 2.0)
		_view.draw_line(c + Vector2(10, -4), c + Vector2(4, 4), INK, 2.0)
	else:
		_view.draw_arc(c + Vector2(1, 0), 5.0, -0.9, 0.9, 8, INK, 1.6)
		_view.draw_arc(c + Vector2(1, 0), 9.0, -0.9, 0.9, 10, INK, 1.6)
