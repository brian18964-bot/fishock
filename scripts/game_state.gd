extends Node

## Autoload singleton. Source of truth for the day's quota, the fish a
## player is carrying but hasn't sacrificed yet (design doc §5.4 / §6), and
## the escape/offering flow (§7, simplified to a single player: "vote" is
## just your own choice to leave or keep pushing for better offerings).

signal quota_updated(progress: float, target: float)
signal inventory_updated(carried: Array)
signal day_cleared()
signal message_posted(text: String)
signal day_phase_changed(phase: String)
signal offering_pool_updated(pool: Array, evil_count: int)
signal run_ended(success: bool, message: String)
signal night_fell()
signal light_stage_changed(stage: int)
signal weather_changed(weather: String)

enum DayPhase { FISHING, ESCAPE, DONE }
enum Weather { CLEAR, FOG, STORM, FISH_RUN }

const OFFERING_ADD_THRESHOLD := 15.0
const RARITY_EVIL_CHANCE := {"common": 0.1, "rare": 0.25, "epic": 0.45}
const RARITY_VALUE := {"common": 10, "rare": 25, "epic": 60}
const BASELINE_REWARD := 8
const MAX_EVIL := 3
const MAX_STARTING_EVIL := 2
## User request: a five-minute day.
const DAY_DURATION := 300.0
## User request: the day darkens in four stages (quarters of the day) - at
## first the lamp at its lowest setting is enough to see ahead; by the last
## you have to turn it right up. See light_stage(), DarknessController and
## Lantern.
const LIGHT_STAGES := 4
const LIGHT_STAGE_MESSAGES := [
	"",
	"天色暗了下來，燈光照得沒那麼遠了",
	"越來越暗了，把燈調亮一點吧（亮）",
	"快入夜了，燈要開到很亮才看得清楚",
]
var _light_stage := 0

## Design doc request: sacrificing a fully rotten fish doesn't add quota
## value - instead it gambles on one of three outcomes.
const ROTTEN_HOTSPOT_CHANCE := 0.5
const ROTTEN_FRENZY_CHANCE := 0.3
## remaining probability (1 - the two above) is the evil-offering outcome
const ROTTEN_FRENZY_DURATION := 12.0

## Design doc request: hitting quota shouldn't just be a reward moment -
## escaping should carry real risk too, and lingering for extra offerings
## should feel riskier than just leaving. Effectively "for the rest of the
## run" rather than a real countdown.
const ESCALATION_FRENZY_DURATION := 99999.0
const GHOST_SCENE := preload("res://scenes/ghost.tscn")
const GHOST_SPAWN_MARGIN := 200.0
const GHOST_SPAWN_MIN_PLAYER_DIST := 400.0

## User feedback: each run should feel different beat-to-beat, not just in
## its map layout - periodic weather that shifts visibility, ghost danger,
## and fishing odds. Weighted so CLEAR is still the most common state.
const WEATHER_MIN_DURATION := 40.0
const WEATHER_MAX_DURATION := 75.0
const WEATHER_FOG_WEIGHT := 0.2
const WEATHER_STORM_WEIGHT := 0.2
const WEATHER_FISH_RUN_WEIGHT := 0.2

var quota_target: float = 30.0
var quota_progress: float = 0.0
var carried_fish: Array = []
var day_over: bool = false

var day_phase: DayPhase = DayPhase.FISHING
var offering_pool: Array = []
var evil_count: int = 0
var run_over: bool = false
var _quota_since_offering: float = 0.0

var time_remaining: float = DAY_DURATION
var is_night: bool = false

var _extra_ghosts: Array = []

var weather: int = Weather.CLEAR
var weather_timer: float = 0.0

## Gates the day timer so it only runs once the player has actually
## pressed "Start" on the title screen - otherwise browsing the shop
## would silently burn down the clock before the run even begins.
var run_started: bool = false
## How the last run ended, for the camp to show it coming home (user
## request, Camp v2): "escaped" (out of the 渡石) or "lost" (waking by the
## fire); "" once shown.
var last_return := ""

## Design doc §5.3: hotspot-only pickup. Solo use is a single automatic
## save from a night catch; multiplayer altar revival doesn't apply here.
var has_heart: bool = false

## User request: the floating ghosts only now and then get in the way - at
## least GHOST_INTERFERENCE_GAP s apart and GHOST_INTERFERENCE_MAX times a
## run between all of them; the rest of the time they drift about the map.
const GHOST_INTERFERENCE_GAP := 20.0
const GHOST_INTERFERENCE_MAX := 4
var ghost_interferences: int = 0
var _ghost_quiet: float = 0.0
## The one ghost currently on its way to the player, if any.
var ghost_haunter: Node = null


func ghost_may_interfere() -> bool:
	return run_started and not run_over and ghost_interferences < GHOST_INTERFERENCE_MAX \
		and _ghost_quiet >= GHOST_INTERFERENCE_GAP


func ghost_interfered() -> void:
	ghost_interferences += 1
	_ghost_quiet = 0.0


func _process(delta: float) -> void:
	if run_started and not run_over:
		_ghost_quiet += delta
	if not run_started or run_over or is_night or day_phase != DayPhase.FISHING:
		return
	time_remaining = max(time_remaining - delta, 0.0)
	var stage := light_stage()
	if stage != _light_stage:
		_light_stage = stage
		light_stage_changed.emit(stage)
		push_message(LIGHT_STAGE_MESSAGES[stage])
	if time_remaining <= 0.0:
		_trigger_night()

	weather_timer -= delta
	if weather_timer <= 0.0:
		_roll_weather()


## 0 at the start of the day ... LIGHT_STAGES - 1 in its last quarter (and
## through the night).
func light_stage() -> int:
	if is_night:
		return LIGHT_STAGES - 1
	return clampi(int((1.0 - time_remaining / DAY_DURATION) * LIGHT_STAGES), 0, LIGHT_STAGES - 1)


func start_run() -> void:
	run_started = true


func add_carried_fish(fish: Dictionary) -> void:
	if not fish.has("uid"):
		fish["uid"] = _next_uid
		_next_uid += 1
	carried_fish.append(fish)
	inventory_updated.emit(carried_fish)


## User request (誘惑): the fish picked to be thrown as a lure, by its uid;
## -1 when none (or once it's gone - sacrificed, dropped, taken).
var lure_uid := -1
var _next_uid := 1


func lure_index() -> int:
	if lure_uid < 0:
		return -1
	for i in carried_fish.size():
		if int(carried_fish[i].get("uid", -2)) == lure_uid:
			return i
	lure_uid = -1
	return -1


func set_lure(index: int) -> void:
	lure_uid = int(carried_fish[index].get("uid", -1)) if index >= 0 and index < carried_fish.size() else -1


func drop_carried_at(index: int) -> Dictionary:
	if index < 0 or index >= carried_fish.size():
		return {}
	var fish: Dictionary = carried_fish[index]
	carried_fish.remove_at(index)
	inventory_updated.emit(carried_fish)
	return fish


func drop_one_carried() -> Dictionary:
	if carried_fish.is_empty():
		return {}
	var fish: Dictionary = carried_fish.pop_back()
	inventory_updated.emit(carried_fish)
	return fish


## Design doc request: sacrificing is per-fish (one small progress bar
## each), not an instant bulk dump - see Player._handle_sacrifice().
func sacrifice_one() -> Dictionary:
	return sacrifice_at(0)


## User request: at the altar the player picks which fish to offer from
## the bag (Backpack's offering mode) - these, highest index first.
func sacrifice_many(indices: Array) -> Array:
	var order := indices.duplicate()
	order.sort()
	order.reverse()
	var out := []
	for i in order:
		var fish := sacrifice_at(int(i))
		if not fish.is_empty():
			out.append(fish)
	return out


func sacrifice_at(index: int) -> Dictionary:
	if index < 0 or index >= carried_fish.size():
		return {}
	var fish: Dictionary = carried_fish[index]
	carried_fish.remove_at(index)
	inventory_updated.emit(carried_fish)

	if fish.get("rotten", false):
		_trigger_rotten_sacrifice()
		return fish

	var value := float(fish.value)
	quota_progress += value
	quota_updated.emit(quota_progress, quota_target)

	if quota_progress >= quota_target and day_phase == DayPhase.FISHING:
		_enter_escape_phase()
	elif day_phase == DayPhase.ESCAPE:
		_quota_since_offering += value
		if _quota_since_offering >= OFFERING_ADD_THRESHOLD:
			_quota_since_offering -= OFFERING_ADD_THRESHOLD
			_add_offering(true)

	return fish


func drop_all_carried() -> int:
	if carried_fish.is_empty():
		return 0
	var count := carried_fish.size()
	carried_fish.clear()
	inventory_updated.emit(carried_fish)
	return count


func steal_one_carried() -> Dictionary:
	if carried_fish.is_empty():
		return {}
	var idx := randi() % carried_fish.size()
	var fish: Dictionary = carried_fish[idx]
	carried_fish.remove_at(idx)
	inventory_updated.emit(carried_fish)
	return fish


func escape() -> void:
	if day_phase != DayPhase.ESCAPE:
		return

	var safe_offerings: Array = offering_pool.filter(func(o): return not o.is_evil and not o.taken)
	var message: String
	if safe_offerings.is_empty():
		message = "成功逃離！供品池已空，領取保底獎勵（價值 %d）" % BASELINE_REWARD
	else:
		var picked: Dictionary = safe_offerings[randi() % safe_offerings.size()]
		picked.taken = true
		message = "成功逃離！拿到了一個%s供品（價值 %d）" % [_rarity_label(picked.rarity), picked.value]
		offering_pool_updated.emit(offering_pool, evil_count)

	end_run(true, message)


func reset_run() -> void:
	last_cause = ""
	quota_progress = 0.0
	carried_fish.clear()
	lure_uid = -1
	day_over = false
	day_phase = DayPhase.FISHING
	offering_pool.clear()
	evil_count = 0
	run_over = false
	_quota_since_offering = 0.0
	time_remaining = DAY_DURATION
	_light_stage = 0
	is_night = false
	run_started = false
	has_heart = false
	ghost_interferences = 0
	_ghost_quiet = 0.0
	ghost_haunter = null
	weather = Weather.CLEAR
	weather_timer = randf_range(WEATHER_MIN_DURATION, WEATHER_MAX_DURATION)
	weather_changed.emit("CLEAR")
	for ghost in _extra_ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_extra_ghosts.clear()
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		ghost.frenzy_timer = 0.0
	inventory_updated.emit(carried_fish)
	quota_updated.emit(quota_progress, quota_target)
	day_phase_changed.emit("FISHING")
	offering_pool_updated.emit(offering_pool, evil_count)
	push_message("重新開始新的一輪")


## Single place every ending path (escape, evil wipe, night catch) funnels
## through, so `run_over` only ever flips once and run_ended only fires once.
func end_run(success: bool, message: String) -> void:
	if run_over:
		return
	run_over = true
	day_phase = DayPhase.DONE
	day_phase_changed.emit("DONE")

	var final_message := message
	last_return = "escaped" if success else "lost"
	if last_cause != "caught":
		last_cause = "escaped" if success else "lost"
	if success:
		final_message += _bring_fish_home()
		# User request (Camp v2): an escape counts toward the tents and
		# lifts the spirit.
		Profile.record_escape()
		Profile.add_spirit(10.0)
	else:
		# Design doc §8: on failure, carried fish are lost outright, never sold;
		# user request: so is gear found on the map - what was brought stays.
		carried_fish.clear()
		inventory_updated.emit(carried_fish)
		Profile.lose_found_gear()

	run_ended.emit(success, final_message)


## User request (fish tank): the fish carried out of a run go into the
## fish tank at home (Profile.tank), to be looked at, sold or traded there;
## rotten ones are thrown away, and any the tank has no room for are sold.
## What to tell the player.
func _bring_fish_home() -> String:
	var kept := []
	var sold := 0
	var rotten := 0
	for fish in carried_fish:
		if fish.get("rotten", false):
			rotten += 1
		elif Profile.add_to_tank(fish):
			kept.append(fish.get("name", "魚"))
		else:
			sold += maxi(1, int(fish.get("value", 0)))
	carried_fish.clear()
	inventory_updated.emit(carried_fish)
	if sold > 0:
		Profile.add_gold(sold)
	var text := ""
	if not kept.is_empty():
		text += "\n將 %s 放進魚缸" % "、".join(kept)
	if sold > 0:
		text += "\n魚缸滿了，其餘的漁獲賣了 %d 金幣" % sold
	if rotten > 0:
		text += "\n腐敗的魚丟掉了 %d 條" % rotten
	return text


## User feedback: periodic weather - mostly clear, but fog (dims/shrinks
## visibility), storms (ghosts more dangerous, water ghost more likely) and
## fish runs (better odds map-wide) each take a turn for a while.
func _roll_weather() -> void:
	var roll := randf()
	var new_weather := Weather.CLEAR
	if roll < WEATHER_FOG_WEIGHT:
		new_weather = Weather.FOG
	elif roll < WEATHER_FOG_WEIGHT + WEATHER_STORM_WEIGHT:
		new_weather = Weather.STORM
	elif roll < WEATHER_FOG_WEIGHT + WEATHER_STORM_WEIGHT + WEATHER_FISH_RUN_WEIGHT:
		new_weather = Weather.FISH_RUN

	weather = new_weather
	weather_timer = randf_range(WEATHER_MIN_DURATION, WEATHER_MAX_DURATION)
	weather_changed.emit(Weather.keys()[weather])

	match weather:
		Weather.FOG:
			push_message("起霧了，視野變差...")
		Weather.STORM:
			push_message("風雨變大，水鬼變得更加活躍！")
		Weather.FISH_RUN:
			push_message("魚汛來了！這段時間更容易釣到魚")
		Weather.CLEAR:
			push_message("天氣恢復平靜")


func _trigger_night() -> void:
	is_night = true
	night_fell.emit()
	push_message("時間到了，額度沒補滿...夜晚降臨，鬼進入獵殺模式！")


func grant_heart() -> void:
	has_heart = true
	push_message("拿到心臟了！關鍵時刻能救你一命")


## User request (Camp v2): not free of the big ghost's grip in time - the
## run is lost and the traveller wakes back at the camp, shaken.
const CAUGHT_SPIRIT := 25.0
## Why the last run ended ("caught": taken by the big ghost), for the end
## screen.
var last_cause := ""


func caught() -> void:
	if run_over:
		return
	last_cause = "caught"
	Profile.add_spirit(-CAUGHT_SPIRIT)
	end_run(false, "被大鬼抓走了……眼前一黑。\n醒來時已經躺在營火邊，精神 -%d" % int(CAUGHT_SPIRIT))


func use_heart() -> bool:
	if not has_heart:
		return false
	has_heart = false
	return true


func push_message(text: String) -> void:
	message_posted.emit(text)


func _enter_escape_phase() -> void:
	day_over = true
	day_phase = DayPhase.ESCAPE
	day_phase_changed.emit("ESCAPE")
	day_cleared.emit()
	var count := randi_range(3, 5)
	for _i in range(count):
		_add_offering(false)
	_escalate_threat()
	push_message("額度已滿！鬼群警覺起來了 - 前往逃離點離開，或繼續釣魚賭更好的供品")


## Design doc request: meeting quota also raises the stakes of staying -
## another ghost joins the hunt and every ghost goes into a lasting
## frenzy, so escaping isn't a formality and farming more offerings is a
## real gamble, not a free lunch.
func _escalate_threat() -> void:
	_spawn_extra_ghost()
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		ghost.enter_frenzy(ESCALATION_FRENZY_DURATION)


func _spawn_extra_ghost() -> void:
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var ghost: Node2D = GHOST_SCENE.instantiate()
	var player: Node2D = main.get_node_or_null("Player")
	var pos := Vector2(
		randf_range(GHOST_SPAWN_MARGIN, Player.WORLD_WIDTH - GHOST_SPAWN_MARGIN),
		randf_range(GHOST_SPAWN_MARGIN, Player.WORLD_HEIGHT - GHOST_SPAWN_MARGIN)
	)
	if player:
		var tries := 0
		while pos.distance_to(player.global_position) < GHOST_SPAWN_MIN_PLAYER_DIST and tries < 10:
			pos = Vector2(
				randf_range(GHOST_SPAWN_MARGIN, Player.WORLD_WIDTH - GHOST_SPAWN_MARGIN),
				randf_range(GHOST_SPAWN_MARGIN, Player.WORLD_HEIGHT - GHOST_SPAWN_MARGIN)
			)
			tries += 1
	ghost.position = pos
	main.add_child(ghost)
	_extra_ghosts.append(ghost)


## Design doc request: a rotten fish sacrificed at the altar gambles on one
## of three outcomes instead of normal quota value - an exclusive hotspot,
## the ghosts turning more dangerous for a while, or a forced evil offering
## dropped straight into the pool.
func _trigger_rotten_sacrifice() -> void:
	var roll := randf()
	if roll < ROTTEN_HOTSPOT_CHANCE:
		var hotspot: Node = get_tree().current_scene.get_node_or_null("Hotspot")
		if hotspot:
			hotspot.force_relocate()
		push_message("腐敗供品引來了魚群，附近浮現一處限定漁場！")
	elif roll < ROTTEN_HOTSPOT_CHANCE + ROTTEN_FRENZY_CHANCE:
		for ghost in get_tree().get_nodes_in_group("ghosts"):
			ghost.enter_frenzy(ROTTEN_FRENZY_DURATION)
		push_message("腐敗供品讓鬼變得更加活躍、更快了...")
	else:
		_add_offering(false, true)
		push_message("腐敗供品召喚出了一份邪惡供品...")


func _add_offering(is_bonus: bool, force_evil: bool = false) -> void:
	var rarity := "common"
	if is_bonus:
		rarity = "epic" if randf() < 0.35 else "rare"
	elif randf() < 0.4:
		rarity = "rare"

	var evil_chance: float = RARITY_EVIL_CHANCE[rarity]
	var is_evil := force_evil or randf() < evil_chance
	if is_evil and not is_bonus and not force_evil and evil_count >= MAX_STARTING_EVIL:
		is_evil = false

	var offering := {"rarity": rarity, "is_evil": is_evil, "value": RARITY_VALUE[rarity], "taken": false}
	offering_pool.append(offering)
	if is_evil:
		evil_count += 1

	offering_pool_updated.emit(offering_pool, evil_count)

	if evil_count >= MAX_EVIL and not run_over:
		_fail_run()


func _fail_run() -> void:
	end_run(false, "邪惡供品累積到 3 個，你沒能逃出去，一無所獲")


func _rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史詩"
		_:
			return rarity
