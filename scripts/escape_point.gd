extends Area2D

@onready var light: PointLight2D = $Light

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.65
	light.color = Color(0.6, 1.0, 0.9)
	light.energy = 1.4

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_escape"):
		body.set_in_escape(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_escape"):
		body.set_in_escape(false)
