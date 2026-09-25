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
## User request (shop linkage): the rod is its own upgrade line, one tier
## per rod in the pack (Lvl1 = the starting rod). Each tier raises the
## line's tension cap (how much strain it takes before snapping); the
## better ones also give a touch more time to strike and take the sting
## out of a leaping fish.
##   strength: divides every tension gain in FishFight
##   window: strike-time multiplier; jump: tension from holding a leap
const ROD_TIERS := [
	{"name": "木竿", "cost": 0, "strength": 1.0, "window": 1.0, "jump": 1.0},
	{"name": "玻纖竿", "cost": 50, "strength": 1.15, "window": 1.0, "jump": 1.0},
	{"name": "碳纖竿", "cost": 100, "strength": 1.3, "window": 1.1, "jump": 1.0},
	{"name": "海釣竿", "cost": 180, "strength": 1.45, "window": 1.15, "jump": 0.75},
	{"name": "黃金竿", "cost": 300, "strength": 1.6, "window": 1.2, "jump": 0.6},
]

## User request (shop linkage): each lure is its own shop item with its own
## effect, and fishing with it shows that lure (LureVisual.LURES[sprite]).
## Bought before a run into stock; the run takes the whole stock along.
##   wait: bite-wait multiplier; prefer: species habit it draws (see
##   FishData.pick_species); nibbles: fewer test nibbles, fake: fake-dunk
##   chance multiplier; rare / epic: rare-fish and legendary-upgrade
##   chance multipliers; no_bite: empty-cast chance multiplier
const LURES := {
	"minnow": {"name": "綠米諾", "sprite": 0, "cost": 10, "desc": "基本款，魚咬得比較快", "wait": 0.75},
	"redhead": {"name": "紅頭", "sprite": 1, "cost": 18, "desc": "愛跳的魚（鬼頭刀、旗魚、紅甘、鮪、鯖）較常上鉤", "prefer": "jumper"},
	"zebra": {"name": "斑馬", "sprite": 2, "cost": 18, "desc": "躲石縫的魚（石斑、鰻、蘇眉）較常上鉤", "prefer": "cover"},
	"clown": {"name": "小丑", "sprite": 3, "cost": 22, "desc": "試探咬口少一次、假咬減半，咬口更乾脆", "nibbles": 1, "fake": 0.5},
	"bluegold": {"name": "藍金", "sprite": 4, "cost": 30, "desc": "稀有魚機率 x1.5", "rare": 1.5},
	"rainbow": {"name": "彩虹", "sprite": 5, "cost": 45, "desc": "傳說魚機率 x2，但比較常空竿", "epic": 2.0, "no_bite": 1.5},
}
const LURE_ORDER := ["minnow", "redhead", "zebra", "clown", "bluegold", "rainbow"]
## User request: the flashlight is a shop item (bought once) that runs on
## batteries, also bought here and kept in stock until used (see Lantern).
const FLASHLIGHT_COST := 120
const BATTERY_COST := 12

var gold: int = 0
var upgrade_levels: Dictionary = {
	"fuel_capacity": 0, "bait_capacity": 0, "flash_cooldown": 0, "fuel_station_charges": 0,
	"rod_distance": 0, "reel_power": 0,
}

## Design doc §9.2: lures bought "賽前" (before the match) - queued here,
## then handed to the player and cleared the moment a run actually starts.
## Lure id (LURES) -> count.
var lure_stock: Dictionary = {}
## Index into ROD_TIERS.
var rod_tier: int = 0

var has_flashlight: bool = false
var batteries: int = 0

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


func buy_lure(id: String) -> bool:
	var cost: int = LURES[id].cost
	if gold < cost:
		return false
	gold -= cost
	lure_stock[id] = int(lure_stock.get(id, 0)) + 1
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


func loadout_lure_total() -> int:
	var total := 0
	for id in lure_stock:
		total += int(lure_stock[id])
	return total


func rod() -> Dictionary:
	return ROD_TIERS[rod_tier]


## The next rod up, or {} once at the top.
func next_rod() -> Dictionary:
	return ROD_TIERS[rod_tier + 1] if rod_tier + 1 < ROD_TIERS.size() else {}


func buy_rod() -> bool:
	var next := next_rod()
	if next.is_empty() or gold < int(next.cost):
		return false
	gold -= int(next.cost)
	rod_tier += 1
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


func buy_flashlight() -> bool:
	if has_flashlight or gold < FLASHLIGHT_COST:
		return false
	gold -= FLASHLIGHT_COST
	has_flashlight = true
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


func buy_battery() -> bool:
	if gold < BATTERY_COST:
		return false
	gold -= BATTERY_COST
	batteries += 1
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


## Takes one battery out of stock; false if there are none.
func use_battery() -> bool:
	if batteries <= 0:
		return false
	batteries -= 1
	profile_changed.emit()
	_save()
	return true


## Hands the whole lure stock to a starting run (id -> count).
func consume_loadout_lures() -> Dictionary:
	var stock := lure_stock
	lure_stock = {}
	_save()
	return stock


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"gold": gold,
			"upgrade_levels": upgrade_levels,
			"lure_stock": lure_stock,
			"rod_tier": rod_tier,
			"fish_log": fish_log,
			"has_flashlight": has_flashlight,
			"batteries": batteries,
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
			lure_stock = data.get("lure_stock", {})
			# Saves from before lure types: those lures become minnows.
			var old_lures: int = data.get("loadout_lures", 0)
			if old_lures > 0:
				lure_stock["minnow"] = int(lure_stock.get("minnow", 0)) + old_lures
			rod_tier = clampi(data.get("rod_tier", 0), 0, ROD_TIERS.size() - 1)
			fish_log = data.get("fish_log", {})
			has_flashlight = data.get("has_flashlight", false)
			batteries = data.get("batteries", 0)
