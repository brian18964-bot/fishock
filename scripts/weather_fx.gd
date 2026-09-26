class_name WeatherFx
extends Node2D

## User request (map styles, atmosphere): what's in the air. Rain in a
## storm; snow falling on snow maps (a blizzard in a storm); leaves drifting
## down in autumn; fireflies at dusk and at night - drawn on their own
## canvas so the darkness doesn't dim them, glowing like the real thing.
## CPU particles in world space around the camera, a few hundred at most
## (phones).

const RAIN := 150
const SNOW := 70
const BLIZZARD := 140
const LEAVES := 12
const FIREFLIES := 22
const AREA := Vector2(340.0, 230.0)
const FIREFLY_THEMES_BY_DAY := ["swamp", "jungle"]
const NO_FIREFLIES := ["snow"]

var _theme := ""
var _rain: CPUParticles2D
var _snow: CPUParticles2D
var _blizzard: CPUParticles2D
var _leaves: CPUParticles2D
var _flies: CPUParticles2D
var _fly_layer: CanvasLayer


func _ready() -> void:
	z_index = 35
	var gen := get_parent().get_node_or_null("MapGenerator")
	if gen != null:
		_theme = gen.theme_name
	_rain = _emitter(RAIN, 0.45, _streak_texture(), Color(0.75, 0.82, 0.95, 0.45))
	_rain.direction = Vector2(0.18, 1.0)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 520.0
	_rain.initial_velocity_max = 640.0
	_rain.gravity = Vector2.ZERO
	if _theme == "snow":
		_snow = _snowfall(SNOW, 0.85)
		_blizzard = _snowfall(BLIZZARD, 1.0)
		_blizzard.initial_velocity_min = 60.0
		_blizzard.initial_velocity_max = 110.0
		_blizzard.direction = Vector2(0.9, 0.6)
	if _theme == "autumn":
		_leaves = _emitter(LEAVES, 7.0, _leaf_texture(), Color.WHITE)
		_leaves.direction = Vector2(0.5, 1.0)
		_leaves.spread = 40.0
		_leaves.initial_velocity_min = 14.0
		_leaves.initial_velocity_max = 30.0
		_leaves.gravity = Vector2(0, 4)
		_leaves.angular_velocity_min = -160.0
		_leaves.angular_velocity_max = 160.0
		_leaves.angle_max = 360.0
		var tints := Gradient.new()
		tints.colors = PackedColorArray([Color(0.85, 0.35, 0.1), Color(0.75, 0.18, 0.08), Color(0.9, 0.62, 0.15)])
		tints.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_leaves.color_initial_ramp = tints
		_leaves.emitting = true
	if _theme not in NO_FIREFLIES:
		_fly_layer = CanvasLayer.new()
		_fly_layer.layer = 1
		_fly_layer.follow_viewport_enabled = true
		add_child(_fly_layer)
		_flies = _emitter(FIREFLIES, 4.0, _glow_texture(), Color(0.85, 1.0, 0.45), _fly_layer)
		_flies.direction = Vector2.RIGHT
		_flies.spread = 180.0
		_flies.initial_velocity_min = 5.0
		_flies.initial_velocity_max = 16.0
		_flies.gravity = Vector2.ZERO
		_flies.scale_amount_min = 0.55
		_flies.scale_amount_max = 1.25
		var pulse := Gradient.new()
		pulse.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		pulse.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		_flies.color_ramp = pulse
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_flies.material = add


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	for e in [_rain, _snow, _blizzard, _leaves, _flies]:
		if e != null:
			e.global_position = center
	var storm := GameState.weather == GameState.Weather.STORM
	_rain.emitting = storm and _theme != "snow"
	if _snow != null:
		_snow.emitting = not storm
		_blizzard.emitting = storm
	if _flies != null:
		_flies.emitting = GameState.is_night or GameState.light_stage() >= 2 or _theme in FIREFLY_THEMES_BY_DAY


func _emitter(amount: int, lifetime: float, tex: Texture2D, color: Color, parent: Node = self) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = amount
	e.lifetime = lifetime
	e.preprocess = lifetime
	e.local_coords = false
	e.texture = tex
	e.color = color
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = AREA
	e.emitting = false
	parent.add_child(e)
	return e


func _snowfall(amount: int, alpha: float) -> CPUParticles2D:
	var e := _emitter(amount, 6.0, _glow_texture(), Color(0.95, 0.97, 1.0, alpha))
	e.direction = Vector2(0.25, 1.0)
	e.spread = 25.0
	e.initial_velocity_min = 16.0
	e.initial_velocity_max = 34.0
	e.gravity = Vector2(0, 5)
	e.scale_amount_min = 0.18
	e.scale_amount_max = 0.42
	return e


static func _streak_texture() -> Texture2D:
	var img := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 2:
			img.set_pixel(x, y, Color(1, 1, 1, float(y) / 13.0))
	return ImageTexture.create_from_image(img)


static func _glow_texture() -> Texture2D:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


static func _leaf_texture() -> Texture2D:
	var img := Image.create(8, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 8:
			var d := Vector2((x + 0.5 - 4.0) / 4.0, (y + 0.5 - 2.5) / 2.5).length()
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 1.0 else 0.0))
	return ImageTexture.create_from_image(img)
