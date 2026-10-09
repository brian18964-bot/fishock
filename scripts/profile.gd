extends Node

## Autoload singleton. The account-level "個人關卡" progress line (design
## doc §9.1/§9.3) - persists across runs AND across sessions via a save
## file, unlike GameState which resets every run. Shop UI (shop.gd) builds
## its rows straight from UPGRADE_DEFS, so a new key here shows up there
## automatically - no UI changes needed to add an upgrade.

signal gold_updated(gold: int)
signal profile_changed()
## User request: a thing worn out (Profile.wear_out()) - gone.
signal gear_broke(id: String, name: String)

const SAVE_PATH := "user://profile.save"

const UPGRADE_DEFS := {
	"fuel_capacity": {"label": "提燈燃油容量", "max_level": 3, "costs": [20, 40, 70], "bonus": 20.0},
	"bait_capacity": {"label": "帶餌上限", "max_level": 3, "costs": [15, 30, 50], "bonus": 5.0},
	"flash_cooldown": {"label": "強光冷卻縮短", "max_level": 3, "costs": [20, 40, 70], "bonus": 0.5},
	"fuel_station_charges": {"label": "營地油桶容量", "max_level": 3, "costs": [25, 45, 75], "bonus": 100.0},
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
	{"name": "木竿", "cost": 0, "strength": 1.0, "window": 1.0, "jump": 1.0, "durability": 50},
	{"name": "玻纖竿", "cost": 50, "strength": 1.15, "window": 1.0, "jump": 1.0, "durability": 70},
	{"name": "碳纖竿", "cost": 100, "strength": 1.3, "window": 1.1, "jump": 1.0, "durability": 90},
	{"name": "海釣竿", "cost": 180, "strength": 1.45, "window": 1.15, "jump": 0.75, "durability": 120},
	{"name": "黃金竿", "cost": 300, "strength": 1.6, "window": 1.2, "jump": 0.6, "durability": 160},
]
## User request: everything worn wears out - every use takes one off its
## durability (a rod: a cast; the flashlight: a flash; the off hand's
## thing: a swing, a parry, a shot), and at 0 it breaks and is gone: buy a
## new one (the wooden rod, free, if no rod's left). Uses each lasts; the
## rods' are ROD_TIERS' durability.
const DURABILITY := {"flashlight": 60, "knife": 60, "hatchet": 50, "machete": 70, "glock": 80, "net": 40}

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
## User request: live baits besides the base bait, bought in the shop and
## packed in the bag; on the float, one is used per cast in place of the
## base bait (chosen in the in-game bag), each with the effect of its
## flavor (Player: 蚯蚓 bites sooner, 蟲子 fewer empty casts, 青蛙 rare
## fish likelier, big bait legends likelier).
const LIVE_BAITS := {
	"worm": {"name": "蚯蚓", "cost": 3, "flavor": "蚯蚓", "desc": "活餌：魚咬得比較快（等待時間 -30%）"},
	# (User request, round 7: the user's grasshopper in the old cricket's
	# place - the id kept, for the saves.)
	"cricket": {"name": "蚱蜢", "cost": 4, "flavor": "蟲子", "desc": "活餌：空竿的機率減半"},
	"shrimp": {"name": "活蝦", "cost": 6, "flavor": "青蛙", "desc": "活餌：稀有魚的機率 x2"},
	"minnow": {"name": "小活魚", "cost": 9, "flavor": "小活魚", "desc": "活餌（大餌）：稀有魚升級成傳說魚的機率 x2"},
	# User request: the frog and the spider (the user's models) sold as
	# live baits too.
	"spider": {"name": "活蜘蛛", "cost": 5, "flavor": "蜘蛛", "desc": "活餌：空竿的機率減半，假咬也減半"},
	"frog": {"name": "活青蛙", "cost": 15, "flavor": "活青蛙",
		"desc": "活餌（大餌）：稀有魚機率 x2，稀有魚升級成傳說魚的機率也 x2"},
	# User request (round 8): what's caught on the map goes in the bag as a
	# live bait - these only that way (shop: false; their cost only sets
	# their rarity). The worm, grasshopper, frog and spider caught there
	# are the ones above; the shrimp and the small fish are only bought.
	"rat": {"name": "老鼠", "cost": 12, "flavor": "老鼠", "shop": false,
		"desc": "活餌（大餌，只能在地圖上抓到）：稀有魚升級成傳說魚的機率 x2"},
	"snake": {"name": "蛇", "cost": 14, "flavor": "蛇", "shop": false,
		"desc": "活餌（大餌，只能在地圖上抓到）：稀有魚升級成傳說魚的機率 x2"},
	"crab": {"name": "螃蟹", "cost": 12, "flavor": "螃蟹", "shop": false,
		"desc": "活餌（大餌，只能在海邊抓到）：稀有魚升級成傳說魚的機率 x2"},
	"bee": {"name": "蜜蜂", "cost": 5, "flavor": "蟲子", "shop": false,
		"desc": "活餌（只能在地圖上抓到）：空竿的機率減半"},
	"black_spider": {"name": "黑蜘蛛", "cost": 10, "flavor": "蜘蛛", "shop": false,
		"desc": "活餌（只能在地圖上抓到）：空竿的機率減半，假咬也減半"},
}
const LIVE_ORDER := ["worm", "cricket", "spider", "shrimp", "minnow", "frog", "rat", "snake", "crab", "bee", "black_spider"]
## Round 8 (user request): the landing net - worn in the off hand
## (equipped.offhand) and held in a run between casts (Player.net_in_hand):
## critters are caught from further off and bite less.
const NET_COST := 70
const NET_DESC := "副手裝備：拿在手上時點一下右搖桿揮網撈活餌，抓得更遠，被咬中毒的機率減半"
## User request: the flashlight is a shop item (bought once) that runs on
## batteries, also bought here and kept in stock until used (see Lantern).
const FLASHLIGHT_COST := 120
const BATTERY_COST := 12
## User request: the knives, the hatchet and the pistol (the user's
## models) sold in the shop - each bought once. User request: worn in the
## off hand (equipped.offhand, with the net - one of them), held while the
## rod's on the back and swung with a tap of the right stick; at the hip
## while fishing. What each does in a run (Player):
##   defend: a beast that pounces is cut back - no fish knocked loose, and
##           only a short stagger;
##   chop:   trees can be chopped (砍樹, see MapTree): sometimes bait falls
##           out, sometimes a black spider - 1 the machete, 2 the hatchet
##           (finds more);
##   gun:    a beast that starts a chase is shot at and runs - one round
##           (ammo, packed in the bag) a shot - but the shot carries: the
##           big ghost comes to look.
const WEAPONS := {
	"knife": {"name": "獵刀", "cost": 80, "size": Vector2i(2, 1), "defend": true,
		"desc": "副手：拿在手上時野獸撲上來會揮刀擋開；點右搖桿揮刀可以趕走身邊的野獸"},
	"hatchet": {"name": "手斧", "cost": 110, "size": Vector2i(2, 1), "chop": 2,
		"desc": "副手：靠近樹點右搖桿砍樹，樹上常掉下餌料，也可能抖出黑蜘蛛"},
	"machete": {"name": "開山刀", "cost": 160, "size": Vector2i(3, 1), "chop": 1, "defend": true,
		"desc": "副手：可以砍樹（找到的比手斧少）；拿在手上時野獸撲上來會擋開，揮刀可趕走野獸"},
	"glock": {"name": "手槍", "cost": 380, "size": Vector2i(2, 1), "gun": true,
		"desc": "副手：點右搖桿開槍嚇跑野獸，拿在手上時野獸追來也會自動開槍（每次 1 發子彈，子彈要放背包）；槍聲會引來大鬼"},
}
const WEAPON_ORDER := ["knife", "hatchet", "machete", "glock"]
const AMMO_COST := 6

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
var equipped: Dictionary = {"rod": "rod_0", "light": "", "offhand": ""}
## Uses left on what's worn out a little (id -> uses; see DURABILITY) -
## there's one of each such thing.
var wear: Dictionary = {}
## The best rod bought (the shop's rod line goes on from it).
var rods_owned: int = 0
## Index into ROD_TIERS: the rod worn (kept in step with equipped.rod).
var rod_tier: int = 0

## The weapon in the off hand (WEAPONS entry; {} for none, or the net).
var weapon: Dictionary:
	get:
		return WEAPONS.get(equipped.get("offhand", ""), {})
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
## User request (the camp): the tent pitched at the camp (CampStage's
## tent_<n> model; 8, the bare lean-to, to start - better ones are earned).
var camp_tent: int = 8

## User request: the four greybox animal people in the game (tools/
## owl_character.py's player(), PLAYER=<id>), each with its own pictures
## (CharacterArt); tapping the camp's fire changes who's travelling. And
## (user request) two more after the user's deer and ram: the stag and the
## sheep. [id, name].
const CHARACTERS := [["cat", "黑貓"], ["owl", "貓頭鷹"], ["dog", "犬"], ["bear", "熊"], ["deer", "鹿"],
	["sheep", "羊"]]
var character: String = "cat"
## User request: the run's three quick slots (QuickSlots, over the right
## stick) - the item each is set to (one of USABLES), or "".
const QUICK_SLOTS := 3
var quick_slots: Array = ["", "", ""]

## User request (Camp v2): the traveller's spirit (精神), 0..SPIRIT_MAX.
## Lost when a ghost's grab isn't escaped; back with rest at the camp, a
## run escaped, or the merchant's tea and food (SNACKS).
const SPIRIT_MAX := 100.0
var spirit: float = SPIRIT_MAX
## One of them bought (the character has it at the camp: CampLife.treat()).
signal snack_had(key: String)
const SNACKS := {
	"tea": {"name": "熱茶", "cost": 15, "spirit": 20.0, "desc": "一杯熱騰騰的茶，暖手也暖心"},
	# User request: the bread roll and the cheeses (the user's models).
	"roll": {"name": "凱薩麵包", "cost": 20, "spirit": 25.0, "desc": "剛烤好的小圓麵包，外皮酥脆"},
	"loaf": {"name": "鄉村麵包", "cost": 35, "spirit": 40.0, "desc": "一整條烤得焦香的大麵包，分著吃也夠"},
	"cheese": {"name": "乳酪拼盤", "cost": 45, "spirit": 50.0, "desc": "三種乳酪切好一盤，配茶最對味"},
}
## (User request, round 7: the rations taken off the menu.)
const SNACK_ORDER := ["tea", "roll", "loaf", "cheese"]

## User request (round 7): things to use in a run (the user's models),
## bought here, packed in the bag and used from it (Backpack's 使用; what
## each does: Player.use_item()). "keep": not used up (the binoculars,
## bought once).
const USABLES := {
	"potion_vigor": {"name": "增強藥水", "cost": 25, "stack": 3, "keep": false,
		"desc": "喝下後 45 秒：跑得更快，搏魚時張力上升變慢"},
	"potion_ward": {"name": "驅鬼藥水", "cost": 30, "stack": 3, "keep": false,
		"desc": "喝下後 30 秒：鬼魂近不了身，身邊的鬼被逼退，水鬼也不敢偷襲"},
	# Round 8 (user request): the eyeball shows the 渡石 now; a new eye the
	# altar, another the ghosts; the binoculars the nearest water.
	"eyeball": {"name": "渡石之眼", "cost": 20, "stack": 5, "keep": false,
		"desc": "使用後 20 秒，眼球會指出渡石在哪個方向、有多遠"},
	"eye_altar": {"name": "祭壇之眼", "cost": 20, "stack": 5, "keep": false,
		"desc": "使用後 20 秒，金色的眼睛會盯著祭壇的方向、告訴你有多遠"},
	"eye_ghost": {"name": "見鬼之眼", "cost": 35, "stack": 5, "keep": false,
		"desc": "使用後 20 秒，看得見最近的鬼在哪個方向（會跟著鬼移動）"},
	"binoculars": {"name": "望遠鏡", "cost": 90, "stack": 1, "keep": true,
		"desc": "望向遠方找出最近的水域（指引 20 秒）；不會用掉，用過要等 60 秒"},
}
const USABLE_ORDER := ["potion_vigor", "potion_ward", "eyeball", "eye_altar", "eye_ghost", "binoculars"]

## User request (Camp v2): what's been done, for the achievements that
## earn the camp's tents (TENTS) - escapes, gold spent, legends caught.
var stats: Dictionary = {"escapes": 0, "gold_spent": 0, "legends": 0}
## The tents, in the order they're earned: [tent model, its name, what
## earns it, its stat ("log": the fish log's share of the kinds), amount].
const TENTS := [
	[8, "枝條棚", "一開始就有", "", 0],
	[9, "編枝小屋", "成功逃脫 10 次", "escapes", 10],
	[7, "枝架遮棚", "圖鑑收集 20%", "log", 20],
	[5, "帆布帳", "累計花費 500 金幣", "gold_spent", 500],
	[6, "皮頂長棚", "成功逃脫 50 次", "escapes", 50],
	[1, "獸皮帳", "圖鑑收集 40%", "log", 40],
	[2, "熊皮大帳", "釣到第一條傳說魚", "legends", 1],
	[3, "旅人帳", "成功逃脫 100 次", "escapes", 100],
	[4, "長屋帳", "圖鑑收集 80%", "log", 80],
]


## User request (the campaign, Campaign): each level's stars [out, ★★,
## ★★★], how often it's been cleared and tried, the best time; the
## chapters whose every-star bonus is paid; the curse sets cleared.
var campaign: Dictionary = {"levels": {}, "chapter_bonus": [], "curse_clears": 0, "best_curses": 0}
## Counts kept for good (Campaign adds each run's into them): catches, far
## catches, stuns, escapes at night...
var records: Dictionary = {}
## Achievements earned (Campaign.ACHIEVEMENTS ids): when.
var achievements: Dictionary = {}


func level_stars(id: String) -> Array:
	var entry: Dictionary = campaign.levels.get(id, {})
	var s: Array = entry.get("stars", [false, false, false])
	return [bool(s[0]), bool(s[1]), bool(s[2])]


func record_level(id: String, stars: Array, seconds: float) -> void:
	var entry: Dictionary = campaign.levels.get(id, {})
	entry["stars"] = stars.duplicate()
	entry["clears"] = int(entry.get("clears", 0)) + 1
	entry["tries"] = int(entry.get("tries", 0)) + 1
	var best := float(entry.get("best", 0.0))
	entry["best"] = seconds if best <= 0.0 else minf(best, seconds)
	campaign.levels[id] = entry
	_changed()


func record_level_try(id: String) -> void:
	var entry: Dictionary = campaign.levels.get(id, {})
	entry["tries"] = int(entry.get("tries", 0)) + 1
	campaign.levels[id] = entry
	_changed()


func level_entry(id: String) -> Dictionary:
	return campaign.levels.get(id, {})


func chapter_bonus_paid(ch: int) -> bool:
	return ch in campaign.chapter_bonus


func pay_chapter_bonus(ch: int) -> void:
	if not ch in campaign.chapter_bonus:
		campaign.chapter_bonus.append(ch)
		_changed()


func record_curse_clear(chosen: Array) -> void:
	campaign["curse_clears"] = int(campaign.get("curse_clears", 0)) + 1
	campaign["best_curses"] = maxi(int(campaign.get("best_curses", 0)), chosen.size())
	_changed()


func record(key: String) -> float:
	return float(records.get(key, 0.0))


func add_records(add: Dictionary) -> void:
	for key in add:
		records[key] = float(records.get(key, 0.0)) + float(add[key])
	_changed()


func has_achievement(id: String) -> bool:
	return achievements.has(id)


## Marks an achievement earned and pays its gold.
func grant_achievement(id: String, gold_reward: int) -> void:
	if achievements.has(id):
		return
	achievements[id] = Time.get_unix_time_from_system()
	gold += gold_reward
	gold_updated.emit(gold)
	_changed()


func set_setting(key: String, value) -> void:
	settings[key] = value
	_changed()


var _rest_time := 0.0
## When the traveller last rested at the camp (unix time; 0 out on a run) -
## the camp's minutes count while the game's closed, too.
var camp_since := 0.0


## Resting at the camp (user request): a point of spirit back for every
## minute there, up to full.
func rest(delta: float) -> void:
	if spirit >= SPIRIT_MAX:
		_rest_time = 0.0
		return
	_rest_time += delta
	if _rest_time >= 60.0:
		_rest_time -= 60.0
		camp_since = Time.get_unix_time_from_system()
		add_spirit(1.0)


## Back at the camp (the main screen): the whole minutes rested since last
## here - with the game closed - come back as spirit.
func arrive_at_camp() -> void:
	var now := Time.get_unix_time_from_system()
	if camp_since > 0.0 and now > camp_since:
		var minutes := floorf((now - camp_since) / 60.0)
		if minutes >= 1.0:
			add_spirit(minutes)
			camp_since += minutes * 60.0
	else:
		camp_since = now
	_save()


## Setting out: the camp's clock stops till the next return.
func leave_camp() -> void:
	camp_since = 0.0
	_save()


## User request (Camp v2): low spirit tells on the traveller - by how low
## (0: 70 and up, 1: 50-69, 2: 30-49, 3: under 30): bag rows lost, slower
## on their feet, less time to strike, the float fooling them more often
## (and, worn right out, a hand that slips and snaps the line now and then).
const SPIRIT_SPEED := [1.0, 0.9, 0.8, 0.7]
const SPIRIT_WINDOW := [1.0, 0.9, 0.8, 0.7]
const SPIRIT_NIBBLES := [0, 0, 1, 2]
const SPIRIT_FAKE := [0.0, 0.0, 0.15, 0.3]


func spirit_penalty() -> int:
	return 0 if spirit >= 70.0 else (1 if spirit >= 50.0 else (2 if spirit >= 30.0 else 3))


## The bag's rows still usable (the rest shut by low spirit).
func bag_rows() -> int:
	return maxi(Inventory.ROWS - spirit_penalty(), 1)


## Spirit up or down by `amount` (kept in 0..SPIRIT_MAX).
func add_spirit(amount: float) -> void:
	var was := spirit
	spirit = clampf(spirit + amount, 0.0, SPIRIT_MAX)
	if spirit != was:
		_changed()


## Sets quick slot `i` to usable `id` ("" clears it); the same item isn't
## in two slots.
func set_quick_slot(i: int, id: String) -> void:
	if i < 0 or i >= QUICK_SLOTS or (id != "" and not USABLES.has(id)):
		return
	if id != "":
		for k in QUICK_SLOTS:
			if quick_slots[k] == id:
				quick_slots[k] = ""
	quick_slots[i] = id
	_changed()


## Buys the merchant's tea or food and has it there and then: false if
## short of gold or already in full spirit.
func buy_snack(key: String) -> bool:
	var d: Dictionary = SNACKS[key]
	if gold < int(d.cost) or spirit >= SPIRIT_MAX:
		return false
	_spend(int(d.cost))
	spirit = minf(spirit + float(d.spirit), SPIRIT_MAX)
	gold_updated.emit(gold)
	_changed()
	snack_had.emit(key)
	return true


## Pays `cost` (counted toward the gold-spent achievement).
func _spend(cost: int) -> void:
	gold -= cost
	stats["gold_spent"] = int(stats.get("gold_spent", 0)) + cost
	records["purchases"] = float(records.get("purchases", 0.0)) + 1.0


## How far the fish log's come: the share (0..100) of the kinds caught.
func log_percent() -> float:
	var caught := 0
	for id in FishData.FISH:
		if fish_log.has(FishData.FISH[id].name):
			caught += 1
	return 100.0 * caught / maxf(FishData.FISH.size(), 1.0)


## How far along a tent's achievement is: [now, needed].
func tent_progress(i: int) -> Array:
	var t: Array = TENTS[i]
	if t[3] == "":
		return [0.0, 0.0]
	var now: float = log_percent() if t[3] == "log" else float(stats.get(t[3], 0))
	return [now, float(t[4])]


func tent_unlocked(tent: int) -> bool:
	for i in TENTS.size():
		if TENTS[i][0] == tent:
			var p := tent_progress(i)
			return p[0] >= p[1]
	return false


## The character's name (CHARACTERS).
func character_name(id: String = character) -> String:
	for c in CHARACTERS:
		if c[0] == id:
			return c[1]
	return id


## The next character in CHARACTERS takes over (the camp's fire).
func next_character() -> String:
	choose_character(character_after())
	return character


## The one after `id` in CHARACTERS (round to the first).
func character_after(id: String = character) -> String:
	var i := 0
	for j in CHARACTERS.size():
		if CHARACTERS[j][0] == id:
			i = j
	return CHARACTERS[(i + 1) % CHARACTERS.size()][0]


## `id` travels from now on.
func choose_character(id: String) -> void:
	character = id
	_changed()


## Pitches tent `tent` at the camp, if it's been earned.
func pitch_tent(tent: int) -> bool:
	if not tent_unlocked(tent):
		return false
	camp_tent = tent
	_changed()
	return true


func record_escape() -> void:
	stats["escapes"] = int(stats.get("escapes", 0)) + 1
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


func record_catch(fish_name: String, value: float, length := 0.0, tank_trait := "", legend := false) -> void:
	if legend:
		stats["legends"] = int(stats.get("legends", 0)) + 1
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
	_spend(cost)
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
	_spend(cost)
	_store("lure_" + id, 1)
	gold_updated.emit(gold)
	_changed()
	return true


## Lures packed for the next run.
func buy_live_bait(key: String) -> bool:
	var cost: int = LIVE_BAITS[key].cost
	if gold < cost:
		return false
	_spend(cost)
	_store("live_" + key, 1)
	gold_updated.emit(gold)
	_changed()
	return true


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


## Buys the next rod (into the warehouse; the shop asks where it goes) -
## or, `tier` given, one bought before that broke.
func buy_rod(tier := -1) -> bool:
	if tier >= 0 and tier <= rods_owned:
		if owned("rod_%d" % tier) > 0 or gold < int(ROD_TIERS[tier].cost):
			return false
		_spend(int(ROD_TIERS[tier].cost))
		_store("rod_%d" % tier, 1)
		gold_updated.emit(gold)
		_changed()
		return true
	var next := next_rod()
	if next.is_empty() or gold < int(next.cost):
		return false
	_spend(int(next.cost))
	rods_owned += 1
	_store("rod_%d" % rods_owned, 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_flashlight() -> bool:
	if owned("flashlight") > 0 or gold < FLASHLIGHT_COST:
		return false
	_spend(FLASHLIGHT_COST)
	_store("flashlight", 1)
	gold_updated.emit(gold)
	_changed()
	return true


## A weapon (WEAPONS), bought once, into the warehouse.
func buy_weapon(id: String) -> bool:
	if not WEAPONS.has(id) or owned(id) > 0 or gold < int(WEAPONS[id].cost):
		return false
	_spend(int(WEAPONS[id].cost))
	_store(id, 1)
	gold_updated.emit(gold)
	_changed()
	return true


## The landing net, bought once, into the warehouse.
func buy_net() -> bool:
	if owned("net") > 0 or gold < NET_COST:
		return false
	_spend(NET_COST)
	_store("net", 1)
	gold_updated.emit(gold)
	_changed()
	return true


func has_net() -> bool:
	return equipped.get("offhand", "") == "net"


## The off hand's thing ("" for none).
func offhand() -> String:
	return str(equipped.get("offhand", ""))


## Uses a thing lasts new (0: it doesn't wear out).
func max_durability(id: String) -> int:
	if id.begins_with("rod_"):
		var tier := int(id.substr(4))
		return int(ROD_TIERS[tier].durability) if tier >= 0 and tier < ROD_TIERS.size() else 0
	return int(DURABILITY.get(id, 0))


## Uses `id` has left.
func durability(id: String) -> int:
	return int(wear.get(id, max_durability(id)))


## A use of `id` (worn): one off its durability; at 0 it breaks - gone
## from where it is (the rod: another put on, or a new wooden one).
## True if it broke.
func wear_out(id: String, uses := 1) -> bool:
	if id == "" or max_durability(id) <= 0:
		return false
	var left := durability(id) - uses
	if left > 0:
		wear[id] = left
		_changed()
		return false
	wear.erase(id)
	var slot := ""
	for k in equipped:
		if equipped[k] == id:
			slot = k
	if slot != "":
		equipped[slot] = ""
	elif stored(id) > 0:
		_store(id, -1)
		if stored(id) <= 0:
			storage.erase(id)
	else:
		bag_take(id, 1)
	if slot == "rod":
		_next_rod()
	gear_broke.emit(id, Items.name_of(id))
	_changed()
	return true


## The rod broke: the best one left goes on (from the warehouse, else the
## bag), or a new wooden one.
func _next_rod() -> void:
	for t in range(ROD_TIERS.size() - 1, -1, -1):
		var id := "rod_%d" % t
		if stored(id) > 0 or bag_count(id) > 0:
			equipped.rod = ""
			equip(id)
			return
	equipped.rod = "rod_0"
	_sync_rod()


func buy_ammo() -> bool:
	if gold < AMMO_COST:
		return false
	_spend(AMMO_COST)
	_store("ammo", 1)
	gold_updated.emit(gold)
	_changed()
	return true


## One of USABLES into the warehouse; false if it can't be bought (no
## gold, or a kept thing already owned).
func buy_usable(id: String) -> bool:
	if not USABLES.has(id):
		return false
	var d: Dictionary = USABLES[id]
	if gold < int(d.cost) or (d.keep and owned(id) > 0):
		return false
	_spend(int(d.cost))
	_store(id, 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_battery() -> bool:
	if gold < BATTERY_COST:
		return false
	_spend(BATTERY_COST)
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
	if cell.x < 0 or cell.y < 0 or rect.end.x > Inventory.COLS or rect.end.y > bag_rows():
		return false
	for i in bag.size():
		if i != ignore and Rect2i(bag[i].cell, Items.size_of(bag[i].id)).intersects(rect):
			return false
	return true


## The first place `id` fits (down each column in turn), or (-1, -1).
func bag_free_cell(id: String, ignore := -1) -> Vector2i:
	for x in Inventory.COLS:
		for y in bag_rows():
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


## Throws away up to `count` of the bag stack at `index` (the bag page's
## 丟棄; not the base bait - it's given every run). How many went.
func bag_discard(index: int, count := -1) -> int:
	if index < 0 or index >= bag.size() or Items.def(bag[index].id).get("fixed", false):
		return 0
	var e: Dictionary = bag[index]
	var n: int = int(e.count) if count < 0 else mini(count, int(e.count))
	e.count -= n
	if int(e.count) <= 0:
		bag.remove_at(index)
	_changed()
	return n


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


## User request (the bag in a run): puts on the thing in the bag stack at
## `index` - what was worn in its slot goes into the bag in its place
## (where it fits, else anywhere) - false if it can't: nothing to wear, or
## no room for what comes off.
func equip_from_bag(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var id: String = bag[index].id
	var slot: String = Items.def(id).get("slot", "")
	if slot == "":
		return false
	var cell: Vector2i = bag[index].cell
	var old: String = equipped.get(slot, "")
	bag.remove_at(index)
	if old != "":
		var at := cell if bag_fits(old, cell) else bag_free_cell(old)
		if at.x < 0:
			bag.insert(index, {"id": id, "count": 1, "cell": cell})
			return false
		bag.append({"id": old, "count": 1, "cell": at})
	equipped[slot] = id
	_sync_rod()
	_changed()
	return true


## User request (the bag in a run): takes off what's in `slot` into the bag
## at `cell` (or anywhere it fits); false if there's no room - or it's the
## rod (there's always one on).
func unequip_to_bag(slot: String, cell := Vector2i(-1, -1)) -> bool:
	var id: String = equipped.get(slot, "")
	if id == "" or slot == "rod":
		return false
	var at := cell if cell.x >= 0 and bag_fits(id, cell) else bag_free_cell(id)
	if at.x < 0:
		return false
	equipped[slot] = ""
	bag.append({"id": id, "count": 1, "cell": at})
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
		"wear": wear,
		"rods_owned": rods_owned,
		"tank": tank,
		"tank_news": tank_news,
		"settings": settings,
		"camp_tent": camp_tent,
		"character": character,
		"quick_slots": quick_slots,
		"spirit": spirit,
		"camp_since": camp_since,
		"stats": stats,
		"campaign": campaign,
		"records": records,
		"achievements": achievements,
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
	wear = data.get("wear", {})
	# (saves from before the off hand: the weapon worn goes in it, else the
	# net; the other back to the warehouse)
	if not equipped.has("offhand"):
		var weapon_id: String = equipped.get("weapon", "")
		var net_id: String = equipped.get("net", "")
		equipped["offhand"] = weapon_id if weapon_id != "" else net_id
		if weapon_id != "" and net_id != "":
			_store(net_id, 1)
	equipped.erase("weapon")
	equipped.erase("net")
	if str(equipped.get("rod", "")) == "":
		equipped["rod"] = "rod_0"
	rods_owned = clampi(data.get("rods_owned", data.get("rod_tier", 0)), 0, ROD_TIERS.size() - 1)
	tank = data.get("tank", [])
	tank_news = data.get("tank_news", [])
	settings = {"auto_lure": false}
	settings.merge(data.get("settings", {}), true)
	camp_tent = int(data.get("camp_tent", 8))
	character = str(data.get("character", "cat"))
	quick_slots = ["", "", ""]
	var saved_slots: Array = data.get("quick_slots", [])
	for i in mini(saved_slots.size(), QUICK_SLOTS):
		if USABLES.has(str(saved_slots[i])):
			quick_slots[i] = str(saved_slots[i])
	if CHARACTERS.all(func(c): return c[0] != character):
		character = "cat"
	spirit = clampf(float(data.get("spirit", SPIRIT_MAX)), 0.0, SPIRIT_MAX)
	camp_since = float(data.get("camp_since", 0.0))
	stats = {"escapes": 0, "gold_spent": 0, "legends": 0}
	stats.merge(data.get("stats", {}), true)
	campaign = {"levels": {}, "chapter_bonus": [], "curse_clears": 0, "best_curses": 0}
	campaign.merge(data.get("campaign", {}), true)
	records = data.get("records", {})
	achievements = data.get("achievements", {})
	if not data.has("equipped"):
		var tier := rods_owned
		equipped = {"rod": "rod_%d" % tier, "light": "flashlight" if data.get("has_flashlight", false) else "", "offhand": ""}
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
