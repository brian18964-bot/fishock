class_name FishData
extends RefCounted

## Cast-distance ratio (0..1) buckets into a tier; tier drives timing and
## base reel difficulty. User feedback (the game's pace too quick): the
## waits for a bite and the fights are about twice what they were. Which actual fish comes up - name, value, how hard
## it fights - is a separate roll against FISH: the map style's waters x
## the water zone type it was caught in x rarity x the cast's reach (see
## pick_species(), called from Player._roll_catch_outcome()).

const TIERS := {
	"near": {
		"label": "近岸小魚",
		"value": 2.0,
		"wait_min": 1.5, "wait_max": 3.5,
		"bite_window": 1.0,
		"reel_speed": 0.24,
		"tension_rise": 0.35,
		"tension_fall": 0.6,
	},
	"mid": {
		"label": "近海魚",
		"value": 5.0,
		"wait_min": 2.5, "wait_max": 5.5,
		"bite_window": 0.7,
		"reel_speed": 0.24,
		"tension_rise": 0.5,
		"tension_fall": 0.55,
	},
	"far": {
		"label": "遠海大魚",
		"value": 10.0,
		"wait_min": 4.0, "wait_max": 7.5,
		"bite_window": 0.45,
		"reel_speed": 0.22,
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
	# User request (the ruined human world - the city, docs/RUINED_WORLD.md): the fish people kept -
	# pets let go, a park's pond, a pet shop's tanks - living on in the empty city's water, grown big.
	# Its own four and its rarest (the golden arowana); each branch's own besides. (Modelled here till
	# the user's photos come - tools/fish_from_photo.py.)
	"flowerhorn": {"name": "羅漢魚", "value": 1.8, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.72, 0.25, 0.22), Color(0.95, 0.7, 0.62), Color(0.12, 0.1, 0.1)], "pattern": "blotch", "body": "tilapia"},
	"koi": {"name": "錦鯉", "value": 1.7, "trait": "calm", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.95, 0.94, 0.9), Color(1.0, 0.98, 0.95), Color(0.9, 0.25, 0.12)], "pattern": "koi", "body": "carp"},
	"blood_parrot": {"name": "血鸚鵡", "value": 1.6, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.95, 0.42, 0.18), Color(1.0, 0.68, 0.42), Color(0.88, 0.3, 0.12)], "pattern": "gradient", "body": "bream"},
	"discus": {"name": "七彩神仙", "value": 1.9, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.2, 0.55, 0.6), Color(0.85, 0.55, 0.35), Color(0.85, 0.3, 0.15)], "pattern": "stripe", "body": "bream"},
	"asian_arowana": {"name": "金龍魚", "value": 5.5, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.9, 0.7, 0.25), Color(1.0, 0.86, 0.5), Color(0.85, 0.55, 0.2)], "pattern": "scales", "body": "arowana"},
	"guppy": {"name": "孔雀魚", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near"],
		"colors": [Color(0.55, 0.56, 0.5), Color(0.85, 0.82, 0.75), Color(0.2, 0.5, 0.95)], "pattern": "spots", "body": "betta"},
	"clown_knifefish": {"name": "小丑刀", "value": 1.9, "trait": "normal", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.6, 0.62, 0.6), Color(0.86, 0.86, 0.82), Color(0.08, 0.08, 0.08)], "pattern": "spots", "body": "ribbon_short"},
	"redtail_catfish": {"name": "紅尾鯰", "value": 2.2, "trait": "wild", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.18, 0.18, 0.18), Color(0.92, 0.88, 0.78), Color(0.9, 0.3, 0.15)], "pattern": "gradient", "body": "catfish"},
	"electric_eel": {"name": "電鰻", "value": 5.5, "trait": "wild", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.22, 0.24, 0.2), Color(0.75, 0.55, 0.35), Color(0.3, 0.3, 0.25)], "pattern": "plain", "body": "eel"},
	"tarpon": {"name": "大海鰱", "value": 5.0, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.7, 0.74, 0.78), Color(0.95, 0.95, 0.95), Color(0.45, 0.5, 0.58)], "pattern": "scales", "body": "trevally"},
	# User request (the human world's countryside - an ordinary place, docs/RUINED_WORLD.md): the fish
	# of the farm ponds, the ditches and the paddies' water - the rice fish, the pale chub, the
	# bitterling, the yellow catfish; the rarest, the mandarin fish. Each branch's own besides: the
	# paradise fish of the paddies, the Wuchang bream, the topmouth culter and the bighead carp, the
	# black carp, the yellowcheek. (Modelled here till the user's photos come.)
	"medaka": {"name": "青鱂魚", "value": 1.2, "trait": "normal", "habit": "", "reach": ["near"],
		"colors": [Color(0.62, 0.6, 0.45), Color(0.9, 0.88, 0.76), Color(0.35, 0.55, 0.75)], "pattern": "plain", "body": "trout"},
	"pale_chub": {"name": "溪哥", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.55, 0.62, 0.6), Color(0.92, 0.9, 0.85), Color(0.85, 0.4, 0.45)], "pattern": "bars", "body": "trout"},
	"bitterling": {"name": "鰟鮍", "value": 1.4, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.6, 0.55, 0.62), Color(0.9, 0.85, 0.88), Color(0.85, 0.3, 0.5)], "pattern": "gradient", "body": "bream"},
	"yellow_catfish": {"name": "黃顙魚", "value": 1.6, "trait": "normal", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.55, 0.45, 0.18), Color(0.92, 0.8, 0.4), Color(0.25, 0.2, 0.1)], "pattern": "blotch", "body": "catfish"},
	"mandarin_fish": {"name": "鱖魚", "value": 4.8, "trait": "wild", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.5, 0.45, 0.25), Color(0.85, 0.78, 0.55), Color(0.2, 0.16, 0.1)], "pattern": "blotch", "body": "bass"},
	"paradise_fish": {"name": "蓋斑鬥魚", "value": 1.5, "trait": "normal", "habit": "", "reach": ["near"],
		"colors": [Color(0.35, 0.3, 0.55), Color(0.85, 0.4, 0.3), Color(0.25, 0.45, 0.85)], "pattern": "bars", "body": "betta"},
	"bream": {"name": "武昌魚", "value": 1.9, "trait": "calm", "habit": "", "reach": ["mid"],
		"colors": [Color(0.5, 0.55, 0.55), Color(0.9, 0.92, 0.9), Color(0.4, 0.45, 0.48)], "pattern": "scales", "body": "bream"},
	"culter": {"name": "翹嘴鮊", "value": 2.1, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.55, 0.6, 0.62), Color(0.95, 0.95, 0.95), Color(0.4, 0.45, 0.5)], "pattern": "plain", "body": "mackerel"},
	"bighead_carp": {"name": "鱅魚", "value": 2.3, "trait": "calm", "habit": "", "reach": ["far"],
		"colors": [Color(0.35, 0.36, 0.3), Color(0.82, 0.8, 0.72), Color(0.25, 0.25, 0.2)], "pattern": "speckle", "body": "carp"},
	"black_carp": {"name": "青魚", "value": 5.0, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.12, 0.14, 0.14), Color(0.45, 0.48, 0.46), Color(0.1, 0.1, 0.1)], "pattern": "scales", "body": "carp"},
	"yellowcheek": {"name": "鱤魚", "value": 5.5, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.55, 0.5, 0.3), Color(0.95, 0.85, 0.5), Color(0.85, 0.55, 0.2)], "pattern": "gradient", "body": "mackerel"},
	# User request (the human world's Japanese village): the fish of its mountain streams, its shrine
	# ponds and the big lake - the masu salmon's parr (yamame), the Japanese dace, the dark chub, the
	# shrine pond's goldfish; the rarest, the Lake Biwa catfish. Each branch's own: the red-spotted
	# masu, the cherry salmon, the hasu and the nigorobuna, the Biwa trout, the akame. (Modelled here.)
	"yamame": {"name": "山女魚", "value": 1.5, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.42, 0.46, 0.38), Color(0.88, 0.86, 0.8), Color(0.3, 0.3, 0.38)], "pattern": "bars", "body": "trout"},
	"ugui": {"name": "珠星三塊魚", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.42, 0.36), Color(0.86, 0.84, 0.76), Color(0.85, 0.3, 0.2)], "pattern": "stripe", "body": "trout"},
	"kawamutsu": {"name": "河鱲", "value": 1.4, "trait": "normal", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.3, 0.32, 0.26), Color(0.82, 0.78, 0.6), Color(0.15, 0.15, 0.18)], "pattern": "stripe", "body": "trout"},
	"goldfish": {"name": "金魚", "value": 1.6, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.95, 0.45, 0.12), Color(1.0, 0.75, 0.45), Color(0.98, 0.95, 0.9)], "pattern": "koi", "body": "bream"},
	"biwa_catfish": {"name": "琵琶湖大鯰", "value": 5.0, "trait": "wild", "habit": "cover", "reach": ["far"],
		"colors": [Color(0.2, 0.2, 0.17), Color(0.75, 0.72, 0.62), Color(0.12, 0.12, 0.1)], "pattern": "speckle", "body": "catfish"},
	"amago": {"name": "天魚", "value": 1.7, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.42, 0.46, 0.38), Color(0.9, 0.86, 0.78), Color(0.9, 0.28, 0.15)], "pattern": "spots", "body": "trout"},
	"sakura_masu": {"name": "櫻鱒", "value": 2.0, "trait": "wild", "habit": "jumper", "reach": ["mid"],
		"colors": [Color(0.45, 0.42, 0.45), Color(0.92, 0.82, 0.82), Color(0.85, 0.42, 0.45)], "pattern": "gradient", "body": "trout"},
	"hasu": {"name": "馬口魚", "value": 2.0, "trait": "wild", "habit": "", "reach": ["mid"],
		"colors": [Color(0.4, 0.46, 0.5), Color(0.9, 0.9, 0.88), Color(0.25, 0.32, 0.45)], "pattern": "bars", "body": "mackerel"},
	"nigoro": {"name": "似五郎鮒", "value": 2.2, "trait": "calm", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.45, 0.42, 0.28), Color(0.85, 0.8, 0.6), Color(0.35, 0.3, 0.18)], "pattern": "scales", "body": "carp"},
	"biwa_trout": {"name": "琵琶鱒", "value": 5.0, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.35, 0.4, 0.42), Color(0.92, 0.9, 0.88), Color(0.6, 0.35, 0.4)], "pattern": "speckle", "body": "trout"},
	"akame": {"name": "日本尖吻鱸", "value": 5.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.55, 0.55, 0.5), Color(0.9, 0.9, 0.86), Color(0.9, 0.25, 0.15)], "pattern": "scales", "body": "bass"},
	# User request (the human world's English village): its river and pond fish - the roach, the rudd,
	# the tench, the dace; the rarest, the Atlantic salmon come up the river. Each branch's own: the
	# gudgeon, the chub, the barbel and the zander, the sea trout, the ferox trout of the deep lochs.
	"roach": {"name": "擬鯉", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.42, 0.46, 0.46), Color(0.9, 0.9, 0.86), Color(0.85, 0.3, 0.2)], "pattern": "scales", "body": "carp"},
	"rudd": {"name": "紅眼魚", "value": 1.4, "trait": "normal", "habit": "", "reach": ["near"],
		"colors": [Color(0.5, 0.48, 0.3), Color(0.95, 0.85, 0.55), Color(0.9, 0.25, 0.15)], "pattern": "scales", "body": "carp"},
	"tench": {"name": "丁鱥", "value": 1.7, "trait": "calm", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.25, 0.32, 0.15), Color(0.62, 0.6, 0.3), Color(0.18, 0.22, 0.1)], "pattern": "plain", "body": "carp"},
	"dace": {"name": "歐洲鰷", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.45, 0.5, 0.55), Color(0.92, 0.92, 0.92), Color(0.6, 0.62, 0.6)], "pattern": "plain", "body": "trout"},
	"atlantic_salmon": {"name": "大西洋鮭", "value": 5.0, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.38, 0.42, 0.48), Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.18)], "pattern": "spots", "body": "trout"},
	"gudgeon": {"name": "鮈魚", "value": 1.4, "trait": "normal", "habit": "", "reach": ["near"],
		"colors": [Color(0.5, 0.46, 0.36), Color(0.88, 0.85, 0.76), Color(0.25, 0.22, 0.18)], "pattern": "spots", "body": "goby"},
	"chub": {"name": "圓鰭雅羅魚", "value": 1.9, "trait": "wild", "habit": "", "reach": ["mid"],
		"colors": [Color(0.32, 0.36, 0.34), Color(0.85, 0.82, 0.72), Color(0.2, 0.2, 0.2)], "pattern": "scales", "body": "carp"},
	"barbel": {"name": "歐洲鲃", "value": 2.2, "trait": "wild", "habit": "cover", "reach": ["mid", "far"],
		"colors": [Color(0.48, 0.42, 0.3), Color(0.88, 0.82, 0.68), Color(0.7, 0.4, 0.25)], "pattern": "speckle", "body": "catfish"},
	"zander": {"name": "白梭吻鱸", "value": 2.3, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.4, 0.44, 0.4), Color(0.88, 0.88, 0.84), Color(0.22, 0.25, 0.22)], "pattern": "bars", "body": "bass"},
	"sea_trout": {"name": "海鱒", "value": 5.0, "trait": "wild", "habit": "jumper", "reach": ["far"],
		"colors": [Color(0.42, 0.46, 0.5), Color(0.95, 0.95, 0.95), Color(0.2, 0.2, 0.25)], "pattern": "speckle", "body": "trout"},
	"ferox_trout": {"name": "巨型褐鱒", "value": 5.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.42, 0.36, 0.22), Color(0.9, 0.8, 0.55), Color(0.2, 0.12, 0.08)], "pattern": "spots", "body": "trout"},
	# User request (the human world's Chinese village, "中國風第 11 章"): the fish of its ponds, canals and
	# the great river - the mud carp, the barbel chub, the Chinese loach, the Yellow River carp with its
	# red fins; the rarest, the Chinese sucker with its tall sail of a fin. Each branch's own: the
	# spotted steed, the Reeves shad, the tapertail anchovy and the long-snouted luciobrama, the goonch
	# of the gorges, the Chinese sturgeon. (Modelled here.)
	"mud_carp": {"name": "鯪魚", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.42, 0.44, 0.42), Color(0.88, 0.88, 0.84), Color(0.3, 0.32, 0.34)], "pattern": "scales", "body": "carp"},
	"red_eye_trout": {"name": "赤眼鱒", "value": 1.5, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.44, 0.42), Color(0.88, 0.86, 0.8), Color(0.85, 0.25, 0.15)], "pattern": "scales", "body": "trout"},
	"sand_loach": {"name": "中華沙鰍", "value": 1.4, "trait": "calm", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.62, 0.55, 0.36), Color(0.88, 0.82, 0.62), Color(0.22, 0.18, 0.12)], "pattern": "bars", "body": "goby"},
	"yellow_river_carp": {"name": "黃河鯉", "value": 1.8, "trait": "calm", "habit": "", "reach": ["mid"],
		"colors": [Color(0.6, 0.5, 0.25), Color(0.95, 0.85, 0.55), Color(0.9, 0.3, 0.12)], "pattern": "scales", "body": "carp"},
	"chinese_sucker": {"name": "胭脂魚", "value": 5.0, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.55, 0.3, 0.25), Color(0.9, 0.72, 0.62), Color(0.75, 0.2, 0.18)], "pattern": "bars", "body": "angel"},
	"spotted_steed": {"name": "花䱻", "value": 1.7, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.5, 0.48, 0.4), Color(0.9, 0.88, 0.8), Color(0.2, 0.2, 0.18)], "pattern": "spots", "body": "trout"},
	"reeves_shad": {"name": "鰣魚", "value": 2.0, "trait": "wild", "habit": "jumper", "reach": ["mid"],
		"colors": [Color(0.45, 0.5, 0.55), Color(0.95, 0.95, 0.95), Color(0.6, 0.62, 0.66)], "pattern": "gradient", "body": "mackerel"},
	"coilia": {"name": "刀鱭", "value": 2.0, "trait": "normal", "habit": "", "reach": ["mid"],
		"colors": [Color(0.7, 0.68, 0.6), Color(0.95, 0.95, 0.92), Color(0.85, 0.75, 0.45)], "pattern": "gradient", "body": "ribbon_short"},
	"luciobrama": {"name": "鯮魚", "value": 2.3, "trait": "wild", "habit": "", "reach": ["mid", "far"],
		"colors": [Color(0.45, 0.48, 0.45), Color(0.9, 0.9, 0.86), Color(0.35, 0.38, 0.36)], "pattern": "plain", "body": "pike"},
	"goonch": {"name": "巨魾", "value": 5.0, "trait": "wild", "habit": "cover", "reach": ["far"],
		"colors": [Color(0.45, 0.38, 0.28), Color(0.82, 0.75, 0.6), Color(0.22, 0.18, 0.12)], "pattern": "speckle", "body": "catfish"},
	"chinese_sturgeon": {"name": "中華鱘", "value": 5.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.3, 0.32, 0.34), Color(0.88, 0.86, 0.82), Color(0.55, 0.55, 0.52)], "pattern": "plates", "body": "sturgeon"},
	# User request (the adobe village - "換成土屋主題"): the fish of its oasis waters and the great river
	# - the Nile tilapia, the bynni barbel, the African catfish, the elephantfish with its trunk of a
	# snout; the rarest, the Nile perch. Each branch's own: the Nile labeo, the electric catfish, the
	# tigerfish and the upside-down catfish, the goliath tigerfish, the aba aba. (Modelled here.)
	"nile_tilapia": {"name": "尼羅吳郭魚", "value": 1.3, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.45, 0.47, 0.42), Color(0.86, 0.85, 0.78), Color(0.75, 0.3, 0.25)], "pattern": "bars", "body": "tilapia"},
	"bynni": {"name": "鮑尼鲃", "value": 1.5, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.55, 0.52, 0.38), Color(0.92, 0.88, 0.72), Color(0.6, 0.5, 0.3)], "pattern": "scales", "body": "carp"},
	"african_catfish": {"name": "尖齒胡鯰", "value": 1.6, "trait": "calm", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.3, 0.3, 0.26), Color(0.78, 0.76, 0.68), Color(0.2, 0.2, 0.18)], "pattern": "speckle", "body": "catfish"},
	"elephantfish": {"name": "象鼻魚", "value": 1.7, "trait": "calm", "habit": "cover", "reach": ["near"],
		"colors": [Color(0.36, 0.3, 0.28), Color(0.7, 0.62, 0.55), Color(0.25, 0.2, 0.18)], "pattern": "plain", "body": "pike"},
	"nile_perch": {"name": "尼羅河鱸", "value": 5.0, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.5, 0.52, 0.48), Color(0.9, 0.9, 0.86), Color(0.85, 0.65, 0.3)], "pattern": "gradient", "body": "bass"},
	"labeo": {"name": "尼羅野鯪", "value": 1.7, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.4, 0.42, 0.42), Color(0.85, 0.85, 0.82), Color(0.3, 0.3, 0.32)], "pattern": "scales", "body": "carp"},
	"electric_catfish": {"name": "電鯰", "value": 2.0, "trait": "wild", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.55, 0.47, 0.36), Color(0.88, 0.82, 0.7), Color(0.2, 0.16, 0.12)], "pattern": "spots", "body": "catfish"},
	"tigerfish": {"name": "虎魚", "value": 2.2, "trait": "wild", "habit": "jumper", "reach": ["mid"],
		"colors": [Color(0.55, 0.58, 0.6), Color(0.92, 0.92, 0.9), Color(0.85, 0.25, 0.15)], "pattern": "stripe", "body": "mackerel"},
	"synodontis": {"name": "倒游鯰", "value": 2.0, "trait": "calm", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.55, 0.48, 0.38), Color(0.82, 0.76, 0.64), Color(0.2, 0.16, 0.12)], "pattern": "spots", "body": "catfish"},
	"goliath_tigerfish": {"name": "巨虎魚", "value": 5.5, "trait": "wild", "habit": "", "reach": ["far"],
		"colors": [Color(0.5, 0.52, 0.55), Color(0.92, 0.92, 0.9), Color(0.85, 0.2, 0.15)], "pattern": "stripe", "body": "bass"},
	"gymnarchus": {"name": "裸臀魚", "value": 5.0, "trait": "wild", "habit": "cover", "reach": ["far"],
		"colors": [Color(0.3, 0.27, 0.24), Color(0.6, 0.55, 0.48), Color(0.18, 0.15, 0.12)], "pattern": "speckle", "body": "eel"},
	# User request (the desert of bones): an oasis's fish - the pupfish of
	# desert springs, the doctor fish, the sucker and the bonytail of
	# desert rivers; the rarest, the Devils Hole pupfish of one desert pool.
	"pupfish": {"name": "沙漠鱂", "value": 1.3, "trait": "calm", "habit": "", "reach": ["near"],
		"colors": [Color(0.22, 0.38, 0.72), Color(0.72, 0.8, 0.92), Color(0.15, 0.2, 0.4)], "pattern": "bars", "body": "tilapia"},
	"garra": {"name": "親親魚", "value": 1.2, "trait": "normal", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.48, 0.46, 0.4), Color(0.8, 0.77, 0.68), Color(0.25, 0.24, 0.22)], "pattern": "stripe", "body": "trout"},
	"desert_sucker": {"name": "沙漠亞口魚", "value": 1.5, "trait": "calm", "habit": "cover", "reach": ["mid"],
		"colors": [Color(0.45, 0.4, 0.3), Color(0.84, 0.78, 0.64), Color(0.32, 0.27, 0.2)], "pattern": "speckle", "body": "carp"},
	"bonytail": {"name": "骨尾魚", "value": 2.0, "trait": "wild", "habit": "jumper", "reach": ["mid", "far"],
		"colors": [Color(0.4, 0.42, 0.38), Color(0.86, 0.85, 0.8), Color(0.55, 0.48, 0.36)], "pattern": "gradient", "body": "trout"},
	"devils_pupfish": {"name": "魔鬼洞鱂", "value": 6.0, "trait": "wild", "habit": "cover", "reach": ["near", "mid"],
		"colors": [Color(0.12, 0.32, 0.88), Color(0.6, 0.76, 1.0), Color(0.08, 0.12, 0.4)], "pattern": "scales", "body": "tilapia"},

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
	# (user request - the beach's first branch's own: made from the trevally - slimmer, silver-blue as
	# moonlight, its fins yellow)
	"moon_jack": {"name": "月光鰺", "value": 2.2, "trait": "normal", "habit": "", "reach": ["near", "mid"],
		"colors": [Color(0.55, 0.63, 0.74), Color(0.93, 0.95, 0.98), Color(0.88, 0.75, 0.3)], "pattern": "gradient", "body": "trevally"},
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
	"desert": [["pupfish", "garra", "desert_sucker", "bonytail"], "devils_pupfish"],
	"city": [["flowerhorn", "koi", "blood_parrot", "discus"], "asian_arowana"],
	"countryside": [["medaka", "pale_chub", "bitterling", "yellow_catfish"], "mandarin_fish"],
	"japan": [["yamame", "ugui", "kawamutsu", "goldfish"], "biwa_catfish"],
	"england": [["roach", "rudd", "tench", "dace"], "atlantic_salmon"],
	"china": [["mud_carp", "red_eye_trout", "sand_loach", "yellow_river_carp"], "chinese_sucker"],
	"adobe": [["nile_tilapia", "bynni", "african_catfish", "elephantfish"], "nile_perch"],
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
	"snow": "snow", "snow_pine": "snow", "snow_lowpoly": "snow", "autumn": "autumn", "autumn_lowpoly": "autumn",
	"ruins": "ruins", "beach_rocky": "sea", "beach_sandy": "sea", "desert": "desert", "coast": "sea", "coast_cliff": "sea", "city": "city",
	"countryside": "countryside", "japan": "japan", "england": "england", "china": "china", "adobe": "adobe",
}
## This map's waters (MapGenerator sets it from the theme).
static var waters := "forest"


static func waters_for_theme(theme_name: String) -> String:
	return THEME_WATERS.get(theme_name, "forest")


## The species ids a cast can bring up: by the map's waters, the rarity
## rolled ("common" / "rare" / "epic") and the water it's cast into (the
## purple rare pools hold only the style's own fish and better).
static func pool_for(water_key: String, zone_key: String, rarity_key: String) -> Array:
	# (user request - the maps' branches: each its own fish - branch_fish with the rare ones and now and
	# then an everyday catch, branch_epic with the rarest - and a fish that's some branch's own found
	# only in that branch)
	# (an everyday catch is rarity "common" as Player rolls it - "" as some callers name it)
	if not branch_fish.is_empty() and rarity_key in ["", "common"] and zone_key != "rare" and randf() < BRANCH_EVERYDAY:
		return branch_fish
	# (user request - free mode's nights: a storm of one kind, most of the everyday catches it)
	if storm_fish != "" and rarity_key in ["", "common"] and zone_key != "rare" and randf() < STORM_SHARE:
		return [storm_fish]
	if water_key == "sea":
		match rarity_key:
			"epic":
				return _branch_pool(SEA_LEGEND, branch_epic, SEA_RARE)
			"rare":
				return _branch_pool(SEA_RARE, branch_fish, SEA_COMMON)
		return _branch_pool(SEA_RARE, branch_fish, SEA_COMMON) if zone_key == "rare" else SEA_COMMON
	var style: Array = STYLE_FISH.get(water_key, STYLE_FISH.forest)
	match rarity_key:
		"epic":
			return [style[1]] + branch_epic
		"rare":
			return style[0] + branch_fish
	if zone_key == "rare":
		return style[0] + branch_fish
	# Everyday fish: the shared ones mostly, the style's own now and then.
	return COMMON_FRESH + style[0] if randf() < STYLE_OWN_CHANCE else COMMON_FRESH


## (the sea's: its pool less the fish that are some other branch's own, with this branch's; the
## `fallback` (less those too) if none are left. The free run, in no branch, has its pools as
## they always were)
static func _branch_pool(base: Array, own: Array, fallback: Array) -> Array:
	if branch_fish.is_empty() and branch_epic.is_empty():
		return base
	var pool := base.filter(func(id): return not id in BRANCH_ONLY) + own
	if pool.is_empty():
		pool = fallback.filter(func(id): return not id in BRANCH_ONLY) + branch_fish
	return pool if not pool.is_empty() else SEA_COMMON


## Every species a cast into these waters can bring up (for warming their models up before the
## run's first bite: RunView3D.start_warm).
static func species_in(water_key: String) -> Array:
	if water_key == "sea":
		return SEA_COMMON + SEA_RARE + SEA_LEGEND + branch_fish + branch_epic
	var style: Array = STYLE_FISH.get(water_key, STYLE_FISH.forest)
	return COMMON_FRESH + style[0] + [style[1]] + branch_fish + branch_epic


## How often an everyday freshwater catch may be one of the style's own.
const STYLE_OWN_CHANCE := 0.3
## (user request - the maps' branches) this run's branch's own fish: with the rare ones (and, BRANCH_EVERYDAY
## of the time, an everyday catch); its rarest, with the rarest. Set by Campaign as a level starts.
static var branch_fish: Array = []
static var branch_epic: Array = []
const BRANCH_EVERYDAY := 0.12

## User request (free mode's nights - Campaign.FREE_EVENTS): tonight's storm of one kind (its id, ""
## none): STORM_SHARE of the everyday catches it, GOLDEN_CHANCE of those golden - worth GOLDEN_VALUE
## times as much; the night's odds of a rare one (rare_mult, x Player's) and the size of what bites
## (size_mult, x its length). Set by Campaign.begin_free, put back for a level.
static var storm_fish := ""
static var rare_mult := 1.0
static var size_mult := 1.0
const STORM_SHARE := 0.6
const GOLDEN_CHANCE := 0.05
const GOLDEN_VALUE := 5.0
const GOLD := Color(1.0, 0.78, 0.24)
static var _gold_icons := {}
## The sea's fish that are a branch's own - not caught in another branch's sea (the free run has
## the sea's rare and rarest as always).
const BRANCH_ONLY := ["moon_jack", "trevally", "napoleon", "sunfish", "sailfish", "hammerhead", "swordfish", "bluefin"]


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
##   rally: the chance it gets its strength back late in the fight
##     (FishFight.RALLY_AT; user request)
const DIFFICULTY := {
	"novice": {"label": "入門", "nibbles": Vector2i(0, 0), "fake": 0.0, "window": 1.1,
		"stamina": 1.0, "pull": 0.8, "run_interval": Vector2(4.5, 7.0), "run_time": 0.5,
		"side": 0.0, "jump": 0.0, "phases": 1, "sweet": 0.4},
	"normal": {"label": "普通", "nibbles": Vector2i(0, 1), "fake": 0.0, "window": 0.8,
		"stamina": 1.3, "pull": 1.0, "run_interval": Vector2(3.0, 5.0), "run_time": 0.6,
		"side": 0.2, "jump": 0.06, "phases": 1, "sweet": 0.34},
	"advanced": {"label": "進階", "nibbles": Vector2i(1, 3), "fake": 0.15, "window": 0.55,
		"stamina": 1.7, "pull": 1.15, "run_interval": Vector2(2.4, 3.9), "run_time": 0.7,
		"side": 0.5, "jump": 0.12, "phases": 1, "sweet": 0.28, "rally": 0.4},
	"master": {"label": "大師", "nibbles": Vector2i(2, 4), "fake": 0.35, "window": 0.38,
		"stamina": 1.7, "pull": 1.3, "run_interval": Vector2(1.9, 3.2), "run_time": 0.8,
		"side": 0.6, "jump": 0.16, "phases": 2, "sweet": 0.22, "rally": 1.0},
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


## User request: a catch is more than its kind - each one has a length, a
## weight and a trait, and the traits will matter in the fish tank later
## (a fierce one goes for the others, a schooling one keeps with them...).
##
## Length: the range an angler lands, in cm; where in it a catch falls
## goes by its size (Inventory: near-shore fish small, far ones large, a
## legend past the top). Weight: k * L^3 grams, k by body shape.
const LENGTH_CM := {
	"carp": [30, 90], "crucian": [12, 35], "grass_carp": [40, 110], "tilapia": [15, 40], "catfish": [30, 90],
	"bass": [25, 60], "bluegill": [10, 25], "rainbow_trout": [25, 65], "eel": [40, 100], "loach": [8, 20],
	"brown_trout": [25, 70], "brook_trout": [20, 45], "grayling": [25, 50], "ayu": [12, 25], "golden_trout": [20, 45],
	"snakehead": [30, 80], "bowfin": [35, 80], "cavefish": [6, 12], "black_catfish": [30, 80], "ghost_fish": [40, 90],
	"char": [25, 60], "sculpin": [8, 18], "goby": [5, 15], "minnow": [5, 12], "wels": [100, 250],
	"piranha": [15, 35], "oscar": [20, 35], "angelfish": [10, 20], "arowana": [50, 90], "arapaima": [120, 280],
	"sturgeon": [80, 200], "lungfish": [50, 120], "bichir": [25, 60], "paddlefish": [80, 180], "coelacanth": [120, 190],
	"swamp_eel": [30, 70], "betta": [5, 8], "climbing_perch": [12, 25], "walking_catfish": [25, 45],
	"alligator_gar": [120, 280], "arctic_char": [30, 75], "whitefish": [25, 55], "burbot": [30, 80], "smelt": [12, 25],
	"taimen": [70, 180], "sockeye": [45, 80], "pike": [45, 120], "perch": [15, 40], "channel_cat": [35, 100],
	"golden_koi": [45, 100], "pleco": [20, 50], "silver_carp": [45, 100], "giant_goldfish": [25, 45], "crayfish": [8, 15],
	"two_headed_carp": [50, 110], "pupfish": [4, 8], "garra": [8, 15], "desert_sucker": [20, 40],
	"bonytail": [30, 60], "devils_pupfish": [3, 6], "mackerel": [25, 50], "sardine": [12, 25], "horse_mackerel": [18, 40],
	"saury": [25, 35], "herring": [20, 40], "sea_bream": [25, 80], "sea_bass": [35, 90], "flounder": [25, 70],
	"cod": [45, 120], "puffer": [15, 40], "cutlassfish": [70, 150], "grouper": [35, 120], "mullet": [35, 70],
	"croaker": [25, 60], "yellowtail": [50, 120], "mahi": [60, 150], "conger": [60, 150], "scorpionfish": [12, 30],
	"trevally": [60, 150], "moon_jack": [30, 70], "napoleon": [80, 200], "sunfish": [120, 300], "sailfish": [170, 300],
	"hammerhead": [180, 400], "swordfish": [150, 350], "bluefin": [120, 280],
	"flowerhorn": [15, 35], "koi": [35, 90], "blood_parrot": [12, 25], "discus": [12, 22], "asian_arowana": [45, 90],
	"guppy": [3, 6], "clown_knifefish": [30, 80], "redtail_catfish": [50, 130], "electric_eel": [80, 220], "tarpon": [80, 220],
	"medaka": [2.5, 4], "pale_chub": [8, 18], "bitterling": [4, 9], "yellow_catfish": [12, 30], "mandarin_fish": [25, 60],
	"paradise_fish": [5, 10], "bream": [20, 45], "culter": [30, 80], "bighead_carp": [50, 130], "black_carp": [60, 150],
	"yellowcheek": [80, 200],
	"yamame": [15, 30], "ugui": [10, 30], "kawamutsu": [8, 16], "goldfish": [8, 25], "biwa_catfish": [60, 120],
	"amago": [15, 30], "sakura_masu": [35, 65], "hasu": [15, 30], "nigoro": [20, 40], "biwa_trout": [40, 70],
	"akame": [60, 130],
	"roach": [15, 35], "rudd": [15, 35], "tench": [25, 60], "dace": [15, 30], "atlantic_salmon": [60, 120],
	"gudgeon": [8, 15], "chub": [30, 60], "barbel": [40, 90], "zander": [40, 90], "sea_trout": [40, 90],
	"ferox_trout": [60, 110],
	"mud_carp": [15, 35], "red_eye_trout": [20, 45], "sand_loach": [8, 18], "yellow_river_carp": [30, 70],
	"chinese_sucker": [50, 100], "spotted_steed": [20, 40], "reeves_shad": [30, 55], "coilia": [20, 35],
	"luciobrama": [50, 110], "goonch": [70, 160], "chinese_sturgeon": [100, 250],
	"nile_tilapia": [15, 40], "bynni": [25, 60], "african_catfish": [30, 90], "elephantfish": [20, 45],
	"nile_perch": [60, 180], "labeo": [25, 55], "electric_catfish": [25, 70], "tigerfish": [30, 70],
	"synodontis": [12, 30], "goliath_tigerfish": [70, 140], "gymnarchus": [80, 160],
}
const WEIGHT_K := {
	"carp": 0.014, "tilapia": 0.018, "bass": 0.013, "trout": 0.011, "catfish": 0.009, "eel": 0.0022, "goby": 0.011,
	"pike": 0.007, "angel": 0.03, "arowana": 0.006, "sturgeon": 0.006, "gar": 0.004, "coelacanth": 0.015,
	"betta": 0.012, "mackerel": 0.009, "tuna": 0.018, "bream": 0.02, "grouper": 0.017, "ribbon": 0.0006,
	"ribbon_short": 0.004, "flat": 0.012, "puffer": 0.03, "billfish": 0.005, "sunfish": 0.06, "shark": 0.006,
	"mahi": 0.009, "trevally": 0.016, "crayfish": 0.02,
}
## Where in its length range a catch of each size falls (0 = shortest).
const SIZE_SPAN := {"small": [0.0, 0.35], "medium": [0.3, 0.65], "large": [0.6, 0.95], "huge": [0.9, 1.12]}

## The tank traits: name, what it does (in the tank - to come).
const TANK_TRAITS := {
	"fierce": ["兇猛", "會攻擊魚缸裡的其他魚"],
	"school": ["群聚", "總是跟其他魚一起游"],
	"bottom": ["底棲", "喜歡待在缸底"],
	"shy": ["膽小", "常躲在水草後面"],
	"lazy": ["慵懶", "很少游動"],
	"active": ["好動", "在缸裡四處巡游"],
	"jumper": ["愛跳", "偶爾會跳出水面"],
	"glutton": ["貪吃", "會搶其他魚的食物"],
}
## Each species' usual trait (the rest: "active"); one in five catches has
## a mind of its own (INDIVIDUAL_CHANCE) and rolls another.
const TRAIT_OF := {
	"fierce": ["bass", "snakehead", "bowfin", "pike", "piranha", "arowana", "arapaima", "alligator_gar", "taimen", "wels",
		"betta", "oscar", "grouper", "hammerhead", "trevally", "cutlassfish", "conger", "ghost_fish", "two_headed_carp",
		"flowerhorn", "asian_arowana", "electric_eel", "mandarin_fish", "paradise_fish", "culter", "yellowcheek",
		"hasu", "akame", "zander", "ferox_trout", "biwa_catfish", "luciobrama", "goonch", "tigerfish", "goliath_tigerfish", "electric_catfish", "nile_perch"],
	"school": ["moon_jack", "sardine", "herring", "horse_mackerel", "saury", "mackerel", "smelt", "minnow", "ayu", "whitefish",
		"bluegill", "crucian", "perch", "croaker", "guppy", "medaka", "pale_chub", "bitterling", "ugui",
		"kawamutsu", "roach", "rudd", "dace", "mud_carp", "coilia", "nile_tilapia", "labeo"],
	"bottom": ["catfish", "black_catfish", "channel_cat", "walking_catfish", "loach", "goby", "sculpin", "flounder",
		"sturgeon", "pleco", "burbot", "crayfish", "scorpionfish", "cod", "redtail_catfish", "yellow_catfish", "gudgeon", "barbel",
		"sand_loach", "chinese_sturgeon", "african_catfish", "synodontis", "elephantfish"],
	"shy": ["eel", "swamp_eel", "cavefish", "angelfish", "bichir", "coelacanth", "puffer", "discus", "clown_knifefish"],
	"lazy": ["lungfish", "sunfish", "giant_goldfish", "paddlefish", "napoleon", "blood_parrot", "bighead_carp", "tench", "chinese_sucker", "gymnarchus"],
	"jumper": ["sailfish", "swordfish", "silver_carp", "mullet", "tarpon", "sakura_masu", "atlantic_salmon", "sea_trout", "reeves_shad"],
	"glutton": ["carp", "grass_carp", "tilapia", "golden_koi", "koi", "black_carp", "goldfish", "nigoro", "yellow_river_carp", "bynni"],
}
const INDIVIDUAL_CHANCE := 0.2


## A catch's length (cm) and weight (kg), by its species and size.
static func measure(id: String, size_key: String) -> Dictionary:
	var span: Array = LENGTH_CM.get(id, [20, 50])
	var at: Array = SIZE_SPAN.get(size_key, SIZE_SPAN.small)
	var length: float = lerpf(span[0], span[1], randf_range(at[0], at[1])) * size_mult
	var body: String = FISH.get(id, {}).get("body", "carp")
	var k: float = 0.0035 if id == "sailfish" else WEIGHT_K.get(body, 0.012)
	var kg: float = k * pow(length, 3) / 1000.0 * randf_range(0.9, 1.1)
	return {"length": snappedf(length, 0.1), "weight": snappedf(kg, 0.01 if kg < 10.0 else 0.1)}


## User request: a bigger fish of a kind sells for more - by where its
## length falls in its kind's range: x0.8 for the smallest, x1.25 for the
## longest, a legend past the top more still.
static func value_for_length(id: String, base: float, length: float) -> float:
	var span: Array = LENGTH_CM.get(id, [20, 50])
	var q := (length - float(span[0])) / maxf(float(span[1]) - float(span[0]), 1.0)
	return snappedf(base * (0.8 + 0.45 * clampf(q, 0.0, 1.2)), 0.1)


## User request (the gate): a fish too big or too rare for the stats carried
## can't be landed. A giant (a common or rare fish in the top of its length
## range) asks one stat, an epic one two, a legend three - each species' own
## (by its nature: GATE_STATS), so a kind always asks the same; the number by
## how big it is, between the band of its kind. Short by up to
## Stats.CHALLENGE it can still be tried (harder); past that it's over (Player).
## [lowest, highest] the single stat asks.
static var GATE_BANDS := {"giant": [20, 40], "giant_rare": [35, 55], "epic": [40, 60], "legend": [65, 100]}
const GIANT_FROM := 0.85

## Each species' main stat, by its nature: 反應 the quick, skittish and
## shoaling; 力量 the heavy and bottom-dwelling; 韌性 the toothed that cut a line;
## 耐力 the long runners and leapers.
const GATE_MAIN := {
	"react": ["brown_trout", "brook_trout", "grayling", "ayu", "golden_trout", "char", "minnow", "crucian",
		"smelt", "sardine", "saury", "pupfish", "devils_pupfish", "angelfish", "cavefish", "loach",
		"tilapia", "mahi", "mullet", "croaker", "rainbow_trout", "sea_bream", "silver_carp", "moon_jack",
		"guppy", "discus", "blood_parrot", "medaka", "pale_chub", "bitterling", "culter",
		"yamame", "ugui", "kawamutsu", "amago", "hasu", "roach", "rudd", "dace", "gudgeon",
		"mud_carp", "red_eye_trout", "sand_loach", "spotted_steed", "coilia", "nile_tilapia", "labeo", "elephantfish"],
	"might": ["carp", "wels", "paddlefish", "lungfish", "golden_koi", "giant_goldfish", "coelacanth", "arapaima",
		"napoleon", "sunfish", "bichir", "catfish", "cod", "bonytail", "koi", "redtail_catfish", "bream", "bighead_carp",
		"black_carp", "goldfish", "nigoro", "biwa_catfish", "tench", "barbel", "yellow_river_carp", "chinese_sucker",
		"goonch", "chinese_sturgeon", "bynni", "african_catfish", "nile_perch"],
	"resil": ["horse_mackerel", "bluegill", "sculpin", "goby", "crayfish", "puffer", "garra", "betta", "bass",
		"snakehead", "bowfin", "ghost_fish", "piranha", "oscar", "pike", "taimen", "alligator_gar",
		"cutlassfish", "conger", "scorpionfish", "two_headed_carp", "hammerhead", "trevally", "arowana",
		"flounder", "channel_cat", "pleco", "walking_catfish", "arctic_char", "flowerhorn", "clown_knifefish",
		"asian_arowana", "yellow_catfish", "mandarin_fish", "paradise_fish",
		"akame", "chub", "zander", "ferox_trout", "luciobrama", "electric_catfish", "synodontis", "goliath_tigerfish"],
	"endure": ["herring", "mackerel", "perch", "climbing_perch", "whitefish", "desert_sucker", "eel", "swamp_eel",
		"sea_bass", "yellowtail", "sockeye", "sailfish", "swordfish", "bluefin", "grass_carp", "sturgeon",
		"burbot", "black_catfish", "grouper", "electric_eel", "tarpon", "yellowcheek", "sakura_masu", "biwa_trout",
		"atlantic_salmon", "sea_trout", "reeves_shad", "tigerfish", "gymnarchus"],
}
## The second (and third) stats the epic and legend fish ask besides their main.
const GATE_EXTRA := {
	"golden_trout": ["resil"], "ghost_fish": ["react"], "wels": ["endure"], "arapaima": ["resil"],
	"coelacanth": ["endure"], "alligator_gar": ["might"], "taimen": ["endure"], "golden_koi": ["react"],
	"two_headed_carp": ["might"], "devils_pupfish": ["endure"], "trevally": ["react"], "napoleon": ["endure"],
	"sunfish": ["react"], "sailfish": ["react"], "hammerhead": ["endure"],
	"swordfish": ["resil", "react"], "bluefin": ["might", "react"],
	"asian_arowana": ["react"], "electric_eel": ["might"], "tarpon": ["react"],
	"mandarin_fish": ["react"], "black_carp": ["endure"], "yellowcheek": ["react"],
	"biwa_catfish": ["endure"], "biwa_trout": ["react"], "akame": ["might"],
	"atlantic_salmon": ["react"], "sea_trout": ["react"], "ferox_trout": ["might"],
	"chinese_sucker": ["endure"], "goonch": ["resil"], "chinese_sturgeon": ["endure"],
	"nile_perch": ["endure"], "goliath_tigerfish": ["might"], "gymnarchus": ["resil"],
}


## Where `length` falls in the species' range (0 the shortest .. 1 the
## longest, past it a record).
static func length_q(id: String, length: float) -> float:
	var span: Array = LENGTH_CM.get(id, [20, 50])
	return (length - float(span[0])) / maxf(float(span[1]) - float(span[0]), 1.0)


static func gate_stats(id: String) -> Array:
	var out := []
	for stat in GATE_MAIN:
		if id in GATE_MAIN[stat]:
			out.append(stat)
	if out.is_empty():
		# (a kind not listed: by its name)
		out.append(Stats.IDS[(id.hash() % 9973) % Stats.IDS.size()])
	out.append_array(GATE_EXTRA.get(id, []))
	# (a fish made a legend or epic without its own extras: others, by its name)
	var rest := Stats.IDS.filter(func(t): return not t in out)
	rest.sort_custom(func(a, b): return (id + a).hash() % 9973 < (id + b).hash() % 9973)
	out.append_array(rest)
	return out


## {stat: number needed} for a catch of `id` (rarity as UiKit.fish_rarity says:
## common, rare, epic, legend) and `length`; {} for a fish with no gate.
static func gate_for(id: String, rarity: String, length: float) -> Dictionary:
	var q := length_q(id, length)
	var level := ""
	var t := 0.0
	match rarity:
		"legend":
			level = "legend"
			t = clampf(q / 1.12, 0.0, 1.0)
		"epic":
			level = "epic"
			t = clampf(q / 1.12, 0.0, 1.0)
		_:
			if q >= GIANT_FROM:
				level = "giant_rare" if rarity == "rare" else "giant"
				t = clampf((q - GIANT_FROM) / (1.12 - GIANT_FROM), 0.0, 1.0)
	if level == "":
		return {}
	var band: Array = GATE_BANDS[level]
	var need := roundi(lerpf(float(band[0]), float(band[1]), t))
	var count: int = {"giant": 1, "giant_rare": 1, "epic": 2, "legend": 3}[level]
	var stats := gate_stats(id)
	var out := {}
	for i in mini(count, stats.size()):
		out[stats[i]] = need
	return out


static func species_trait(id: String) -> String:
	for key in TRAIT_OF:
		if id in TRAIT_OF[key]:
			return key
	return "active"


## One catch's trait: mostly its kind's, now and then its own.
static func roll_tank_trait(id: String) -> String:
	var usual := species_trait(id)
	if randf() >= INDIVIDUAL_CHANCE:
		return usual
	var others := TANK_TRAITS.keys().filter(func(k): return k != usual)
	return others[randi() % others.size()]


static func trait_name(key: String) -> String:
	return TANK_TRAITS.get(key, ["", ""])[0]


## "45.2 cm・1.24 kg" for a catch that has them ("" otherwise).
static func size_text(fish: Dictionary) -> String:
	if not fish.has("length"):
		return ""
	var kg: float = float(fish.weight)
	var w := "%.0f g" % (kg * 1000.0) if kg < 1.0 else ("%.2f kg" % kg if kg < 10.0 else "%.1f kg" % kg)
	return "%.1f cm・%s" % [float(fish.length), w]


static var _icons := {}


## A species' picture (tools/render_fish.py, or the photo-built one): by id
## or, failing that, by name. Null for what isn't a fish (the heart).
## A fish's picture as the fish dict `f` is: a golden one's in gold (made once a kind).
static func icon_of(f: Dictionary) -> Texture2D:
	var id := str(f.get("id", ""))
	var tex := icon(id, str(f.get("name", "")))
	if tex == null or not f.get("golden", false):
		return tex
	if not _gold_icons.has(id):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a <= 0.01:
					continue
				var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				var g := GOLD * (0.35 + lum * 0.95)
				img.set_pixel(x, y, Color(minf(g.r, 1.0), minf(g.g, 1.0), minf(g.b, 1.0), c.a))
		_gold_icons[id] = ImageTexture.create_from_image(img)
	return _gold_icons[id]


static func icon(id: String, species_name: String = "") -> Texture2D:
	if id == "" and species_name != "":
		id = id_for(species_name)
	if id == "" or not FISH.has(id):
		return null
	if not _icons.has(id):
		_icons[id] = load("res://assets/sprites/fish/%s.png" % id)
	return _icons[id]
