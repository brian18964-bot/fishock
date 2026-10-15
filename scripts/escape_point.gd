extends Area2D

## User request: the escape point is a pair of rune stones (the user's
## standing stones, runes carved in by tools/render_props.py). They stand
## dark all day; only once the sacrifice quota is met (GameState's ESCAPE
## phase) do the runes light up - and only then is it a way out, and a
## ghost-proof light like a lit fuel station.

const SPRITE_SCALE := 0.5
## The 渡石's base (px) - the camp's stone at CampStage.STONE_SCALE.
const STONE_RADIUS := 15.0
## (center_x, -center_y) * 27.108 for the render's camera (render_props.py).
const OFFSET := Vector2(0.71, -27.6)
const RUNE_COLOR := Color(0.45, 1.0, 0.85)
## Seconds for the runes to come up to full glow.
const WAKE_TIME := 2.5

var _glow_level := 0.0
var _time := 0.0

@onready var light: PointLight2D = $Light
@onready var glow: Sprite2D = $Glow

func solids() -> Array:
	var out := []
	for s in $Stones.get_children():
		var r: float = (s.shape as CircleShape2D).radius
		out.append([s.global_position, Vector2(r, r)])
	return out


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("solids")
	# User request: one stone, the camp's 渡石 (RunView3D's model) - its
	# base, at the middle; the second pillar's gone.
	var stones := $Stones.get_children()
	for i in stones.size():
		var s: CollisionShape2D = stones[i]
		if i > 0:
			$Stones.remove_child(s)
			s.queue_free()
			continue
		var base := CircleShape2D.new()
		base.radius = STONE_RADIUS
		s.shape = base
		s.position = Vector2.ZERO
	var tex := CanvasTexture.new()
	var visual: Sprite2D = $Visual
	visual.texture = tex
	Art.place(visual, OFFSET, SPRITE_SCALE)
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
