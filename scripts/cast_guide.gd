extends Node2D

## User request: the direction a cast will go has to be visible up front.
## While charging, a dotted line runs out to where the cast will land
## (Player.landing_point) and a ring marks the spot - red when there's no
## water that way. (User feedback: no standing arrow in front of the feet.)

const SQUASH := 0.819  # sin 55deg: drawn lying on the ground
const COLOR_AIM := Color(1.0, 0.92, 0.6, 0.55)
const COLOR_OK := Color(0.85, 0.95, 1.0, 0.8)
const COLOR_MISS := Color(1.0, 0.35, 0.3, 0.85)

@onready var _player: Player = get_parent()


func _ready() -> void:
	position = Player.FEET
	z_index = -2
	show_behind_parent = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player.state != Player.State.CHARGING:
		return
	var color := COLOR_AIM
	if _player.state == Player.State.CHARGING:
		var ratio: float = _player.charge_time / Player.MAX_CHARGE_TIME
		var land: Vector2 = _player.landing_point(ratio) - _player.global_position - Player.FEET
		var in_water: bool = _player._find_water_zone(_player.global_position + Player.FEET + land) != null
		color = COLOR_OK if in_water else COLOR_MISS
		# Dotted line out to the landing point, then a ring on the water.
		var length := land.length()
		var n := int(length / 9.0)
		for i in range(2, n):
			draw_circle(land * (float(i) / n), 1.4, Color(color, color.a * 0.8))
		var ring := PackedVector2Array()
		for i in 25:
			var a := i * TAU / 24.0
			ring.append(land + Vector2(cos(a) * 7.0, sin(a) * 7.0 * SQUASH))
		draw_polyline(ring, color, 1.5, true)
