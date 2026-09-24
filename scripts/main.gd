extends Node2D

@onready var player: Player = $Player
@onready var bobber: Node2D = $Bobber
@onready var line: Line2D = $Line
@onready var lure: LureVisual = $Bobber/Lure

var _reset_combo_held := false

## Water ripples (see Ripple): a lure leaves a wake ring every WAKE_SPACING
## px it's reeled, a waiting bobber bobs one out every BOB_INTERVAL s, and
## the player sends one out every WADE_SPACING px walked through water.
## User feedback: too many ripples - spaced out ~1.6x.
const WAKE_SPACING := 22.0
const BOB_INTERVAL := 2.6
const WADE_SPACING := 26.0
const PLAYER_FEET := Vector2(0, 8)

## User feedback: once a fish is on, the line end mustn't sit still. It
## jerks at the bite; while reeled it swims about the line end, bolts during
## a run (away from the angler, or the way a rare fish is pulling), and is
## dragged in as the reel progress climbs. Purely visual - the fight's
## rules live in Player.
const FISH_ROAM := 34.0
const FISH_RUN_ROAM := 72.0
const FISH_WAKE_SPACING := 16.0

var _fish_offset := Vector2.ZERO
var _fish_goal := Vector2.ZERO
var _fish_goal_timer := 0.0

## Now and then a fish leaps somewhere in the water near the player
## (user feedback: every 10-25 s, not 5-12).
const FISH_JUMP_INTERVAL := Vector2(10.0, 25.0)
const FISH_JUMP_RANGE := 420.0

var _fish_jump_timer := 12.0
var _last_wake_pos := Vector2.INF
var _last_wade_pos := Vector2.INF
var _bob_timer := 0.0


func _ready() -> void:
	add_child(WaterSim.new())
	# Phones (the web build on iPhone): on-screen buttons for the keys, and
	# the long keyboard help text would sit right under them.
	add_child(TouchControls.new())
	if DisplayServer.is_touchscreen_available():
		$HUD/Panel/HelpLabel.visible = false
		# User request: see-through controls, the sticks included.
		for stick in [$HUD/Panel/MoveJoystick, $HUD/Panel/AimJoystick]:
			stick.modulate.a = 0.45
	player.cast_started.connect(_on_cast_started)
	player.bite_started.connect(_on_bite_started)
	player.hook_success.connect(func(): lure.float_state = LureVisual.FloatState.HOOKED)
	player.line_cleared.connect(_on_line_cleared)
	# Covers opening this scene directly (e.g. F6 in the editor) without
	# going through the title screen's Start button.
	GameState.start_run()


func _process(delta: float) -> void:
	if bobber.visible:
		# Continuously tracks rather than a fixed point set once, so a
		# lure being reeled in visibly moves back toward the player.
		bobber.global_position = _fish_motion(delta, player.get_line_target_position())
		var rod: Node2D = player.get_node("Rod")
		line.points = PackedVector2Array([rod.tip_position(), bobber.global_position])
		if lure.is_lure:
			lure.face(player.global_position)
		_update_line_ripples(delta)
	_update_wading_ripples()
	_update_fish_jumps(delta)

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
	# Lure mode shows a rendered lure; bobber mode the float.
	lure.pick(player.fishing_mode == Player.FishingMode.LURE)
	_fish_offset = Vector2.ZERO
	_fish_goal = Vector2.ZERO
	# Splashdown: a big ring, then a smaller echo.
	_last_wake_pos = target_pos
	_bob_timer = BOB_INTERVAL
	Ripple.spawn(self, target_pos, 36.0, 1.0, 1.7)
	if Ripple.water_at(get_tree(), target_pos) != null:
		SplashFx.play(self, "splash_land", target_pos)
	get_tree().create_timer(0.3).timeout.connect(func(): Ripple.spawn(self, target_pos, 22.0, 0.7, 1.4))
	bobber.modulate = Color.WHITE
	line.visible = true


## User feedback: species have a distinct color (FishData.SPECIES) as the
## one "appearance" difference available without real art - reveal it on
## the bobber only once the bite happens, keeping the same suspense as the
## existing rare/heart bite messages.
func _on_bite_started() -> void:
	bobber.modulate = player.current_fish_color
	lure.float_state = LureVisual.FloatState.BITING
	SplashFx.play(self, "splash_bite", bobber.global_position)
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
	if player.state == Player.State.BITE or player.state == Player.State.REELING:
		# A hooked fish leaves a wake wherever it thrashes.
		if _last_wake_pos.distance_to(pos) >= FISH_WAKE_SPACING:
			_last_wake_pos = pos
			Ripple.spawn(self, pos, 16.0, 0.8, 1.0)
	elif player.fishing_mode == Player.FishingMode.LURE:
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


func _update_fish_jumps(delta: float) -> void:
	_fish_jump_timer -= delta
	if _fish_jump_timer > 0.0:
		return
	_fish_jump_timer = randf_range(FISH_JUMP_INTERVAL.x, FISH_JUMP_INTERVAL.y)
	# A spot well inside some water near the player, if there is one.
	for _try in 12:
		var pos := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, FISH_JUMP_RANGE)
		var zone: WaterZone = Ripple.water_at(get_tree(), pos)
		if zone == null or not zone.is_deep(pos, 30.0):
			continue
		var right := randf() < 0.5
		SplashFx.play(self, "fish_jump_right" if right else "fish_jump_left", pos)
		var dx := SplashFx.FISH_HALF_SPAN * (1.0 if right else -1.0)
		Ripple.spawn(self, pos - Vector2(dx, 0), 20.0, 0.7)
		get_tree().create_timer(0.6).timeout.connect(func(): Ripple.spawn(self, pos + Vector2(dx, 0), 26.0, 0.9))
		return


func _fish_motion(delta: float, base: Vector2) -> Vector2:
	match player.state:
		Player.State.BITE:
			# Short, sharp tugs around the bite.
			_fish_goal_timer -= delta
			if _fish_goal_timer <= 0.0:
				_fish_goal_timer = randf_range(0.08, 0.2)
				_fish_goal = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(3.0, 9.0)
			_fish_offset = _fish_offset.lerp(_fish_goal, minf(1.0, delta * 20.0))
		Player.State.REELING:
			var running: bool = player.fish_run_active_time > 0.0
			base = base.lerp(player.global_position, player.progress * 0.8)
			_fish_goal_timer -= delta
			if _fish_goal_timer <= 0.0:
				_fish_goal_timer = randf_range(0.2, 0.45) if running else randf_range(0.5, 1.1)
				var dir := Vector2.RIGHT.rotated(randf() * TAU)
				if player.is_rare_catch:
					dir = (dir + player.rare_pull_dir * 1.5).normalized()
				elif running:
					dir = (dir + (base - player.global_position).normalized() * 1.2).normalized()
				_fish_goal = dir * randf_range(0.5, 1.0) * (FISH_RUN_ROAM if running else FISH_ROAM)
			_fish_offset = _fish_offset.lerp(_fish_goal, minf(1.0, delta * (6.0 if running else 2.5)))
		_:
			_fish_offset = Vector2.ZERO
			return base
	var pos := base + _fish_offset
	if Ripple.water_at(get_tree(), pos) == null:
		# Hit the shore: turn back toward open water.
		_fish_offset *= 0.6
		_fish_goal = -_fish_goal * 0.5
		pos = base + _fish_offset
		if Ripple.water_at(get_tree(), pos) == null:
			pos = base
	return pos
