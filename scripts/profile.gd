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
	{"name": "玻纖竿", "cost": 150, "strength": 1.15, "window": 1.0, "jump": 1.0, "durability": 70},
	{"name": "碳纖竿", "cost": 400, "strength": 1.3, "window": 1.1, "jump": 1.0, "durability": 90},
	{"name": "海釣竿", "cost": 900, "strength": 1.45, "window": 1.15, "jump": 0.75, "durability": 120},
	{"name": "黃金竿", "cost": 1800, "strength": 1.6, "window": 1.2, "jump": 0.6, "durability": 160},
]
## User request: everything worn wears out - every use takes one off its
## durability (a rod: a cast; the flashlight: a flash; the off hand's
## thing: a swing, a parry, a shot), and at 0 it breaks and is gone: buy a
## new one (the wooden rod, free, if no rod's left). Uses each lasts; the
## rods' are ROD_TIERS' durability.
const DURABILITY := {"flashlight": 60, "knife": 60, "hatchet": 50, "machete": 70, "glock": 80, "net": 40, "oxy_box": 40, "shovel": 45}

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
## User request: the oxygenated fish box (打氧魚箱) - an off-hand thing, bought
## once; unworn it takes six cells of the bag (a row); worn it holds OXY_SLOTS
## fish whose vitality doesn't run down (GameState.oxy_fish) - each one put in
## or taken out wears it by one. What's in it must be escaped with, like
## whatever's carried.
## User request: the shovel (the user's model) - an off-hand thing, bought once;
## held in a run, it digs (Player.dig: the frost flower's soil -> 冷凍土); each
## dig wears it by one.
const SHOVEL_COST := 100
const SHOVEL_DESC := "副手裝備：拿在手上時，在冷凍花的冰冷根部按「挖掘」，可以挖出冷凍土。每次挖掘用掉 1 點耐久"
const OXY_BOX_COST := 150
## User request: the live-fish clasp (活魚扣) - worn in one of the three slots that were
## locked, a fish from the bag or the warehouse hung on it (one hook, one fish): it
## doesn't take bag room, but its vitality and freshness still run down, and it goes
## on the run.
const CLASP_COST := 220
const CLASP_SLOTS := ["clasp1", "clasp2", "clasp3"]
const CLASP_DESC := "裝備在角色的扣魚欄：點裝備上去的活魚扣，會出現帶「＋」的空格，把背包或倉庫裡的魚掛上去（一個空格一條魚，不管魚本身多大）。掛著的魚不佔背包格子，活性和新鮮度照樣倒數、也會一起出發；適合把帶醃製詞綴或不死的魚扣在身上管理。要卸下活魚扣，得先把魚取下來"
const OXY_SLOTS := 6
const OXY_BOX_DESC := "副手裝備：打開後有六格，放進去的魚活性不會下降。放進、拿出各用掉 1 點耐久；沒有逃脫成功，裡面的魚一樣帶不出來。沒裝備時佔背包六格"
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
var settings: Dictionary = {"auto_lure": false, "damage_numbers": true}
## User request (the camp): the tent pitched at the camp (CampStage's
## tent_<n> model; 8, the bare lean-to, to start - better ones are earned).
var camp_tent: int = 8

## User request: the four greybox animal people in the game (tools/
## owl_character.py's player(), PLAYER=<id>), each with its own pictures
## (CharacterArt); the camp's fire opens the picker (CharacterPage) to
## choose who's travelling. And (user request) two more after the user's
## deer and ram: the stag and the sheep. And (user request) the user's own
## Meshy ones beside them - the old ones stay: a bear, two dogs, a deer, a
## horned owl, a croc and a sheep (tools/build_meshy_character.py). Made
## less alike (user request): the old owl a snowy owl, the Meshy bear a
## Formosan black bear, its deer a sika deer and its sheep black-faced
## (build_meshy_character's recolour). Then (user request) the old ones in
## the new ones' outfit and painted as finely (tools/paint_pelt.py): the
## dog a chihuahua, the bear a brown bear, the deer a red deer stag, the
## sheep white all over. (User request: the shiba taken out; the same kinds
## side by side in the picker, to compare.) [id, name].
const CHARACTERS := [["cat", "黑貓"], ["owl", "雪鴞"], ["owl2", "角鴞"], ["dog", "吉娃娃"], ["dog3", "牧羊犬"],
	["bear", "棕熊"], ["bear2", "台灣黑熊"], ["deer", "紅鹿"], ["deer2", "梅花鹿"], ["sheep", "綿羊"],
	["sheep2", "黑面羊"], ["croc", "鱷魚"]]
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
		"desc": "使用後 20 秒，看得見大鬼在哪個方向（會跟著牠移動）"},
	"binoculars": {"name": "望遠鏡", "cost": 90, "stack": 1, "keep": true,
		"desc": "望向遠方找出最近的水域（指引 20 秒）；不會用掉，用過要等 60 秒"},
	# User request: the glow mushroom - not sold, only picked under the
	# map's trees (GlowMushroom); its cost only ranks it (UiKit's rarity).
	"glow_mushroom": {"name": "發光蘑菇", "cost": 12, "stack": 5, "keep": false, "sold": false,
		"desc": "長在樹下、在黑暗裡默默發著藍光的蘑菇。揉碎撒在身上，30 秒內全身散發微弱的藍光，照亮身邊一圈（約 2.4 公尺）"},
	# User request: found on the map, used on a carried fish (FishLife.use_oxy_tree
	# / use_frozen) - not sold. 魚氧樹 grows only at the water's edge (OxyTree);
	# 冷凍土 is dug from the frost flower's cold patch (FrostFlower, with the shovel).
	"oxy_tree": {"name": "魚氧樹", "cost": 15, "stack": 5, "keep": false, "sold": false, "target": "fish",
		"desc": "只長在水邊、冒著氧氣微氣泡的小樹。整顆揉碎，塗在背包裡一條魚的魚鰓上：魚離開水面也能撐久一點，180 秒內活性下降速度只剩 1/4"},
	"frozen_soil": {"name": "冷凍土", "cost": 15, "stack": 5, "keep": false, "sold": false, "target": "fish",
		"desc": "冷凍花根部蔓延處挖出來的土，涼得刺手。用在背包裡的一條魚身上：300 秒內新鮮度下降速度大幅降低（只剩 1/4）"},
	# User request (weak fish): bought at the shop - gives a fish's vitality back
	# (and un-weakens it); fed in a run (from the bag) or at home (fish card).
	"vigor_feed": {"name": "活力飼料", "cost": 40, "stack": 5, "keep": false, "target": "fish",
		"desc": "餵給一條活魚：活性恢復一半，虛弱的魚也會恢復過來（不再倒數虛弱）"},
	# User request: the syringe - a dead fish lives again, but weak.
	"revive_needle": {"name": "復活針", "cost": 150, "stack": 3, "keep": false, "target": "fish",
		"desc": "打在一條剛死的魚（還沒腐敗）身上：牠會復活，但立刻陷入虛弱（活性 5%，快放進魚缸或餵飼料）"},
	# User request: the dropper bottle - the stat affixes drawn again.
	"affix_dropper": {"name": "洗點滴瓶", "cost": 80, "stack": 5, "keep": false, "target": "fish",
		"desc": "滴在一條魚身上：牠的屬性詞綴（力量／韌性／反應／耐力）在各自那一階的範圍內重新抽一次數值"},
	# User request (醃製): salt for a fish that's dead and not yet rotten.
	"salt": {"name": "鹽巴", "cost": 12, "stack": 10, "keep": false, "target": "fish",
		"desc": "撒在一條死掉、還沒腐敗的魚身上：有 5% 機率醃製成功，魚會多出 1～4 條素質詞綴（越稀有越可能多，數值 2～6，種類可以重複），而且不會再變不新鮮。沒成功鹽就用掉了"},
}
const USABLE_ORDER := ["potion_vigor", "potion_ward", "eyeball", "eye_altar", "eye_ghost", "binoculars", "glow_mushroom",
	"oxy_tree", "frozen_soil", "vigor_feed", "revive_needle", "affix_dropper", "salt"]

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


## User request: each character's starting stats (the five: 反應 react, 力量 might,
## 韌性 resil, 耐力 endure, 幸運 luck) - 10 points each, spread by the animal's
## nature. No levelling (everything after comes from the rod, talent, fish, gear).
const START_STATS := {
	"cat": {"react": 4, "luck": 3, "endure": 2, "resil": 1},
	"owl": {"endure": 4, "react": 3, "resil": 2, "luck": 1},
	"owl2": {"react": 4, "endure": 2, "luck": 2, "resil": 1, "might": 1},
	"dog": {"react": 4, "resil": 3, "luck": 2, "endure": 1},
	"dog3": {"endure": 4, "react": 2, "resil": 2, "might": 1, "luck": 1},
	"bear": {"might": 5, "resil": 3, "endure": 2},
	"bear2": {"might": 4, "endure": 3, "resil": 2, "react": 1},
	"deer": {"react": 3, "endure": 3, "luck": 3, "resil": 1},
	"deer2": {"luck": 4, "react": 3, "endure": 2, "resil": 1},
	"sheep": {"endure": 3, "resil": 3, "luck": 2, "might": 1, "react": 1},
	"sheep2": {"resil": 4, "endure": 3, "might": 2, "luck": 1},
	"croc": {"might": 4, "resil": 4, "endure": 2},
}


## User request (talents): the talent each character took in place of its own
## ability (Abilities.TALENTS ids; none: its own ability).
var talents: Dictionary = {}


func talent_of(id: String = character) -> String:
	var t: String = talents.get(id, "")
	return t if Abilities.TALENTS.has(t) else ""


func set_talent(id: String, talent: String) -> void:
	if talent == "" or not Abilities.TALENTS.has(talent):
		talents.erase(id)
	else:
		talents[id] = talent
	_changed()


## The character's name (CHARACTERS).
func character_name(id: String = character) -> String:
	for c in CHARACTERS:
		if c[0] == id:
			return c[1]
	return id


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
	recover_unfinished_run()


## User request (weak fish): the fish brought on a run are copied here for its
## length - a run that never ended (the player left) puts them in the tank on
## the next start; the run's finds and catches are gone with it.
var run_brought: Array = []

## Names of the fish that came back weak from a lost night (the camp warns).
var weak_news: Array = []

## The camp's warning is open: weak fish don't run down meanwhile.
var aging_paused := false


func note_run_brought(list: Array) -> void:
	run_brought = []
	for f in list:
		run_brought.append(f.duplicate(true))
	_changed()


func clear_run_brought() -> void:
	if not run_brought.is_empty():
		run_brought = []
		_changed()


## Left in the middle of a run: what was brought goes into the tank (full - the
## warehouse; dead - the bucket), sound as it was packed.
func recover_unfinished_run() -> void:
	if run_brought.is_empty():
		return
	var list := run_brought
	run_brought = []
	for f in list:
		f.erase("brought")
		f.erase("cell")
		f.erase("rot")
		if FishLife.state(f) == "alive" and add_to_tank(f):
			continue
		if FishLife.state(f) != "alive" and add_to_fish_box(f):
			continue
		if stash_fish.size() < STASH_SIZE:
			stash_fish.append(f)
	_changed()


## A weak fish (or any) back in the bag - the first free corner, else the warehouse.
func put_in_pack(f: Dictionary) -> void:
	f.erase("cell")
	f.erase("rot")
	var at := pack_first_fit(f)
	if at.x >= 0:
		f["cell"] = [at.x, at.y]
		pack_fish.append(f)
	elif stash_fish.size() < STASH_SIZE:
		stash_fish.append(f)
	_changed()


## The fish hung on the clasps worn (see CLASP_COST): each has `hook` (a hook's id).
var clasp_fish: Array = []


## The hooks there are: [{id ("clasp1:0"), slot}] over the clasps worn.
func clasp_hooks() -> Array:
	var out := []
	for slot in CLASP_SLOTS:
		var id: String = equipped.get(slot, "")
		for n in int(Items.def(id).get("hooks", 0)) if id != "" else 0:
			out.append({"id": "%s:%d" % [slot, n], "slot": slot})
	return out


## The first hook with nothing on it ("" if none).
func clasp_free_hook() -> String:
	var taken := clasp_fish.map(func(f): return f.get("hook", ""))
	for h in clasp_hooks():
		if h.id not in taken:
			return h.id
	return ""


## The fish on the hook `id`, as an index into clasp_fish (-1: none).
func hooked_at(hook: String) -> int:
	for i in clasp_fish.size():
		if clasp_fish[i].get("hook", "") == hook:
			return i
	return -1


## Does a clasp worn in `slot` have fish on it?
func clasp_busy(slot: String) -> bool:
	return clasp_fish.any(func(f): return str(f.get("hook", "")).begins_with(slot + ":"))


## Hangs a fish from the bag or the warehouse (`from`: "pack"/"stash", index `i`) on
## the hook `hook` ("" the first free). "" if done, else why not.
func hang_fish(from: String, i: int, hook := "") -> String:
	if hook != "" and hooked_at(hook) >= 0:
		return "這個扣環上有魚了"
	var why := move_fish(from, i, "clasp")
	if why != "" or hook == "":
		return why
	var f: Dictionary = clasp_fish.back()
	f["hook"] = hook
	_changed()
	return ""


## After a run (or a load): a fish that was hung comes back to its hook - its hook gone,
## to the bag or the warehouse instead.
func return_clasped(f: Dictionary) -> void:
	f.erase("clasped")
	var hook: String = f.get("hook", "")
	if hook != "" and hooked_at(hook) < 0 and clasp_hooks().any(func(h): return h.id == hook):
		clasp_fish.append(f)
	else:
		f.erase("hook")
		put_in_pack(f)
	_changed()


## Fish whose hook is gone (a clasp taken off) go to the bag or the warehouse.
func _sync_clasp() -> void:
	var ids := clasp_hooks().map(func(h): return h.id)
	for f in clasp_fish.duplicate():
		if f.get("hook", "") not in ids:
			clasp_fish.erase(f)
			f.erase("hook")
			put_in_pack(f)


func weak_count() -> int:
	var n := 0
	for list in [pack_fish, stash_fish, fish_box, clasp_fish]:
		for f in list:
			if f.get("weak", false):
				n += 1
	return n


## All the weak fish into the tank (as many as fit). How many went.
func weak_to_tank() -> int:
	var moved := 0
	for name in ["pack_fish", "stash_fish"]:
		var list: Array = get(name)
		for f in list.duplicate():
			if f.get("weak", false) and tank.size() < TANK_SIZE:
				list.erase(f)
				f.erase("cell")
				f.erase("rot")
				if add_to_tank(f):
					moved += 1
				else:
					list.append(f)
	tank_news.clear()
	_changed()
	return moved


## User request (the gate): kinds seen but never landed - a shadow in the fish
## log (species ids). A kind already in the log isn't noted.
var shadows: Array = []


func note_shadow(id: String, species_name: String) -> void:
	if id != "" and not id in shadows and not fish_log.has(species_name):
		shadows.append(id)
		_changed()


func record_catch(fish_name: String, value: float, length := 0.0, tank_trait := "", legend := false) -> void:
	shadows.erase(FishData.id_for(fish_name))
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
	if not storage_room("lure_" + id):
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
	if not storage_room("live_" + key):
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


## Buys a rod (into the warehouse; the shop asks where it goes) - any tier at
## any time (user request: save up and buy the best straight away); none given:
## the next one up. False if it's already owned (or the gold's short).
func buy_rod(tier := -1) -> bool:
	if tier < 0:
		tier = rods_owned + 1
	if tier >= ROD_TIERS.size() or owned("rod_%d" % tier) > 0 or gold < int(ROD_TIERS[tier].cost):
		return false
	if not storage_room("rod_%d" % tier):
		return false
	_spend(int(ROD_TIERS[tier].cost))
	rods_owned = maxi(rods_owned, tier)
	_store("rod_%d" % tier, 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_flashlight() -> bool:
	if owned("flashlight") > 0 or gold < FLASHLIGHT_COST:
		return false
	if not storage_room("flashlight"):
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
	if not storage_room(id):
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
	if not storage_room("net"):
		return false
	_spend(NET_COST)
	_store("net", 1)
	gold_updated.emit(gold)
	_changed()
	return true


## The oxygenated fish box, bought once, into the warehouse.
func buy_fish_clasp() -> bool:
	if owned("fish_clasp") > 0 or gold < CLASP_COST:
		return false
	if not storage_room("fish_clasp"):
		return false
	_spend(CLASP_COST)
	_store("fish_clasp", 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_oxy_box() -> bool:
	if owned("oxy_box") > 0 or gold < OXY_BOX_COST:
		return false
	if not storage_room("oxy_box"):
		return false
	_spend(OXY_BOX_COST)
	_store("oxy_box", 1)
	gold_updated.emit(gold)
	_changed()
	return true


## The shovel, bought once, into the warehouse.
func buy_shovel() -> bool:
	if owned("shovel") > 0 or gold < SHOVEL_COST:
		return false
	if not storage_room("shovel"):
		return false
	_spend(SHOVEL_COST)
	_store("shovel", 1)
	gold_updated.emit(gold)
	_changed()
	return true


func has_shovel() -> bool:
	return equipped.get("offhand", "") == "shovel"


func has_oxy_box() -> bool:
	return equipped.get("offhand", "") == "oxy_box"


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
	if not storage_room("ammo"):
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
	if not d.get("sold", true) or gold < int(d.cost) or (d.keep and owned(id) > 0):
		return false
	if not storage_room(id):
		return false
	_spend(int(d.cost))
	_store(id, 1)
	gold_updated.emit(gold)
	_changed()
	return true


func buy_battery() -> bool:
	if gold < BATTERY_COST:
		return false
	if not storage_room("battery"):
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
	if tank.size() >= TANK_SIZE or FishLife.state(fish) != "alive":
		return false
	# (what the fortune fish sent so far is paid before a new one comes)
	settle_fortune()
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


## User request: the fish brought home dead (or rotten) are kept here
## (a catch dict each) to be sold to the merchant - a rotten one is no use
## (yet): thrown away. (They age at home now: age_home.)
## User request (魚桶): it is a bucket now - how many fit.
const FISH_BOX_SIZE := 24
var fish_box: Array = []


## User request: at home, the fish in the bucket, the bag and the warehouse
## run down (a live one's vitality, then a dead one's freshness) as the game
## runs; only the tank keeps them as they are. Not on a run (the carried fish
## age there).
func age_home(delta: float) -> void:
	if aging_paused:
		return
	for list in [fish_box, pack_fish, stash_fish, clasp_fish]:
		for f in list:
			FishLife.ensure(f)
			FishLife.tick(f, delta, GameState.is_night)


## Fish from before the life system (or from old saves) get theirs rolled -
## else they'd never run down. Every list.
func ensure_fish_life() -> void:
	for list in [tank, fish_box, pack_fish, stash_fish, clasp_fish]:
		for f in list:
			FishLife.ensure(f)


## (the bucket alone, as before: the test's)
func age_bucket(delta: float) -> void:
	for f in fish_box:
		FishLife.tick(f, delta, GameState.is_night)


## Puts a dead (or rotten) fish brought home in the box. False if it's full.
func add_to_fish_box(fish: Dictionary) -> bool:
	if fish_box.size() >= FISH_BOX_SIZE:
		return false
	var f := fish.duplicate()
	f.erase("tier")
	fish_box.append(f)
	_changed()
	return true


## Sells the box's fish at `index` (not a rotten one); the gold made.
func sell_from_box(index: int) -> int:
	return sell_fish("box", index)


## How many in the box can be sold (the rotten can't), and what they'd bring.
func box_sellable() -> int:
	var n := 0
	for f in fish_box:
		if FishLife.state(f) != "rotten":
			n += 1
	return n


func box_worth() -> int:
	var total := 0
	for f in fish_box:
		total += FishLife.sale_value(f)
	return total


## Sells all that can be; the gold made.
func sell_box_all() -> int:
	var total := 0
	for i in range(fish_box.size() - 1, -1, -1):
		total += sell_from_box(i)
	return total


## Throws the box's fish at `index` away.
func discard_from_box(index: int) -> void:
	if index >= 0 and index < fish_box.size():
		fish_box.remove_at(index)
		_changed()


## User request: fish can be taken out of the tank (and put back): into the
## bag (pack_fish: carried on the next run - lost with it if it's lost),
## or the warehouse (stash_fish). The dead and the rotten, in the fish box,
## can be moved the same way (a rotten wraith goes in the bag); only a living
## one goes back in the tank. None of them age at home.
const STASH_SIZE := 20
var pack_fish: Array = []
var stash_fish: Array = []


## The fish list `place` names ("tank", "box", "pack", "stash").
func fish_list(place: String) -> Array:
	match place:
		"tank":
			return tank
		"box":
			return fish_box
		"pack":
			return pack_fish
		"clasp":
			return clasp_fish
	return stash_fish


## Where fish `f` may be put (besides where it is): living - the tank; dead
## or rotten - the fish box; both - the bag, the warehouse.
func fish_places(f: Dictionary, from: String) -> Array:
	var out := ["pack", "stash", "box"]
	if FishLife.state(f) == "alive":
		out.push_front("tank")
	# (the clasp: with a free hook, from the bag or the warehouse)
	if clasp_free_hook() != "" and from in ["pack", "stash"]:
		out.append("clasp")
	out.erase(from)
	return out


## Why fish `f` can't go to `to` ("" it can).
func fish_refusal(f: Dictionary, to: String) -> String:
	match to:
		"tank":
			if FishLife.state(f) != "alive":
				return "只有活著的魚能放進魚缸"
			if tank.size() >= TANK_SIZE:
				return "魚缸滿了"
		"box":
			if fish_box.size() >= FISH_BOX_SIZE:
				return "魚桶滿了"
		"pack":
			var items := Inventory.items(null)
			for p in pack_fish:
				items.append(Inventory.fish_item(p))
			var mine := Inventory.fish_item(f)
			mine.erase("cell")
			items.append(mine)
			if Inventory.pack(items).is_empty():
				return "背包放不下"
		"stash":
			if stash_fish.size() >= STASH_SIZE:
				return "倉庫放不下了"
		"clasp":
			if clasp_free_hook() == "":
				return "沒有空的扣環（先裝備活魚扣）"
	return ""


## Moves a fish from list `from` (index `i`) to `to`. "" if done, else why not.
func move_fish(from: String, i: int, to: String, at := Vector2i(-1, -1)) -> String:
	var src := fish_list(from)
	if i < 0 or i >= src.size() or from == to:
		return "找不到這條魚"
	var f: Dictionary = src[i]
	var why := fish_refusal(f, to)
	if why != "":
		return why
	# User request: put in the bag or the warehouse, it goes where the player
	# set it (a cell of the bag's grid, a slot of the warehouse's), if it's
	# somewhere it fits; else the first place there is.
	FishLife.ensure(f)
	f.erase("cell")
	f.erase("slot")
	f.erase("hook")
	if to == "clasp":
		f.erase("rot")
		f["hook"] = clasp_free_hook()
	if to == "pack" and at.x >= 0:
		if not pack_fits(f, at):
			return "放不下這裡"
		f["cell"] = [at.x, at.y]
	elif to == "stash" and at.x >= 0:
		if not stash_free(at.x):
			return "這格有魚了"
		f["slot"] = at.x
	# (the fortune fish's gold up to now - it may be leaving the tank)
	settle_fortune()
	src.remove_at(i)
	fish_list(to).append(f)
	if to == "tank":
		tank_news.clear()
	_changed()
	return ""


## A fish already in the bag set down at `cell` (if it fits there).
func relocate_pack_fish(i: int, cell: Vector2i) -> bool:
	if i < 0 or i >= pack_fish.size() or not pack_fits(pack_fish[i], cell):
		return false
	pack_fish[i]["cell"] = [cell.x, cell.y]
	_changed()
	return true


## The bag's cells taken by what's packed (the bag's things and the fish in
## it, the fish `except` left out): {cell: true}.
func pack_used(except: Dictionary = {}) -> Dictionary:
	var used := {}
	var items := Inventory.items(null)
	for p in pack_fish:
		if p != except:
			items.append(Inventory.fish_item(p))
	var placed := Inventory.pack(items)
	for k in placed.size():
		var r: Rect2i = placed[k]
		for dx in r.size.x:
			for dy in r.size.y:
				used[r.position + Vector2i(dx, dy)] = true
	return used


## Would fish `f` fit in the bag with its corner at `at`?
func pack_fits(f: Dictionary, at: Vector2i) -> bool:
	return Inventory._free(pack_used(f), at, Inventory.fish_item(f).size, Inventory.ROWS) \
		and at.y + Inventory.fish_item(f).size.y <= bag_rows()


## Where the bag's fish are (same order as pack_fish): their rectangles.
func pack_places() -> Array:
	var items := Inventory.items(null)
	var base := items.size()
	for p in pack_fish:
		items.append(Inventory.fish_item(p))
	var placed := Inventory.pack(items)
	return placed.slice(base) if not placed.is_empty() else []


## The first free corner for fish `f` in the bag, or (-1, -1).
func pack_first_fit(f: Dictionary) -> Vector2i:
	var used := pack_used(f)
	var size: Vector2i = Inventory.fish_item(f).size
	for x in Inventory.COLS - size.x + 1:
		for y in bag_rows() - size.y + 1:
			if Inventory._free(used, Vector2i(x, y), size, Inventory.ROWS):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Is warehouse slot `n` free (not taken by a fish already there)?
func stash_free(n: int, except: Dictionary = {}) -> bool:
	if n < 0 or n >= STASH_SIZE:
		return false
	for f in stash_fish:
		if f != except and stash_slot(f) == n:
			return false
	return true


## The slot fish `f` is in (set, else the first free by its place in the
## list - the old saves').
func stash_slot(f: Dictionary) -> int:
	if f.has("slot"):
		return int(f.slot)
	var taken := {}
	for g in stash_fish:
		if g.has("slot"):
			taken[int(g.slot)] = true
	var n := 0
	for g in stash_fish:
		if g == f:
			break
		if not g.has("slot"):
			while taken.has(n):
				n += 1
			taken[n] = true
	while taken.has(n) and not f.has("slot"):
		n += 1
	return n


func stash_first_free() -> int:
	for n in STASH_SIZE:
		if stash_free(n):
			return n
	return -1


func clear_tank_news() -> void:
	tank_news.clear()
	_save()


## Sells the tank's fish at `index`; the gold made (what any fish brings,
## wherever it's sold: FishLife.sale_value).
func sell_from_tank(index: int) -> int:
	if index < 0 or index >= tank.size():
		return 0
	settle_fortune()
	return sell_fish("tank", index)


## User request: one price for a fish wherever it's sold (the tank page's
## 販售 and the merchant's 收購): FishLife.sale_value - its full value while it
## lives, less as it goes stale when dead, nothing rotten. Sells fish `i` of
## list `place` ("tank", "box", "pack", "stash"); the gold made (0 if it can't
## be sold: rotten).
func sell_fish(place: String, i: int) -> int:
	var list := fish_list(place)
	if i < 0 or i >= list.size():
		return 0
	var price := FishLife.sale_value(list[i])
	if price <= 0:
		return 0
	list.remove_at(i)
	gold += price
	gold_updated.emit(gold)
	_changed()
	return price


## Throws fish `i` of list `place` away.
func discard_fish(place: String, i: int) -> void:
	var list := fish_list(place)
	if i >= 0 and i < list.size():
		list.remove_at(i)
		_changed()


# --- Selling back (收購) --------------------------------------------------

## User request: the merchant buys what's brought back - everything but the
## rods and the base bait - at this share of what it sells it for new, and
## the less a worn thing has left of its uses, the less it's worth.
const BUYBACK := 0.5
## What the merchant takes for a thing found on the map (not sold new): its
## own cost (the table's) - a few coins' worth.
const BUYBACK_FOUND := 0.4


## What the shop sells `id` for new (0: it doesn't).
func shop_cost(id: String) -> int:
	if id.begins_with("rod_"):
		return int(ROD_TIERS[clampi(int(id.substr(4)), 0, ROD_TIERS.size() - 1)].cost)
	match id:
		"flashlight": return FLASHLIGHT_COST
		"battery": return BATTERY_COST
		"ammo": return AMMO_COST
		"net": return NET_COST
		"shovel": return SHOVEL_COST
		"oxy_box": return OXY_BOX_COST
		"fish_clasp": return CLASP_COST
	if WEAPONS.has(id):
		return int(WEAPONS[id].cost)
	if id.begins_with("live_") and LIVE_BAITS.has(id.substr(5)):
		return int(LIVE_BAITS[id.substr(5)].cost)
	if id.begins_with("lure_") and LURES.has(id.substr(5)):
		return int(LURES[id.substr(5)].cost)
	if USABLES.has(id):
		return int(USABLES[id].cost)
	if SNACKS.has(id):
		return int(SNACKS[id].cost)
	return 0


## Can the merchant buy `id` back at all?
func buyback_ok(id: String) -> bool:
	if id.begins_with("rod_") or id == "lamp" or Items.def(id).is_empty() or bool(Items.def(id).get("fixed", false)):
		return false
	return shop_cost(id) > 0


## What the merchant pays for one `id` now: the share of its new price,
## times how much of its uses are left (0: it won't buy).
func buyback_price(id: String) -> int:
	if not buyback_ok(id):
		return 0
	var rate := BUYBACK if not (USABLES.has(id) and not bool(USABLES[id].get("sold", true))) else BUYBACK_FOUND
	var worn := 1.0
	var most := max_durability(id)
	if most > 0:
		worn = clampf(float(durability(id)) / most, 0.0, 1.0)
	return maxi(1, roundi(shop_cost(id) * rate * worn))


## Sells `count` of `id` from the warehouse ("storage") or the bag stack at
## `index` ("bag") to the merchant; the gold made (0: not bought).
func sell_item(from: String, id: String, count := 1, index := -1) -> int:
	var price := buyback_price(id)
	if price <= 0 or count <= 0:
		return 0
	var n := 0
	if from == "storage":
		n = mini(count, stored(id))
		if n <= 0:
			return 0
		storage[id] = stored(id) - n
		if stored(id) <= 0:
			storage.erase(id)
	elif from == "bag" and index >= 0 and index < bag.size() and bag[index].id == id:
		n = mini(count, int(bag[index].count))
		bag[index].count -= n
		if int(bag[index].count) <= 0:
			bag.remove_at(index)
	if n <= 0:
		return 0
	# (the last of a worn thing sold: its wear goes with it)
	if owned(id) <= 0:
		wear.erase(id)
	gold += price * n
	gold_updated.emit(gold)
	_changed()
	return price * n


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
## User request: the warehouse has cells like the bag (about 2.4 times its 35):
## everything takes the room it does in the bag - a rod 3 x 1, a weapon its
## length - and a stack (`Items.stack_of`) a cell's worth. The stacks are laid
## out by `pack_cells` (the big ones first); overflow from a run or a reward
## just makes the list longer, but what's put in by hand must fit.
const STORAGE_COLS := 7
const STORAGE_ROWS := 12


## The warehouse's stacks, [{id, count}], the biggest first (then in the usual order).
func storage_stacks(extra := {}) -> Array:
	var counts := storage.duplicate()
	for id in extra:
		counts[id] = int(counts.get(id, 0)) + int(extra[id])
	var ids := []
	for id in counts:
		if int(counts[id]) > 0:
			ids.append(id)
	ids = Items.sort_ids(ids)
	var order := {}
	for i in ids.size():
		var sz := Items.size_of(ids[i])
		order[ids[i]] = -sz.x * sz.y * 1000 + i
	ids.sort_custom(func(a, b): return order[a] < order[b])
	var out := []
	for id in ids:
		var left: int = int(counts[id])
		var per := maxi(Items.stack_of(id), 1)
		while left > 0:
			out.append({"id": id, "count": mini(left, per)})
			left -= per
	return out


## First-fit packing of `sizes` (Vector2i) into `cols` columns, from the top
## left, into `taken` (a Dictionary of used cells, shared so more can follow):
## [each one's top-left cell, ...] and the rows used.
static func pack_cells(sizes: Array, cols: int, taken := {}) -> Array:
	var cells := []
	for sz: Vector2i in sizes:
		var placed := false
		var y := 0
		while not placed:
			for x in range(0, cols - sz.x + 1):
				var free := true
				for dx in sz.x:
					for dy in sz.y:
						if taken.has(Vector2i(x + dx, y + dy)):
							free = false
				if free:
					for dx in sz.x:
						for dy in sz.y:
							taken[Vector2i(x + dx, y + dy)] = true
					cells.append(Vector2i(x, y))
					placed = true
					break
			y += 1
	return cells


## The warehouse laid out: [{id, count, cell, size}] for the things, then
## [{fish: index, cell, size}] for the fish put in it.
func storage_layout() -> Array:
	var stacks := storage_stacks()
	var entries := []
	var sizes := []
	for st in stacks:
		sizes.append(Items.size_of(st.id))
		entries.append(st)
	for i in stash_fish.size():
		sizes.append(Inventory.fish_item(stash_fish[i]).size)
		entries.append({"fish": i})
	var taken := {}
	var cells := pack_cells(sizes, STORAGE_COLS, taken)
	for i in entries.size():
		entries[i]["cell"] = cells[i]
		entries[i]["size"] = sizes[i]
	return entries


## Rows the things (not the fish) take, with `extra` ({id: count}) more.
func storage_rows(extra := {}) -> int:
	var sizes := storage_stacks(extra).map(func(st): return Items.size_of(st.id))
	var taken := {}
	pack_cells(sizes, STORAGE_COLS, taken)
	var rows := 0
	for c: Vector2i in taken:
		rows = maxi(rows, c.y + 1)
	return rows


## Is there room to put `count` more of `id` in the warehouse?
func storage_room(id: String, count := 1) -> bool:
	return storage_rows({id: count}) <= STORAGE_ROWS


func storage_ids(tab := "") -> Array:
	var ids := []
	for id in storage:
		if int(storage[id]) > 0 and (tab == "" or Items.def(id).get("tab", "other") == tab):
			ids.append(id)
	return Items.sort_ids(ids)


## Does `id` fit in the bag with its top-left at `cell` (not counting the
## stack at index `ignore`), laid the other way if `rot`?
func bag_fits(id: String, cell: Vector2i, ignore := -1, rot := false) -> bool:
	var rect := Rect2i(cell, Items.size_rot(id, rot))
	if cell.x < 0 or cell.y < 0 or rect.end.x > Inventory.COLS or rect.end.y > bag_rows():
		return false
	for i in bag.size():
		if i != ignore and Rect2i(bag[i].cell, bag_size_of(i)).intersects(rect):
			return false
	return true


## The cells the bag stack at `i` takes (turned if it is).
func bag_size_of(i: int) -> Vector2i:
	return Items.size_rot(bag[i].id, bool(bag[i].get("rot", false)))


## The first place `id` fits (down each column in turn), or (-1, -1).
func bag_free_cell(id: String, ignore := -1, rot := false) -> Vector2i:
	for x in Inventory.COLS:
		for y in bag_rows():
			if bag_fits(id, Vector2i(x, y), ignore, rot):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## User request: the bag is 7 x 5 now (it was 8 x 4): what a save had out of
## its bounds is put again in the first free place (what doesn't fit goes to the
## warehouse).
func relayout_bag() -> void:
	var out := []
	for i in range(bag.size() - 1, -1, -1):
		var e: Dictionary = bag[i]
		var cell = e.get("cell", Vector2i(-1, -1))
		var c := Vector2i(cell) if cell is Vector2i else Vector2i(-1, -1)
		var rect := Rect2i(c, Items.size_rot(e.id, bool(e.get("rot", false))))
		if c.x < 0 or c.y < 0 or rect.end.x > Inventory.COLS or rect.end.y > Inventory.ROWS:
			out.append(e)
			bag.remove_at(i)
	for e in out:
		var free := bag_free_cell(e.id, -1, bool(e.get("rot", false)))
		if free.x >= 0:
			e["cell"] = free
			bag.append(e)
		else:
			_store(e.id, int(e.get("count", 1)))
	for f in pack_fish.duplicate():
		var fc = f.get("cell", null)
		var size: Vector2i = Inventory.fish_item(f).size
		if fc == null or int(fc[0]) + size.x > Inventory.COLS or int(fc[1]) + size.y > Inventory.ROWS:
			pack_fish.erase(f)
			f.erase("cell")
			var at := pack_first_fit(f)
			if at.x >= 0:
				f["cell"] = [at.x, at.y]
				pack_fish.append(f)
			else:
				stash_fish.append(f)


## The bag stack covering `cell`, or -1.
func bag_at(cell: Vector2i) -> int:
	for i in bag.size():
		if Rect2i(bag[i].cell, bag_size_of(i)).has_point(cell):
			return i
	return -1


## User request: turns the bag stack at `index` (lying <-> standing), where
## it is if it fits so, else at the first place it does. False if it's not
## more than a cell (or there's no room turned).
func bag_rotate(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var e: Dictionary = bag[index]
	var size := Items.size_of(e.id)
	if size.x == size.y:
		return false
	var turned := not bool(e.get("rot", false))
	var at: Vector2i = e.cell
	if not bag_fits(e.id, at, index, turned):
		at = bag_free_cell(e.id, index, turned)
		if at.x < 0:
			return false
	e["rot"] = turned
	e.cell = at
	_changed()
	return true


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
## Is there room in the bag for one more of `id` (a stack with space, or a cell)?
func bag_has_room(id: String) -> bool:
	var stack := Items.stack_of(id)
	for e in bag:
		if e.id == id and int(e.count) < stack:
			return true
	return bag_free_cell(id).x >= 0


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


## User request: dying in a run loses the fish and anything picked up on
## the map there (note_found: the glow mushrooms, live baits caught or
## turned up, what the dog sniffed out...) - as many of each as were found,
## so long as they're still in the bag; what was brought in stays.
func lose_found_gear() -> void:
	for id in found_this_run:
		bag_take(id, int(found_this_run[id]))
	found_this_run.clear()
	_changed()


## What's been picked up on the map this run: {item id: how many}
## (GameState.start_run clears it).
var found_this_run := {}


## `count` of `id` picked up on the map (into the bag).
func note_found(id: String, count: int) -> void:
	if count > 0:
		found_this_run[id] = int(found_this_run.get(id, 0)) + count


## `count` of `id` put down again out of the bag: as many of them as were
## found go back to being the map's (how many: carried by the DroppedItem).
func unnote_found(id: String, count: int) -> int:
	var n := mini(count, int(found_this_run.get(id, 0)))
	if n > 0:
		found_this_run[id] = int(found_this_run[id]) - n
		if int(found_this_run[id]) <= 0:
			found_this_run.erase(id)
	return n


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
	# (only as many as the warehouse has room for)
	while n > 0 and not storage_room(e.id, n):
		n -= 1
	if n <= 0:
		return 0
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
	if not bag_fits(e.id, cell, index, bool(e.get("rot", false))):
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
## One of `id` for use at home: from the bag, else the warehouse. False if none.
## Every fish at camp: [{fish, src, index, where}] - the bag, the tank, the
## warehouse and the bucket (src: move_fish's "pack" / "tank" / "stash" / "box").
func home_fish() -> Array:
	var out := []
	for pair in [["pack", pack_fish, "背包"], ["clasp", clasp_fish, "活魚扣"], ["tank", tank, "魚缸"], ["stash", stash_fish, "倉庫"], ["box", fish_box, "魚桶"]]:
		for i in (pair[1] as Array).size():
			out.append({"fish": pair[1][i], "src": pair[0], "index": i, "where": pair[2]})
	return out


## User request (the camp's bag page): a fish item (USABLES "target": "fish")
## used on one of the fish at camp. "" and `lines` (what it did) if it worked,
## else why not.
func use_on_home_fish(id: String, f: Dictionary, lines: Array) -> String:
	if bag_count(id) + stored(id) <= 0:
		return "沒有了"
	var why := FishLife.apply_item(id, f, lines)
	if why != "":
		return why
	take_one(id)
	_changed()
	return ""


func take_one(id: String) -> bool:
	if bag_take(id, 1) > 0:
		return true
	if stored(id) > 0:
		storage[id] = stored(id) - 1
		_changed()
		return true
	return false


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
func equip(id: String, bag_index := -1, want := "") -> bool:
	var slot := _slot_for(id, want)
	if slot == "" or equipped.get(slot, "") == id:
		return false
	# (a clasp with fish hung on it stays put)
	if slot.begins_with("clasp") and clasp_busy(slot):
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


## The slot `id` goes in: its own, or - a clasp - the one asked for, else the first
## empty of the three, else the first.
func _slot_for(id: String, want := "") -> String:
	var slot: String = Items.def(id).get("slot", "")
	if slot != "clasp":
		return slot
	if want in CLASP_SLOTS:
		return want
	for k in CLASP_SLOTS:
		if equipped.get(k, "") == "":
			return k
	return CLASP_SLOTS[0]


## User request (the bag in a run): puts on the thing in the bag stack at
## `index` - what was worn in its slot goes into the bag in its place
## (where it fits, else anywhere) - false if it can't: nothing to wear, or
## no room for what comes off.
func equip_from_bag(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var id: String = bag[index].id
	var slot := _slot_for(id)
	if slot == "" or (slot.begins_with("clasp") and clasp_busy(slot)):
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
	if id == "" or slot == "rod" or clasp_busy(slot):
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
	if id == "" or slot == "rod" or clasp_busy(slot):
		return false
	equipped[slot] = ""
	_store(id, 1)
	_changed()
	return true


## A thing given (a reward): into the warehouse.
func add_stored(id: String, count: int) -> void:
	_store(id, count)
	_changed()


## User request: the smith in the tank - a piece of gear that wears out,
## `uses` of its durability back (up to its full). How many it got.
func repair(id: String, uses: int) -> int:
	var full := max_durability(id)
	if full <= 0:
		return 0
	var before := durability(id)
	var after := mini(before + uses, full)
	if after >= full:
		wear.erase(id)
	else:
		wear[id] = after
	_changed()
	return after - before


## The gear worn down some (owned, anywhere): its ids.
func repairable() -> Array:
	var out := []
	var seen := {}
	var ids := []
	for slot in equipped:
		ids.append(str(equipped[slot]))
	ids.append_array(storage.keys())
	for e in bag:
		ids.append(str(e.id))
	for id in ids:
		if id != "" and not seen.has(id) and max_durability(id) > 0 and durability(id) < max_durability(id):
			seen[id] = true
			out.append(id)
	return out


## User request: the fortune fish in the tank (FishLife) send gold by the
## hour - real time, up to FORTUNE_CAP_HOURS' worth. The clock when it was
## last settled (unix s; 0: not running).
var fortune_clock := 0.0
## (tests: the time now)
var now_override := 0.0


func _now() -> float:
	return now_override if now_override > 0.0 else Time.get_unix_time_from_system()


## What the fortune fish have sent since last settled; settles it and pays.
## The gold paid.
func settle_fortune() -> int:
	var now := _now()
	var n := FishLife.count_trait(tank, "fortune")
	if n == 0 or fortune_clock <= 0.0:
		fortune_clock = now
		return 0
	var rate := float(n * FishLife.FORTUNE_GOLD)
	var hours := (now - fortune_clock) / 3600.0
	var paid := 0
	if hours >= FishLife.FORTUNE_CAP_HOURS:
		paid = int(floor(FishLife.FORTUNE_CAP_HOURS * rate))
		fortune_clock = now
	else:
		paid = int(floor(maxf(hours, 0.0) * rate))
		# (only the whole gold is taken off the clock: the rest keeps)
		if paid > 0:
			fortune_clock += float(paid) / rate * 3600.0
	if paid > 0:
		gold += paid
		gold_updated.emit(gold)
		_changed()
	return paid


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
		"fish_box": fish_box,
		"pack_fish": pack_fish,
		"clasp_fish": clasp_fish,
		"stash_fish": stash_fish,
		"fortune_clock": fortune_clock,
		"tank_news": tank_news,
		"shadows": shadows,
		"run_brought": run_brought,
		"weak_news": weak_news,
		"settings": settings,
		"camp_tent": camp_tent,
		"character": character,
		"talents": talents.duplicate(),
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
	shadows = data.get("shadows", [])
	run_brought = data.get("run_brought", [])
	weak_news = data.get("weak_news", [])
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
	fish_box = data.get("fish_box", [])
	pack_fish = data.get("pack_fish", [])
	clasp_fish = data.get("clasp_fish", [])
	stash_fish = data.get("stash_fish", [])
	ensure_fish_life()
	fortune_clock = float(data.get("fortune_clock", 0.0))
	tank_news = data.get("tank_news", [])
	settings = {"auto_lure": false, "damage_numbers": true}
	settings.merge(data.get("settings", {}), true)
	camp_tent = int(data.get("camp_tent", 8))
	character = str(data.get("character", "cat"))
	talents = data.get("talents", {}).duplicate()
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
	relayout_bag()
	_sync_clasp()
	ensure_bait()
