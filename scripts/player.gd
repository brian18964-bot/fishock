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
## A test nibble on the bait before the real bite (fake: a full-looking dunk
## meant to bait an early strike) - see the fishing difficulty plan.
signal nibble(fake: bool)
## Something happened in the fight (FishFight event: run, side_run, jump,
## dive, dive_saved, enrage).
signal fight_event(kind: String)

enum State { IDLE, CHARGING, WAITING, BITE, REELING }
enum FishingMode { BOBBER, LURE }

## User feedback: 20% slower (was 140).
const SPEED := 112.0
## User request: no wading at all any more - the player's feet stay on dry
## land, except out along docks, stairs and boardwalks (Dock walkways).
## Rare zones stay fully solid.
const FEET := Vector2(0, 8)
## User feedback: charging was too quick - 30% slower (was 1.2 s), then
## another 50% slower.
const MAX_CHARGE_TIME := 2.34
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

## Design doc request: reeling a lure in is player-paced, not an automatic
## countdown - holding retrieves steadily, each tap also nudges it a bit
## for fine, "點收" control when you want to go slower.
const LURE_HOLD_RATE := 0.55
const LURE_CLICK_AMOUNT := 0.12

## Design doc request: common water is easy to reach and cast into but
## pays worse; rare water pays much better for the precision (and risk -
## it's solid ground you can't stand on, see water_zone.gd) it takes to
## land a cast on it at all.
const COMMON_ZONE_VALUE_MULT := 0.7
const RARE_ZONE_VALUE_MULT := 2.2
const RARE_ZONE_RARE_CHANCE_BONUS := 0.25

## Design doc request: any cast can call up a "water ghost" that jumps a
## player standing too close to the water's edge - lost gear, a stolen
## fish, and a lingering status effect. Casting far from where you're
## standing doesn't save you; standing far from any water does.
const WATER_GHOST_CHANCE := 0.16
const WATER_GHOST_RANGE := 130.0
const WATER_GHOST_DEBUFF_DURATION := 4.0
## User decision: out on a dock (walkway over the water) the ghost has a
## harder time reaching you.
const DOCK_WATER_GHOST_MULT := 0.35
const ANIMAL_ATTACK_DEBUFF_DURATION := 2.5
const WATER_GHOST_SPEED_MULT := 0.55

## User feedback: carrying the oil drum should slow you down, not just
## block fishing.
const OIL_DRUM_SPEED_MULT := 0.65

## User feedback: a cast shouldn't guarantee a bite - most of the time
## something takes it, but sometimes nothing's interested (a bobber just
## sits there) or, bobber-only, a fish nibbles the bait clean off early
## without ever giving a real bite to hook.
enum CastOutcome { BITE, TIMEOUT, BAIT_STOLEN }
const NO_BITE_CHANCE := 0.22
const HOTSPOT_NO_BITE_MULT := 0.4

## User decision (fishing difficulty plan): each species fights at a
## difficulty (FishData.DIFFICULTY) - test nibbles before the real bite,
## the strike window, and the whole fight (FishFight: stamina, runs
## straight or sideways, leaps, dashes for cover, berserk masters).
## Seconds between nibbles:
const NIBBLE_GAP := Vector2(0.55, 1.2)

## User feedback: rarity should go a step further than common/rare - a
## small chance for a rare catch to be upgraded to a legendary "epic" fish
## (see FishData.SPECIES' "epic" pools), worth much more and fights harder
## still on top of the normal rare-catch difficulty bump.
const EPIC_CHANCE_OF_RARE := 0.18

## User feedback: bait flavor from roadside rummaging should actually do
## something, not just be a message string - each type biases the very
## next cast one way, then gets used up regardless of what happens.
const BAIT_FLAVOR_WORM := "蚯蚓"
const BAIT_FLAVOR_BUG := "蟲子"
const BAIT_FLAVOR_FROG := "青蛙"
## User request: critters (see Critter) can be caught as bait. Rats and
## snakes are "big bait": a rare catch is twice as likely to turn epic.
const BIG_BAIT_FLAVORS := ["老鼠", "蛇"]

## User feedback: weather (see GameState.Weather) should color the fishing
## odds too - a fish run is a reliably better window, a storm makes the
## water ghost more likely to actually catch someone standing too close.
const FISH_RUN_WEATHER_NO_BITE_MULT := 0.5
const FISH_RUN_WEATHER_RARE_BONUS := 0.08
const STORM_WATER_GHOST_MULT := 1.6

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
var in_critter_zone: bool = false
var current_noise_radius: float = 0.0
var cast_jittered: bool = false
var retrieve_progress: float = 0.0
var cast_water_zone: WaterZone
var water_ghost_timer: float = 0.0
## What the HUD warning names while water_ghost_timer runs - the water
## ghost, or an animal that caught up with you (see animal_attack()).
var affliction_text: String = "水鬼異常狀態中"
## Set by TouchControls while the cast button is dragged; wins over the aim
## stick. Zero when not in use.
var touch_aim := Vector2.ZERO
var cast_outcome: int = CastOutcome.BITE
var stolen_timer: float = 0.0
## While a run is on (seconds left) - the rod and camera shake with it.
var fish_run_active_time: float = 0.0
var fight: FishFight
var difficulty_key := "novice"
var fish_habit := ""
var nibbles_left := 0
## Chance each test nibble is a fake dunk (the difficulty's, times the lure's).
var fake_chance := 0.0
var _nibbled := false
var _lure_nibbles: Array = []
var pending_bait_flavor: String = ""
var is_epic_catch: bool = false
var fish_trait: String = "normal"
var current_fish_color: Color = Color(1, 0.85, 0.2)

## Design doc §9.1/§9.2: base cast distance / reel speed plus the
## rod_distance / reel_power Profile upgrades, recomputed in reset_gear()
## since upgrades only change between runs.
var max_cast_dist: float = MAX_CAST_DIST
var reel_power_mult: float = 1.0

const SACRIFICE_DURATION := 0.6
var sacrifice_progress: float = 0.0
var rummage_progress: float = 0.0

## Design doc request: the oil drum is carried back to a fuel station by
## hand instead of refilling the whole map on the spot - see
## _handle_action_input()'s oil-drum/fuel-station branches.
var carrying_oil_drum: bool = false

var _fuel_station: FuelStation
var _oil_drum: OilDrum
var _carried_oil_drum: OilDrum
var _dropped_fish: DroppedFish
var _roadside_item: RoadsideItem
var _critter: Critter
var _critter_hint_shown: bool = false
var _wait_duration: float = 1.0

## Design doc §4.2/§9.2: bobber is quiet, free, consumable bait; lure is a
## noisier, hands-busy active jig using durable gear you can't restock
## mid-run and can lose to interference.
var fishing_mode: FishingMode = FishingMode.BOBBER
var bait_count: int = START_BAIT
var lure_count: int = START_LURES
## User request (shop linkage): lure id (Profile.LURES) -> how many this run
## carries, and which one is on the line in lure mode.
var lure_stock: Dictionary = {}
var current_lure: String = ""

## Design doc §5.2/§5.3: rolled at cast time, revealed at bite time.
const NORMAL_RARE_CHANCE := 0.03
const FAR_RARE_CHANCE := 0.06
const HOTSPOT_RARE_CHANCE := 0.35
const HOTSPOT_HEART_CHANCE_DAY := 0.08
const HOTSPOT_HEART_CHANCE_NIGHT := 0.16
var is_rare_catch: bool = false
var is_heart_catch: bool = false
var caught_in_hotspot: bool = false

var _prev_action_held: bool = false
var _prev_mode_toggle_held: bool = false
var _key_prev_held: Dictionary = {}

@onready var facing_indicator: ColorRect = $FacingIndicator
@onready var _move_joystick: TouchJoystick = get_tree().current_scene.get_node("HUD/Panel/MoveJoystick")
@onready var _aim_joystick: TouchJoystick = get_tree().current_scene.get_node("HUD/Panel/AimJoystick")
@onready var _hotspot: Hotspot = get_tree().current_scene.get_node("Hotspot")


func _ready() -> void:
	add_to_group("player")
	# The gas can in hand while it's being carried (see OilDrum).
	var can := Sprite2D.new()
	can.name = "CarriedCan"
	var tex := CanvasTexture.new()
	tex.diffuse_texture = preload("res://assets/sprites/gas_can/gas_can_55deg_albedo.png")
	tex.normal_texture = preload("res://assets/sprites/gas_can/gas_can_55deg_normal.png")
	can.texture = tex
	Art.place(can, Vector2(0, -5.56), 0.5)
	can.position = Vector2(9, 4)
	can.visible = false
	add_child(can)
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


func set_in_critter(value: bool, critter: Critter) -> void:
	if value:
		in_critter_zone = true
		_critter = critter
		if not _critter_hint_shown:
			_critter_hint_shown = true
			GameState.push_message("按空白鍵可以抓%s當餌料" % critter.get_label())
	elif critter == _critter:
		in_critter_zone = false
		_critter = null


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
## Once hooked, _start_bite() freezes cast_target at this same point, so
## the fight starts where the bite happened, not back at the original cast.
func get_line_target_position() -> Vector2:
	if state == State.WAITING and fishing_mode == FishingMode.LURE:
		return cast_target.lerp(global_position, clamp(retrieve_progress, 0.0, 1.0))
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
	lure_stock = Profile.consume_loadout_lures()
	_sync_lures()
	fishing_mode = FishingMode.BOBBER
	max_cast_dist = MAX_CAST_DIST + Profile.get_upgrade_bonus("rod_distance")
	reel_power_mult = 1.0 + Profile.get_upgrade_bonus("reel_power")
	_force_drop_oil_drum()


## Debug-reset safety net (main.gd's Shift+R restarts the run in place,
## without reloading the scene): without this, an oil drum picked up right
## before the reset would stay permanently "carried" by a player who no
## longer has any way to deliver it, vanishing from the map for the rest
## of the session. Deliver()-ing it sends it back through the normal
## relocate-after-a-delay flow instead of leaving it stuck.
func _force_drop_oil_drum() -> void:
	if carrying_oil_drum and _carried_oil_drum != null:
		_carried_oil_drum.deliver()
	_carried_oil_drum = null
	carrying_oil_drum = false


func _can_start_cast() -> bool:
	if fishing_mode == FishingMode.BOBBER:
		return bait_count > 0
	return lure_count > 0


func _lose_lure() -> void:
	if current_lure != "":
		lure_stock[current_lure] = maxi(int(lure_stock.get(current_lure, 0)) - 1, 0)
	_sync_lures()
	if lure_count <= 0:
		fishing_mode = FishingMode.BOBBER
		GameState.push_message("假餌都用完了，只能用浮標了")
	elif fishing_mode == FishingMode.LURE and int(lure_stock.get(current_lure, 0)) <= 0:
		current_lure = _next_lure("")
		GameState.push_message("這款假餌沒了，換上%s" % lure_label(current_lure))


## Recounts lure_count, and keeps current_lure on a lure that's in stock.
func _sync_lures() -> void:
	lure_count = 0
	for id in lure_stock:
		lure_count += int(lure_stock[id])
	if current_lure == "" or int(lure_stock.get(current_lure, 0)) <= 0:
		current_lure = _next_lure("")


## The next lure in shop order after `after` that's in stock ("" for the
## first; "" back if there's none after it).
func _next_lure(after: String) -> String:
	var start := Profile.LURE_ORDER.find(after) + 1
	for i in range(start, Profile.LURE_ORDER.size()):
		var id: String = Profile.LURE_ORDER[i]
		if int(lure_stock.get(id, 0)) > 0:
			return id
	return ""


## The lure on the line, as its shop entry ({} in bobber mode).
func lure_def() -> Dictionary:
	if fishing_mode != FishingMode.LURE or current_lure == "":
		return {}
	return Profile.LURES[current_lure]


func lure_label(id: String) -> String:
	return "%s（x%d）" % [Profile.LURES[id].name, int(lure_stock.get(id, 0))] if id != "" else ""


## Design doc request: fishing only works if the cast actually lands in
## water - rare zones checked first since a rare zone can sit close to a
## common one and should win the value/odds bonus.
func _find_water_zone(point: Vector2) -> WaterZone:
	for zone in get_tree().get_nodes_in_group("water_zones_rare"):
		if zone.contains(point):
			return zone
	for zone in get_tree().get_nodes_in_group("water_zones_common"):
		if zone.contains(point):
			return zone
	return null


func _nearest_water_edge_distance() -> float:
	var best := INF
	for zone in get_tree().get_nodes_in_group("water_zones"):
		var d: float = zone.distance_to_edge(global_position)
		best = min(best, d)
	return best


## Design doc request: discourage cheesing quick, close-range casts by
## rolling a water-ghost attack on every cast, regardless of its distance -
## it only actually lands if the PLAYER is standing close to the water,
## since standing back out of its reach is what keeps you safe, not how
## far you happened to cast.
func _maybe_trigger_water_ghost() -> void:
	var chance := WATER_GHOST_CHANCE
	if GameState.weather == GameState.Weather.STORM:
		chance *= STORM_WATER_GHOST_MULT
	if Dock.on_walkway(get_tree(), global_position + FEET) and _find_water_zone(global_position + FEET) != null:
		chance *= DOCK_WATER_GHOST_MULT
	if randf() >= chance:
		return
	if _nearest_water_edge_distance() > WATER_GHOST_RANGE:
		return
	_apply_water_ghost_attack()


func _apply_water_ghost_attack() -> void:
	water_ghost_timer = WATER_GHOST_DEBUFF_DURATION
	affliction_text = "水鬼異常狀態中"
	cast_jittered = true
	if fishing_mode == FishingMode.BOBBER:
		bait_count = max(bait_count - 1, 0)
	else:
		_lose_lure()
	var stolen: Dictionary = GameState.steal_one_carried()
	var msg := "水鬼從水裡冒出來偷襲！身上狀態異常中"
	if not stolen.is_empty():
		msg = "水鬼冒出來偷襲，還搶走了一條 %s！身上狀態異常中" % stolen.get("name", "魚")
	GameState.push_message(msg)


## User decision: wolves and the meat-eating dinosaurs chase the player
## (see Critter); one that catches up knocks a carried fish to the ground
## (it can be picked back up, like a G-dropped one), snaps the line if
## you're fishing, and leaves you slowed for a moment.
func animal_attack(attacker: String) -> void:
	water_ghost_timer = maxf(water_ghost_timer, ANIMAL_ATTACK_DEBUFF_DURATION)
	affliction_text = "被%s攻擊，行動變慢" % attacker
	if state != State.IDLE:
		_cancel_cast("animal_attack")
	var fish: Dictionary = GameState.drop_one_carried()
	if fish.is_empty():
		GameState.push_message("%s撲了上來！" % attacker)
		return
	var dropped: DroppedFish = DROPPED_FISH_SCENE.instantiate()
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * 40.0
	dropped.setup(fish)
	GameState.push_message("%s撲了上來，%s 掉在地上了！" % [attacker, fish.get("name", "魚")])


func _handle_mode_toggle() -> void:
	if state != State.IDLE:
		return
	var held := Input.is_key_pressed(KEY_TAB)
	var just_pressed := held and not _prev_mode_toggle_held
	_prev_mode_toggle_held = held
	if not just_pressed:
		return

	# Bobber -> each lure in stock, in shop order -> back to the bobber.
	var next := _next_lure("" if fishing_mode == FishingMode.BOBBER else current_lure)
	if next == "":
		if fishing_mode == FishingMode.BOBBER:
			GameState.push_message("沒有假餌了，只能用浮標（假餌在商店買）")
			return
		fishing_mode = FishingMode.BOBBER
		GameState.push_message("切換成浮標")
	else:
		fishing_mode = FishingMode.LURE
		current_lure = next
		GameState.push_message("切換成路亞：%s－%s" % [lure_label(next), Profile.LURES[next].desc])


## Legacy debug-key path to the same purchases the title screen's shop UI
## now offers - kept working since it's harmless (nothing here takes
## effect until the next reset_gear()), just no longer the primary way in.
func _handle_shop_input() -> void:
	if _key_just_pressed(KEY_B):
		if Profile.buy_lure("minnow"):
			GameState.push_message("買了一個假餌（下輪庫存 %d），這輪不會生效" % Profile.loadout_lure_total())
		else:
			GameState.push_message("金幣不夠，買不起假餌（需要 %d）" % Profile.LURES.minnow.cost)
	if _key_just_pressed(KEY_1):
		_try_buy_upgrade("fuel_capacity")
	if _key_just_pressed(KEY_2):
		_try_buy_upgrade("bait_capacity")
	if _key_just_pressed(KEY_3):
		_try_buy_upgrade("flash_cooldown")
	if _key_just_pressed(KEY_4):
		_try_buy_upgrade("rod_distance")
	if _key_just_pressed(KEY_5):
		_try_buy_upgrade("reel_power")


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
	water_ghost_timer = max(water_ghost_timer - delta, 0.0)
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
	elif touch_aim != Vector2.ZERO:
		# Dragging the cast button (see TouchControls) steers the cast.
		aim_dir = touch_aim
	elif _aim_joystick.is_pressed:
		aim_dir = _aim_joystick.output.normalized()
	elif not DisplayServer.is_touchscreen_available():
		# Mouse aim is a desktop-testing fallback for when there's no
		# touchscreen to drag the right stick with. (On a phone the emulated
		# mouse sits wherever the last touch was, so it'd yank the aim.)
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

	# Design doc request: a water ghost hit scrambles steering for a bit -
	# the input direction wobbles randomly instead of going where aimed.
	if water_ghost_timer > 0.0 and input_dir.length() > 0.05:
		input_dir = input_dir.rotated(randf_range(-1.2, 1.2))

	var carry_ratio: float = carry_speed_ratio(GameState.carried_fish.size())
	var affliction_ratio: float = WATER_GHOST_SPEED_MULT if water_ghost_timer > 0.0 else 1.0
	var drum_ratio: float = OIL_DRUM_SPEED_MULT if carrying_oil_drum else 1.0
	$CarriedCan.visible = carrying_oil_drum
	velocity = input_dir * SPEED * carry_ratio * affliction_ratio * drum_ratio
	var before := position
	move_and_slide()
	position.x = clamp(position.x, 16.0, WORLD_WIDTH - 16.0)
	position.y = clamp(position.y, 16.0, WORLD_HEIGHT - 16.0)
	# Keep out of deep water, sliding along the shallows' edge. (Only
	# blocks stepping deeper - never traps someone already out there.)
	if _too_deep(position) and not _too_deep(before):
		var moved := position - before
		position = before
		if not _too_deep(before + Vector2(moved.x, 0.0)):
			position = before + Vector2(moved.x, 0.0)
		elif not _too_deep(before + Vector2(0.0, moved.y)):
			position = before + Vector2(0.0, moved.y)


func _too_deep(pos: Vector2) -> bool:
	if Dock.on_walkway(get_tree(), pos + FEET):
		return false
	for zone in get_tree().get_nodes_in_group("water_zones_common"):
		if zone.contains(pos + FEET):
			return true
	return false


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
			if carrying_oil_drum:
				_deliver_oil_drum()
			else:
				var lantern: Lantern = get_node("Lantern")
				if _fuel_station.try_refuel(lantern):
					GameState.push_message("煤油加滿了！（煤油站剩 %d/%d）" % [int(_fuel_station.total_fuel), int(_fuel_station.max_total_fuel)])
				elif _fuel_station.total_fuel <= 0.0:
					GameState.push_message("煤油站的油用完了，帶油箱回來加吧")
				else:
					GameState.push_message("燃油已經是滿的")
		_prev_action_held = held
		return

	if in_oil_drum_zone:
		if just_pressed and _oil_drum != null and not carrying_oil_drum:
			_oil_drum.pick_up()
			_carried_oil_drum = _oil_drum
			carrying_oil_drum = true
			in_oil_drum_zone = false
			_oil_drum = null
			GameState.push_message("提起了油箱，送去煤油站吧（提著沒辦法釣魚）")
		_prev_action_held = held
		return

	if in_dropped_fish_zone:
		if just_pressed and _dropped_fish != null:
			_pick_up_dropped_fish()
		_prev_action_held = held
		return

	if in_critter_zone and _critter != null and _critter.active and state == State.IDLE:
		if just_pressed:
			_catch_critter()
		_prev_action_held = held
		return

	if in_roadside_zone:
		_handle_rummage(held, delta)
		_prev_action_held = held
		return

	match state:
		State.IDLE:
			if just_pressed:
				if carrying_oil_drum:
					GameState.push_message("提著油箱沒辦法釣魚，先送到煤油站")
				elif _can_start_cast():
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
		State.WAITING:
			# Design doc request: each tap nudges the retrieve forward a bit
			# on top of the steady per-delta rate in _update_fishing(), so
			# quick taps give slow, precise "點收" control.
			if fishing_mode == FishingMode.LURE and just_pressed:
				retrieve_progress = min(retrieve_progress + LURE_CLICK_AMOUNT, 1.0)
			elif fishing_mode == FishingMode.BOBBER and just_pressed and _nibbled:
				# Struck at a nibble (or a fake dunk): the fish is gone.
				_fail_catch("spooked")
		State.REELING:
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


func _catch_critter() -> void:
	var label: String = _critter.get_label()
	var flavor: String = _critter.catch()
	_critter = null
	in_critter_zone = false
	bait_count += 1
	pending_bait_flavor = flavor
	GameState.push_message("抓到了%s，當作一份餌料！（下一竿餌料：%s）" % [label, flavor])


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
				var flavor: String = result.get("flavor", "餌料")
				pending_bait_flavor = flavor
				GameState.push_message("翻到了%s，補充了一份餌料！（下一竿咬餌手感會不一樣）" % flavor)
			else:
				GameState.push_message("翻了半天，什麼都沒找到")
	else:
		rummage_progress = 0.0
	rummage_progress_updated.emit(rummage_progress)


func _deliver_oil_drum() -> void:
	var added: float = _fuel_station.add_fuel(OilDrum.FUEL_AMOUNT)
	if _carried_oil_drum != null:
		_carried_oil_drum.deliver()
	_carried_oil_drum = null
	carrying_oil_drum = false
	if added > 0.0:
		GameState.push_message("把油箱倒進煤油站了！補充了 %d 燃油" % int(added))
	else:
		GameState.push_message("煤油站已經是滿的，油箱白提了一趟")


func _update_fishing(delta: float) -> void:
	match state:
		State.WAITING:
			if fishing_mode == FishingMode.BOBBER:
				# Design doc §4.2: bobber waits passively for a bite.
				wait_timer -= delta
				# User feedback: a bobber cast isn't guaranteed to land a
				# bite - it can come up empty at the end of the wait, or
				# have its bait nibbled off early with no bite at all.
				if cast_outcome == CastOutcome.BAIT_STOLEN and wait_timer <= stolen_timer:
					_fail_catch("bait_nibbled")
				elif wait_timer <= 0.0:
					if cast_outcome == CastOutcome.TIMEOUT:
						_fail_catch("no_bite")
					elif nibbles_left > 0:
						# Test nibbles first - the float twitches (or, on
						# harder fish, dunks right under without the splash)
						# and striking now scares the fish off.
						nibbles_left -= 1
						_nibbled = true
						nibble.emit(randf() < fake_chance)
						wait_timer = randf_range(NIBBLE_GAP.x, NIBBLE_GAP.y)
					else:
						_start_bite()
			else:
				# Design doc request: lure retrieval speed is player-paced -
				# steady while held, plus click bumps from
				# _handle_action_input() - rather than an automatic timer.
				if _is_action_pressed():
					retrieve_progress += LURE_HOLD_RATE * delta / max(_wait_duration, 0.1)
				# Nibbles on a lure are just a tell (taps on the line).
				if not _lure_nibbles.is_empty() and retrieve_progress >= _lure_nibbles[0]:
					_lure_nibbles.pop_front()
					nibble.emit(false)
				# Design doc request: reeled out of a rare zone's boundary
				# counts as fully retrieved outright - you don't have to
				# drag it all the way back to shore.
				var exited_rare_zone := false
				if cast_water_zone != null and cast_water_zone.is_rare():
					exited_rare_zone = not cast_water_zone.contains(get_line_target_position())
				if retrieve_progress >= 1.0 or exited_rare_zone:
					retrieve_progress = 1.0
					# User feedback: a lure retrieve isn't guaranteed a bite
					# either - sometimes it just comes back empty.
					if cast_outcome == CastOutcome.TIMEOUT:
						_fail_catch("no_bite")
					else:
						_start_bite()
		State.BITE:
			bite_timer -= delta
			if bite_timer <= 0.0:
				_fail_catch("missed_bite")
		State.REELING:
			# The fight itself lives in FishFight (see its rules).
			var held := _is_action_pressed()
			var moving := velocity.length() > 1.0
			var reel_mult := MOVE_REEL_PENALTY if moving and fight.run_side == Vector2.ZERO else 1.0
			var line_dir := (cast_target - global_position).normalized()
			for ev in fight.update(delta, held, _counter_dir(), line_dir, reel_mult):
				_on_fight_event(ev)
			progress = fight.progress
			tension = fight.tension
			fish_run_active_time = fight.run_left
			reel_progress.emit(progress, tension)
			match fight.result:
				"landed":
					_succeed_catch()
				"line_break", "shook_off", "cover":
					_fail_catch(fight.result)
		_:
			pass


## Where a cast at `ratio` of full charge lands. User feedback: overshooting
## the water used to fail the cast - now it drops in at the far edge of the
## last water it flew over (a line that crosses no water still misses).
func landing_point(ratio: float) -> Vector2:
	var dist: float = lerp(MIN_CAST_DIST, max_cast_dist, ratio)
	var target := global_position + aim_dir * dist
	if _find_water_zone(target) != null:
		return target
	var step := 6.0
	var d := dist - step
	while d > MIN_CAST_DIST * 0.5:
		var p := global_position + aim_dir * d
		var zone := _find_water_zone(p)
		if zone != null:
			# A little way in from that far bank.
			return global_position + aim_dir * maxf(d - 6.0, MIN_CAST_DIST * 0.5)
		d -= step
	return target


func _launch_cast() -> void:
	if fishing_mode == FishingMode.BOBBER:
		bait_count = max(bait_count - 1, 0)

	# Design doc request: any cast can call up a water ghost before it even
	# lands - see _maybe_trigger_water_ghost(). It can set cast_jittered
	# itself, so this check comes before the jitter is consumed below.
	_maybe_trigger_water_ghost()

	var ratio: float = charge_time / MAX_CHARGE_TIME
	if cast_jittered or water_ghost_timer > 0.0:
		ratio = clamp(ratio * randf_range(0.3, 1.4), 0.0, 1.0)
		cast_jittered = false
		GameState.push_message("蓄力被干擾了，拋竿距離變得不可靠")
	cast_target = landing_point(ratio)

	# Design doc request: a cast that doesn't land in any water zone just
	# comes up empty - fishing only works where there's actually water now.
	cast_water_zone = _find_water_zone(cast_target)
	if cast_water_zone == null:
		GameState.push_message("這個方向沒有水，這竿撲空了")
		_reset_line(State.IDLE)
		return

	current_tier = FishData.tier_for_ratio(ratio)
	tier_data = FishData.get_tier_data(current_tier)
	wait_timer = randf_range(tier_data.wait_min, tier_data.wait_max)
	# User feedback: worm bait bites faster - trims the wait down.
	if pending_bait_flavor == BAIT_FLAVOR_WORM:
		wait_timer *= 0.7
	wait_timer *= float(lure_def().get("wait", 1.0))
	_wait_duration = wait_timer
	retrieve_progress = 0.0
	_roll_catch_outcome()
	_set_state(State.WAITING)
	cast_started.emit(cast_target, current_tier)


## Design doc §5.2/§5.3: decides now (revealed only at bite time) whether
## this cast lands a rare fish or, hotspot-only, a heart. Hotspots also
## boost rare odds far above open water's "surprise" chance. Design doc
## request: which water zone the cast landed in also scales the catch's
## value on its own, on top of any rare-fish roll.
func _roll_catch_outcome() -> void:
	is_rare_catch = false
	is_heart_catch = false
	is_epic_catch = false
	cast_outcome = CastOutcome.BITE
	caught_in_hotspot = _hotspot.active and cast_target.distance_to(_hotspot.global_position) <= Hotspot.RADIUS
	var in_rare_zone: bool = cast_water_zone != null and cast_water_zone.is_rare()
	var flavor := pending_bait_flavor
	var lure := lure_def()
	pending_bait_flavor = ""

	# User feedback: not every cast should land a fish. Roll this first and
	# skip the rare/heart rolls entirely on a dud, so they're never wasted
	# on a cast that was never going to bite anyway. A hotspot or rare zone
	# is supposed to be a reliably good spot, so it's much less likely here;
	# a fish-run weather window and "蟲子" bait both cut it further.
	var no_bite_chance := NO_BITE_CHANCE
	if caught_in_hotspot or in_rare_zone:
		no_bite_chance *= HOTSPOT_NO_BITE_MULT
	if GameState.weather == GameState.Weather.FISH_RUN:
		no_bite_chance *= FISH_RUN_WEATHER_NO_BITE_MULT
	if flavor == BAIT_FLAVOR_BUG:
		no_bite_chance *= 0.5
	no_bite_chance *= float(lure.get("no_bite", 1.0))
	if randf() < no_bite_chance:
		if fishing_mode == FishingMode.BOBBER and randf() < 0.5:
			cast_outcome = CastOutcome.BAIT_STOLEN
			stolen_timer = randf_range(_wait_duration * 0.2, _wait_duration * 0.7)
		else:
			cast_outcome = CastOutcome.TIMEOUT
		return

	var rare_chance := FAR_RARE_CHANCE if current_tier == "far" else NORMAL_RARE_CHANCE
	if in_rare_zone:
		rare_chance += RARE_ZONE_RARE_CHANCE_BONUS
	if GameState.weather == GameState.Weather.FISH_RUN:
		rare_chance += FISH_RUN_WEATHER_RARE_BONUS
	if flavor == BAIT_FLAVOR_FROG:
		rare_chance *= 2.0
	rare_chance *= float(lure.get("rare", 1.0))

	if caught_in_hotspot:
		var heart_chance := HOTSPOT_HEART_CHANCE_NIGHT if GameState.is_night else HOTSPOT_HEART_CHANCE_DAY
		if randf() < heart_chance:
			is_heart_catch = true
		elif randf() < HOTSPOT_RARE_CHANCE:
			is_rare_catch = true
	elif randf() < rare_chance:
		is_rare_catch = true

	# User feedback: rarity goes a step further - a rare catch has a small
	# chance to be upgraded again into a legendary "epic" fish.
	var epic_chance := EPIC_CHANCE_OF_RARE
	if flavor in BIG_BAIT_FLAVORS:
		epic_chance *= 2.0
	epic_chance *= float(lure.get("epic", 1.0))
	if is_rare_catch and randf() < epic_chance:
		is_epic_catch = true

	# User feedback: named species (FishData.SPECIES) replace the old
	# generic "稀有" + label - which zone type and rarity tier decide the
	# pool this cast draws from.
	tier_data = tier_data.duplicate()
	if is_heart_catch:
		# Not a real species - keep the fight gentle and give it its own
		# color rather than reusing whatever the last real fish rolled.
		fish_trait = "calm"
		current_fish_color = Color(1, 0.4, 0.5)
		difficulty_key = "novice"
		fish_habit = ""
	else:
		var zone_key := "rare" if in_rare_zone else "common"
		var rarity_key := "epic" if is_epic_catch else ("rare" if is_rare_catch else "common")
		var species: Dictionary = FishData.pick_species(current_tier, zone_key, rarity_key, lure.get("prefer", ""))
		tier_data.label = species.name
		tier_data.value = tier_data.value * float(species.value_mult)
		fish_trait = species.trait
		current_fish_color = species.color
		difficulty_key = FishData.difficulty_for(rarity_key, fish_trait)
		fish_habit = FishData.habit_for(species.name)

	# How long you get to strike: the difficulty's window, a little longer
	# close in and shorter far out (the cast tier's own window, 0.7 = mid).
	var diff: Dictionary = FishData.DIFFICULTY[difficulty_key]
	# A better rod (Profile.ROD_TIERS) gives a little longer.
	tier_data.bite_window = clampf(diff.window * tier_data.bite_window / 0.7 * float(Profile.rod().window), 0.3, 1.5)
	nibbles_left = maxi(randi_range(diff.nibbles.x, diff.nibbles.y) - int(lure.get("nibbles", 0)), 0)
	fake_chance = diff.fake * float(lure.get("fake", 1.0))
	_nibbled = false
	_lure_nibbles.clear()
	for _i in nibbles_left:
		_lure_nibbles.append(randf_range(0.35, 0.95))
	_lure_nibbles.sort()

	var zone_mult: float = RARE_ZONE_VALUE_MULT if in_rare_zone else COMMON_ZONE_VALUE_MULT
	tier_data.value = tier_data.value * zone_mult


## Design doc request: the fight should start from wherever the lure had
## actually been retrieved to when it got bit, not snap back to the
## original far-off cast point - freeze cast_target there before the
## state change (get_line_target_position() still reads the old state).
func _start_bite() -> void:
	if fishing_mode == FishingMode.LURE:
		cast_target = get_line_target_position()
	bite_timer = tier_data.bite_window
	_set_state(State.BITE)
	bite_started.emit()
	if is_heart_catch:
		GameState.push_message("水花特別亮、震動特別強...是心臟！")
	elif is_epic_catch:
		GameState.push_message("水面掀起巨浪，感覺上鉤的是隻大傢伙...傳說級的魚！")
	elif is_rare_catch:
		GameState.push_message("水花聲跟震動都變強了，是稀有魚！")


func _hook_fish() -> void:
	fight = FishFight.new(difficulty_key, fish_habit, tier_data, reel_power_mult, Profile.rod())
	progress = 0.0
	tension = fight.tension
	fish_run_active_time = 0.0
	GameState.push_message("上鉤了！（難度：%s）" % fight.label())
	_set_state(State.REELING)
	hook_success.emit()


## Which way the rod is being pulled, for answering a sideways run: the
## cast button being dragged, else the aim stick, else the way you walk.
func _counter_dir() -> Vector2:
	if touch_aim != Vector2.ZERO:
		return touch_aim
	if _aim_joystick.is_pressed:
		return _aim_joystick.output.normalized()
	if velocity.length() > 1.0:
		return velocity.normalized()
	return Vector2.ZERO


func _on_fight_event(kind: String) -> void:
	match kind:
		"run":
			GameState.push_message("魚往外衝！先放手放線")
		"side_run":
			GameState.push_message("魚往%s邊衝！往%s拉竿頂住" % [FishFight.describe(fight.run_side), FishFight.describe(-fight.run_side)])
		"jump":
			GameState.push_message("魚跳出水面！快放手！")
		"dive":
			GameState.push_message("魚往岸邊石縫鑽！按住收線把牠拉回來！")
		"dive_saved":
			GameState.push_message("把魚從石縫邊拉回來了")
		"enrage":
			GameState.push_message("魚暴走了！先放線撐住！")
	fight_event.emit(kind)


func _succeed_catch() -> void:
	if caught_in_hotspot:
		_hotspot.consume()

	if is_heart_catch:
		GameState.grant_heart()
		catch_success.emit({"name": "心臟", "value": 0, "tier": current_tier})
		Profile.record_catch("心臟", 0.0)
	else:
		var fish := {"name": tier_data.label, "value": tier_data.value, "tier": current_tier}
		catch_success.emit(fish)
		GameState.add_carried_fish(fish)
		Profile.record_catch(fish.name, fish.value)
		GameState.push_message("釣到了 %s！" % tier_data.label)

	_reset_line(State.IDLE)


func _fail_catch(reason: String) -> void:
	catch_failed.emit(reason)
	var msg := "魚跑掉了"
	# A snapped or frayed line takes the lure with it.
	var lure_gone: bool = reason in ["line_break", "cover"] and fishing_mode == FishingMode.LURE
	if lure_gone:
		_lose_lure()
	if reason == "line_break":
		msg = "線斷了，魚跑了"
	elif reason == "line_cut":
		msg = "線被鬼剪斷了！"
	elif reason == "lure_knocked":
		msg = "假餌被鬼弄掉了！"
	elif reason == "bait_stolen":
		msg = "餌被鬼偷走了！"
	elif reason == "bait_nibbled":
		msg = "餌被小魚偷吃掉了，什麼都沒釣到"
	elif reason == "no_bite":
		msg = "等了老半天，這裡沒魚咬餌"
	elif reason == "spooked":
		msg = "太早揚竿，把魚嚇跑了（等浮標整個沉下去、水花濺起再拉）"
	elif reason == "shook_off":
		msg = "魚在空中甩掉了魚鉤（跳起來時要放手）"
	elif reason == "cover":
		msg = "魚鑽進石縫，線被磨斷了"
	if lure_gone:
		msg += "，假餌也沒了"
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
