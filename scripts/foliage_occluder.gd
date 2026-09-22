extends Node2D

## Design doc request: obstacles that cover the player from above (tree
## canopy) or around them (bushes) should visually reveal the player
## through them, using the common semi-transparent-when-behind trick,
## since we don't have real sprite Y-sorting yet.

const OCCLUDED_ALPHA := 0.35
const FADE_SPEED := 6.0

var _target_alpha: float = 1.0

@onready var visual: CanvasItem = $Visual
@onready var area: Area2D = $Area2D


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	var next: float = move_toward(visual.modulate.a, _target_alpha, FADE_SPEED * delta)
	visual.modulate.a = next


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_target_alpha = OCCLUDED_ALPHA


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_target_alpha = 1.0
