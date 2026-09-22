extends Area2D

@onready var light: PointLight2D = $Light

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.65
	light.color = Color(1.0, 0.85, 0.55)
	light.energy = 1.4

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_altar"):
		body.set_in_altar(false)
