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
## "run" (see Player._update_fish_run()/TRAIT_RUN_*): calm fish run less
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


## zone_key: "common"/"rare" water zone. rarity_key: "common"/"rare"/"epic".
## Falls back to the tier's generic label if a bucket somehow has no
## entries, so this never returns an empty dict.
static func pick_species(tier: String, zone_key: String, rarity_key: String) -> Dictionary:
	var pool: Array = SPECIES.get(tier, {}).get(zone_key, {}).get(rarity_key, [])
	if pool.is_empty():
		var fallback: Dictionary = TIERS[tier]
		return {"name": fallback.label, "value_mult": 1.0, "trait": "normal", "color": Color(1, 0.85, 0.2)}
	return pool[randi() % pool.size()]
