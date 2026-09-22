extends Area2D

## Sacrifice-only now: no refuel, and its light is just a faint marker
## with no ghost-proof safe zone (see ghost.gd - it's not in the
## avoidance list). The fuel station is the actual safe spot.

@onready var light: PointLight2D = $Light

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.4
	light.color = Color(1.0, 0.85, 0.55)
	light.energy = 0.5
	light.shadow_enabled = true

func _process(_delta: float) -> void:
	light.visible = not GameState.is_night

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(false)
