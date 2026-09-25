extends Area2D

## User request: the escape point is a pair of rune stones (the user's
## standing stones, runes carved in by tools/render_props.py). They stand
## dark all day; only once the sacrifice quota is met (GameState's ESCAPE
## phase) do the runes light up - and only then is it a way out, and a
## ghost-proof light like a lit fuel station.

const SHEET := [preload("res://assets/sprites/rune_stones/rune_stones_55deg_albedo.png"),
	preload("res://assets/sprites/rune_stones/rune_stones_55deg_normal.png")]
const GLOW := preload("res://assets/sprites/rune_stones/rune_stones_55deg_glow.png")
const SPRITE_SCALE := 0.5
## (center_x, -center_y) * 27.108 for the render's camera (render_props.py).
const OFFSET := Vector2(0.71, -27.6)
const RUNE_COLOR := Color(0.45, 1.0, 0.85)
## Seconds for the runes to come up to full glow.
const WAKE_TIME := 2.5

var _glow_level := 0.0
var _time := 0.0

@onready var light: PointLight2D = $Light
@onready var glow: Sprite2D = $Glow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	var visual: Sprite2D = $Visual
	visual.texture = tex
	Art.place(visual, OFFSET, SPRITE_SCALE)
	glow.texture = GLOW
	Art.place(glow, OFFSET, SPRITE_SCALE)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = add
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.65
	light.color = RUNE_COLOR
	light.energy = 1.4
	light.height = Lantern.LIGHT_HEIGHT
	light.shadow_enabled = true
	LightTwin.attach(light)

func _process(delta: float) -> void:
	_time += delta
	var open := GameState.day_phase == GameState.DayPhase.ESCAPE and not GameState.run_over
	_glow_level = move_toward(_glow_level, 1.0 if open else 0.0, delta / WAKE_TIME)
	var pulse := 0.85 + 0.15 * sin(_time * 2.4)
	glow.visible = _glow_level > 0.0
	glow.modulate = Color(RUNE_COLOR, _glow_level * pulse)
	# The light (and with it the ghosts' keep-out circle) is on once the
	# runes are fully awake.
	light.visible = open
	light.energy = 1.4 * _glow_level * pulse

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_escape"):
		body.set_in_escape(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_escape"):
		body.set_in_escape(false)
