class_name LureGuide
extends Node2D

## Where the 誘惑 throw will land while it's being charged (Player's lure
## throw): a dotted arc from the player to a ring on the ground.

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	visible = false


func show_throw(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	visible = true
	queue_redraw()


func hide_throw() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var col := Color(1.0, 0.75, 0.45, 0.85)
	var d := _from.distance_to(_to)
	var n := maxi(int(d / 14.0), 2)
	for i in range(1, n):
		var k := float(i) / n
		var p := _from.lerp(_to, k) + Vector2(0, -sin(k * PI) * minf(d * 0.35, 80.0))
		draw_circle(p, 2.2, Color(col, 0.35 + 0.5 * k))
	var r := 12.0 + sin(_t * 6.0) * 2.0
	draw_arc(_to, r, 0.0, TAU, 28, col, 2.0)
	draw_arc(_to, r * 0.45, 0.0, TAU, 16, Color(col, 0.5), 1.5)
