class_name FishData
extends RefCounted

## Cast-distance ratio (0..1) buckets into a tier; tier drives value, timing
## and reel difficulty. No hotspots/rare fish yet — MVP only proves the loop.

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

static func tier_for_ratio(ratio: float) -> String:
	if ratio < 0.34:
		return "near"
	elif ratio < 0.7:
		return "mid"
	return "far"

static func get_tier_data(tier: String) -> Dictionary:
	return TIERS[tier]
