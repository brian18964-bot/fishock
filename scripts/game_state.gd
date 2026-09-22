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

enum DayPhase { FISHING, ESCAPE, DONE }

const OFFERING_ADD_THRESHOLD := 15.0
const RARITY_EVIL_CHANCE := {"common": 0.1, "rare": 0.25, "epic": 0.45}
const RARITY_VALUE := {"common": 10, "rare": 25, "epic": 60}
const BASELINE_REWARD := 8
const MAX_EVIL := 3
const MAX_STARTING_EVIL := 2
const DAY_DURATION := 180.0

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

## Design doc §5.3: hotspot-only pickup. Solo use is a single automatic
## save from a night catch; multiplayer altar revival doesn't apply here.
var has_heart: bool = false


func _process(delta: float) -> void:
	if run_over or is_night or day_phase != DayPhase.FISHING:
		return
	time_remaining = max(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_trigger_night()


func add_carried_fish(fish: Dictionary) -> void:
	carried_fish.append(fish)
	inventory_updated.emit(carried_fish)


func sacrifice_all() -> int:
	if carried_fish.is_empty():
		return 0
	var count := carried_fish.size()
	var total_value := 0.0
	for fish in carried_fish:
		total_value += float(fish.value)
	carried_fish.clear()
	inventory_updated.emit(carried_fish)

	quota_progress += total_value
	quota_updated.emit(quota_progress, quota_target)

	if quota_progress >= quota_target and day_phase == DayPhase.FISHING:
		_enter_escape_phase()
	elif day_phase == DayPhase.ESCAPE:
		_quota_since_offering += total_value
		if _quota_since_offering >= OFFERING_ADD_THRESHOLD:
			_quota_since_offering -= OFFERING_ADD_THRESHOLD
			_add_offering(true)

	return count


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
	quota_progress = 0.0
	carried_fish.clear()
	day_over = false
	day_phase = DayPhase.FISHING
	offering_pool.clear()
	evil_count = 0
	run_over = false
	_quota_since_offering = 0.0
	time_remaining = DAY_DURATION
	is_night = false
	has_heart = false
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
	if success:
		var sold := _sell_carried_fish()
		if sold > 0:
			final_message += "\n順便賣掉身上剩下的漁獲，賺了 %d 金幣" % sold
	else:
		# Design doc §8: on failure, carried fish are lost outright, never sold.
		carried_fish.clear()
		inventory_updated.emit(carried_fish)

	run_ended.emit(success, final_message)


## Design doc §7/§9.1: excess catch you carried onto the "boat" (i.e. still
## on hand when you escape) becomes sellable, permanent gold.
func _sell_carried_fish() -> int:
	var total := 0
	for fish in carried_fish:
		total += int(fish.value)
	carried_fish.clear()
	inventory_updated.emit(carried_fish)
	if total > 0:
		Profile.add_gold(total)
	return total


func _trigger_night() -> void:
	is_night = true
	night_fell.emit()
	push_message("時間到了，額度沒補滿...夜晚降臨，鬼進入獵殺模式！")


func grant_heart() -> void:
	has_heart = true
	push_message("拿到心臟了！關鍵時刻能救你一命")


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
	push_message("額度已滿！前往逃離點離開，或繼續釣魚賭更好的供品")


func _add_offering(is_bonus: bool) -> void:
	var rarity := "common"
	if is_bonus:
		rarity = "epic" if randf() < 0.35 else "rare"
	elif randf() < 0.4:
		rarity = "rare"

	var evil_chance: float = RARITY_EVIL_CHANCE[rarity]
	var is_evil := randf() < evil_chance
	if is_evil and not is_bonus and evil_count >= MAX_STARTING_EVIL:
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
