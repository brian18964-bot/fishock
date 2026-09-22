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
signal sacrifice_progress_updated(progress: float)
signal rummage_progress_updated(progress: float)

enum State { IDLE, CHARGING, WAITING, BITE, REELING }
enum FishingMode { BOBBER, LURE }

const SPEED := 140.0
const MAX_CHARGE_TIME := 1.2
const MIN_CAST_DIST := 40.0
const MAX_CAST_DIST := 340.0
const MOVE_REEL_PENALTY := 0.5
const WORLD_WIDTH := 2400.0
const WORLD_HEIGHT := 1350.0
const START_BAIT := 20
const START_LURES := 5

## Design doc request: carrying more fish weighs the player down; each
## fish drops speed a bit further, floored so it's slow, never frozen.
const WEIGHT_SPEED_PENALTY := 0.05
const MIN_SPEED_RATIO := 0.4
const RUMMAGE_DURATION := 0.9

const DROPPED_FISH_SCENE := preload("res://scenes/dropped_fish.tscn")

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
var in_escape_zone: bool = false
var in_fuel_zone: bool = false
var in_oil_drum_zone: bool = false
var in_dropped_fish_zone: bool = false
var in_roadside_zone: bool = false
var current_noise_radius: float = 0.0
var cast_jittered: bool = false

const SACRIFICE_DURATION := 0.6
var sacrifice_progress: float = 0.0
var rummage_progress: float = 0.0

var _fuel_station: FuelStation
var _oil_drum: OilDrum
var _dropped_fish: DroppedFish
var _roadside_item: RoadsideItem
var _wait_duration: float = 1.0

## Design doc §4.2/§9.2: bobber is quiet, free, consumable bait; lure is a
## noisier, hands-busy active jig using durable gear you can't restock
## mid-run and can lose to interference.
var fishing_mode: FishingMode = FishingMode.BOBBER
var bait_count: int = START_BAIT
var lure_count: int = START_LURES

## Design doc §5.2/§5.3: rolled at cast time, revealed at bite time.
const NORMAL_RARE_CHANCE := 0.03
const FAR_RARE_CHANCE := 0.06
const HOTSPOT_RARE_CHANCE := 0.35
const HOTSPOT_HEART_CHANCE_DAY := 0.08
const HOTSPOT_HEART_CHANCE_NIGHT := 0.16
const RARE_PULL_INTERVAL := 2.0

var is_rare_catch: bool = false
var is_heart_catch: bool = false
var caught_in_hotspot: bool = false
var rare_pull_dir: Vector2 = Vector2.ZERO
var rare_pull_timer: float = 0.0

var _prev_action_held: bool = false
var _prev_mode_toggle_held: bool = false
var _key_prev_held: Dictionary = {}

@onready var facing_indicator: ColorRect = $FacingIndicator
@onready var _move_joystick: TouchJoystick = get_tree().current_scene.get_node("HUD/Panel/MoveJoystick")
@onready var _aim_joystick: TouchJoystick = get_tree().current_scene.get_node("HUD/Panel/AimJoystick")
@onready var _hotspot: Hotspot = get_tree().current_scene.get_node("Hotspot")


func _ready() -> void:
	reset_gear()
	_set_state(State.IDLE)


func set_in_altar(value: bool) -> void:
	in_altar_zone = value
	if value and state != State.IDLE:
		_cancel_cast("altar_interrupt")


func set_in_escape(value: bool) -> void:
	in_escape_zone = value
	if value and state != State.IDLE:
		_cancel_cast("escape_interrupt")


func set_in_fuel_station(value: bool, station: FuelStation) -> void:
	in_fuel_zone = value
	_fuel_station = station if value else null
	if value and state != State.IDLE:
		_cancel_cast("fuel_interrupt")


func set_in_oil_drum(value: bool, drum: OilDrum) -> void:
	in_oil_drum_zone = value
	_oil_drum = drum if value else null


func set_in_dropped_fish(value: bool, fish_node: DroppedFish) -> void:
	in_dropped_fish_zone = value
	_dropped_fish = fish_node if value else null
	if value and state != State.IDLE:
		_cancel_cast("dropped_fish_interrupt")


func set_in_roadside(value: bool, item: RoadsideItem) -> void:
	in_roadside_zone = value
	_roadside_item = item if value else null
	if value and state != State.IDLE:
		_cancel_cast("roadside_interrupt")


## Design doc request: heavier weight from carried fish, dropping some
## fish lightens the load - see _update_movement() for where this applies.
static func carry_speed_ratio(carried_count: int) -> float:
	var ratio: float = clamp(1.0 - carried_count * WEIGHT_SPEED_PENALTY, MIN_SPEED_RATIO, 1.0)
	return ratio


## Design doc §3.3: a ghost lurking near a charging player scrambles the
## cast, so the eventual distance stops tracking hold time reliably.
func apply_cast_jitter() -> void:
	if state == State.CHARGING:
		cast_jittered = true


func has_line_out() -> bool:
	return state == State.WAITING or state == State.BITE or state == State.REELING


## Design doc request: lure fishing should visibly retrieve toward the
## player as it's reeled in, with the bite happening mid-retrieve, rather
## than just sitting at the cast point. Bobber stays put (still water).
func get_line_target_position() -> Vector2:
	if state == State.WAITING and fishing_mode == FishingMode.LURE and _wait_duration > 0.0:
		var retrieved: float = clamp(1.0 - (wait_timer / _wait_duration), 0.0, 1.0)
		return cast_target.lerp(global_position, retrieved)
	return cast_target


## Design doc §3.3: cutting the line always fails the catch; when it's a
## lure, the gear itself also gets knocked off and lost for good.
func cut_line() -> void:
	if not has_line_out():
		return
	if fishing_mode == FishingMode.LURE:
		_lose_lure()
		_fail_catch("lure_knocked")
	else:
		_fail_catch("line_cut")


## Design doc §3.3: bobber-only - the ghost reaching the resting bobber
## spoils that cast (bait already spent stays spent, nothing extra lost).
func spoil_bait() -> void:
	if state == State.WAITING and fishing_mode == FishingMode.BOBBER:
		_fail_catch("bait_stolen")


## Design doc §9.1/§9.2: starting bait scales with the bait_capacity
## upgrade; lures come from whatever the player bought into their loadout
## before this run started (consumed here, not reusable across runs).
func reset_gear() -> void:
	bait_count = START_BAIT + int(Profile.get_upgrade_bonus("bait_capacity"))
	lure_count = Profile.consume_loadout_lures()
	fishing_mode = FishingMode.BOBBER


func _can_start_cast() -> bool:
	if fishing_mode == FishingMode.BOBBER:
		return bait_count > 0
	return lure_count > 0


func _lose_lure() -> void:
	lure_count = max(lure_count - 1, 0)
	if lure_count <= 0:
		fishing_mode = FishingMode.BOBBER
		GameState.push_message("假餌都用完了，只能用浮標了")


func _handle_mode_toggle() -> void:
	if state != State.IDLE:
		return
	var held := Input.is_key_pressed(KEY_TAB)
	var just_pressed := held and not _prev_mode_toggle_held
	_prev_mode_toggle_held = held
	if not just_pressed:
		return

	if fishing_mode == FishingMode.BOBBER:
		if lure_count <= 0:
			GameState.push_message("沒有假餌了，只能用浮標")
			return
		fishing_mode = FishingMode.LURE
		GameState.push_message("切換成路亞")
	else:
		fishing_mode = FishingMode.BOBBER
		GameState.push_message("切換成浮標")


## Legacy debug-key path to the same purchases the title screen's shop UI
## now offers - kept working since it's harmless (nothing here takes
## effect until the next reset_gear()), just no longer the primary way in.
func _handle_shop_input() -> void:
	if _key_just_pressed(KEY_B):
		if Profile.buy_lure():
			GameState.push_message("買了一個假餌（下輪庫存 %d），這輪不會生效" % Profile.loadout_lures)
		else:
			GameState.push_message("金幣不夠，買不起假餌（需要 %d）" % Profile.LURE_COST)
	if _key_just_pressed(KEY_1):
		_try_buy_upgrade("fuel_capacity")
	if _key_just_pressed(KEY_2):
		_try_buy_upgrade("bait_capacity")
	if _key_just_pressed(KEY_3):
		_try_buy_upgrade("flash_cooldown")


## Design doc request: dropping carried fish lightens the load (see
## carry_speed_ratio()) and leaves a pickup-able, decaying pile behind -
## for someone else, or for yourself once a ghost stops watching this spot.
func _handle_drop_input() -> void:
	if not _key_just_pressed(KEY_G):
		return
	var fish: Dictionary = GameState.drop_one_carried()
	if fish.is_empty():
		GameState.push_message("身上沒有漁獲可以丟")
		return
	var dropped: DroppedFish = DROPPED_FISH_SCENE.instantiate()
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = global_position
	dropped.setup(fish)
	GameState.push_message("丟掉了一條 %s，跑得更快了" % fish.get("name", "魚"))


func _key_just_pressed(key: int) -> bool:
	var held := Input.is_key_pressed(key)
	var was_held: bool = _key_prev_held.get(key, false)
	_key_prev_held[key] = held
	return held and not was_held


func _try_buy_upgrade(upgrade_key: String) -> void:
	var def: Dictionary = Profile.UPGRADE_DEFS[upgrade_key]
	if Profile.buy_upgrade(upgrade_key):
		GameState.push_message("升級了%s！（Lv.%d）" % [def.label, Profile.get_upgrade_level(upgrade_key)])
	else:
		GameState.push_message("升不了級（金幣不夠或已滿級）")


func _physics_process(delta: float) -> void:
	_update_aim()
	_update_movement()
	_update_noise()
	_update_fishing(delta)
	_handle_mode_toggle()
	_handle_shop_input()
	_handle_drop_input()
	_handle_action_input(delta)


func _update_aim() -> void:
	if state == State.REELING:
		# Design doc §4.4: while reeling, facing/light lock onto the fish
		# instead of free aim, so the player isn't fighting two things.
		var to_fish := cast_target - global_position
		if to_fish.length() > 1.0:
			aim_dir = to_fish.normalized()
	elif fishing_mode == FishingMode.LURE and state == State.WAITING and _is_action_pressed():
		# Design doc §4.2 "視野弱點": hands are busy jigging the lure, so
		# aim just holds still instead of tracking mouse/stick input.
		pass
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

	var carry_ratio: float = carry_speed_ratio(GameState.carried_fish.size())
	velocity = input_dir * SPEED * carry_ratio
	move_and_slide()
	position.x = clamp(position.x, 16.0, WORLD_WIDTH - 16.0)
	position.y = clamp(position.y, 16.0, WORLD_HEIGHT - 16.0)


func _update_noise() -> void:
	# Design doc §3.1: casting/reeling/running are heard, not just seen.
	# §4.2: lure is "捲線聲持續" (constant reel sound) while bobber is quiet.
	var noise := 0.0
	if velocity.length() > 1.0:
		noise = max(noise, 90.0)
	if state == State.REELING:
		noise = max(noise, 110.0)
	elif state == State.WAITING:
		if fishing_mode == FishingMode.LURE and _is_action_pressed():
			noise = max(noise, 110.0)
		else:
			noise = max(noise, 40.0)
	elif state == State.BITE:
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
		_handle_sacrifice(held, delta)
		_prev_action_held = held
		return

	if in_escape_zone:
		if just_pressed and GameState.day_phase == GameState.DayPhase.ESCAPE:
			GameState.escape()
		_prev_action_held = held
		return

	if in_fuel_zone:
		if just_pressed and _fuel_station != null:
			var lantern: Lantern = get_node("Lantern")
			if _fuel_station.try_refuel(lantern):
				GameState.push_message("煤油加滿了！（煤油站剩 %d/%d 次）" % [_fuel_station.charges_remaining, _fuel_station.max_charges])
			elif _fuel_station.charges_remaining <= 0:
				GameState.push_message("煤油站次數用完了")
			else:
				GameState.push_message("燃油已經是滿的")
		_prev_action_held = held
		return

	if in_oil_drum_zone:
		if just_pressed and _oil_drum != null:
			_oil_drum.use()
		_prev_action_held = held
		return

	if in_dropped_fish_zone:
		if just_pressed and _dropped_fish != null:
			_pick_up_dropped_fish()
		_prev_action_held = held
		return

	if in_roadside_zone:
		_handle_rummage(held, delta)
		_prev_action_held = held
		return

	match state:
		State.IDLE:
			if just_pressed:
				if _can_start_cast():
					_set_state(State.CHARGING)
					charge_time = 0.0
				else:
					var out_of := "餌" if fishing_mode == FishingMode.BOBBER else "假餌"
					GameState.push_message("沒有%s了，按 Tab 換釣法" % out_of)
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


## Design doc request: sacrificing is no longer instant-bulk - each fish
## takes a short held progress bar, one at a time.
func _handle_sacrifice(held: bool, delta: float) -> void:
	if held and not GameState.carried_fish.is_empty():
		sacrifice_progress += delta / SACRIFICE_DURATION
		if sacrifice_progress >= 1.0:
			sacrifice_progress = 0.0
			var fish: Dictionary = GameState.sacrifice_one()
			if not fish.is_empty():
				GameState.push_message("獻祭了一條 %s" % fish.get("name", "魚"))
	else:
		sacrifice_progress = 0.0
	sacrifice_progress_updated.emit(sacrifice_progress)


func _pick_up_dropped_fish() -> void:
	var fish: Dictionary = _dropped_fish.pick_up()
	_dropped_fish = null
	in_dropped_fish_zone = false
	GameState.add_carried_fish(fish)
	if fish.get("rotten", false):
		GameState.push_message("撿回了一份腐敗的%s（獻祭它可能引發異變）" % fish.get("name", "魚獲"))
	else:
		GameState.push_message("撿回了%s（新鮮度打折，價值 %.0f）" % [fish.get("name", "魚"), fish.value])


## Design doc request: rummaging a roadside pile takes a short held
## progress bar and only sometimes turns up bait.
func _handle_rummage(held: bool, delta: float) -> void:
	if held and _roadside_item != null and _roadside_item.active:
		rummage_progress += delta / RUMMAGE_DURATION
		if rummage_progress >= 1.0:
			rummage_progress = 0.0
			var result: Dictionary = _roadside_item.resolve()
			if result.get("found", false):
				bait_count += 1
				GameState.push_message("翻到了%s，補充了一份餌料！" % result.get("flavor", "餌料"))
			else:
				GameState.push_message("翻了半天，什麼都沒找到")
	else:
		rummage_progress = 0.0
	rummage_progress_updated.emit(rummage_progress)


func _update_fishing(delta: float) -> void:
	match state:
		State.WAITING:
			# Design doc §4.2: bobber waits passively; lure only progresses
			# toward a bite while actively jigged ("持續收線動作").
			if fishing_mode == FishingMode.BOBBER or _is_action_pressed():
				wait_timer -= delta
			if wait_timer <= 0.0:
				_start_bite()
		State.BITE:
			bite_timer -= delta
			if bite_timer <= 0.0:
				_fail_catch("missed_bite")
		State.REELING:
			var held := _is_action_pressed()
			var rate_mult := 1.0
			if is_rare_catch:
				rate_mult = _update_rare_pull(delta)
			else:
				var moving := velocity.length() > 1.0
				rate_mult = MOVE_REEL_PENALTY if moving else 1.0
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
	if fishing_mode == FishingMode.BOBBER:
		bait_count = max(bait_count - 1, 0)

	var ratio: float = charge_time / MAX_CHARGE_TIME
	if cast_jittered:
		ratio = clamp(ratio * randf_range(0.3, 1.4), 0.0, 1.0)
		cast_jittered = false
		GameState.push_message("蓄力被干擾了，拋竿距離變得不可靠")
	var dist: float = lerp(MIN_CAST_DIST, MAX_CAST_DIST, ratio)
	cast_target = global_position + aim_dir * dist
	current_tier = FishData.tier_for_ratio(ratio)
	tier_data = FishData.get_tier_data(current_tier)
	wait_timer = randf_range(tier_data.wait_min, tier_data.wait_max)
	_wait_duration = wait_timer
	_roll_catch_outcome()
	_set_state(State.WAITING)
	cast_started.emit(cast_target, current_tier)


## Design doc §5.2/§5.3: decides now (revealed only at bite time) whether
## this cast lands a rare fish or, hotspot-only, a heart. Hotspots also
## boost rare odds far above open water's "surprise" chance.
func _roll_catch_outcome() -> void:
	is_rare_catch = false
	is_heart_catch = false
	caught_in_hotspot = _hotspot.active and cast_target.distance_to(_hotspot.global_position) <= Hotspot.RADIUS

	if caught_in_hotspot:
		var heart_chance := HOTSPOT_HEART_CHANCE_NIGHT if GameState.is_night else HOTSPOT_HEART_CHANCE_DAY
		if randf() < heart_chance:
			is_heart_catch = true
		elif randf() < HOTSPOT_RARE_CHANCE:
			is_rare_catch = true
	else:
		var rare_chance := FAR_RARE_CHANCE if current_tier == "far" else NORMAL_RARE_CHANCE
		if randf() < rare_chance:
			is_rare_catch = true

	if is_rare_catch:
		tier_data = tier_data.duplicate()
		tier_data.label = "稀有" + tier_data.label
		tier_data.value = tier_data.value * 3.0
		tier_data.reel_speed = tier_data.reel_speed * 0.6
		tier_data.tension_rise = tier_data.tension_rise * 1.15
		tier_data.bite_window = tier_data.bite_window * 1.2


func _start_bite() -> void:
	bite_timer = tier_data.bite_window
	_set_state(State.BITE)
	bite_started.emit()
	if is_heart_catch:
		GameState.push_message("水花特別亮、震動特別強...是心臟！")
	elif is_rare_catch:
		GameState.push_message("水花聲跟震動都變強了，是稀有魚！")


func _hook_fish() -> void:
	progress = 0.0
	tension = 0.15
	if is_rare_catch:
		rare_pull_dir = Vector2.RIGHT.rotated(randf() * TAU)
		rare_pull_timer = RARE_PULL_INTERVAL
		GameState.push_message("稀有魚用力往%s拉，往反方向走可以拉近距離！" % _describe_pull(rare_pull_dir))
	_set_state(State.REELING)
	hook_success.emit()


## Design doc §4.4: rare-fish direction resistance. Moving opposite the
## fish's current pull speeds progress up (to 1.2x); moving with it drags
## it down (to 0.2x); standing still is a middling 0.7x either way.
func _update_rare_pull(delta: float) -> float:
	rare_pull_timer -= delta
	if rare_pull_timer <= 0.0:
		rare_pull_dir = Vector2.RIGHT.rotated(randf() * TAU)
		rare_pull_timer = RARE_PULL_INTERVAL
		GameState.push_message("稀有魚換方向了，往%s拉！" % _describe_pull(rare_pull_dir))

	var alignment := 0.0
	if velocity.length() > 1.0:
		alignment = velocity.normalized().dot(-rare_pull_dir)
	var clamped: float = clamp(alignment, -1.0, 1.0)
	return 0.7 + clamped * 0.5


func _describe_pull(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "右" if dir.x > 0.0 else "左"
	return "下" if dir.y > 0.0 else "上"


func _succeed_catch() -> void:
	if caught_in_hotspot:
		_hotspot.consume()

	if is_heart_catch:
		GameState.grant_heart()
		catch_success.emit({"name": "心臟", "value": 0, "tier": current_tier})
	else:
		var fish := {"name": tier_data.label, "value": tier_data.value, "tier": current_tier}
		catch_success.emit(fish)
		GameState.add_carried_fish(fish)
		GameState.push_message("釣到了 %s！" % tier_data.label)

	_reset_line(State.IDLE)


func _fail_catch(reason: String) -> void:
	catch_failed.emit(reason)
	var msg := "魚跑掉了"
	if reason == "line_break":
		msg = "線斷了，魚跑了"
	elif reason == "line_cut":
		msg = "線被鬼剪斷了！"
	elif reason == "lure_knocked":
		msg = "假餌被鬼弄掉了！"
	elif reason == "bait_stolen":
		msg = "餌被鬼偷走了！"
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
