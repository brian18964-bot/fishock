extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var bobber: Node2D = $Bobber
@onready var line: Line2D = $Line


func _ready() -> void:
	player.cast_started.connect(_on_cast_started)
	player.line_cleared.connect(_on_line_cleared)


func _process(_delta: float) -> void:
	if bobber.visible:
		line.points = PackedVector2Array([player.global_position, bobber.global_position])


func _on_cast_started(target_pos: Vector2, _tier: String) -> void:
	bobber.global_position = target_pos
	bobber.visible = true
	line.visible = true


func _on_line_cleared() -> void:
	bobber.visible = false
	line.visible = false
	line.points = PackedVector2Array()
