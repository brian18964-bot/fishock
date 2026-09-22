extends Node

## Autoload singleton. The account-level "個人關卡" progress line (design
## doc §9.1/§9.3) - persists across runs AND across sessions via a save
## file, unlike GameState which resets every run. Shop UI (shop.gd) builds
## its rows straight from UPGRADE_DEFS, so a new key here shows up there
## automatically - no UI changes needed to add an upgrade.

signal gold_updated(gold: int)
signal profile_changed()

const SAVE_PATH := "user://profile.save"

const UPGRADE_DEFS := {
	"fuel_capacity": {"label": "提燈燃油容量", "max_level": 3, "costs": [20, 40, 70], "bonus": 20.0},
	"bait_capacity": {"label": "帶餌上限", "max_level": 3, "costs": [15, 30, 50], "bonus": 5.0},
	"flash_cooldown": {"label": "強光冷卻縮短", "max_level": 3, "costs": [20, 40, 70], "bonus": 0.5},
	"fuel_station_charges": {"label": "煤油站總量上限", "max_level": 3, "costs": [25, 45, 75], "bonus": 100.0},
	"rod_distance": {"label": "釣竿拋投距離", "max_level": 3, "costs": [20, 40, 70], "bonus": 40.0},
	"reel_power": {"label": "捲線器力道", "max_level": 3, "costs": [25, 50, 85], "bonus": 0.12},
}
const LURE_COST := 15

var gold: int = 0
var upgrade_levels: Dictionary = {
	"fuel_capacity": 0, "bait_capacity": 0, "flash_cooldown": 0, "fuel_station_charges": 0,
	"rod_distance": 0, "reel_power": 0,
}

## Design doc §9.2: lures bought "賽前" (before the match) - queued here,
## then handed to the player and cleared the moment a run actually starts.
var loadout_lures: int = 0

## User feedback: a fish log to give players a long-term goal beyond just
## gold - name -> {"count": int, "best_value": float}. See fish_log.gd for
## the read-only screen that lists this.
var fish_log: Dictionary = {}


func _ready() -> void:
	_load()


func record_catch(fish_name: String, value: float) -> void:
	var entry: Dictionary = fish_log.get(fish_name, {"count": 0, "best_value": 0.0})
	entry.count = int(entry.count) + 1
	entry.best_value = max(float(entry.best_value), value)
	fish_log[fish_name] = entry
	profile_changed.emit()
	_save()


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
		file.store_var({
			"gold": gold,
			"upgrade_levels": upgrade_levels,
			"loadout_lures": loadout_lures,
			"fish_log": fish_log,
		})


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
			fish_log = data.get("fish_log", {})
