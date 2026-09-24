extends Node2D

@onready var player: Player = $Player
@onready var bobber: Node2D = $Bobber
@onready var line: Line2D = $Line
@onready var lure: Sprite2D = $Bobber/Lure

var _reset_combo_held := false


func _ready() -> void:
	player.cast_started.connect(_on_cast_started)
	player.bite_started.connect(_on_bite_started)
	player.line_cleared.connect(_on_line_cleared)
	# Covers opening this scene directly (e.g. F6 in the editor) without
	# going through the title screen's Start button.
	GameState.start_run()


func _process(_delta: float) -> void:
	if bobber.visible:
		# Continuously tracks rather than a fixed point set once, so a
		# lure being reeled in visibly moves back toward the player.
		bobber.global_position = player.get_line_target_position()
		line.points = PackedVector2Array([player.global_position, bobber.global_position])
		if lure.is_lure:
			lure.face(player.global_position)

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
	# Lure mode shows a rendered lure; bobber mode the worm on the hook.
	lure.pick(player.fishing_mode == Player.FishingMode.LURE)
	bobber.modulate = Color.WHITE
	line.visible = true


## User feedback: species have a distinct color (FishData.SPECIES) as the
## one "appearance" difference available without real art - reveal it on
## the bobber only once the bite happens, keeping the same suspense as the
## existing rare/heart bite messages.
func _on_bite_started() -> void:
	bobber.modulate = player.current_fish_color


func _on_line_cleared() -> void:
	bobber.visible = false
	line.visible = false
	line.points = PackedVector2Array()
