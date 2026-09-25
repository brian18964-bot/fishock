extends Area2D

## Sacrifice-only now: no refuel, and its light is just a faint marker
## (always on) with no ghost-proof safe zone (see ghost.gd - it's not in the
## avoidance list). The fuel station is the actual safe spot.
##
## User request: drawn from the user's ancient altar model (a round stone
## dais, tools/render_props.py) - low enough to stand on, so it lies under
## everything like the docks do (z_index -3 in main.tscn).

const SHEET := [preload("res://assets/sprites/altar/altar_55deg_albedo.png"),
	preload("res://assets/sprites/altar/altar_55deg_normal.png")]
const SPRITE_SCALE := 0.5
## (0, -center_y) * 27.108 for the render's camera (render_props.py).
const OFFSET := Vector2(0.0, -8.8)

@onready var light: PointLight2D = $Light

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	var visual: Sprite2D = $Visual
	visual.texture = tex
	Art.place(visual, OFFSET, SPRITE_SCALE)
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.55
	light.color = Color(1.0, 0.82, 0.55)
	light.energy = 0.6
	light.height = Lantern.LIGHT_HEIGHT
	light.shadow_enabled = true
	LightTwin.attach(light)

## User request: a faint glow, day and night, so it can be found - it
## breathes a little.
var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	light.energy = 0.6 + sin(_time * 1.6) * 0.1

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(false)
