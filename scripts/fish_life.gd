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

## User request: the traits are AFFIXES (詞綴): each has a TIER, 1..5 - white,
## green, blue, purple, gold - and its numbers grow with the tier (the `vals`,
## one per tier; 財富's `ranges`). A fish rolls up to MAX_AFFIXES of them,
## more and better the rarer the fish (SLOT_ODDS, TIER_ODDS - odds, not a
## promise: a rare fish needn't have a high one, and a bad one is as good for
## the collection). The mythic ones (gold only) come only on epic fish and up
## (MYTHIC_CHANCE) and take one of the slots. A fish keeps `life_traits` (the
## ids), `trait_tiers` (id -> tier) and, for 財富, `wealth_gold` (rolled in the
## tier's range). One saved without tiers is read as tier 3 (LEGACY_TIER).
##
## name, how often it comes up (weight), what it bends ("kind"), `bad`, `fixed`
## (a tier it always has; `rare_up`: only on rare fish and up), `vals` per tier.
const TRAITS := {
	# -- life (the vitality's pace and start)
	"tough": {"name": "頑強", "weight": 10.0, "kind": "vit", "vals": [0.8, 0.6, 0.4, 0.3, 0.2]},
	"weary": {"name": "厭世", "weight": 10.0, "kind": "vit", "bad": true, "vals": [1.4, 1.8, 2.5, 3.2, 4.0]},
	"dying": {"name": "垂死", "weight": 8.0, "kind": "start", "bad": true, "vals": [0.5, 0.4, 0.29, 0.2, 0.1]},
	"vigorous": {"name": "生猛", "weight": 8.0, "kind": "start", "vals": [0.8, 0.85, 0.9, 0.95, 1.0]},
	"nocturnal": {"name": "夜行", "weight": 6.0, "kind": "vit", "vals": [0.8, 0.65, 0.5, 0.35, 0.2]},
	"immortal": {"name": "不死", "weight": 2.0, "kind": "vit", "fixed": 4, "rare_up": true},
	# -- freshness
	"filthy": {"name": "骯髒", "weight": 9.0, "kind": "fresh", "bad": true, "vals": [1.4, 1.8, 2.5, 3.2, 4.0]},
	"clean": {"name": "潔身", "weight": 9.0, "kind": "fresh", "vals": [0.8, 0.6, 0.4, 0.3, 0.2]},
	"imperishable": {"name": "不腐", "weight": 3.0, "kind": "fresh", "fixed": 4, "rare_up": true},
	# -- worth
	"plump": {"name": "肥美", "weight": 7.0, "kind": "value", "vals": [0.10, 0.18, 0.25, 0.40, 0.60]},
	"scrawny": {"name": "瘦弱", "weight": 7.0, "kind": "value", "bad": true, "vals": [0.08, 0.14, 0.20, 0.30, 0.40]},
	"wealth": {"name": "財富", "weight": 6.0, "kind": "gold", "ranges": [[20, 40], [40, 80], [80, 120], [120, 160], [160, 200]]},
	"faith": {"name": "信仰", "weight": 5.0, "kind": "offer", "vals": [0.10, 0.20, 0.30, 0.45, 0.60]},
	"hold": {"name": "保值", "weight": 5.0, "kind": "hold", "vals": [0.5, 0.6, 0.7, 0.8, 0.9]},
	# -- carried in the bag
	"glow": {"name": "微光", "weight": 4.0, "kind": "bag", "vals": [0.2, 0.3, 0.45, 0.6, 0.8]},
	"savory": {"name": "鮮美", "weight": 4.0, "kind": "bag", "bad": true, "vals": [0.10, 0.20, 0.30, 0.45, 0.60]},
	"smelly": {"name": "腥臭", "weight": 4.0, "kind": "bag", "bad": true, "vals": [0.10, 0.20, 0.30, 0.45, 0.60]},
	# -- the four STATS (屬性) carried in the bag, alive and not weak: each a number
	# rolled in its tier's range (STAT_RANGES) and kept on the fish (`trait_vals`);
	# the sum of all the sources is Stats.total.
	"might": {"name": "力量", "weight": 12.0, "kind": "stat"},
	"resil": {"name": "韌性", "weight": 12.0, "kind": "stat"},
	"react": {"name": "反應", "weight": 12.0, "kind": "stat"},
	"endure": {"name": "耐力", "weight": 12.0, "kind": "stat"},
	# User request: the very rare ones (MYTHIC_CHANCE, epic fish and up, gold) -
	# each with a use of its own: in the tank (fortune, guide, smith) or in the
	# bag (wraith, angel, luckystar).
	"fortune": {"name": "財神", "weight": 1.0, "kind": "mythic", "fixed": 5},
	"guide": {"name": "引路魚", "weight": 1.0, "kind": "mythic", "fixed": 5},
	"smith": {"name": "鐵匠", "weight": 1.0, "kind": "mythic", "fixed": 5},
	"wraith": {"name": "惡靈", "weight": 1.0, "kind": "mythic", "fixed": 5},
	"luckystar": {"name": "幸運星", "weight": 1.0, "kind": "mythic", "fixed": 5},
	"angel": {"name": "天使", "weight": 1.0, "kind": "mythic", "fixed": 5},
}
const MYTHIC := ["fortune", "guide", "smith", "wraith", "angel", "luckystar"]
## A stat affix's number, by tier: rolled anywhere in the range (and a feed
## may move a fish's range - reroll_stat).
const STAT_RANGES := [[1, 4], [5, 8], [9, 14], [15, 22], [23, 32]]
const STAT_IDS := ["might", "resil", "react", "endure"]
## The tiers' names and colours.
const TIER_NAMES := ["普通", "精良", "稀有", "史詩", "傳說"]
const TIER_COLORS := [Color(0.88, 0.88, 0.88), Color(0.45, 0.85, 0.45), Color(0.4, 0.66, 1.0), Color(0.75, 0.5, 0.95), Color(1.0, 0.78, 0.3)]
## How many affixes at most.
const MAX_AFFIXES := 3
## How many a catch rolls (0, 1, 2, 3), by its rarity: weights.
const SLOT_ODDS := {"common": [45.0, 38.0, 14.0, 3.0], "rare": [25.0, 40.0, 25.0, 10.0], "epic": [10.0, 35.0, 35.0, 20.0]}
## Which tier each rolls (1..5), by the fish's rarity: weights. (More rarities
## - the mythic fish to come - go on the end.)
const TIER_ODDS := {"common": [60.0, 28.0, 10.0, 2.0, 0.0], "rare": [25.0, 35.0, 28.0, 10.0, 2.0], "epic": [8.0, 22.0, 32.0, 26.0, 12.0]}
## The mythic ones only come on these (the chance each has of one of them).
const MYTHIC_CHANCE := {"epic": 0.05}
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
## Traits that don't go together (each group: at most one).
const EXCLUSIVE := [["tough", "weary", "immortal"], ["filthy", "clean", "imperishable"], ["dying", "vigorous"],
	["plump", "scrawny"]]
## The tier a fish saved without tiers is read as.
const LEGACY_TIER := 3
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
## by its kind, then its affixes (tiers and all). Its value is bent by the
## worth ones' (肥美, 瘦弱).
static func roll(f: Dictionary) -> Dictionary:
	var id: String = f.get("id", "")
	var kind: Dictionary = KINDS[kind_for(id)]
	var rolled := roll_traits(str(f.get("rarity", "common")))
	var traits: Array = rolled.ids
	var tiers: Dictionary = rolled.tiers
	var start := randf_range(kind.start.x, kind.start.y)
	if "dying" in traits:
		start = randf_range(0.05, float(TRAITS.dying.vals[int(tiers.dying) - 1]))
	elif "vigorous" in traits:
		start = randf_range(float(TRAITS.vigorous.vals[int(tiers.vigorous) - 1]), 1.0)
	f["vit"] = snappedf(start, 0.001)
	f["vit_life"] = snappedf(randf_range(kind.life.x, kind.life.y), 0.1)
	f["fresh"] = 1.0
	f["fresh_life"] = -1.0 if kind.fresh.x < 0.0 else snappedf(randf_range(kind.fresh.x, kind.fresh.y), 0.1)
	f["dead"] = false
	f["rotten"] = false
	f["life_traits"] = traits
	f["trait_tiers"] = tiers
	if "wealth" in traits:
		var span: Array = TRAITS.wealth.ranges[int(tiers.wealth) - 1]
		f["wealth_gold"] = randi_range(int(span[0]), int(span[1]))
	var stat_vals := {}
	for t in traits:
		if STAT_IDS.has(t):
			var r: Array = STAT_RANGES[int(tiers[t]) - 1]
			stat_vals[t] = randi_range(int(r[0]), int(r[1]))
	f["trait_vals"] = stat_vals
	if f.has("value"):
		if "plump" in traits:
			f["value"] = float(f.value) * (1.0 + float(TRAITS.plump.vals[int(tiers.plump) - 1]))
		if "scrawny" in traits:
			f["value"] = float(f.value) * (1.0 - float(TRAITS.scrawny.vals[int(tiers.scrawny) - 1]))
	return f


## A fish that came without a life (older ones, a test's) gets one.
static func ensure(f: Dictionary) -> void:
	if not has_life(f):
		var rotten: bool = f.get("rotten", false)
		roll(f)
		if rotten:
			kill(f)


## The affixes of a catch of `rarity`: {ids: [...], tiers: {id: tier}} - up to
## MAX_AFFIXES, none that clash; a mythic one (epic fish and up only, by
## chance) takes a place among them.
static func roll_traits(rarity: String) -> Dictionary:
	var slots: Array = _odds(SLOT_ODDS, rarity)
	var n := _pick(slots)
	var ids: Array = []
	if MYTHIC_CHANCE.has(rarity) and randf() < float(MYTHIC_CHANCE[rarity]):
		ids.append(MYTHIC.pick_random())
		n = maxi(n, 1)
	var tries := 0
	while ids.size() < mini(n, MAX_AFFIXES) and tries < 40:
		tries += 1
		var pool := []
		var total := 0.0
		for t in TRAITS:
			if t in MYTHIC or t in ids or _clashes(t, ids) or (TRAITS[t].has("rare_up") and rarity in ["common", ""]):
				continue
			pool.append(t)
			total += float(TRAITS[t].weight)
		var at := randf() * total
		for t in pool:
			at -= float(TRAITS[t].weight)
			if at <= 0.0:
				ids.append(t)
				break
	var tiers := {}
	var odds: Array = _odds(TIER_ODDS, rarity)
	for t in ids:
		tiers[t] = int(TRAITS[t].fixed) if TRAITS[t].has("fixed") else _pick(odds) + 1
	return {"ids": ids, "tiers": tiers}


## The weights for `rarity` (the rarer ones to come borrow the epic's).
static func _odds(table: Dictionary, rarity: String) -> Array:
	return table.get(rarity, table.epic if rarity != "" and rarity != "common" else table.common)


## An index picked by weights.
static func _pick(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var at := randf() * total
	for i in weights.size():
		at -= float(weights[i])
		if at <= 0.0:
			return i
	return weights.size() - 1


static func _clashes(t: String, have: Array) -> bool:
	for group in EXCLUSIVE:
		if t in group:
			for h in have:
				if h in group:
					return true
	return false


static func has_trait(f: Dictionary, t: String) -> bool:
	return t in f.get("life_traits", [])


## The tier (1..5) of affix `t` on fish `f` (a fish saved without tiers: 3).
static func tier_of(f: Dictionary, t: String) -> int:
	if TRAITS.get(t, {}).has("fixed"):
		return int(TRAITS[t].fixed)
	return clampi(int(f.get("trait_tiers", {}).get(t, LEGACY_TIER)), 1, 5)


## The number of affix `t` on `f`, by its tier (0 if it hasn't it).
static func val_of(f: Dictionary, t: String) -> float:
	if has_trait(f, t) and STAT_IDS.has(t):
		var r: Array = STAT_RANGES[tier_of(f, t) - 1]
		return float(f.get("trait_vals", {}).get(t, (int(r[0]) + int(r[1])) / 2))
	if not has_trait(f, t) or not TRAITS[t].has("vals"):
		return 0.0
	return float(TRAITS[t].vals[tier_of(f, t) - 1])


static func is_bad(t: String) -> bool:
	return bool(TRAITS.get(t, {}).get("bad", false))


## The colour of the tier of `t` on `f`.
static func trait_color(f: Dictionary, t: String) -> Color:
	return TIER_COLORS[tier_of(f, t) - 1]


## Vitality lost per second (the traits bending it; `night` for the nocturnal).
static func vit_rate(f: Dictionary, night := false) -> float:
	var rate := 1.0 / maxf(float(f.get("vit_life", 200.0)), 1.0)
	for t in f.get("life_traits", []):
		if t == "tough" or t == "weary":
			rate *= val_of(f, t)
		elif t == "nocturnal" and night:
			rate *= val_of(f, t)
	return rate


## Freshness lost per second once dead (0 never; rots at once past INSTANT).
static func fresh_rate(f: Dictionary) -> float:
	var life := float(f.get("fresh_life", 300.0))
	if life < 0.0 or has_trait(f, "imperishable") or is_salted(f):
		return 0.0
	var rate := 1.0 / maxf(life, 0.001)
	for t in f.get("life_traits", []):
		if t == "filthy" or t == "clean":
			rate *= val_of(f, t)
	return rate


## What the map's finds do (user request): 魚氧樹 - for OXY_TREE_TIME s of its
## living time a fish's vitality runs down at SLOW of its pace; 冷凍土 - for
## FROZEN_TIME s of its dead time the freshness does. (Time on the clock
## runs only while it matters, so none is wasted on a fish yet to die.)
const SLOW := 0.25
const OXY_TREE_TIME := 180.0
const FROZEN_TIME := 300.0


## Oxygen algae on a fish: "" done, else why not.
static func use_oxy_tree(f: Dictionary) -> String:
	if state(f) != "alive":
		return "這條魚已經死了"
	if has_trait(f, "immortal"):
		return "這條魚不會死，用不到"
	f["vit_slow"] = OXY_TREE_TIME
	return ""


## Frozen soil on a fish: "" done, else why not.
static func use_frozen(f: Dictionary) -> String:
	if state(f) == "rotten":
		return "這條魚已經腐敗了"
	if has_trait(f, "imperishable") or float(f.get("fresh_life", 300.0)) < 0.0:
		return "這條魚不會腐敗，用不到"
	f["fresh_slow"] = FROZEN_TIME
	return ""


const FEED_VIGOR := 0.5


## Vitality feed on a fish: "" done, else why not.
static func use_vigor_feed(f: Dictionary) -> String:
	if state(f) != "alive":
		return "這條魚已經死了，餵不回來"
	if has_trait(f, "immortal"):
		return "這條魚不會死，用不到"
	if not f.get("weak", false) and float(f.get("vit", 1.0)) >= 0.99:
		return "這條魚活力十足"
	restore(f, FEED_VIGOR)
	return ""


## Revive needle on a dead (not rotten) fish: it lives again, weak. "" done.
static func use_revive(f: Dictionary) -> String:
	match state(f):
		"alive":
			return "這條魚還活著"
		"rotten":
			return "腐敗了，救不回來"
	f["dead"] = false
	f["rotten"] = false
	f["fresh"] = 1.0
	f["vit"] = 1.0
	make_weak(f)
	if not f.get("weak", false):
		# (an immortal one: just up again)
		f["vit"] = 1.0
	return ""


## The stat affixes (ids) a fish has.
static func stat_affixes(f: Dictionary) -> Array:
	return STAT_IDS.filter(func(t): return has_trait(f, t))


## Affix dropper on a fish: every stat affix it has gets its number drawn
## again within its own tier's range (it may come out the same). The affixes
## themselves stay. "" done, else why not; `out` gets a line each ("力量 +5 → +6").
static func use_dropper(f: Dictionary, out: Array = [], _stat := "") -> String:
	var have := stat_affixes(f)
	if have.is_empty():
		return "這條魚沒有屬性詞綴"
	for t in have:
		var before := int(val_of(f, t))
		var after := reroll_stat(f, t)
		var r: Array = STAT_RANGES[tier_of(f, t) - 1]
		out.append("%s +%d → +%d（%d～%d）" % [TRAITS[t].name, before, after, r[0], r[1]])
	return ""


## User request (醃製): salt on a fish that's dead but not rotten - SALT_CHANCE it
## takes: the fish gains salt affixes (`salt`: [{stat, val}], the same stat may come
## again), from the five stats (the four and 幸運), SALT_VALUE each, as many as its
## rarity allows (SALT_COUNT, at random between). A salted fish no longer loses
## freshness, and it counts toward the stats carried even dead.
const SALT_CHANCE := 0.05
const SALT_VALUE := [2, 6]
const SALT_COUNT := {"common": [1, 1], "rare": [1, 2], "epic": [1, 3], "legend": [1, 4]}
const SALT_STATS := ["might", "resil", "react", "endure", "luck"]


static func is_salted(f: Dictionary) -> bool:
	return not f.get("salt", []).is_empty()


## "力量 +4、反應 +3" for a salted fish ("" none).
static func salt_text(f: Dictionary) -> String:
	var parts := []
	for e in f.get("salt", []):
		parts.append("%s +%d" % [Stats.NAMES[e.stat], int(e.val)])
	return "、".join(parts)


## "" if `f` can be salted, else why not.
static func can_salt(f: Dictionary) -> String:
	match state(f):
		"alive":
			return "活著的魚不能醃，要等牠死了"
		"rotten":
			return "已經腐敗了，醃不了"
	if is_salted(f):
		return "這條魚已經醃過了"
	return ""


## Salt on `f`: "" it was used (it took or not - `out` says), else why not.
static func use_salt(f: Dictionary, out: Array = []) -> String:
	var why := can_salt(f)
	if why != "":
		return why
	if not Abilities.roll(SALT_CHANCE):
		out.append("沒有醃成功，鹽用掉了")
		return ""
	var span: Array = SALT_COUNT.get(UiKit.fish_rarity(f), [1, 1])
	var list := []
	for _i in randi_range(int(span[0]), int(span[1])):
		list.append({"stat": SALT_STATS.pick_random(), "val": randi_range(SALT_VALUE[0], SALT_VALUE[1])})
	f["salt"] = list
	out.append("醃製成功！%s" % salt_text(f))
	return ""


## Whether item `id` could be used on `f` now ("" yes, else why not) - without
## using it.
static func can_use(id: String, f: Dictionary) -> String:
	if id == "salt":
		return can_salt(f)
	return apply_item(id, f.duplicate(true))


## A fish item (Profile.USABLES with "target": "fish") on `f`: "" it worked
## (f changed), else why not.
static func apply_item(id: String, f: Dictionary, out: Array = [], stat := "") -> String:
	match id:
		"oxy_tree":
			return use_oxy_tree(f)
		"vigor_feed":
			return use_vigor_feed(f)
		"revive_needle":
			return use_revive(f)
		"affix_dropper":
			return use_dropper(f, out, stat)
		"salt":
			return use_salt(f, out)
	return use_frozen(f)


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
	if f.get("weak", false) and not f.dead:
		# Weak (a night lost): its vitality held low, a grace running - at
		# nothing it dies, the rest of the time on its freshness.
		f["weak_left"] = float(f.get("weak_left", WEAK_TIME)) - dt
		if float(f.weak_left) > 0.0:
			return ""
		left = -float(f.weak_left)
		f["weak"] = false
		f["weak_left"] = 0.0
		f.vit = 0.0
		f.dead = true
		said = "died"
	elif not f.dead:
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


## User request: a night lost leaves the fish brought in weak, not dead: its
## vitality held at WEAK_VIT and WEAK_TIME s to get it back (to the tank, or fed:
## restore) before it dies. 不死 ones are untouched. True if it went weak.
const WEAK_VIT := 0.05
const WEAK_TIME := 300.0


static func make_weak(f: Dictionary) -> bool:
	if state(f) != "alive" or has_trait(f, "immortal"):
		return false
	f["vit"] = WEAK_VIT
	f["weak"] = true
	f["weak_left"] = WEAK_TIME
	return true


## A feed: `amount` (0..1) of vitality back, and no longer weak.
static func restore(f: Dictionary, amount: float) -> void:
	if state(f) != "alive":
		return
	f["weak"] = false
	f["weak_left"] = 0.0
	f["vit"] = minf(float(f.get("vit", 0.0)) + amount, 1.0)


## Dead on the spot (vitality gone) - a fish put down in a hurry, a test's.
static func kill(f: Dictionary) -> void:
	f["weak"] = false
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


## What it's worth (a living one in full; a dead one by how fresh - the stalest
## DEAD_WORTH.x of its value, raised by 保值 - the freshest .9; a rotten one
## nothing): what it counts for at the sale and, before 信仰, the altar.
static func worth(f: Dictionary) -> float:
	match state(f):
		"rotten":
			return 0.0
		"dead":
			var low := maxf(DEAD_WORTH.x, val_of(f, "hold"))
			return float(f.get("value", 0.0)) * lerpf(low, maxf(DEAD_WORTH.y, low), float(f.get("fresh", 0.0)))
	return float(f.get("value", 0.0))


## What it counts for at the altar: its worth, and 信仰's share more.
static func offer_value(f: Dictionary) -> float:
	return worth(f) * (1.0 + val_of(f, "faith"))


## 財富: the extra gold it brings when sold (a dead one's by its freshness).
static func wealth_bonus(f: Dictionary) -> int:
	if not has_trait(f, "wealth") or state(f) == "rotten":
		return 0
	var share := 1.0 if state(f) == "alive" else float(f.get("fresh", 0.0))
	return roundi(float(f.get("wealth_gold", 0)) * share)


## What it sells for (gold; at least 1 unless rotten) - the same wherever it's
## sold: the tank page's 販售, the merchant's 收購.
static func sale_value(f: Dictionary) -> int:
	return 0 if state(f) == "rotten" else maxi(1, roundi(worth(f))) + wealth_bonus(f)


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


## What an affix does, with its numbers (`f`'s tier of it).
static func trait_desc(f: Dictionary, t: String) -> String:
	var v := val_of(f, t)
	match t:
		"tough", "weary":
			return "活性下降速度變成 %d%%" % roundi(v * 100.0)
		"dying":
			return "釣起來活性低於 %d%%" % roundi(v * 100.0)
		"vigorous":
			return "釣起來活性 %d%% 以上" % roundi(v * 100.0)
		"nocturnal":
			return "夜晚活性下降速度再變成 %d%%" % roundi(v * 100.0)
		"immortal":
			return "活性歸零也不會死亡"
		"filthy", "clean":
			return "新鮮度下降速度變成 %d%%" % roundi(v * 100.0)
		"imperishable":
			return "新鮮度歸零也不會腐敗"
		"plump":
			return "價值 +%d%%" % roundi(v * 100.0)
		"scrawny":
			return "價值 -%d%%" % roundi(v * 100.0)
		"wealth":
			return "賣出時額外 +%d 金幣（死魚按新鮮度折算）" % int(f.get("wealth_gold", 0))
		"faith":
			return "獻祭額度 +%d%%" % roundi(v * 100.0)
		"hold":
			return "死後價值最低保有原價的 %d%%（一般是 %d%%）" % [roundi(v * 100.0), roundi(DEAD_WORTH.x * 100.0)]
		"glow":
			return "活著放在包包裡：身邊散發微光（亮度 %d%%）" % roundi(v * 100.0)
		"savory":
			return "放在包包裡：野獸更容易盯上你（發現距離 +%d%%）" % roundi(v * 100.0)
		"smelly":
			return "放在包包裡：小鬼更常來搗亂（頻率 +%d%%）" % roundi(v * 100.0)
		"might", "resil", "react", "endure":
			var r: Array = STAT_RANGES[tier_of(f, t) - 1]
			return "放在包包裡（活著、不虛弱）：%s +%d（這一階 %d～%d）" % [TRAITS[t].name, int(v), int(r[0]), int(r[1])]
		"fortune":
			return "養在魚缸：每小時送來 20 金幣（最多累積 12 小時）"
		"guide":
			return "養在魚缸：每次夜晚成功逃脫，有 10% 機率帶回一個隨機的眼球道具"
		"smith":
			return "養在魚缸：餵食腐敗的魚後，可選一件裝備回復 5 點耐久"
		"wraith":
			return "腐敗後放在包包：猛獸攻擊 -20%，但小鬼偷襲 +10%"
		"luckystar":
			return "放在包包裡：釣到稀有魚的機率微幅提升（+3%）"
		"angel":
			return "活著時放在包包：小鬼偷襲 -60%，猛獸攻擊 -50%"
	return ""


## One line each: an affix's name (and tier) - what it does.
static func trait_lines(f: Dictionary) -> Array:
	var out := []
	for t in f.get("life_traits", []):
		out.append("%s：%s" % [TRAITS[t].name, trait_desc(f, t)])
	return out


## "活躍／已死亡／腐敗了" for the card.
static func state_text(f: Dictionary) -> String:
	return {"alive": "活著", "dead": "已死亡", "rotten": "腐敗了"}[state(f)]


## How long (s) a living fish lasts as it is (infinity: never).
static func lifespan_left(f: Dictionary, night := false) -> float:
	if state(f) != "alive" or has_trait(f, "immortal"):
		return INF
	if f.get("weak", false):
		return float(f.get("weak_left", WEAK_TIME))
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
## usual; the angel's slow them, the wraith's and 腥臭's hasten them).
static func imp_rate(carried: Array) -> float:
	var rate := 1.0
	for f in carried:
		if has_trait(f, "angel") and state(f) == "alive":
			rate *= 1.0 - ANGEL_IMP
		if has_trait(f, "wraith") and state(f) == "rotten":
			rate *= 1.0 + WRAITH_IMP
		rate *= 1.0 + val_of(f, "smelly")
	return rate


## How much farther the beasts notice the traveller (1: as usual): 鮮美 carried.
static func beast_attention(carried: Array) -> float:
	var more := 1.0
	for f in carried:
		more += val_of(f, "savory")
	return more


## The faint light of 微光 carried alive (0..): the brightest of them.
static func glow_level(carried: Array) -> float:
	var best := 0.0
	for f in carried:
		if state(f) == "alive":
			best = maxf(best, val_of(f, "glow"))
	return best


## How much likelier a rare catch is with the lucky stars carried (any state).
static func luck_bonus(carried: Array) -> float:
	return minf(float(count_trait(carried, "luckystar")) * LUCK_RARE, LUCK_MOST)


## User request: a feed rolls a stat affix's number again, within its tier's
## range moved by `lo` and `hi` (0, 0: the range as it is; a feed that lifts
## the floor passes lo > 0...). The tier stays; the number is kept inside the
## 1..99 a stat can be. The new number.
static func reroll_stat(f: Dictionary, t: String, lo := 0, hi := 0) -> int:
	if not has_trait(f, t) or not STAT_IDS.has(t):
		return 0
	var r: Array = STAT_RANGES[tier_of(f, t) - 1]
	var a := clampi(int(r[0]) + lo, 1, 99)
	var b := clampi(int(r[1]) + hi, a, 99)
	var n := randi_range(a, b)
	if not f.has("trait_vals"):
		f["trait_vals"] = {}
	f.trait_vals[t] = n
	return n


## Whether its stat affixes count now: alive, not weak (and carried: the
## caller's business).
static func stats_count(f: Dictionary) -> bool:
	return state(f) == "alive" and not bool(f.get("weak", false))
