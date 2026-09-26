extends Node2D

@onready var player: Player = $Player
@onready var bobber: Node2D = $Bobber
@onready var line: Line2D = $Line
@onready var lure: LureVisual = $Bobber/Lure

var _reset_combo_held := false

## User feedback: the only ripple left is a small ring where a cast lands.
const CAST_RING_RADIUS := 20.0

## User feedback: once a fish is on, the line end mustn't sit still. It
## jerks at the bite; while reeled it swims about the line end, bolts during
## a run (away from the angler, or the way a rare fish is pulling), and is
## dragged in as the reel progress climbs. Purely visual - the fight's
## rules live in Player.
## User feedback: that was far too wild - the fish only shifts about a little
## around where it bit, and comes in closer as its stamina (the reel
## progress) runs down.
const FISH_ROAM := 7.0
const FISH_RUN_ROAM := 15.0
const FISH_PULL_IN := 0.85
const FISH_DIVE_REACH := 40.0

## User request: a hooked fish is felt, not just read in the top-left log -
## the camera kicks at the bite and at the hook-set, and trembles slightly
## all through the fight (harder while the fish runs).
const SHAKE_BITE := 5.0
const SHAKE_HOOK := 4.0
const SHAKE_FIGHT := 0.8
const SHAKE_RUN := 2.0
const SHAKE_DECAY := 14.0

var _shake := 0.0
var _shown_progress := 0.0

## User decision (Diablo II as the reference for scale): walking about, the
## camera sits close; the moment fishing starts - charging, waiting, the
## fight - it eases out just enough to keep the player and where the line
## is going both on screen, framed between them, then eases back in.
const WALK_ZOOM := 2.6
const MIN_ZOOM := 1.0
const FRAME_MARGIN := Vector2(70.0, 60.0)
const ZOOM_EASE := 2.2
const FRAME_EASE := 3.0

var _frame_offset := Vector2.ZERO

var _fish_offset := Vector2.ZERO
var _fish_goal := Vector2.ZERO
var _fish_goal_timer := 0.0

## Now and then a fish leaps somewhere in the water near the player
## (user feedback: every 10-25 s, not 5-12).
const FISH_JUMP_INTERVAL := Vector2(10.0, 25.0)
const FISH_JUMP_RANGE := 420.0

var _fish_jump_timer := 12.0


func _ready() -> void:
	add_child(Atmosphere.new())
	# Above the breathing-darkness vignette (Atmosphere, layer 1).
	$HUD.layer = 2
	# Phones (the web build on iPhone): on-screen buttons for the keys, and
	# the long keyboard help text would sit right under them.
	add_child(TouchControls.new())
	# The object buttons (ActionPrompt) take a touch before the sticks and
	# the on-screen buttons do: input goes to the last in the tree first.
	move_child($ActionPrompt, -1)
	if DisplayServer.is_touchscreen_available():
		$HUD/Panel/HelpLabel.visible = false
		# User request: see-through controls, the sticks included.
		for stick in [$HUD/Panel/MoveJoystick, $HUD/Panel/AimJoystick]:
			stick.modulate.a = 0.45
	player.cast_started.connect(_on_cast_started)
	player.bite_started.connect(_on_bite_started)
	player.hook_success.connect(_on_hook_success)
	player.nibble.connect(_on_nibble)
	player.fight_event.connect(_on_fight_event)
	player.line_cleared.connect(_on_line_cleared)
	# User request: sound (AudioDirector plays the game through Sfx).
	add_child(AudioDirector.new())
	# Rain, snow, falling leaves, fireflies (WeatherFx).
	add_child(WeatherFx.new())
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
	_update_fish_jumps(delta)
	_update_camera(delta)

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
	lure.pick(player.fishing_mode == Player.FishingMode.LURE, int(player.lure_def().get("sprite", -1)))
	_fish_offset = Vector2.ZERO
	_fish_goal = Vector2.ZERO
	# User feedback: no more rolling waves - just a small ring where the
	# cast lands.
	Ripple.spawn(self, target_pos, CAST_RING_RADIUS, 0.55, 1.2)
	if Ripple.water_at(get_tree(), target_pos) != null:
		SplashFx.play(self, "splash_land", target_pos)
	bobber.modulate = Color.WHITE
	line.visible = true


## User feedback: species have a distinct color (FishData.SPECIES) as the
## one "appearance" difference available without real art - reveal it on
## the bobber only once the bite happens, keeping the same suspense as the
## existing rare/heart bite messages.
func _on_bite_started() -> void:
	bobber.modulate = player.current_fish_color
	lure.float_state = LureVisual.FloatState.BITING
	_shake = maxf(_shake, SHAKE_BITE)
	SplashFx.play(self, "splash_bite", bobber.global_position)


func _on_hook_success() -> void:
	lure.float_state = LureVisual.FloatState.HOOKED
	_shake = maxf(_shake, SHAKE_HOOK)


func _update_camera(delta: float) -> void:
	var cam: Camera2D = player.get_node("Camera2D")
	# Framing: what the shot has to include besides the player.
	var focus := Vector2.ZERO
	var fishing := true
	match player.state:
		Player.State.CHARGING:
			var ratio: float = player.charge_time / Player.MAX_CHARGE_TIME
			focus = player.aim_dir * lerpf(Player.MIN_CAST_DIST, player.max_cast_dist, ratio)
		Player.State.WAITING, Player.State.BITE, Player.State.REELING:
			focus = bobber.global_position - player.global_position
		_:
			fishing = false
	var zoom := WALK_ZOOM
	var frame := Vector2.ZERO
	if fishing:
		var view := get_viewport().get_visible_rect().size
		var need := focus.abs() * 0.5 + FRAME_MARGIN
		zoom = clampf(minf(view.x * 0.5 / need.x, view.y * 0.5 / need.y), MIN_ZOOM, WALK_ZOOM)
		frame = focus * 0.5
	var z := lerpf(cam.zoom.x, zoom, minf(1.0, delta * ZOOM_EASE))
	cam.zoom = Vector2(z, z)
	_frame_offset = _frame_offset.lerp(frame, minf(1.0, delta * FRAME_EASE))

	var floor_amount := 0.0
	if player.state == Player.State.REELING:
		floor_amount = SHAKE_RUN if player.fish_run_active_time > 0.0 else SHAKE_FIGHT
	_shake = maxf(move_toward(_shake, 0.0, SHAKE_DECAY * delta), floor_amount)
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.05 else Vector2.ZERO
	# The camera's limits clamp its own position before the offset is
	# added, so fishing near the map's edge the framing offset shoved the
	# player off screen. Aim the view's center instead, kept inside the
	# limits, offset from where the clamped camera actually sits.
	var half := get_viewport().get_visible_rect().size * 0.5 / z
	var lo := Vector2(cam.limit_left, cam.limit_top) + half
	var hi := Vector2(cam.limit_right, cam.limit_bottom) - half
	var base := player.global_position.clamp(lo, hi)
	var center := (player.global_position + _frame_offset).clamp(lo, hi)
	cam.offset = center - base + shake


func _on_line_cleared() -> void:
	bobber.visible = false
	line.visible = false
	line.points = PackedVector2Array()


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
		return


## Toward the nearest bank from `from` (for a fish dashing for cover).
func _cover_dir(from: Vector2) -> Vector2:
	var zone: WaterZone = Ripple.water_at(get_tree(), from)
	if zone == null:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_d := INF
	for i in 12:
		var d := Vector2.RIGHT.rotated(i * TAU / 12.0)
		for step in range(1, 30):
			if not zone.contains(from + d * step * 6.0):
				if step < best_d:
					best_d = step
					best = d
				break
	return best


func _on_nibble(fake: bool) -> void:
	lure.dip(LureVisual.DIP_FAKE if fake else LureVisual.DIP_NIBBLE)


func _on_fight_event(kind: String) -> void:
	match kind:
		"jump":
			var right := randf() < 0.5
			SplashFx.play(self, "fish_jump_right" if right else "fish_jump_left", bobber.global_position)
			_shake = maxf(_shake, SHAKE_HOOK)
		"enrage":
			_shake = maxf(_shake, SHAKE_BITE)


func _fish_motion(delta: float, base: Vector2) -> Vector2:
	match player.state:
		Player.State.BITE:
			# Short, sharp tugs around the bite.
			_fish_goal_timer -= delta
			if _fish_goal_timer <= 0.0:
				_fish_goal_timer = randf_range(0.08, 0.2)
				_fish_goal = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(1.5, 4.0)
			_fish_offset = _fish_offset.lerp(_fish_goal, minf(1.0, delta * 20.0))
		Player.State.REELING:
			var fight: FishFight = player.fight
			var running: bool = fight.run_left > 0.0
			_shown_progress = lerpf(_shown_progress, player.progress, minf(1.0, delta * 2.0))
			base = base.lerp(player.global_position, _shown_progress * FISH_PULL_IN)
			var away := (base - player.global_position).normalized()
			_fish_goal_timer -= delta
			if fight.dive_active:
				# Dashing for the bank: slides toward the nearest shore as
				# the dive gains ground.
				_fish_goal = _cover_dir(base) * fight.dive * FISH_DIVE_REACH
			elif running and fight.run_side != Vector2.ZERO:
				_fish_goal = fight.run_side * FISH_RUN_ROAM
			elif _fish_goal_timer <= 0.0:
				_fish_goal_timer = randf_range(0.2, 0.45) if running else randf_range(0.5, 1.1)
				var dir := Vector2.RIGHT.rotated(randf() * TAU)
				if running:
					dir = (dir + away * 1.2).normalized()
				_fish_goal = dir * randf_range(0.5, 1.0) * (FISH_RUN_ROAM if running else FISH_ROAM)
			_fish_offset = _fish_offset.lerp(_fish_goal, minf(1.0, delta * (6.0 if running or fight.dive_active else 2.5)))
		_:
			_fish_offset = Vector2.ZERO
			_shown_progress = 0.0
			return _keep_in_water(base)
	var pos := base + _fish_offset
	if Ripple.water_at(get_tree(), pos) == null:
		# Hit the shore: turn back toward open water.
		_fish_offset *= 0.6
		_fish_goal = -_fish_goal * 0.5
	return _keep_in_water(pos)


## User bug report: a fish being fought (or a lure reeled in) could cross
## the bank. Anything past the shore is pulled back along the line to the
## last point still inside the water it was cast into.
func _keep_in_water(pos: Vector2) -> Vector2:
	var anchor: Vector2 = player.cast_target
	var zone: WaterZone = Ripple.water_at(get_tree(), anchor)
	if zone == null or zone.contains(pos):
		return pos
	var inside := anchor
	var outside := pos
	for _i in 12:
		var mid := (inside + outside) * 0.5
		if zone.contains(mid):
			inside = mid
		else:
			outside = mid
	return inside + (anchor - inside).limit_length(3.0)
