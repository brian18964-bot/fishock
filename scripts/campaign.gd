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
## (user request - the maps' branches, the later the bigger: an extra-large one too, "XL")
const MAP_SIZES := {"S": Vector2(1300, 760), "M": Vector2(1850, 1050), "L": Vector2(2400, 1350), "XL": Vector2(2900, 1630)}
const MAP_NAMES := {"S": "小", "M": "中", "L": "大", "XL": "特大"}

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
	"tutorial": "", "gift": {}, "hide": [],
}

const CHAPTERS := [
	{"id": 1, "name": "湖畔森林", "stars": 0, "blurb": "森林中的湖泊與池塘，熟悉的夜晚。從小池開始，走進深林的大湖。"},
	{"id": 2, "name": "秋林", "stars": 0, "blurb": "枯樹與落葉，荒田、舊水庫、枯沼，林間只剩零星的野獸——和越來越多的鬼火。"},
	{"id": 3, "name": "雪地森林", "stars": 0, "blurb": "覆雪的松林與結冰的池緣，冷冽的夜，最後是暴風雪裡的冰洞。"},
	{"id": 4, "name": "沙漠綠洲", "stars": 0, "blurb": "沙丘間的綠洲與泉眼，遠古白骨半埋沙中，沙塵暴說來就來。"},
	{"id": 5, "name": "沙灘海岸", "stars": 0, "blurb": "一側是大海，椰子樹下的沙灘與浪花，越往後浪越大。"},
	{"id": 6, "name": "海崖", "stars": 0, "blurb": "草原台地的盡頭是斷崖，崖下浪花拍打礁石，霧與風暴守著深海的大魚。"},
]
## The levels: each map's branches, in order (user request - one level a branch; a map's
## branches open one after another, the next map once the whole of this one's done). stars:
## the ★★ (one of the branch's own fish - its rules' fish / fish_epic) and ★★★ conditions (★ is
## getting out). reward: the first clear's gold and items (into the warehouse).
const LEVELS := [
	{"id": "1-1", "chapter": 1, "name": "林間淺池", "teach": "走路、拋竿、收線、獻祭、離開",
		"intro": "林間有兩個小池，魚很多。先釣一條交給祭壇，再從亮起來的渡石回去。",
		"rules": {"theme": "forest_pine", "map": "S", "ponds": [2, 0], "day": 0.0, "quota": 3.0, "drain": 0.0, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "rocks": [0, 0], "critters": 8, "hotspot": false, "oil": false, "escalate": false, "evil": false, "safe": true, "tutorial": "first_cast", "hide": ["lure", "quick", "energy", "lamp", "bait"], "mods": {"animal_count": 2, "animals": {"deer": 1.0}}, "fish": ["minnow", "goby"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到鱥魚或鰕虎"}, {"stat": "elapsed", "text": "3 分鐘內離開", "max": 180}],
		"reward": {"gold": 40}},
	{"id": "1-2", "chapter": 1, "name": "苔石溪潭", "teach": "活餌：翻石頭找蟲",
		"intro": "石頭多、樹少的溪邊，一串小潭。翻開石頭，底下有蟲可以當餌。",
		"rules": {"bait": 2, "night_fails": true, "safe": true, "theme": "forest_pine", "map": "M", "ponds": [4, 0], "day": 240.0, "quota": 10.0, "drain": 0.5, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": [["CLEAR", 90.0], ["FOG", 60.0], "mild"], "rocks": [14, 18], "critters": 4, "hotspot": false, "escalate": false, "evil": false, "tutorial": "bait", "hide": ["lure", "quick", "energy", "lamp"], "mods": {"rocks": 6, "trees": 16, "animals": {"fox": 1.0, "deer": 1.0}}, "fish": ["char"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到紅點鮭"}, {"stat": "flip_rock", "text": "翻開 3 塊石頭找活餌", "min": 3}],
		"reward": {"gold": 100}},
	{"id": "1-3", "chapter": 1, "name": "霧沼林緣", "teach": "煤燈與夜晚",
		"intro": "林緣的沼澤，水窪一個接一個，蘆葦和睡蓮長滿水面。霧常常湧上來。",
		"rules": {"night_fails": true, "safe": true, "theme": "forest_pine", "map": "L", "ponds": [6, 1], "day": 300.0, "quota": 18.0, "ghosts": 1, "meddle": 2, "big_ghost": false, "water_ghost": 1.6, "hunters": false, "weather": "foggy", "critters": 10, "escalate": false, "evil": false, "tutorial": "lamp", "hide": ["lure", "quick"], "mods": {"shore_extras": {"reeds": 0.3, "lilypad": 0.12, "driftwood": 0.05}, "trees": 22}, "fish": ["swamp_eel", "betta"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到黃鱔或鬥魚"}, {"stat": "water_ghost_hit", "text": "不被水鬼拉到", "max": 0}],
		"reward": {"gold": 130, "items": {"battery": 2}}},
	{"id": "1-4", "chapter": 1, "name": "雙子湖", "teach": "小鬼",
		"intro": "兩座深湖之間的林地。鹿群在湖邊，狼在林子裡。魚群湧現時要把握。",
		"rules": {"night_fails": true, "theme": "forest_pine", "map": "L", "ponds": [2, 1], "day": 300.0, "quota": 26.0, "ghosts": 1, "meddle": 3, "big_ghost": false, "weather": {"FISH_RUN": 0.35, "FOG": 0.12, "DRIZZLE": 0.12}, "critters": 6, "escalate": false, "tutorial": "ghost", "hide": ["lure"], "mods": {"animals": {"deer": 2.5, "stag": 1.5, "wolf": 0.8}}, "fish": [], "fish_epic": ["wels"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到巨型鯰魚"}, {"stat": "catch_rare", "text": "一晚釣到 2 條稀有魚", "min": 2}],
		"reward": {"gold": 170}},
	{"id": "1-5", "chapter": 1, "name": "深林大湖", "teach": "路亞與大鬼",
		"intro": "森林最深處的一座巨湖，四周散著小池。暴雨、狼群，還有醒過來的大鬼。",
		"rules": {"theme": "forest_pine", "map": "XL", "ponds": [4, 1], "day": 360.0, "quota": 35.0, "ghosts": 2, "meddle": 4, "big_ghost": true, "weather": "stormy", "critters": 4, "tutorial": "lure", "hide": [], "mods": {"animals": {"deer": 1.5, "wolf": 1.6, "fox": 1.0}}, "fish": [], "fish_epic": ["alligator_gar"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到鱷雀鱔"}, {"stat": "evil", "text": "達標後留下來獻祭一次", "min": 1}],
		"reward": {"gold": 260, "items": {"lure_redhead": 3}}},
	{"id": "2-1", "chapter": 2, "name": "荒田魚塭", "teach": "熱點",
		"intro": "荒廢田地裡的方正小塘，水淺魚多，田埂上蟲很多。",
		"rules": {"night_fails": true, "theme": "autumn", "map": "S", "ponds": [3, 0], "day": 240.0, "quota": 12.0, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "critters": 10, "escalate": false, "evil": false, "tutorial": "hotspot", "mods": {"trees": 10, "animal_count": 1}, "fish": ["crayfish", "giant_goldfish"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到螯蝦或巨型金魚"}, {"stat": "stolen", "text": "魚獲沒被偷走", "max": 0}],
		"reward": {"gold": 120}},
	{"id": "2-2", "chapter": 2, "name": "舊水庫", "teach": "天氣",
		"intro": "廢棄的水庫，一大片水面加一個小池。水邊有東西會跳出來。",
		"rules": {"night_fails": true, "theme": "autumn", "map": "M", "ponds": [2, 0], "day": 300.0, "quota": 18.0, "ghosts": 1, "meddle": 3, "big_ghost": false, "weather": {"FOG": 0.25, "DRIZZLE": 0.2, "FISH_RUN": 0.15}, "critters": 6, "escalate": false, "tutorial": "weather", "fish": ["silver_carp", "pleco"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到飛躍鯉或清道夫"}, {"stat": "oil_left", "text": "燈油剩一半以上離開", "min": 0.5}],
		"reward": {"gold": 160}},
	{"id": "2-3", "chapter": 2, "name": "枯沼", "teach": "水鬼",
		"intro": "枯樹圍著的暗色水窪，霧散不掉。水鬼就在水邊等著。",
		"rules": {"night_fails": true, "theme": "autumn", "map": "L", "ponds": [6, 1], "day": 300.0, "quota": 26.0, "ghosts": 2, "meddle": 3, "big_ghost": false, "water_ghost": 1.8, "weather": "foggy", "critters": 6, "tutorial": "water_ghost", "mods": {"shore_critters": ["snake", "snake", "frog", "spider"]}, "fish": ["snakehead", "black_catfish"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到烏鱧或黑鯰"}, {"stat": "grabbed", "text": "沒被大鬼或水鬼抓到", "max": 0}],
		"reward": {"gold": 220, "items": {"battery": 3}}},
	{"id": "2-4", "chapter": 2, "name": "鬼火林", "teach": "大鬼",
		"intro": "鬼火飄在分散的深潭之間。小鬼很多，大鬼很早就醒。",
		"rules": {"theme": "autumn", "map": "XL", "ponds": [5, 1], "day": 360.0, "quota": 34.0, "ghosts": 3, "meddle": 5, "big_ghost": true, "big_wake": 1, "weather": "stormy", "critters": 4, "tutorial": "big_ghost", "fish": ["bowfin"], "fish_epic": ["ghost_fish"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到弓鰭魚或幽靈魚"}, {"stat": "species_both", "text": "兩種獨有魚都釣到", "min": 2}],
		"reward": {"gold": 280, "items": {"lure_rainbow": 2}}},
	{"id": "3-1", "chapter": 3, "name": "冰緣小潭", "teach": "營火的燈油",
		"intro": "兩個小池，冰緣很寬，能下竿的水面不多。冷，但很安靜。",
		"rules": {"night_fails": true, "theme": "snow_pine", "map": "S", "ponds": [2, 0], "day": 240.0, "quota": 12.0, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "critters": 2, "rocks": [10, 12], "escalate": false, "evil": false, "tutorial": "oil", "fish": ["sculpin"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到杜父魚"}, {"stat": "oil_delivered", "text": "幫營火加過燈油", "min": 1}],
		"reward": {"gold": 140}},
	{"id": "3-2", "chapter": 3, "name": "雪松河灣", "teach": "",
		"intro": "細長的河灣穿過雪松林，偶爾飄雪，狐狸在岸邊。",
		"rules": {"night_fails": true, "theme": "snow_pine", "map": "M", "ponds": [3, 0], "day": 300.0, "quota": 18.0, "ghosts": 1, "meddle": 3, "big_ghost": false, "weather": "mild", "critters": 2, "escalate": false, "mods": {"animals": {"fox": 2.0, "deer": 1.0}}, "fish": ["paddlefish"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到匙吻鱘"}, {"stat": "flip_rock", "text": "不翻石頭也完成", "max": 0}],
		"reward": {"gold": 180}},
	{"id": "3-3", "chapter": 3, "name": "凍原深湖", "teach": "",
		"intro": "凍原上的一座大湖，霧和雪交替。狼比平常多。",
		"rules": {"theme": "snow_pine", "map": "L", "ponds": [1, 1], "day": 330.0, "quota": 26.0, "ghosts": 1, "meddle": 3, "big_ghost": true, "weather": "foggy", "critters": 1, "mods": {"animals": {"wolf": 1.5, "deer": 1.0, "stag": 1.0}}, "fish": ["sturgeon"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到鱘魚"}, {"stat": "swipe_hit", "text": "沒被野獸撲到", "max": 0}],
		"reward": {"gold": 230}},
	{"id": "3-4", "chapter": 3, "name": "暴雪冰洞", "teach": "",
		"intro": "冰面上鑿開的一個個小冰洞。暴風雪不停，燈油燒得特別快。",
		"rules": {"theme": "snow_pine", "map": "XL", "ponds": [7, 1], "day": 360.0, "quota": 32.0, "drain": 1.4, "ghosts": 2, "meddle": 4, "big_ghost": true, "weather": [["STORM", 120.0], "stormy"], "critters": 1, "mods": {"animals": {"wolf": 2.0, "fox": 1.0}}, "fish": [], "fish_epic": ["cavefish"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到洞穴盲魚"}, {"stat": "quota_met", "text": "暴風雪中達標", "min": 1}],
		"reward": {"gold": 300, "items": {"battery": 3}}},
	{"id": "4-1", "chapter": 4, "name": "旱季水窪", "teach": "",
		"intro": "兩個快乾掉的小水窪，魚擠在一起。天氣晴，很熱。",
		"rules": {"night_fails": true, "theme": "desert", "map": "S", "ponds": [2, 0], "day": 210.0, "quota": 12.0, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "critters": 6, "escalate": false, "evil": false, "fish": ["climbing_perch", "walking_catfish"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到攀鱸或胡子鯰"}, {"stat": "time_left", "text": "還剩 60 秒以上就達標離開", "min": 60}],
		"reward": {"gold": 150}},
	{"id": "4-2", "chapter": 4, "name": "椰棗泉", "teach": "",
		"intro": "椰棗樹下的綠洲泉，旁邊一個小池。駱駝在泉邊喝水。",
		"rules": {"night_fails": true, "theme": "desert", "map": "M", "ponds": [2, 1], "day": 300.0, "quota": 18.0, "ghosts": 1, "meddle": 3, "big_ghost": false, "weather": "mild", "critters": 6, "escalate": false, "mods": {"animals": {"camel": 1.0, "iguana": 0.5}}, "fish": ["angelfish", "oscar"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到神仙魚或地圖魚"}, {"stat": "catch_far", "text": "釣到一條遠處的魚", "min": 1}],
		"reward": {"gold": 190}},
	{"id": "4-3", "chapter": 4, "name": "白骨乾湖", "teach": "",
		"intro": "乾掉的湖床上只剩幾個水潭，化石半埋在沙裡。沙塵偶爾捲起。",
		"rules": {"theme": "desert", "map": "L", "ponds": [4, 1], "day": 330.0, "quota": 26.0, "ghosts": 1, "meddle": 3, "big_ghost": true, "weather": {"SANDSTORM": 0.25, "FISH_RUN": 0.12}, "critters": 3, "mods": {"big_fossils": 5, "animals": {"hyena": 1.0, "camel": 0.3}}, "fish": ["lungfish", "bichir"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到肺魚或恐龍魚"}, {"stat": "swipe_hit", "text": "沒被鬣狗撲到", "max": 0}],
		"reward": {"gold": 240}},
	{"id": "4-4", "chapter": 4, "name": "大綠洲湖", "teach": "",
		"intro": "沙漠中央的大湖，魚群會湧現，鬣狗在暗處。",
		"rules": {"theme": "desert", "map": "L", "ponds": [1, 1], "day": 330.0, "quota": 30.0, "ghosts": 2, "meddle": 3, "big_ghost": true, "weather": {"FISH_RUN": 0.3, "SANDSTORM": 0.15}, "critters": 4, "mods": {"animals": {"hyena": 1.5, "camel": 0.5}}, "fish": ["arowana", "piranha"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到銀龍魚或食人魚"}, {"stat": "catch_rare", "text": "一晚釣到 3 條稀有魚", "min": 3}],
		"reward": {"gold": 270}},
	{"id": "4-5", "chapter": 4, "name": "地底湧泉", "teach": "",
		"intro": "沙丘之間散著深泉眼，地底的水裡住著遠古的魚。沙塵暴一次比一次大。",
		"rules": {"theme": "desert", "map": "XL", "ponds": [5, 1], "day": 360.0, "quota": 38.0, "ghosts": 2, "meddle": 4, "big_ghost": true, "weather": [["SANDSTORM", 90.0], {"SANDSTORM": 0.35, "FISH_RUN": 0.1}], "critters": 2, "fish": ["arapaima"], "fish_epic": ["coelacanth"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到巨骨舌魚或腔棘魚"}, {"stat": "catch_legend", "text": "釣到傳說魚", "min": 1}],
		"reward": {"gold": 320, "items": {"lure_rainbow": 2}}},
	{"id": "5-1", "chapter": 5, "name": "椰林小灣", "teach": "",
		"intro": "椰林圍著的小海灣，海面窄、浪小，沙灘上螃蟹很多。",
		"rules": {"night_fails": true, "theme": "coast", "map": "S", "day": 270.0, "quota": 14.0, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "critters": 8, "escalate": false, "evil": false, "fish": ["moon_jack"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到月光鰺"}, {"stat": "catch_far", "text": "釣到一條遠海的魚", "min": 1}],
		"reward": {"gold": 170}},
	{"id": "5-2", "chapter": 5, "name": "長灘", "teach": "",
		"intro": "長長的沙灘，海面開闊，偶爾起霧。",
		"rules": {"night_fails": true, "theme": "coast", "map": "M", "day": 300.0, "quota": 20.0, "ghosts": 1, "meddle": 3, "big_ghost": false, "weather": "mild", "critters": 5, "escalate": false, "fish": ["trevally"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到浪人鰺"}, {"stat": "catch_rare", "text": "一晚釣到 2 條稀有魚", "min": 2}],
		"reward": {"gold": 210}},
	{"id": "5-3", "chapter": 5, "name": "潟湖灘", "teach": "",
		"intro": "沙灘後方多了一座鹹水潟湖，海霧常從海上漫過來。",
		"rules": {"theme": "coast", "map": "L", "ponds": [1, 1], "day": 330.0, "quota": 28.0, "ghosts": 2, "meddle": 3, "big_ghost": true, "weather": "foggy", "critters": 4, "fish": ["napoleon"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到蘇眉"}, {"stat": "grabbed", "text": "沒被大鬼抓到", "max": 0}],
		"reward": {"gold": 260}},
	{"id": "5-4", "chapter": 5, "name": "大浪灘", "teach": "",
		"intro": "海面最寬、浪最大的沙灘。暴雨一來，浪沖得很遠。",
		"rules": {"theme": "coast", "map": "XL", "day": 360.0, "quota": 36.0, "ghosts": 2, "meddle": 4, "big_ghost": true, "weather": "stormy", "critters": 3, "fish": ["sunfish"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到翻車魚"}, {"stat": "storm", "text": "在暴風雨中撐過去", "min": 1}],
		"reward": {"gold": 300, "items": {"battery": 3}}},
	{"id": "6-1", "chapter": 6, "name": "低崖灣", "teach": "",
		"intro": "崖比較矮、礁石少的海灣，從崖邊往下拋竿。",
		"rules": {"night_fails": true, "theme": "coast_cliff", "map": "S", "day": 270.0, "quota": 14.0, "ghosts": 0, "big_ghost": false, "water_ghost": 0.0, "hunters": false, "weather": "clear", "critters": 3, "escalate": false, "evil": false, "fish": ["sailfish"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到雨傘旗魚"}, {"stat": "catch_far", "text": "釣到一條遠海的魚", "min": 1}],
		"reward": {"gold": 190}},
	{"id": "6-2", "chapter": 6, "name": "礁柱群", "teach": "",
		"intro": "海裡立著許多礁石，浪一波波拍上去。",
		"rules": {"night_fails": true, "theme": "coast_cliff", "map": "M", "day": 300.0, "quota": 22.0, "ghosts": 1, "meddle": 3, "big_ghost": false, "weather": "mild", "critters": 2, "escalate": false, "fish": ["hammerhead"], "fish_epic": []},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到鎚頭鯊"}, {"stat": "catch_rare", "text": "一晚釣到 2 條稀有魚", "min": 2}],
		"reward": {"gold": 230}},
	{"id": "6-3", "chapter": 6, "name": "霧崖", "teach": "",
		"intro": "海霧終年籠罩的高崖，看不清的海面下有大魚。",
		"rules": {"theme": "coast_cliff", "map": "L", "day": 330.0, "quota": 30.0, "ghosts": 2, "meddle": 3, "big_ghost": true, "weather": {"SEA_FOG": 0.45, "FOG": 0.15, "FISH_RUN": 0.1}, "critters": 1, "fish": [], "fish_epic": ["swordfish"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到劍旗魚"}, {"stat": "fog", "text": "在霧中撐過去", "min": 1}],
		"reward": {"gold": 280}},
	{"id": "6-4", "chapter": 6, "name": "暴風岬角", "teach": "終章",
		"intro": "風暴最大的岬角，浪擊最強。深海之王在這裡。",
		"rules": {"theme": "coast_cliff", "map": "XL", "day": 360.0, "quota": 40.0, "ghosts": 3, "meddle": 5, "big_ghost": true, "weather": "stormy", "critters": 1, "fish": [], "fish_epic": ["bluefin"]},
		"stars": [{"stat": "branch_fish", "min": 1, "text": "釣到藍鰭鮪"}, {"stat": "catch_legend", "text": "釣到傳說魚", "min": 1}],
		"reward": {"gold": 500, "items": {"lure_rainbow": 3}}},
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
const RUN_ONLY := ["elapsed", "time_left", "evil", "species", "species_both", "branch_fish", "oil_left", "streak", "streak_best", "near_water",
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
	["dragon_joke", "隱藏", "龍就只是個笑話!", "龍熄滅營火之後，還從渡石逃了出去", 1000, {"run": "escaped_doused", "min": 1, "won": true}],
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
		["額度滿了，渡石亮了！走進光裡就能回營地。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"reach": [
		["{far}，拋得越遠。遠處的魚比較大，也值得比較多。", {"after": 7.0}, ""],
		["試試把浮標拋到池塘中間，釣一條遠海大魚。", {"stat": "catch_far", "min": 1}, "water"],
		["大魚拉力強。張力條太紅就放手，讓牠跑一下再收。", {"after": 7.0}, ""],
		["湊滿額度，就能回去了。", {"stat": "quota_met", "min": 1}, "altar"],
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"bait": [
		["餌只剩兩份。用完就不能用浮標釣了。", {"after": 6.0}, ""],
		["有些石頭可以翻開，底下常有蟲子。走過去{act}「翻開」。", {"stat": "flip_rock", "min": 1}, "rock"],
		["草地上的小動物也能抓來當活餌，比普通的餌好用。", {"stat": "grab_bait", "min": 1}, "critter"],
		["好，餌夠了。繼續釣吧。", {"stat": "quota_met", "min": 1}, ""],
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"lamp": [
		["上方是剩下的時間。時間到天就黑了，這裡天黑前一定要離開。", {"after": 7.0}, ""],
		["天會一點一點暗下來。燈會自己維持一樣亮，但越晚越耗油。", {"after": 7.0}, ""],
		["右上角是燈油。", {"after": 6.0}, ""],
		["油不夠時回營火，就能把燈加滿。", {"stat": "refuel", "min": 1}, "camp"],
		["記得時間。湊滿額度就離開。", {"stat": "quota_met", "min": 1}, ""],
		["快，渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
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
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"lure": [
		["商人給的假餌在背包裡。{mode}，換成路亞。", {"stat": "mode_lure", "min": 1}, ""],
		["路亞要邊收線，魚才會追上來咬。拋出去以後{reel}慢慢收。", {"stat": "catch_lure", "min": 1}, "water"],
		["假餌被扯斷就沒了。張力太紅時一定要放手。", {"stat": "quota_met", "min": 1}, ""],
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"weather": [
		["起霧了，燈照不遠。慢慢走，別迷路。", {"stat": "fish_run", "min": 1}, ""],
		["魚汛來了！這段時間魚特別容易上鉤，把握機會。", {"stat": "catch_fishrun", "min": 3}, "water"],
		["天氣還會再變。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"water_ghost": [
		["暴風雨會讓水鬼更活躍。", {"after": 6.0}, ""],
		["站在岸邊、浮標又落在很近的地方，水鬼就可能冒出來拖住你。拋遠一點。", {"after": 8.0}, ""],
		["站在棧橋上釣，水鬼比較難抓到你。", {"stat": "catch_dock", "min": 1}, "dock"],
		["湊滿額度就離開。", {"stat": "quota_met", "min": 1}, ""],
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"oil": [
		["營火的油不多了。營火熄了，營地就不再安全。", {"after": 7.0}, ""],
		["地圖上有油箱。走過去{act}「提起」。", {"stat": "carrying_oil", "min": 1}, "oil"],
		["提著油箱沒辦法釣魚，先送回營火倒進去。", {"stat": "oil_delivered", "min": 1}, "camp"],
		["油箱過一陣子會在別處出現。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["渡石亮了。", {"stat": "escaped", "min": 1}, "escape"],
	],
	"big_ghost": [
		["天色暗了以後，大鬼會醒來。聽到鐵鍊聲就是牠。", {"stat": "big_awake", "min": 1}, ""],
		["牠會被燈光吸引：燈照到牠，牠就會衝過來。", {"after": 7.0}, ""],
		["被盯上就把燈調暗、離開牠的視線，或躲回營火的光圈裡。", {"after": 8.0}, "camp"],
		["牠進不了營火的光圈。小心地釣，湊滿額度。", {"stat": "quota_met", "min": 1}, ""],
		["額度滿了，鬼群會更兇。快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"flash_big": [
		["強光也能定住大鬼。牠靠近時，{flash}，照牠的臉。", {"stat": "big_ghost_stun", "min": 1}, ""],
		["被抓住的時候，強光照牠也能掙脫。", {"stat": "quota_met", "min": 1}, ""],
		["快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"lure_throw": [
		["大鬼很貪吃。先選一條魚當誘餌：{lure}。", {"stat": "big_ghost_lured", "min": 1}, ""],
		["牠在吃的時候不會管你。趁現在。", {"stat": "quota_met", "min": 1}, ""],
		["快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"heart": [
		["這一趟時間很緊，夜一定會來。入夜後大鬼會直接追你。", {"after": 7.0}, ""],
		["漣漪裡偶爾會釣到一顆還在跳的心臟。帶著牠，被抓時能救你一命。", {"stat": "heart_got", "min": 1}, "hotspot"],
		["有心臟了。被抓住的時候，按畫面上的心臟就能掙脫。", {"stat": "quota_met", "min": 1}, ""],
		["快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"hunters": [
		["雪地上的狼靠太近，就會盯上你。", {"stat": "beast_seen", "min": 1}, ""],
		["被撲倒時，身上的魚會掉在地上。用強光照牠，牠會嚇跑。", {"stat": "beast_scare", "min": 1}, ""],
		["掉在地上的魚可以撿回來。湊滿額度就走。", {"stat": "quota_met", "min": 1}, ""],
		["快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
	],
	"fight": [
		["這裡的魚很會掙扎。魚往外衝時，先放手，讓牠跑。", {"stat": "fight_run", "min": 1}, ""],
		["往旁邊衝時，{swipe}，就是反甩。", {"stat": "swipe_hit", "min": 1}, ""],
		["魚跳出水面時一定要放手，不然會被甩掉。", {"stat": "quota_met", "min": 1}, ""],
		["快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
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
		["快去渡石！", {"stat": "escaped", "min": 1}, "escape"],
	],
}

## The controls' words: [touchscreen, keyboard].
const CONTROLS := {
	"move": ["左搖桿", "WASD"],
	"cast": ["把右搖桿往要拋的方向拉，放開", "滑鼠指向水面，按住空白鍵、放開"],
	"far": ["右搖桿拉得越遠", "空白鍵按得越久"],
	"strike": ["點右搖桿", "按空白鍵"],
	"reel": ["按住右搖桿", "按住空白鍵"],
	"act": ["點旁邊的按鈕", "按 E"],
	"bright": ["長按畫面空白處再上下滑", "按 [ 或 ]"],
	"flash": ["按住燈的按鈕蓄力、放開", "按住 F 蓄力、放開"],
	"mode": ["點左上角的人物卡打開背包，在背包裡切換", "按 Tab"],
	"lure": ["點「誘惑」選魚，再按住往遠處拖、放開", "按 G 選魚，再按住 G、放開"],
	"swipe": ["右搖桿往反方向一甩", "往反方向按方向鍵（WASD）"],
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
	if r.hunters and (not r.beasts.is_empty() or true):
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
	# (no bait comes free with the bag any more: a level without its own count hands out a
	# full bait box, so the first rod of the tutorial can be cast)
	if int(rules.bait) < 0:
		rules.bait = 20
	FishData.branch_fish = rules.get("fish", []).duplicate()
	FishData.branch_epic = rules.get("fish_epic", []).duplicate()
	_apply_world()
	GameState.reset_run()


## Plays the free run next, with these curses (CURSES keys).
func begin_free(chosen: Array = [], theme := "") -> void:
	level_id = ""
	curses = chosen.duplicate()
	rules = DEFAULT_RULES.duplicate(true)
	rules.theme = theme
	FishData.branch_fish = []
	FishData.branch_epic = []
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
	FishData.branch_fish = []
	FishData.branch_epic = []
	rules = DEFAULT_RULES.duplicate(true)
	_apply_world()


func is_level() -> bool:
	return level_id != ""


## User request (the first levels' screen): a level shows only the parts of the HUD it has taught so
## far - rules.hide names the ones still to come: "lure" (the 誘惑 button), "quick" (the quick
## slots), "energy" (the light's box), "lamp" (the light's button), "bait" (the bait on the line).
## A free run hides none.
func hud_hidden(what: String) -> bool:
	return is_level() and what in rules.get("hide", [])


func _apply_world() -> void:
	var size: Vector2 = MAP_SIZES.get(rules.map, MAP_SIZES.L)
	# User request: the 3D run's map (and its ponds) bigger - the 2D one's
	# was made for a closer camera.
	size = (size * RunView3D.MAP_SCALE).round()
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
	if rules.map in ["L", "XL"]:
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
		"oil_left":
			# (the lamp's oil left, of a full one)
			var lamp: Lantern = _player.get_node_or_null("Lantern") as Lantern if _player != null else null
			return lamp.fuel / Lantern.MAX_FUEL if lamp != null else 1.0
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
		# (the branch's own fish, each counted - the ★★; and how many of them caught at all)
		stat("caught_" + id)
		var own: Array = rules.get("fish", []) + rules.get("fish_epic", [])
		if id in own:
			stat("branch_fish")
			var kinds := 0
			for f in own:
				if value("caught_" + str(f)) > 0.0:
					kinds += 1
			set_stat("species_both", float(kinds))
		if FishData.habit_for(str(fish.get("name", ""))) == "jumper":
			stat("catch_jumper")


const LOSSES := ["line_break", "shook_off", "cover", "missed_bite", "bad_strike", "spooked", "walked_off", "line_cut", "lure_knocked"]


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
		"FOG", "DENSE_FOG", "SEA_FOG":
			stat("fog")
		"SANDSTORM":
			stat("sandstorm")
		"DRIZZLE":
			stat("drizzle")


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
	if c.has("any"):
		# (one of several: the branch's own fish - any of them caught)
		for k in c.any:
			if value(str(k)) >= float(c.get("min", 1)):
				return true
		return false
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
		if GameState.dark_fell:
			stat("escaped_doused")
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
		if level_done(LEVELS.back().id):
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
## User request (the developer testing every map): every chapter and level open. Set false for the
## players' release - then a map's branches open one after another, the next map once the whole of
## this one's done.
static var dev_all_open := true


func chapter_open(ch: int) -> bool:
	if ch <= 1 or dev_all_open:
		return true
	var before := levels_of(ch - 1)
	return level_done(before.back().id) and stars_total() >= int(chapter(ch).stars)


func chapter_done(ch: int) -> bool:
	return level_done(levels_of(ch).back().id)


func level_open(id: String) -> bool:
	var l := level(id)
	if l.is_empty() or not chapter_open(l.chapter):
		return false
	if dev_all_open:
		return true
	var mine := levels_of(l.chapter)
	var i := mine.find(l)
	return i <= 0 or level_done(mine[i - 1].id)


## The free run: after chapter 1, or straight away on a save that's
## already been out (from before the campaign).
func free_open() -> bool:
	return chapter_done(1) or int(Profile.stats.get("escapes", 0)) > 0


func curses_open() -> bool:
	return chapter_done(CHAPTERS.size())


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
