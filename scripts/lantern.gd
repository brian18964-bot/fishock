extends PointLight2D

## Directional lantern (design doc §2.1). Brightness trades light reach for
## fuel burn; standing in a fixed light (altar) refuels instead of draining.
## `[` / `]` are desktop placeholders for a future HUD brightness control.

const MAX_FUEL := 100.0
const DRAIN_RATE := 7.0
const REFUEL_RATE := 35.0
const MIN_BRIGHTNESS := 0.35
const MAX_BRIGHTNESS := 1.0
const BRIGHTNESS_STEP := 0.5
const MIN_SCALE := 1.1
const MAX_SCALE := 2.6

var fuel: float = MAX_FUEL
var brightness: float = 0.75

@onready var _player: Node2D = get_parent()


func _ready() -> void:
	texture = LightTextureFactory.make_cone_texture()
	color = Color(1.0, 0.92, 0.75)


func _process(delta: float) -> void:
	_handle_brightness_input(delta)

	if _player.in_altar_zone:
		fuel = min(fuel + REFUEL_RATE * delta, MAX_FUEL)
	else:
		fuel = max(fuel - DRAIN_RATE * brightness * delta, 0.0)

	var out_of_fuel := fuel <= 0.0
	visible = not out_of_fuel
	rotation = _player.aim_dir.angle()
	texture_scale = lerp(MIN_SCALE, MAX_SCALE, brightness)
	energy = lerp(0.7, 1.3, brightness)


func _handle_brightness_input(delta: float) -> void:
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		brightness = clamp(brightness - BRIGHTNESS_STEP * delta, MIN_BRIGHTNESS, MAX_BRIGHTNESS)
	elif Input.is_key_pressed(KEY_BRACKETRIGHT):
		brightness = clamp(brightness + BRIGHTNESS_STEP * delta, MIN_BRIGHTNESS, MAX_BRIGHTNESS)
