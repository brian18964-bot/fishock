extends Node

## Autoload singleton. The account-level "個人關卡" progress line (design
## doc §9.1/§9.3) - persists across runs AND across sessions via a save
## file, unlike GameState which resets every run.
##
## There's no shop UI yet, so buying is done with debug-style key presses
## (see Player._handle_shop_input); the economics themselves are real.

signal gold_updated(gold: int)
signal profile_changed()

const SAVE_PATH := "user://profile.save"

const UPGRADE_DEFS := {
	"fuel_capacity": {"label": "提燈燃油容量", "max_level": 3, "costs": [20, 40, 70], "bonus": 20.0},
	"bait_capacity": {"label": "帶餌上限", "max_level": 3, "costs": [15, 30, 50], "bonus": 5.0},
	"flash_cooldown": {"label": "強光冷卻縮短", "max_level": 3, "costs": [20, 40, 70], "bonus": 0.5},
	"fuel_station_charges": {"label": "煤油站總量上限", "max_level": 3, "costs": [25, 45, 75], "bonus": 100.0},
}
const LURE_COST := 15

var gold: int = 0
var upgrade_levels: Dictionary = {
	"fuel_capacity": 0, "bait_capacity": 0, "flash_cooldown": 0, "fuel_station_charges": 0,
}

## Design doc §9.2: lures bought "賽前" (before the match) - queued here,
## then handed to the player and cleared the moment a run actually starts.
var loadout_lures: int = 0


func _ready() -> void:
	_load()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_updated.emit(gold)
	_save()


func get_upgrade_level(key: String) -> int:
	return upgrade_levels.get(key, 0)


func get_upgrade_bonus(key: String) -> float:
	var def: Dictionary = UPGRADE_DEFS[key]
	return get_upgrade_level(key) * float(def.bonus)


func buy_upgrade(key: String) -> bool:
	var def: Dictionary = UPGRADE_DEFS[key]
	var level: int = get_upgrade_level(key)
	if level >= int(def.max_level):
		return false
	var cost: int = def.costs[level]
	if gold < cost:
		return false
	gold -= cost
	upgrade_levels[key] = level + 1
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


func buy_lure() -> bool:
	if gold < LURE_COST:
		return false
	gold -= LURE_COST
	loadout_lures += 1
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


func consume_loadout_lures() -> int:
	var count := loadout_lures
	loadout_lures = 0
	_save()
	return count


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"gold": gold, "upgrade_levels": upgrade_levels, "loadout_lures": loadout_lures})


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Dictionary:
			gold = data.get("gold", 0)
			upgrade_levels = data.get("upgrade_levels", upgrade_levels)
			loadout_lures = data.get("loadout_lures", 0)
