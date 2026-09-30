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
	"redhead": {"name": "紅頭", "sprite": 1, "cost": 18, "desc": "愛跳的魚（鱒、鱸、鮪、旗魚、鯖）較常上鉤", "prefer": "jumper"},
	"zebra": {"name": "斑馬", "sprite": 2, "cost": 18, "desc": "躲藏的魚（鯰、鰻、石斑、狗魚）較常上鉤", "prefer": "cover"},
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

## User request (warehouse): what's owned between runs - the warehouse
## (storage: item id -> count, see Items), the bag packed for the next run
## (bag: [{id, count, cell}] on the in-game backpack's grid - what's in it
## is what's taken in, used up in the run as it's used), and what's worn
## (equipped: slot -> item id; there's always a rod). The shop puts what
## it sells in the warehouse.
var storage: Dictionary = {}
var bag: Array = []
var equipped: Dictionary = {"rod": "rod_0", "light": ""}
## The best rod bought (the shop's rod line goes on from it).
var rods_owned: int = 0
## Index into ROD_TIERS: the rod worn (kept in step with equipped.rod).
var rod_tier: int = 0

## Worn in the light slot - usable in a run.
var has_flashlight: bool:
	get:
		return equipped.get("light", "") == "flashlight"
## Batteries packed in the bag.
var batteries: int:
	get:
		return bag_count("battery")
## Lures packed in the bag: lure key -> count.
var lure_stock: Dictionary:
	get:
		var out := {}
		for e in bag:
			var key: String = Items.def(e.id).get("lure", "")
			if key != "":
				out[key] = int(out.get(key, 0)) + int(e.count)
		return out

## User request: the game's settings. auto_lure: after a 誘惑 throw, pick
## the cheapest fish carried as the next lure (off: pick again yourself).
var settings: Dictionary = {"auto_lure": false}


func set_setting(key: String, value) -> void:
	settings[key] = value
	_changed()


## User request (fish tank): the fish brought home from a run live here -
## each a catch dict (id, name, value, size, length, weight, tank_trait).
## Sold or (later, with multiplayer) traded from the tank page.
const TANK_SIZE := 10
var tank: Array = []
## Names put in the tank since the main screen last said so.
var tank_news: Array = []

## User feedback: a fish log to give players a long-term goal beyond just
## gold - name -> {"count": int, "best_value": float}. See fish_log.gd for
## the read-only screen that lists this.
var fish_log: Dictionary = {}


func _ready() -> void:
	_load()


func record_catch(fish_name: String, value: float, length := 0.0, tank_trait := "") -> void:
	var entry: Dictionary = fish_log.get(fish_name, {"count": 0, "best_value": 0.0})
	entry.count = int(entry.count) + 1
	entry.best_value = max(float(entry.best_value), value)
	entry["longest"] = maxf(float(entry.get("longest", 0.0)), length)
	var traits: Array = entry.get("traits", [])
	if tank_trait != "" and not tank_trait in traits:
		traits.append(tank_trait)
	entry["traits"] = traits
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
	if key == "bait_capacity":
		ensure_bait()
	gold_updated.emit(gold)
	profile_changed.emit()
	_save()
	return true


func buy_lure(id: String) -> bool:
	var cost: int = LURES[id].cost
	if gold < cost:
		return false
	gold -= cost
	_store("lure_" + id, 1)
	gold_updated.emit(gold)
	_changed()
	return true


## Lures packed for the next run.
func loadout_lure_total() -> int:
	var total := 0
	for key in lure_stock:
		total += int(lure_stock[key])
	return total


func rod() -> Dictionary:
	return ROD_TIERS[rod_tier]


## The next rod up the shop's line, or {} once at the top.
func next_rod() -> Dictionary:
	return ROD_TIERS[rods_owned + 1] if rods_owned + 1 < ROD_TIERS.size() else {}


## Buys the next rod (into the warehouse; the shop asks where it goes).
func buy_rod() -> bool:
	var next := next_rod()
	if next.is_empty() or gold < int(next.cost):
		return false
	gold -= int(next.cost)
	rods_owned += 1
	_store("rod_%d" % rods_owned, 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_flashlight() -> bool:
	if owned("flashlight") > 0 or gold < FLASHLIGHT_COST:
		return false
	gold -= FLASHLIGHT_COST
	_store("flashlight", 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_battery() -> bool:
	if gold < BATTERY_COST:
		return false
	gold -= BATTERY_COST
	_store("battery", 1)
	gold_updated.emit(gold)
	_changed()
	return true


## Takes one battery out of the bag; false if there are none.
func use_battery() -> bool:
	return bag_take("battery", 1) == 1


## The lures a starting run takes: what's packed in the bag (lure key ->
## count). They stay in the bag and are taken out as they're lost.
func consume_loadout_lures() -> Dictionary:
	return lure_stock


# --- Fish tank ------------------------------------------------------------

## Puts a fish brought home in the tank (filling in length, weight and
## trait for fish from before those). False if the tank's full.
func add_to_tank(fish: Dictionary) -> bool:
	if tank.size() >= TANK_SIZE:
		return false
	var f := fish.duplicate()
	var id: String = f.get("id", "")
	if id == "":
		id = FishData.id_for(f.get("name", ""))
		f["id"] = id
	if not f.has("length"):
		f.merge(FishData.measure(id, f.get("size", "small")))
	if not f.has("tank_trait"):
		f["tank_trait"] = FishData.roll_tank_trait(id)
	f.erase("tier")
	tank.append(f)
	tank_news.append(f.get("name", "魚"))
	_changed()
	return true


func clear_tank_news() -> void:
	tank_news.clear()
	_save()


## Sells the tank's fish at `index` for its value; the gold made.
func sell_from_tank(index: int) -> int:
	if index < 0 or index >= tank.size():
		return 0
	var f: Dictionary = tank[index]
	tank.remove_at(index)
	var price := maxi(1, roundi(float(f.get("value", 0.0))))
	gold += price
	gold_updated.emit(gold)
	_changed()
	return price


# --- Warehouse, bag and equipment ---------------------------------------

func stored(id: String) -> int:
	return int(storage.get(id, 0))


func bag_count(id: String) -> int:
	var n := 0
	for e in bag:
		if e.id == id:
			n += int(e.count)
	return n


## How many of a thing are owned, wherever they are.
func owned(id: String) -> int:
	var worn := 0
	for slot in equipped:
		if equipped[slot] == id:
			worn += 1
	return stored(id) + bag_count(id) + worn


## Warehouse ids on a tab (Items.TABS), in order.
func storage_ids(tab := "") -> Array:
	var ids := []
	for id in storage:
		if int(storage[id]) > 0 and (tab == "" or Items.def(id).get("tab", "other") == tab):
			ids.append(id)
	return Items.sort_ids(ids)


## Does `id` fit in the bag with its top-left at `cell` (not counting the
## stack at index `ignore`)?
func bag_fits(id: String, cell: Vector2i, ignore := -1) -> bool:
	var rect := Rect2i(cell, Items.size_of(id))
	if cell.x < 0 or cell.y < 0 or rect.end.x > Inventory.COLS or rect.end.y > Inventory.ROWS:
		return false
	for i in bag.size():
		if i != ignore and Rect2i(bag[i].cell, Items.size_of(bag[i].id)).intersects(rect):
			return false
	return true


## The first place `id` fits (down each column in turn), or (-1, -1).
func bag_free_cell(id: String, ignore := -1) -> Vector2i:
	for x in Inventory.COLS:
		for y in Inventory.ROWS:
			if bag_fits(id, Vector2i(x, y), ignore):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## The bag stack covering `cell`, or -1.
func bag_at(cell: Vector2i) -> int:
	for i in bag.size():
		if Rect2i(bag[i].cell, Items.size_of(bag[i].id)).has_point(cell):
			return i
	return -1


## Moves up to `count` of `id` from the warehouse into the bag - onto the
## stack at `cell` or a new one there if given, the rest topping up stacks
## already packed, then into new ones wherever they fit. How many went in.
func to_bag(id: String, count: int, cell := Vector2i(-1, -1)) -> int:
	var left := mini(count, stored(id))
	var moved := 0
	var stack := Items.stack_of(id)
	if cell.x >= 0 and left > 0:
		var at := bag_at(cell)
		if at >= 0 and bag[at].id == id:
			var n := mini(left, stack - int(bag[at].count))
			bag[at].count += n
			left -= n
			moved += n
		elif at < 0 and bag_fits(id, cell):
			var n := mini(left, stack)
			bag.append({"id": id, "count": n, "cell": cell})
			left -= n
			moved += n
	for e in bag:
		if left <= 0:
			break
		if e.id == id and int(e.count) < stack:
			var n := mini(left, stack - int(e.count))
			e.count += n
			left -= n
			moved += n
	while left > 0:
		var free := bag_free_cell(id)
		if free.x < 0:
			break
		var n := mini(left, stack)
		bag.append({"id": id, "count": n, "cell": free})
		left -= n
		moved += n
	if moved > 0:
		storage[id] = stored(id) - moved
		if stored(id) <= 0:
			storage.erase(id)
		_changed()
	return moved


## Puts `count` of `id` straight in the bag (picked up in a run): topping
## up stacks, then new ones where they fit. How many went in.
func bag_put(id: String, count: int) -> int:
	var left := count
	var stack := Items.stack_of(id)
	for e in bag:
		if left <= 0:
			break
		if e.id == id and int(e.count) < stack:
			var n := mini(left, stack - int(e.count))
			e.count += n
			left -= n
	while left > 0:
		var free := bag_free_cell(id)
		if free.x < 0:
			break
		var n := mini(left, stack)
		bag.append({"id": id, "count": n, "cell": free})
		left -= n
	if left < count:
		_changed()
	return count - left


## The base bait a run starts with (the bait_capacity upgrade adds).
func base_bait() -> int:
	return Player.START_BAIT + int(get_upgrade_bonus("bait_capacity"))


## User request: the base bait takes bag cells - kept as "bait" stacks in
## the bag, as many as it needs (ten to a cell), placed where there's room
## (the last thing packed goes back to the warehouse if there isn't).
func ensure_bait() -> void:
	var need := base_bait()
	var cells := ceili(need / float(Items.stack_of("bait")))
	var have := []
	for i in bag.size():
		if bag[i].id == "bait":
			have.append(i)
	for k in range(have.size() - 1, cells - 1, -1):
		bag.remove_at(have[k])
	have.resize(mini(have.size(), cells))
	var guard := 0
	while have.size() < cells and guard < 40:
		guard += 1
		var free := bag_free_cell("bait")
		if free.x < 0:
			# No room: the last thing packed (not bait) goes to the warehouse.
			for j in range(bag.size() - 1, -1, -1):
				if bag[j].id != "bait":
					_store(bag[j].id, int(bag[j].count))
					bag.remove_at(j)
					break
			continue
		bag.append({"id": "bait", "count": 0, "cell": free})
		have.append(bag.size() - 1)
	var left := need
	for e in bag:
		if e.id == "bait":
			e.count = mini(left, Items.stack_of("bait"))
			left -= e.count
	profile_changed.emit()


## User request: dying in a run loses the fish and any gear found on the
## map there (flagged "found"); what was brought in stays.
func lose_found_gear() -> void:
	for i in range(bag.size() - 1, -1, -1):
		if bag[i].get("found", false):
			bag.remove_at(i)
	_changed()


## Takes the bag stack at `index` out whole (put down in a run).
func bag_remove(index: int) -> Dictionary:
	if index < 0 or index >= bag.size():
		return {}
	var e: Dictionary = bag[index]
	bag.remove_at(index)
	_changed()
	return e


## Puts up to `count` from the bag stack at `index` back in the warehouse.
func to_storage(index: int, count := -1) -> int:
	if index < 0 or index >= bag.size() or Items.def(bag[index].id).get("fixed", false):
		return 0
	var e: Dictionary = bag[index]
	var n: int = int(e.count) if count < 0 else mini(count, int(e.count))
	e.count -= n
	if int(e.count) <= 0:
		bag.remove_at(index)
	_store(e.id, n)
	_changed()
	return n


## Moves the bag stack at `index` so its top-left is at `cell`: onto a
## stack of the same thing there (as much as it takes), or to free room.
func bag_move(index: int, cell: Vector2i) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var e: Dictionary = bag[index]
	var other := bag_at(cell)
	if other >= 0 and other != index and bag[other].id == e.id:
		var n := mini(int(e.count), Items.stack_of(e.id) - int(bag[other].count))
		if n <= 0:
			return false
		bag[other].count += n
		e.count -= n
		if int(e.count) <= 0:
			bag.remove_at(index)
		_changed()
		return true
	if not bag_fits(e.id, cell, index):
		return false
	e.cell = cell
	_changed()
	return true


## Splits `count` off the bag stack at `index` into a new stack at `cell`.
func bag_split(index: int, count: int, cell: Vector2i) -> bool:
	if index < 0 or index >= bag.size() or count <= 0 or count >= int(bag[index].count):
		return false
	var id: String = bag[index].id
	if not bag_fits(id, cell):
		return false
	bag[index].count -= count
	bag.append({"id": id, "count": count, "cell": cell})
	_changed()
	return true


## Takes up to `count` of `id` out of the bag (used up in a run).
func bag_take(id: String, count: int) -> int:
	var taken := 0
	for i in range(bag.size() - 1, -1, -1):
		if taken >= count:
			break
		if bag[i].id != id:
			continue
		var n := mini(count - taken, int(bag[i].count))
		bag[i].count -= n
		taken += n
		if int(bag[i].count) <= 0:
			bag.remove_at(i)
	if taken > 0:
		_changed()
	return taken


## Puts on `id` - from the bag stack at `bag_index` if given, else from
## the warehouse (or the bag if none are there); what was worn in its slot
## goes to the warehouse.
func equip(id: String, bag_index := -1) -> bool:
	var slot: String = Items.def(id).get("slot", "")
	if slot == "" or equipped.get(slot, "") == id:
		return false
	if bag_index >= 0:
		if bag_index >= bag.size() or bag[bag_index].id != id:
			return false
		bag.remove_at(bag_index)
	elif stored(id) > 0:
		storage[id] = stored(id) - 1
		if stored(id) <= 0:
			storage.erase(id)
	else:
		var i := -1
		for j in bag.size():
			if bag[j].id == id:
				i = j
		if i < 0:
			return false
		bag.remove_at(i)
	var old: String = equipped.get(slot, "")
	if old != "":
		_store(old, 1)
	equipped[slot] = id
	_sync_rod()
	_changed()
	return true


## Takes off what's in `slot` (to the warehouse). The rod stays: there's
## always one on.
func unequip(slot: String) -> bool:
	var id: String = equipped.get(slot, "")
	if id == "" or slot == "rod":
		return false
	equipped[slot] = ""
	_store(id, 1)
	_changed()
	return true


func _store(id: String, count: int) -> void:
	if count > 0:
		storage[id] = stored(id) + count


func _sync_rod() -> void:
	rod_tier = clampi(int(str(equipped.get("rod", "rod_0")).substr(4)), 0, ROD_TIERS.size() - 1)


func _changed() -> void:
	profile_changed.emit()
	_save()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(snapshot())


## Everything saved, as load_data() takes it.
func snapshot() -> Dictionary:
	return {
		"gold": gold,
		"upgrade_levels": upgrade_levels,
		"fish_log": fish_log,
		"storage": storage,
		"bag": bag,
		"equipped": equipped,
		"rods_owned": rods_owned,
		"tank": tank,
		"tank_news": tank_news,
		"settings": settings,
	}.duplicate(true)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Dictionary:
			load_data(data)


## From a save (also saves from before the warehouse: their rod line, the
## lures and batteries bought for the next run - packed in the bag - and
## the flashlight, worn).
func load_data(data: Dictionary) -> void:
	gold = data.get("gold", 0)
	upgrade_levels = data.get("upgrade_levels", upgrade_levels)
	fish_log = data.get("fish_log", {})
	storage = data.get("storage", {})
	bag = data.get("bag", [])
	equipped = data.get("equipped", {"rod": "rod_0", "light": ""})
	rods_owned = clampi(data.get("rods_owned", data.get("rod_tier", 0)), 0, ROD_TIERS.size() - 1)
	tank = data.get("tank", [])
	tank_news = data.get("tank_news", [])
	settings = {"auto_lure": false}
	settings.merge(data.get("settings", {}), true)
	if not data.has("equipped"):
		var tier := rods_owned
		equipped = {"rod": "rod_%d" % tier, "light": "flashlight" if data.get("has_flashlight", false) else ""}
		for t in tier:
			_store("rod_%d" % t, 1)
		var lures: Dictionary = data.get("lure_stock", {})
		var old_lures: int = data.get("loadout_lures", 0)
		if old_lures > 0:
			lures["minnow"] = int(lures.get("minnow", 0)) + old_lures
		for key in lures:
			_store("lure_" + key, int(lures[key]))
			to_bag("lure_" + key, int(lures[key]))
		var cells: int = data.get("batteries", 0)
		_store("battery", cells)
		to_bag("battery", cells)
	_sync_rod()
	ensure_bait()
