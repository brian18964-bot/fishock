class_name FishLife
extends RefCounted

## User request: fish have a vitality (活性) and a freshness (新鮮度).
## Caught, a fish has some vitality, which runs down with time; at nothing
## it's marked dead (死亡) and its freshness shows instead, which also runs
## down; at nothing it's rotten (腐敗). Each fish rolls its own start and its
## own pace (a low start that goes down slowly, a high one that drops fast...),
## and 0-2 traits that bend them (TRAITS - they can come together: 垂死 +
## 頑強 is low and slow, 垂死 + 潔身 dies at once and keeps long).
##
## A fish dict keeps it all: vit (0..1), vit_life (s from full to nothing),
## dead, fresh (0..1), fresh_life (s from fresh to rotten; <= INSTANT: rots as
## it dies), rotten, life_traits. Time goes by in a run (GameState._process
## ticks the bag; a fish put down ticks on the ground); at home they keep (the
## tank's alive, the box's cold).

## The traits: name, what it does, how often they come up (weight), and the
## sort of thing it is: "vit" (the vitality's pace), "fresh" (the
## freshness'), "start", "value".
const TRAITS := {
	"immortal": {"name": "不死", "desc": "活性歸零也不會死亡", "weight": 2.0, "kind": "vit"},
	"tough": {"name": "頑強", "desc": "活性下降速度慢", "weight": 10.0, "kind": "vit", "vit": 0.4},
	"weary": {"name": "厭世", "desc": "活性下降速度快", "weight": 10.0, "kind": "vit", "vit": 2.5},
	"dying": {"name": "垂死", "desc": "釣起來活性就偏低（低於 30%）", "weight": 8.0, "kind": "start"},
	"vigorous": {"name": "生猛", "desc": "釣起來活性特別高（90% 以上）", "weight": 8.0, "kind": "start"},
	"nocturnal": {"name": "夜行", "desc": "夜晚活性下降速度減半", "weight": 6.0, "kind": "vit"},
	"filthy": {"name": "骯髒", "desc": "新鮮度下降速度快", "weight": 9.0, "kind": "fresh", "fresh": 2.5},
	"clean": {"name": "潔身", "desc": "新鮮度下降速度慢", "weight": 9.0, "kind": "fresh", "fresh": 0.4},
	"imperishable": {"name": "不腐", "desc": "新鮮度歸零也不會腐敗", "weight": 3.0, "kind": "fresh"},
	"plump": {"name": "肥美", "desc": "價值提高 25%", "weight": 7.0, "kind": "value", "value": 1.25},
	"scrawny": {"name": "瘦弱", "desc": "價值降低 20%", "weight": 7.0, "kind": "value", "value": 0.8},
	# User request: the very rare ones (MYTHIC_CHANCE) - each with a use of
	# its own: in the tank (fortune, guide, smith) or in the bag (wraith, angel).
	"fortune": {"name": "財神", "desc": "養在魚缸：每小時送來 20 金幣（最多累積 12 小時）", "weight": 1.0, "kind": "mythic"},
	"guide": {"name": "引路魚", "desc": "養在魚缸：每次夜晚成功逃脫，有 10% 機率帶回一個隨機的眼球道具", "weight": 1.0, "kind": "mythic"},
	"smith": {"name": "鐵匠", "desc": "養在魚缸：餵食腐敗的魚後，可選一件裝備回復 5 點耐久", "weight": 1.0, "kind": "mythic"},
	"wraith": {"name": "惡靈", "desc": "腐敗後放在包包：猛獸攻擊 -20%，但小鬼偷襲 +10%", "weight": 1.0, "kind": "mythic"},
	"luckystar": {"name": "幸運星", "desc": "放在包包裡：釣到稀有魚的機率微幅提升（+3%）", "weight": 1.0, "kind": "mythic"},
	"angel": {"name": "天使", "desc": "活著時放在包包：小鬼偷襲 -60%，猛獸攻擊 -50%", "weight": 1.0, "kind": "mythic"},
}
const MYTHIC := ["fortune", "guide", "smith", "wraith", "angel", "luckystar"]
## A catch's chance of one of them, by its rarity.
const MYTHIC_CHANCE := {"common": 0.012, "rare": 0.025, "epic": 0.05}
## Their numbers (user: set as these for now).
const FORTUNE_GOLD := 20
const FORTUNE_CAP_HOURS := 12.0
const GUIDE_CHANCE := 0.10
const GUIDE_EYES := ["eyeball", "eye_altar", "eye_ghost"]
const SMITH_REPAIR := 5
const WRAITH_BEAST := 0.20
const WRAITH_IMP := 0.10
const ANGEL_IMP := 0.60
const ANGEL_BEAST := 0.50
## 幸運星 in the bag: a rare catch this much more likely (each; at most
## LUCK_MOST in all).
const LUCK_RARE := 0.03
const LUCK_MOST := 0.12
## The traits to the fish's good (the rest - to its bad; the mythic ones, gold).
const GOOD := ["immortal", "tough", "vigorous", "nocturnal", "clean", "imperishable", "plump"]
## Traits that don't go together (each group: at most one).
const EXCLUSIVE := [["tough", "weary", "immortal"], ["filthy", "clean", "imperishable"], ["dying", "vigorous"],
	["plump", "scrawny"]]
## How many traits a fish rolls, by its rarity: weights for 0, 1, 2.
const TRAIT_COUNT := {"common": [50.0, 38.0, 12.0], "rare": [35.0, 45.0, 20.0], "epic": [20.0, 50.0, 30.0]}

## The vitality the dying start under, and the vigorous over.
const DYING_START := Vector2(0.05, 0.29)
const VIGOROUS_START := Vector2(0.9, 1.0)
## Night's slowing for the nocturnal.
const NIGHT_VIT := 0.5
## A fish whose freshness lasts no longer than this (s) rots as it dies.
const INSTANT := 1.0

## Per kind of fish (by how it keeps): start vitality, seconds of vitality
## from full to nothing, seconds of freshness from fresh to rotten. A
## kind's own, rolled within.
const KINDS := {
	"normal": {"start": Vector2(0.55, 1.0), "life": Vector2(150, 330), "fresh": Vector2(200, 480)},
	"hardy": {"start": Vector2(0.7, 1.0), "life": Vector2(400, 800), "fresh": Vector2(420, 900)},
	"delicate": {"start": Vector2(0.45, 0.95), "life": Vector2(50, 120), "fresh": Vector2(90, 240)},
	"sea": {"start": Vector2(0.5, 1.0), "life": Vector2(100, 220), "fresh": Vector2(150, 360)},
	"giant": {"start": Vector2(0.75, 1.0), "life": Vector2(300, 600), "fresh": Vector2(400, 800)},
	# (spoils as it dies)
	"fragile": {"start": Vector2(0.45, 0.9), "life": Vector2(40, 100), "fresh": Vector2(0.5, 0.5)},
	# (never rots: a ghost, a fossil)
	"undying": {"start": Vector2(0.7, 1.0), "life": Vector2(300, 600), "fresh": Vector2(-1, -1)},
}
const KIND_OF := {
	"hardy": ["carp", "crucian", "catfish", "black_catfish", "walking_catfish", "channel_cat", "eel", "swamp_eel", "loach",
		"goby", "lungfish", "bichir", "bowfin", "snakehead", "climbing_perch", "pleco", "betta", "giant_goldfish",
		"crayfish", "pupfish", "devils_pupfish", "garra", "desert_sucker", "bonytail", "tilapia"],
	"delicate": ["rainbow_trout", "brown_trout", "brook_trout", "golden_trout", "grayling", "ayu", "char", "arctic_char",
		"sockeye", "whitefish", "sculpin", "minnow", "bluegill", "perch"],
	"fragile": ["sardine", "herring", "saury", "smelt", "horse_mackerel"],
	"giant": ["wels", "arapaima", "alligator_gar", "taimen", "sturgeon", "paddlefish", "arowana", "two_headed_carp",
		"golden_koi", "napoleon", "sunfish", "swordfish", "bluefin", "sailfish", "hammerhead"],
	"undying": ["ghost_fish", "coelacanth"],
}


## What a dead fish sells for, of its value: the stalest .. the freshest.
const DEAD_WORTH := Vector2(0.4, 0.9)


## A fish's kind of keeping ("sea" for the sea's, else "normal").
static func kind_for(id: String) -> String:
	for k in KIND_OF:
		if id in KIND_OF[k]:
			return k
	if id in FishData.SEA_COMMON or id in FishData.SEA_RARE or id in FishData.SEA_LEGEND:
		return "sea"
	return "normal"


## Whether a fish dict has its life rolled.
static func has_life(f: Dictionary) -> bool:
	return f.has("vit")


## Rolls a catch's life into `f` (its id, rarity set): vitality and paces
## by its kind, then its traits. Its value is bent by its traits' (肥美...).
static func roll(f: Dictionary) -> Dictionary:
	var id: String = f.get("id", "")
	var kind: Dictionary = KINDS[kind_for(id)]
	var traits := roll_traits(str(f.get("rarity", "common")))
	var start := randf_range(kind.start.x, kind.start.y)
	if "dying" in traits:
		start = randf_range(DYING_START.x, DYING_START.y)
	elif "vigorous" in traits:
		start = randf_range(VIGOROUS_START.x, VIGOROUS_START.y)
	f["vit"] = snappedf(start, 0.001)
	f["vit_life"] = snappedf(randf_range(kind.life.x, kind.life.y), 0.1)
	f["fresh"] = 1.0
	f["fresh_life"] = -1.0 if kind.fresh.x < 0.0 else snappedf(randf_range(kind.fresh.x, kind.fresh.y), 0.1)
	f["dead"] = false
	f["rotten"] = false
	if randf() < float(MYTHIC_CHANCE.get(str(f.get("rarity", "common")), MYTHIC_CHANCE.common)):
		traits.append(MYTHIC.pick_random())
	f["life_traits"] = traits
	for t in traits:
		if TRAITS[t].has("value") and f.has("value"):
			f["value"] = float(f.value) * float(TRAITS[t].value)
	return f


## A fish that came without a life (older ones, a test's) gets one.
static func ensure(f: Dictionary) -> void:
	if not has_life(f):
		var rotten: bool = f.get("rotten", false)
		roll(f)
		if rotten:
			kill(f)


## 0-2 traits for a fish of `rarity`, none that clash.
static func roll_traits(rarity: String) -> Array:
	var counts: Array = TRAIT_COUNT.get(rarity, TRAIT_COUNT.common)
	var pick: float = randf() * (float(counts[0]) + float(counts[1]) + float(counts[2]))
	var n := 0 if pick < float(counts[0]) else (1 if pick < float(counts[0]) + float(counts[1]) else 2)
	var out: Array = []
	for _i in n:
		var pool := []
		var total := 0.0
		for t in TRAITS:
			if t in MYTHIC or t in out or _clashes(t, out):
				continue
			pool.append(t)
			total += float(TRAITS[t].weight)
		var at := randf() * total
		for t in pool:
			at -= float(TRAITS[t].weight)
			if at <= 0.0:
				out.append(t)
				break
	return out


static func _clashes(t: String, have: Array) -> bool:
	for group in EXCLUSIVE:
		if t in group:
			for h in have:
				if h in group:
					return true
	return false


static func has_trait(f: Dictionary, t: String) -> bool:
	return t in f.get("life_traits", [])


## Vitality lost per second (the traits bending it; `night` for the nocturnal).
static func vit_rate(f: Dictionary, night := false) -> float:
	var rate := 1.0 / maxf(float(f.get("vit_life", 200.0)), 1.0)
	for t in f.get("life_traits", []):
		rate *= float(TRAITS[t].get("vit", 1.0))
		if t == "nocturnal" and night:
			rate *= NIGHT_VIT
	return rate


## Freshness lost per second once dead (0 never; rots at once past INSTANT).
static func fresh_rate(f: Dictionary) -> float:
	var life := float(f.get("fresh_life", 300.0))
	if life < 0.0 or has_trait(f, "imperishable"):
		return 0.0
	var rate := 1.0 / maxf(life, 0.001)
	for t in f.get("life_traits", []):
		rate *= float(TRAITS[t].get("fresh", 1.0))
	return rate


## What the map's finds do (user request): 魚氧藻 - for ALGAE_TIME s of its
## living time a fish's vitality runs down at SLOW of its pace; 冷凍土 - for
## FROZEN_TIME s of its dead time the freshness does. (Time on the clock
## runs only while it matters, so none is wasted on a fish yet to die.)
const SLOW := 0.25
const ALGAE_TIME := 180.0
const FROZEN_TIME := 300.0


## Oxygen algae on a fish: "" done, else why not.
static func use_algae(f: Dictionary) -> String:
	if state(f) != "alive":
		return "這條魚已經死了"
	if has_trait(f, "immortal"):
		return "這條魚不會死，用不到"
	f["vit_slow"] = ALGAE_TIME
	return ""


## Frozen soil on a fish: "" done, else why not.
static func use_frozen(f: Dictionary) -> String:
	if state(f) == "rotten":
		return "這條魚已經腐敗了"
	if has_trait(f, "imperishable") or float(f.get("fresh_life", 300.0)) < 0.0:
		return "這條魚不會腐敗，用不到"
	f["fresh_slow"] = FROZEN_TIME
	return ""


## `value` run down at `rate` a second for `dt` s, the first `slow` s of it at
## SLOW of that: [what's left (0 if it ran out), time left over (-1 if it
## didn't run out), the slow time left].
static func _run(value: float, rate: float, slow: float, dt: float) -> Array:
	var t_slow := minf(slow, dt)
	var slow_drop := rate * SLOW * t_slow
	if value <= slow_drop:
		var used := value / (rate * SLOW)
		return [0.0, dt - used, slow - used]
	value -= slow_drop
	dt -= t_slow
	slow -= t_slow
	var need := value / rate
	if need > dt:
		return [value - rate * dt, -1.0, slow]
	return [0.0, dt - need, slow]


## How long (s) `value` lasts at `rate`, with `slow` s of it slowed.
static func _lasts(value: float, rate: float, slow: float) -> float:
	var slow_drop := rate * SLOW * slow
	if value <= slow_drop:
		return value / (rate * SLOW)
	return slow + (value - slow_drop) / rate


## Time goes by (`dt` s). "died" / "rotted" when this tick did it, else "".
static func tick(f: Dictionary, dt: float, night := false) -> String:
	if f.get("rotten", false) or not has_life(f) or dt <= 0.0:
		return ""
	var said := ""
	var left := dt
	if not f.dead:
		if has_trait(f, "immortal"):
			return ""
		var run := _run(float(f.vit), vit_rate(f, night), float(f.get("vit_slow", 0.0)), left)
		f.vit = maxf(float(run[0]), 0.0)
		f["vit_slow"] = maxf(float(run[2]), 0.0)
		if float(run[1]) < 0.0:
			return ""
		left = float(run[1])
		f.vit = 0.0
		f.dead = true
		said = "died"
	var fr := fresh_rate(f)
	if fr <= 0.0:
		return said
	if float(f.get("fresh_life", 300.0)) <= INSTANT:
		rot(f)
		return "rotted"
	var run := _run(float(f.fresh), fr, float(f.get("fresh_slow", 0.0)), left)
	f.fresh = maxf(float(run[0]), 0.0)
	f["fresh_slow"] = maxf(float(run[2]), 0.0)
	if float(run[1]) >= 0.0:
		rot(f)
		return "rotted"
	return said


## Dead on the spot (vitality gone) - a fish put down in a hurry, a test's.
static func kill(f: Dictionary) -> void:
	f["vit"] = 0.0
	f["dead"] = true
	if fresh_rate(f) > 0.0 and float(f.get("fresh_life", 300.0)) <= INSTANT:
		rot(f)


## Past eating: no value, only the sacrifice's gamble left (GameState).
static func rot(f: Dictionary) -> void:
	f["dead"] = true
	f["fresh"] = 0.0
	f["rotten"] = true
	f["value"] = 0.0
	f["tier"] = "rotten"


## "alive" / "dead" / "rotten".
static func state(f: Dictionary) -> String:
	if f.get("rotten", false):
		return "rotten"
	return "dead" if f.get("dead", false) else "alive"


## What it's worth (a living one in full; a dead one by how fresh; a rotten
## one nothing): the sacrifice's credit and the price.
static func worth(f: Dictionary) -> float:
	match state(f):
		"rotten":
			return 0.0
		"dead":
			return float(f.get("value", 0.0)) * lerpf(DEAD_WORTH.x, DEAD_WORTH.y, float(f.get("fresh", 0.0)))
	return float(f.get("value", 0.0))


## What it sells for (gold; at least 1 unless rotten).
static func sale_value(f: Dictionary) -> int:
	return 0 if state(f) == "rotten" else maxi(1, roundi(worth(f)))


## The bar to show: its share (0..1) and what it is.
static func bar(f: Dictionary) -> Dictionary:
	match state(f):
		"alive":
			return {"label": "活性", "share": float(f.get("vit", 1.0)), "kind": "vit"}
		"dead":
			return {"label": "新鮮度", "share": float(f.get("fresh", 0.0)), "kind": "fresh"}
	return {"label": "新鮮度", "share": 0.0, "kind": "rotten"}


## "頑強・垂死" ("" none).
static func traits_text(f: Dictionary) -> String:
	var names := []
	for t in f.get("life_traits", []):
		names.append(TRAITS[t].name)
	return "・".join(names)


## One line each: a trait's name - what it does.
static func trait_lines(f: Dictionary) -> Array:
	var out := []
	for t in f.get("life_traits", []):
		out.append("%s：%s" % [TRAITS[t].name, TRAITS[t].desc])
	return out


## "活躍／已死亡／腐敗了" for the card.
static func state_text(f: Dictionary) -> String:
	return {"alive": "活著", "dead": "已死亡", "rotten": "腐敗了"}[state(f)]


## How long (s) a living fish lasts as it is (infinity: never).
static func lifespan_left(f: Dictionary, night := false) -> float:
	if state(f) != "alive" or has_trait(f, "immortal"):
		return INF
	return _lasts(float(f.vit), vit_rate(f, night), float(f.get("vit_slow", 0.0)))


## How long (s) a dead fish keeps (infinity: never; 0 once rotten).
static func freshness_left(f: Dictionary) -> float:
	if state(f) == "rotten":
		return 0.0
	var fr := fresh_rate(f)
	if fr <= 0.0:
		return INF
	return _lasts(float(f.get("fresh", 1.0)), fr, float(f.get("fresh_slow", 0.0)))


## How many of the tank's fish (dicts) have `t`.
static func count_trait(fish: Array, t: String) -> int:
	var n := 0
	for f in fish:
		n += 1 if has_trait(f, t) else 0
	return n


## What the carried fish do for the traveller (user request): the angel
## (while alive) and the wraith (once rotten) in the bag. The chance a
## beast's pounce is turned aside.
static func beast_ward(carried: Array) -> float:
	var open := 1.0
	for f in carried:
		if has_trait(f, "angel") and state(f) == "alive":
			open *= 1.0 - ANGEL_BEAST
		if has_trait(f, "wraith") and state(f) == "rotten":
			open *= 1.0 - WRAITH_BEAST
	return 1.0 - open


## How much sooner the little ghosts come to trouble the traveller (1: as
## usual; the angel's slow them, the wraith's hasten them).
static func imp_rate(carried: Array) -> float:
	var rate := 1.0
	for f in carried:
		if has_trait(f, "angel") and state(f) == "alive":
			rate *= 1.0 - ANGEL_IMP
		if has_trait(f, "wraith") and state(f) == "rotten":
			rate *= 1.0 + WRAITH_IMP
	return rate


## How much likelier a rare catch is with the lucky stars carried (any state).
static func luck_bonus(carried: Array) -> float:
	return minf(float(count_trait(carried, "luckystar")) * LUCK_RARE, LUCK_MOST)
