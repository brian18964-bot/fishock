class_name Player
extends CharacterBody2D

signal state_changed(new_state: String)
signal cast_started(target_pos: Vector2, tier: String)
signal bite_started()
signal hook_success()
signal catch_success(fish: Dictionary)
signal catch_failed(reason: String)
signal line_cleared()
signal sacrifice_progress_updated(progress: float)
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
## User request: only cast from near the water - no further than this from
## its edge; and with a line out, walk further than REEL_IN_SHORE_RANGE
## from it and the line is reeled in (a fish on it gets away).
const CAST_SHORE_RANGE := 90.0
const REEL_IN_SHORE_RANGE := 150.0
const MAX_CAST_DIST := 340.0
const MOVE_REEL_PENALTY := 0.5
## The map's size: the full map, or a campaign level's smaller one
## (Campaign sets these before the run's scene loads).
static var WORLD_WIDTH := 2400.0
static var WORLD_HEIGHT := 1350.0
const START_BAIT := 20
const START_LURES := 5

## Design doc request: carrying more fish weighs the player down; each
## fish drops speed a bit further, floored so it's slow, never frozen.
const WEIGHT_SPEED_PENALTY := 0.05
const MIN_SPEED_RATIO := 0.4

## Design doc request: reeling a lure in is player-paced, not an automatic
## countdown - holding retrieves steadily, each tap also nudges it a bit
## for fine, "點收" control when you want to go slower.
## User feedback: each tap reeled in far too much to feel like fishing -
## both cut to about a quarter.
const LURE_HOLD_RATE := 0.25
const LURE_CLICK_AMOUNT := 0.03
## User feedback: lure bites all came right at the end, by the player -
## a fish strikes somewhere along the retrieve (this share of the way in).
const LURE_BITE_RANGE := Vector2(0.15, 0.85)

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
const WATER_GHOST_RANGE := 40.0
## ...and only when the cast lands this close in to the bank.
const WATER_GHOST_BOBBER_RANGE := 60.0
const WATER_GHOST_DEBUFF_DURATION := 4.0
## User decision: out on a dock (walkway over the water) the ghost has a
## harder time reaching you.
const DOCK_WATER_GHOST_MULT := 0.35
const ANIMAL_ATTACK_DEBUFF_DURATION := 2.5
const WATER_GHOST_SPEED_MULT := 0.55
## User request (the black spider): its bite sometimes poisons - a big
## slow-down for a while (no wobble, just heavy legs). Round 8: a snake's
## bite or a bee's sting too - how likely is the critter's (Critter.venom()).
const POISON_TIME := 8.0
const POISON_SPEED_MULT := 0.4
## A black spider caught is worth this many baits (the risk's reward).
const BLACK_SPIDER_BAIT := 2
## Round 8 (user request): the landing net in hand (worn in the off hand,
## held between casts - offhand_in_hand()) reaches a critter NET_REACH px
## off (bare-handed: standing on it) and halves the chance it bites or
## stings.
const NET_REACH := 46.0
const NET_VENOM_MULT := 0.5
## Round 8 (user request): what turns up under a rock or drops from a tree
## goes in the bag as a live bait (Profile.LIVE_BAITS) - by its flavor.
const FOUND_BAIT := {"蚯蚓": "worm", "蟲子": "cricket", "青蛙": "frog"}
## A weapon that defends (Profile.WEAPONS): the stagger it leaves.
const PARRY_DEBUFF_DURATION := 0.8
## Chopping: how close to a trunk.
const CHOP_REACH := 34.0

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
const NIBBLE_GAP := Vector2(0.9, 1.8)

## User feedback: rarity should go a step further than common/rare - a
## small chance for a rare catch to be upgraded to a legendary "epic" fish
## (see FishData.pool_for()'s "epic" pools), worth much more and fights harder
## still on top of the normal rare-catch difficulty bump.
const EPIC_CHANCE_OF_RARE := 0.18

## User feedback: bait flavor from roadside rummaging should actually do
## something, not just be a message string - each type biases the very
## next cast one way, then gets used up regardless of what happens.
const BAIT_FLAVOR_WORM := "蚯蚓"
const BAIT_FLAVOR_BUG := "蟲子"
const BAIT_FLAVOR_FROG := "青蛙"
## User request: critters (see Critter) can be caught as bait. Rats,
## snakes and the beach's crabs are "big bait": a rare catch is twice as
## likely to turn epic.
const BIG_BAIT_FLAVORS := ["老鼠", "蛇", "螃蟹", "小活魚", "活青蛙"]
## User request (the shop's live frog and spider): the frog is big bait that
## also draws rare fish like a caught frog; the spider halves empty casts
## (as bugs do) and fake bites.
const BAIT_FLAVOR_LIVE_FROG := "活青蛙"
const BAIT_FLAVOR_SPIDER := "蜘蛛"

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
var in_rock_zone: bool = false
var in_critter_zone: bool = false
var current_noise_radius: float = 0.0
var cast_jittered: bool = false
var retrieve_progress: float = 0.0
var cast_water_zone: WaterZone
var water_ghost_timer: float = 0.0
## Poisoned (a black spider's bite): seconds left, see POISON_SPEED_MULT.
var poison_timer: float = 0.0
## User request (round 7): things used from the bag (Profile.USABLES,
## use_item()). The increase potion: VIGOR_TIME s running VIGOR_SPEED
## times as fast, the line's tension building VIGOR_STRAIN as fast in a
## fight. The ghost-ward potion: WARD_TIME s that no ghost comes within
## WARD_RADIUS (the big one can't grab, the floating ones give up, the
## water ghost won't rise). The eyes and the binoculars: GuideArrow
## pointing for GUIDE_TIME s - round 8 (user request): the eyeball at the
## 渡石, the golden eye (eye_altar) at the altar, the ghost eye at the
## nearest ghost (following it), the binoculars at the nearest water; the
## binoculars aren't used up, but wait BINOCULARS_COOLDOWN s after.
const VIGOR_TIME := 45.0
const VIGOR_SPEED := 1.3
const VIGOR_STRAIN := 0.75
const WARD_TIME := 30.0
const WARD_RADIUS := 110.0
const GUIDE_TIME := 20.0
const BINOCULARS_COOLDOWN := 60.0
const ALTAR_GUIDE := Color(1.0, 0.5, 0.42)
const STONE_GUIDE := Color(0.45, 1.0, 0.85)
const GHOST_GUIDE := Color(0.72, 0.6, 1.0)
const WATER_GUIDE := Color(0.45, 0.75, 1.0)
## The binoculars look past the water you're standing at (this close) to
## the next, if there's another.
const BINOCULARS_SKIP := 60.0
var vigor_timer := 0.0
var ward_timer := 0.0
var binoculars_cooldown := 0.0
var guide: GuideArrow
## User request: the off hand (Profile.offhand() - a weapon or the net) is
## held while the rod's on the back - between casts (offhand_in_hand()) -
## and hangs at the hip while fishing. A tap of the right stick (Q on a
## keyboard) swings it (swing()): a blade slashes at the beasts close by
## (they run), the hatchet or the machete chops a tree in reach, the net
## scoops a critter, the pistol fires at a beast ahead (GUN_RANGE, within
## GUN_CONE of the aim). A swing takes SWING_TIME, its blow landing
## SWING_HIT in; each wears the thing (Profile.wear_out). A press on the
## stick held past SWING_TAP, or dragged, draws the rod and casts instead.
const SWING_TIME := 0.55
const SWING_HIT := 0.25
const SWING_TAP := 0.2
const SWING_DRAG := 0.3
const SWING_REACH := 46.0
const GUN_RANGE := 220.0
const GUN_CONE := 0.5
## The swing on ("slash", "chop", "scoop", "shoot"; "" for none) and its
## seconds left.
var swing_kind := ""
var swing_left := 0.0
var _swing_landed := false
## Seconds the right stick's been pressed while the off hand's held (a tap
## swings; -1: not deciding).
var _stick_press := -1.0
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
## User request: a fish is reeled in by turning the right stick round and
## round like a reel's handle - the faster, the faster the line comes in
## (FishFight). crank: 0..1, CRANK_FULL turns a second flat out; eased
## (CRANK_EASE) so a stroke reads as a steady turn. The stick must be
## pushed out at least CRANK_REACH to turn it. Space on a keyboard cranks
## at FishFight.CRANK_NORMAL (with Shift, flat out).
const CRANK_FULL := 1.6
const CRANK_EASE := 7.0
const CRANK_REACH := 0.35
var crank := 0.0
var _crank_angle := 0.0
var _crank_had := false
## User request: the fish's pull on the line (FishFight.swim_out, m/s) -
## by how hard it fights (DIFFICULTY's pull), rare and legendary fish,
## wild ones, and big ones off the far water. User feedback (the longer
## fights): eased so the legends can be brought in - from the far water
## with a better rod's longer line.
const SWIM_OUT := 0.7
const SWIM_OUT_RARE := 1.25
const SWIM_OUT_EPIC := 1.3
const SWIM_OUT_TRAIT := {"calm": 0.8, "normal": 1.0, "wild": 1.15}
const SWIM_OUT_FAR := 1.05
## The line on the reel (m): LINE_BASE, LINE_PER_TIER more each better rod.
const LINE_BASE := 40.0
const LINE_PER_TIER := 5.0
## World px to a m of line (as GuideArrow shows distances).
const PX_PER_M := 16.0
## Why the line last went, said with the loss (see _fail_catch()).
var _snap_note := ""
var difficulty_key := "novice"
var fish_habit := ""
var nibbles_left := 0
## Chance each test nibble is a fake dunk (the difficulty's, times the lure's).
var fake_chance := 0.0
var _nibbled := false
var _lure_nibbles: Array = []
## Where along this retrieve the fish strikes (a share of the way in).
var _lure_bite_at := 1.0
var pending_bait_flavor: String = ""
var is_epic_catch: bool = false
var fish_trait: String = "normal"
var current_fish_color: Color = Color(1, 0.85, 0.2)
## The species on the line (FishData.FISH id; "" for the heart).
var fish_id := ""

## Design doc §9.1/§9.2: base cast distance / reel speed plus the
## rod_distance / reel_power Profile upgrades, recomputed in reset_gear()
## since upgrades only change between runs.
var max_cast_dist: float = MAX_CAST_DIST
var reel_power_mult: float = 1.0

const SACRIFICE_DURATION := 0.6
var sacrifice_progress: float = 0.0

## Design doc request: the oil drum is carried back to a fuel station by
## hand instead of refilling the whole map on the spot - see
## _handle_action_input()'s oil-drum/fuel-station branches.
var carrying_oil_drum: bool = false
## User request: the big ghost drags the player off to its cage. While
## held (carried, then caged) the player can't move or fish; whoever holds
## them places them (BigGhost).
var held: bool = false

var _fuel_station: FuelStation
var _oil_drum: OilDrum
var _carried_oil_drum: OilDrum
var _dropped_fish: DroppedFish
var _rock: FlipRock
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
var _prev_use_held: bool = false
var _prev_mode_toggle_held: bool = false
var _key_prev_held: Dictionary = {}

@onready var facing_indicator: ColorRect = $FacingIndicator
@onready var _move_joystick: TouchJoystick = get_tree().current_scene.get_node("HUD/Panel/MoveJoystick")
@onready var _aim_joystick: TouchJoystick = get_tree().current_scene.get_node("HUD/Panel/AimJoystick")
@onready var _hotspot: Hotspot = get_tree().current_scene.get_node("Hotspot")


func _ready() -> void:
	add_to_group("player")
	var guide_layer := CanvasLayer.new()
	guide_layer.name = "GuideLayer"
	# (over the things' buttons - ActionPrompt, 4 - so they don't hide it)
	guide_layer.layer = 5
	add_child(guide_layer)
	guide = GuideArrow.new()
	guide.name = "Guide"
	guide.follow = self
	guide.visible = false
	guide_layer.add_child(guide)
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam != null:
		cam.limit_right = int(WORLD_WIDTH)
		cam.limit_bottom = int(WORLD_HEIGHT)
	# The gas can in hand while it's being carried (see OilDrum).
	# User feedback: held in the hand, swinging with the walk (carried_can.gd).
	var hand := Node2D.new()
	hand.name = "CarriedCan"
	var can := Sprite2D.new()
	can.name = "Can"
	var tex := CanvasTexture.new()
	tex.diffuse_texture = preload("res://assets/sprites/gas_can/gas_can_55deg_albedo.png")
	tex.normal_texture = preload("res://assets/sprites/gas_can/gas_can_55deg_normal.png")
	can.texture = tex
	Art.place(can, Vector2(0, -5.56), 0.5)
	hand.add_child(can)
	hand.set_script(preload("res://scripts/carried_can.gd"))
	hand.visible = false
	add_child(hand)
	# User request: the off hand's thing, in the hand or at the hip.
	var prop := OffhandProp.new()
	prop.name = "Offhand"
	add_child(prop)
	reset_gear()
	_set_state(State.IDLE)
	Profile.gear_broke.connect(_on_gear_broke)


## User request: worn out, a thing breaks - said, and it's gone.
func _on_gear_broke(id: String, item_name: String) -> void:
	Sfx.play("swipe_hit", -4.0)
	if id.begins_with("rod_"):
		GameState.push_message("%s用壞了，斷成兩截！換上%s" % [item_name, Profile.rod().name])
	else:
		GameState.push_message("%s用壞了！要回營地的商店買新的" % item_name)
	GameState.report("%s壞掉了" % item_name, "warn")


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
			GameState.push_message("可以抓%s當餌料（點牠旁邊的「抓餌」）" % critter.get_label())
	elif critter == _critter:
		in_critter_zone = false
		_critter = null


func set_in_rock(value: bool, rock: FlipRock) -> void:
	if value:
		in_rock_zone = true
		_rock = rock
	elif rock == _rock:
		in_rock_zone = false
		_rock = null


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
	Profile.ensure_bait()
	bait_count = Profile.base_bait()
	lure_stock = Profile.consume_loadout_lures()
	_sync_lures()
	fishing_mode = FishingMode.BOBBER
	swing_kind = ""
	swing_left = 0.0
	_stick_press = -1.0
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


## Grabbed by the big ghost: whatever was going on is dropped.
## User request (Camp v2): seized by the big ghost, the player struggles -
## a few seconds to get free (the heart, the strong light, a fish thrown;
## see BigGhost) - and staggers back when they do.
const KNOCK_TIME := 0.55
const KNOCK_SPEED := 120.0
var struggling := false
var grab_from := Vector2.ZERO
var _knock_time := 0.0
var _knock_dir := Vector2.ZERO


func seize(from := Vector2.ZERO) -> void:
	held = true
	struggling = true
	grab_from = from
	velocity = Vector2.ZERO
	charge_time = 0.0
	if state != State.IDLE:
		_reset_line(State.IDLE)
	_force_drop_oil_drum()


func release() -> void:
	held = false
	struggling = false


## Free of the big ghost's grip: thrown back a step, staggering.
func break_free(from: Vector2) -> void:
	release()
	var away := global_position - from
	_knock_dir = away.normalized() if away.length() > 0.5 else Vector2.DOWN
	_knock_time = KNOCK_TIME


func knocked() -> bool:
	return _knock_time > 0.0


## How far through the stagger (0..1), for the sprite.
func knock_progress() -> float:
	return 1.0 - _knock_time / KNOCK_TIME if _knock_time > 0.0 else 1.0


## The heart, spent by hand to break the big ghost's grip (H, or the HUD's
## button).
func use_heart_to_escape() -> bool:
	var big := get_tree().current_scene.get_node_or_null("BigGhost")
	return big != null and struggling and big.escape_with_heart()


## The live bait on the hook (Profile.LIVE_BAITS key; "" for the base
## bait): one is used per float cast while any are in the bag.
var live_bait := ""


func choose_live_bait(key: String) -> void:
	live_bait = key if key == "" or Profile.bag_count("live_" + key) > 0 else ""
	if live_bait != "":
		fishing_mode = FishingMode.BOBBER
		GameState.push_message("換上活餌：%s" % Profile.LIVE_BAITS[live_bait].name)


## A float cast takes a live bait (its flavor on the hook) while any of
## the one chosen are packed, else a base bait.
func use_bait_for_cast() -> void:
	if live_bait != "" and Profile.bag_take("live_" + live_bait, 1) == 1:
		pending_bait_flavor = Profile.LIVE_BAITS[live_bait].flavor
		if Profile.bag_count("live_" + live_bait) <= 0:
			live_bait = ""
	else:
		live_bait = ""
		bait_count = max(bait_count - 1, 0)


func _can_start_cast() -> bool:
	if fishing_mode == FishingMode.BOBBER:
		return bait_count > 0 or (live_bait != "" and Profile.bag_count("live_" + live_bait) > 0)
	return lure_count > 0


func _lose_lure() -> void:
	Campaign.stat("lure_lost")
	if current_lure != "":
		lure_stock[current_lure] = maxi(int(lure_stock.get(current_lure, 0)) - 1, 0)
		Profile.bag_take("lure_" + current_lure, 1)
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
## rolling a water-ghost attack on every cast. User request: stricter - it
## only lands on a player standing right at the water's edge whose cast
## also drops close in by the bank.
func _maybe_trigger_water_ghost() -> void:
	var chance := WATER_GHOST_CHANCE * float(Campaign.rules.water_ghost)
	if chance <= 0.0:
		return
	if GameState.weather == GameState.Weather.STORM:
		chance *= STORM_WATER_GHOST_MULT
	if Dock.on_walkway(get_tree(), global_position + FEET) and _find_water_zone(global_position + FEET) != null:
		chance *= DOCK_WATER_GHOST_MULT
	if randf() >= chance:
		return
	# User request: only for someone right at the water's edge whose float
	# lands close in by the bank too.
	if _nearest_water_edge_distance() > WATER_GHOST_RANGE:
		return
	if cast_water_zone == null or cast_water_zone.depth(cast_target) > WATER_GHOST_BOBBER_RANGE:
		return
	_apply_water_ghost_attack()


func _apply_water_ghost_attack(cause := "") -> void:
	if ward_timer > 0.0:
		# (the ghost-ward potion: it doesn't dare)
		GameState.report("水鬼探出頭，又被藥水的氣味逼回水裡")
		return
	water_ghost_timer = WATER_GHOST_DEBUFF_DURATION
	affliction_text = "水鬼異常狀態中"
	cast_jittered = true
	if fishing_mode == FishingMode.BOBBER:
		bait_count = max(bait_count - 1, 0)
	else:
		_lose_lure()
	# User request: and it's seen doing it (WaterGhost).
	WaterGhost.summon(self)
	var stolen: Dictionary = GameState.steal_one_carried()
	Campaign.stat("water_ghost_hit")
	if not stolen.is_empty():
		Campaign.stat("stolen")
	var msg := "水鬼從水裡冒出來偷襲！身上狀態異常中"
	if not stolen.is_empty():
		msg = "水鬼冒出來偷襲，還搶走了一條 %s！身上狀態異常中" % stolen.get("name", "魚")
	GameState.push_message(cause + msg)
	GameState.report("水鬼偷襲！" if stolen.is_empty() else "水鬼偷襲，搶走了%s" % stolen.get("name", "魚"))


## User request (round 7): uses one of Profile.USABLES from the bag (see
## VIGOR_TIME...); false (and why, in the event feed) if it can't be.
func use_item(id: String) -> bool:
	if Profile.bag_count(id) < 1:
		return false
	match id:
		"potion_vigor":
			Profile.bag_take(id, 1)
			vigor_timer = VIGOR_TIME
			GameState.report("喝下增強藥水：腳步輕快，手上更有力", "good")
		"potion_ward":
			Profile.bag_take(id, 1)
			ward_timer = WARD_TIME
			for ghost in get_tree().get_nodes_in_group("ghosts"):
				if ghost.global_position.distance_to(global_position) < WARD_RADIUS * 1.5 and ghost.has_method("stun"):
					ghost.stun(1.5)
			for ghost in get_tree().get_nodes_in_group("water_ghosts"):
				ghost.repel()
			GameState.report("喝下驅鬼藥水：鬼魂近不了身", "good")
		"eyeball":
			var stone: Node2D = get_tree().current_scene.get_node_or_null("EscapePoint")
			if stone == null:
				return false
			Profile.bag_take(id, 1)
			guide.show_to(stone.global_position, "渡石", STONE_GUIDE, GUIDE_TIME)
			GameState.report("眼球轉了過去，盯著渡石的方向", "info")
		"eye_altar":
			var altar: Node2D = get_tree().current_scene.get_node_or_null("Altar")
			if altar == null:
				return false
			Profile.bag_take(id, 1)
			guide.show_to(altar.global_position, "祭壇", ALTAR_GUIDE, GUIDE_TIME)
			GameState.report("金色的眼睛亮了起來，盯著祭壇的方向", "info")
		"eye_ghost":
			var ghost := nearest_ghost()
			if ghost == null:
				GameState.report("眼睛四處張望……附近看不見鬼", "info")
				return false
			Profile.bag_take(id, 1)
			guide.show_to(ghost.global_position, "鬼", GHOST_GUIDE, GUIDE_TIME)
			guide.track = func():
				var g := nearest_ghost()
				return g.global_position if g != null else null
			GameState.report("眼裡浮出一縷白霧，看見了鬼的方向", "info")
		"binoculars":
			if binoculars_cooldown > 0.0:
				GameState.report("望遠鏡的鏡片還起著霧（%d 秒）" % ceili(binoculars_cooldown), "warn")
				return false
			var water := nearest_water()
			if water.is_empty():
				return false
			binoculars_cooldown = GUIDE_TIME + BINOCULARS_COOLDOWN
			guide.show_to(water.at, water.name, WATER_GUIDE, GUIDE_TIME)
			GameState.report("用望遠鏡望見了%s" % water.name, "info")
		_:
			return false
	Sfx.play("ui_open", -8.0)
	return true


## The nearest ghost about (a floating one or the big one), or null.
func nearest_ghost() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for group in ["ghosts", "big_ghost"]:
		for g in get_tree().get_nodes_in_group(group):
			var ghost := g as Node2D
			if ghost == null or not ghost.is_inside_tree() or not ghost.visible:
				continue
			var d := global_position.distance_to(ghost.global_position)
			if d < best_d:
				best = ghost
				best_d = d
	return best


## The binoculars' find: the nearest water's nearest shore {at, name} -
## past the water you're standing at when there's another; {} for none.
func nearest_water() -> Dictionary:
	var finds := []
	for zone in get_tree().get_nodes_in_group("water_zones"):
		var best := Vector2.ZERO
		var best_d := INF
		for poly in zone.outline:
			for i in poly.size():
				var q := Geometry2D.get_closest_point_to_segment(global_position, poly[i], poly[(i + 1) % poly.size()])
				var d := global_position.distance_to(q)
				if d < best_d:
					best = q
					best_d = d
		if best_d < INF:
			finds.append({"at": best, "d": best_d, "name": "稀有水域" if zone.is_rare() else "水域"})
	if finds.is_empty():
		return {}
	finds.sort_custom(func(a, b): return a.d < b.d)
	if finds.size() > 1 and finds[0].d < BINOCULARS_SKIP:
		return finds[1]
	return finds[0]


## User request: a floating ghost passing through the player leaves them
## dizzy - the same muddled steering and slow feet as a water-ghost hit.
func ghost_confuse(duration: float) -> void:
	water_ghost_timer = maxf(water_ghost_timer, duration)
	affliction_text = "被鬼纏過，頭昏眼花"


## The off hand's thing is in hand: worn, and the rod on the back (not
## fishing, the hands not full of the oil drum, not in the big ghost's
## grip).
func offhand_in_hand() -> bool:
	return Profile.offhand() != "" and state == State.IDLE and not carrying_oil_drum and not held


## The weapon in hand (Profile.WEAPONS entry; {} with none in the off hand,
## or while fishing - it's at the hip then).
func held_weapon() -> Dictionary:
	return Profile.weapon if offhand_in_hand() else {}


## The landing net in hand.
func net_in_hand() -> bool:
	return Profile.has_net() and offhand_in_hand()


## What a swing of the off hand's thing does now: "chop" (a tree in reach
## and a chopping blade - the hatchet always), "slash" (a blade), "scoop"
## (the net), "shoot" (the pistol); "" with nothing to swing.
func swing_move() -> String:
	var id := Profile.offhand()
	if id == "" or not offhand_in_hand():
		return ""
	if id == "net":
		return "scoop"
	var w: Dictionary = Profile.weapon
	if w.get("gun", false):
		return "shoot"
	if int(w.get("chop", 0)) > 0 and (choppable_tree() != null or not w.get("defend", false)):
		return "chop"
	return "slash"


## Swings the off hand's thing (see SWING_TIME); false if it can't now.
func swing(kind := "") -> bool:
	if kind == "":
		kind = swing_move()
	if kind == "" or swing_left > 0.0 or not offhand_in_hand():
		return false
	swing_kind = kind
	swing_left = SWING_TIME
	_swing_landed = false
	return true


func _update_swing(delta: float) -> void:
	if swing_left <= 0.0:
		return
	swing_left = maxf(swing_left - delta, 0.0)
	if not _swing_landed and SWING_TIME - swing_left >= SWING_HIT:
		_swing_landed = true
		_swing_lands()
	if swing_left <= 0.0:
		swing_kind = ""


## The swing's blow, as it lands.
func _swing_lands() -> void:
	var id := Profile.offhand()
	if id == "":
		return
	match swing_kind:
		"chop":
			var tree := choppable_tree()
			if tree != null:
				_chop_tree(tree)
			else:
				_drive_off_beasts()
		"scoop":
			if reachable_critter() != null:
				_catch_critter()
		"slash":
			_drive_off_beasts()
		"shoot":
			_fire()
			return
	Sfx.play_at("swipe_hit", global_position, -10.0)
	Profile.wear_out(id)


## A blade swung: the beasts close by run.
func _drive_off_beasts() -> void:
	var hit := 0
	for c in get_tree().get_nodes_in_group("critters"):
		var beast := c as Critter
		if beast != null and beast.is_hunter() and beast.global_position.distance_to(global_position) < SWING_REACH * 1.3:
			beast.scare()
			hit += 1
	if hit > 0:
		GameState.report("揮%s趕走了野獸" % Profile.weapon.get("name", "刀"), "good")


## The pistol fired (a tap): a round from the bag; the beasts ahead (or
## right by) run, and the big ghost hears it.
func _fire() -> void:
	if Profile.bag_take("ammo", 1) != 1:
		Sfx.play("ui_click", -6.0)
		GameState.report("沒有子彈了（子彈要放在背包）", "warn")
		return
	Profile.wear_out("glock")
	Sfx.play_at("gunshot", global_position, -2.0, 0.03)
	Campaign.stat("gunshot")
	var hit: Critter = null
	for c in get_tree().get_nodes_in_group("critters"):
		var beast := c as Critter
		if beast == null or not beast.is_hunter():
			continue
		var to := beast.global_position - global_position
		if to.length() < GUN_RANGE and (to.length() < SWING_REACH or to.normalized().dot(aim_dir) > GUN_CONE):
			beast.scare()
			hit = beast
	if hit != null:
		GameState.report("開槍嚇跑了%s（子彈剩 %d）" % [hit.get_label(), Profile.bag_count("ammo")], "info")
	else:
		GameState.report("開了一槍（子彈剩 %d）" % Profile.bag_count("ammo"), "info")
	for ghost in get_tree().get_nodes_in_group("big_ghost"):
		ghost.hear(global_position)


## User decision: wolves and the meat-eating dinosaurs chase the player
## (see Critter); one that catches up knocks a carried fish to the ground
## (it can be picked back up, like a G-dropped one), snaps the line if
## you're fishing, and leaves you slowed for a moment.
func animal_attack(attacker: String) -> void:
	# User request (weapons): a blade worn turns the pounce aside - a short
	# stagger, nothing knocked loose, the line kept.
	if held_weapon().get("defend", false):
		Profile.wear_out(Profile.offhand())
		# (the parry seen as a slash - its blow already struck)
		if swing("slash"):
			_swing_landed = true
		water_ghost_timer = maxf(water_ghost_timer, PARRY_DEBUFF_DURATION)
		affliction_text = "擋下了%s的撲擊" % attacker
		Sfx.play_at("swipe_hit", global_position, -4.0)
		Campaign.stat("parry")
		GameState.push_message("%s撲上來，你揮出%s擋開了牠！" % [attacker, held_weapon().name])
		GameState.report("揮刀擋開了%s" % attacker)
		return
	water_ghost_timer = maxf(water_ghost_timer, ANIMAL_ATTACK_DEBUFF_DURATION)
	affliction_text = "被%s攻擊，行動變慢" % attacker
	Campaign.stat("animal_hit")
	if state != State.IDLE:
		_cancel_cast("animal_attack")
	var fish: Dictionary = GameState.drop_one_carried()
	if fish.is_empty():
		GameState.push_message("%s撲了上來！" % attacker)
		GameState.report("%s撲上來了！" % attacker)
		return
	var dropped: DroppedFish = DROPPED_FISH_SCENE.instantiate()
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * 40.0
	dropped.setup(fish)
	GameState.push_message("%s撲了上來，%s 掉在地上了！" % [attacker, fish.get("name", "魚")])
	GameState.report("%s撲上來，%s掉了" % [attacker, fish.get("name", "魚")])


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
		choose_bobber()
	else:
		choose_lure(next)


## User request: picked straight from the backpack (Backpack), or stepped
## through with Tab. Only between casts.
func choose_bobber() -> void:
	if state != State.IDLE or fishing_mode == FishingMode.BOBBER:
		return
	fishing_mode = FishingMode.BOBBER
	GameState.push_message("切換成浮標")


func choose_lure(id: String) -> void:
	if state != State.IDLE or int(lure_stock.get(id, 0)) <= 0:
		return
	if fishing_mode == FishingMode.LURE and current_lure == id:
		return
	fishing_mode = FishingMode.LURE
	current_lure = id
	GameState.push_message("切換成路亞：%s－%s" % [lure_label(id), Profile.LURES[id].desc])


## Legacy debug-key path to the same purchases the title screen's shop UI
## now offers - kept working since it's harmless (nothing here takes
## effect until the next reset_gear()), just no longer the primary way in.
func _handle_shop_input() -> void:
	if _key_just_pressed(KEY_B):
		if Profile.buy_lure("minnow"):
			GameState.push_message("買了一個假餌（放進倉庫），這輪不會生效")
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
const FISH_TOSS := 36.0


func _handle_drop_input() -> void:
	# G (keyboard): the 誘惑 throw - held to charge, let go to throw; with no
	# fish picked yet it opens the bag to pick one.
	var g := Input.is_key_pressed(KEY_G)
	var pressed: bool = g and not _key_prev_held.get(KEY_G, false)
	_key_prev_held[KEY_G] = g
	if pressed and GameState.lure_index() < 0:
		pick_lure_fish()
		return
	if g and GameState.lure_index() >= 0:
		lure_held = true
	elif _g_throwing:
		lure_held = false
	_g_throwing = g and GameState.lure_index() >= 0


## User request (誘惑): the fish picked as a lure is thrown - charged like a
## cast (held longer, thrown further; dragged, aimed) - far off to draw the
## big ghost away, or close by to save your skin (and, later, a teammate).
## lure_held: the button / G is held (TouchControls sets it); lure_aim: the
## direction dragged (ZERO: the way you face).
const LURE_THROW_MIN := 30.0
const LURE_THROW_MAX := 260.0
const LURE_CHARGE_TIME := 1.2
var lure_held := false
var lure_aim := Vector2.ZERO
## Set by the touch button: how far it's dragged (0..1) - the throw's
## length; -1 (keyboard): it charges by holding instead.
var lure_pull := -1.0
var lure_charge := 0.0
var _lure_charging := false
var _g_throwing := false
var _lure_guide: LureGuide


## Opens the bag to pick the 誘惑 fish.
func pick_lure_fish() -> void:
	if GameState.carried_fish.is_empty():
		GameState.push_message("身上沒有魚可以當誘餌")
		return
	var bag := backpack()
	if bag != null:
		bag.open_mode("pick_lure")


func backpack() -> Backpack:
	for c in get_tree().current_scene.get_children():
		if c is Backpack:
			return c
	return null


func _update_lure_throw(delta: float) -> void:
	if _lure_guide == null:
		# On a layer of its own that follows the camera: out of reach of the
		# night's darkening (CanvasModulate), so it shows in the dark.
		var layer := CanvasLayer.new()
		layer.layer = 2
		layer.follow_viewport_enabled = true
		add_child(layer)
		_lure_guide = LureGuide.new()
		layer.add_child(_lure_guide)
	if lure_held and GameState.lure_index() >= 0 and state == State.IDLE and (not held or struggling):
		if not _lure_charging:
			_lure_charging = true
			lure_charge = 0.0
		if lure_pull >= 0.0:
			lure_charge = lure_pull
		else:
			lure_charge = minf(lure_charge + delta / LURE_CHARGE_TIME, 1.0)
		_lure_guide.show_throw(global_position, lure_target())
	elif _lure_charging:
		_lure_charging = false
		_lure_guide.hide_throw()
		if not lure_held:
			throw_lure()
		lure_charge = 0.0
		lure_aim = Vector2.ZERO
		lure_pull = -1.0


## Where the lure fish would land now: out along the aim (dragged, or the
## way you face) by the charge, short of any water.
func lure_target() -> Vector2:
	var dir := lure_aim.normalized() if lure_aim != Vector2.ZERO else aim_dir.normalized()
	var dist := lerpf(LURE_THROW_MIN, LURE_THROW_MAX, lure_charge)
	var to := global_position + dir * dist
	var step := 0
	while step < 20 and Ripple.water_at(get_tree(), to + FEET) != null:
		dist -= 16.0
		to = global_position + dir * maxf(dist, 0.0)
		step += 1
	return to


func throw_lure() -> void:
	var i := GameState.lure_index()
	if i < 0:
		return
	var to := lure_target()
	var fish: Dictionary = GameState.drop_carried_at(i)
	if fish.is_empty():
		return
	var dropped: DroppedFish = DROPPED_FISH_SCENE.instantiate()
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = global_position
	dropped.setup(fish)
	dropped.fly_to(to)
	GameState.push_message("丟出誘餌 %s（大鬼會被引過去）" % fish.get("name", "魚"))
	if Profile.settings.get("auto_lure", false):
		# Settings: the cheapest fish carried is the next lure.
		var best := -1
		for j in GameState.carried_fish.size():
			var f: Dictionary = GameState.carried_fish[j]
			if best < 0 or float(f.get("value", 0.0)) < float(GameState.carried_fish[best].get("value", 0.0)):
				best = j
		GameState.set_lure(best)


## Puts carried fish `index` down at your feet (from the bag).
func put_fish_down(index: int) -> void:
	var fish: Dictionary = GameState.drop_carried_at(index)
	if not fish.is_empty():
		_put_fish_down(fish, global_position + Vector2(randf_range(-10, 10), 10))
		GameState.push_message("把 %s 放在地上" % fish.get("name", "魚"))


## User request (for multiplayer): puts the bag stack at `index` (Profile.bag)
## down on the ground, to be picked up again (DroppedItem).
func put_item_down(index: int) -> void:
	var e := Profile.bag_remove(index)
	if e.is_empty():
		return
	var key: String = Items.def(e.id).get("lure", "")
	if key != "":
		lure_stock[key] = maxi(int(lure_stock.get(key, 0)) - int(e.count), 0)
		_sync_lures()
		if lure_count <= 0 and fishing_mode == FishingMode.LURE:
			fishing_mode = FishingMode.BOBBER
	var item := DroppedItem.make(e.id, int(e.count))
	get_tree().current_scene.add_child(item)
	item.global_position = global_position + Vector2(randf_range(-12, 12), 12)
	GameState.push_message("把 %s 放在地上" % item.title())


func _nearest_dropped_item() -> DroppedItem:
	var best: DroppedItem = null
	var best_d := DroppedItem.PICK_RANGE
	for n in get_tree().get_nodes_in_group("dropped_items"):
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best = n
			best_d = d
	return best


func _pick_up_item(item: DroppedItem) -> void:
	if item == null:
		return
	var n := Profile.bag_put(item.item_id, item.count)
	if n <= 0:
		GameState.push_message("背包滿了，放不下")
		return
	var key: String = Items.def(item.item_id).get("lure", "")
	if key != "":
		lure_stock[key] = int(lure_stock.get(key, 0)) + n
		_sync_lures()
	if n < item.count:
		item.count -= n
		GameState.push_message("撿起了一部分（背包滿了）")
		return
	GameState.push_message("撿起了 %s" % item.title())
	item.pick_up()


## Tosses carried fish `index` a little way ahead (also from the backpack):
## thrown to the big ghost, it stops to eat it (BigGhost). Into the water
## it isn't - then at your feet.
func throw_fish(index: int) -> void:
	var fish: Dictionary = GameState.drop_carried_at(index)
	if fish.is_empty():
		return
	var toss := global_position + aim_dir.normalized() * FISH_TOSS
	_put_fish_down(fish, global_position if Ripple.water_at(get_tree(), toss + FEET) != null else toss)
	GameState.push_message("丟出了一條 %s，跑得更快了（大鬼會被魚引開）" % fish.get("name", "魚"))


func _put_fish_down(fish: Dictionary, at: Vector2) -> void:
	var dropped: DroppedFish = DROPPED_FISH_SCENE.instantiate()
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = at
	dropped.setup(fish)


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
	poison_timer = maxf(poison_timer - delta, 0.0)
	vigor_timer = maxf(vigor_timer - delta, 0.0)
	ward_timer = maxf(ward_timer - delta, 0.0)
	binoculars_cooldown = maxf(binoculars_cooldown - delta, 0.0)
	if _knock_time > 0.0:
		# Staggering back, free.
		_knock_time = maxf(_knock_time - delta, 0.0)
		velocity = _knock_dir * KNOCK_SPEED * (_knock_time / KNOCK_TIME)
		move_and_slide()
		return
	if held:
		velocity = Vector2.ZERO
		if struggling:
			# Seconds to get loose: the light, a fish thrown, the heart.
			_update_aim()
			_update_lure_throw(get_physics_process_delta_time())
			if _key_just_pressed(KEY_H):
				use_heart_to_escape()
		return
	_update_aim()
	_update_movement()
	_update_noise()
	_update_fishing(delta)
	_handle_mode_toggle()
	_handle_shop_input()
	_handle_drop_input()
	_update_swing(delta)
	# Q swings the off hand's thing (a tap of the right stick on a phone).
	if _key_just_pressed(KEY_Q):
		swing()
	_update_lure_throw(get_physics_process_delta_time())
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
	elif _lure_charging and lure_aim != Vector2.ZERO:
		aim_dir = lure_aim.normalized()
	elif touch_aim != Vector2.ZERO:
		aim_dir = touch_aim
	elif skill_held and skill_aim != Vector2.ZERO:
		# The light skill being aimed (TouchControls).
		aim_dir = skill_aim
	elif _aim_joystick.is_pressed and _aim_joystick.output.length() > 0.15:
		# The right stick aims the cast (and the light with it).
		aim_dir = _aim_joystick.output.normalized()
	elif _mouse_aiming():
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			aim_dir = to_mouse.normalized()
	elif state == State.IDLE and velocity.length() > 5.0:
		# User request: left alone, the light points the way you walk.
		aim_dir = velocity.normalized()
	_update_light_skill()
	facing_indicator.position = aim_dir * 18.0 - Vector2(3.0, 3.0)


## User request: the light is a skill, Brawl Stars' super as the model -
## its own button (TouchControls) next to the right stick, which fishes.
## Drag the button to aim the light (left alone it follows your walk), hold
## it to charge the light up - brighter, further, a longer stun - and let
## go: a ghost in the light is flashed. A quick tap flashes the nearest
## ghost close by for a short stun - for when one's about to grab you.
## (Desktop: hold the right mouse button to aim; F flashes.)
const AIM_TAP_TIME := 0.22
const LIGHT_CHARGE_TIME := 1.2
## A tap only reaches a ghost this close, and holds it this much less long.
const TAP_FLASH_REACH := 90.0
const TAP_STUN_SCALE := 0.6
## Set by TouchControls while the light button is held / dragged.
var skill_held := false
var skill_aim := Vector2.ZERO
var skill_dragged := false
var _was_aiming := false
var _aim_time := 0.0


func _mouse_aiming() -> bool:
	return not DisplayServer.is_touchscreen_available() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _update_light_skill() -> void:
	var aiming: bool = skill_held or _mouse_aiming()
	var lantern: Lantern = get_node("Lantern")
	if aiming:
		_aim_time = 0.0 if not _was_aiming else _aim_time + get_physics_process_delta_time()
		# User request: held on, the light charges up - brighter and brighter.
		lantern.boost = clampf((_aim_time - AIM_TAP_TIME) / LIGHT_CHARGE_TIME, 0.0, 1.0) if lantern.lit else 0.0
	elif _was_aiming and (not held or struggling):
		if _aim_time < AIM_TAP_TIME and not skill_dragged:
			_tap_flash(lantern)
		else:
			lantern.release_flash()
		skill_aim = Vector2.ZERO
		skill_dragged = false
	_was_aiming = aiming


## A quick tap: the nearest ghost close by, if any, gets a short flash.
func _tap_flash(lantern: Lantern) -> void:
	lantern.boost = 0.0
	var ghost := lantern.nearest_ghost()
	if ghost == null or ghost.global_position.distance_to(global_position) > TAP_FLASH_REACH:
		GameState.push_message("身邊沒有鬼")
		return
	aim_dir = (ghost.global_position - global_position).normalized()
	lantern.release_flash(TAP_STUN_SCALE)


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
	if poison_timer > 0.0:
		affliction_ratio *= POISON_SPEED_MULT
	var drum_ratio: float = OIL_DRUM_SPEED_MULT if carrying_oil_drum else 1.0
	$CarriedCan.visible = carrying_oil_drum
	# Low spirit: heavier on their feet (Profile.SPIRIT_SPEED).
	var spirit_ratio: float = Profile.SPIRIT_SPEED[Profile.spirit_penalty()]
	var vigor_ratio: float = VIGOR_SPEED if vigor_timer > 0.0 else 1.0
	velocity = input_dir * SPEED * carry_ratio * affliction_ratio * drum_ratio * spirit_ratio * vigor_ratio
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


## User request: the right stick fishes (Brawl Stars' attack stick as the
## model): a finger on it is the fishing action held - so it casts, strikes
## and reels - its direction aims the cast (and answers a fish's sideways
## run) and, while casting, how far it's pulled sets how far the cast goes
## (the landing mark shows where). A tap casts ahead at CAST_TAP_RATIO -
## or, with the off hand's thing held (user request), swings it (SWING_TAP);
## held still, the cast goes out at CAST_TAP_RATIO. Space on a keyboard
## (held to charge).
const CAST_TAP_RATIO := 0.55
## User request: the cast charges 40% slower than it used to (full charge
## took MAX_CHARGE_TIME seconds) so it's easier to stop where you want.
## The stick's pull sets where the charge is heading; it gets there at this
## pace (and backs off twice as fast).
const CHARGE_RATE := 0.6
var _cast_dragged := false
var _cast_by_stick := false

## User request: a perfect strike - right as the float goes under, the
## first part of the bite window (this share of it, within these bounds)
## - starts the fight with the fish already worn (FishFight.perfect_hook).
const PERFECT_HOOK_SHARE := 0.45
const PERFECT_HOOK_TIME := Vector2(0.2, 0.35)
## User request: shine the light on the float and fish come to it. Hold
## the light button aimed at the float (charging the light - the lamp
## already points at the float after a cast, so it's the focused beam that
## lures): the wait for a bite runs up to LIGHT_LURE_MULT times as fast
## with the charge. Letting go with no ghost in the light flashes nothing.
## But the light on the water can draw the water ghost up too, for someone
## standing at the edge (a chance per second, at most once a cast).
const LIGHT_LURE_MULT := 2.2
const LIGHT_LURE_GHOST_CHANCE := 0.04
## How strongly the light is luring (0 = not): the charge, on the float.
var light_lure := 0.0
var _lured_this_cast := false
var _lure_ghost_came := false


func _cast_stick_touched() -> bool:
	return _aim_joystick._touch_index != -1


func _is_action_pressed() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or _cast_stick_touched()


## User request: the action button only fishes. Everything else - offering
## fish at the altar, refuelling, the oil drum, picking a dropped fish back
## up, catching a critter for bait, turning a rock, escaping - is offered
## by a button at the thing itself whenever it can be done (ActionPrompt,
## from interaction() below), held or tapped like before; E on a keyboard.
func interaction() -> Dictionary:
	if held or state != State.IDLE or GameState.run_over:
		return {}
	if in_altar_zone and not GameState.carried_fish.is_empty():
		return _offer(get_parent().get_node("Altar"), "祭壇", "獻祭", false, -34.0)
	if in_escape_zone and GameState.day_phase == GameState.DayPhase.ESCAPE:
		return _offer(get_parent().get_node("EscapePoint"), "符文石柱", "逃離", false, -30.0)
	var item := _nearest_dropped_item()
	if item != null:
		return _offer(item, item.title(), "撿起", false, -22.0)
	if in_fuel_zone and _fuel_station != null:
		var station := "營地油桶 %d/%d" % [int(_fuel_station.total_fuel), int(_fuel_station.max_total_fuel)]
		if carrying_oil_drum:
			return _offer(_fuel_station, station, "補充站點", false, -42.0)
		var lantern: Lantern = get_node("Lantern")
		if _fuel_station.total_fuel > 0.0 and lantern.fuel < lantern.max_fuel - 0.5:
			return _offer(_fuel_station, station, "補充", false, -42.0)
	if in_oil_drum_zone and _oil_drum != null and not carrying_oil_drum:
		return _offer(_oil_drum, "油箱", "提起", false, -30.0)
	if in_dropped_fish_zone and is_instance_valid(_dropped_fish):
		return _offer(_dropped_fish, _dropped_fish.label.text, "撿回", false, -22.0)
	var critter := reachable_critter()
	if critter != null:
		return _offer(critter, critter.get_label(), "抓餌", false, -20.0)
	# User request: once the quota's met, Willow (before the altar) can be
	# talked to - it tells what offerings turned up.
	var willow := get_tree().get_first_node_in_group("willow") as Node2D
	if willow != null and willow.can_talk() and global_position.distance_to(willow.global_position) < TALK_RANGE:
		return _offer(willow, "Willow", "對話", false, -34.0)
	if in_rock_zone and _rock != null and _rock.active:
		return {"at": _rock.prompt_anchor(), "name": "石頭", "verb": "翻開", "hold": false}
	var tree := choppable_tree()
	if tree != null:
		return {"at": tree.global_position + Vector2(0, -30), "name": "樹", "verb": "砍樹", "hold": false}
	return {}


## User request (the hatchet and the machete): the nearest tree in reach
## that can be chopped, with a chopping weapon worn; null otherwise.
func choppable_tree() -> MapTree:
	if int(held_weapon().get("chop", 0)) <= 0:
		return null
	var best: MapTree = null
	var best_d := CHOP_REACH
	for t in get_tree().get_nodes_in_group("trees"):
		var tree := t as MapTree
		if tree == null or tree.chopped:
			continue
		var d := global_position.distance_to(tree.global_position)
		if d < best_d:
			best_d = d
			best = tree
	return best


const TALK_RANGE := 40.0


func _talk_to_willow() -> void:
	var box: DialogBox = null
	for c in get_parent().get_children():
		if c is DialogBox:
			box = c
	if box == null:
		return
	var lines := ["「祭品我都收下了。這次祭壇回應的供品有這些……」", ""]
	for o in GameState.offering_pool:
		var label: String = GameState._rarity_label(o.rarity)
		if o.is_evil:
			lines.append("・%s供品（價值 %d）——散發著不祥的氣息，是邪惡的" % [label, o.value])
		elif o.taken:
			lines.append("・%s供品（價值 %d）——已經被拿走了" % [label, o.value])
		else:
			lines.append("・%s供品（價值 %d）" % [label, o.value])
	if GameState.offering_pool.is_empty():
		lines.append("・（什麼都沒有）")
	lines.append("")
	lines.append("「去符文石柱吧，離開時會帶走其中一個不是邪惡的供品。」")
	box.say("Willow", "\n".join(lines))


func _offer(node: Node2D, title: String, verb: String, hold: bool, lift: float) -> Dictionary:
	return {"at": node.global_position + Vector2(0, lift), "name": title, "verb": verb, "hold": hold}


func _is_use_pressed() -> bool:
	return Input.is_key_pressed(KEY_E)


func _handle_interaction(delta: float) -> void:
	var use_held := _is_use_pressed()
	var use_pressed := use_held and not _prev_use_held
	_prev_use_held = use_held
	var offer := interaction()
	var verb: String = offer.get("verb", "")
	if verb != "獻祭" and sacrifice_progress > 0.0:
		sacrifice_progress = 0.0
		sacrifice_progress_updated.emit(0.0)
	match verb:
		"獻祭":
			# User request: a tap opens the bag to pick the fish to offer.
			if use_pressed:
				var bag := backpack()
				if bag != null:
					bag.open_mode("sacrifice")
		"撿起":
			if use_pressed:
				_pick_up_item(_nearest_dropped_item())
		"翻開":
			if use_pressed:
				_turn_rock()
		"砍樹":
			if use_pressed:
				swing("chop")
		"逃離":
			if use_pressed:
				GameState.escape()
		"補充站點":
			if use_pressed:
				_deliver_oil_drum()
		"補充":
			if use_pressed:
				var lantern: Lantern = get_node("Lantern")
				if _fuel_station.try_refuel(lantern):
					Campaign.stat("refuel")
					GameState.push_message("煤油加滿了！（營地油桶剩 %d/%d）" % [int(_fuel_station.total_fuel), int(_fuel_station.max_total_fuel)])
		"提起":
			if use_pressed:
				_oil_drum.pick_up()
				_carried_oil_drum = _oil_drum
				carrying_oil_drum = true
				in_oil_drum_zone = false
				_oil_drum = null
				Campaign.stat("oil_pickup")
				GameState.push_message("提起了油箱，送回營地吧（提著沒辦法釣魚）")
		"撿回":
			if use_pressed:
				_pick_up_dropped_fish()
		"抓餌":
			if use_pressed and not (net_in_hand() and swing("scoop")):
				_catch_critter()
		"對話":
			if use_pressed:
				Campaign.stat("willow_talk")
				_talk_to_willow()


func _handle_action_input(delta: float) -> void:
	var held := _is_action_pressed()
	var just_pressed := held and not _prev_action_held
	var just_released := (not held) and _prev_action_held

	_handle_interaction(delta)

	match state:
		State.IDLE:
			if swing_left > 0.0:
				pass
			elif _stick_press >= 0.0:
				# A press on the stick with the off hand held: a tap swings it,
				# held on (or dragged) it's the rod - a cast.
				_stick_press += delta
				var dragged: bool = _aim_joystick.is_pressed and _aim_joystick.output.length() > SWING_DRAG
				if not held:
					_stick_press = -1.0
					swing()
				elif dragged or _stick_press > SWING_TAP:
					_stick_press = -1.0
					_try_start_charge()
			elif just_pressed and _cast_stick_touched() and offhand_in_hand():
				_stick_press = 0.0
			elif just_pressed:
				_try_start_charge()
		State.CHARGING:
			if held and _cast_stick_touched():
				# Pulled this far: heading this far out.
				_cast_by_stick = true
				if _aim_joystick.is_pressed:
					_cast_dragged = true
				var pull: float = _aim_joystick.output.length() if _aim_joystick.is_pressed else CAST_TAP_RATIO
				var target := clampf(pull, 0.0, 1.0) * MAX_CHARGE_TIME
				var rate := CHARGE_RATE * (1.0 if target > charge_time else 2.0)
				charge_time = move_toward(charge_time, target, rate * delta)
			elif held:
				charge_time = min(charge_time + delta * CHARGE_RATE, MAX_CHARGE_TIME)
			elif just_released:
				if _cast_by_stick and not _cast_dragged:
					# A tap: out ahead at the usual distance.
					charge_time = CAST_TAP_RATIO * MAX_CHARGE_TIME
				_launch_cast()
		State.BITE:
			if just_pressed:
				_hook_fish(perfect_hook_left() > 0.0)
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


## Pressed to fish: the cast starts charging - if it can.
func _try_start_charge() -> void:
	if carrying_oil_drum:
		GameState.push_message("提著油箱沒辦法釣魚，先送回營地")
	elif _nearest_water_edge_distance() > CAST_SHORE_RANGE:
		GameState.push_message("離水邊太遠了，走近岸邊再拋竿")
		GameState.report("離水邊太遠，靠近再拋竿", "info")
	elif _can_start_cast():
		_set_state(State.CHARGING)
		charge_time = 0.0
		_cast_dragged = false
		_cast_by_stick = _cast_stick_touched()
	else:
		var out_of := "餌" if fishing_mode == FishingMode.BOBBER else "假餌"
		GameState.push_message("沒有%s了，按 Tab 換釣法" % out_of)
		GameState.report("沒有%s了" % out_of)


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
	if not Inventory.fits_with(self, [Inventory.fish_item(_dropped_fish.as_fish())]):
		GameState.push_message("背包滿了，放不下這條魚")
		return
	var fish: Dictionary = _dropped_fish.pick_up()
	_dropped_fish = null
	in_dropped_fish_zone = false
	GameState.add_carried_fish(fish)
	if fish.get("rotten", false):
		GameState.push_message("撿回了一份腐敗的%s（獻祭它可能引發異變）" % fish.get("name", "魚獲"))
	else:
		GameState.push_message("撿回了%s（新鮮度打折，價值 %.0f）" % [fish.get("name", "魚"), fish.value])


## The critter a catch would take: the one stood on, or with the net in
## hand the nearest within NET_REACH; null if none.
func reachable_critter() -> Critter:
	if in_critter_zone and _critter != null and is_instance_valid(_critter) and _critter.active:
		return _critter
	if not net_in_hand():
		return null
	var best: Critter = null
	var best_d := NET_REACH
	for c in get_tree().get_nodes_in_group("critters"):
		var critter := c as Critter
		if critter == null or not critter.active or not critter.visible:
			continue
		var d := global_position.distance_to(critter.global_position)
		if d < best_d:
			best = critter
			best_d = d
	return best


## Room in the bag for `count` more of live bait `key`: topping up its
## stacks, or a new cell.
func _room_for_live(key: String, count := 1) -> bool:
	var id := "live_" + key
	var room := 0
	for e in Profile.bag:
		if e.id == id:
			room += Items.stack_of(id) - int(e.count)
	if room >= count:
		return true
	return Inventory.fits_with(self, [{"kind": "live", "size": Items.size_of(id)}])


## Puts `count` of live bait `key` in the bag (round 8, user request: what's
## caught or found on the map is a real live bait); how many went in. Hooked
## at once if it's a float with no live bait on.
func pocket_live_bait(key: String, count := 1) -> int:
	var n := 0
	for i in count:
		if not _room_for_live(key):
			break
		n += Profile.bag_put("live_" + key, 1)
	if n > 0 and live_bait == "" and fishing_mode == FishingMode.BOBBER and state == State.IDLE:
		live_bait = key
	return n


## Catches the critter in reach (reachable_critter()) into the bag as a
## live bait - BLACK_SPIDER_BAIT of a black spider. One that bites or
## stings (Critter.venom(); halved with the net) may poison.
func _catch_critter() -> void:
	var critter := reachable_critter()
	if critter == null:
		return
	var key := critter.bait_key()
	if not _room_for_live(key):
		GameState.push_message("背包滿了，放不下%s" % critter.get_label())
		return
	var label: String = critter.get_label()
	var venom: float = critter.venom() * (NET_VENOM_MULT if net_in_hand() else 1.0)
	var stings: bool = critter.stings()
	var many := BLACK_SPIDER_BAIT if critter.species == "black_spider" else 1
	critter.catch()
	if critter == _critter:
		_critter = null
		in_critter_zone = false
	var got := pocket_live_bait(key, many)
	Campaign.stat("grab_bait")
	if critter.species == "black_spider":
		Campaign.stat("black_spider")
	var bait_name: String = Profile.LIVE_BAITS[key].name
	var how := "用網子撈到了" if net_in_hand() else "抓到了"
	if venom > 0.0 and randf() < venom:
		poison_timer = POISON_TIME
		Campaign.stat("poisoned")
		Sfx.play("swipe_hit", -8.0)
		var hurt := "螫了一下" if stings else "咬了一口"
		GameState.push_message("%s%s，卻被牠%s——中毒了，腳步變得好沉重！（%s +%d）" % [how, label, hurt, bait_name, got])
		GameState.report("被%s%s，中毒變慢" % [label, hurt.substr(0, 1)])
	else:
		GameState.push_message("%s%s，放進背包當活餌（%s +%d）" % [how, label, bait_name, got])


## Turning a rock over (was: rummaging a roadside pile) only sometimes
## turns up bait. User request: at once - no progress bar.
func _turn_rock() -> void:
	if _rock == null or not _rock.active:
		return
	var result: Dictionary = _rock.turn_over(global_position)
	Campaign.stat("flip_rock")
	if result.get("spider", false):
		Critter.spawn_black_spider(get_parent(), _rock.global_position + Vector2(0, -4), global_position)
		GameState.push_message("石頭底下爬出一隻黑蜘蛛！抓不抓？牠可能會咬人")
	var key: String = FOUND_BAIT.get(result.get("flavor", ""), "worm")
	if result.get("found", false) and not _room_for_live(key):
		GameState.push_message("石頭底下有%s，但背包滿了放不下" % Profile.LIVE_BAITS[key].name)
	elif result.get("found", false):
		pocket_live_bait(key)
		GameState.push_message("石頭底下有%s，放進背包當活餌！" % Profile.LIVE_BAITS[key].name)
	else:
		GameState.push_message("石頭底下什麼都沒有")


## Chops `tree` (once a run each): it shakes, and bait may drop out of it,
## or a black spider (Profile.WEAPONS chop: the hatchet finds more).
func _chop_tree(tree: MapTree) -> void:
	if tree == null:
		return
	var result: Dictionary = tree.chop(global_position, int(held_weapon().get("chop", 1)))
	Campaign.stat("chop_tree")
	if result.get("spider", false):
		Critter.spawn_black_spider(get_parent(), tree.global_position + Vector2(randf_range(-10, 10), 6), global_position)
		GameState.push_message("樹上掉下一隻黑蜘蛛！")
	elif result.get("found", false) and not _room_for_live(FOUND_BAIT.get(result.get("flavor", ""), "cricket")):
		GameState.push_message("樹上掉下了%s，但背包滿了放不下" % Profile.LIVE_BAITS[FOUND_BAIT.get(result.get("flavor", ""), "cricket")].name)
	elif result.get("found", false):
		var key: String = FOUND_BAIT.get(result.get("flavor", ""), "cricket")
		pocket_live_bait(key)
		GameState.push_message("樹上掉下了%s，放進背包當活餌！" % Profile.LIVE_BAITS[key].name)
	else:
		GameState.push_message("砍了幾下，什麼也沒掉下來")


## User request (the pistol): fires at `beast` as it starts a chase - it
## bolts - using a round from the bag. The shot carries: the big ghost
## comes to look (BigGhost.hear). False with no pistol worn or no rounds.
func shoot_at(beast: Node2D) -> bool:
	if not held_weapon().get("gun", false) or Profile.bag_take("ammo", 1) != 1:
		return false
	swing("shoot")
	_swing_landed = true
	Profile.wear_out("glock")
	Sfx.play_at("gunshot", global_position, -2.0, 0.03)
	Campaign.stat("gunshot")
	GameState.report("開槍嚇跑了%s（子彈剩 %d）" % [beast.get_label(), Profile.bag_count("ammo")])
	for ghost in get_tree().get_nodes_in_group("big_ghost"):
		ghost.hear(global_position)
	return true


func _deliver_oil_drum() -> void:
	var added: float = _fuel_station.add_fuel(OilDrum.FUEL_AMOUNT)
	if _carried_oil_drum != null:
		_carried_oil_drum.deliver()
	_carried_oil_drum = null
	carrying_oil_drum = false
	Campaign.stat("oil_delivered")
	if added > 0.0:
		GameState.push_message("把油箱倒進營地的油桶了！補充了 %d 燃油" % int(added))
	else:
		GameState.push_message("營地的油桶已經是滿的，油箱白提了一趟")


func _update_fishing(delta: float) -> void:
	if state in [State.WAITING, State.BITE, State.REELING] \
			and _nearest_water_edge_distance() > REEL_IN_SHORE_RANGE:
		_fail_catch("walked_off")
		return
	match state:
		State.WAITING:
			if fishing_mode == FishingMode.BOBBER:
				# Design doc §4.2: bobber waits passively for a bite.
				_update_light_lure(delta)
				wait_timer -= delta * (1.0 + (LIGHT_LURE_MULT - 1.0) * light_lure)
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
						GameState.report("有魚在碰餌…先別拉", "info")
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
				if cast_outcome != CastOutcome.TIMEOUT and retrieve_progress >= _lure_bite_at:
					# The strike, wherever along the retrieve it comes.
					_start_bite()
				elif retrieve_progress >= 1.0 or exited_rare_zone:
					retrieve_progress = minf(retrieve_progress, 1.0)
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
			_update_crank(delta)
			var moving := velocity.length() > 1.0
			var reel_mult := MOVE_REEL_PENALTY if moving and fight.run_side == Vector2.ZERO else 1.0
			var line_dir := (cast_target - global_position).normalized()
			fight.strain = VIGOR_STRAIN if vigor_timer > 0.0 else 1.0
			fight.hold = _is_action_pressed()
			for ev in fight.update(delta, crank, _counter_dir(), line_dir, reel_mult):
				_on_fight_event(ev)
			progress = fight.progress
			tension = fight.tension
			fish_run_active_time = fight.run_left
			_follow_line(line_dir)
			if _snap_at >= 0.0 and progress >= _snap_at and fight.result == "":
				_snap_at = -1.0
				GameState.push_message("精神恍惚，手一抖——線斷了")
				_fail_catch("line_break")
				return
			match fight.result:
				"landed":
					_succeed_catch()
				"line_break", "line_out":
					if fight.result == "line_out":
						_snap_note = "out"
					elif fight.snap_why != "":
						_snap_note = fight.snap_why
					_fail_catch("line_break")
				"shook_off", "cover":
					if fight.snap_why == "slack":
						_snap_note = "slack"
					_fail_catch(fight.result)
		_:
			pass


## The crank this frame (see CRANK_FULL): the right stick's turning, else
## Space.
func _update_crank(delta: float) -> void:
	var want := 0.0
	var stick: Vector2 = _aim_joystick.output if _aim_joystick.is_pressed else Vector2.ZERO
	if stick.length() >= CRANK_REACH:
		var a := stick.angle()
		if _crank_had and delta > 0.0:
			var turns := absf(angle_difference(_crank_angle, a)) / TAU / delta
			want = clampf(turns / CRANK_FULL, 0.0, 1.0)
		_crank_angle = a
		_crank_had = true
	else:
		_crank_had = false
		if Input.is_key_pressed(KEY_SPACE):
			want = 1.0 if Input.is_key_pressed(KEY_SHIFT) else FishFight.CRANK_NORMAL
			# Struck: Space held is the stick held - it holds the line
			# through the fish's first pull (Shift cranks).
			if fight != null and fight.opening_left > 0.0 and not Input.is_key_pressed(KEY_SHIFT):
				want = 0.0
	crank = lerpf(crank, want, 1.0 - exp(-CRANK_EASE * delta)) if want < crank else want
	if crank < 0.01:
		crank = 0.0


## The reel turning (a fish on: the crank; else the action held - a lure
## retrieved).
func is_cranking() -> bool:
	if state == State.REELING:
		return crank >= FishFight.HELD_AT
	return _is_action_pressed()


## The fish out where the line says it is (FishFight.distance), along the
## line - while that's still in the water it was hooked in.
func _follow_line(line_dir: Vector2) -> void:
	if line_dir == Vector2.ZERO:
		return
	var at := global_position + line_dir * fight.distance * PX_PER_M
	if cast_water_zone == null or cast_water_zone.contains(at):
		cast_target = at


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
		use_bait_for_cast()
	# User request: the rod wears with each cast (Profile.wear_out).
	Profile.wear_out(str(Profile.equipped.get("rod", "")))

	var ratio: float = charge_time / MAX_CHARGE_TIME
	if cast_jittered or water_ghost_timer > 0.0:
		ratio = clamp(ratio * randf_range(0.3, 1.4), 0.0, 1.0)
		cast_jittered = false
		GameState.push_message("蓄力被干擾了，拋竿距離變得不可靠")
		GameState.report("被干擾，拋竿失準")
	cast_target = landing_point(ratio)

	# Design doc request: a cast that doesn't land in any water zone just
	# comes up empty - fishing only works where there's actually water now.
	cast_water_zone = _find_water_zone(cast_target)
	if cast_water_zone == null:
		GameState.push_message("這個方向沒有水，這竿撲空了")
		GameState.report("這方向沒有水", "info")
		_reset_line(State.IDLE)
		return

	# Design doc request: a cast can call up a water ghost - see
	# _maybe_trigger_water_ghost() for when.
	_maybe_trigger_water_ghost()

	current_tier = FishData.tier_for_ratio(ratio)
	tier_data = FishData.get_tier_data(current_tier)
	wait_timer = randf_range(tier_data.wait_min, tier_data.wait_max)
	# User feedback: worm bait bites faster - trims the wait down.
	if pending_bait_flavor == BAIT_FLAVOR_WORM:
		wait_timer *= 0.7
	wait_timer *= float(lure_def().get("wait", 1.0))
	_wait_duration = wait_timer
	retrieve_progress = 0.0
	light_lure = 0.0
	_lured_this_cast = false
	_lure_ghost_came = false
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
	if flavor == BAIT_FLAVOR_BUG or flavor == BAIT_FLAVOR_SPIDER:
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
	if flavor == BAIT_FLAVOR_FROG or flavor == BAIT_FLAVOR_LIVE_FROG:
		rare_chance *= 2.0
	rare_chance *= float(lure.get("rare", 1.0))

	if caught_in_hotspot:
		var heart_chance := HOTSPOT_HEART_CHANCE_NIGHT if GameState.is_night else HOTSPOT_HEART_CHANCE_DAY
		heart_chance *= float(Campaign.rules.heart)
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

	# User feedback: named species (FishData.FISH) replace the old
	# generic "稀有" + label - which zone type and rarity tier decide the
	# pool this cast draws from.
	tier_data = tier_data.duplicate()
	fish_id = ""
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
		fish_id = species.id
		tier_data.value = tier_data.value * float(species.value_mult)
		fish_trait = species.trait
		current_fish_color = species.color
		difficulty_key = FishData.difficulty_for(rarity_key, fish_trait)
		fish_habit = species.habit

	# How long you get to strike: the difficulty's window, a little longer
	# close in and shorter far out (the cast tier's own window, 0.7 = mid).
	var diff: Dictionary = FishData.DIFFICULTY[difficulty_key]
	# A better rod (Profile.ROD_TIERS) gives a little longer.
	tier_data.bite_window = clampf(diff.window * tier_data.bite_window / 0.7 * float(Profile.rod().window), 0.3, 1.5)
	nibbles_left = maxi(randi_range(diff.nibbles.x, diff.nibbles.y) - int(lure.get("nibbles", 0)), 0)
	fake_chance = diff.fake * float(lure.get("fake", 1.0))
	if flavor == BAIT_FLAVOR_SPIDER:
		fake_chance *= 0.5
	# Low spirit (Profile.spirit_penalty): less time to strike, and the
	# float fools you more.
	var worn := Profile.spirit_penalty()
	tier_data.bite_window *= Profile.SPIRIT_WINDOW[worn]
	nibbles_left += Profile.SPIRIT_NIBBLES[worn]
	fake_chance = minf(fake_chance + Profile.SPIRIT_FAKE[worn], 0.9)
	_nibbled = false
	_lure_bite_at = randf_range(LURE_BITE_RANGE.x, LURE_BITE_RANGE.y)
	_lure_nibbles.clear()
	for _i in nibbles_left:
		# The tells come before the strike.
		_lure_nibbles.append(randf_range(0.05, maxf(_lure_bite_at - 0.04, 0.06)))
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
	GameState.report("咬鉤了！快揚竿", "good")
	if is_heart_catch:
		GameState.push_message("水花特別亮、震動特別強...是心臟！")
	# (User request: what's on isn't said - it's read from the line once
	# struck, FishFight.open().)


## How long the perfect strike lasts on this bite.
func perfect_hook_window() -> float:
	var window: float = tier_data.get("bite_window", 1.0)
	return minf(clampf(window * PERFECT_HOOK_SHARE, PERFECT_HOOK_TIME.x, PERFECT_HOOK_TIME.y), window * 0.7)


## Time left for a perfect strike (0 once it's passed, or not biting).
func perfect_hook_left() -> float:
	if state != State.BITE:
		return 0.0
	var window: float = tier_data.get("bite_window", 1.0)
	return maxf(perfect_hook_window() - (window - bite_timer), 0.0)


## Is a charged light on the float? (bobber fishing, waiting for a bite)
func _update_light_lure(delta: float) -> void:
	var lantern: Lantern = get_node("Lantern")
	var on_float := lantern.lit and lantern.illuminates(cast_target)
	light_lure = lantern.boost if on_float else 0.0
	if light_lure <= 0.0:
		return
	if not _lured_this_cast:
		_lured_this_cast = true
		GameState.push_message("燈光照在浮標上，魚被吸引過來了…水裡好像也有東西在看")
	if not _lure_ghost_came and water_ghost_timer <= 0.0 \
			and _nearest_water_edge_distance() <= WATER_GHOST_RANGE \
			and randf() < LIGHT_LURE_GHOST_CHANCE * light_lure * delta:
		_lure_ghost_came = true
		_apply_water_ghost_attack("水面的燈光把水鬼引來了！")


## Worn right out (spirit under 30), now and then the hand slips mid-fight
## and the line snaps: where in the fight (progress), or -1.
const SPENT_SNAP_CHANCE := 0.15
var _snap_at := -1.0


func _hook_fish(perfect := false) -> void:
	fight = FishFight.new(difficulty_key, fish_habit, tier_data, reel_power_mult, Profile.rod())
	_snap_at = randf_range(0.3, 0.8) if Profile.spirit_penalty() >= 3 and randf() < SPENT_SNAP_CHANCE else -1.0
	fight.open(fish_heft())
	if perfect:
		fight.perfect_hook()
	# The line out to the fish, all there is on the reel, and how hard this
	# one pulls it away.
	fight.line_max = LINE_BASE + LINE_PER_TIER * Profile.rod_tier
	fight.distance = clampf(global_position.distance_to(cast_target) / PX_PER_M, FishFight.MIN_DISTANCE, fight.line_max * 0.6)
	fight.swim_out = swim_out_rate()
	crank = 0.0
	_crank_had = false
	_snap_note = ""
	progress = fight.progress
	tension = fight.tension
	fish_run_active_time = 0.0
	var hold := "按住右搖桿" if DisplayServer.is_touchscreen_available() else "按住空白鍵"
	if perfect:
		GameState.push_message("完美揚竿！魚掉了一截體力——先%s頂住，看張力再收線" % hold)
	else:
		GameState.push_message("上鉤了！先%s頂住，看張力再收線" % hold)
	_set_state(State.REELING)
	hook_success.emit()


## User request: how hard the fish on the line is to land, for the strike's
## opening (FishFight.open: 0 easy .. 1 the hardest) - its difficulty, its
## size, its rarity and its temper.
const HEFT_DIFFICULTY := {"novice": 0.0, "normal": 0.25, "advanced": 0.5, "master": 0.75}
const HEFT_SIZE := {"small": 0.0, "medium": 0.05, "large": 0.1, "huge": 0.15}
const HEFT_TRAIT := {"calm": -0.05, "normal": 0.0, "wild": 0.08}
const HEFT_RARE := 0.07
const HEFT_EPIC := 0.15


func fish_heft() -> float:
	var h: float = HEFT_DIFFICULTY.get(difficulty_key, 0.0)
	h += float(HEFT_SIZE.get(Inventory.size_for_catch(current_tier, is_epic_catch), 0.0))
	h += float(HEFT_TRAIT.get(fish_trait, 0.0))
	if is_epic_catch:
		h += HEFT_EPIC
	elif is_rare_catch:
		h += HEFT_RARE
	return clampf(h, 0.0, 1.0)


## How fast the fish on the line swims off with it (m/s, FishFight.swim_out):
## by how hard its kind fights, rarer, wilder and (off the far water)
## bigger ones faster.
func swim_out_rate() -> float:
	var pull: float = FishData.DIFFICULTY[difficulty_key].pull
	var rate := SWIM_OUT * pull * pull
	if is_epic_catch:
		rate *= SWIM_OUT_EPIC
	elif is_rare_catch:
		rate *= SWIM_OUT_RARE
	rate *= float(SWIM_OUT_TRAIT.get(fish_trait, 1.0))
	if current_tier == "far":
		rate *= SWIM_OUT_FAR
	return rate


## Which way the rod is being pulled, for answering a sideways run: the
## right stick, else the way you walk.
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
			GameState.push_message("魚往外衝！先停手放線，別讓線被拉光")
			GameState.report("魚往外衝，放線！", "info")
		"side_run":
			GameState.push_message("魚往%s邊衝！快把右搖桿往%s一甩" % [FishFight.describe(fight.run_side), FishFight.describe(-fight.run_side)])
		"swipe_hit":
			GameState.push_message("反甩成功！魚掉了一截體力")
		"swipe_miss":
			GameState.push_message("沒來得及反甩，往%s拉竿頂住！" % FishFight.describe(-fight.run_side))
		"jump":
			GameState.push_message("魚跳出水面！快停手！")
			GameState.report("魚跳起來了，停手！", "info")
		"dive":
			GameState.push_message("魚往岸邊石縫鑽！快轉右搖桿收線把牠拉回來！")
		"dive_saved":
			GameState.push_message("把魚從石縫邊拉回來了")
		"enrage":
			GameState.push_message("魚暴走了！先放線撐住！")
		"spent":
			GameState.push_message("魚沒力了！繼續轉右搖桿，把牠拉上岸")
			GameState.report("魚沒力了，收線拉上岸！", "info")
		"recover":
			GameState.push_message("停太久，魚緩過氣來了！")
	fight_event.emit(kind)


func _succeed_catch() -> void:
	if caught_in_hotspot:
		_hotspot.consume()

	if is_heart_catch:
		if GameState.has_heart or Inventory.fits_with(self, [{"kind": "heart", "size": Vector2i(1, 1)}]):
			GameState.grant_heart()
			catch_success.emit({"name": "心臟", "value": 0, "tier": current_tier})
			Profile.record_catch("心臟", 0.0)
		else:
			GameState.push_message("背包滿了，放不下心臟，眼睜睜看它沉回水裡...")
	else:
		var fish := {"name": tier_data.label, "id": fish_id, "value": tier_data.value, "tier": current_tier,
			"size": Inventory.size_for_catch(current_tier, is_epic_catch)}
		fish.merge(FishData.measure(fish_id, fish.size))
		fish.value = FishData.value_for_length(fish_id, float(fish.value), fish.length)
		fish["tank_trait"] = FishData.roll_tank_trait(fish_id)
		fish["rarity"] = "epic" if is_epic_catch else ("rare" if is_rare_catch else "common")
		# User request: the catch card calls out a first catch of a kind
		# (NEW), a trait not seen on it before, and a record size (BIGGER).
		var seen: Dictionary = Profile.fish_log.get(fish.name, {})
		fish["is_new"] = seen.is_empty()
		fish["new_trait"] = not seen.is_empty() and not fish.tank_trait in seen.get("traits", [])
		fish["bigger"] = not seen.is_empty() and fish.length > float(seen.get("longest", 0.0))
		catch_success.emit(fish)
		Profile.record_catch(fish.name, fish.value, fish.length, fish.tank_trait, UiKit.fish_rarity(fish) == "legend")
		if Inventory.fits_with(self, [Inventory.fish_item(fish)]):
			GameState.add_carried_fish(fish)
			GameState.push_message("釣到了 %s（%s型）！" % [tier_data.label, Inventory.SIZE_NAMES[fish.size]])
		else:
			# User request: a full backpack takes nothing more - it's left
			# at your feet.
			_put_fish_down(fish, global_position)
			GameState.push_message("釣到了 %s，但背包滿了，只好放在地上" % tier_data.label)

	_reset_line(State.IDLE)


## What a lost cast or fish says under the character card (user request),
## in a few words.
const FAIL_REPORTS := {
	"bait_nibbled": "餌被小魚偷吃了", "no_bite": "等了很久，沒魚咬餌", "missed_bite": "沒及時揚竿，魚跑了",
	"spooked": "太早揚竿，魚嚇跑了", "line_break": "線斷了，魚跑了", "shook_off": "魚甩掉了鉤",
	"cover": "魚鑽進石縫，線磨斷了", "walked_off": "離岸太遠，魚脫鉤了", "line_cut": "小鬼剪斷了釣線",
	"lure_knocked": "小鬼弄掉了假餌", "bait_stolen": "小鬼偷走了餌",
}


func _fail_catch(reason: String) -> void:
	catch_failed.emit(reason)
	var msg := "魚跑掉了"
	# A snapped or frayed line takes the lure with it.
	var lure_gone: bool = reason in ["line_break", "cover"] and fishing_mode == FishingMode.LURE
	if lure_gone:
		_lose_lure()
	if reason == "line_break":
		match _snap_note:
			"out":
				msg = "線被魚拉光了，斷了（魚越跑越遠時要轉右搖桿收線）"
			"far":
				msg = "魚跑得太遠，線撐不住斷了（距離變紅時要快收線）"
			"leap":
				msg = "魚在遠處跳出水面，線一下就斷了"
			"rush":
				msg = "刺魚後馬上收線，正好撞上魚猛拉，線斷了（先按住頂住，看張力再收）"
			_:
				msg = "線斷了，魚跑了"
		_snap_note = ""
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
	elif reason == "shook_off" and _snap_note == "slack":
		msg = "刺魚後放了手，線一鬆魚就脫鉤了（刺魚後要按住頂住）"
		_snap_note = ""
	elif reason == "shook_off":
		msg = "魚在空中甩掉了魚鉤（跳起來時要放手）"
	elif reason == "cover":
		msg = "魚鑽進石縫，線被磨斷了"
	elif reason == "walked_off":
		msg = "拉著魚走離岸邊太遠，魚脫鉤跑了" if state == State.REELING else "離岸邊太遠，自動收竿了"
	if lure_gone:
		msg += "，假餌也沒了"
	GameState.push_message(msg)
	if FAIL_REPORTS.has(reason):
		var short: String = FAIL_REPORTS[reason]
		if reason == "walked_off" and state != State.REELING:
			short = "離岸太遠，收竿了"
		GameState.report(short + ("，假餌沒了" if lure_gone else ""))
	_reset_line(State.IDLE)


func _cancel_cast(reason: String) -> void:
	catch_failed.emit(reason)
	_reset_line(State.IDLE)


func _reset_line(next_state: State) -> void:
	line_cleared.emit()
	_set_state(next_state)


func _set_state(new_state: State) -> void:
	state = new_state
	if new_state != State.WAITING:
		light_lure = 0.0
	state_changed.emit(State.keys()[state])
