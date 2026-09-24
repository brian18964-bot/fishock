extends Node2D

@onready var player: Player = $Player
@onready var bobber: Node2D = $Bobber
@onready var line: Line2D = $Line
@onready var lure: Sprite2D = $Bobber/Lure

var _reset_combo_held := false

## Water ripples (see Ripple): a lure leaves a wake ring every WAKE_SPACING
## px it's reeled, a waiting bobber bobs one out every BOB_INTERVAL s, and
## the player sends one out every WADE_SPACING px walked through water.
const WAKE_SPACING := 14.0
const BOB_INTERVAL := 1.6
const WADE_SPACING := 16.0
const PLAYER_FEET := Vector2(0, 8)

var _last_wake_pos := Vector2.INF
var _last_wade_pos := Vector2.INF
var _bob_timer := 0.0


func _ready() -> void:
	add_child(WaterSim.new())
	player.cast_started.connect(_on_cast_started)
	player.bite_started.connect(_on_bite_started)
	player.line_cleared.connect(_on_line_cleared)
	# Covers opening this scene directly (e.g. F6 in the editor) without
	# going through the title screen's Start button.
	GameState.start_run()


func _process(delta: float) -> void:
	if bobber.visible:
		# Continuously tracks rather than a fixed point set once, so a
		# lure being reeled in visibly moves back toward the player.
		bobber.global_position = player.get_line_target_position()
		line.points = PackedVector2Array([player.global_position, bobber.global_position])
		if lure.is_lure:
			lure.face(player.global_position)
		_update_line_ripples(delta)
	_update_wading_ripples()

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
	# Splashdown: a big ring, then a smaller echo.
	_last_wake_pos = target_pos
	_bob_timer = BOB_INTERVAL
	Ripple.spawn(self, target_pos, 36.0, 1.0, 1.7)
	get_tree().create_timer(0.3).timeout.connect(func(): Ripple.spawn(self, target_pos, 22.0, 0.7, 1.4))
	bobber.modulate = Color.WHITE
	line.visible = true


## User feedback: species have a distinct color (FishData.SPECIES) as the
## one "appearance" difference available without real art - reveal it on
## the bobber only once the bite happens, keeping the same suspense as the
## existing rare/heart bite messages.
func _on_bite_started() -> void:
	bobber.modulate = player.current_fish_color
	# The fish yanks at the line: a quick burst of sharp rings.
	for i in 3:
		get_tree().create_timer(i * 0.15).timeout.connect(
			func(): Ripple.spawn(self, bobber.global_position, 26.0, 1.2, 1.0))


func _on_line_cleared() -> void:
	bobber.visible = false
	line.visible = false
	line.points = PackedVector2Array()


func _update_line_ripples(delta: float) -> void:
	var pos := bobber.global_position
	if player.fishing_mode == Player.FishingMode.LURE:
		if _last_wake_pos.distance_to(pos) >= WAKE_SPACING:
			_last_wake_pos = pos
			Ripple.spawn(self, pos, 16.0, 0.6, 1.1)
	elif player.state == Player.State.WAITING:
		_bob_timer -= delta
		if _bob_timer <= 0.0:
			_bob_timer = BOB_INTERVAL
			Ripple.spawn(self, pos, 14.0, 0.45, 1.3)


func _update_wading_ripples() -> void:
	var feet := player.global_position + PLAYER_FEET
	if _last_wade_pos.distance_to(feet) >= WADE_SPACING:
		_last_wade_pos = feet
		Ripple.spawn(self, feet, 22.0, 0.7, 1.2)
