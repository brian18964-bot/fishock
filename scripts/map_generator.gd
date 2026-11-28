class_name MapGenerator
extends Node2D

## Design doc request: each run gets a freshly randomized layout instead of
## the old fixed one - a handful of water zones (mostly "common", a couple
## "rare"; see water_zone.gd), plus the altar and escape point no longer
## sitting at fixed coordinates. This node is the FIRST child of Main (see
## main.tscn) specifically so its _ready() runs before any sibling that
## reads these positions/groups in its own _ready() - Hotspot (picks a spot
## inside a common zone) and Ghost (reads EscapePoint's position).

const WATER_ZONE_SCENE := preload("res://scenes/water_zone.tscn")

## User request: 3-4 common zones and a single rare one per run, each an
## irregular pond - a main circle plus a few overlapping lobes (see
## WaterZone) - kept apart so each is its own lake with a shore to dress.
const COMMON_ZONE_COUNT := Vector2i(3, 4)
const RARE_ZONE_COUNT := 1
## A "sea" theme (user request: the seaside - the water along one side of the map, any side, as the
## old beach maps had it): how far in the sea reaches (share of the map across it), the zones' least
## radius, how much the coast wanders, lobes a zone, the baked shore's coarseness, the open sea's
## backing circle.
const SEA_REACH := Vector2(0.3, 0.38)
const SEA_RADIUS := 320.0
const SEA_WOBBLE := 50.0
const SEA_LOBES := Vector2i(2, 3)
const SEA_FIELD_TEXEL := 2.0
const SEA_BACKING_RADIUS := 20000.0
const COMMON_RADIUS_MIN := 130.0
const COMMON_RADIUS_MAX := 175.0
const COMMON_EXTRA_LOBES := Vector2i(2, 4)
const RARE_RADIUS_MIN := 90.0
const RARE_RADIUS_MAX := 115.0
const RARE_EXTRA_LOBES := Vector2i(1, 2)
const ZONE_MARGIN := 60.0
const ZONE_MIN_GAP := 90.0

## Design doc request: rare zones are placed without regard to the altar -
## no distance-from-altar logic here, just kept clear of the shared spawn
## point so the player never spawns inside solid water-zone collision.
## The middle of the map: the full map's, or a smaller one's (Campaign).
static var SPAWN_POS := Vector2(1200.0, 700.0)
const SPAWN_CLEAR_RADIUS := 220.0

const FIXED_POINT_MARGIN := 150.0
const FIXED_POINT_MIN_SEPARATION := 550.0
const WILLOW_BESIDE_ALTAR := Vector2(72.0, 16.0)
## How far out the willow stands from the altar's middle (Willow.FRONT
## and its own breadth).
const WILLOW_RING := 66.0

## User feedback follow-up: obstacles/trees/bushes were still at fixed
## main.tscn positions, so they could visually land inside a randomized
## water zone (a tree "growing" out of a lake). Scattered here too, kept
## clear of water and of each other - purely cosmetic (obstacles/tree
## trunks are already solid, so overlapping a rare zone's collision was
## never a functional bug, just an odd-looking one).
const PROP_NAMES := [
	"Obstacle1", "Obstacle2", "Obstacle3", "Obstacle4", "Obstacle5",
	"Tree1", "Tree2", "Tree3", "Tree4", "Tree5", "Tree6",
	"Bush1", "Bush2", "Bush3",
]
const PROP_MARGIN := 80.0
const PROP_MIN_SEPARATION := 90.0
## User request (3D): nothing in anything, nothing crowded. Every solid
## thing placed keeps this much ground (px) between its base and the next
## one's - room to walk between; trees keep their branches clear of each
## other's and of the camp, the altar, the stones and the bank.
const PROP_GAP := 34.0
## Branches clear of the water's edge by this much more (the rod's swing).
const BANK_CLEAR := 40.0
const PROP_AVOID_SPAWN_RADIUS := 180.0

const DOCK_SCENE := preload("res://scenes/dock.tscn")
## Every common pond gets one, and this share of them a second.
const SECOND_DOCK_CHANCE := 0.5
const DOCK_SHORE_MARGIN := 60.0
const DOCK_STAIRS_CHANCE := 0.5
const DOCK_BOAT_CHANCE := 0.4
## User request: "可以走上去的橋" - bridges over the ponds on the villages' maps (a style's "bridge":
## how they're built; user decision: none on the forest, autumn and other maps that aren't villages). The water it crosses (px, bank to bank - a pond's waist, or across a small one;
## the longest with the ponds on a bigger map, up to BRIDGE_SPAN_GROW times), how far each end
## reaches up onto the bank (px), its walkable half width (px), how many crossings are tried on each
## pond; and how far into the water its middle must be against half its span (more a waist than a
## chord across a little bay at the pond's edge).
const BRIDGE_SPAN := Vector2(150.0, 340.0)
## User report ("很多小水域你也設計了橋樑，是多餘的"): a bridge only over a big water - a pond this long
## at its longest (px) or more - never a small one, walked round in a moment.
const BRIDGE_POND_MIN := 620.0
const BRIDGE_SPAN_GROW := 2.0
const BRIDGE_LAND := 34.0
const BRIDGE_HALF_WIDTH := 26.0
const BRIDGE_TRIES := 80
const BRIDGE_WAIST := 0.5
## (the most on one map: one a base map's area - a small map one, a big one three)
const BRIDGE_MOST := 3

const GROUND_COVER_SCENE := preload("res://scenes/ground_cover.tscn")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const TREE_SCENE := preload("res://scenes/tree.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const FLIP_ROCK_SCENE := preload("res://scenes/flip_rock.tscn")
## User request: rocks the player can turn over for bait, per run.
const FLIP_ROCKS := Vector2i(8, 10)
const NOT_FLIPPABLE := ["pillar", "grave", "lantern", "shrine", "well", "lp_grave", "lp_lantern", "lp_shrine", "lp_well",
	"bones"]
const BUSH_SCENE := preload("res://scenes/bush.tscn")

## User decision: one place for now - the lakeside pine forest (in 3D,
## RunView3D), polished before the next opens. How many extra trees,
## rocks, bushes and plants it scatters and which kinds. User request: not
## crowded - few small things.
const THEME := "forest_pine"
## The style this run's map has (set as the map is made; RunView3D dresses it by it).
static var current_theme := "forest_pine"
## The season the map's trees are in (MapTree.SEASON_KINDS - the level's own, a free night's at
## random; "" for a style whose trees look one way the year round).
static var current_season := ""
## The Chinese village's bamboo grove (a level may ask for more, thicker ones - its "yard" "groves").
const CHINA_BAMBOO := {"kind": "bamboo", "models": ["cn_bamboo"], "count": 2, "rows": Vector2i(2, 3), "cols": Vector2i(3, 5),
	"gap": 120.0, "jitter": 30.0, "fill": 0.5, "size": Vector2(40, 0)}
const THEMES := {
	"forest_pine": {
		"look": "detailed",
		"floor": ["forest_floor", "grass", 0.35],
		"trees": 28, "rocks": 3, "bushes": 4, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"plant": 1.0},
		# (user report: too many wolves - one following about without biting
		# was the husky, a wolf to look at in the dark: gone; wolves fewer)
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 1.5, "wolf": 0.5},
	},
	# User request: another look - the snowy pine forest: the same pines under snow, a frozen
	# fringe round the water, snow falling; fewer plants, the wolves a bit more about.
	"snow_pine": {
		"look": "detailed",
		"floor": ["grass", "forest_floor", 0.45],
		"trees": 24, "rocks": 4, "bushes": 3, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"plant": 0.5},
		"animals": {"deer": 1.5, "stag": 1.0, "fox": 2.0, "wolf": 0.8},
		"shore_extras": {"reeds": 0.08, "lilypad": 0.0, "driftwood": 0.12},
	},
	# User request: the next look - autumn: the wood's trees bare and dead, a few with their last
	# turned leaves (MapTree.THEME_KINDS), the ground leaf litter and dry grass ("floor3d", the 3D
	# ground's two), leaves falling (WeatherFX); very few wild animals about.
	"autumn": {
		"look": "detailed",
		"floor": ["leaf_litter", "grass_autumn", 0.5],
		"floor3d": {"grass": "grass_autumn", "forest": "leaf_litter"},
		"trees": 24, "rocks": 4, "bushes": 2, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"plant": 0.4},
		# (the forest's AMBIENT_ANIMAL_COUNT is 8 a base map's area - ~21 on the free run's; here
		# one - ~3 there)
		"animal_count": 1,
		"animals": {"deer": 1.5, "stag": 1.0, "fox": 1.5, "wolf": 0.3},
		"shore_extras": {"reeds": 0.12, "lilypad": 0.02, "driftwood": 0.14},
	},
	# User request: the desert - the water an oasis (the picture: a pool in a hollow of the dunes,
	# ringed with green, palms thick along one side), the oasis meeting the desert well, very few
	# animals. RunView3D's _desert: the dunes, the damp sand and the green round the pools
	# ("floor3d"), the blown sand, prints in the sand. The palms grow by the water ("oasis_trees"
	# of them in the "oasis_band", px up from the shore, most in a grove or two a pool -
	# _place_tree), the rest dead trees out on the dunes (MapTree.DESERT_OPEN); the dinosaur's bones
	# ("fossils") out in the open.
	"desert": {
		"look": "detailed",
		"floor": ["dune_sand", "oasis_grass", 0.12],
		"floor3d": {"grass": "dune_sand", "forest": "oasis_grass", "mud": "wet_sand", "stone": "cracked_mud"},
		"trees": 22, "rocks": 3, "bushes": 3, "ground": 6,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"plant": 1.0},
		# (user request: no dead trees in the desert - every tree a palm by the water - and what grows
		# only near the water: the hide bushes and the ground's plants in "plant_band" round the pools)
		"oasis_trees": 1.0,
		# (user request: green only near the water - the oasis's ring; out on the open sand only the
		# dry plants RunView3D adds)
		"plant_band": [30.0, 230.0],
		"oasis_band": [24.0, 230.0],
		# (the big skeletons - the dinosaur, the mammoth and the user's second batch's elephant, crocodile
		# and big cat - "big_fossils" of them a base map's area, which drawn anew each game; each
		# covered by the sand to its own depth: Fossil.cover)
		# ("bones": what came off them, lying alone out on the sand - a leg, a skull)
		"fossils": {"dino": 1, "mammoth": 1, "elephant": 1, "crocodile": 1, "wildcat": 1, "saguaro": 3, "cholla": 3, "skull": 3, "bones": 3},
		"big_fossils": 3,
		# (one a base map's area - ~3 on the free run's; the user's own desert animals - made ours by
		# tools/make_desert_animals.py: a camel about the oasis, an iguana basking, the hyena hunting
		# as the wolf does elsewhere, now and then the sandy fox)
		"animal_count": 1,
		"animals": {"camel": 0.35, "iguana": 0.3, "hyena": 0.25, "fox": 0.1},
		# (a level's own beasts, the desert's kin of them)
		"beast_kin": {"wolf": "hyena"},
		"shore": {"grass": 0.32, "shrub": 0.1, "pebbles": 0.0},
		"shore_extras": {"reeds": 0.16, "lilypad": 0.0, "driftwood": 0.0},
		"shore_critters": ["frog", "spider", "snake"],
	},
	# User request: the seaside - the sea along one side of the map (any side: up, down, left or right
	# on the screen; "sea", MapGenerator._generate_sea), a sand beach along it, its wet edge where the
	# waves run up, the waves; crabs and gulls - none of the forest's animals. RunView3D's _coast: the
	# beach and the dunes behind it (its "floor3d": the pale sea sand, the wet sand, the grass back
	# from the beach, the pebbles), the sea out to the horizon. User feedback: a beach and a sea cliff
	# are two kinds of coast that don't meet - no rocks walling the beach off: the cliffs are a map of
	# their own ("coast_cliff"). Here coconut palms (MapTree's "coast") along the top of the beach and
	# inland ("inland", px from the shore), a few rocks.
	"coast": {
		"look": "detailed",
		"sea": true,
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "sea_sand", "forest": "grass", "mud": "wet_sand", "stone": "sea_pebbles"},
		"trees": 14, "rocks": 2, "bushes": 3, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"inland": 200.0,
		"animal_count": 0,
		"animals": {},
		"shore": {"grass": 0.0, "shrub": 0.0, "pebbles": 0.03},
		"shore_extras": {"reeds": 0.0, "lilypad": 0.0, "driftwood": 0.05},
		"shore_critter_count": 0,
		"shore_critters": ["crab"],
		"water": {"base": Color(0.07, 0.36, 0.46), "deep": Color(0.02, 0.12, 0.24)},
	},
	# User request (the coast's other kind - a beach and a sea cliff don't meet): the sea cliff - the
	# land high over the sea along its side (RunView3D's _cliff: a grassy top falling sheer into the
	# water, rock at its face, the surf breaking at its foot), fished from the edge; no beach, no dock
	# ("docks"). The sea narrower than the beach's and further from the camp ("sea_reach", share of the
	# map across it; "sea_clear", px - the camp, the altar, the way out and the cage down off the
	# cliff's rise, "fixed_inland"); windswept pines on the top; rocks at the cliff's foot in the sea.
	"coast_cliff": {
		"look": "detailed",
		"sea": true,
		"cliff": true,
		"docks": false,
		"sea_reach": Vector2(0.12, 0.16),
		"sea_clear": 760.0,
		"fixed_inland": 800.0,
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "dirt", "forest": "grass", "mud": "mud", "stone": "lp_stone"},
		"trees": 12, "rocks": 4, "bushes": 3, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"inland": 140.0,
		"animal_count": 0,
		"animals": {},
		"shore": {"grass": 0.0, "shrub": 0.0, "pebbles": 0.0},
		"shore_extras": {"reeds": 0.0, "lilypad": 0.0, "driftwood": 0.0},
		"shore_critter_count": 0,
		"shore_critters": ["crab"],
		"water": {"base": Color(0.06, 0.3, 0.42), "deep": Color(0.02, 0.1, 0.22)},
	},
	# User request (the ruined human world - its first map, the city): a city left empty - cracked
	# asphalt and paving (RunView3D's "floor3d": the streets' asphalt, the pavements round the
	# buildings, weeds and soil breaking through), the empty buildings along streets no longer kept
	# ("ruins" - Ruin, _place_ruins: the streets' width, a block's size, lots a block, the alleys
	# between them, how many blocks lie empty, how many buildings have fallen to rubble, how far from
	# the water they keep), the water where the road has sunk and flooded - murky. A few trees
	# breaking through (MapTree's "city"); none of the forest's animals.
	"city": {
		"look": "detailed",
		# (user request: "廢墟系列是會有破損生鏽的物件" - its buildings and what's about the street worn
		# hard, mossy at the foot, rusted in patches and run down the walls: CityBuild.aged; mine for now)
		"aged": {"age": 1.0, "moss": 0.35, "rust": 0.7},
		# (user request: water splitting the map, bridges over it - the city's a canal: straight, its
		# banks walled, crossed by concrete bridges - _generate_river)
		"river": {"half": Vector2(80.0, 80.0), "canal": true, "bridge": "concrete"},
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "asphalt", "forest": "grass", "path": "sidewalk", "stone": "moss_soil", "mud": "mud"},
		"trees": 10, "rocks": 2, "bushes": 3, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ruins": {"road": 180.0, "block_min": Vector2(380, 340), "block_max": Vector2(760, 600), "lots": Vector2i(2, 3),
			"alley": 60.0, "setback": 20.0, "vacant": 0.1, "fallen": 0.15, "water_gap": 60.0, "towers": 1,
			# (the user's low buildings, made ours - a whole block one of them, this share of the blocks
			# they fit; the skyline's towers outside the map's top and sides - Ruin, CityBuild)
			"models": ["city_house_1", "city_house_2", "city_house_3", "city_house_4"], "model_share": 0.55,
			"skyline": ["city_tower_1", "city_tower_2", "city_tower_3", "city_tower_4", "city_tower_5"]},
		# (what's left in the streets - StreetProp: cars and street lamps a base map's area, the share of
		# the cars slewed across the road rather than by the kerb, the lamps still lit (at most so many))
		"street": {"cars": 9, "lamps": 10, "drums": 7, "crates": 5, "benches": 3, "slewed": 0.3, "lit": 0.3, "lit_most": 3},
		"animal_count": 0,
		"animals": {},
		"shore": {"grass": 0.04, "shrub": 0.03, "pebbles": 0.06},
		"shore_extras": {"reeds": 0.05, "lilypad": 0.0, "driftwood": 0.0},
		"shore_critters": ["frog", "spider"],
		"water": {"base": Color(0.1, 0.19, 0.18), "deep": Color(0.03, 0.08, 0.08)},
	},
	# User request (the human world's countryside - an ordinary place, not a ruin: user decision):
	# farms among meadows. Its farmsteads ("farm" - _place_farms: so many a base map's area, each a
	# farmhouse and its barn about a yard, now and then a water tower, a lookout, a shelter or a row
	# of silos - the user's farm set, made ours: Ruin models "farm_*", scaled "scale"), its fields
	# (FarmField - ploughed, in stubble with round bales after the harvest, in pumpkins or greens;
	# "fenced" of them with a wooden fence along most sides, a gap in each to walk through - Fence),
	# a dirt track from each farm out to the map's edge, and what stands about ("yard" - StreetProp's
	# farm kinds: lantern posts along the tracks - "lit" of them at night, at most "lit_most" - a
	# well, log piles and lumber, barrels, troughs, milk cans, wagons and barrows by the buildings,
	# an orchard of fruit trees). The ground (RunView3D's "floor3d"): the meadow's grass, the
	# stubble, the tracks' and yards' dirt, the ploughed earth, the ponds' mud. Its farm ponds
	# brown-green; a deer or a fox about - none of the forest's wolves.
	"countryside": {
		"look": "detailed",
		# (user request: a bridge to walk over the water - Dock.setup_bridge, its build)
		"bridge": "wood",
		# (user request: a river across the map, winding between the farms - _generate_river)
		"river": {"half": Vector2(90.0, 110.0), "wind": 0.12, "bends": Vector2(1100.0, 1600.0)},
		# (user request: "至少要舊的、有年代感的" - old farm buildings, their metal rusting a little:
		# CityBuild.aged; mine for now)
		"aged": {"age": 0.8, "moss": 0.3, "rust": 0.3},
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "stubble", "forest": "grass", "path": "dirt", "stone": "furrow", "mud": "mud"},
		"trees": 14, "rocks": 2, "bushes": 4, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"farm": {"steads": 3, "houses": ["farm_house_1", "farm_house_2", "farm_house_3", "farm_house_4", "farm_house_5", "farm_house_6"],
			"barns": ["farm_barn_1", "farm_barn_2", "farm_barn_3", "farm_barn_4"],
			"extras": ["farm_tower_1", "farm_tower_2", "farm_lookout", "farm_shelter", "farm_silos"], "extra": Vector2i(0, 2),
			"scale": Vector2(0.8, 0.95), "yard": 170.0, "water_gap": 70.0,
			"fields": 5, "field_min": Vector2(340, 260), "field_max": Vector2(760, 520),
			"crops": {"plough": 1.0, "stubble": 1.2, "pumpkin": 0.7, "greens": 0.5},
			"fenced": 0.6, "gate": Vector2(80, 130), "bales": Vector2i(2, 5)},
		"yard": {"lit_most": 3, "things": [
			{"kind": "lantern", "models": ["farm_lantern"], "count": 6, "where": "track", "lit": 0.5},
			{"kind": "well", "models": ["farm_well_1", "farm_well_2"], "count": 1},
			{"kind": "logs", "models": ["farm_logs_1"], "count": 3},
			{"kind": "lumber", "models": ["farm_logs_2"], "count": 2, "turn": "square"},
			{"kind": "barrel", "models": ["farm_barrel"], "count": 4},
			{"kind": "trough", "models": ["farm_trough"], "count": 2, "turn": "square"},
			{"kind": "milk", "models": ["farm_milk"], "count": 3},
			{"kind": "wagon", "models": ["farm_wagon"], "count": 2, "turn": "square"},
			{"kind": "barrow", "models": ["farm_barrow"], "count": 2, "turn": "square"}],
			"groves": [{"kind": "fruit", "models": ["farm_fruit_1", "farm_fruit_2", "farm_fruit_3"], "count": 1,
				"rows": Vector2i(2, 3), "cols": Vector2i(3, 4), "gap": 105.0, "jitter": 8.0}]},
		# (user request: its farm animals - the calves and sheep grazing, the chickens about the yards;
		# a deer or a fox now and then - tools/make_farm_animals.py)
		"animal_count": 3,
		"animals": {"calf": 1.2, "sheep": 1.0, "chicken": 1.2, "rooster": 0.4, "deer": 0.4, "fox": 0.5},
		"shore": {"grass": 0.06, "shrub": 0.04, "pebbles": 0.02},
		"shore_extras": {"reeds": 0.14, "lilypad": 0.06, "driftwood": 0.02},
		"water": {"base": Color(0.12, 0.24, 0.18), "deep": Color(0.04, 0.11, 0.09)},
	},
	# User request (the human world's other villages, made as ordinary places): the Japanese village -
	# laid out as the countryside is ("farm", "yard"), its own: houses with a shrine or a shed across the
	# yard, now and then a roofed gate, an ema stand, a big hall as its landmark ("landmark"); rice
	# fields behind bamboo fences; pale gravel paths (RunView3D's "floor3d") from each house out to the
	# map's edge, a vermilion torii astride each near its house, stone lanterns along them (a few lit
	# at night); tall wooden lanterns, benches, stone basins and baskets by the houses; bamboo groves
	# (the user's shrine set, made ours - tools/make_japan_assets.py). Moss where the grass thins; black
	# pines and maples turning; deer and foxes about.
	"japan": {
		"look": "detailed",
		# (user request: a bridge to walk over the water - Dock.setup_bridge, its build)
		"bridge": "jp_bridge",
		# (user request: a river across the map - a mountain stream's winding - _generate_river)
		"river": {"half": Vector2(80.0, 100.0), "wind": 0.14, "bends": Vector2(900.0, 1300.0)},
		# (user request: old, of its years - weathered wood, moss in the damp: CityBuild.aged; mine for now)
		"aged": {"age": 0.8, "moss": 0.5, "rust": 0.0},
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "moss_soil", "forest": "grass", "path": "shrine_gravel", "stone": "furrow", "mud": "mud"},
		"trees": 16, "rocks": 3, "bushes": 4, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"farm": {"steads": 3, "landmark": "jp_house_2", "houses": ["jp_house_1"], "barns": ["jp_shrine", "jp_house_1", "jp_shed"],
			"extras": ["jp_gate", "jp_ema_1", "jp_shrine", "jp_shed"], "extra": Vector2i(0, 2),
			"scale": Vector2(0.85, 1.0), "yard": 150.0, "water_gap": 70.0,
			"fields": 3, "field_min": Vector2(300, 220), "field_max": Vector2(620, 420),
			# User report ("菜園只應該出現在鄉村或是中式地圖"): no vegetable plots here - its rice fields
			# after the harvest (their stubble, no bales) and turned earth.
			"crops": {"stubble": 1.0, "plough": 0.6}, "fenced": 0.75, "fences": {"bamboo": 1.0},
			"gate": Vector2(80, 120), "bales": Vector2i(0, 0)},
		"yard": {"lit_most": 4, "things": [
			{"kind": "torii", "models": ["jp_torii"], "count": 2, "where": "across", "size": Vector2(10, 155)},
			# (user request, "補強日式": the user's mossy stone lanterns among the shrine set's - tools/
			# make_japan_extras.py - and its tiered stone towers)
			{"kind": "lantern", "models": ["jp_toro", "jp_toro_moss", "jp_kasuga"], "count": 7, "where": "track", "lit": 0.6, "size": Vector2(13, 0)},
			{"kind": "lamp", "models": ["jp_lamp"], "count": 3, "lit": 0.4, "size": Vector2(9, 0)},
			{"kind": "stupa", "models": ["jp_stupa_1", "jp_stupa_2"], "count": 2, "size": Vector2(16, 0)},
			{"kind": "ema", "models": ["jp_ema_2"], "count": 1, "turn": "square", "size": Vector2(20, 57)},
			{"kind": "bench", "models": ["jp_bench"], "count": 2, "where": "yard", "size": Vector2(9, 54)},
			{"kind": "basin", "models": ["jp_basin"], "count": 2, "size": Vector2(11, 0)},
			{"kind": "basket", "models": ["jp_basket"], "count": 3, "size": Vector2(9, 0)}],
			"groves": [{"kind": "bamboo", "models": ["cn_bamboo"], "count": 3, "rows": Vector2i(2, 3), "cols": Vector2i(3, 5),
				"gap": 120.0, "jitter": 30.0, "fill": 0.5, "size": Vector2(40, 0)}]},
		# (user request: crows pecking about and flying off - tools/make_farm_animals.py)
		"animal_count": 2,
		"animals": {"crow": 1.4, "deer": 1.4, "fox": 1.0},
		"shore": {"grass": 0.06, "shrub": 0.04, "pebbles": 0.04},
		"shore_extras": {"reeds": 0.1, "lilypad": 0.1, "driftwood": 0.0},
		"water": {"base": Color(0.09, 0.24, 0.24), "deep": Color(0.03, 0.1, 0.12)},
	},
	# User request (the human world's other villages, made as ordinary places): the English village -
	# its timber-framed houses in pairs about a yard, the chapel with its spire its landmark, now and
	# then the small stone tower or a shelter beside a house (the user's medieval set and tower, made
	# ours - tools/make_england_assets.py); pastures and fields behind dry-stone walls and hedges, the
	# stubble with its bales; dirt lanes out to the map's edge with lantern posts; wells, logs, wagons
	# and an apple orchard (the farm set's, made ours). Oaks turning and pines; deer and foxes.
	"england": {
		"look": "detailed",
		# (user request: a bridge to walk over the water - Dock.setup_bridge, its build)
		"bridge": "wood",
		# (user request: a river across the map, its meanders - _generate_river)
		"river": {"half": Vector2(90.0, 110.0), "wind": 0.13, "bends": Vector2(1000.0, 1500.0)},
		# (user request: old, of its years - weathered timber and stone, moss on the roofs:
		# CityBuild.aged; mine for now)
		"aged": {"age": 0.85, "moss": 0.55, "rust": 0.0},
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "stubble", "forest": "grass", "path": "dirt", "stone": "furrow", "mud": "mud"},
		"trees": 14, "rocks": 3, "bushes": 4, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"farm": {"steads": 3, "landmark": "eng_chapel", "houses": ["eng_house_1", "eng_house_2", "eng_house_3", "eng_house_4"],
			"barns": ["eng_house_1", "eng_house_2", "eng_house_3", "eng_house_4", "farm_barn_1"],
			"extras": ["eng_tower", "farm_shelter"], "extra": Vector2i(0, 1),
			"scale": Vector2(0.8, 0.95), "yard": 160.0, "water_gap": 70.0,
			"fields": 5, "field_min": Vector2(340, 260), "field_max": Vector2(760, 520),
			# (user report: vegetable plots only in the countryside and the Chinese village - pastures here)
			"crops": {"pasture": 1.4, "plough": 0.8, "stubble": 0.8}, "fenced": 0.85,
			"fences": {"stone": 1.0, "hedge": 0.7}, "gate": Vector2(80, 120), "bales": Vector2i(2, 4)},
		"yard": {"lit_most": 3, "things": [
			{"kind": "lantern", "models": ["farm_lantern"], "count": 5, "where": "track", "lit": 0.5},
			{"kind": "well", "models": ["farm_well_1"], "count": 1},
			{"kind": "logs", "models": ["farm_logs_1"], "count": 3},
			{"kind": "lumber", "models": ["farm_logs_2"], "count": 2, "turn": "square"},
			{"kind": "trough", "models": ["farm_trough"], "count": 2, "turn": "square"},
			{"kind": "wagon", "models": ["farm_wagon"], "count": 2, "turn": "square"},
			{"kind": "barrow", "models": ["farm_barrow"], "count": 2, "turn": "square"}],
			"groves": [{"kind": "fruit", "models": ["farm_fruit_1", "farm_fruit_2", "farm_fruit_3"], "count": 1,
				"rows": Vector2i(2, 3), "cols": Vector2i(3, 4), "gap": 105.0, "jitter": 8.0}]},
		# (user request: its sheep in the pastures, a calf or two - tools/make_farm_animals.py)
		"animal_count": 3,
		"animals": {"sheep": 1.6, "calf": 0.6, "deer": 0.6, "fox": 0.8},
		"shore": {"grass": 0.06, "shrub": 0.04, "pebbles": 0.04},
		"shore_extras": {"reeds": 0.14, "lilypad": 0.04, "driftwood": 0.03},
		"water": {"base": Color(0.1, 0.2, 0.17), "deep": Color(0.035, 0.09, 0.08)},
	},
	# User request ("開始做中國風第 11 章"): the Chinese village - laid out as the other villages are
	# ("farm", "yard"): its grey stone houses about their yards, a red pavilion or the two-storey
	# pavilion across from them, the temple hall its landmark (the user's uploads, made ours -
	# tools/make_china_assets.py); vegetable plots behind white walls under dark tiles (Fence's
	# "tile_wall"); flagstone lanes (RunView3D's "floor3d") out to the map's edge, red lantern posts
	# along them (a few lit at night); stone garden lanterns, water jars, stone tables and wells by the
	# houses; bamboo groves; willows by the water (MapTree's "china"). Deer and foxes about.
	"china": {
		"look": "detailed",
		# (user request: a bridge to walk over the water - Dock.setup_bridge, its build)
		"bridge": "stone",
		# (user request: a river across the map, broad and slow - _generate_river)
		"river": {"half": Vector2(100.0, 125.0), "wind": 0.1, "bends": Vector2(1200.0, 1700.0)},
		# (user request: old, of its years - stained walls, moss on the tiles: CityBuild.aged; mine for now)
		"aged": {"age": 0.85, "moss": 0.45, "rust": 0.0},
		"floor": ["grass", "grass", 0.3],
		"floor3d": {"grass": "grass", "forest": "moss_soil", "path": "flagstone", "stone": "furrow", "mud": "mud"},
		"trees": 16, "rocks": 3, "bushes": 4, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"farm": {"steads": 3, "landmark": "cn_hall", "houses": ["cn_house"], "barns": ["cn_pavilion", "cn_house", "cn_pavilion"],
			"extras": ["cn_pavilion", "cn_tower"], "extra": Vector2i(0, 1),
			"scale": Vector2(0.85, 1.0), "yard": 160.0, "water_gap": 70.0,
			"fields": 3, "field_min": Vector2(300, 220), "field_max": Vector2(620, 420),
			"crops": {"greens": 1.0, "plough": 0.7}, "fenced": 0.8, "fences": {"tile_wall": 1.0, "bamboo": 0.3},
			"gate": Vector2(80, 120), "bales": Vector2i(0, 0)},
		"yard": {"lit_most": 4, "things": [
			{"kind": "lantern", "models": ["cn_red_lantern"], "count": 7, "where": "track", "lit": 0.6, "size": Vector2(8, 0)},
			{"kind": "lamp", "models": ["cn_lamp_1", "cn_lamp_2", "cn_lamp_3", "cn_lamp_4"], "count": 4, "lit": 0.4, "size": Vector2(14, 0)},
			{"kind": "jar", "models": ["cn_jar"], "count": 4, "where": "building", "size": Vector2(15, 0)},
			{"kind": "table", "models": ["cn_table"], "count": 2, "where": "yard", "size": Vector2(26, 0)},
			{"kind": "well", "models": ["cn_well"], "count": 1, "size": Vector2(20, 0)}],
			"groves": [CHINA_BAMBOO]},
		"animal_count": 2,
		"animals": {"chicken": 1.2, "rooster": 0.4, "crow": 0.4, "deer": 0.6, "fox": 0.6},
		"shore": {"grass": 0.06, "shrub": 0.04, "pebbles": 0.04},
		"shore_extras": {"reeds": 0.12, "lilypad": 0.14, "driftwood": 0.0},
		# (the willows by the water: half the trees, their trunks this far from the shore (px) -
		# their hanging leaves over the bank, high over the rod; the rest out away from it)
		"oasis_trees": 0.5,
		"oasis_band": [70.0, 240.0],
		"water": {"base": Color(0.1, 0.23, 0.2), "deep": Color(0.035, 0.1, 0.09)},
	},
	# User request (the tribal theme dropped - "換成土屋主題"): the adobe village by its oasis waters - laid
	# out as the other villages are ("farm", "yard"): its mud-brick houses about their yards (the
	# user's Egyptian houses, made ours - tools/make_adobe_assets.py: earthen or lime-washed), now and
	# then a shade of palm fronds or a bread oven beside them, the tallest house its landmark; wheat
	# fields behind low mud walls (Fence's "mud_wall"); dirt lanes out to the map's edge with
	# lantern posts; water jars, pots, ovens and wells about the yards; date palms thick by the water
	# ("oasis_trees", as the desert's), dead trees and a palm or two out on the sand (MapTree's
	# OPEN_KINDS). Camels, chickens and crows about.
	"adobe": {
		"look": "detailed",
		# (user request: a bridge to walk over the water - Dock.setup_bridge, its build)
		"bridge": "wood",
		# (user request: a great broad river across the map, its Nile - _generate_river)
		"river": {"half": Vector2(150.0, 180.0), "wind": 0.07, "bends": Vector2(1500.0, 2200.0)},
		# (user request: old, of its years - sun-faded mud brick, dust up from the ground:
		# CityBuild.aged; mine for now)
		"aged": {"age": 0.75, "moss": 0.0, "rust": 0.0, "grime": Color(0.5, 0.4, 0.28), "fade_to": Color(0.58, 0.47, 0.34)},
		"floor": ["dune_sand", "oasis_grass", 0.3],
		"floor3d": {"grass": "dune_sand", "forest": "oasis_grass", "path": "dirt", "stone": "furrow", "mud": "wet_sand"},
		"trees": 16, "rocks": 3, "bushes": 3, "ground": 0,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"farm": {"steads": 3, "landmark": "adb_house_9", "houses": ["adb_house_1", "adb_house_2", "adb_house_4", "adb_house_5", "adb_house_7"],
			"barns": ["adb_house_3", "adb_house_6", "adb_house_8", "adb_house_2"],
			"extras": ["adb_shade", "adb_oven"], "extra": Vector2i(0, 2),
			"scale": Vector2(0.95, 1.05), "yard": 150.0, "water_gap": 70.0,
			"fields": 4, "field_min": Vector2(300, 220), "field_max": Vector2(640, 440),
			# (user report: vegetable plots only in the countryside and the Chinese village - its wheat
			# after the harvest and turned earth by the water here)
			"crops": {"stubble": 1.0, "plough": 0.8}, "fenced": 0.75, "fences": {"mud_wall": 1.0},
			"gate": Vector2(80, 120), "bales": Vector2i(0, 2)},
		"yard": {"lit_most": 3, "things": [
			{"kind": "lantern", "models": ["farm_lantern"], "count": 5, "where": "track", "lit": 0.5},
			{"kind": "jar", "models": ["adb_jar"], "count": 5, "where": "building", "size": Vector2(12, 0)},
			{"kind": "pots", "models": ["adb_pots"], "count": 3, "where": "building", "size": Vector2(16, 0)},
			{"kind": "oven", "models": ["adb_oven"], "count": 2, "where": "yard", "size": Vector2(24, 0)},
			{"kind": "well", "models": ["adb_well"], "count": 1, "size": Vector2(22, 0)}],
			"groves": []},
		"animal_count": 2,
		"animals": {"camel": 0.8, "chicken": 1.2, "rooster": 0.4, "crow": 0.5, "fox": 0.3},
		"shore": {"grass": 0.05, "shrub": 0.03, "pebbles": 0.04},
		"shore_extras": {"reeds": 0.18, "lilypad": 0.04, "driftwood": 0.0},
		# (dry land: the green and its grass only by the water - RunView3D's _dry_farm)
		"oasis_meadow": true,
		# (the date palms by the water: most of the trees, their trunks this far from the shore (px))
		"oasis_trees": 0.7,
		"oasis_band": [24.0, 230.0],
		"water": {"base": Color(0.13, 0.22, 0.16), "deep": Color(0.05, 0.1, 0.07)},
	},}
## User feedback: the water's edge is grass, small shrubs, pebbles and
## boardwalks (no big trees or boulders there), with bugs and frogs about.
## Per shore sample: chance of a grass clump / low shrub / pebbles.
const SHORE_ODDS := {"grass": 0.0, "shrub": 0.0, "pebbles": 0.0}
## User request (water plants): per shore sample, on top of the above - a
## reed clump at the waterline, lily pads out on the water, a washed-up
## log. Themes override with "shore_extras".
const SHORE_EXTRAS := {"reeds": 0.0, "lilypad": 0.05, "driftwood": 0.0}
const SHORE_HIDE_BUSH_CHANCE := 0.25  # of shrubs: a bush you can hide in
const SHORE_CRITTERS := ["frog", "frog", "spider", "wasp"]
## (the room kept round one where it starts, px - the biggest of them, a snake's body)
const SHORE_CRITTER_ROOM := 18.0
const SHORE_CRITTER_COUNT := 5

const SHORE_SPACING := 26.0
const SHORE_CLEAR_OF_SPAWN := 160.0


var theme_name := ""
var theme: Dictionary = {}
## Which map edge a "sea" theme's sea lies along (and the 3D view's: its open water beyond it).
static var sea_side := Vector2.ZERO
var _walk_rects: Array[Rect2] = []
## Just outside each walkway's way on - kept clear of trees and rocks.
var _entrances: Array[Vector2] = []
const ENTRANCE_CLEARANCE := 60.0
const CRITTER_SCENE := preload("res://scenes/critter.tscn")
## User decision: 6 catchable critters by day, more come out at night.
const CRITTER_COUNT := 6
const NIGHT_CRITTER_COUNT := 6
## (user report: too many wolves - a level's own beasts at this share of
## their weight)
const BEAST_SHARE := 0.5
## User decision: ambient animals follow the map style, ~8 per map.
const AMBIENT_ANIMAL_COUNT := 8

var water_zones: Array = []


func _ready() -> void:
	# (the level's, or the free run's pick; the lakeside pine forest else)
	var pick := str(Campaign.rules.get("theme", ""))
	theme_name = pick if THEMES.has(pick) else THEME
	current_theme = theme_name
	var seasons := MapTree.seasons_of(theme_name)
	current_season = str(Campaign.rules.get("season", ""))
	if not current_season in seasons:
		current_season = str(seasons[randi() % seasons.size()]) if not seasons.is_empty() else ""
	theme = THEMES[theme_name].duplicate(true)
	# (user request - the maps' branches: a level's own changes to its map - its trees, animals,
	# shore life and the like - over the style's)
	var mods: Dictionary = Campaign.rules.get("mods", {})
	theme.merge(mods.duplicate(true), true)
	# (the countryside's farms and yards: a level changes only what it names of them - its fences, its
	# crops, its orchards - the rest the style's)
	for key: String in ["farm", "yard"]:
		if mods.has(key) and (THEMES[theme_name] as Dictionary).has(key):
			var whole: Dictionary = (THEMES[theme_name][key] as Dictionary).duplicate(true)
			whole.merge((mods[key] as Dictionary).duplicate(true), true)
			theme[key] = whole
	_fit_theme()
	# User request (the campaign): maps of three sizes - the floor, the
	# camp and the player's start go where this one's middle is.
	var ground: CanvasItem = get_parent().get_node_or_null("GroundBackground")
	if ground is Control:
		ground.size = Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT)
	for start in ["Player", "FuelStation"]:
		var node: Node2D = get_parent().get_node_or_null(start)
		if node != null:
			node.position = SPAWN_POS
	if ground != null:
		ground.material = _ground_material()
	var darkness := get_parent().get_node_or_null("Darkness")
	if darkness != null and "tint" in darkness:
		darkness.tint = theme.get("tint", Color.WHITE)
	WaterZone.theme_water = theme.get("water", {})
	FishData.waters = FishData.waters_for_theme(theme_name)
	GameState.night_fell.connect(_on_night_fell)
	# (the last map's tracks gone before anything's laid against them - the river's bridges are)
	farm_tracks = []
	_generate_water_zones()
	_place_docks()
	_place_altar_and_escape()
	_take_fixed_points()
	# (the river's bridges before the village: the ways over it, which the houses, fields and walls
	# keep clear of)
	_place_river_bridges()
	_place_ruins()
	_place_street_props()
	_place_farms()
	# (the bridge after the village: it fits round the houses, the fields and their walls, not they
	# round it - a small map keeps its farm)
	_place_bridges()
	_place_fossils()
	if theme.get("cliff", false):
		_place_coast_rocks()
	# Docks and shores before the trees and rocks, so those can keep clear
	# of every walkway entrance.
	_dress_shores()
	_scatter_props()
	_scatter_themed_props()
	_scatter_flip_rocks()
	# (once the trees are in - they go in deferred)
	_scatter_mushrooms.call_deferred()
	_scatter_oxy_trees.call_deferred()
	_scatter_frost_flowers.call_deferred()
	_scatter_ground_cover()
	_scatter_critters()


## A smaller map (the campaign's) gets fewer trees, rocks, plants and
## animals, so it's as thick with them as the full one; a level without
## beasts has none of the hunters, and one may bring its own (rules.beasts).
func _fit_theme() -> void:
	var share := Campaign.area_share()
	for key in ["trees", "rocks", "bushes", "ground"]:
		theme[key] = int(roundf(float(theme.get(key, 0)) * share))
	theme["animal_count"] = maxi(2, int(roundf(float(theme.get("animal_count", AMBIENT_ANIMAL_COUNT)) * share)))
	# (a style with no animals of its own - the seaside: none of the forest's - only a level's own
	# beasts)
	if theme.animals.is_empty() and Campaign.rules.beasts.is_empty():
		theme["animal_count"] = 0
		return
	var animals: Dictionary = theme.animals.duplicate()
	if not Campaign.rules.hunters:
		for kind in animals.keys():
			if Critter.SPECIES.get(kind, {}).has("chase_speed"):
				animals.erase(kind)
	var beasts: Dictionary = Campaign.rules.beasts
	var kin: Dictionary = theme.get("beast_kin", {})
	for kind in beasts:
		var own: String = kin.get(kind, kind)
		animals[own] = float(animals.get(own, 0.0)) + float(beasts[kind]) * BEAST_SHARE
	if animals.is_empty():
		animals = {"fox": 1.0, "deer": 1.0}
	theme["animals"] = animals


## User request: the ground itself follows the style - "floor" is
## [texture A, texture B, share of B] from assets/sprites/ground (made by
## tools/make_ground.py), blended by shaders/ground.gdshader.
func _ground_material() -> ShaderMaterial:
	var spec: Array = theme.floor
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	for slot in [["a", spec[0]], ["b", spec[1]]]:
		mat.set_shader_parameter("albedo_" + slot[0], load("res://assets/sprites/ground/%s_albedo.png" % slot[1]))
		mat.set_shader_parameter("normal_" + slot[0], load("res://assets/sprites/ground/%s_normal.png" % slot[1]))
	mat.set_shader_parameter("blend_b", spec[2])
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var macro := NoiseTexture2D.new()
	macro.width = 256
	macro.height = 256
	macro.seamless = true
	macro.noise = noise
	mat.set_shader_parameter("macro", macro)
	return mat



func _generate_water_zones() -> void:
	WaterZone.sea_backing = []
	sea_side = Vector2.ZERO
	if theme.get("sea", false):
		_generate_sea()
	# (a river first: the biggest thing, right across the map - the ponds keep clear of it)
	_generate_river()
	# The rare one first: it's smaller and solid, so it gets its pick.
	var ponds: Array = Campaign.rules.ponds
	var k := _pond_scale()
	for _i in range(int(ponds[1])):
		_spawn_zone(WaterZone.ZoneType.RARE, randf_range(RARE_RADIUS_MIN, RARE_RADIUS_MAX) * k, RARE_EXTRA_LOBES)
	# (by the sea: the sea is the common water - no ponds besides the rare one, a pool among the
	# rocks)
	if theme.get("sea", false):
		return
	var commons := int(ponds[0])
	if commons < 0:
		commons = randi_range(COMMON_ZONE_COUNT.x, COMMON_ZONE_COUNT.y)
	if not river_zones.is_empty():
		commons = river_ponds(commons)
	for _i in range(commons):
		_spawn_zone(WaterZone.ZoneType.COMMON, randf_range(COMMON_RADIUS_MIN, COMMON_RADIUS_MAX) * k, COMMON_EXTRA_LOBES)


## Ponds (and the room kept round the start) shrink a little on a smaller
## map (the campaign's), so they fit with land to walk round them.
static func _pond_scale() -> float:
	var k := sqrt(Campaign.area_share())
	# (the 3D run's bigger map: its ponds bigger with it)
	return k if k > 1.0 else clampf(k, 0.72, 1.0)


## User request (the seaside): the water is the sea - one great sweep of it along one side of the
## map, any side (up, down, left or right on the screen), a good third of the view, its coast one
## long wavy line. Made of big common zones in a row along that edge, reaching off the map,
## overlapping so their shores merge (and baked coarser); the open sea beyond them one huge circle
## (WaterZone.sea_backing - the 3D view's sea reaches the horizon). (From the old 2D beach maps.)
func _generate_sea() -> void:
	var w := Player.WORLD_WIDTH
	var h := Player.WORLD_HEIGHT
	sea_side = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT].pick_random()
	var across := sea_side.y != 0.0  # the coast runs across the map
	var length := w if across else h
	# How far in from the edge the water comes (the cliff's sea narrower: "sea_reach"), and how far it
	# keeps from the camp ("sea_clear").
	var share: Vector2 = theme.get("sea_reach", SEA_REACH)
	var clear: float = theme.get("sea_clear", SPAWN_CLEAR_RADIUS)
	var reach := randf_range(share.x, share.y) * (h if across else w)
	var r := maxf(SEA_RADIUS, reach * 0.62)
	var n := int(ceil(length / (r * 1.3))) + 1
	# The open sea behind the coast: one huge circle whose edge runs along the band every zone's
	# water surely covers.
	var edge_mid := Vector2(w, h) / 2.0 + sea_side * ((h if across else w) / 2.0)
	var backing := edge_mid - sea_side * (reach - 0.45 * r) + sea_side * SEA_BACKING_RADIUS
	WaterZone.sea_backing = [Vector3(backing.x, backing.y, SEA_BACKING_RADIUS)]
	for i in n:
		var t := (float(i) + randf_range(-0.15, 0.15)) * length / float(n - 1)
		var inland := reach - r + randf_range(-SEA_WOBBLE, SEA_WOBBLE)
		var pos: Vector2
		match sea_side:
			Vector2.DOWN: pos = Vector2(t, h - inland)
			Vector2.UP: pos = Vector2(t, inland)
			Vector2.LEFT: pos = Vector2(inland, t)
			_: pos = Vector2(w - inland, t)
		# Near the spawn point the sea draws back (a bay) rather than leave a gap in the coast.
		for _step in 40:
			if pos.distance_to(SPAWN_POS) - r >= clear:
				break
			pos += sea_side * 40.0
		# Lobes for a ragged coast - none reaching up to the spawn point.
		var lobes: Array[Vector3] = []
		for lobe in _make_lobes(r, SEA_LOBES):
			if (pos + Vector2(lobe.x, lobe.y)).distance_to(SPAWN_POS) - lobe.z >= clear:
				lobes.append(lobe)
		var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
		zone.field_texel = SEA_FIELD_TEXEL
		zone.sea = true
		zone.setup(WaterZone.ZoneType.COMMON, r, pos, lobes)
		get_parent().add_child.call_deferred(zone)
		water_zones.append(zone)


## Lobes spread around the main circle, overlapping it, for a wobbly shore.
func _make_lobes(radius: float, count_range: Vector2i) -> Array[Vector3]:
	var lobes: Array[Vector3] = []
	var n := randi_range(count_range.x, count_range.y)
	var base := randf() * TAU
	for k in n:
		var a := base + (k + randf_range(-0.25, 0.25)) / n * TAU
		var dist := radius * randf_range(0.55, 0.85)
		var r := radius * randf_range(0.45, 0.72)
		lobes.append(Vector3(cos(a) * dist, sin(a) * dist, r))
	return lobes


## User request ("是不是該把地圖也加入河流元素，把地圖用河流水域切割，這樣橋體的必要性就很高"; "河流依照你的
## 建議"): a style with "river" has a water running right across its map, edge to edge, splitting it
## in two - the countryside's and the Japanese, English and Chinese villages' a winding river, the
## adobe village's a great broad one (its Nile), the city's a canal: straight, a jog now and then
## (CANAL_JOG), its banks even (WaterZone.smooth - walled in RunView3D). Left to right or top to
## bottom, wherever there's room for it clear of the camp (SPAWN_CLEAR_RADIUS and RIVER_CAMP_GAP
## more) with land enough beyond it (RIVER_FAR_SIDE of the map across) - a wider room likelier;
## half as wide as "half" (px - with the ponds' size on a bigger map, _pond_scale), a little wider
## and narrower along it; winding "wind" of the map across (less where there's less room), its
## bends "bends" px long. Made as the sea is, of common zones in a row: each a stretch of
## RIVER_LOBES lobes along its middle, RIVER_SPACING of its half width apart, the next overlapping
## it by RIVER_SHARE, running on RIVER_OVER px past the map's edges (out under the land's frame).
const RIVER_OVER := 520.0
const RIVER_FAR_SIDE := 0.12
const RIVER_CAMP_GAP := 40.0
const RIVER_LOBES := 9
const RIVER_SHARE := 2
const RIVER_SPACING := 0.45
const RIVER_FIELD_TEXEL := 2.0
const CANAL_JOG := 0.5
## (the shore's creatures on a river's bank this far (px) in from the map's edge at least)
const RIVER_CRITTER_IN := 160.0
## (the share of a map's ponds a river stands for - see river_ponds)
const RIVER_PONDS := 1.0 / 3.0


## How many ponds a map whose level asks for `asked` has with its river: the river a big water, it
## stands for a third of them (rounded up), at least one left - or the village has no room left
## round it, the river and the ponds (its farms crowded in by the camp, their tracks shut in).
static func river_ponds(asked: int) -> int:
	return maxi(asked - ceili(asked * RIVER_PONDS), 1)
const CANAL_JOG_LEAST := 160.0
## The river's middle line and its half width along it (px), which way it runs (RIGHT: across the
## map, DOWN: top to bottom; ZERO: no river) and whether it's a canal.
static var river_line := PackedVector2Array()
static var river_half := PackedFloat32Array()
static var river_axis := Vector2.ZERO
static var river_canal := false
var river_zones: Array = []


func _generate_river() -> void:
	river_line = PackedVector2Array()
	river_half = PackedFloat32Array()
	river_axis = Vector2.ZERO
	river_canal = false
	river_zones = []
	var spec: Dictionary = theme.get("river", {})
	if spec.is_empty():
		return
	var k := _pond_scale()
	var halves: Vector2 = spec.half * k
	var canal := bool(spec.get("canal", false))
	var room := halves.y * (1.0 if canal else 1.12) + WaterZone.SHORE_BLEND * 0.25 \
		+ (0.0 if canal else WaterZone.WARP_AMP_A + WaterZone.WARP_AMP_B)
	var near := SPAWN_CLEAR_RADIUS * k + room + RIVER_CAMP_GAP
	# (each way it could run, and the bands across the map its middle may keep within - one each side
	# of the camp)
	var ways := []
	var total := 0.0
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		var across := Player.WORLD_HEIGHT if axis == Vector2.RIGHT else Player.WORLD_WIDTH
		var me := SPAWN_POS.y if axis == Vector2.RIGHT else SPAWN_POS.x
		var edge := across * RIVER_FAR_SIDE + room
		for band: Vector2 in [Vector2(edge, me - near), Vector2(me + near, across - edge)]:
			if band.y > band.x:
				ways.append([axis, band, across])
				total += band.y - band.x
	if ways.is_empty():
		return
	var roll := randf() * total
	var way: Array = ways[-1]
	for w: Array in ways:
		roll -= (w[1] as Vector2).y - (w[1] as Vector2).x
		if roll <= 0.0:
			way = w
			break
	var axis: Vector2 = way[0]
	var band: Vector2 = way[1]
	var along := Player.WORLD_WIDTH if axis == Vector2.RIGHT else Player.WORLD_HEIGHT
	var wind := 0.0 if canal else minf(float(spec.get("wind", 0.1)) * float(way[2]), (band.y - band.x) * 0.5)
	var base := randf_range(band.x + wind, band.y - wind)
	var bends: Vector2 = spec.get("bends", Vector2(1200.0, 1600.0)) * k
	var long1 := randf_range(bends.x, bends.y)
	var long2 := long1 * randf_range(0.32, 0.42)
	var phases := [randf() * TAU, randf() * TAU, randf() * TAU]
	var half := randf_range(halves.x, halves.y)
	var jog := 0.0
	var jog_at := 0.0
	if canal and randf() < CANAL_JOG:
		var to := randf_range(band.x, band.y)
		if absf(to - base) >= CANAL_JOG_LEAST:
			jog = to - base
			jog_at = randf_range(along * 0.25, along * 0.75 - absf(jog))
	var t := -RIVER_OVER
	while t <= along + RIVER_OVER:
		var c := base
		if jog != 0.0:
			c += jog * clampf((t - jog_at) / absf(jog), 0.0, 1.0)
		elif not canal:
			c += wind * (0.7 * sin(TAU * t / long1 + phases[0]) + 0.3 * sin(TAU * t / long2 + phases[1]))
		river_line.append(Vector2(t, c) if axis == Vector2.RIGHT else Vector2(c, t))
		river_half.append(half if canal else half * (1.0 + 0.12 * sin(TAU * t / (long1 * 0.6) + phases[2])))
		t += halves.x * RIVER_SPACING
	river_axis = axis
	river_canal = canal
	# The zones: RIVER_LOBES points of it each, the next starting RIVER_SHARE back.
	var i := 0
	while i < river_line.size() - 1:
		var j := mini(i + RIVER_LOBES, river_line.size())
		var mid := (i + j - 1) / 2
		var origin := river_line[mid]
		var lobes: Array[Vector3] = []
		for q in range(i, j):
			if q != mid:
				var off := river_line[q] - origin
				lobes.append(Vector3(off.x, off.y, river_half[q]))
		var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
		zone.river = true
		zone.smooth = canal
		zone.field_texel = RIVER_FIELD_TEXEL
		zone.setup(WaterZone.ZoneType.COMMON, river_half[mid], origin, lobes)
		get_parent().add_child.call_deferred(zone)
		water_zones.append(zone)
		river_zones.append(zone)
		if j >= river_line.size():
			break
		i = j - RIVER_SHARE
	for zone: WaterZone in river_zones:
		zone.joined = river_zones.filter(func(z): return z != zone)


## Whether `p` is in the river.
func _in_river(p: Vector2) -> bool:
	for zone: WaterZone in river_zones:
		if zone.contains(p):
			return true
	return false


## Where a line from `c` (in the river) along `dir` reaches its bank: the last point in it.
func _river_end(c: Vector2, dir: Vector2) -> Vector2:
	var p := c
	for _i in 400:
		if not _in_river(p + dir * 4.0):
			return p
		p += dir * 4.0
	return p


## Tries for a pond that doesn't fit, each 0.85 the size of the last (the last about half the size).
const POND_SHRINKS := 5


func _spawn_zone(type: int, radius: float, lobe_range: Vector2i) -> void:
	var lobes := _make_lobes(radius, lobe_range)
	# User bug report: the spawn point ended up under water (about 1 map in
	# 25) - when no spot was found, the last random one was used anyway. Now
	# a pond that doesn't fit shrinks and tries again, and is left out if it
	# still doesn't. (A smaller map with five ponds - the countryside's and the Chinese town's third branches - now and then
	# had no room for its last one even at 0.85^2 its size and went a pond
	# short of its rules - so it shrinks further first, POND_SHRINKS times.)
	var pos := Vector2.INF
	for _shrink in POND_SHRINKS:
		var bounds := radius
		for lobe in lobes:
			bounds = maxf(bounds, Vector2(lobe.x, lobe.y).length() + lobe.z)
		pos = _pick_zone_position(bounds)
		if pos != Vector2.INF:
			break
		radius *= 0.85
		for k in lobes.size():
			lobes[k] = Vector3(lobes[k].x * 0.85, lobes[k].y * 0.85, lobes[k].z * 0.85)
	if pos == Vector2.INF:
		return
	var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
	# Main is still mid-instantiation while this whole scene's _ready() chain
	# is running (map_generator is a static child of it) - add_child() on it
	# here fails outright ("Parent node is busy setting up children"), so
	# this has to be deferred. setup() only touches the zone's own already-
	# instantiated children, so it's safe to call before the zone is in the
	# tree at all.
	zone.setup(type, radius, pos, lobes)
	get_parent().add_child.call_deferred(zone)
	water_zones.append(zone)


## User request: docks out into a few common zones, some with stairs off
## the water end and some with a rowboat moored alongside. Each picks one of
## the four directions whose shore point (where a ray from the zone's origin
## leaves the water) is on open land - inside the map, not in another zone -
## and lays the dock across it, pointing back toward the zone's origin.
## Roughly how much water a zone holds (its lobes' areas, px²).
static func _zone_area(zone: WaterZone) -> float:
	var total := 0.0
	for l in zone.world_lobes():
		total += PI * l.z * l.z
	return total


func _place_docks() -> void:
	# (none off a sea cliff)
	if not theme.get("docks", true):
		return
	var commons: Array = water_zones.filter(func(z): return not z.is_rare())
	# (on a pond rather than out into the river, which has its bridges)
	var ponds := commons.filter(func(z): return not z.river)
	if not ponds.is_empty():
		commons = ponds
	# User request: one dock, on the biggest water - not one on every pond.
	commons.sort_custom(func(a, b): return _zone_area(a) > _zone_area(b))
	var jobs := commons.slice(0, 1)
	var used := {}
	for zone in jobs:
		var dirs := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
		dirs.shuffle()
		for d in dirs:
			if d in used.get(zone, []):
				continue
			var vertical: bool = d.x == 0.0
			var half: float = Dock.half_length(vertical)
			var edge: Vector2 = zone.shore_point(d)
			var shore: Vector2 = edge + d * half * 0.6
			if shore.x < DOCK_SHORE_MARGIN or shore.x > Player.WORLD_WIDTH - DOCK_SHORE_MARGIN \
					or shore.y < DOCK_SHORE_MARGIN or shore.y > Player.WORLD_HEIGHT - DOCK_SHORE_MARGIN:
				continue
			if _in_any_water(shore):
				continue
			# The water end must reach past the shallows, or the dock is pointless.
			if not zone.is_deep(edge - d * half * 1.4, 10.0):
				continue
			var dock: Dock = DOCK_SCENE.instantiate()
			# Shore end 30% of the length past the edge, the rest over water.
			dock.position = edge - d * half * 0.4
			var kind: String = ["long_rope", "long", "wide"].pick_random()
			dock.setup(vertical, kind)
			var stairs_too := randf() < DOCK_STAIRS_CHANCE
			# In from the land end only (and on through to the stairs).
			dock.add_walls([d, -d] if stairs_too else [d])
			_add_entrance(dock.walk_rect, d)
			get_parent().add_child.call_deferred(dock)
			_walk_rects.append(dock.walk_rect)
			if randf() < DOCK_BOAT_CHANCE:
				# Moored alongside the water half, bow out toward open water.
				var side := Vector2(d.y, -d.x) * (1.0 if randf() < 0.5 else -1.0)
				var boat: Dock = DOCK_SCENE.instantiate()
				boat.position = dock.position - d * half * 0.35 \
						+ side * (Dock.half_width(vertical, kind) + Dock.boat_half_beam(vertical) + 3.0)
				boat.setup_boat(_dir_name(-d))
				get_parent().add_child.call_deferred(boat)
			if stairs_too:
				# Steps off the water end, leading on toward the center.
				var stairs: Dock = DOCK_SCENE.instantiate()
				stairs.position = dock.position - d * (half + Dock.stairs_half_length(vertical))
				stairs.setup_stairs(_dir_name(-d))
				stairs.add_walls([d, -d])
				get_parent().add_child.call_deferred(stairs)
				_walk_rects.append(stairs.walk_rect)
			used.get_or_add(zone, []).append(d)
			break



## User request: "可以走上去的橋" - a bridge to walk over the water, bank to bank. Crossings straight
## across or up and down each common pond are tried from points in its water (the rare ones are
## solid and keep to themselves); one counts when its water's span is BRIDGE_SPAN, its middle is a
## waist's (BRIDGE_WAIST), its deck's whole width is over that one pond's water between the banks,
## and both banks are open dry land inside the map, clear of the dock and the village laid out
## before it (_bridge_fits). The narrowest such crossing gets the bridge (the most natural place for
## one); none if there's none - no bridge then. A bigger map gets more, each on a pond of its own.
func _place_bridges() -> void:
	var style := str(theme.get("bridge", ""))
	# (a map with a river: its bridges are the river's - _place_river_bridges)
	if style == "" or not river_zones.is_empty():
		return
	# (user decision: more than one to a map is fine - one a base map's area, never two on one pond)
	var count := clampi(roundi(Campaign.area_share()), 1, BRIDGE_MOST)
	var longest := BRIDGE_SPAN.y * clampf(_pond_scale(), 1.0, BRIDGE_SPAN_GROW)
	var bridged := []
	for _n in count:
		var best := []  # [span, from, to, zone]
		for zone in water_zones:
			if zone.is_rare() or zone in bridged or _zone_extent(zone) < BRIDGE_POND_MIN:
				continue
			for _try in BRIDGE_TRIES:
				var c: Vector2 = zone.random_point(12.0)
				var d: Vector2 = [Vector2.RIGHT, Vector2.DOWN].pick_random()
				var a := _water_end(zone, c, -d)
				var b := _water_end(zone, c, d)
				var span := a.distance_to(b)
				if span < BRIDGE_SPAN.x or span > longest:
					continue
				if not best.is_empty() and span >= float(best[0]):
					continue
				if zone.depth((a + b) * 0.5) < span * 0.5 * BRIDGE_WAIST:
					continue
				var from := a - d * BRIDGE_LAND
				var to := b + d * BRIDGE_LAND
				if _bridge_fits(zone.contains, a, b, from, to, d):
					best = [span, from, to, zone]
		if best.is_empty():
			return
		bridged.append(best[3])
		_lay_bridge(best[1], best[2], style)


## A bridge of `style` from `from` to `to`: on and off at either end only - rails along both sides.
func _lay_bridge(from: Vector2, to: Vector2, style: String) -> void:
	var dir := (to - from).normalized()
	var bridge: Dock = DOCK_SCENE.instantiate()
	bridge.setup_bridge(from, to, BRIDGE_HALF_WIDTH, style)
	bridge.add_walls([dir, -dir])
	_add_entrance(bridge.walk_rect, dir)
	_add_entrance(bridge.walk_rect, -dir)
	get_parent().add_child.call_deferred(bridge)
	_walk_rects.append(bridge.walk_rect)


## User request (the river - "這樣橋體的必要性就很高"): bridges across it, the only ways over (no one
## wades into a river: Player._too_deep) - one on a small map, two on a bigger one, three on the
## biggest (RIVER_BRIDGES: under these shares of the base map's area), each in its own stretch of
## the river along the map (RIVER_BRIDGE_END px in from the map's ends), straight across it (the
## bridges lie square to the map - over a river running left to right, up and down) where it's
## narrowest and nearest the middle of its stretch (RIVER_BRIDGE_MID px of span counted for each px
## off it), both banks open dry land clear of the camp, the altar, the way out and the dock. Laid
## before the village, which keeps clear of them and their ends. Its style the river's "bridge" (the
## city's concrete), else the map's.
const RIVER_BRIDGES := Vector2(1.0, 3.0)
const RIVER_BRIDGE_END := 280.0
const RIVER_BRIDGE_MID := 0.15


func _place_river_bridges() -> void:
	if river_zones.is_empty():
		return
	var style := str((theme.river as Dictionary).get("bridge", theme.get("bridge", "wood")))
	var share := Campaign.area_share()
	var count := 1 if share < RIVER_BRIDGES.x else (2 if share < RIVER_BRIDGES.y else 3)
	var d := Vector2.DOWN if river_axis == Vector2.RIGHT else Vector2.RIGHT
	var along := Player.WORLD_WIDTH if river_axis == Vector2.RIGHT else Player.WORLD_HEIGHT
	for part in count:
		var t0 := lerpf(RIVER_BRIDGE_END, along - RIVER_BRIDGE_END, float(part) / count)
		var t1 := lerpf(RIVER_BRIDGE_END, along - RIVER_BRIDGE_END, float(part + 1) / count)
		var best := []
		var least := INF
		for c in river_line:
			var at := c.dot(river_axis)
			if at < t0 or at > t1:
				continue
			# (out to where the water ends under both its sides too - where the river bends, its bank
			# runs slantwise under the deck's end)
			var near := 0.0
			var far := 0.0
			for s in [-1.0, 0.0, 1.0]:
				var on: Vector2 = c + d.orthogonal() * BRIDGE_HALF_WIDTH * s
				near = maxf(near, (on - _river_end(on, -d)).length())
				far = maxf(far, (_river_end(on, d) - on).length())
			var a := c - d * near
			var b := c + d * far
			var score := a.distance_to(b) + absf(at - (t0 + t1) * 0.5) * RIVER_BRIDGE_MID
			if score >= least:
				continue
			var from := a - d * BRIDGE_LAND
			var to := b + d * BRIDGE_LAND
			if _bridge_fits(_in_river, a, b, from, to, d):
				least = score
				best = [from, to]
		if not best.is_empty():
			_lay_bridge(best[0], best[1], style)


## How long a pond is at its longest (px): across its lobes' box.
static func _zone_extent(zone: WaterZone) -> float:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for l in zone.world_lobes():
		lo = lo.min(Vector2(l.x - l.z, l.y - l.z))
		hi = hi.max(Vector2(l.x + l.z, l.y + l.z))
	return maxf(hi.x - lo.x, hi.y - lo.y) if lo.is_finite() else 0.0


## Where a line from `c` (in `zone`'s water) along `dir` reaches the bank: the last point in it.
static func _water_end(zone: WaterZone, c: Vector2, dir: Vector2) -> Vector2:
	var p := c
	for _i in 200:
		if not zone.contains(p + dir * 4.0):
			return p
		p += dir * 4.0
	return p


## Whether a bridge from `from` to `to` (along `d`; its water from `a` to `b`) fits: the deck's
## sides over the water it crosses (`inside` - the pond's, the river's) along its middle (no spit
## of land under it), both banks dry open land inside the map (in no water, rare or common) where
## the ends rest and a little past, and the whole of it clear of the dock and its stairs.
func _bridge_fits(inside: Callable, a: Vector2, b: Vector2, from: Vector2, to: Vector2, d: Vector2) -> bool:
	var side := d.orthogonal() * BRIDGE_HALF_WIDTH
	var span := a.distance_to(b)
	# (its middle - at the banks, a slanting shore can come in under one side: its foot on the bank)
	var t := span * 0.15
	while t < span * 0.85:
		var q := a + d * t
		if not inside.call(q + side) or not inside.call(q - side):
			return false
		t += 8.0
	for end: Array in [[a, -d], [b, d]]:
		for k in int((BRIDGE_LAND + 40.0) / 8.0):
			var q: Vector2 = end[0] + end[1] * (8.0 + 8.0 * k)
			for s in [-1.0, 0.0, 1.0]:
				var qq: Vector2 = q + side * s
				if qq.x < DOCK_SHORE_MARGIN or qq.x > Player.WORLD_WIDTH - DOCK_SHORE_MARGIN \
						or qq.y < DOCK_SHORE_MARGIN or qq.y > Player.WORLD_HEIGHT - DOCK_SHORE_MARGIN:
					return false
				if _in_any_water(qq):
					return false
	var rect := Rect2(from, Vector2.ZERO).expand(to).grow(BRIDGE_HALF_WIDTH)
	for w in _walk_rects:
		if w.grow(40.0).intersects(rect):
			return false
	# (clear of the village laid out before it - its buildings, fields, tracks, walls and yard things,
	# the camp and the fixed points - and room to step on and off at both ends)
	for r in _ruins + _fields:
		if (r as Rect2).grow(20.0).intersects(rect):
			return false
	var ways := [from - d * 24.0, to + d * 24.0]
	for solid: Array in _taken:
		if _rect_distance(rect, solid[0]) < float(solid[1]) + 10.0:
			return false
		for e: Vector2 in ways:
			if e.distance_to(solid[0]) < float(solid[1]) + 24.0:
				return false
	for line in farm_tracks:
		for q in (line as PackedVector2Array):
			if _rect_distance(rect, q) < _track_half + 6.0:
				return false
	return not rect.grow(SPAWN_CLEAR_RADIUS * 0.3).has_point(SPAWN_POS)


func _dir_name(v: Vector2) -> String:
	if absf(v.x) < 0.5:
		return "down" if v.y > 0.0 else "up"
	return "right" if v.x > 0.0 else "left"


## A spot for a pond this big, clear of the spawn point and the other
## ponds; Vector2.INF if there's none.
func _pick_zone_position(radius: float) -> Vector2:
	for _try in range(60):
		var pos := Vector2(
			randf_range(ZONE_MARGIN + radius, Player.WORLD_WIDTH - ZONE_MARGIN - radius),
			randf_range(ZONE_MARGIN + radius, Player.WORLD_HEIGHT - ZONE_MARGIN - radius)
		)
		if pos.distance_to(SPAWN_POS) < SPAWN_CLEAR_RADIUS * _pond_scale() + radius:
			continue
		var overlaps := false
		for zone in water_zones:
			if pos.distance_to(zone.global_position) < radius + zone.radius + ZONE_MIN_GAP:
				# (a river's long stretch: kept that far from its bank, not from the stretch's middle)
				if zone.river and zone.depth(pos) < -(radius + ZONE_MIN_GAP):
					continue
				overlaps = true
				break
		if not overlaps:
			return pos
	return Vector2.INF


func _place_altar_and_escape() -> void:
	var altar: Node2D = get_parent().get_node("Altar")
	var escape_point: Node2D = get_parent().get_node("EscapePoint")

	altar.global_position = _pick_fixed_point_position([SPAWN_POS])
	escape_point.global_position = _pick_fixed_point_position([SPAWN_POS, altar.global_position])
	# User request: Willow, the harmless NPC, stands beside the altar; the
	# big ghost's cage is a fixed point of its own, away from the rest.
	var willow: Node2D = get_parent().get_node_or_null("Willow")
	if willow != null:
		willow.global_position = altar.global_position + Willow.FRONT
	var cage: Node2D = get_parent().get_node_or_null("GhostCage")
	if cage != null:
		cage.global_position = _pick_fixed_point_position([SPAWN_POS, altar.global_position, escape_point.global_position])


func _pick_fixed_point_position(avoid: Array) -> Vector2:
	# Clear of all water (a common pond's middle is too deep to wade) and
	# far from the other fixed points. If nothing meets both, the spot that
	# comes closest - never one at the water's edge (it used to take the
	# last random try, which could be in a pond).
	var best := Vector2(Player.WORLD_WIDTH * 0.5, FIXED_POINT_MARGIN)
	var best_score := -INF
	# Closer together on a smaller map (the campaign's).
	var separation := FIXED_POINT_MIN_SEPARATION * minf(1.0, sqrt(Campaign.area_share()))
	for _try in range(60):
		var pos := Vector2(
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_WIDTH - FIXED_POINT_MARGIN),
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_HEIGHT - FIXED_POINT_MARGIN)
		)
		var spread := INF
		for p in avoid:
			spread = minf(spread, pos.distance_to(p))
		var shore := _shore_distance(pos)
		# (on the sea cliff, down off its rise: "fixed_inland")
		var inland: float = theme.get("fixed_inland", 50.0)
		if spread >= separation and shore > inland:
			return pos
		var score := minf(spread / separation, 1.0) + (1.0 if shore > inland else -2.0)
		if score > best_score:
			best_score = score
			best = pos
	return best


## Distance to the nearest water (0 when inside it).
func _shore_distance(pos: Vector2) -> float:
	var best := INF
	for zone in water_zones:
		# (a zone surely further than the nearest so far - past its bounding radius by that - skipped:
		# a river is many)
		if pos.distance_to(zone.global_position) - zone.radius >= best:
			continue
		best = minf(best, zone.distance_to_edge(pos))
	return best


func _add_entrance(rect: Rect2, side: Vector2) -> void:
	var c := rect.get_center()
	_entrances.append(c + side * (absf(side.x) * rect.size.x + absf(side.y) * rect.size.y) * 0.5 + side * 20.0)


func _near_entrance(pos: Vector2, margin: float) -> bool:
	for e in _entrances:
		if e.distance_to(pos) < margin:
			return true
	return false


## How far up the bank a point is: negative in the water.
func _land_score(pos: Vector2) -> float:
	var d := _shore_distance(pos)
	return -d if _in_any_water(pos) else d


func _in_any_water(pos: Vector2) -> bool:
	for zone in water_zones:
		if zone.contains(pos):
			return true
	return false


func _scatter_props() -> void:
	for prop_name in PROP_NAMES:
		var prop: Node2D = get_parent().get_node_or_null(prop_name)
		if prop == null:
			continue
		# Scene props haven't run _ready yet (this node is Main's first
		# child), so the theme still decides what they become.
		_theme_prop(prop)
		var size := _footprint(prop)
		# (a style with "plant_band": the scene's bushes too only near the water - user request)
		var pos := _place_tree(prop) if prop is MapTree and theme.has("oasis_trees") \
			else (_by_water(size[0], size[1]) if str(prop.name).begins_with("Bush") and theme.has("plant_band")
			else _pick_prop_position(size[0], size[1]))
		if pos.x < 0.0:
			# (no room left that keeps clear of everything: not placed)
			prop.queue_free()
			continue
		size = _footprint(prop)
		prop.global_position = pos
		_taken.append([pos, size[0], size[1]])


## The camp, the altar (and the willow's walk round it), the rune stones
## and the big ghost's lair: kept clear by everything.
func _take_fixed_points() -> void:
	var camp := get_parent().get_node_or_null("FuelStation") as Node2D
	if camp != null:
		for b in FuelStation.solids_local():
			var r: Vector2 = b[1]
			var reach := maxf(r.x, r.y) * (1.0 if is_equal_approx(r.x, r.y) else 1.42)
			_taken.append([camp.global_position + b[0], reach, reach + 40.0])
		# (and the player's start, with room to turn round)
		_taken.append([camp.global_position, 30.0, 0.0])
	var altar := get_parent().get_node_or_null("Altar") as Node2D
	if altar != null:
		var walk: float = WILLOW_RING + 16.0
		_taken.append([altar.global_position, walk, walk])
	var escape := get_parent().get_node_or_null("EscapePoint") as Node2D
	if escape != null:
		_taken.append([escape.global_position, 50.0, 60.0])
	var cage := get_parent().get_node_or_null("GhostCage") as Node2D
	if cage != null:
		_taken.append([cage.global_position, 60.0, 60.0])


## A prop's [base radius, branch reach] (px), its kind already chosen.
func _footprint(prop: Node) -> Array:
	if prop is MapTree:
		var t := prop as MapTree
		if not t.picked:
			t.pick(randi())
		return [float(MapTree.KINDS[t.kind]) * t.tree_scale * MapTree.PX, MapTree.canopy_of(t.kind, t.tree_scale)]
	if prop is Obstacle:
		var biggest := 0.0
		for k in Obstacle.KINDS:
			biggest = maxf(biggest, maxf(k.base.x, k.base.y) * 0.5)
		return [biggest, 0.0]
	if prop is FlipRock:
		# (and where it rolls to when it's turned)
		return [Obstacle.KINDS[1].base.x * 0.5 * FlipRock.SIZE + FlipRock.ROLL_DISTANCE.y, 0.0]
	if "families" in prop:
		return [24.0, 0.0]
	return [20.0, 0.0]


## Everything solid placed so far: [centre, base radius, branch reach]
## (px; reach 0 for what has no branches). See _fits().
var _taken: Array = []


func _scatter_flip_rocks() -> void:
	var count: Array = Campaign.rules.rocks
	for _i in randi_range(int(count[0]), int(count[1])):
		var rock: Node2D = FLIP_ROCK_SCENE.instantiate()
		var size := _footprint(rock)
		var at := _pick_prop_position(size[0], size[1])
		if at.x < 0.0:
			rock.free()
			continue
		rock.position = at
		_taken.append([at, size[0], size[1]])
		# Small stones to turn over - not the standing slabs or the props.
		rock.variant_pool = theme.rock_pool.filter(func(e): return not (e is String and e in NOT_FLIPPABLE))
		get_parent().add_child.call_deferred(rock)


## User request: the glow mushrooms, only under trees - each at the foot of
## one (a few trees, picked at random), on dry ground clear of the docks'
## and shores' walkways and of every other thing's base.
func _scatter_mushrooms() -> void:
	var trees := get_tree().get_nodes_in_group("trees").filter(func(t): return t is MapTree and _inside_map(t.global_position, 40.0))
	trees.shuffle()
	# (a rare find: no more on a bigger map, fewer on a smaller one)
	var share := minf(Campaign.area_share(), 1.0)
	var want := maxi(1, roundi(randi_range(GlowMushroom.PER_MAP.x, GlowMushroom.PER_MAP.y) * share))
	var made := 0
	for t in trees:
		if made >= want:
			break
		var tree := t as MapTree
		for _try in 6:
			var a := randf() * TAU
			var at := tree.global_position + Vector2(cos(a), sin(a)) * (tree.trunk_radius + randf_range(GlowMushroom.FROM_TRUNK.x, GlowMushroom.FROM_TRUNK.y))
			if water_zones.any(func(z): return z.contains(at)) or _near_walkway(at, 20.0) or not _clear_of_bases(at, tree):
				continue
			var m := GlowMushroom.new()
			m.name = "GlowMushroom%d" % made
			m.position = at
			get_parent().add_child(m)
			made += 1
			break


## User request: the oxygen algae (OxyTree), in the shallows along the
## shores - a few to a map, off the docks' and walkways' way; never in the sea.
func _scatter_oxy_trees() -> void:
	var spots := []
	for z in water_zones:
		# (user report: none out in the sea - the sea's surface only its waves, and rocks here and
		# there; by the sea, in the rare pool)
		if (z as WaterZone).sea:
			continue
		for s in (z as WaterZone).shore_samples(60.0):
			spots.append([z, s[0], s[1]])
	spots.shuffle()
	var share := minf(Campaign.area_share(), 1.0)
	var want := maxi(1, roundi(randi_range(OxyTree.TREES_PER_MAP.x, OxyTree.TREES_PER_MAP.y) * share))
	var made := 0
	for sp in spots:
		if made >= want:
			break
		var zone: WaterZone = sp[0]
		var at: Vector2 = sp[1] - (sp[2] as Vector2) * randf_range(OxyTree.FROM_SHORE.x, OxyTree.FROM_SHORE.y)
		# (the shallows only: in, but not far in - the shore's curve can run it deeper than the step)
		if not zone.contains(at) or zone.depth(at) > OxyTree.FROM_SHORE.y + 4.0 or not _inside_map(at, 40.0) or _near_walkway(at, 20.0):
			continue
		var a := OxyTree.new()
		a.name = "OxyTree%d" % made
		a.position = at
		get_parent().add_child(a)
		# (never alone: shore grass grows about it - and a reed or two)
		for _k in randi_range(OxyTree.GRASS.x, OxyTree.GRASS.y):
			var off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(OxyTree.GRASS_NEAR.x, OxyTree.GRASS_NEAR.y)
			_add_ground_cover(at + off, "grass")
		for _k in randi_range(0, 2):
			_add_ground_cover(at + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(OxyTree.GRASS_NEAR.x, OxyTree.GRASS_NEAR.y), "reeds")
		made += 1


## User request: the frost flowers, only by the stones - each a little off one
## of the small stones (the ones that turn over), on dry ground clear of the
## walkways and of every other thing's base.
func _scatter_frost_flowers() -> void:
	var rocks := get_tree().get_nodes_in_group("solids").filter(func(n): return n is FlipRock and _inside_map(n.global_position, 40.0))
	rocks.shuffle()
	var share := minf(Campaign.area_share(), 1.0)
	var want := maxi(1, roundi(randi_range(FrostFlower.PER_MAP.x, FrostFlower.PER_MAP.y) * share))
	var made := 0
	for r in rocks:
		if made >= want:
			break
		var rock := r as FlipRock
		for _try in 8:
			var a := randf() * TAU
			var at := rock.global_position + Vector2(cos(a), sin(a)) * (rock.radius + randf_range(FrostFlower.FROM_ROCK.x, FrostFlower.FROM_ROCK.y))
			if water_zones.any(func(z): return z.contains(at) or z.distance_to_edge(at) < 30.0) or _near_walkway(at, 24.0) \
					or not _clear_of_bases(at, rock):
				continue
			var flower := FrostFlower.new()
			flower.name = "FrostFlower%d" % made
			flower.position = at
			get_parent().add_child(flower)
			made += 1
			break


## Whether `at` is off every solid thing's base but `tree`'s (a mushroom's
## room).
func _clear_of_bases(at: Vector2, tree: Node2D) -> bool:
	for entry in _taken:
		if (entry[0] as Vector2).distance_to(tree.global_position) < 1.0:
			continue
		if (entry[0] as Vector2).distance_to(at) < float(entry[1]) + 8.0:
			return false
	return true


func _theme_prop(prop: Node) -> void:
	if "family_weights" in prop:
		prop.family_weights = theme.tree_families
	elif "variant_pool" in prop:
		prop.variant_pool = theme.rock_pool
		prop.modulate = theme.get("rock_tint", Color.WHITE)
	elif "families" in prop:
		prop.families = theme.get("bush_families", [])


## The desert's bones, cacti and skulls (a style's "fossils" - Fossil kinds and how many a base
## map's area holds; the big bones one each): out on the open sand, kept from the water (the bones
## and the cacti well away - they're the dry desert's; a skull anywhere off the shore), the start
## and the camp, turned any way; before anything else is placed, so they get their room.
const FOSSIL_SHORE := {"dino": 90.0, "mammoth": 90.0, "elephant": 90.0, "crocodile": 70.0, "wildcat": 80.0,
	"saguaro": 120.0, "cholla": 90.0, "skull": 80.0, "bones": 80.0}
## The cacti are plants: (user request) only near the water - in the oasis's margin, no further out
## from a shore than this (px; the green reaches some 160-280) - nothing green out in the desert.
const FOSSIL_SHORE_MAX := {"saguaro": 300.0, "cholla": 270.0}


## User request (the ruined human world - the city, a style with "ruins"): its buildings along
## streets no longer kept. A grid of blocks, its streets "road" px wide, each block its own size
## (block_min..block_max) and the grid's start somewhere new each game, so no two maps are alike;
## each block split along its length into a few lots ("lots", "alley" px between them, set back
## from the street by up to "setback"), each a building - a shop, a block of flats - some blocks
## left empty ("vacant": weeds and trees), some buildings fallen to rubble ("fallen"); the biggest
## lot well away from the start the tall office block ("towers"), to find one's way by. None in
## the water or within "water_gap" px of it, on the camp, the altar, the way out or the cage, on a
## dock's way or by the start: a lot that won't fit shrinks, else is left empty. What's placed
## after keeps clear of them (_taken).
func _place_ruins() -> void:
	var spec: Dictionary = theme.get("ruins", {})
	if spec.is_empty():
		return
	# (a few layouts of the streets, the best kept - a small map, its start, its camp and its
	# water taking most of the room, may leave one few lots: at least RUIN_FEW a base map's area)
	var want := maxi(1, roundi(float(spec.get("few", RUIN_FEW)) * Campaign.area_share()))
	var best: Array = []
	for _try in RUIN_TRIES:
		var got := _ruin_layout(spec)
		if got.size() > best.size():
			best = got
		if best.size() >= want:
			break
	var towers := int(spec.get("towers", 0))
	var made := 0
	for entry in best:
		var rect: Rect2 = entry.rect
		var ruin := Ruin.new()
		ruin.name = "Ruin%d" % made
		if str(entry.get("model", "")) != "":
			ruin.kind = "model"
			ruin.model = entry.model
			ruin.model_yaw = entry.yaw
			ruin.model_scale = entry.scale
		elif towers > 0 and rect.get_center().distance_to(SPAWN_POS) > RUIN_TOWER_AWAY and rect.get_area() > RUIN_TOWER_AREA:
			ruin.kind = "tower"
			towers -= 1
		elif randf() < float(spec.fallen):
			ruin.kind = "rubble"
		else:
			ruin.kind = "flat" if rect.get_area() > RUIN_FLAT_AREA and randf() < 0.6 else "shop"
		var floors: Vector2i = Ruin.STOREYS[ruin.kind]
		ruin.storeys = randi_range(floors.x, floors.y)
		ruin.size = rect.size
		ruin.position = rect.get_center()
		ruin.seed_value = randi()
		# (a building's keep-clear circles - marked, so what stands by its walls asks its rectangle)
		for c in ruin.footprint_circles():
			_taken.append([c[0], c[1], c[1], true])
		_ruins.append(rect)
		get_parent().add_child.call_deferred(ruin)
		made += 1


## One layout of the streets: the buildings that fit, each {rect, model, yaw, scale} (model "" for
## a building of our own shapes) - a whole block one of the models now and then, else its lots
## (biggest first - the tower's pick).
func _ruin_layout(spec: Dictionary) -> Array:
	var road := float(spec.road)
	var lo: Vector2 = spec.block_min
	var hi: Vector2 = spec.block_max
	var lots := []
	var models := []
	for bx in _street_cuts(Player.WORLD_WIDTH, road, lo.x, hi.x):
		for by in _street_cuts(Player.WORLD_HEIGHT, road, lo.y, hi.y):
			if randf() < float(spec.vacant):
				continue
			var block := Rect2(bx.x, by.x, bx.y - bx.x, by.y - by.x)
			var whole := _model_on(block, spec)
			if not whole.is_empty():
				models.append(whole)
				continue
			var along_x := block.size.x >= block.size.y
			var length := block.size.x if along_x else block.size.y
			var alley := float(spec.alley)
			# (as many lots as asked, or as fit - each at least RUIN_LEAST)
			var most := maxi(1, int((length + alley) / (RUIN_LEAST + alley)))
			var n := mini(randi_range(int(spec.lots.x), int(spec.lots.y)), most)
			var each := (length - alley * float(n - 1)) / float(n)
			var at := 0.0
			for i in n:
				# (each lot its own share of the block, give or take)
				var cut := each * randf_range(0.8, 1.2) if i < n - 1 else length - at
				cut = clampf(cut, RUIN_LEAST, length - at)
				var lot := Rect2(block.position + (Vector2(at, 0.0) if along_x else Vector2(0.0, at)),
					Vector2(cut, block.size.y) if along_x else Vector2(block.size.x, cut))
				var back := float(spec.setback)
				lot = lot.grow_individual(-randf() * back, -randf() * back, -randf() * back, -randf() * back)
				if lot.size.x >= RUIN_LEAST and lot.size.y >= RUIN_LEAST:
					lots.append(lot)
				at += cut + alley
				if at >= length - RUIN_LEAST:
					break
	lots.sort_custom(func(a, b): return (a as Rect2).get_area() > (b as Rect2).get_area())
	var out := models.duplicate()
	for lot in lots:
		var fitted := _ruin_room(lot, float(spec.water_gap))
		if fitted.size != Vector2.ZERO:
			out.append({"rect": fitted, "model": ""})
	return out


## One of the models for a whole block (`spec` "models", "model_share" of the blocks): the one that
## fits it best (each turned either way, scaled to the block within Ruin.MODEL_SCALE), set somewhere
## in it, if it's clear there (as _ruin_room asks); {} if none.
func _model_on(block: Rect2, spec: Dictionary) -> Dictionary:
	var names: Array = spec.get("models", [])
	if names.is_empty() or randf() >= float(spec.get("model_share", 0.0)):
		return {}
	var room := block.grow(-float(spec.setback) * 0.5)
	var picks := []
	for name in names:
		if Ruin.info(str(name)).is_empty():
			continue
		for quarter in [0, 1]:
			var unit := Ruin.model_footprint(str(name), quarter * PI * 0.5, 1.0)
			var k := minf(room.size.x / unit.x, room.size.y / unit.y)
			k = minf(k, Ruin.MODEL_SCALE.y)
			if k >= Ruin.MODEL_SCALE.x:
				picks.append([str(name), quarter, k])
	picks.shuffle()
	for p in picks:
		# (turned its way, or the other way round - its back to the street sometimes)
		var yaw := float(p[1]) * PI * 0.5 + (PI if randf() < 0.5 else 0.0)
		var k := float(p[2])
		var size := Ruin.model_footprint(str(p[0]), yaw, k)
		var slack := room.size - size
		var rect := Rect2(room.position + Vector2(randf() * slack.x, randf() * slack.y), size)
		if _ruin_clear(rect, float(spec.water_gap)):
			return {"rect": rect, "model": p[0], "yaw": yaw, "scale": k}
	return {}


## User request (the city, a style with "street"): its cars and street lamps. A car by the kerb of
## some building's street (its pavement's width out from the wall, the road's edge), along it -
## or, now and then, slewed across the road, anywhere; a lamp at a pavement's outer edge. Each
## where it's clear (the water, the docks' ways, the start, everything placed); some lamps lit.
func _place_street_props() -> void:
	var spec: Dictionary = theme.get("street", {})
	if spec.is_empty() or _ruins.is_empty():
		return
	var share := Campaign.area_share()
	var walk := CityBuild.WALK * Fossil.PX
	var lit_left := int(spec.get("lit_most", 3))
	var made := 0
	for kind: String in ["car", "lamp", "drum", "crate", "bench"]:
		var key := "benches" if kind == "bench" else kind + "s"
		if float(spec.get(key, 0)) <= 0.0:
			continue
		var count := maxi(1, roundi(float(spec.get(key, 0)) * share))
		for _i in count:
			for _try in 30:
				var at := Vector2.INF
				var yaw := 0.0
				if (kind == "car" and randf() < float(spec.slewed)) or (kind != "car" and kind != "lamp" and randf() < 0.4):
					at = Vector2(randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN), randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN))
					yaw = randf() * TAU
				else:
					# (a side of some building: along it, out from it by the pavement - the kerb)
					var rect: Rect2 = _ruins.pick_random()
					var side := randi() % 4
					var t := randf_range(0.1, 0.9)
					var out := walk + (StreetProp.CAR.y * 0.5 + 8.0 if kind == "car" else (6.0 if kind == "lamp" else randf_range(-walk * 0.6, 10.0)))
					match side:
						0: at = Vector2(rect.position.x + rect.size.x * t, rect.position.y - out)
						1: at = Vector2(rect.end.x + out, rect.position.y + rect.size.y * t)
						2: at = Vector2(rect.position.x + rect.size.x * t, rect.end.y + out)
						_: at = Vector2(rect.position.x - out, rect.position.y + rect.size.y * t)
					yaw = (0.0 if side % 2 == 0 else PI * 0.5) + randf_range(-0.12, 0.12) + (PI if randf() < 0.5 else 0.0)
				var reach := StreetProp.reach_of(kind) + (0.0 if kind == "car" else 10.0)
				if at.x < PROP_MARGIN or at.y < PROP_MARGIN or at.x > Player.WORLD_WIDTH - PROP_MARGIN or at.y > Player.WORLD_HEIGHT - PROP_MARGIN:
					continue
				if at.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS or _shore_distance(at) < reach + 30.0 or _in_any_water(at):
					continue
				if _near_walkway(at, reach + 20.0) or _near_entrance(at, ENTRANCE_CLEARANCE):
					continue
				# (a street lamp's arm reaches out LAMP_ARM px along the wall: two lamps' arms kept apart)
				if not _fits_street(at, reach + (LAMP_ARM if kind == "lamp" else 0.0)) or _in_ruin(at, reach):
					continue
				var prop := StreetProp.new()
				prop.name = "StreetProp%d" % made
				prop.kind = kind
				prop.yaw = yaw
				prop.position = at
				prop.seed_value = randi()
				if kind == "lamp" and lit_left > 0 and randf() < float(spec.lit):
					prop.lit = true
					lit_left -= 1
				_taken.append([at, reach, 0.0])
				get_parent().add_child.call_deferred(prop)
				made += 1
				break


const LAMP_ARM := 45.0


## _fits for what stands in the street by the buildings' walls: clear of everything placed but the
## buildings' keep-clear circles (their rectangles are asked instead - _in_ruin).
func _fits_street(at: Vector2, base: float) -> bool:
	for t in _taken:
		if (t as Array).size() > 3:
			continue
		if at.distance_to(t[0]) < base + float(t[1]) + PROP_GAP * 0.5:
			return false
	return true


## Whether a thing (radius `r`, px) at `at` would stand in a building.
func _in_ruin(at: Vector2, r: float) -> bool:
	for rect in _ruins:
		if _rect_distance(rect, at) < r + 6.0:
			return true
	return false


## (the least buildings a base map's area - a style's or a level's "few" - and how many layouts are
## tried for them)
const RUIN_FEW := 6.0
const RUIN_TRIES := 6
## (a building's least side; a block of flats' least ground; the tower's - and how far from the
## start it stands)
const RUIN_LEAST := 150.0
const RUIN_FLAT_AREA := 90000.0
const RUIN_TOWER_AREA := 120000.0
const RUIN_TOWER_AWAY := 600.0
## The buildings placed (their rectangles, px).
var _ruins: Array = []


## The blocks along one side of the map ([start, end] px each): each its own length, the streets
## between them `road` wide, the first starting somewhere off the map's edge.
static func _street_cuts(length: float, road: float, least: float, most: float) -> Array:
	var out := []
	var at := -randf_range(0.0, most * 0.5)
	while at < length:
		var size := randf_range(least, most)
		var a := maxf(at, PROP_MARGIN)
		var b := minf(at + size, length - PROP_MARGIN)
		if b - a >= RUIN_LEAST:
			out.append(Vector2(a, b))
		at += size + road
	return out


## Where a building may stand on `lot`: the lot, or the most of it that's clear - a side given up
## (a lot by the water keeps back from it), or the lot drawn in - clear of the water (`gap` px), the
## fixed points, the docks' ways and the start; zero if none.
func _ruin_room(lot: Rect2, gap: float) -> Rect2:
	var tries: Array = [lot]
	for f: float in [0.25, 0.45]:
		var cx := lot.size.x * f
		var cy := lot.size.y * f
		tries.append(lot.grow_individual(-cx, 0.0, 0.0, 0.0))
		tries.append(lot.grow_individual(0.0, -cy, 0.0, 0.0))
		tries.append(lot.grow_individual(0.0, 0.0, -cx, 0.0))
		tries.append(lot.grow_individual(0.0, 0.0, 0.0, -cy))
		tries.append(lot.grow_individual(-cx * 0.5, -cy * 0.5, -cx * 0.5, -cy * 0.5))
	for rect in tries:
		var r: Rect2 = rect
		if r.size.x >= RUIN_LEAST and r.size.y >= RUIN_LEAST and _ruin_clear(r, gap):
			return r
	return Rect2()


func _ruin_clear(rect: Rect2, gap: float) -> bool:
	if _rect_distance(rect, SPAWN_POS) < SPAWN_CLEAR_RADIUS:
		return false
	for t in _taken:
		if _rect_distance(rect, t[0]) < float(t[1]) + PROP_GAP:
			return false
	for w in _walk_rects:
		if rect.grow(40.0).intersects(w):
			return false
	for e in _entrances:
		if _rect_distance(rect, e) < ENTRANCE_CLEARANCE:
			return false
	# (the water: along its edges and across it, every RUIN_PROBE px)
	var nx := maxi(2, ceili(rect.size.x / RUIN_PROBE) + 1)
	var ny := maxi(2, ceili(rect.size.y / RUIN_PROBE) + 1)
	for i in nx:
		for j in ny:
			var p := rect.position + Vector2(rect.size.x * i / float(nx - 1), rect.size.y * j / float(ny - 1))
			if _in_any_water(p) or _shore_distance(p) < gap:
				return false
	return true


const RUIN_PROBE := 50.0


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


## User request (the countryside, a style with "farm"): its farmsteads, the tracks from them out to
## the map's edge, its fields (some fenced, the stubble with its bales) and what stands about (the
## "yard" - StreetProp's farm kinds). The farms first - the biggest things - then the tracks, then the
## fields clear of both, then the rest round them.
func _place_farms() -> void:
	farm_tracks = []
	var spec: Dictionary = theme.get("farm", {})
	if spec.is_empty():
		return
	var share := Campaign.area_share()
	# (a farm, its track, a field, in turn - so a crowded map still has some of each)
	var steads := maxi(1, roundi(float(spec.steads) * share))
	var fields := maxi(1, roundi(float(spec.fields) * share))
	var farms := 0
	if spec.has("landmark"):
		# (the village's landmark first - the English chapel, the Japanese hall - on its own, where it fits)
		var mark := spec.duplicate()
		mark.houses = [spec.landmark]
		mark.extra = Vector2i(0, 0)
		var yard := _farmstead(mark, false)
		if yard != Vector2.INF:
			_farm_track(yard, TRACK_HALF * 2.0)
	for i in maxi(steads, fields):
		if i < steads:
			var yard := _farmstead(spec, true)
			if yard == Vector2.INF and farms == 0:
				# (no room for the first farm and its barn: a farmhouse on its own, a little smaller)
				var alone := spec.duplicate()
				alone.scale = Vector2((spec.scale as Vector2).x * 0.85, (spec.scale as Vector2).x)
				yard = _farmstead(alone, false)
			if yard != Vector2.INF:
				_farm_track(yard, TRACK_HALF * 2.0)
				farms += 1
		if i < fields:
			_farm_field(spec, ceili(float(fields) * FIELD_LEAST))
	_place_yard_things()


## One farmstead: a farmhouse and its barn (`with_barn`; else the house alone) either side of a yard
## (`spec` "yard" px across), now and then a tower, lookout, shelter or silos beside it ("extra" of
## them) - each clear as a city building is (_ruin_clear); its yard's middle, or INF if none would
## fit.
func _farmstead(spec: Dictionary, with_barn: bool) -> Vector2:
	var yard_w := float(spec.yard)
	var gap := float(spec.water_gap)
	var scale: Vector2 = spec.scale
	# (the yard's middle in from the map's edges - its buildings reach out from it)
	var inset := Vector2(minf(STEAD_INSET, Player.WORLD_WIDTH * 0.25), minf(STEAD_INSET, Player.WORLD_HEIGHT * 0.25))
	for _try in STEAD_TRIES:
		var c := Vector2(randf_range(inset.x, Player.WORLD_WIDTH - inset.x), randf_range(inset.y, Player.WORLD_HEIGHT - inset.y))
		if c.distance_to(SPAWN_POS) < SPAWN_CLEAR_RADIUS or _in_any_water(c) or _shore_distance(c) < gap + yard_w * 0.5:
			continue
		# (the house one side of the yard, the barn the other - along x or y, whichever way they fit;
		# the extras across)
		var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
		dirs.shuffle()
		var dir := Vector2.ZERO
		var placed := []
		for d: Vector2 in dirs:
			placed = []
			for pick in ([[spec.houses, -d], [spec.barns, d]] if with_barn else [[spec.houses, -d]]):
				var got := _farm_building((pick[0] as Array).pick_random(), c, pick[1], yard_w * 0.5, scale, gap, placed)
				if got.is_empty():
					break
				placed.append(got)
			if placed.size() == (2 if with_barn else 1):
				dir = d
				break
		if dir == Vector2.ZERO:
			continue
		var across := Vector2(-dir.y, dir.x)
		# (the extras across the yard: out past the house and the barn's sides, somewhere along them)
		var extras: Vector2i = spec.extra
		var want := randi_range(extras.x, extras.y)
		var sides := [across, -across]
		sides.shuffle()
		for k in mini(want, 2):
			var side: Vector2 = sides[k]
			var past := 0.0
			for entry in placed:
				var r: Rect2 = entry.rect
				past = maxf(past, maxf((r.position - c).dot(side), (r.end - c).dot(side)))
			for _t in 4:
				var anchor := c + dir * randf_range(-yard_w * 1.5, yard_w * 1.5)
				var got := _farm_building((spec.extras as Array).pick_random(), anchor, side, past + yard_w * 0.4, scale, gap, placed)
				if not got.is_empty():
					placed.append(got)
					break
		for entry in placed:
			var rect: Rect2 = entry.rect
			var ruin := Ruin.new()
			ruin.name = "Ruin%d" % _ruins.size()
			ruin.kind = "model"
			ruin.model = entry.model
			ruin.model_yaw = entry.yaw
			ruin.model_scale = entry.scale
			ruin.storeys = 1
			ruin.size = rect.size
			ruin.position = rect.get_center()
			ruin.seed_value = randi()
			for circle in ruin.footprint_circles():
				_taken.append([circle[0], circle[1], circle[1], true])
			_ruins.append(rect)
			get_parent().add_child.call_deferred(ruin)
		# (the yard itself kept open)
		_taken.append([c, yard_w * 0.4, 0.0])
		_yards.append(c)
		return c
	return Vector2.INF


## A farm building (`name`, scaled within `scale`, a quarter turn either way) by the yard: out along
## `side` from `c` by `away` px and half itself; {rect, model, yaw, scale} if it's clear of the water
## (`gap`), of everything placed and of the farm's others (`placed`, FARM_APART apart), else {}.
func _farm_building(name: String, c: Vector2, side: Vector2, away: float, scale: Vector2, gap: float, placed: Array) -> Dictionary:
	if Ruin.info(name).is_empty():
		return {}
	var yaw := float(randi() % 4) * PI * 0.5
	var k := randf_range(scale.x, scale.y)
	var size := Ruin.model_footprint(name, yaw, k)
	var out := (absf(side.x) * size.x + absf(side.y) * size.y) * 0.5 + away
	var rect := Rect2(c + side * out - size * 0.5, size)
	if rect.position.x < PROP_MARGIN or rect.position.y < PROP_MARGIN or rect.end.x > Player.WORLD_WIDTH - PROP_MARGIN or rect.end.y > Player.WORLD_HEIGHT - PROP_MARGIN:
		return {}
	for other in placed:
		if (other.rect as Rect2).grow(FARM_APART).intersects(rect):
			return {}
	# (clear of the fields and the tracks already laid - the farms and the fields go down in turn)
	for f in _fields:
		if (f as Rect2).grow(FARM_APART).intersects(rect):
			return {}
	for line in farm_tracks:
		for q in (line as PackedVector2Array):
			if rect.grow(_track_half + 10.0).has_point(q):
				return {}
	if not _ruin_clear(rect, gap):
		return {}
	return {"rect": rect, "model": name, "yaw": yaw, "scale": k}


## A dirt track from a farm's yard (`from`) out to the map's edge - the nearest edge it can reach
## without crossing the water, a building or the camp - wandering a little; `width` px. None if no
## edge can be reached so.
func _farm_track(from: Vector2, width: float) -> void:
	var edges := [Vector2(0.0, from.y), Vector2(Player.WORLD_WIDTH, from.y), Vector2(from.x, 0.0), Vector2(from.x, Player.WORLD_HEIGHT)]
	edges.sort_custom(func(a, b): return from.distance_to(a) < from.distance_to(b))
	var tries := []
	for end in edges:
		for k in TRACK_TRIES:
			# (straight-ish first, then wandering further - round a pond in its way)
			tries.append([end, TRACK_WANDER * float(k) / float(TRACK_TRIES - 1) * (1.0 if randf() < 0.5 else -1.0)])
	for attempt in tries:
		var end: Vector2 = attempt[0]
		var length := from.distance_to(end)
		var n := maxi(2, ceili(length / TRACK_STEP))
		var side := (end - from).normalized().orthogonal()
		var amp: float = attempt[1]
		var waves := randf_range(0.6, 1.4)
		var phase := randf() * TAU
		var line := PackedVector2Array()
		var ok := true
		for i in n + 1:
			var t := float(i) / float(n)
			var p := from.lerp(end, t) + side * amp * sin(t * PI) * (0.6 + 0.4 * sin(t * PI * waves + phase))
			# (past the yard: clear of the water, the buildings and the camp)
			if t * length > float((theme.farm as Dictionary).yard) * 0.6:
				if _in_any_water(p) or _shore_distance(p) < width * 0.5 + 30.0 or _in_ruin(p, width * 0.5) or p.distance_to(SPAWN_POS) < SPAWN_CLEAR_RADIUS:
					ok = false
					break
				for w in _walk_rects:
					if (w as Rect2).grow(width * 0.5).has_point(p):
						ok = false
				if not ok:
					break
			line.append(p)
		if ok:
			farm_tracks.append(line)
			return


## Whether a thing (radius `r`, px) at `at` would stand on one of the tracks.
func _on_track(at: Vector2, r: float) -> bool:
	for line in farm_tracks:
		var pts := line as PackedVector2Array
		for i in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(at, pts[i], pts[i + 1]).distance_to(at) < r + _track_half:
				return true
	return false


## One field (its size within `spec` "field_min".."field_max" - as big as there's room for - its crop
## by "crops"' weights) where
## there's room - clear of the water, the farms, the tracks, the camp and the other fields; some
## fenced ("fenced"), the stubble with its bales ("bales"). Looked for over the whole map while the map
## has fewer than `at_least`.
func _farm_field(spec: Dictionary, at_least := 1) -> void:
	var lo: Vector2 = spec.field_min
	var hi: Vector2 = spec.field_max
	var tries := []
	for attempt in FIELD_TRIES:
		# (big ones tried first, smaller as they fail - the room left between the ponds and the farms)
		var t := float(attempt) / float(FIELD_TRIES - 1)
		var size := hi.lerp(lo, t) * Vector2(randf_range(0.8, 1.0), randf_range(0.8, 1.0))
		size = size.max(lo)
		tries.append(Rect2(Vector2(randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN - size.x),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN - size.y)), size))
	# (user request - the river: on a small map, what's left beside it, the ponds and the farms has
	# room for a field in only a few places, which random tries can all miss - so a field, if they do,
	# the smallest one tried at every FIELD_SCAN px over the map, each way round, in no order. Not only
	# the first: the river takes a third of a map's room, and 9-2's walled pastures and 7-2's riverside
	# fields had gone down to one or two - so up to `at_least` of them (FIELD_LEAST of the map's, about
	# as many as random tries found before there were rivers; looked for to the last one, the biggest
	# maps were packed with small fields). Once a scan finds no room, there's none for the fields after
	# it either - _no_room - and they're not looked for again.)
	var scanned := false
	if not _no_room and _fields.size() < at_least:
		scanned = true
		var scan := []
		var least := minf(lo.x, lo.y)
		var y := PROP_MARGIN
		while y <= Player.WORLD_HEIGHT - PROP_MARGIN - least:
			var x := PROP_MARGIN
			while x <= Player.WORLD_WIDTH - PROP_MARGIN - least:
				scan.append(Rect2(Vector2(x, y), lo))
				scan.append(Rect2(Vector2(x, y), Vector2(lo.y, lo.x)))
				x += FIELD_SCAN
			y += FIELD_SCAN
		scan.shuffle()
		tries.append_array(scan)
	for rect: Rect2 in tries:
		if rect.end.x > Player.WORLD_WIDTH - PROP_MARGIN or rect.end.y > Player.WORLD_HEIGHT - PROP_MARGIN:
			continue
		if not _field_clear(rect, float(spec.water_gap)):
			continue
		var field := FarmField.new()
		field.name = "FarmField%d" % _fields.size()
		field.rect = rect
		field.position = rect.get_center()
		field.crop = _weighted(spec.crops)
		field.seed_value = randi()
		_fields.append(rect)
		get_parent().add_child.call_deferred(field)
		if randf() < float(spec.fenced):
			_fence_field(rect, spec.gate, _weighted(spec.get("fences", {"wood": 1.0})))
		if field.crop == "stubble":
			var bales: Vector2i = spec.bales
			for _b in randi_range(bales.x, bales.y):
				for _t in 12:
					var inner := rect.grow(-45.0)
					var at := inner.position + Vector2(randf() * inner.size.x, randf() * inner.size.y)
					if _fits_street(at, StreetProp.reach_of("bale") + 12.0):
						_add_farm_prop({"kind": "bale"}, at, randf() * TAU)
						break
		return
	if scanned:
		_no_room = true


func _field_clear(rect: Rect2, gap: float) -> bool:
	if _rect_distance(rect, SPAWN_POS) < SPAWN_CLEAR_RADIUS:
		return false
	for f in _fields:
		if (f as Rect2).grow(FIELD_GAP).intersects(rect):
			return false
	for t in _taken:
		if _rect_distance(rect, t[0]) < float(t[1]) + 20.0:
			return false
	for w in _walk_rects:
		if rect.grow(40.0).intersects(w):
			return false
	for e in _entrances:
		if _rect_distance(rect, e) < ENTRANCE_CLEARANCE:
			return false
	for line in farm_tracks:
		for p in (line as PackedVector2Array):
			if _rect_distance(rect, p) < _track_half + 16.0:
				return false
	var nx := maxi(2, ceili(rect.size.x / RUIN_PROBE) + 1)
	var ny := maxi(2, ceili(rect.size.y / RUIN_PROBE) + 1)
	for i in nx:
		for j in ny:
			var p := rect.position + Vector2(rect.size.x * i / float(nx - 1), rect.size.y * j / float(ny - 1))
			if _in_any_water(p) or _shore_distance(p) < gap:
				return false
	return true


## The fence round a field (of `style` - Fence.STYLES): along each side but now and then one, with a
## gap (`gate` px wide, somewhere along it) to walk through; runs too short left out.
func _fence_field(rect: Rect2, gate: Vector2, style: String) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		if randf() < FENCE_OPEN_SIDE:
			continue
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var length := a.distance_to(b)
		var width := minf(randf_range(gate.x, gate.y), length * 0.5)
		var at := randf_range(length * 0.2, length * 0.8 - width)
		for run in [[0.0, at], [at + width, length]]:
			var r0: float = run[0]
			var r1: float = run[1]
			if r1 - r0 < FENCE_LEAST:
				continue
			var p0 := a.lerp(b, r0 / length)
			var p1 := a.lerp(b, r1 / length)
			var fence := Fence.new()
			fence.name = "Fence%d" % _fence_count
			_fence_count += 1
			fence.position = (p0 + p1) * 0.5
			fence.half = (r1 - r0) * 0.5
			fence.yaw = (p1 - p0).angle()
			fence.style = style
			fence.seed_value = randi()
			get_parent().add_child.call_deferred(fence)
			var steps := maxi(1, ceili((r1 - r0) / 40.0))
			for i in steps + 1:
				_taken.append([p0.lerp(p1, float(i) / float(steps)), Fence.thick_of(style), 0.0])


## What stands about the farms (`theme` "yard" - its "things", each a StreetProp `kind` with its
## `models` (one picked each), so many a base map's area ("count"), its solid ground ("size" -
## [radius, length] px; StreetProp.FARM's else) and where it goes ("where": "track" beside the tracks,
## "across" astride a track near its farm - a gate - "building" by the farm buildings' walls, "yard"
## about the farms' yards, "open" anywhere); "lit" of the lanterns at night, at most "lit_most"); its
## "groves" - an orchard's trees in rows, a bamboo grove - so many a map whatever its size.
func _place_yard_things() -> void:
	var spec: Dictionary = theme.get("yard", {})
	if spec.is_empty():
		return
	var share := Campaign.area_share()
	var lit_left := int(spec.get("lit_most", 3))
	for thing: Dictionary in spec.get("things", []):
		var where := str(thing.get("where", "building"))
		if (where == "track" or where == "across") and farm_tracks.is_empty():
			continue
		if float(thing.get("count", 0)) <= 0.0:
			continue
		for _i in maxi(1, roundi(float(thing.count) * share)):
			for _t in 25:
				var at := Vector2.INF
				var yaw := randf() * TAU if str(thing.get("turn", "free")) == "free" else float(randi() % 4) * PI * 0.5 + randf_range(-0.2, 0.2)
				var reach := _thing_shape(thing).x
				match where:
					"track", "across":
						var line := farm_tracks.pick_random() as PackedVector2Array
						# (a gate near its farm - the track's first stretch, further along it if there's no room
						# for all of it there (its beam clear of the buildings); a lantern anywhere along it)
						var first := (line.size() - 1) / 3 if _t < 10 else (line.size() - 1) * 2 / 3
						var i := randi() % maxi(1, first if where == "across" else line.size() - 1)
						i = maxi(i, 2) if where == "across" else i
						i = mini(i, line.size() - 2)
						var dir := (line[i + 1] - line[i]).normalized()
						yaw = dir.angle() + PI * 0.5
						at = line[i] if where == "across" else line[i] + dir.orthogonal() * (_track_half + reach + 8.0) * (1.0 if randf() < 0.5 else -1.0)
					"yard":
						if not _yards.is_empty():
							at = (_yards.pick_random() as Vector2) + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(50.0, 160.0)
					"open":
						at = Vector2(randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN), randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN))
					_:
						if not _ruins.is_empty():
							var rect: Rect2 = _ruins.pick_random()
							var side := randi() % 4
							var t := randf_range(0.1, 0.9)
							var out := reach + randf_range(14.0, 50.0)
							match side:
								0: at = Vector2(rect.position.x + rect.size.x * t, rect.position.y - out)
								1: at = Vector2(rect.end.x + out, rect.position.y + rect.size.y * t)
								2: at = Vector2(rect.position.x + rect.size.x * t, rect.end.y + out)
								_: at = Vector2(rect.position.x - out, rect.position.y + rect.size.y * t)
				if at == Vector2.INF:
					break
				var prop := _add_farm_prop(thing, at, yaw, where)
				if prop != null:
					if lit_left > 0 and randf() < float(thing.get("lit", 0.0)):
						prop.lit = true
						lit_left -= 1
					break
	for grove: Dictionary in spec.get("groves", []):
		_place_grove(grove)


## A grove (`grove`: an orchard's trees in rows "rows" x "cols", "gap" px apart, each off its place by
## up to "jitter") where at least "fill" of it fits, "count" of them.
func _place_grove(grove: Dictionary) -> void:
	var rows_span: Vector2i = grove.get("rows", Vector2i(2, 3))
	var cols_span: Vector2i = grove.get("cols", Vector2i(3, 4))
	var gap := float(grove.get("gap", 105.0))
	var jitter := float(grove.get("jitter", 8.0))
	var reach := _thing_shape(grove).x
	for _o in int(grove.get("count", 0)):
		for _t in 30:
			var rows := randi_range(rows_span.x, rows_span.y)
			var cols := randi_range(cols_span.x, cols_span.y)
			var origin := Vector2(randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN - gap * cols), randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN - gap * rows))
			var spots := []
			for r in rows:
				for q in cols:
					var p := origin + Vector2(q * gap + randf_range(-jitter, jitter), r * gap + randf_range(-jitter, jitter))
					if _yard_spot_ok(p, reach) and _fits(p, reach, 0.0):
						spots.append(p)
			if spots.size() >= int(rows * cols * float(grove.get("fill", 0.7))):
				var area := Rect2(spots[0], Vector2.ZERO)
				for p in spots:
					_add_farm_prop(grove, p, randf() * TAU, "grove")
					area = area.expand(p)
				# (the grove's ground, its clumps' or rows' reach round it: kept to itself)
				_grove_areas.append(area.grow(reach + gap * 0.25))
				break


## A yard thing's solid ground: (radius, length) px - its own "size", else its kind's.
static func _thing_shape(thing: Dictionary) -> Vector2:
	if thing.has("size"):
		var s = thing.size
		return Vector2(float(s[0]), float(s[1])) if s is Array else s as Vector2
	return StreetProp.shape_of(str(thing.get("kind", "")))


## Whether a yard thing (radius `reach`, px) may stand at `at`: on the map, off the start, the water,
## the docks' ways, the buildings and the tracks.
func _yard_spot_ok(at: Vector2, reach: float) -> bool:
	if at.x < PROP_MARGIN or at.y < PROP_MARGIN or at.x > Player.WORLD_WIDTH - PROP_MARGIN or at.y > Player.WORLD_HEIGHT - PROP_MARGIN:
		return false
	if at.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS or _shore_distance(at) < reach + 30.0 or _in_any_water(at):
		return false
	if _near_walkway(at, reach + 20.0) or _near_entrance(at, ENTRANCE_CLEARANCE):
		return false
	return not _in_ruin(at, reach) and not _on_track(at, reach + 4.0)


## A yard thing (`thing`: its kind, its models, its size) at `at` if it may stand there - outside the
## fields but for the bales; `where` "track": right beside a track, "across": astride one, its two
## ends off it - the prop, or null.
func _add_farm_prop(thing: Dictionary, at: Vector2, yaw: float, where := "") -> StreetProp:
	var kind := str(thing.get("kind", ""))
	var shape := _thing_shape(thing)
	var reach := maxf(shape.x, shape.y * 0.5)
	var models: Array = thing.get("models", [])
	var model := str(models.pick_random()) if not models.is_empty() else ""
	# User request ("所有物件不可以有穿圖"): kept clear by all of its model as drawn - a lantern post's
	# hanging lanterns, a gate's top beam out past its posts - not just its foot (what grows aside: its
	# leaves may meet, its stems kept apart).
	var drawn := _model_reach(model) if not kind in FarmBuild.GROWN else 0.0
	if kind != "bale":
		if where == "across":
			# (a gate: each of its two posts clear, the track running between them; its beam's ends -
			# all of the model's length - clear of the buildings too)
			var along := Vector2(cos(yaw), sin(yaw)) * (shape.y * 0.5 - shape.x)
			for post in [at + along, at - along]:
				if not _yard_spot_ok(post, 0.0) or _on_track(post, shape.x) or not _fits_street(post, shape.x):
					return null
				for f in _fields:
					if _rect_distance(f, post) < shape.x + 10.0:
						return null
			var span := Vector2(cos(yaw), sin(yaw)) * maxf(drawn, along.length())
			for end in [at + span, at - span, at + span * 0.5, at - span * 0.5]:
				if _in_ruin(end, 4.0):
					return null
		else:
			reach = maxf(reach, drawn)
			if not _yard_spot_ok(at, 0.0 if where == "track" else reach) or not _fits_street(at, reach):
				return null
			if where == "track" and (_on_track(at, 0.0) or _in_ruin(at, reach)):
				return null
			for f in _fields:
				if _rect_distance(f, at) < reach + 10.0:
					return null
	var prop := StreetProp.new()
	prop.name = "StreetProp%d" % _farm_props
	_farm_props += 1
	prop.kind = kind
	prop.model = model
	if thing.has("size"):
		prop.size = shape
	prop.yaw = yaw
	prop.position = at
	prop.seed_value = randi()
	if where == "across":
		var along := Vector2(cos(yaw), sin(yaw)) * (shape.y * 0.5 - shape.x)
		_taken.append([at + along, shape.x, 0.0])
		_taken.append([at - along, shape.x, 0.0])
	else:
		_taken.append([at, reach, 0.0])
	get_parent().add_child.call_deferred(prop)
	return prop


## How far a yard thing's model reaches from its middle as drawn (px: to its corners on the ground,
## whichever way it's turned); 0 for one without a model.
static func _model_reach(model: String) -> float:
	if model == "":
		return 0.0
	var size: Array = Ruin.info(model).get("size", [])
	if size.size() < 2:
		return 0.0
	return Vector2(float(size[0]), float(size[1])).length() * 0.5 * Fossil.PX


## A key of `weights` ({key: weight}) drawn by its weight.
static func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return str(k)
	return str(weights.keys().back())


## The countryside's tracks this map (px polylines, from a farm's yard to the map's edge) - for
## RunView3D's ground.
static var farm_tracks: Array = []
## (the tracks' half width, px; how far apart their points; how far they wander from straight)
const TRACK_HALF := 32.0
var _track_half := TRACK_HALF
const TRACK_STEP := 40.0
const TRACK_WANDER := 260.0
const TRACK_TRIES := 4
## (fields: how far apart; how likely a side is left unfenced; a fence's least run, px)
const FIELD_GAP := 70.0
const FIELD_TRIES := 60
const FIELD_SCAN := 60.0
## (how many of a map's fields are looked for over the whole map when random tries miss - _farm_field)
const FIELD_LEAST := 0.5
## (where a farm might stand: so many tried, its yard's middle this far in from the map's edges, px)
const STEAD_TRIES := 120
const STEAD_INSET := 300.0
## (a farm's buildings: at least this far apart, px)
const FARM_APART := 50.0
const FENCE_OPEN_SIDE := 0.15
const FENCE_LEAST := 40.0
## The fields placed (their rectangles, px); the farms' yards (px).
var _fields: Array = []
## (a scan of the whole map has found no room for another field - _farm_field)
var _no_room := false
var _yards: Array = []
var _fence_count := 0
var _farm_props := 0


func _place_fossils() -> void:
	var want: Dictionary = theme.get("fossils", {})
	var share := Campaign.area_share()
	var made := 0
	# (which of the big skeletons this game: "big_fossils" of them a base map's area, drawn anew)
	var bigs := []
	for kind in want:
		if kind in Fossil.BIG:
			bigs.append(kind)
	bigs.shuffle()
	bigs = bigs.slice(0, clampi(roundi(float(theme.get("big_fossils", bigs.size())) * share), mini(1, bigs.size()), bigs.size()))
	for kind in want:
		if kind in Fossil.BIG and not kind in bigs:
			continue
		var count := int(want[kind]) if kind in Fossil.BIG else maxi(1, int(roundf(float(want[kind]) * share)))
		for _i in count:
			# (one of its ways, drawn each time: its legs or its skull here or there, some gone off)
			var form := Fossil.pick(kind)
			var bones := _place_fossil(kind, form, made, Rect2(0, 0, Player.WORLD_WIDTH, Player.WORLD_HEIGHT))
			if bones == null:
				continue
			made += 1
			# (what's gone off it lies near it, on the sand round it)
			for piece in Fossil.SCATTER.get(form, []):
				var around := Rect2(bones.position - Vector2.ONE * (bones.reach() + 6.0 * Fossil.PX), Vector2.ONE * 2.0 * (bones.reach() + 6.0 * Fossil.PX))
				if _place_fossil("bones", str(piece), made, around) != null:
					made += 1


## User request (the sea cliff - tools/make_coast_props.py, Fossil "reef"): rocks fallen from the
## cliff out in the surf at its foot (COAST_FOOT px out from it), in twos and threes (COAST_REEFS
## clusters a base map's area). (User feedback: no cliffs or rocks walling the sandy beach off - a
## beach and a sea cliff are kinds of coast of their own.)
const COAST_REEFS := Vector2i(3, 4)
const COAST_FOOT := Vector2(30.0, 110.0)


func _place_coast_rocks() -> void:
	var across := sea_side.y != 0.0
	var length := Player.WORLD_WIDTH if across else Player.WORLD_HEIGHT
	var made := 0
	# (the sea cliff: its face is RunView3D's, all along the coast; here the rocks fallen from it,
	# out in the surf at its foot, in twos and threes)
	var clusters := maxi(1, roundi(randi_range(COAST_REEFS.x, COAST_REEFS.y) * Campaign.area_share()))
	for _c in clusters:
		var t := randf_range(length * 0.06, length * 0.94)
		for k in randi_range(2, 3):
			var p := _coast_point(t + randf_range(-120.0, 120.0), -randf_range(COAST_FOOT.x, COAST_FOOT.y))
			if p.is_finite() and _put_coast_rock("reef", p, randf() * TAU, made):
				made += 1


## The coast `t` px along it (from the map's top or left), `up` px up from the sea's edge (into
## the sea if less than 0); INF if the coast isn't there.
func _coast_point(t: float, up: float) -> Vector2:
	var w := Player.WORLD_WIDTH
	var h := Player.WORLD_HEIGHT
	var from: Vector2
	match sea_side:
		Vector2.DOWN: from = Vector2(t, 0.0)
		Vector2.UP: from = Vector2(t, h)
		Vector2.LEFT: from = Vector2(w, t)
		_: from = Vector2(0.0, t)
	var steps := int((h if sea_side.y != 0.0 else w) / 8.0) + 40
	for k in steps:
		var p := from + sea_side * float(k) * 8.0
		if _sea_depth(p) > -up:
			return p
	return Vector2.INF


func _sea_depth(p: Vector2) -> float:
	var best := -INF
	for zone in water_zones:
		if zone.sea:
			best = maxf(best, zone.depth(p))
	return best


## One of the seaside's rocks (`kind`: "cliff" or "reef", one of its ways) at `pos`, turned `yaw`,
## if it may stand there: on the map, clear of the camp, the decks and what's placed.
func _put_coast_rock(kind: String, pos: Vector2, yaw: float, n: int) -> bool:
	var form := Fossil.pick(kind)
	var reach := Fossil.reach_px(form)
	var room := reach * (0.45 if kind == "cliff" else 0.55)
	if not _inside_map(pos, room * 0.5) or pos.distance_to(SPAWN_POS) < reach + PROP_AVOID_SPAWN_RADIUS + 80.0:
		return false
	if _near_walkway(pos, reach + 30.0) or _near_entrance(pos, reach + 20.0) or not _fits(pos, room, 0.0):
		return false
	var rock := Fossil.new()
	rock.name = "CoastRock%d" % n
	rock.kind = kind
	rock.form = form
	rock.yaw = yaw
	rock.position = pos
	_taken.append([pos, room, 0.0])
	get_parent().add_child.call_deferred(rock)
	return true


## One of the desert's bones, cacti or skulls - `kind`, its way `form` - somewhere in `within` (and
## the map) it fits: out on the open sand, kept from the water, the start and the camp; turned any
## way, the sand over it as this game has it (Fossil.cover). Null if nowhere would do.
func _place_fossil(kind: String, form: String, n: int, within: Rect2) -> Fossil:
	var reach := Fossil.reach_px(form)
	var lo := Vector2(maxf(within.position.x, reach + 60.0), maxf(within.position.y, reach + 60.0))
	var hi := Vector2(minf(within.end.x, Player.WORLD_WIDTH - reach - 60.0), minf(within.end.y, Player.WORLD_HEIGHT - reach - 60.0))
	if hi.x <= lo.x or hi.y <= lo.y:
		return null
	for _try in (360 if FOSSIL_SHORE_MAX.has(kind) else 120):
		var pos := Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))
		if pos.distance_to(SPAWN_POS) < reach + PROP_AVOID_SPAWN_RADIUS + 60.0:
			continue
		if _shore_distance(pos) < reach + float(FOSSIL_SHORE.get(kind, 90.0)) or _near_walkway(pos, reach + 30.0):
			continue
		if FOSSIL_SHORE_MAX.has(kind) and _shore_distance(pos) > float(FOSSIL_SHORE_MAX[kind]):
			continue
		if not _fits(pos, reach, 0.0):
			continue
		var bones := Fossil.new()
		bones.name = "Fossil%d" % n
		bones.kind = kind
		bones.form = form
		bones.yaw = randf() * TAU
		bones.position = pos
		bones.cover()
		_taken.append([pos, reach * (0.9 if kind in Fossil.BIG else 1.0), 0.0])
		get_parent().add_child.call_deferred(bones)
		return bones
	return null


## The desert's trees (a style with "oasis_trees"): most a palm by the water - in its "oasis_band"
## (px up from the shore), nearer likelier, most of a pool's in a grove or two (the picture: the
## palms thick along one side of the pool) - the rest a dead tree out on the dunes. Picks the
## tree's kind and where it goes ((-1, -1): nowhere). The palms' crowns are high over the rod, so
## they may stand nearer the bank than the pines' branches.
var _groves := {}
## The bamboo groves' and orchards' ground (px): no other tree grows in it (_fits).
var _grove_areas: Array[Rect2] = []


## (a style with "plant_band") a spot near some pool for a plant: out from its shore within the band
## (px), nearer likelier, clear of what's there ((-1, -1): none found).
func _by_water(base: float, reach: float) -> Vector2:
	var band: Array = theme.plant_band
	var zones := water_zones.filter(func(z): return not z.is_rare())
	if zones.is_empty():
		zones = water_zones
	if zones.is_empty():
		return _pick_prop_position(base, reach)
	for _try in 80:
		var zone: WaterZone = zones.pick_random()
		var samples: Array = zone.shore_samples(30.0)
		if samples.is_empty():
			continue
		var s: Array = samples.pick_random()
		var n: Vector2 = s[1]
		var pos: Vector2 = s[0] + n * lerpf(float(band[0]) + base, float(band[1]), pow(randf(), 1.4)) \
			+ n.orthogonal() * randf_range(-14.0, 14.0)
		if not _inside_map(pos, PROP_MARGIN) or pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		if _shore_distance(pos) < base + 10.0 or _in_any_water(pos):
			continue
		if _near_entrance(pos, ENTRANCE_CLEARANCE) or _near_walkway(pos, 30.0):
			continue
		if _fits(pos, base, reach):
			return pos
	return Vector2(-1, -1)


func _place_tree(tree: MapTree) -> Vector2:
	var roll := randi()
	if randf() >= float(theme.oasis_trees):
		tree.pick_from(roll, MapTree.open_for(theme_name))
		var size := _footprint(tree)
		return _pick_prop_position(size[0], size[1])
	tree.pick_from(roll, MapTree.kinds_for(theme_name))
	var size := _footprint(tree)
	var base: float = size[0]
	# (the crowns of a grove may meet)
	var reach: float = size[1] * 0.55
	var band: Array = theme.oasis_band
	var zones := water_zones.filter(func(z): return not z.is_rare())
	if zones.is_empty():
		zones = water_zones
	if zones.is_empty():
		return _pick_prop_position(base, size[1])
	for _try in 90:
		var zone: WaterZone = zones.pick_random()
		if not _groves.has(zone):
			var samples: Array = zone.shore_samples(30.0)
			var anchors := []
			for _g in randi_range(1, 2):
				anchors.append(randi() % maxi(samples.size(), 1))
			_groves[zone] = [samples, anchors]
		var samples: Array = _groves[zone][0]
		if samples.is_empty():
			continue
		var i := randi() % samples.size()
		if randf() < 0.7:
			# (in a grove: near one of its anchors along the shore)
			var anchors: Array = _groves[zone][1]
			i = posmod(int(anchors.pick_random()) + randi_range(-5, 5), samples.size())
		var s: Array = samples[i]
		var n: Vector2 = s[1]
		var out := lerpf(float(band[0]) + base, float(band[1]), pow(randf(), 1.7))
		var pos: Vector2 = s[0] + n * out + n.orthogonal() * randf_range(-14.0, 14.0)
		if not _inside_map(pos, PROP_MARGIN) or pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		if _shore_distance(pos) < base + 16.0 or _in_any_water(pos):
			continue
		if _near_entrance(pos, ENTRANCE_CLEARANCE) or _near_walkway(pos, 30.0):
			continue
		# (a grove's crowns may meet - but none grows into a building: its whole crown kept clear)
		if _fits(pos, base, reach) and _crown_clear(pos, size[1]):
			return pos
	return Vector2(-1, -1)


## User request ("所有物件不可以有穿圖"): a tree's crown (`crown` px out from its trunk) clear of
## every building's walls and roof - but CROWN_BRUSH px (the tips of its leaves may brush).
const CROWN_BRUSH := 12.0


func _crown_clear(pos: Vector2, crown: float) -> bool:
	for rect in _ruins:
		if _rect_distance(rect, pos) < crown - CROWN_BRUSH:
			return false
	return true


## The theme's extra trees, rocks and bushes, spaced like the scene props.
func _scatter_themed_props() -> void:
	for spec in [[TREE_SCENE, theme.trees], [OBSTACLE_SCENE, theme.rocks], [BUSH_SCENE, theme.bushes]]:
		for _i in spec[1]:
			var prop: Node2D = spec[0].instantiate()
			_theme_prop(prop)
			var size := _footprint(prop)
			var at := _place_tree(prop) if prop is MapTree and theme.has("oasis_trees") \
				else (_by_water(size[0], size[1]) if spec[0] == BUSH_SCENE and theme.has("plant_band")
				else _pick_prop_position(size[0], size[1]))
			if at.x < 0.0:
				prop.free()
				continue
			size = _footprint(prop)
			prop.position = at
			_taken.append([at, size[0], size[1]])
			get_parent().add_child.call_deferred(prop)


## User request: pond edges dressed from the existing art. User feedback:
## grass clumps (some standing in the shallows), low shrubs and pebbles,
## kept off docks, paths and the spawn point; most common ponds also get a
## dock out into deep water (see _place_docks); frogs and bugs about.
func _dress_shores() -> void:
	for zone in water_zones:
		for sample in zone.shore_samples(SHORE_SPACING):
			var p: Vector2 = sample[0]
			var n: Vector2 = sample[1]
			if p.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN or not _inside_map(p, 24.0) \
					or _near_walkway(p, 26.0):
				continue
			# Where zones overlap (the sea's), a zone's own shore can lie
			# out in the other's water.
			if water_zones.any(func(z): return z != zone and z.depth(p) > 2.0):
				continue
			var extras: Dictionary = theme.get("shore_extras", SHORE_EXTRAS)
			if not zone.is_rare() and randf() < extras.get("lilypad", 0.0):
				var pad := p - n * randf_range(16.0, 44.0) + n.orthogonal() * randf_range(-10.0, 10.0)
				if zone.contains(pad) and not _near_walkway(pad, 20.0):
					_add_ground_cover(pad, "lilypad")
			if randf() < extras.get("reeds", 0.0):
				_add_ground_cover(p + n * randf_range(-10.0, 6.0) + n.orthogonal() * randf_range(-6.0, 6.0), "reeds")
			if randf() < extras.get("driftwood", 0.0):
				var log_pos := p + n * randf_range(8.0, 20.0)
				if _shore_distance(log_pos) > 4.0:
					_add_ground_cover(log_pos, "driftwood")
			var roll := randf()
			var odds: Dictionary = theme.get("shore", SHORE_ODDS)
			if roll < odds.grass:
				for _k in randi_range(2, 4):
					_add_ground_cover(p + n * randf_range(-10.0, 12.0) + n.orthogonal() * randf_range(-10.0, 10.0), "grass")
			elif roll < odds.grass + odds.shrub:
				var pos := p + n * randf_range(10.0, 26.0)
				if _shore_distance(pos) < 6.0:
					continue
				if randf() < SHORE_HIDE_BUSH_CHANCE and _fits(pos + n * 10.0, 24.0, 0.0):
					var bush: Node2D = BUSH_SCENE.instantiate()
					bush.position = pos + n * 10.0
					_taken.append([bush.position, 24.0, 0.0])
					_theme_prop(bush)
					get_parent().add_child.call_deferred(bush)
				else:
					_add_ground_cover(pos, "shrub")
			elif roll < odds.grass + odds.shrub + odds.pebbles:
				for _k in randi_range(1, 3):
					_add_ground_cover(p + n * randf_range(-4.0, 16.0) + n.orthogonal() * randf_range(-12.0, 12.0), "pebble")
	_add_shore_critters()


## Catchable frogs and bugs hanging about the water's edge.
func _add_shore_critters() -> void:
	var zones: Array = water_zones.filter(func(z): return not z.is_rare())
	if zones.is_empty():
		return
	for _i in theme.get("shore_critter_count", SHORE_CRITTER_COUNT):
		var zone: WaterZone = zones.pick_random()
		var samples: Array = zone.shore_samples(60.0)
		if samples.is_empty():
			continue
		var sample: Array = samples.pick_random()
		var pos: Vector2 = sample[0] + sample[1] * randf_range(14.0, 30.0)
		if _shore_distance(pos) < 6.0 or pos.distance_to(SPAWN_POS) < SHORE_CLEAR_OF_SPAWN:
			continue
		# (a river's stretch runs on off the map: its shore there not a place for one - nor where it
		# runs out between the edge's trees)
		if zone.river and not _inside_map(pos, RIVER_CRITTER_IN):
			continue
		# (user report "動物們也不能被物件卡住跟穿圖": a frog left standing in a palm's trunk, a spider
		# boxed in by what was placed round it after - room kept for it, as for anything placed)
		if not _fits(pos, SHORE_CRITTER_ROOM, 0.0) or _near_walkway(pos, SHORE_CRITTER_ROOM):
			continue
		var critter: Critter = CRITTER_SCENE.instantiate()
		critter.species = theme.get("shore_critters", SHORE_CRITTERS).pick_random()
		critter.position = pos
		_taken.append([pos, SHORE_CRITTER_ROOM, 0.0])
		get_parent().add_child.call_deferred(critter)



func _add_ground_cover(pos: Vector2, kind: String) -> void:
	var plant: Node2D = GROUND_COVER_SCENE.instantiate()
	plant.position = pos
	# The theme's look's own version of a generic plant (see THEMES).
	plant.kind_override = theme.get("cover", {}).get(kind, kind)
	get_parent().add_child.call_deferred(plant)


func _inside_map(pos: Vector2, margin: float) -> bool:
	return pos.x > margin and pos.y > margin and pos.x < Player.WORLD_WIDTH - margin and pos.y < Player.WORLD_HEIGHT - margin


func _near_walkway(pos: Vector2, margin: float) -> bool:
	for r in _walk_rects:
		if r.grow(margin).has_point(pos):
			return true
	return false


## Decorative only, so no spacing rules beyond staying out of the water.
func _scatter_ground_cover() -> void:
	for _i in range(theme.ground):
		var pos := Vector2.ZERO
		if theme.has("plant_band"):
			pos = _by_water(10.0, 0.0)
			if pos.x < 0.0:
				continue
			var near: Node2D = GROUND_COVER_SCENE.instantiate()
			near.position = pos
			near.kind_weights = theme.ground_kinds
			get_parent().add_child.call_deferred(near)
			continue
		for _try in range(15):
			pos = Vector2(
				randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
				randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
			)
			if not _in_any_water(pos):
				break
		var plant: Node2D = GROUND_COVER_SCENE.instantiate()
		plant.position = pos
		plant.kind_weights = theme.ground_kinds
		# Main is still mid-setup here; see _spawn_zone().
		get_parent().add_child.call_deferred(plant)


## User request: small animals to catch as bait, spread around the map
## (kept off the spawn point so the first few seconds aren't a chase).
func _scatter_critters() -> void:
	for _i in range(int(Campaign.rules.critters)):
		var pos := _pick_prop_position(12.0, 0.0)
		if pos.x < 0.0:
			continue
		var critter: Node2D = CRITTER_SCENE.instantiate()
		critter.position = pos
		# Main is still mid-setup here; see _spawn_zone().
		get_parent().add_child.call_deferred(critter)
	# User request: larger ambient animals (cows, a deer...) as scenery,
	# the kinds picked by the map style.
	for _i in range(theme.get("animal_count", AMBIENT_ANIMAL_COUNT)):
		var animal: Critter = CRITTER_SCENE.instantiate()
		animal.ambient = true
		animal.species = _weighted_pick(theme.animals)
		var spot := _pick_prop_position(26.0, 0.0)
		if spot.x < 0.0:
			animal.free()
			continue
		animal.position = spot
		get_parent().add_child.call_deferred(animal)


## Extra catchable critters come out at nightfall, away from the player.
func _on_night_fell() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	for _i in range(int(roundf(NIGHT_CRITTER_COUNT * Campaign.area_share()))):
		var pos := _pick_prop_position(12.0, 0.0)
		for _try in range(6):
			if player == null or pos.distance_to(player.global_position) > 250.0:
				break
			pos = _pick_prop_position(12.0, 0.0)
		if pos.x < 0.0:
			continue
		var critter: Node2D = CRITTER_SCENE.instantiate()
		critter.position = pos
		get_parent().add_child(critter)


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return weights.keys()[0]


## Somewhere for a thing of base radius `base` and branch reach `reach`
## (px): on land, off the paths and the docks' ways on, clear of
## everything placed (_fits); (-1, -1) if there's no such place.
func _pick_prop_position(base: float, reach: float) -> Vector2:
	for _try in range(80):
		var pos := Vector2(
			randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
		)
		if pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		# Clear of the water with room for its base - and its branches
		# clear of the bank, where the rod swings.
		var shore := _shore_distance(pos)
		if shore < maxf(30.0, base + 8.0) or (reach > 0.0 and shore < reach + BANK_CLEAR):
			continue
		# (by the sea: the trees back from the beach - "inland")
		if reach > 0.0 and shore < float(theme.get("inland", 0.0)):
			continue
		# User bug report: rocks were landing across a boardwalk's way on.
		if _near_entrance(pos, ENTRANCE_CLEARANCE) or _near_walkway(pos, maxf(30.0, reach)):
			continue
		if _fits(pos, base, reach):
			return pos
	return Vector2(-1, -1)


## Whether a thing at `pos` (base radius, branch reach; px) keeps clear of
## everything placed: bases PROP_GAP apart; branches clear of branches.
func _fits(pos: Vector2, base: float, reach: float) -> bool:
	# (the countryside: nothing stands in its fields or on its tracks)
	for f in _fields:
		if _rect_distance(f, pos) < base + 12.0:
			return false
	# User report ("竹林裡出現綠樹"): nothing with a crown - a tree, a bush - in a bamboo grove or an
	# orchard, between its own clumps and rows
	if reach > 0.0:
		for g in _grove_areas:
			if _rect_distance(g, pos) < reach * 0.5:
				return false
	if _on_track(pos, base + 6.0):
		return false
	for t in _taken:
		var d := pos.distance_to(t[0])
		if d < base + float(t[1]) + PROP_GAP:
			return false
		if reach > 0.0 and float(t[2]) > 0.0 and d < reach + float(t[2]):
			return false
	# (a crown clear of the buildings' corners too - their keep-clear circles leave them out)
	return reach <= 0.0 or _crown_clear(pos, reach)
