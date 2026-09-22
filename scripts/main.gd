extends Node2D

@onready var player: Player = $Player
@onready var bobber: Node2D = $Bobber
@onready var line: Line2D = $Line

var _reset_combo_held := false


func _ready() -> void:
	player.cast_started.connect(_on_cast_started)
	player.line_cleared.connect(_on_line_cleared)
	# Covers opening this scene directly (e.g. F6 in the editor) without
	# going through the title screen's Start button.
	GameState.start_run()


func _process(_delta: float) -> void:
	if bobber.visible:
		line.points = PackedVector2Array([player.global_position, bobber.global_position])

	# Debug convenience: Shift+R restarts the run without reopening Godot.
	var reset_combo := Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_R)
	if reset_combo and not _reset_combo_held:
		GameState.reset_run()
		GameState.start_run()
		player.reset_gear()
	_reset_combo_held = reset_combo


func _on_cast_started(target_pos: Vector2, _tier: String) -> void:
	bobber.global_position = target_pos
	bobber.visible = true
	line.visible = true


func _on_line_cleared() -> void:
	bobber.visible = false
	line.visible = false
	line.points = PackedVector2Array()
