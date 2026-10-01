extends Node

## User request: a single-player campaign (渡湖紀行, docs/CAMPAIGN.md) - from
## a small, safe map that teaches one thing at a time, up to the full map
## with everything in it - with a tutorial, objectives, stars and
## achievements; then the free run (自由夜釣) and, after the last chapter,
## curses (詛咒) to make it harder for more gold.
##
## Every run - a level, the free run, a cursed run - is played by one set of
## rules (`rules`: DEFAULT_RULES with the level's or the curses' changes),
## which the game reads where it decides things: the map's size and look
## (MapGenerator), the quota and the day (GameState), which threats there
## are (here, attach()), the lamp's drain (Lantern), the water ghost's odds
## and the bait (Player).
##
## While a run is on, `run` counts what happens in it (stat()): the game's
## own signals are listened to here, and the few things with no signal call
## Campaign.stat() where they happen. Stars, the tutorial's steps, the
## objectives shown and the achievements are all read off those counts.

signal stat_changed(key: String, value: float)
signal achievement_unlocked(id: String)

## The map sizes (world px). L is the full map the free run has always had.
const MAP_SIZES := {"S": Vector2(1300, 760), "M": Vector2(1850, 1050), "L": Vector2(2400, 1350)}
const MAP_NAMES := {"S": "小", "M": "中", "L": "大"}

## The free run as it has always been. A level changes some of these.
## ponds: [common (-1: 3-4 at random), rare]; day: seconds (0: no clock, no
## night); fuel: the camp fire's oil (-1: as upgraded); drain: the lamp's
## oil use; ghosts: floating ghosts; meddle: how often they may make
## trouble; big_wake: the light stage the big ghost wakes at (-1: its own);
## water_ghost / heart: odds multipliers; weather: "random", "mild" (no
## storms), "stormy", "clear", or a schedule [[kind, seconds], ...] then
## "random"; rocks: flip rocks [min, max]; bait: the base bait (-1: as
## upgraded); escalate: another ghost and a frenzy once the quota's met;
## evil: evil offerings can turn up; night_fails: nightfall ends the run
## (levels with no big ghost to make the night deadly); safe: losing costs
## nothing (no found gear lost, no spirit); gift: items the bag is topped
## up to as the level starts (what its lesson needs); beasts: hunters added
## to the map's animals.
const DEFAULT_RULES := {
	"map": "L", "theme": "", "ponds": [-1, 1], "day": 300.0, "quota": 30.0,
	"fuel": -1.0, "drain": 1.0, "oil": true,
	"ghosts": 1, "meddle": 4, "big_ghost": true, "big_wake": -1, "water_ghost": 1.0, "heart": 1.0,
	"hunters": true, "beasts": {}, "weather": "random", "rocks": [8, 10], "critters": 6,
	"hotspot": true, "bait": -1, "escalate": true, "evil": true, "night_fails": false, "safe": false,
	"tutorial": "", "gift": {},
}

const CHAPTERS := [
	{"id": 1, "name": "初渡", "stars": 0, "blurb": "柳靈帶你走第一趟。小小的池塘，沒有危險，失敗也不會失去任何東西。"},
	{"id": 2, "name": "秋沼", "stars": 0, "blurb": "楓紅與沼澤。漣漪、暗潭、路亞、霧與暴雨，還有水裡的東西。"},
	{"id": 3, "name": "鐵鍊聲", "stars": 10, "blurb": "枯木林裡傳來鐵鍊拖地的聲音。燈光會引來它。"},
	{"id": 4, "name": "荒野", "stars": 20, "blurb": "雪原、雨林、史前大地。野獸會撲人，魚也更難纏。"},
	{"id": 5, "name": "邪祭", "stars": 30, "blurb": "額度滿了，才是真正的抉擇：走，還是留下來賭供品？"},
]

## The 25 levels, in order. stars: the ★★ and ★★★ conditions (★ is getting
## out): a run stat (see stat()) with "min" or "max". reward: the first
## clear's gold and items (into the warehouse).
const LEVELS := [
	# ---- Chapter 1: 初渡 - the tutorial: small, safe, one thing a level.
	{"id": "1-1", "chapter": 1, "name": "第一竿", "teach": "走路、拋竿、揚竿、收線、獻祭、離開",
		"intro": "湖的另一邊很安靜。先釣一條魚，交給祭壇，再從亮起來的符文石回去。",
		"rules": {"map": "S", "theme": "forest_birch", "ponds": [1, 0], "day": 0.0, "quota": 1.0, "drain": 0.0,
			"ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear",
			"rocks": [0, 0], "critters": 0, "hotspot": false, "oil": false, "escalate": false, "evil": false,
			"safe": true, "tutorial": "first_cast"},
		"stars": [{"stat": "lost_fish", "max": 0, "text": "沒有讓魚跑掉"},
			{"stat": "elapsed", "max": 180, "text": "3 分鐘內離開"}],
		"reward": {"gold": 40}},
	{"id": "1-2", "chapter": 1, "name": "遠與近", "teach": "拋得越遠魚越大、張力條",
		"intro": "近岸的小魚好釣，但遠處的大魚值得多。張力太緊線會斷。",
		"rules": {"map": "S", "theme": "forest_birch", "ponds": [1, 0], "day": 0.0, "quota": 10.0, "drain": 0.0,
			"ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear",
			"rocks": [2, 3], "critters": 0, "hotspot": false, "oil": false, "escalate": false, "evil": false,
			"safe": true, "tutorial": "reach"},
		"stars": [{"stat": "catch_far", "min": 1, "text": "釣到一條遠海大魚"},
			{"stat": "line_break", "max": 0, "text": "沒有斷線"}],
		"reward": {"gold": 50}},
	{"id": "1-3", "chapter": 1, "name": "石下有餌", "teach": "餌會用完；翻石頭、抓小動物當餌",
		"intro": "餌只剩一點點。石頭底下、草叢裡，到處都有東西可以掛上鉤。",
		"rules": {"map": "S", "theme": "forest_pine", "ponds": [1, 0], "day": 0.0, "quota": 14.0, "drain": 0.0,
			"ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear",
			"rocks": [7, 8], "critters": 6, "hotspot": false, "oil": false, "escalate": false, "evil": false,
			"bait": 2, "safe": true, "tutorial": "bait"},
		"stars": [{"stat": "flip_rock", "min": 4, "text": "翻開 4 塊石頭"},
			{"stat": "grab_bait", "min": 1, "text": "抓到 1 隻活餌"}],
		"reward": {"gold": 60, "items": {"live_worm": 3}}},
	{"id": "1-4", "chapter": 1, "name": "天色將暗", "teach": "時間、天色、燈的亮度、燈油、回營火補油",
		"intro": "這裡的白天很短。天黑以前沒離開，符文石就再也不會亮了。",
		"rules": {"map": "S", "theme": "forest_maple", "ponds": [1, 0], "day": 240.0, "quota": 18.0,
			"ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear",
			"rocks": [5, 6], "critters": 4, "hotspot": false, "oil": false, "escalate": false, "evil": false,
			"night_fails": true, "safe": true, "tutorial": "lamp"},
		"stars": [{"stat": "refuel", "min": 1, "text": "回營火補 1 次燈油"},
			{"stat": "time_left", "min": 60, "text": "剩 60 秒以上離開"}],
		"reward": {"gold": 70, "items": {"battery": 2}}},
	{"id": "1-5", "chapter": 1, "name": "飄忽的影子", "teach": "小鬼的搗亂、用強光定住鬼",
		"intro": "有東西在樹梢間飄。它們不會傷人，只是愛搗蛋。",
		"rules": {"map": "S", "theme": "forest_green", "ponds": [1, 0], "day": 270.0, "quota": 22.0,
			"ghosts": 1, "meddle": 3, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear",
			"rocks": [5, 6], "critters": 4, "hotspot": false, "oil": false, "escalate": false, "evil": false,
			"night_fails": true, "safe": true, "tutorial": "ghost"},
		"stars": [{"stat": "ghost_stun", "min": 1, "text": "用強光定住小鬼"},
			{"stat": "stolen", "max": 0, "text": "沒有魚被偷"}],
		"reward": {"gold": 80}},
	# ---- Chapter 2: 秋沼 - a middle-sized map, the real rules.
	{"id": "2-1", "chapter": 2, "name": "漣漪與暗潭", "teach": "魚群漣漪、暗潭的稀有魚",
		"intro": "水面一圈圈的漣漪，是魚群在底下翻騰。那個顏色特別深的小潭，藏著不一樣的東西。",
		"rules": {"map": "M", "theme": "autumn", "ponds": [2, 1], "quota": 26.0, "ghosts": 1, "meddle": 3,
			"big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "escalate": false,
			"evil": false, "night_fails": true, "tutorial": "hotspot"},
		"stars": [{"stat": "catch_hotspot", "min": 2, "text": "在漣漪裡釣到 2 條"},
			{"stat": "catch_rare", "min": 1, "text": "釣到 1 條稀有魚"}],
		"reward": {"gold": 90}},
	{"id": "2-2", "chapter": 2, "name": "路亞", "teach": "路亞：邊收線魚才會追；假餌會被扯斷",
		"intro": "青蛙商人塞了幾個假餌給你：「試試看，會動的東西魚比較愛。」",
		"rules": {"map": "M", "theme": "autumn", "ponds": [2, 1], "quota": 28.0, "ghosts": 1, "meddle": 3,
			"big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "escalate": false,
			"evil": false, "night_fails": true, "gift": {"lure_minnow": 6}, "tutorial": "lure"},
		"stars": [{"stat": "catch_lure", "min": 3, "text": "用路亞釣到 3 條"},
			{"stat": "lure_lost", "max": 0, "text": "沒弄丟假餌"}],
		"reward": {"gold": 100}},
	{"id": "2-3", "chapter": 2, "name": "霧與魚汛", "teach": "天氣：起霧、魚汛",
		"intro": "沼澤的天氣說變就變。霧散了以後，魚會一起浮上來。",
		"rules": {"map": "M", "theme": "swamp", "ponds": [2, 1], "quota": 32.0, "ghosts": 1, "meddle": 3,
			"big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": [["FOG", 55.0], ["FISH_RUN", 55.0], "mild"],
			"escalate": false, "evil": false, "night_fails": true, "tutorial": "weather"},
		"stars": [{"stat": "catch_fishrun", "min": 3, "text": "魚汛時釣到 3 條"},
			{"stat": "time_left", "min": 45, "text": "剩 45 秒以上離開"}],
		"reward": {"gold": 110}},
	{"id": "2-4", "chapter": 2, "name": "暴雨", "teach": "暴風雨、水鬼、棧橋",
		"intro": "雨大到看不清水面。這種天氣，水裡的東西會爬上來。",
		"rules": {"map": "M", "theme": "swamp", "ponds": [2, 1], "quota": 32.0, "ghosts": 1, "meddle": 3,
			"big_ghost": false, "water_ghost": 1.5, "hunters": false, "weather": [["STORM", 100.0], "random"],
			"escalate": false, "evil": false, "night_fails": true, "tutorial": "water_ghost"},
		"stars": [{"stat": "water_ghost_hit", "max": 0, "text": "沒被水鬼抓到"},
			{"stat": "catch_dock", "min": 3, "text": "在棧橋上釣到 3 條"}],
		"reward": {"gold": 120}},
	{"id": "2-5", "chapter": 2, "name": "搬油", "teach": "營火的油、提油箱回營地",
		"intro": "營火的油桶快見底了。地圖上散落著油箱，得自己提回來。",
		"rules": {"map": "M", "theme": "autumn", "ponds": [2, 1], "day": 330.0, "quota": 36.0, "fuel": 160.0,
			"drain": 1.3, "ghosts": 1, "meddle": 3, "big_ghost": false, "water_ghost": 0.6, "hunters": false,
			"weather": "mild", "escalate": false, "evil": false, "night_fails": true, "tutorial": "oil"},
		"stars": [{"stat": "oil_delivered", "min": 2, "text": "提回 2 桶油"},
			{"stat": "fire_out", "max": 0, "text": "營火從沒熄滅"}],
		"reward": {"gold": 130, "items": {"battery": 2}}},
	# ---- Chapter 3: 鐵鍊聲 - the big ghost.
	{"id": "3-1", "chapter": 3, "name": "鐵鍊聲", "teach": "大鬼：被燈光吸引、會抓人；營火圈裡安全",
		"intro": "天色一暗，遠處就傳來鐵鍊拖地的聲音。它看得見光。",
		"rules": {"map": "M", "theme": "deadwood", "ponds": [2, 1], "quota": 28.0, "ghosts": 0,
			"water_ghost": 0.5, "hunters": false, "weather": "mild", "evil": false, "tutorial": "big_ghost"},
		"stars": [{"stat": "grabbed", "max": 0, "text": "沒被大鬼抓住"},
			{"stat": "catch", "min": 8, "text": "釣到 8 條"}],
		"reward": {"gold": 150}},
	{"id": "3-2", "chapter": 3, "name": "強光", "teach": "強光定住大鬼；被抓時用強光掙脫",
		"intro": "光會引來它，也能擋下它。看準時機，用盡全力照過去。",
		"rules": {"map": "M", "theme": "deadwood", "ponds": [2, 1], "quota": 32.0, "ghosts": 1, "meddle": 3,
			"water_ghost": 0.5, "hunters": false, "weather": "mild", "evil": false, "tutorial": "flash_big"},
		"stars": [{"stat": "big_ghost_stun", "min": 1, "text": "用強光定住大鬼"},
			{"stat": "grabbed", "max": 0, "text": "沒被大鬼抓住"}],
		"reward": {"gold": 160, "items": {"battery": 3}}},
	{"id": "3-3", "chapter": 3, "name": "誘惑", "teach": "丟一條魚引開大鬼",
		"intro": "它餓了。餓的東西，都會被吃的引走。",
		"rules": {"map": "M", "theme": "rocky", "ponds": [2, 1], "quota": 36.0, "ghosts": 1, "meddle": 3,
			"water_ghost": 0.5, "hunters": false, "weather": "mild", "evil": false, "tutorial": "lure_throw"},
		"stars": [{"stat": "big_ghost_lured", "min": 1, "text": "用魚引開大鬼"},
			{"stat": "time_left", "min": 30, "text": "剩 30 秒以上離開"}],
		"reward": {"gold": 170}},
	{"id": "3-4", "chapter": 3, "name": "心臟", "teach": "心臟（被抓時救命）；入夜",
		"intro": "這一趟時間不夠，夜一定會來。漣漪裡偶爾會釣到一顆還在跳的心臟。",
		"rules": {"map": "M", "theme": "rocky", "ponds": [2, 1], "day": 210.0, "quota": 42.0, "ghosts": 1,
			"meddle": 3, "water_ghost": 0.5, "heart": 4.0, "hunters": false, "weather": "mild", "evil": false,
			"tutorial": "heart"},
		"stars": [{"stat": "heart_got", "min": 1, "text": "拿到心臟"},
			{"stat": "escaped_night", "min": 1, "text": "入夜後才成功離開"}],
		"reward": {"gold": 180}},
	{"id": "3-5", "chapter": 3, "name": "鬼門關", "teach": "綜合考驗：第一次到大地圖",
		"intro": "湖面一下子變得好寬。小鬼、大鬼、水鬼，全都在。",
		"rules": {"map": "L", "theme": "deadwood", "ponds": [3, 1], "quota": 45.0, "ghosts": 2, "meddle": 4,
			"hunters": false, "evil": false},
		"stars": [{"stat": "stolen", "max": 0, "text": "沒有魚被偷"},
			{"stat": "grabbed", "max": 0, "text": "沒被大鬼抓住"}],
		"reward": {"gold": 220}},
	# ---- Chapter 4: 荒野 - beasts, and fish that fight back.
	{"id": "4-1", "chapter": 4, "name": "狼嚎", "teach": "野獸：盯上、撲倒、魚掉地上；強光嚇跑",
		"intro": "雪地上有一串腳印，一直延伸到樹林裡。",
		"rules": {"map": "L", "theme": "snow", "ponds": [3, 1], "quota": 40.0, "ghosts": 1, "big_ghost": false,
			"night_fails": true, "evil": false, "beasts": {"wolf": 2.0}, "tutorial": "hunters"},
		"stars": [{"stat": "animal_hit", "max": 0, "text": "沒被野獸撲倒"},
			{"stat": "beast_scare", "min": 1, "text": "用強光嚇跑野獸"}],
		"reward": {"gold": 220, "items": {"lure_redhead": 3}}},
	{"id": "4-2", "chapter": 4, "name": "掙扎的魚", "teach": "魚往外衝、往旁邊衝、跳出水面",
		"intro": "雨林的魚個性很烈。上鉤以後，才是真正的開始。",
		"rules": {"map": "L", "theme": "tropical", "ponds": [3, 1], "quota": 45.0, "ghosts": 1,
			"evil": false, "tutorial": "fight"},
		"stars": [{"stat": "swipe_hit", "min": 3, "text": "反甩成功 3 次"},
			{"stat": "catch_jumper", "min": 1, "text": "釣到 1 條會跳的魚"}],
		"reward": {"gold": 230}},
	{"id": "4-3", "chapter": 4, "name": "雪夜長路", "teach": "綜合：油少、大鬼、野獸",
		"intro": "營火燒不久，池塘又離得遠。每一趟來回都要算好。",
		"rules": {"map": "L", "theme": "snow", "ponds": [3, 1], "day": 330.0, "quota": 48.0, "fuel": 220.0,
			"drain": 1.2, "ghosts": 1, "evil": false, "beasts": {"wolf": 1.5}},
		"stars": [{"stat": "oil_delivered", "min": 1, "text": "提回 1 桶油"},
			{"stat": "grabbed", "max": 0, "text": "沒被大鬼抓住"}],
		"reward": {"gold": 240}},
	{"id": "4-4", "chapter": 4, "name": "巨獸之地", "teach": "暴龍、迅猛龍：更快的獵食者",
		"intro": "地面在震。那些不是石頭，是在睡覺的東西。",
		"rules": {"map": "L", "theme": "prehistoric", "ponds": [3, 1], "quota": 50.0, "ghosts": 1, "evil": false},
		"stars": [{"stat": "animal_hit", "max": 0, "text": "沒被野獸撲倒"},
			{"stat": "catch", "min": 10, "text": "釣到 10 條"}],
		"reward": {"gold": 250, "items": {"battery": 3}}},
	{"id": "4-5", "chapter": 4, "name": "黑松林", "teach": "暴雨、水鬼、野獸、大鬼一起來",
		"intro": "松林深處終年不見天日，雨總是下個不停。",
		"rules": {"map": "L", "theme": "forest_pine", "ponds": [3, 1], "quota": 55.0, "ghosts": 1,
			"water_ghost": 1.3, "weather": "stormy", "evil": false, "beasts": {"wolf": 2.0}},
		"stars": [{"stat": "water_ghost_hit", "max": 0, "text": "沒被水鬼抓到"},
			{"stat": "time_left", "min": 30, "text": "剩 30 秒以上離開"}],
		"reward": {"gold": 260}},
	# ---- Chapter 5: 邪祭 - offerings and the evil in them; the full rules.
	{"id": "5-1", "chapter": 5, "name": "供品", "teach": "供品池、留下來賭、邪惡供品",
		"intro": "額度滿了，祭壇卻還在發光。再多獻一點，也許會有更好的東西……也許不會。",
		"rules": {"map": "L", "theme": "beach_sandy", "quota": 40.0, "ghosts": 1, "tutorial": "offerings"},
		"stars": [{"stat": "offering_rare", "min": 1, "text": "帶回稀有以上的供品"},
			{"stat": "evil", "max": 0, "text": "沒有邪惡供品"}],
		"reward": {"gold": 280, "items": {"lure_rainbow": 2}}},
	{"id": "5-2", "chapter": 5, "name": "腐魚", "teach": "放在地上的魚會腐敗；腐魚獻祭是賭博",
		"intro": "廢城的街上到處是被丟下的魚。有人說，腐敗的東西，鬼最喜歡。",
		"rules": {"map": "L", "theme": "ruins", "quota": 45.0, "ghosts": 1, "tutorial": "rotten"},
		"stars": [{"stat": "rotten_sacrifice", "min": 1, "text": "獻祭 1 條腐魚"},
			{"stat": "evil", "max": 0, "text": "沒有邪惡供品"}],
		"reward": {"gold": 290}},
	{"id": "5-3", "chapter": 5, "name": "海岸", "teach": "大海與石堤、海魚",
		"intro": "湖的盡頭是海。浪很大，魚也大。",
		"rules": {"map": "L", "theme": "beach_rocky", "quota": 60.0, "ghosts": 1},
		"stars": [{"stat": "species", "min": 6, "text": "釣到 6 種不同的魚"},
			{"stat": "catch_rare", "min": 1, "text": "釣到 1 條稀有魚"}],
		"reward": {"gold": 300}},
	{"id": "5-4", "chapter": 5, "name": "廢城", "teach": "街道與廢墟；大鬼一開始就醒著",
		"intro": "這座城沒有白天。它早就醒著，在街角等你。",
		"rules": {"map": "L", "theme": "ruins", "quota": 60.0, "ghosts": 1, "big_wake": 0},
		"stars": [{"stat": "grabbed", "max": 0, "text": "沒被大鬼抓住"},
			{"stat": "evil", "max": 0, "text": "沒有邪惡供品"}],
		"reward": {"gold": 320}},
	{"id": "5-5", "chapter": 5, "name": "深淵之夜", "teach": "終章：全部的威脅",
		"intro": "柳靈說，這裡是湖最深的地方。從來沒有人在這裡等到天亮。",
		"rules": {"map": "L", "theme": "swamp", "day": 360.0, "quota": 80.0, "ghosts": 2, "meddle": 5,
			"big_wake": 0, "water_ghost": 1.3, "weather": "stormy", "beasts": {"wolf": 1.0}},
		"stars": [{"stat": "evil", "max": 0, "text": "沒有邪惡供品"},
			{"stat": "catch_legend", "min": 1, "text": "釣到 1 條傳說魚"}],
		"reward": {"gold": 500}},
]

## User design (post-game): the free run with curses, each paying a share
## more gold on the way out.
const CURSES := {
	"fog": {"name": "濃霧", "desc": "整輪都是霧", "bonus": 0.2},
	"early": {"name": "早醒", "desc": "大鬼一開始就醒", "bonus": 0.3},
	"dry": {"name": "枯油", "desc": "營火和燈油只有一半", "bonus": 0.25},
	"rush": {"name": "急潮", "desc": "時間少 40%", "bonus": 0.25},
	"greed": {"name": "貪念", "desc": "額度多 50%", "bonus": 0.3},
	"horde": {"name": "群鬼", "desc": "多 2 隻小鬼", "bonus": 0.2},
}
const CURSE_ORDER := ["fog", "early", "dry", "rush", "greed", "horde"]

## Gold for each new star, and for a chapter's every star.
const STAR_GOLD := 15
const CHAPTER_GOLD := 200

## The run stats that are a run's own (not added up into Profile.records).
const RUN_ONLY := ["elapsed", "time_left", "evil", "species", "streak", "streak_best", "near_water",
	"light_stage", "quota_met", "big_awake", "mode_lure", "brightness_changed", "carrying_oil",
	"first_cast_far", "casts", "night", "fish_run", "storm", "fog", "escape_phase"]

## User request: achievements - [id, category, name, what it takes, gold,
## check]. check: {"life": stat, "min": n} (lifetime, Profile.records),
## {"run": stat, "min"/"max": n, "won": true} (one run), {"stars": n},
## {"chapter": n} (cleared), {"level": id}, {"log": percent},
## {"all": [checks]}.
const ACHIEVEMENTS := [
	["first_crossing", "旅程", "初渡", "通過 1-1「第一竿」", 30, {"level": "1-1"}],
	["chapter_2", "旅程", "秋沼行者", "通過第二章", 100, {"chapter": 2}],
	["chapter_3", "旅程", "鐵鍊聽者", "通過第三章", 150, {"chapter": 3}],
	["chapter_4", "旅程", "荒野旅人", "通過第四章", 200, {"chapter": 4}],
	["chapter_5", "旅程", "邪祭見證", "通過第五章，渡湖紀行完結", 300, {"chapter": 5}],
	["stars_45", "旅程", "滿天星", "收集 45 顆星", 200, {"stars": 45}],
	["stars_75", "旅程", "渡湖紀行", "收集全部 75 顆星", 500, {"stars": 75}],
	["catch_100", "釣技", "百尾", "總共釣到 100 條魚", 100, {"life": "catch", "min": 100}],
	["catch_1000", "釣技", "千尾", "總共釣到 1000 條魚", 500, {"life": "catch", "min": 1000}],
	["far_50", "釣技", "遠方的回應", "釣到 50 條遠海大魚", 120, {"life": "catch_far", "min": 50}],
	["swipe_30", "釣技", "反甩大師", "反甩成功 30 次", 120, {"life": "swipe_hit", "min": 30}],
	["streak_10", "釣技", "一線不斷", "一輪裡連續釣到 10 條，中間沒跑掉任何一條", 150, {"run": "streak_best", "min": 10}],
	["lure_50", "釣技", "路亞手", "用路亞釣到 50 條", 120, {"life": "catch_lure", "min": 50}],
	["legend", "收集", "傳說", "釣到第一條傳說魚", 150, {"life": "catch_legend", "min": 1}],
	["log_50", "收集", "圖鑑半滿", "圖鑑收集 50%", 200, {"log": 50}],
	["stun_20", "生存", "光之盾", "用強光定住大鬼 20 次", 150, {"life": "big_ghost_stun", "min": 20}],
	["free_10", "生存", "九死一生", "從大鬼手中掙脫 10 次", 150, {"life": "grab_escaped", "min": 10}],
	["night_5", "生存", "夜行者", "入夜後成功離開 5 次", 150, {"life": "escaped_night", "min": 5}],
	["one_lamp", "生存", "一盞到底", "有天黑的一輪，沒回營火補油就成功離開", 80,
		{"all": [{"run": "refuel", "max": 0, "won": true}, {"run": "timed", "min": 1}]}],
	["untouched", "生存", "毫髮無傷", "一輪裡沒被抓、沒被偷、沒被撲倒、沒被水鬼抓，成功離開（大地圖）", 150,
		{"all": [{"run": "grabbed", "max": 0, "won": true}, {"run": "stolen", "max": 0}, {"run": "animal_hit", "max": 0},
			{"run": "water_ghost_hit", "max": 0}, {"run": "big_map", "min": 1}]}],
	["gambler", "邪祭", "賭徒", "額度滿後繼續獻祭，帶回史詩供品", 150, {"run": "offering_epic", "min": 1, "won": true}],
	["pure_20", "邪祭", "純淨之手", "沒有邪惡供品成功離開 20 次", 150, {"life": "pure_escape", "min": 20}],
	["rotten_10", "邪祭", "腐敗的饋贈", "獻祭 10 條腐魚", 100, {"life": "rotten_sacrifice", "min": 10}],
	["regular", "營地", "老主顧", "跟青蛙商人買東西 20 次", 100, {"life": "purchases", "min": 20}],
	["willow_10", "營地", "柳靈之友", "跟柳靈說話 10 次", 80, {"life": "willow_talk", "min": 10}],
	["dancer", "隱藏", "水鬼的舞伴", "一輪裡被水鬼抓 3 次還成功離開", 100, {"run": "water_ghost_hit", "min": 3, "won": true}],
	["feeder", "隱藏", "餵鬼人", "一輪裡用魚引開大鬼 3 次", 100, {"run": "big_ghost_lured", "min": 3}],
	["one_cast", "隱藏", "一竿入魂", "一輪的第一竿就釣到遠海大魚", 80, {"run": "first_cast_far", "min": 1}],
]

## The tutorials: steps of [what Willow says, until (a stat reaching "min"
## or "after" seconds), target (where the guide arrow points, or "")].
## Words in braces are the controls, put for a touchscreen or a keyboard
## (CONTROLS).
const TUTORIALS := {
	"first_cast": [
		["歡迎來到湖的另一邊。先走到水邊吧（{move}）。", {"stat": "near_water", "min": 1}, "water"],
		["{cast}，就能把浮標拋出去。", {"stat": "casts", "min": 1}, ""],
		["等浮標整個沉下去、水花濺起來再{strike}！太早拉會把魚嚇跑。", {"stat": "hook", "min": 1}, ""],
		["上鉤了！{reel}收線；張力條變紅就先放手。", {"stat": "catch", "min": 1}, ""],
		["釣到了！魚放進背包裡了。把牠帶去祭壇。", {"stat": "near_altar", "min": 1}, "altar"],
		["在祭壇旁{act}「獻祭」，選魚交出去。", {"stat": "quota_met", "min": 1}, "altar"],
		["額度滿了，符文石亮了！走進光裡就能回營地。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"reach": [
		["拉得越久，拋得越遠。遠處的魚比較大，也值得比較多。", {"after": 7.0}, ""],
		["試試把浮標拋到池塘中間，釣一條遠海大魚。", {"stat": "catch_far", "min": 1}, "water"],
		["大魚拉力強。張力條太紅就放手，讓牠跑一下再收。", {"after": 7.0}, ""],
		["湊滿額度，就能回去了。", {"stat": "quota_met", "min": 1}, "altar"],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"bait": [
		["餌只剩兩份。用完就不能用浮標釣了。", {"after": 6.0}, ""],
		["有些石頭可以翻開，底下常有蟲子。走過去{act}「翻開」。", {"stat": "flip_rock", "min": 1}, "rock"],
		["草地上的小動物也能抓來當活餌，比普通的餌好用。", {"stat": "grab_bait", "min": 1}, "critter"],
		["好，餌夠了。繼續釣吧。", {"stat": "quota_met", "min": 1}, ""],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"lamp": [
		["上方是剩下的時間。時間到天就黑了，這裡天黑前一定要離開。", {"after": 7.0}, ""],
		["天會一點一點暗下來。暗了就把燈調亮（{bright}）。", {"stat": "brightness_changed", "min": 1}, ""],
		["燈越亮越耗油。右上角是燈油。", {"after": 6.0}, ""],
		["油不夠時回營火，就能把燈加滿。", {"stat": "refuel", "min": 1}, "camp"],
		["記得時間。湊滿額度就離開。", {"stat": "quota_met", "min": 1}, ""],
		["快，符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"ghost": [
		["看到那個飄來飄去的影子了嗎？小鬼會偷餌、剪線、偷魚。", {"after": 7.0}, ""],
		["牠靠過來時，{flash}，用強光照牠，就會定住一陣子。", {"stat": "ghost_stun", "min": 1}, ""],
		["做得好。小鬼不會殺人，但很煩人。別讓牠偷走你的魚。", {"stat": "quota_met", "min": 1}, ""],
		["走吧。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"hotspot": [
		["水面那一圈圈的漣漪，是魚群。在那裡下竿，好魚比較多。", {"stat": "catch_hotspot", "min": 1}, "hotspot"],
		["顏色特別深的小潭是暗潭，稀有的魚住在那裡。", {"stat": "catch_rare", "min": 1}, "rare"],
		["漣漪釣過一次就會換地方。跟著牠走。", {"stat": "quota_met", "min": 1}, ""],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"lure": [
		["商人給的假餌在背包裡。{mode}，換成路亞。", {"stat": "mode_lure", "min": 1}, ""],
		["路亞要邊收線，魚才會追上來咬。拋出去以後{reel}慢慢收。", {"stat": "catch_lure", "min": 1}, "water"],
		["假餌被扯斷就沒了。張力太紅時一定要放手。", {"stat": "quota_met", "min": 1}, ""],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"weather": [
		["起霧了，燈照不遠。慢慢走，別迷路。", {"stat": "fish_run", "min": 1}, ""],
		["魚汛來了！這段時間魚特別容易上鉤，把握機會。", {"stat": "catch_fishrun", "min": 3}, "water"],
		["天氣還會再變。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"water_ghost": [
		["暴風雨會讓水鬼更活躍。", {"after": 6.0}, ""],
		["站在岸邊、浮標又落在很近的地方，水鬼就可能冒出來拖住你。拋遠一點。", {"after": 8.0}, ""],
		["站在棧橋上釣，水鬼比較難抓到你。", {"stat": "catch_dock", "min": 1}, "dock"],
		["湊滿額度就離開。", {"stat": "quota_met", "min": 1}, ""],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"oil": [
		["營火的油不多了。營火熄了，營地就不再安全。", {"after": 7.0}, ""],
		["地圖上有油箱。走過去{act}「提起」。", {"stat": "carrying_oil", "min": 1}, "oil"],
		["提著油箱沒辦法釣魚，先送回營火倒進去。", {"stat": "oil_delivered", "min": 1}, "camp"],
		["油箱過一陣子會在別處出現。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["符文石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"big_ghost": [
		["天色暗了以後，大鬼會醒來。聽到鐵鍊聲就是牠。", {"stat": "big_awake", "min": 1}, ""],
		["牠會被燈光吸引：燈照到牠，牠就會衝過來。", {"after": 7.0}, ""],
		["被盯上就把燈調暗、離開牠的視線，或躲回營火的光圈裡。", {"after": 8.0}, "camp"],
		["牠進不了營火的光圈。小心地釣，湊滿額度。", {"stat": "quota_met", "min": 1}, ""],
		["額度滿了，鬼群會更兇。快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"flash_big": [
		["強光也能定住大鬼。牠靠近時，{flash}，照牠的臉。", {"stat": "big_ghost_stun", "min": 1}, ""],
		["被抓住的時候，強光照牠也能掙脫。", {"stat": "quota_met", "min": 1}, ""],
		["快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"lure_throw": [
		["大鬼很貪吃。先選一條魚當誘餌：{lure}。", {"stat": "big_ghost_lured", "min": 1}, ""],
		["牠在吃的時候不會管你。趁現在。", {"stat": "quota_met", "min": 1}, ""],
		["快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"heart": [
		["這一趟時間很緊，夜一定會來。入夜後大鬼會直接追你。", {"after": 7.0}, ""],
		["漣漪裡偶爾會釣到一顆還在跳的心臟。帶著牠，被抓時能救你一命。", {"stat": "heart_got", "min": 1}, "hotspot"],
		["有心臟了。被抓住的時候，按畫面上的心臟就能掙脫。", {"stat": "quota_met", "min": 1}, ""],
		["快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"hunters": [
		["雪地上的狼靠太近，就會盯上你。", {"stat": "beast_seen", "min": 1}, ""],
		["被撲倒時，身上的魚會掉在地上。用強光照牠，牠會嚇跑。", {"stat": "beast_scare", "min": 1}, ""],
		["掉在地上的魚可以撿回來。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"fight": [
		["這裡的魚很會掙扎。魚往外衝時，先放手，讓牠跑。", {"stat": "fight_run", "min": 1}, ""],
		["往旁邊衝時，{swipe}，就是反甩。", {"stat": "swipe_hit", "min": 1}, ""],
		["魚跳出水面時一定要放手，不然會被甩掉。", {"stat": "quota_met", "min": 1}, ""],
		["快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"offerings": [
		["這次額度滿了先別急著走。", {"stat": "quota_met", "min": 1}, ""],
		["繼續獻祭，供品池會多出更好的供品。跟柳靈說話，可以知道有哪些。", {"stat": "willow_talk", "min": 1}, "willow"],
		["但供品裡可能藏著邪惡的東西，滿三個就全部泡湯。見好就收。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"rotten": [
		["放在地上的魚，過一陣子就會腐敗。", {"after": 7.0}, ""],
		["把腐魚獻祭，可能引來好漁場，也可能讓鬼發狂，或招來邪惡供品。", {"stat": "rotten_sacrifice", "min": 1}, "altar"],
		["賭完了。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["快去符文石！", {"stat": "escaped", "min": 1}, "escape"],
	],
}

## The controls' words: [touchscreen, keyboard].
const CONTROLS := {
	"move": ["左搖桿", "WASD"],
	"cast": ["按住右搖桿往後拉、放開", "按住空白鍵、放開"],
	"strike": ["點右搖桿", "按空白鍵"],
	"reel": ["按住右搖桿", "按住空白鍵"],
	"act": ["點旁邊的按鈕", "按 E"],
	"bright": ["長按畫面空白處再上下滑", "按 [ 或 ]"],
	"flash": ["按住燈的按鈕蓄力、放開", "按住 F 蓄力、放開"],
	"mode": ["點左上角的人物卡打開背包，在背包裡切換", "按 Tab"],
	"lure": ["點「誘惑」選魚，再按住往遠處拖、放開", "按 G 選魚，再按住 G、放開"],
	"swipe": ["右搖桿往反方向一甩", "往反方向按方向鍵"],
}

## What's being played: a level's id, or "" (the free run).
var level_id := ""
var rules: Dictionary = DEFAULT_RULES.duplicate(true)
var curses: Array = []
## This run's counts (see stat()).
var run: Dictionary = {}
## The last finished run's outcome, for the end screen (finish()).
var result: Dictionary = {}
var _main: Node = null
var _player: Player = null
var _first_cast_pending := false
var _species := {}
var _weather_plan: Array = []
var _brightness0 := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.run_ended.connect(_on_run_ended)
	GameState.weather_changed.connect(_on_weather_changed)
	GameState.quota_updated.connect(func(_p, _t): _poll_quota())
	GameState.day_phase_changed.connect(func(phase):
		if phase == "ESCAPE":
			stat("quota_met"))


# ---------------------------------------------------------------- data

static func level(id: String) -> Dictionary:
	for l in LEVELS:
		if l.id == id:
			return l
	return {}


static func levels_of(chapter: int) -> Array:
	return LEVELS.filter(func(l): return l.chapter == chapter)


static func chapter(n: int) -> Dictionary:
	for c in CHAPTERS:
		if c.id == n:
			return c
	return {}


## The level after `id`, or {} after the last.
static func next_level(id: String) -> Dictionary:
	for i in LEVELS.size():
		if LEVELS[i].id == id and i + 1 < LEVELS.size():
			return LEVELS[i + 1]
	return {}


## A level's rules: the free run's with the level's changes.
static func rules_for(id: String) -> Dictionary:
	var r: Dictionary = DEFAULT_RULES.duplicate(true)
	var l := level(id)
	if not l.is_empty():
		r.merge(l.rules.duplicate(true), true)
	return r


## How dangerous a run under `r` is: a skull for each of the night, the
## floating ghosts, the big ghost, the water ghost, beasts, storms and
## evil offerings (0-5 shown).
static func danger(r: Dictionary) -> int:
	var n := 0
	if float(r.day) > 0.0:
		n += 1
	if int(r.ghosts) > 0:
		n += 1
	if r.big_ghost:
		n += 1
	if float(r.water_ghost) > 0.0:
		n += 1
	if r.hunters and (not r.beasts.is_empty() or str(r.theme) in ["", "deadwood", "rocky", "snow", "prehistoric", "swamp", "forest_pine"]):
		n += 1
	var w = r.weather
	if (w is String and w in ["random", "stormy"]) or (w is Array and str(w).contains("STORM")):
		n += 1
	if r.evil:
		n += 1
	return mini(n, 5)


# ---------------------------------------------------------------- setting up a run

## Plays level `id` next.
func begin_level(id: String) -> void:
	level_id = id
	curses = []
	rules = rules_for(id)
	_apply_world()
	GameState.reset_run()


## Plays the free run next, with these curses (CURSES keys).
func begin_free(chosen: Array = []) -> void:
	level_id = ""
	curses = chosen.duplicate()
	rules = DEFAULT_RULES.duplicate(true)
	for c in curses:
		match c:
			"fog":
				rules.weather = [["FOG", 1.0e9]]
			"early":
				rules.big_wake = 0
			"dry":
				rules.fuel = FuelStation.BASE_TOTAL_FUEL * 0.5
				rules.drain = 1.6
			"rush":
				rules.day = float(rules.day) * 0.6
			"greed":
				rules.quota = float(rules.quota) * 1.5
			"horde":
				rules.ghosts = int(rules.ghosts) + 2
				rules.meddle = int(rules.meddle) + 2
	_apply_world()
	GameState.reset_run()


## Back to the plain free run's rules (the camp, the tests).
func clear() -> void:
	level_id = ""
	curses = []
	rules = DEFAULT_RULES.duplicate(true)
	_apply_world()


func is_level() -> bool:
	return level_id != ""


func _apply_world() -> void:
	var size: Vector2 = MAP_SIZES.get(rules.map, MAP_SIZES.L)
	Player.WORLD_WIDTH = size.x
	Player.WORLD_HEIGHT = size.y
	MapGenerator.SPAWN_POS = Vector2(roundf(size.x * 0.5), roundf(size.y * 0.5185))


## The share of the full map's area this run's map has (props and animals
## are scattered to match).
static func area_share() -> float:
	return Player.WORLD_WIDTH * Player.WORLD_HEIGHT / (2400.0 * 1350.0)


## The weather for the run's start, and what comes after (GameState).
func weather_plan() -> Array:
	var w = rules.weather
	if w is Array:
		return w.duplicate(true)
	return [w]


## Main is up: set the threats as the rules say, listen in, put up the
## objectives and the tutorial.
func attach(main: Node) -> void:
	_main = main
	_player = main.get_node("Player")
	run = {}
	result = {}
	_species = {}
	_first_cast_pending = true
	_brightness0 = -1.0
	if rules.map == "L":
		run["big_map"] = 1.0
	if float(rules.day) > 0.0:
		run["timed"] = 1.0
	_player.cast_started.connect(_on_cast)
	_player.bite_started.connect(func(): stat("bite"))
	_player.hook_success.connect(func(): stat("hook"))
	_player.catch_success.connect(_on_catch)
	_player.catch_failed.connect(_on_failed)
	_player.fight_event.connect(_on_fight_event)
	_set_threats()
	_give_gifts()
	if rules.bait >= 0:
		_player.bait_count = int(rules.bait)
	if is_level():
		main.add_child(CampaignHud.new())


func _set_threats() -> void:
	var ghost: Node = _main.get_node_or_null("Ghost")
	if int(rules.ghosts) <= 0:
		_retire(ghost)
	else:
		for i in int(rules.ghosts) - 1:
			GameState._spawn_extra_ghost()
	if not rules.big_ghost:
		_retire(_main.get_node_or_null("BigGhost"))
	if not rules.oil:
		_retire(_main.get_node_or_null("OilDrum"))
	if not rules.hotspot:
		var hotspot: Node = _main.get_node_or_null("Hotspot")
		if hotspot != null:
			hotspot.active = false
			_retire(hotspot)
	if float(rules.fuel) >= 0.0:
		var station: FuelStation = _main.get_node_or_null("FuelStation")
		if station != null:
			station.max_total_fuel = float(rules.fuel)
			station.total_fuel = float(rules.fuel)


## Out of the run: off the map, unseen, still (other scripts may still hold
## it, so it stays in the tree).
func _retire(node: Node) -> void:
	if node == null:
		return
	for g in node.get_groups():
		if not str(g).begins_with("_"):
			node.remove_from_group(g)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		node.visible = false
	if node is Node2D:
		node.global_position = Vector2(-5000, -5000)


## The level's lesson's tools: the bag topped up to the gift's counts.
func _give_gifts() -> void:
	var gift: Dictionary = rules.gift
	for id in gift:
		var need := int(gift[id]) - Profile.bag_count(id)
		if need > 0:
			Profile._store(id, need)
			Profile.to_bag(id, need)
	if not gift.is_empty():
		_player.reset_gear()


# ---------------------------------------------------------------- counting

## Adds `amount` to this run's count `key` (no-op with no run on).
func stat(key: String, amount := 1.0) -> void:
	if _main == null:
		return
	run[key] = float(run.get(key, 0.0)) + amount
	stat_changed.emit(key, run[key])


## Sets a count outright (for the states polled each frame).
func set_stat(key: String, value: float) -> void:
	if _main == null or float(run.get(key, -1.0)) == value:
		return
	run[key] = value
	stat_changed.emit(key, value)


func value(key: String) -> float:
	match key:
		"elapsed":
			return float(run.get("elapsed", 0.0))
		"time_left":
			return GameState.time_remaining if float(rules.day) > 0.0 else 9999.0
		"evil":
			return float(GameState.evil_count)
		"species":
			return float(_species.size())
	return float(run.get(key, 0.0))


func _process(delta: float) -> void:
	if _main == null:
		return
	if not is_instance_valid(_main) or not _main.is_inside_tree():
		_main = null
		_player = null
		return
	if GameState.run_started and not GameState.run_over:
		run["elapsed"] = float(run.get("elapsed", 0.0)) + delta
	if _player == null:
		return
	set_stat("near_water", 1.0 if _player._nearest_water_edge_distance() <= Player.CAST_SHORE_RANGE else float(run.get("near_water", 0.0)))
	var altar: Node2D = _main.get_node_or_null("Altar")
	if altar != null and _player.global_position.distance_to(altar.global_position) < 90.0:
		set_stat("near_altar", 1.0)
	set_stat("light_stage", float(GameState.light_stage()))
	if GameState.is_night:
		set_stat("night", 1.0)
	if _player.fishing_mode == Player.FishingMode.LURE:
		set_stat("mode_lure", 1.0)
	if _player.carrying_oil_drum:
		set_stat("carrying_oil", 1.0)
	var big: Node = _main.get_node_or_null("BigGhost")
	if big != null and big.process_mode != Node.PROCESS_MODE_DISABLED and big.mode != BigGhost.Mode.ASLEEP:
		set_stat("big_awake", 1.0)
	var lantern: Lantern = _player.get_node_or_null("Lantern")
	if lantern != null:
		if _brightness0 < 0.0:
			_brightness0 = lantern.brightness
		elif absf(lantern.brightness - _brightness0) > 0.05:
			set_stat("brightness_changed", 1.0)


func _poll_quota() -> void:
	if GameState.day_phase == GameState.DayPhase.ESCAPE:
		set_stat("quota_met", 1.0)


func _on_cast(_target: Vector2, tier: String) -> void:
	stat("casts")
	if tier == "far":
		stat("cast_far")


func _on_catch(fish: Dictionary) -> void:
	if fish.get("name", "") == "心臟":
		stat("heart_got")
		_first_cast_pending = false
		return
	stat("catch")
	stat("streak")
	set_stat("streak_best", maxf(value("streak_best"), value("streak")))
	var tier := str(fish.get("tier", ""))
	if tier == "far":
		stat("catch_far")
		if _first_cast_pending:
			stat("first_cast_far")
	_first_cast_pending = false
	var rarity := UiKit.fish_rarity(fish)
	if rarity in ["rare", "epic", "legend"] or str(fish.get("rarity", "")) in ["rare", "epic"]:
		stat("catch_rare")
	if rarity == "legend":
		stat("catch_legend")
	if _player.fishing_mode == Player.FishingMode.LURE:
		stat("catch_lure")
	if _player.caught_in_hotspot:
		stat("catch_hotspot")
	if GameState.weather == GameState.Weather.FISH_RUN:
		stat("catch_fishrun")
	if Dock.on_walkway(_player.get_tree(), _player.global_position + Player.FEET):
		stat("catch_dock")
	var id := str(fish.get("id", ""))
	if id != "":
		_species[id] = true
		if FishData.habit_for(str(fish.get("name", ""))) == "jumper":
			stat("catch_jumper")


const LOSSES := ["line_break", "shook_off", "cover", "missed_bite", "spooked", "walked_off", "line_cut", "lure_knocked"]


func _on_failed(reason: String) -> void:
	if reason in ["no_bite", "bait_nibbled", "bait_stolen"] or not reason in LOSSES:
		_first_cast_pending = false
		return
	_first_cast_pending = false
	stat("lost_fish")
	set_stat("streak", 0.0)
	if reason == "line_break":
		stat("line_break")


func _on_fight_event(kind: String) -> void:
	match kind:
		"swipe_hit":
			stat("swipe_hit")
		"run", "side_run":
			stat("fight_run")
		"jump":
			stat("fish_jump")


func _on_weather_changed(kind: String) -> void:
	match kind:
		"FISH_RUN":
			stat("fish_run")
		"STORM":
			stat("storm")
		"FOG":
			stat("fog")


# ---------------------------------------------------------------- guiding

## Where the tutorial's arrow points for `what` (Vector2.INF: nowhere).
func target(what: String) -> Vector2:
	if _main == null or _player == null:
		return Vector2.INF
	var me := _player.global_position
	match what:
		"water", "rare":
			var group := "water_zones_rare" if what == "rare" else "water_zones_common"
			var best := Vector2.INF
			for zone in _player.get_tree().get_nodes_in_group(group):
				var p: Vector2 = zone.shore_point((me - zone.global_position).normalized())
				if what == "rare":
					p = zone.global_position
				if p.distance_to(me) < best.distance_to(me):
					best = p
			return best
		"altar":
			return _node_at("Altar")
		"escape":
			return _node_at("EscapePoint")
		"camp":
			return _node_at("FuelStation")
		"willow":
			return _node_at("Willow")
		"oil":
			var drum: Node2D = _main.get_node_or_null("OilDrum")
			if drum == null or not drum.visible or _player.carrying_oil_drum:
				return Vector2.INF
			return drum.global_position
		"hotspot":
			var spot: Node2D = _main.get_node_or_null("Hotspot")
			if spot == null or not spot.active or not spot.visible:
				return Vector2.INF
			return spot.global_position
		"rock", "critter", "dock":
			var best := Vector2.INF
			for c in _main.get_children():
				var ok := false
				if what == "rock":
					ok = c is FlipRock and c.active
				elif what == "critter":
					ok = c is Critter and not c.ambient and c.active and c.visible
				else:
					ok = c is Dock
				if ok and c.global_position.distance_to(me) < best.distance_to(me):
					best = c.global_position
			return best
	return Vector2.INF


func _node_at(node_name: String) -> Vector2:
	var n: Node2D = _main.get_node_or_null(node_name)
	return n.global_position if n != null else Vector2.INF


func tutorial_steps() -> Array:
	if not Profile.settings.get("hints", true):
		return []
	return TUTORIALS.get(str(rules.tutorial), [])


# ---------------------------------------------------------------- the end

## The stars a finished run earns: [out, ★★, ★★★].
func stars_earned(success: bool) -> Array:
	var out := [success, false, false]
	if not success or not is_level():
		return out
	var conds: Array = level(level_id).stars
	for i in conds.size():
		out[i + 1] = condition_met(conds[i])
	return out


## Whether a star's condition holds now.
func condition_met(c: Dictionary) -> bool:
	var v := value(str(c.stat))
	if c.has("min") and v < float(c.min):
		return false
	if c.has("max") and v > float(c.max):
		return false
	return true


func _on_run_ended(success: bool, _message: String) -> void:
	if _main == null:
		return
	finish(success)


## Scores the run: its stars and rewards (a level), the lifetime records,
## the achievements. The end screen reads `result`.
func finish(success: bool) -> Dictionary:
	if success:
		run["won"] = 1.0
		if GameState.is_night:
			stat("escaped_night")
		if GameState.evil_count == 0:
			stat("pure_escape")
		stat("escaped")
	var stars := stars_earned(success)
	result = {"success": success, "level": level_id, "stars": stars, "new_stars": [], "gold": 0,
		"items": {}, "achievements": [], "first_clear": false, "chapter_done": false, "curse_gold": 0}
	if is_level() and success:
		_score_level(stars)
	elif success and not curses.is_empty():
		var bonus := 0.0
		for c in curses:
			bonus += float(CURSES[c].bonus)
		var gold := int(roundf(GameState.quota_progress * bonus))
		if gold > 0:
			Profile.add_gold(gold)
			result.curse_gold = gold
		if level_done("5-5"):
			Profile.record_curse_clear(curses)
	elif is_level():
		Profile.record_level_try(level_id)
	_record_life()
	result.achievements = check_achievements()
	return result


func _score_level(stars: Array) -> void:
	var before: Array = Profile.level_stars(level_id)
	var first := not bool(before[0])
	var merged := []
	var new_stars := []
	for i in 3:
		var got: bool = bool(before[i]) or bool(stars[i])
		merged.append(got)
		if got and not bool(before[i]):
			new_stars.append(i)
	Profile.record_level(level_id, merged, value("elapsed"))
	var gold := STAR_GOLD * new_stars.size()
	var items := {}
	if first:
		var reward: Dictionary = level(level_id).reward
		gold += int(reward.get("gold", 0))
		items = reward.get("items", {}).duplicate()
		for id in items:
			Profile._store(id, int(items[id]))
	var ch: int = level(level_id).chapter
	var chapter_full := true
	for l in levels_of(ch):
		var s: Array = Profile.level_stars(l.id)
		if not (bool(s[0]) and bool(s[1]) and bool(s[2])):
			chapter_full = false
	if chapter_full and not Profile.chapter_bonus_paid(ch):
		gold += CHAPTER_GOLD
		Profile.pay_chapter_bonus(ch)
		result.chapter_full = true
	if gold > 0:
		Profile.add_gold(gold)
	result.first_clear = first
	result.new_stars = new_stars
	result.gold = gold
	result.items = items
	var last: Dictionary = levels_of(ch).back()
	result.chapter_done = first and last.id == level_id


## The run's counts added into the lifetime records.
func _record_life() -> void:
	var add := {}
	for key in run:
		if not key in RUN_ONLY:
			add[key] = run[key]
	Profile.add_records(add)


# ---------------------------------------------------------------- progress

func level_done(id: String) -> bool:
	return bool(Profile.level_stars(id)[0])


func stars_total() -> int:
	var n := 0
	for l in LEVELS:
		for s in Profile.level_stars(l.id):
			if s:
				n += 1
	return n


func chapter_stars(ch: int) -> int:
	var n := 0
	for l in levels_of(ch):
		for s in Profile.level_stars(l.id):
			if s:
				n += 1
	return n


## A chapter opens once the one before is through and enough stars are in.
func chapter_open(ch: int) -> bool:
	if ch <= 1:
		return true
	var before := levels_of(ch - 1)
	return level_done(before.back().id) and stars_total() >= int(chapter(ch).stars)


func chapter_done(ch: int) -> bool:
	return level_done(levels_of(ch).back().id)


func level_open(id: String) -> bool:
	var l := level(id)
	if l.is_empty() or not chapter_open(l.chapter):
		return false
	var mine := levels_of(l.chapter)
	var i := mine.find(l)
	return i <= 0 or level_done(mine[i - 1].id)


## The free run: after chapter 1, or straight away on a save that's
## already been out (from before the campaign).
func free_open() -> bool:
	return chapter_done(1) or int(Profile.stats.get("escapes", 0)) > 0


func curses_open() -> bool:
	return chapter_done(5)


## The level to suggest: the first not yet cleared that's open.
func next_to_play() -> String:
	for l in LEVELS:
		if level_open(l.id) and not level_done(l.id):
			return l.id
	return LEVELS.back().id


# ---------------------------------------------------------------- achievements

func achievement_done(a: Array) -> bool:
	return _check(a[5])


func _check(c: Dictionary) -> bool:
	if c.has("all"):
		for part in c.all:
			if not _check(part):
				return false
		return true
	if c.has("level"):
		return level_done(c.level)
	if c.has("chapter"):
		return chapter_done(int(c.chapter))
	if c.has("stars"):
		return stars_total() >= int(c.stars)
	if c.has("log"):
		return Profile.log_percent() >= float(c.log)
	if c.has("life"):
		return Profile.record(str(c.life)) >= float(c.min)
	if c.has("run"):
		if c.get("won", false) and not run.has("won"):
			return false
		if _main == null and run.is_empty():
			return false
		var v := value(str(c.run))
		if c.has("min") and v < float(c.min):
			return false
		if c.has("max") and v > float(c.max):
			return false
		return true
	return false


## Unlocks what's newly done and pays for it; returns their ids.
func check_achievements() -> Array:
	var got := []
	for a in ACHIEVEMENTS:
		if Profile.has_achievement(a[0]):
			continue
		if achievement_done(a):
			Profile.grant_achievement(a[0], int(a[4]))
			got.append(a[0])
			achievement_unlocked.emit(a[0])
	return got


static func achievement(id: String) -> Array:
	for a in ACHIEVEMENTS:
		if a[0] == id:
			return a
	return []


## How far along an achievement is, [now, needed] (needed 0: yes/no).
func achievement_progress(a: Array) -> Array:
	var c: Dictionary = a[5]
	if c.has("life"):
		return [Profile.record(str(c.life)), float(c.min)]
	if c.has("stars"):
		return [float(stars_total()), float(c.stars)]
	if c.has("log"):
		return [Profile.log_percent(), float(c.log)]
	return [1.0 if Profile.has_achievement(a[0]) else 0.0, 0.0]


# ---------------------------------------------------------------- words

## Willow's words with the controls put in for this device.
static func say(text: String) -> String:
	var touch := DisplayServer.is_touchscreen_available()
	for key in CONTROLS:
		text = text.replace("{%s}" % key, CONTROLS[key][0 if touch else 1])
	return text


static func star_text(cond: Dictionary) -> String:
	return str(cond.text)
