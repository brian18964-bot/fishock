extends Node

## Autoload singleton. Source of truth for the day's quota and the fish a
## player is carrying but hasn't sacrificed yet (design doc §5.4 / §6).

signal quota_updated(progress: float, target: float)
signal inventory_updated(carried: Array)
signal day_cleared()
signal message_posted(text: String)

var quota_target: float = 30.0
var quota_progress: float = 0.0
var carried_fish: Array = []
var day_over: bool = false

func add_carried_fish(fish: Dictionary) -> void:
	carried_fish.append(fish)
	inventory_updated.emit(carried_fish)

func sacrifice_all() -> int:
	if carried_fish.is_empty():
		return 0
	var count := carried_fish.size()
	for fish in carried_fish:
		quota_progress += float(fish.value)
	carried_fish.clear()
	inventory_updated.emit(carried_fish)
	quota_updated.emit(quota_progress, quota_target)
	if quota_progress >= quota_target and not day_over:
		day_over = true
		day_cleared.emit()
		push_message("額度已滿！可以前往逃離點了（逃離流程尚未實作）")
	return count

func drop_all_carried() -> int:
	if carried_fish.is_empty():
		return 0
	var count := carried_fish.size()
	carried_fish.clear()
	inventory_updated.emit(carried_fish)
	return count

func push_message(text: String) -> void:
	message_posted.emit(text)
