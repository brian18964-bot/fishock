class_name Player
extends CharacterBody2D

signal state_changed(new_state: String)
signal cast_started(target_pos: Vector2, tier: String)
signal bite_started()
signal hook_success()
signal reel_progress(progress: float, tension: float)
signal catch_success(fish: Dictionary)
signal catch_failed(reason: String)
signal line_cleared()

enum State { IDLE, CHARGING, WAITING, BITE, REELING }

const SPEED := 140.0
const MAX_CHARGE_TIME := 1.2
const MIN_CAST_DIST := 40.0
const MAX_CAST_DIST := 340.0
const MOVE_REEL_PENALTY := 0.5

var state: State = State.IDLE
var aim_dir: Vector2 = Vector2.DOWN
var charge_time: float = 0.0
var cast_target: Vector2 = Vector2.ZERO
var current_tier: String = "near"
var tier_data: Dictionary = {}
var wait_timer: float = 0.0
var bite_timer: float = 0.0
var progress: float = 0.0
var tension: float = 0.0
var in_altar_zone: bool = false
var current_noise_radius: float = 0.0

var _prev_action_held: bool = false

@onready var facing_indicator: ColorRect = $FacingIndicator
@onready var _move_joystick: VirtualJoystick = get_tree().current_scene.get_node("HUD/Panel/MoveJoystick")
@onready var _aim_joystick: VirtualJoystick = get_tree().current_scene.get_node("HUD/Panel/AimJoystick")


func _ready() -> void:
	_set_state(State.IDLE)


func set_in_altar(value: bool) -> void:
	in_altar_zone = value
	if value and state != State.IDLE:
		_cancel_cast("altar_interrupt")


func _physics_process(delta: float) -> void:
	_update_aim()
	_update_movement()
	_update_noise()
	_update_fishing(delta)
	_handle_action_input(delta)


func _update_aim() -> void:
	if state == State.REELING:
		# Design doc §4.4: while reeling, facing/light lock onto the fish
		# instead of free aim, so the player isn't fighting two things.
		var to_fish := cast_target - global_position
		if to_fish.length() > 1.0:
			aim_dir = to_fish.normalized()
	elif _aim_joystick.is_pressed:
		aim_dir = _aim_joystick.output.normalized()
	else:
		# Mouse aim is a desktop-testing fallback for when there's no
		# touchscreen to drag the right stick with.
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			aim_dir = to_mouse.normalized()
	facing_indicator.position = aim_dir * 18.0 - Vector2(3.0, 3.0)


func _update_movement() -> void:
	var input_dir := _move_joystick.output
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	elif input_dir.length() < 0.05:
		# Keyboard is a desktop-testing fallback for the left stick.
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.y += 1.0
		input_dir = input_dir.normalized()

	velocity = input_dir * SPEED
	move_and_slide()
	position.x = clamp(position.x, 16.0, 944.0)
	position.y = clamp(position.y, 16.0, 524.0)


func _update_noise() -> void:
	# Design doc §3.1: casting/reeling/running are heard, not just seen.
	var noise := 0.0
	if velocity.length() > 1.0:
		noise = max(noise, 90.0)
	if state == State.REELING:
		noise = max(noise, 110.0)
	elif state == State.WAITING or state == State.BITE:
		noise = max(noise, 40.0)
	current_noise_radius = noise


func _is_action_pressed() -> bool:
	# Mouse-left now drags the aim joystick on desktop, so the action button
	# is keyboard-only here; on mobile this will be a dedicated screen button.
	return Input.is_key_pressed(KEY_SPACE)


func _handle_action_input(delta: float) -> void:
	var held := _is_action_pressed()
	var just_pressed := held and not _prev_action_held
	var just_released := (not held) and _prev_action_held

	if in_altar_zone:
		if just_pressed:
			var count := GameState.sacrifice_all()
			if count > 0:
				GameState.push_message("獻祭了 %d 條魚" % count)
			else:
				GameState.push_message("身上沒有可獻祭的漁獲")
		_prev_action_held = held
		return

	match state:
		State.IDLE:
			if just_pressed:
				_set_state(State.CHARGING)
				charge_time = 0.0
		State.CHARGING:
			if held:
				charge_time = min(charge_time + delta, MAX_CHARGE_TIME)
			elif just_released:
				_launch_cast()
		State.BITE:
			if just_pressed:
				_hook_fish()
		State.WAITING, State.REELING:
			pass

	_prev_action_held = held


func _update_fishing(delta: float) -> void:
	match state:
		State.WAITING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				_start_bite()
		State.BITE:
			bite_timer -= delta
			if bite_timer <= 0.0:
				_fail_catch("missed_bite")
		State.REELING:
			var held := _is_action_pressed()
			var moving := velocity.length() > 1.0
			var rate_mult := MOVE_REEL_PENALTY if moving else 1.0
			if held:
				progress += tier_data.reel_speed * rate_mult * delta
				tension += tier_data.tension_rise * delta
			else:
				tension -= tier_data.tension_fall * delta
			tension = clamp(tension, 0.0, 1.0)
			progress = clamp(progress, 0.0, 1.0)
			reel_progress.emit(progress, tension)
			if tension >= 1.0:
				_fail_catch("line_break")
			elif progress >= 1.0:
				_succeed_catch()
		_:
			pass


func _launch_cast() -> void:
	var ratio: float = charge_time / MAX_CHARGE_TIME
	var dist: float = lerp(MIN_CAST_DIST, MAX_CAST_DIST, ratio)
	cast_target = global_position + aim_dir * dist
	current_tier = FishData.tier_for_ratio(ratio)
	tier_data = FishData.get_tier_data(current_tier)
	wait_timer = randf_range(tier_data.wait_min, tier_data.wait_max)
	_set_state(State.WAITING)
	cast_started.emit(cast_target, current_tier)


func _start_bite() -> void:
	bite_timer = tier_data.bite_window
	_set_state(State.BITE)
	bite_started.emit()


func _hook_fish() -> void:
	progress = 0.0
	tension = 0.15
	_set_state(State.REELING)
	hook_success.emit()


func _succeed_catch() -> void:
	var fish := {"name": tier_data.label, "value": tier_data.value, "tier": current_tier}
	catch_success.emit(fish)
	GameState.add_carried_fish(fish)
	GameState.push_message("釣到了 %s！" % tier_data.label)
	_reset_line(State.IDLE)


func _fail_catch(reason: String) -> void:
	catch_failed.emit(reason)
	var msg := "魚跑掉了" if reason == "missed_bite" else "線斷了，魚跑了"
	GameState.push_message(msg)
	_reset_line(State.IDLE)


func _cancel_cast(reason: String) -> void:
	catch_failed.emit(reason)
	_reset_line(State.IDLE)


func _reset_line(next_state: State) -> void:
	line_cleared.emit()
	_set_state(next_state)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(State.keys()[state])
