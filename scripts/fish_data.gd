class_name FishData
extends RefCounted

## Cast-distance ratio (0..1) buckets into a tier; tier drives timing and
## base reel difficulty. Which actual fish comes up - name, value, how hard
## it fights - is a separate roll against FISH: the map style's waters x
## the water zone type it was caught in x rarity x the cast's reach (see
## pick_species(), called from Player._roll_catch_outcome()).

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

## User request: every map style has fish of its own. The freshwater
## styles share COMMON_FRESH (well-known fish, 10), each adds its own four
## and one rarest (STYLE_FISH); the sea (the beach styles) has its own
## SEA_COMMON (18) and SEA_RARE (7, the last two its legends). Picked in
## pick_species() by the map's waters (FishData.waters, set by
## MapGenerator), the rarity rolled for the cast, and the cast's reach.
##
## Per species: name; value (x the cast tier's base); trait (calm / normal
## / wild: how the fight goes, see difficulty_for()); habit ("cover": bolts
## for cover near the bank, "jumper": leaps, "" none); reach (the cast
## tiers it's found at - small fish close in, big ones far out); colors
## [back, belly, fins / markings] and pattern (plain, spots, stripes,
## bars, koi, gradient, speckle), body (the model it's drawn from, see
## tools/render_fish.py). colors[0] also tints the float at the bite.
const FISH := {
	# --- Freshwater, every freshwater style --------------------------------
	"carp": {"name": "鯉魚", "value": 1.0, "trait": "normal", "habit": "", "reach": ["near", "mid", "far"],
		"colors": [Color(0.55, 0.45, 0.25), Color(0.85, 0.75, 0.5), Color(0.6, 0.35, 0.2)], "pattern": "scales", "body": "carp"},
	"crucian": {"name": "鯽魚", "value": 0.8, "trait": "calm", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.5, 0.48, 0.35), Color(0.8, 0.78, 0.65), Color(0.45, 0.42, 0.3)], "pattern": "scales", "body": "carp"},
	"grass_carp": {"name": "草魚", "value": 1.1, "trait": "normal", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.42, 0.45, 0.3), Color(0.8, 0.78, 0.62), Color(0.4, 0.4, 0.28)], "pattern": "scales", "body": "carp"},
	"tilapia": {"name": "吳郭魚", "value": 0.8, "trait": "calm", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.45, 0.42), Color(0.75, 0.75, 0.7), Color(0.55, 0.3, 0.3)], "pattern": "bars", "body": "tilapia"},
	"catfish": {"name": "鯰魚", "value": 1.2, "trait": "normal", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.32, 0.3, 0.27), Color(0.8, 0.78, 0.7), Color(0.25, 0.23, 0.2)], "pattern": "plain", "body": "catfish"},
	"bass": {"name": "大口黑鱸", "value": 1.2, "trait": "wild", "habit": "jumper", "reach": ["near", "mid", "far"],
		"colors": [Color(0.35, 0.45, 0.25), Color(0.85, 0.85, 0.7), Color(0.2, 0.25, 0.15)], "pattern": "stripe", "body": "bass"},
	"bluegill": {"name": "藍鰓太陽魚", "value": 0.7, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.3, 0.4, 0.4), Color(0.9, 0.65, 0.3), Color(0.15, 0.2, 0.35)], "pattern": "bars", "body": "tilapia"},
	"rainbow_trout": {"name": "虹鱒", "value": 1.3, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.4, 0.5, 0.4), Color(0.9, 0.88, 0.85), Color(0.85, 0.4, 0.45)], "pattern": "speckle", "body": "trout"},
	"eel": {"name": "鰻魚", "value": 1.3, "trait": "normal", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.25, 0.28, 0.2), Color(0.7, 0.7, 0.5), Color(0.2, 0.22, 0.15)], "pattern": "plain", "body": "eel"},
	"loach": {"name": "泥鰍", "value": 0.6, "trait": "calm", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.45, 0.4, 0.28), Color(0.75, 0.7, 0.55), Color(0.3, 0.26, 0.18)], "pattern": "speckle", "body": "eel"},

	# --- Freshwater, one style each (four, then its rarest) ----------------
	# Forest: clear streams.
	"brown_trout": {"name": "褐鱒", "value": 1.7, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.5, 0.42, 0.25), Color(0.9, 0.82, 0.6), Color(0.7, 0.2, 0.15)], "pattern": "spots", "body": "trout"},
	"brook_trout": {"name": "溪鱒", "value": 1.6, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.25, 0.32, 0.25), Color(0.9, 0.5, 0.25), Color(0.95, 0.85, 0.4)], "pattern": "spots", "body": "trout"},
	"grayling": {"name": "茴魚", "value": 1.5, "trait": "calm", "habit": "", "reach": ["mid"],
		"colors": [Color(0.5, 0.52, 0.55), Color(0.85, 0.85, 0.85), Color(0.55, 0.3, 0.45)], "pattern": "speckle", "body": "trout"},
	"ayu": {"name": "香魚", "value": 1.6, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.5, 0.52, 0.4), Color(0.9, 0.88, 0.8), Color(0.9, 0.75, 0.3)], "pattern": "gradient", "body": "trout"},
	"golden_trout": {"name": "金鱒", "value": 5.0, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.95, 0.72, 0.2), Color(0.95, 0.4, 0.2), Color(0.8, 0.25, 0.2)], "pattern": "speckle", "body": "trout"},
	# Dead wood: dark, dead water.
	"snakehead": {"name": "烏鱧", "value": 1.7, "trait": "wild", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.2, 0.2, 0.17), Color(0.55, 0.52, 0.45), Color(0.1, 0.1, 0.08)], "pattern": "spots", "body": "pike"},
	"bowfin": {"name": "弓鰭魚", "value": 1.8, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.3, 0.32, 0.22), Color(0.7, 0.68, 0.5), Color(0.2, 0.3, 0.2)], "pattern": "speckle", "body": "pike"},
	"cavefish": {"name": "洞穴盲魚", "value": 1.5, "trait": "calm", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.9, 0.78, 0.78), Color(0.95, 0.88, 0.88), Color(0.85, 0.6, 0.6)], "pattern": "plain", "body": "tilapia"},
	"black_catfish": {"name": "黑鯰", "value": 1.6, "trait": "normal", "habit": "cover", "reach": ["far"],
		"colors": [Color(0.12, 0.12, 0.12), Color(0.4, 0.38, 0.35), Color(0.08, 0.08, 0.08)], "pattern": "plain", "body": "catfish"},
	"ghost_fish": {"name": "幽靈魚", "value": 5.5, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.75, 0.85, 0.9), Color(0.9, 0.95, 1.0), Color(0.55, 0.75, 0.85)], "pattern": "bones", "body": "carp"},
	# Rocky: mountain streams.
	"char": {"name": "紅點鮭", "value": 1.6, "trait": "normal", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.35, 0.4, 0.35), Color(0.9, 0.55, 0.35), Color(0.95, 0.5, 0.45)], "pattern": "spots", "body": "trout"},
	"sculpin": {"name": "杜父魚", "value": 1.4, "trait": "calm", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.45, 0.4, 0.32), Color(0.75, 0.7, 0.6), Color(0.3, 0.25, 0.2)], "pattern": "bars", "body": "goby"},
	"goby": {"name": "鰕虎", "value": 1.3, "trait": "calm", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.55, 0.5, 0.4), Color(0.85, 0.8, 0.7), Color(0.35, 0.5, 0.6)], "pattern": "speckle", "body": "goby"},
	"minnow": {"name": "鱥魚", "value": 1.2, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.45, 0.48, 0.4), Color(0.9, 0.85, 0.75), Color(0.8, 0.35, 0.25)], "pattern": "stripe", "body": "trout"},
	"wels": {"name": "巨型鯰魚", "value": 5.0, "trait": "wild", "habit": "cover", "reach": ["far"],
		"colors": [Color(0.28, 0.3, 0.25), Color(0.8, 0.78, 0.7), Color(0.2, 0.22, 0.18)], "pattern": "speckle", "body": "catfish"},
	# Tropical.
	"piranha": {"name": "食人魚", "value": 1.8, "trait": "wild", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.5, 0.52, 0.55), Color(0.85, 0.3, 0.2), Color(0.3, 0.3, 0.32)], "pattern": "speckle", "body": "tilapia"},
	"oscar": {"name": "地圖魚", "value": 1.6, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.2, 0.2, 0.18), Color(0.5, 0.45, 0.4), Color(0.95, 0.45, 0.15)], "pattern": "koi", "body": "tilapia"},
	"angelfish": {"name": "神仙魚", "value": 1.7, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.8, 0.8, 0.75), Color(0.9, 0.9, 0.88), Color(0.15, 0.15, 0.15)], "pattern": "bars", "body": "angel"},
	"arowana": {"name": "銀龍魚", "value": 2.0, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.75, 0.78, 0.8), Color(0.9, 0.9, 0.92), Color(0.6, 0.5, 0.6)], "pattern": "scales", "body": "arowana"},
	"arapaima": {"name": "巨骨舌魚", "value": 5.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.3, 0.32, 0.28), Color(0.6, 0.55, 0.45), Color(0.8, 0.25, 0.2)], "pattern": "scales", "body": "arowana"},
	# Prehistoric.
	"sturgeon": {"name": "鱘魚", "value": 1.9, "trait": "normal", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.35, 0.35, 0.33), Color(0.8, 0.78, 0.72), Color(0.6, 0.6, 0.55)], "pattern": "plates", "body": "sturgeon"},
	"lungfish": {"name": "肺魚", "value": 1.6, "trait": "calm", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.38, 0.3), Color(0.7, 0.65, 0.5), Color(0.25, 0.22, 0.18)], "pattern": "spots", "body": "eel"},
	"bichir": {"name": "恐龍魚", "value": 1.7, "trait": "normal", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.4, 0.3), Color(0.8, 0.75, 0.6), Color(0.2, 0.2, 0.15)], "pattern": "bars", "body": "gar"},
	"paddlefish": {"name": "匙吻鱘", "value": 1.9, "trait": "calm", "habit": "", "reach": ["far"],
		"colors": [Color(0.42, 0.45, 0.48), Color(0.85, 0.85, 0.85), Color(0.35, 0.38, 0.4)], "pattern": "plain", "body": "sturgeon"},
	"coelacanth": {"name": "腔棘魚", "value": 6.0, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.2, 0.28, 0.45), Color(0.3, 0.38, 0.55), Color(0.85, 0.85, 0.8)], "pattern": "spots", "body": "coelacanth"},
	# Swamp.
	"swamp_eel": {"name": "黃鱔", "value": 1.4, "trait": "normal", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.5, 0.38, 0.18), Color(0.85, 0.7, 0.35), Color(0.35, 0.25, 0.1)], "pattern": "speckle", "body": "eel"},
	"betta": {"name": "鬥魚", "value": 1.5, "trait": "wild", "habit": "", "reach": ["near"],
		"colors": [Color(0.6, 0.12, 0.2), Color(0.25, 0.2, 0.6), Color(0.8, 0.2, 0.3)], "pattern": "gradient", "body": "betta"},
	"climbing_perch": {"name": "攀鱸", "value": 1.5, "trait": "normal", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.42, 0.3), Color(0.75, 0.72, 0.55), Color(0.25, 0.28, 0.2)], "pattern": "bars", "body": "bass"},
	"walking_catfish": {"name": "胡子鯰", "value": 1.6, "trait": "normal", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.35, 0.3, 0.25), Color(0.7, 0.62, 0.5), Color(0.25, 0.2, 0.15)], "pattern": "speckle", "body": "catfish"},
	"alligator_gar": {"name": "鱷雀鱔", "value": 5.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.4, 0.42, 0.3), Color(0.8, 0.78, 0.62), Color(0.25, 0.25, 0.18)], "pattern": "spots", "body": "gar"},
	# Snow: fishing through the ice.
	"arctic_char": {"name": "北極紅點鮭", "value": 1.7, "trait": "normal", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.3, 0.38, 0.4), Color(0.9, 0.45, 0.3), Color(0.95, 0.7, 0.65)], "pattern": "spots", "body": "trout"},
	"whitefish": {"name": "白鮭", "value": 1.5, "trait": "calm", "habit": "", "reach": ["mid"],
		"colors": [Color(0.6, 0.65, 0.68), Color(0.92, 0.92, 0.9), Color(0.5, 0.55, 0.58)], "pattern": "scales", "body": "trout"},
	"burbot": {"name": "江鱈", "value": 1.6, "trait": "normal", "habit": "cover", "reach": ["far"],
		"colors": [Color(0.4, 0.38, 0.25), Color(0.8, 0.78, 0.6), Color(0.25, 0.22, 0.15)], "pattern": "speckle", "body": "eel"},
	"smelt": {"name": "胡瓜魚", "value": 1.3, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.6, 0.7, 0.65), Color(0.92, 0.92, 0.9), Color(0.6, 0.75, 0.8)], "pattern": "stripe", "body": "mackerel"},
	"taimen": {"name": "哲羅鮭", "value": 5.5, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.4, 0.35, 0.3), Color(0.85, 0.6, 0.45), Color(0.75, 0.3, 0.25)], "pattern": "spots", "body": "trout"},
	# Autumn wood.
	"sockeye": {"name": "紅鮭", "value": 1.8, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.8, 0.2, 0.15), Color(0.85, 0.3, 0.2), Color(0.25, 0.4, 0.25)], "pattern": "plain", "body": "trout"},
	"pike": {"name": "白斑狗魚", "value": 1.8, "trait": "wild", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.35, 0.42, 0.25), Color(0.85, 0.85, 0.7), Color(0.85, 0.85, 0.6)], "pattern": "spots", "body": "pike"},
	"perch": {"name": "河鱸", "value": 1.4, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.5, 0.55, 0.25), Color(0.9, 0.85, 0.6), Color(0.9, 0.4, 0.2)], "pattern": "bars", "body": "bass"},
	"channel_cat": {"name": "斑點叉尾鮰", "value": 1.5, "trait": "normal", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.5, 0.52, 0.55), Color(0.88, 0.88, 0.85), Color(0.3, 0.3, 0.32)], "pattern": "spots", "body": "catfish"},
	"golden_koi": {"name": "金錦鯉", "value": 5.0, "trait": "calm", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.98, 0.78, 0.2), Color(1.0, 0.9, 0.6), Color(0.95, 0.45, 0.15)], "pattern": "koi", "body": "carp"},
	# Ruins: the flooded town.
	"pleco": {"name": "清道夫", "value": 1.4, "trait": "calm", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.3, 0.26, 0.2), Color(0.55, 0.5, 0.4), Color(0.15, 0.12, 0.1)], "pattern": "spots", "body": "catfish"},
	"silver_carp": {"name": "飛躍鯉", "value": 1.6, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.65, 0.68, 0.7), Color(0.92, 0.92, 0.9), Color(0.55, 0.58, 0.6)], "pattern": "scales", "body": "carp"},
	"giant_goldfish": {"name": "巨型金魚", "value": 1.7, "trait": "calm", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.95, 0.5, 0.12), Color(1.0, 0.75, 0.4), Color(0.95, 0.6, 0.25)], "pattern": "scales", "body": "carp"},
	"crayfish": {"name": "螯蝦", "value": 1.3, "trait": "normal", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.7, 0.2, 0.12), Color(0.85, 0.45, 0.3), Color(0.4, 0.1, 0.08)], "pattern": "plain", "body": "crayfish"},
	"two_headed_carp": {"name": "雙頭變異鯉", "value": 5.5, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.5, 0.55, 0.3), Color(0.8, 0.8, 0.55), Color(0.6, 0.8, 0.3)], "pattern": "blotch", "body": "carp"},

	# --- The sea ------------------------------------------------------------
	"mackerel": {"name": "鯖魚", "value": 1.0, "trait": "normal", "habit": "jumper", "reach": ["near", "mid"],
		"colors": [Color(0.2, 0.45, 0.45), Color(0.9, 0.9, 0.88), Color(0.1, 0.2, 0.2)], "pattern": "stripe", "body": "mackerel"},
	"sardine": {"name": "沙丁魚", "value": 0.6, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.3, 0.45, 0.6), Color(0.92, 0.92, 0.92), Color(0.2, 0.3, 0.4)], "pattern": "gradient", "body": "mackerel"},
	"horse_mackerel": {"name": "竹莢魚", "value": 0.8, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.45, 0.55, 0.5), Color(0.9, 0.9, 0.85), Color(0.85, 0.75, 0.35)], "pattern": "gradient", "body": "mackerel"},
	"saury": {"name": "秋刀魚", "value": 0.8, "trait": "calm", "habit": "", "reach": ["mid"],
		"colors": [Color(0.25, 0.3, 0.5), Color(0.9, 0.9, 0.92), Color(0.85, 0.75, 0.3)], "pattern": "gradient", "body": "ribbon_short"},
	"herring": {"name": "鯡魚", "value": 0.7, "trait": "calm", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.3, 0.42, 0.55), Color(0.9, 0.92, 0.92), Color(0.25, 0.35, 0.45)], "pattern": "gradient", "body": "mackerel"},
	"sea_bream": {"name": "真鯛", "value": 1.3, "trait": "normal", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.9, 0.45, 0.45), Color(0.95, 0.8, 0.8), Color(0.4, 0.6, 0.85)], "pattern": "speckle", "body": "bream"},
	"sea_bass": {"name": "海鱸", "value": 1.2, "trait": "wild", "habit": "jumper", "reach": ["near", "mid"],
		"colors": [Color(0.45, 0.5, 0.55), Color(0.9, 0.9, 0.9), Color(0.3, 0.35, 0.4)], "pattern": "speckle", "body": "bass"},
	"flounder": {"name": "比目魚", "value": 1.3, "trait": "calm", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.55, 0.48, 0.35), Color(0.9, 0.88, 0.85), Color(0.35, 0.3, 0.2)], "pattern": "spots", "body": "flat"},
	"cod": {"name": "鱈魚", "value": 1.2, "trait": "normal", "habit": "", "reach": ["far"],
		"colors": [Color(0.55, 0.5, 0.35), Color(0.88, 0.86, 0.78), Color(0.4, 0.36, 0.25)], "pattern": "speckle", "body": "grouper"},
	"puffer": {"name": "河豚", "value": 1.1, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.55, 0.5, 0.35), Color(0.95, 0.92, 0.85), Color(0.25, 0.25, 0.2)], "pattern": "spots", "body": "puffer"},
	"cutlassfish": {"name": "白帶魚", "value": 1.2, "trait": "normal", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.8, 0.84, 0.88), Color(0.92, 0.94, 0.96), Color(0.7, 0.75, 0.8)], "pattern": "plain", "body": "ribbon"},
	"grouper": {"name": "石斑", "value": 1.4, "trait": "wild", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.45, 0.38, 0.28), Color(0.8, 0.72, 0.6), Color(0.3, 0.25, 0.18)], "pattern": "spots", "body": "grouper"},
	"mullet": {"name": "烏魚", "value": 1.0, "trait": "normal", "habit": "jumper", "reach": ["near", "mid"],
		"colors": [Color(0.38, 0.42, 0.45), Color(0.88, 0.88, 0.86), Color(0.3, 0.33, 0.36)], "pattern": "stripe", "body": "mackerel"},
	"croaker": {"name": "黃魚", "value": 1.3, "trait": "calm", "habit": "", "reach": ["mid"],
		"colors": [Color(0.75, 0.62, 0.3), Color(0.95, 0.82, 0.4), Color(0.85, 0.7, 0.25)], "pattern": "gradient", "body": "bass"},
	"yellowtail": {"name": "鰤魚", "value": 1.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.3, 0.4, 0.5), Color(0.92, 0.92, 0.9), Color(0.9, 0.8, 0.25)], "pattern": "stripe", "body": "tuna"},
	"mahi": {"name": "鬼頭刀", "value": 1.5, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.2, 0.6, 0.45), Color(0.9, 0.8, 0.25), Color(0.3, 0.5, 0.8)], "pattern": "speckle", "body": "mahi"},
	"conger": {"name": "海鰻", "value": 1.3, "trait": "normal", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.35, 0.35, 0.3), Color(0.75, 0.72, 0.65), Color(0.25, 0.25, 0.22)], "pattern": "plain", "body": "eel"},
	"scorpionfish": {"name": "石狗公", "value": 1.2, "trait": "normal", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.6, 0.3, 0.2), Color(0.85, 0.65, 0.5), Color(0.35, 0.18, 0.12)], "pattern": "blotch", "body": "grouper"},
	# Sea rarities (the last two its legends).
	"trevally": {"name": "浪人鰺", "value": 2.6, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.4, 0.45, 0.5), Color(0.85, 0.87, 0.88), Color(0.25, 0.28, 0.3)], "pattern": "gradient", "body": "trevally"},
	"napoleon": {"name": "蘇眉", "value": 2.8, "trait": "normal", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.25, 0.6, 0.55), Color(0.4, 0.7, 0.75), Color(0.15, 0.35, 0.5)], "pattern": "speckle", "body": "grouper"},
	"sunfish": {"name": "翻車魚", "value": 3.0, "trait": "calm", "habit": "", "reach": ["far"],
		"colors": [Color(0.55, 0.58, 0.6), Color(0.85, 0.85, 0.85), Color(0.45, 0.48, 0.5)], "pattern": "speckle", "body": "sunfish"},
	"sailfish": {"name": "雨傘旗魚", "value": 3.2, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.15, 0.25, 0.5), Color(0.85, 0.88, 0.9), Color(0.2, 0.35, 0.7)], "pattern": "bars", "body": "billfish"},
	"hammerhead": {"name": "鎚頭鯊", "value": 3.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.48, 0.5, 0.52), Color(0.88, 0.88, 0.88), Color(0.4, 0.42, 0.44)], "pattern": "plain", "body": "shark"},
	"swordfish": {"name": "劍旗魚", "value": 5.0, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.25, 0.28, 0.35), Color(0.8, 0.8, 0.82), Color(0.2, 0.22, 0.28)], "pattern": "plain", "body": "billfish"},
	"bluefin": {"name": "藍鰭鮪", "value": 5.5, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.12, 0.2, 0.4), Color(0.82, 0.85, 0.88), Color(0.9, 0.8, 0.2)], "pattern": "gradient", "body": "tuna"},
}

const COMMON_FRESH := ["carp", "crucian", "grass_carp", "tilapia", "catfish", "bass", "bluegill", "rainbow_trout", "eel", "loach"]
## Each freshwater style's own four, then its rarest.
const STYLE_FISH := {
	"forest": [["brown_trout", "brook_trout", "grayling", "ayu"], "golden_trout"],
	"deadwood": [["snakehead", "bowfin", "cavefish", "black_catfish"], "ghost_fish"],
	"rocky": [["char", "sculpin", "goby", "minnow"], "wels"],
	"tropical": [["piranha", "oscar", "angelfish", "arowana"], "arapaima"],
	"prehistoric": [["sturgeon", "lungfish", "bichir", "paddlefish"], "coelacanth"],
	"swamp": [["swamp_eel", "betta", "climbing_perch", "walking_catfish"], "alligator_gar"],
	"snow": [["arctic_char", "whitefish", "burbot", "smelt"], "taimen"],
	"autumn": [["sockeye", "pike", "perch", "channel_cat"], "golden_koi"],
	"ruins": [["pleco", "silver_carp", "giant_goldfish", "crayfish"], "two_headed_carp"],
}
const SEA_COMMON := ["mackerel", "sardine", "horse_mackerel", "saury", "herring", "sea_bream", "sea_bass",
	"flounder", "cod", "puffer", "cutlassfish", "grouper", "mullet", "croaker", "yellowtail", "mahi", "conger",
	"scorpionfish"]
const SEA_RARE := ["trevally", "napoleon", "sunfish", "sailfish", "hammerhead"]
const SEA_LEGEND := ["swordfish", "bluefin"]

## Which waters a map style's fish come from (MapGenerator theme names;
## the reserved low-poly styles borrow a near one's).
const THEME_WATERS := {
	"forest_pine": "forest", "forest_birch": "forest", "forest_maple": "forest", "forest_green": "forest",
	"forest_conifer": "forest", "meadow": "forest",
	"deadwood": "deadwood", "rocky": "rocky", "stone_forest": "rocky", "savanna": "rocky",
	"tropical": "tropical", "jungle": "tropical", "prehistoric": "prehistoric", "swamp": "swamp",
	"snow": "snow", "snow_lowpoly": "snow", "autumn": "autumn", "autumn_lowpoly": "autumn",
	"ruins": "ruins", "beach_rocky": "sea", "beach_sandy": "sea",
}
## This map's waters (MapGenerator sets it from the theme).
static var waters := "forest"


static func waters_for_theme(theme_name: String) -> String:
	return THEME_WATERS.get(theme_name, "forest")


## The species ids a cast can bring up: by the map's waters, the rarity
## rolled ("common" / "rare" / "epic") and the water it's cast into (the
## purple rare pools hold only the style's own fish and better).
static func pool_for(water_key: String, zone_key: String, rarity_key: String) -> Array:
	if water_key == "sea":
		match rarity_key:
			"epic":
				return SEA_LEGEND
			"rare":
				return SEA_RARE
		return SEA_RARE if zone_key == "rare" else SEA_COMMON
	var style: Array = STYLE_FISH.get(water_key, STYLE_FISH.forest)
	match rarity_key:
		"epic":
			return [style[1]]
		"rare":
			return style[0]
	if zone_key == "rare":
		return style[0]
	# Everyday fish: the shared ones mostly, the style's own now and then.
	return COMMON_FRESH + style[0] if randf() < STYLE_OWN_CHANCE else COMMON_FRESH


## How often an everyday freshwater catch may be one of the style's own.
const STYLE_OWN_CHANCE := 0.3


## A species by id, with its id and the float tint ("color") filled in.
static func species(id: String) -> Dictionary:
	var f: Dictionary = FISH[id].duplicate()
	f["id"] = id
	f["color"] = f.colors[0]
	f["value_mult"] = f.value
	return f


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
## PREFER_WEIGHT times more. Fish found at the cast's reach (tier) first;
## if none are, the whole pool.
static func pick_species(tier: String, zone_key: String, rarity_key: String, prefer: String = "",
		water_key: String = "") -> Dictionary:
	var pool: Array = pool_for(water_key if water_key != "" else waters, zone_key, rarity_key)
	var here := pool.filter(func(id): return tier in FISH[id].reach)
	if not here.is_empty():
		pool = here
	if prefer == "":
		return species(pool[randi() % pool.size()])
	var weights := []
	var total := 0.0
	for id in pool:
		var w := PREFER_WEIGHT if FISH[id].habit == prefer else 1.0
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return species(pool[i])
	return species(pool[-1])


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

static func difficulty_for(rarity_key: String, trait_name: String) -> String:
	var score: float = RARITY_SCORE.get(rarity_key, 0.0) + TRAIT_SCORE.get(trait_name, 0.6)
	if score < 0.5:
		return "novice"
	if score < 1.2:
		return "normal"
	if score < 2.4:
		return "advanced"
	return "master"


## A species' habit, by name (plan phase 4): reef, bottom and eel types
## bolt for cover near the bank; the fast hunters leap far more often.
static func habit_for(species_name: String) -> String:
	for id in FISH:
		if FISH[id].name == species_name:
			return FISH[id].habit
	return ""


## A species id by name ("" if none - e.g. the heart).
static func id_for(species_name: String) -> String:
	for id in FISH:
		if FISH[id].name == species_name:
			return id
	return ""
