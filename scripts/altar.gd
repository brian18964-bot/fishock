extends Area2D

## Sacrifice-only now: no refuel, and its light is just a faint marker
## (always on) with no ghost-proof safe zone (see ghost.gd - it's not in the
## avoidance list). The fuel station is the actual safe spot.
##
## User request: drawn from the user's ancient altar model (a round stone
## dais, tools/render_props.py) - low enough to stand on, so it lies under
## everything like the docks do (z_index -3 in main.tscn).
##
## User request: it shows how the offering's going. Past two thirds of the
## quota it starts to glow, brighter as it fills; once the quota's met it
## settles back to its old faint glow (and Willow, before it, turns round -
## willow.gd). Evil offerings (GameState.evil_count, 1-3) eat into it:
## the stone darkens and stains, its light turns sickly, and a dark haze
## rises off it - worse with each one.

const SHEET := [preload("res://assets/sprites/altar/altar_55deg_albedo.png"),
	preload("res://assets/sprites/altar/altar_55deg_normal.png")]
const SPRITE_SCALE := 0.5
## (0, -center_y) * 27.108 for the render's camera (render_props.py).
const OFFSET := Vector2(0.0, -8.8)
const GLOW_FROM := 2.0 / 3.0
const LIGHT_COLOR := Color(1.0, 0.82, 0.55)
const GLOW_COLOR := Color(1.0, 0.78, 0.4)
const CORRUPT_COLOR := Color(0.6, 0.3, 0.8)
const CORRUPT_TINT := Color(0.55, 0.45, 0.62)
## The dais top, as an ellipse round the origin (world px).
const TOP := Vector2(25.0, 14.0)
const TOP_CENTER := Vector2(0.0, -8.0)

## User request: a faint glow, day and night, so it can be found - it
## breathes a little.
var _time := 0.0
var _glow := 0.0
var _corruption := 0.0
var _stains: Array = []  # [position, radius] per stain, grown as evil comes

@onready var light: PointLight2D = $Light
@onready var visual: Sprite2D = $Visual
var _halo: Sprite2D
var _stain_layer: Node2D
var _haze: CPUParticles2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	visual.texture = tex
	Art.place(visual, OFFSET, SPRITE_SCALE)
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.55
	light.color = LIGHT_COLOR
	light.energy = 0.6
	light.height = Lantern.LIGHT_HEIGHT
	light.shadow_enabled = true
	LightTwin.attach(light)

	# The glow across its top as the offering fills.
	_halo = Sprite2D.new()
	_halo.texture = LightTextureFactory.make_radial_texture(128, 0.6)
	_halo.position = TOP_CENTER
	_halo.scale = Vector2(TOP.x, TOP.y) / 64.0 * 1.3
	_halo.z_index = -2
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo.material = add
	_halo.visible = false
	add_child(_halo)

	# Evil's stains on the stone, and the haze off it.
	_stain_layer = Node2D.new()
	_stain_layer.z_index = -2
	_stain_layer.draw.connect(_draw_stains)
	add_child(_stain_layer)
	for i in 3 * GameState.MAX_EVIL:
		var a := randf() * TAU
		var r := sqrt(randf()) * 0.8
		_stains.append([TOP_CENTER + Vector2(cos(a) * TOP.x, sin(a) * TOP.y) * r, randf_range(4.0, 8.0)])
	_haze = CPUParticles2D.new()
	_haze.emitting = false
	_haze.amount = 18
	_haze.lifetime = 2.6
	_haze.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_haze.emission_rect_extents = TOP * 0.8
	_haze.position = TOP_CENTER
	_haze.direction = Vector2.UP
	_haze.spread = 20.0
	_haze.gravity = Vector2(0, -6)
	_haze.initial_velocity_min = 4.0
	_haze.initial_velocity_max = 10.0
	_haze.scale_amount_min = 1.5
	_haze.scale_amount_max = 3.5
	_haze.color = Color(0.25, 0.1, 0.3, 0.55)
	_haze.z_index = 1
	add_child(_haze)


func _process(delta: float) -> void:
	_time += delta
	var fill := 0.0
	if GameState.quota_target > 0.0 and GameState.day_phase == GameState.DayPhase.FISHING:
		fill = GameState.quota_progress / GameState.quota_target
	var want_glow := clampf((fill - GLOW_FROM) / (1.0 - GLOW_FROM), 0.0, 1.0) if fill >= GLOW_FROM else 0.0
	if fill >= GLOW_FROM:
		want_glow = maxf(want_glow, 0.25)
	_glow = move_toward(_glow, want_glow, delta * 0.8)
	var want_corrupt := clampf(float(GameState.evil_count) / GameState.MAX_EVIL, 0.0, 1.0)
	if not is_equal_approx(_corruption, want_corrupt):
		_corruption = move_toward(_corruption, want_corrupt, delta * 0.5)
		_stain_layer.queue_redraw()

	var breathe := sin(_time * 1.6)
	var glow_pulse := 0.85 + 0.15 * sin(_time * 3.0)
	var base := LIGHT_COLOR.lerp(GLOW_COLOR, _glow)
	light.color = base.lerp(CORRUPT_COLOR, _corruption)
	light.energy = 0.6 + breathe * 0.1 + _glow * 1.0 * glow_pulse
	light.texture_scale = 0.55 + _glow * 0.35
	_halo.visible = _glow > 0.01
	_halo.modulate = Color(GLOW_COLOR.lerp(CORRUPT_COLOR, _corruption), _glow * 0.55 * glow_pulse)
	visual.modulate = Color.WHITE.lerp(CORRUPT_TINT, _corruption)
	_haze.emitting = _corruption > 0.05
	_haze.amount = maxi(4, int(18 * _corruption))


func _draw_stains() -> void:
	if _corruption <= 0.0:
		return
	# Each evil offering spreads a few more stains, and darkens them all.
	var shown := int(ceil(_corruption * _stains.size()))
	for i in shown:
		var st: Array = _stains[i]
		_stain_layer.draw_set_transform(st[0], 0.0, Vector2(1.0, 0.6))
		_stain_layer.draw_circle(Vector2.ZERO, st[1] * (0.6 + 0.4 * _corruption), Color(0.12, 0.03, 0.14, 0.35 + 0.35 * _corruption))
	_stain_layer.draw_set_transform(Vector2.ZERO)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(true)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(false)
