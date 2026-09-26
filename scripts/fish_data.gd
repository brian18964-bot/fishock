class_name FishData
extends RefCounted

## Cast-distance ratio (0..1) buckets into a tier; tier drives timing and
## base reel difficulty. Which actual fish comes up - name, value, how hard
## it fights - is a separate roll against SPECIES, keyed by tier x which
## water zone type it was caught in x rarity (see pick_species(), called
## from Player._roll_catch_outcome()).

const TIERS := {
	"near": {
		"label": "近岸小魚",
		"value": 2.0,
		"wait_min": 0.6, "wait_max": 1.4,
		"bite_window": 1.0,
		"reel_speed": 0.55,
		"tension_rise": 0.35,
		"tension_fall": 0.6,
	},
	"mid": {
		"label": "近海魚",
		"value": 5.0,
		"wait_min": 1.0, "wait_max": 2.2,
		"bite_window": 0.7,
		"reel_speed": 0.4,
		"tension_rise": 0.5,
		"tension_fall": 0.55,
	},
	"far": {
		"label": "遠海大魚",
		"value": 10.0,
		"wait_min": 1.6, "wait_max": 3.0,
		"bite_window": 0.45,
		"reel_speed": 0.3,
		"tension_rise": 0.65,
		"tension_fall": 0.5,
	},
}

## User feedback: named fish species per tier x zone type x rarity, instead
## of a generic label + flat multiplier. "trait" feeds the fight's periodic
## difficulty (see difficulty_for() / FishFight): calm fish run less
## often and gentler, wild fish run more often and harder. "color" tints
## the bobber once the bite is revealed (main.gd), the only "appearance"
## difference available without real art.
const SPECIES := {
	"near": {
		"common": {
			"common": [
				{"name": "花身雞魚", "value_mult": 1.0, "trait": "calm", "color": Color(0.8, 0.8, 0.75)},
				{"name": "臭肚魚", "value_mult": 0.85, "trait": "normal", "color": Color(0.6, 0.75, 0.5)},
				{"name": "四齒魨", "value_mult": 0.9, "trait": "calm", "color": Color(0.85, 0.75, 0.5)},
			],
			"rare": [
				{"name": "石斑幼魚", "value_mult": 1.7, "trait": "wild", "color": Color(0.5, 0.4, 0.25)},
				{"name": "赤鰭笛鯛", "value_mult": 1.8, "trait": "normal", "color": Color(0.85, 0.3, 0.25)},
			],
			"epic": [
				{"name": "黃金石斑", "value_mult": 4.0, "trait": "wild", "color": Color(1.0, 0.8, 0.2)},
			],
		},
		"rare": {
			"common": [
				{"name": "白帶魚", "value_mult": 1.3, "trait": "normal", "color": Color(0.85, 0.87, 0.9)},
				{"name": "秋姑魚", "value_mult": 1.2, "trait": "calm", "color": Color(0.9, 0.55, 0.4)},
			],
			"rare": [
				{"name": "紅魽", "value_mult": 2.0, "trait": "wild", "color": Color(0.9, 0.35, 0.3)},
			],
			"epic": [
				{"name": "曲紋唇魚（蘇眉）", "value_mult": 4.5, "trait": "wild", "color": Color(0.3, 0.7, 0.9)},
			],
		},
	},
	"mid": {
		"common": {
			"common": [
				{"name": "花飛（鯖魚）", "value_mult": 1.0, "trait": "normal", "color": Color(0.4, 0.55, 0.7)},
				{"name": "煙仔虎", "value_mult": 0.95, "trait": "wild", "color": Color(0.3, 0.35, 0.4)},
				{"name": "紅目鰱", "value_mult": 0.9, "trait": "calm", "color": Color(0.8, 0.4, 0.4)},
			],
			"rare": [
				{"name": "午仔魚", "value_mult": 1.6, "trait": "calm", "color": Color(0.9, 0.9, 0.85)},
				{"name": "土魠魚", "value_mult": 1.8, "trait": "normal", "color": Color(0.55, 0.6, 0.65)},
			],
			"epic": [
				{"name": "紅甘將軍", "value_mult": 4.2, "trait": "wild", "color": Color(0.85, 0.55, 0.2)},
			],
		},
		"rare": {
			"common": [
				{"name": "白北魚", "value_mult": 1.3, "trait": "normal", "color": Color(0.75, 0.8, 0.85)},
				{"name": "赤鯮", "value_mult": 1.4, "trait": "calm", "color": Color(0.9, 0.5, 0.45)},
			],
			"rare": [
				{"name": "野生紅甘", "value_mult": 2.2, "trait": "wild", "color": Color(0.9, 0.45, 0.2)},
			],
			"epic": [
				{"name": "黑鮪幼魚", "value_mult": 5.0, "trait": "wild", "color": Color(0.15, 0.2, 0.3)},
			],
		},
	},
	"far": {
		"common": {
			"common": [
				{"name": "鬼頭刀", "value_mult": 1.0, "trait": "wild", "color": Color(0.2, 0.7, 0.5)},
				{"name": "白皮旗魚幼體", "value_mult": 1.05, "trait": "normal", "color": Color(0.6, 0.7, 0.8)},
				{"name": "油帶", "value_mult": 0.9, "trait": "calm", "color": Color(0.4, 0.4, 0.45)},
			],
			"rare": [
				{"name": "巨石斑", "value_mult": 1.9, "trait": "wild", "color": Color(0.35, 0.3, 0.2)},
				{"name": "深海鰻", "value_mult": 1.7, "trait": "normal", "color": Color(0.25, 0.2, 0.25)},
			],
			"epic": [
				{"name": "銀色巨旗魚", "value_mult": 4.8, "trait": "wild", "color": Color(0.75, 0.8, 0.95)},
			],
		},
		"rare": {
			"common": [
				{"name": "紅目鰻", "value_mult": 1.4, "trait": "normal", "color": Color(0.55, 0.3, 0.25)},
				{"name": "圓鱈", "value_mult": 1.5, "trait": "calm", "color": Color(0.5, 0.55, 0.6)},
			],
			"rare": [
				{"name": "深海巨石斑", "value_mult": 2.4, "trait": "wild", "color": Color(0.3, 0.25, 0.15)},
			],
			"epic": [
				{"name": "藍鰭鮪", "value_mult": 5.5, "trait": "wild", "color": Color(0.15, 0.35, 0.65)},
			],
		},
	},
}

static func tier_for_ratio(ratio: float) -> String:
	if ratio < 0.34:
		return "near"
	elif ratio < 0.7:
		return "mid"
	return "far"

static func get_tier_data(tier: String) -> Dictionary:
	return TIERS[tier]


## How much more often a lure's preferred kind of fish is picked, when the
## pool has one (see Profile.LURES "prefer").
const PREFER_WEIGHT := 4.0


## zone_key: "common"/"rare" water zone. rarity_key: "common"/"rare"/"epic".
## prefer: a habit ("cover"/"jumper") the lure draws - those species weigh
## PREFER_WEIGHT times more. Falls back to the tier's generic label if a
## bucket somehow has no entries, so this never returns an empty dict.
static func pick_species(tier: String, zone_key: String, rarity_key: String, prefer: String = "") -> Dictionary:
	var pool: Array = SPECIES.get(tier, {}).get(zone_key, {}).get(rarity_key, [])
	if pool.is_empty():
		var fallback: Dictionary = TIERS[tier]
		return {"name": fallback.label, "value_mult": 1.0, "trait": "normal", "color": Color(1, 0.85, 0.2)}
	if prefer == "":
		return pool[randi() % pool.size()]
	var weights := []
	var total := 0.0
	for species in pool:
		var w := PREFER_WEIGHT if habit_for(species.name) == prefer else 1.0
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[-1]


## User decision (fishing difficulty plan): every species fights at one of
## four difficulties, from how rare it is and its temperament - calm
## commons are 入門, legendary fish 大師. Read at the bite and through the
## fight by Player and FishFight.
##   nibbles: how many test nibbles (float twitches you must NOT strike
##     at) come before the real bite, [min, max]; fake: chance each one is
##     a full-looking dunk (no splash, no shake) meant to bait a strike
##   window: seconds to strike once it really bites (scaled by the cast
##     tier's own window)
##   stamina: how long the fish takes to tire (divides reel speed)
##   pull: tension multiplier
##   run_interval / run_time: seconds between runs / how long one lasts
##   side: chance a run goes sideways (pull the rod the other way) rather
##     than straight out (give line)
##   jump: chance per second of leaping mid-fight (give slack while it's up)
##   phases: 2 = goes berserk at half stamina
##   sweet: how wide the tension sweet spot is (reel faster inside it)
const DIFFICULTY := {
	"novice": {"label": "入門", "nibbles": Vector2i(0, 0), "fake": 0.0, "window": 1.1,
		"stamina": 1.0, "pull": 0.8, "run_interval": Vector2(3.5, 5.5), "run_time": 0.5,
		"side": 0.0, "jump": 0.0, "phases": 1, "sweet": 0.4},
	"normal": {"label": "普通", "nibbles": Vector2i(0, 1), "fake": 0.0, "window": 0.8,
		"stamina": 1.3, "pull": 1.0, "run_interval": Vector2(2.2, 3.6), "run_time": 0.6,
		"side": 0.2, "jump": 0.06, "phases": 1, "sweet": 0.34},
	"advanced": {"label": "進階", "nibbles": Vector2i(1, 3), "fake": 0.15, "window": 0.55,
		"stamina": 1.7, "pull": 1.15, "run_interval": Vector2(1.7, 2.8), "run_time": 0.7,
		"side": 0.5, "jump": 0.12, "phases": 1, "sweet": 0.28},
	"master": {"label": "大師", "nibbles": Vector2i(2, 4), "fake": 0.35, "window": 0.38,
		"stamina": 1.9, "pull": 1.3, "run_interval": Vector2(1.3, 2.3), "run_time": 0.8,
		"side": 0.6, "jump": 0.16, "phases": 2, "sweet": 0.22},
}
const RARITY_SCORE := {"common": 0.0, "rare": 1.0, "epic": 2.5}
const TRAIT_SCORE := {"calm": 0.0, "normal": 0.6, "wild": 1.2}

## Species habits (plan phase 4): reef and eel types bolt for cover near the
## bank; the fast open-water hunters leap far more often.
const COVER_SPECIES := ["石斑幼魚", "黃金石斑", "巨石斑", "深海鰻", "紅目鰻", "曲紋唇魚（蘇眉）"]
const JUMPER_SPECIES := ["鬼頭刀", "銀色巨旗魚", "白皮旗魚幼體", "紅甘將軍", "野生紅甘", "黑鮪幼魚", "花飛（鯖魚）"]


static func difficulty_for(rarity_key: String, trait_name: String) -> String:
	var score: float = RARITY_SCORE.get(rarity_key, 0.0) + TRAIT_SCORE.get(trait_name, 0.6)
	if score < 0.5:
		return "novice"
	if score < 1.2:
		return "normal"
	if score < 2.4:
		return "advanced"
	return "master"


static func habit_for(species_name: String) -> String:
	if species_name in COVER_SPECIES:
		return "cover"
	if species_name in JUMPER_SPECIES:
		return "jumper"
	return ""
