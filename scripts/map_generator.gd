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
## A "sea" theme: how far in the sea reaches (share of the map across
## it), the zones' least radius, how much the coast wanders, lobes a zone,
## the baked shore's coarseness.
const SEA_REACH := Vector2(0.33, 0.42)
const SEA_RADIUS := 320.0
const SEA_WOBBLE := 50.0
const SEA_LOBES := Vector2i(2, 3)
const SEA_FIELD_TEXEL := 2.0
## The beach map (ground shader): px a texel, the farthest distance kept.
const COAST_TEXEL := 16.0
const COAST_RANGE := 400.0
## Rock ridges: length (share of the land between the coast and the far
## edge), boulder size (smallest, biggest).
const RIDGE_LENGTH := Vector2(0.3, 0.5)
const RIDGE_SIZE := Vector2(1.3, 1.9)
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
const SPAWN_POS := Vector2(1200.0, 700.0)
const SPAWN_CLEAR_RADIUS := 220.0

const FIXED_POINT_MARGIN := 150.0
const FIXED_POINT_MIN_SEPARATION := 550.0
const WILLOW_BESIDE_ALTAR := Vector2(72.0, 16.0)

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
const PROP_AVOID_SPAWN_RADIUS := 180.0

const DOCK_SCENE := preload("res://scenes/dock.tscn")
## Every common pond gets one, and this share of them a second.
const SECOND_DOCK_CHANCE := 0.5
const DOCK_SHORE_MARGIN := 60.0
const DOCK_STAIRS_CHANCE := 0.5
const DOCK_BOAT_CHANCE := 0.4

const GROUND_COVER_SCENE := preload("res://scenes/ground_cover.tscn")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const TREE_SCENE := preload("res://scenes/tree.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const FLIP_ROCK_SCENE := preload("res://scenes/flip_rock.tscn")
## User request: rocks the player can turn over for bait, per run.
const FLIP_ROCKS := Vector2i(8, 10)
const NOT_FLIPPABLE := ["pillar", "grave", "lantern", "shrine", "well", "lp_grave", "lp_lantern", "lp_shrine", "lp_well"]
const BUSH_SCENE := preload("res://scenes/bush.tscn")

## User request: each run is dressed in one of a few looks, all from the
## existing art. A theme sets how many extra trees/rocks/bushes/plants get
## scattered and which kinds (tree families, rock variants - obstacle.gd
## VARIANTS indices, 3-7 are the boulders - and ground-cover kinds).
## User feedback: a forest is one look, not every tree at once - it comes
## in single-colour variants; dead wood gets stone footpaths; the rock pile
## is mostly rocks with a few dead trees.
## User feedback: don't mix art styles - a finely drawn pine beside a
## flat-coloured low-poly one looks like a jumble. Every theme has a
## "look": "detailed" (the painted, finely modelled art) or "lowpoly" (the
## flat-coloured packs, and low-poly ground cover, bushes, props and a
## faceted floor made to match - tools/render_packs.py, make_ground.py),
## and draws only on art of that look. "cover" maps the shore and ground
## plants the generator asks for by generic name (grass, shrub,
## flower_bush, pebble, reeds, driftwood) to the look's own. The low-poly
## floors carry no painted detail, so those themes scatter more plants.
const THEMES := {
	"forest_pine": {
		"look": "detailed",
		"floor": ["forest_floor", "grass", 0.35],
		"trees": 28, "rocks": 3, "bushes": 6, "ground": 110,
		"tree_families": {"pine": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 4.0, "clover": 2.0, "plant": 2.0, "mushroom": 3.0, "shrub": 2.0},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 1.5, "wolf": 1.0, "husky": 1.0},
	},
	"forest_birch": {
		"look": "detailed",
		"floor": ["grass_light", "grass", 0.3],
		"trees": 26, "rocks": 2, "bushes": 6, "ground": 120,
		"tree_families": {"birch": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 3.0, "flower_group": 2.0, "flower_single": 2.0, "flower_clump": 2.0,
			"flower_petal": 1.0, "shrub": 2.0, "plant": 1.0},
		"animals": {"deer": 2.0, "stag": 1.0, "fox": 1.5, "shiba": 1.0, "white_horse": 1.0},
	},
	"forest_maple": {
		"look": "detailed",
		"floor": ["grass", "leaf_litter", 0.45],
		"trees": 24, "rocks": 3, "bushes": 6, "ground": 110,
		"tree_families": {"maple": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 3.0, "clover": 2.0, "flower_bush": 2.0, "mushroom": 2.0, "shrub": 2.0, "plant": 1.0},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 1.5, "shiba": 1.0, "wolf": 0.5},
	},
	"forest_green": {
		"look": "detailed",
		"floor": ["grass", "dirt", 0.2],
		"trees": 26, "rocks": 3, "bushes": 8, "ground": 120,
		"tree_families": {"oak": 1.0, "leafy": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 4.0, "clover": 2.0, "plant": 3.0, "shrub": 3.0, "flower_single": 1.0, "mushroom": 1.0},
		"animals": {"cow": 1.5, "bull": 1.0, "horse": 1.0, "deer": 1.0, "shiba": 1.0, "husky": 1.0},
	},
	"deadwood": {
		"look": "detailed",
		"shore_extras": {"reeds": 0.14, "lilypad": 0.06, "driftwood": 0.05},
		"floor": ["dirt", "gravel", 0.2],
		"trees": 22, "rocks": 5, "bushes": 2, "ground": 80,
		"tree_families": {"dead": 1.0, "bare": 1.0},
		"rock_pool": [0, 1, 2, 3, 4, "grave", "well"],
		"ground_kinds": {"grass": 2.0, "mushroom": 3.0, "pebble": 2.0, "plant": 1.0},
		"paths": true,
		"animals": {"wolf": 2.0, "fox": 1.5, "stag": 1.0, "husky": 0.5},
	},
	"rocky": {
		"look": "detailed",
		"shore_extras": {"reeds": 0.05, "lilypad": 0.03, "driftwood": 0.03},
		"floor": ["gravel", "dirt", 0.4],
		"trees": 6, "rocks": 26, "bushes": 1, "ground": 100,
		"tree_families": {"dead": 1.0, "bare": 1.0},
		"rock_pool": [0, 1, 2, 3, 4, 5, 6, 7, "granite", "sand"],
		"ground_kinds": {"pebble": 5.0, "grass": 2.0, "clover": 1.0},
		"animals": {"alpaca": 2.0, "donkey": 1.5, "fox": 1.0, "wolf": 1.0},
	},
	# User decision: a tropical look - palms, flowers and sandy ground.
	"tropical": {
		"look": "detailed",
		"shore_extras": {"reeds": 0.04, "lilypad": 0.02, "driftwood": 0.07},
		"floor": ["sand", "grass", 0.25],
		"trees": 22, "rocks": 3, "bushes": 5, "ground": 120,
		"tree_families": {"palm": 1.0},
		"rock_pool": [0, 1, 2],
		"ground_kinds": {"grass": 2.0, "flower_group": 2.0, "flower_single": 2.0, "flower_clump": 2.0,
			"flower_petal": 2.0, "flower_bush": 1.0, "plant": 2.0, "pebble": 1.0},
		"animals": {"horse": 1.0, "white_horse": 1.0, "alpaca": 1.0, "donkey": 1.0, "shiba": 1.0},
	},
	# User decision: dinosaurs only turn up here, a rare prehistoric look -
	# palms and conifers, ferny plants, boulders.
	"prehistoric": {
		"look": "detailed",
		"floor": ["moss_soil", "dirt", 0.3],
		"trees": 20, "rocks": 12, "bushes": 4, "ground": 110,
		"tree_families": {"palm": 2.0, "pine": 1.0, "leafy": 0.5},
		"rock_pool": [0, 1, 2, 3, 4, 5, 6, 7],
		"ground_kinds": {"plant": 5.0, "grass": 3.0, "mushroom": 1.0, "pebble": 2.0, "shrub": 1.0},
		"animals": {"stegosaurus": 1.0, "apatosaurus": 1.0, "parasaurolophus": 1.0, "triceratops": 1.0,
			"trex": 0.6, "velociraptor": 1.0},
	},
	# User request: a detailed snowfield and a detailed autumn wood - the
	# detailed trees, rocks and bushes made over for the season
	# (DerivedArt: pine_snow, oak_autumn, rock_snow, bush_autumn...).
	"snow": {
		"look": "detailed",
		"shore_extras": {"reeds": 0.06, "lilypad": 0.0, "driftwood": 0.06},
		"floor": ["snow", "gravel", 0.1],
		"trees": 24, "rocks": 7, "bushes": 3, "ground": 60,
		"tree_families": {"pine_snow": 3.0, "dead_snow": 1.0, "bare_snow": 1.5},
		"rock_pool": ["rock_snow"],
		"bush_families": ["bush_snow", "fern_snow"],
		"ground_kinds": {"pebble": 4.0, "grass": 1.0},
		"shore": {"grass": 0.05, "shrub": 0.0, "pebbles": 0.45},
		"animals": {"wolf": 2.0, "husky": 2.0, "stag": 1.0, "white_horse": 0.5, "fox": 1.0},
		"tint": Color(0.86, 0.95, 1.16),
		"water": {"base": Color(0.14, 0.28, 0.36), "deep": Color(0.03, 0.08, 0.14)},
	},
	"autumn": {
		"look": "detailed",
		"shore_extras": {"reeds": 0.14, "lilypad": 0.12, "driftwood": 0.03},
		"floor": ["leaf_litter", "grass", 0.3],
		"trees": 26, "rocks": 3, "bushes": 6, "ground": 110,
		"tree_families": {"maple": 2.0, "oak_autumn": 1.5, "birch": 1.2, "leafy_autumn": 1.0, "twisted": 0.5,
			"bare": 0.4},
		"rock_pool": [0, 1, 2],
		"bush_families": ["bush_autumn", "fern_autumn", "plant_autumn"],
		"ground_kinds": {"mushroom": 3.0, "grass": 2.0},
		# No green shrubs or flower bushes on the bank: mushrooms and grass.
		"cover": {"shrub": "mushroom", "flower_bush": "grass"},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 2.0, "wolf": 0.5},
		"tint": Color(1.1, 0.98, 0.86),
		"water": {"base": Color(0.12, 0.22, 0.24), "deep": Color(0.04, 0.07, 0.08)},
	},
	# User request: a beach - the user's coconut palms and crabs. Sand, a
	# turquoise lagoon, driftwood, sandstone boulders; crabs scuttle along
	# the water's edge instead of frogs and bugs, the surf in the air.
	# User request: the sea styles, from the user's photos - both a big
	# sweep of sea along one side of the map (no ponds, no docks), a beach
	# along it painted into the ground ("coast": its sand, the stones at the
	# water's edge, how wide each, 1 = sand only in patches).
	# A rocky coast (Akiya, Shimane): red-brown rock ridges running out into
	# the sea and sea stacks off them, a cobble beach with a little sand,
	# green scrub and trees behind.
	"beach_rocky": {
		"look": "detailed",
		"sea": true,
		"docks": false,
		"coast": {"sand": "beach_sand", "stones": "cobbles", "sand_width": 140.0, "stones_width": 75.0,
			"patches": 0.7},
		"shore_extras": {"reeds": 0.0, "lilypad": 0.0, "driftwood": 0.06},
		"floor": ["grass", "grass_light", 0.35],
		"trees": 14, "rocks": 8, "bushes": 8, "ground": 80,
		"ridges": 3,
		"sea_stacks": 7,
		"ridge_pool": [3, 4, 5, 6, 7],
		"rock_tint": Color(1.0, 0.8, 0.68),
		"tree_families": {"leafy": 1.0},
		"rock_pool": [3, 4, 5, 6, 7],
		"bush_families": ["fern", "plant"],
		"ground_kinds": {"grass": 3.0, "plant": 2.0, "pebble": 2.0},
		"cover": {"shrub": "plant", "flower_bush": "plant"},
		"shore": {"grass": 0.0, "shrub": 0.0, "pebbles": 0.35},
		"shore_critters": ["crab"],
		"shore_critter_count": 7,
		"animals": {"fox": 1.0, "shiba": 0.6, "deer": 0.6},
		"animal_count": 2,
		"tint": Color(1.02, 1.02, 0.98),
		"water": {"base": Color(0.1, 0.42, 0.42), "deep": Color(0.03, 0.16, 0.22)},
	},
	# A palm beach (Hualien-Taitung): a wide sand beach, coconut palms
	# along it, a strip of pebbles at the water, grass behind.
	"beach_sandy": {
		"look": "detailed",
		"sea": true,
		"docks": false,
		"coast": {"sand": "beach_sand", "stones": "cobbles", "sand_width": 300.0, "stones_width": 22.0,
			"patches": 0.0},
		"shore_extras": {"reeds": 0.0, "lilypad": 0.0, "driftwood": 0.12},
		"floor": ["grass_light", "grass", 0.3],
		"trees": 6, "rocks": 3, "bushes": 0, "ground": 50,
		"beach_trees": 22,
		"tree_families": {"coconut": 1.0},
		"rock_pool": [3, 4, 5, 6, 7],
		"bush_families": ["plant", "fern"],
		"ground_kinds": {"shells": 2.0, "pebble": 2.0, "grass": 1.0},
		"cover": {"shrub": "shells", "flower_bush": "shells"},
		"shore": {"grass": 0.0, "shrub": 0.0, "pebbles": 0.3},
		"shore_critters": ["crab"],
		"shore_critter_count": 9,
		"animals": {"shiba": 1.0, "white_horse": 0.6, "husky": 0.5},
		"animal_count": 2,
		"tint": Color(1.08, 1.03, 0.94),
		"water": {"base": Color(0.07, 0.38, 0.44), "deep": Color(0.02, 0.13, 0.22)},
	},

	# User request: a post-apocalyptic town, taken back by nature - its
	# streets, buildings, wrecks and junk laid out by TownBuilder; weeds,
	# trees and bushes in the empty lots, stray dogs, murky flooded
	# streets for ponds.
	"ruins": {
		"look": "detailed",
		"town": true,
		# User feedback: wooden jetties make no sense in a flooded town.
		"docks": false,
		"shore_extras": {"reeds": 0.12, "lilypad": 0.06, "driftwood": 0.03},
		"floor": ["grass", "dirt", 0.45],
		# Weeds and scrub, not a garden: no red bushes or bright shrubs.
		"trees": 12, "rocks": 2, "bushes": 5, "ground": 80,
		"tree_families": {"leafy": 1.0, "bare": 1.0, "dead": 0.7},
		"rock_pool": [0, 1, 2],
		"bush_families": ["fern", "plant"],
		"ground_kinds": {"grass": 5.0, "plant": 2.0, "pebble": 2.0, "clover": 1.0},
		"cover": {"shrub": "plant"},
		"animals": {"husky": 1.5, "shiba": 1.5, "fox": 1.0, "wolf": 0.6},
		"tint": Color(0.94, 0.98, 1.0),
		"water": {"base": Color(0.12, 0.17, 0.14), "deep": Color(0.04, 0.06, 0.05)},
	},
	# User request: many more map styles so the picture isn't monotonous,
	# from the user's packs (NatureCatalog, tools/render_packs.py). Each has
	# its own ground, light ("tint", multiplying the day's darkness), pond
	# colour ("water"), trees, rocks (catalog rock families by name),
	# bushes ("bush_families") and animals.
	"forest_conifer": {
		"look": "lowpoly",
		"floor": ["lp_forest", "lp_stone", 0.25],
		"trees": 28, "rocks": 4, "bushes": 5, "ground": 160,
		"tree_families": {"conifer": 1.0},
		"rock_pool": ["stone", "grey", "mossy"],
		"bush_families": ["lp_bush_dark"],
		"ground_kinds": {"lp_grass_dark": 4.0, "lp_fern_dark": 3.0, "lp_mushroom": 2.0, "lp_shrub_dark": 2.0,
			"lp_pebbles_moss": 1.0},
		"cover": {"grass": "lp_grass_dark", "shrub": "lp_shrub_dark", "flower_bush": "lp_fern_dark",
			"pebble": "lp_pebbles_moss", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"animals": {"deer": 2.0, "stag": 1.5, "wolf": 1.0, "fox": 1.0},
		"tint": Color(0.94, 1.0, 1.02),
	},
	"autumn_lowpoly": {
		"look": "lowpoly",
		"shore_extras": {"reeds": 0.12, "lilypad": 0.12, "driftwood": 0.02},
		"floor": ["lp_autumn", "lp_meadow", 0.15],
		"trees": 26, "rocks": 3, "bushes": 5, "ground": 160,
		"tree_families": {"autumn": 1.0},
		"rock_pool": ["stone", "mossy", "lp_lantern", "lp_shrine"],
		"bush_families": ["lp_bush_autumn"],
		"ground_kinds": {"lp_leaves": 4.0, "lp_grass_autumn": 3.0, "lp_mushroom": 2.0, "lp_shrub_autumn": 2.0},
		"cover": {"grass": "lp_grass_autumn", "shrub": "lp_shrub_autumn", "flower_bush": "lp_leaves",
			"pebble": "lp_pebbles", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"animals": {"deer": 2.0, "stag": 1.5, "fox": 2.0, "wolf": 0.5},
		"tint": Color(1.1, 0.98, 0.86),
		"water": {"base": Color(0.12, 0.22, 0.24), "deep": Color(0.04, 0.07, 0.08)},
	},
	"snow_lowpoly": {
		"look": "lowpoly",
		"shore_extras": {"reeds": 0.05, "lilypad": 0.0, "driftwood": 0.05},
		"floor": ["lp_snow", "lp_stone", 0.08],
		"trees": 24, "rocks": 6, "bushes": 3, "ground": 80,
		"tree_families": {"snow_pine": 3.0, "snow_bare": 1.2},
		"rock_pool": ["grey", "stone", "lp_grave"],
		"bush_families": ["lp_bush_snow"],
		"ground_kinds": {"lp_pebbles_snow": 4.0, "lp_grass_dry": 2.0},
		"cover": {"grass": "lp_grass_dry", "shrub": "lp_pebbles_snow", "flower_bush": "lp_grass_dry",
			"pebble": "lp_pebbles_snow", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"shore": {"grass": 0.12, "shrub": 0.0, "pebbles": 0.45},
		"animals": {"wolf": 2.0, "husky": 2.0, "stag": 1.0, "white_horse": 0.5, "fox": 1.0},
		"tint": Color(0.86, 0.95, 1.16),
		"water": {"base": Color(0.14, 0.28, 0.36), "deep": Color(0.03, 0.08, 0.14)},
	},
	"jungle": {
		"look": "lowpoly",
		"shore_extras": {"reeds": 0.16, "lilypad": 0.2, "driftwood": 0.02},
		"floor": ["lp_jungle", "lp_forest", 0.3],
		"trees": 26, "rocks": 3, "bushes": 10, "ground": 190,
		"tree_families": {"banana": 2.0, "palm2": 1.5, "sago": 1.2, "banyan": 0.5},
		"rock_pool": ["mossy", "stone"],
		"bush_families": ["monstera", "lp_bush_dark"],
		"ground_kinds": {"lp_fern": 4.0, "lp_grass_dark": 3.0, "lp_flowers": 1.0, "lp_mushroom": 1.0},
		"cover": {"grass": "lp_grass_dark", "shrub": "lp_fern", "flower_bush": "lp_flowers",
			"pebble": "lp_pebbles_moss", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"animals": {"fox": 1.0},
		"animal_count": 2,
		"tint": Color(0.9, 1.06, 0.94),
		"water": {"base": Color(0.07, 0.25, 0.2), "deep": Color(0.02, 0.08, 0.06)},
	},
	"savanna": {
		"look": "lowpoly",
		"shore_extras": {"reeds": 0.08, "lilypad": 0.03, "driftwood": 0.05},
		"floor": ["lp_savanna", "lp_autumn", 0.12],
		"trees": 12, "rocks": 8, "bushes": 4, "ground": 130,
		"tree_families": {"baobab": 3.0, "sago": 0.6},
		"rock_pool": ["red"],
		"bush_families": ["rock_bush", "lp_bush_dry"],
		"ground_kinds": {"lp_grass_dry": 5.0, "lp_pebbles_red": 3.0, "lp_shrub_dry": 1.0},
		"cover": {"grass": "lp_grass_dry", "shrub": "lp_shrub_dry", "flower_bush": "lp_grass_dry",
			"pebble": "lp_pebbles_red", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"animals": {"alpaca": 1.5, "donkey": 1.5, "horse": 1.0, "bull": 1.0},
		"tint": Color(1.12, 1.0, 0.84),
		"water": {"base": Color(0.18, 0.22, 0.16), "deep": Color(0.06, 0.07, 0.04)},
	},
	"meadow": {
		"look": "lowpoly",
		"shore_extras": {"reeds": 0.12, "lilypad": 0.16, "driftwood": 0.01},
		"floor": ["lp_meadow", "lp_forest", 0.1],
		"trees": 14, "rocks": 2, "bushes": 6, "ground": 240,
		"tree_families": {"meadow": 2.0, "round": 2.0},
		"rock_pool": ["stone", "grey"],
		"bush_families": ["rock_bush", "lp_bush"],
		"ground_kinds": {"lp_grass": 4.0, "lp_flowers": 4.0, "lp_shrub": 1.0, "lp_mushroom": 0.5},
		"cover": {"grass": "lp_grass", "shrub": "lp_shrub", "flower_bush": "lp_flowers",
			"pebble": "lp_pebbles", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"animals": {"cow": 1.5, "horse": 1.0, "white_horse": 1.0, "alpaca": 1.0, "shiba": 1.0},
		"tint": Color(1.04, 1.06, 0.98),
	},
	"stone_forest": {
		"look": "lowpoly",
		"shore_extras": {"reeds": 0.1, "lilypad": 0.22, "driftwood": 0.02},
		"floor": ["lp_stone", "lp_forest", 0.3],
		"trees": 14, "rocks": 22, "bushes": 2, "ground": 140,
		"tree_families": {"bonsai": 1.0},
		"rock_pool": ["pillar", "grey", "stone", "lp_lantern", "lp_shrine"],
		"bush_families": ["lp_bush_dark"],
		"ground_kinds": {"lp_grass_dark": 3.0, "lp_pebbles_moss": 3.0, "lp_fern_dark": 1.0, "lp_mushroom": 1.0},
		"cover": {"grass": "lp_grass_dark", "shrub": "lp_shrub_dark", "flower_bush": "lp_fern_dark",
			"pebble": "lp_pebbles_moss", "reeds": "lp_reeds", "driftwood": "lp_driftwood"},
		"animals": {"stag": 1.5, "fox": 1.0, "white_horse": 1.0, "wolf": 1.0},
		"tint": Color(0.92, 1.0, 0.98),
		"water": {"base": Color(0.1, 0.28, 0.26), "deep": Color(0.02, 0.08, 0.08)},
	},
	"swamp": {
		"look": "detailed",
		"shore_extras": {"reeds": 0.4, "lilypad": 0.28, "driftwood": 0.05},
		"floor": ["mud", "moss_soil", 0.35],
		"trees": 22, "rocks": 6, "bushes": 4, "ground": 90,
		"tree_families": {"dead": 1.0, "twisted": 1.0, "bare": 1.0},
		"rock_pool": [0, 1, 2, "grave"],
		"ground_kinds": {"grass": 3.0, "mushroom": 3.0, "plant": 2.0},
		"animals": {"wolf": 1.5, "fox": 1.0},
		"animal_count": 4,
		"tint": Color(0.92, 1.04, 0.84),
		"water": {"base": Color(0.1, 0.15, 0.08), "deep": Color(0.03, 0.05, 0.02)},
	},
}
## Forest looks share one pick with the other styles. User decision: the
## three main styles ~28% each, tropical 12%, prehistoric (dinosaurs) 4%.
## User request (more styles): the new ones share the odds now - every
## style about as likely, dinosaurs still rare. User decision: only the
## detailed look is played for now (forest ~18%, dead wood, snow and
## autumn ~13% each, beach and rocky ~11% each, tropical ~9%, swamp ~8%,
## prehistoric ~4%).
const STYLES := {
	"forest": {"weight": 14.0, "themes": ["forest_pine", "forest_birch", "forest_maple", "forest_green"]},
	"deadwood": {"weight": 10.0, "themes": ["deadwood"]},
	"rocky": {"weight": 9.0, "themes": ["rocky"]},
	"tropical": {"weight": 7.0, "themes": ["tropical"]},
	"prehistoric": {"weight": 3.0, "themes": ["prehistoric"]},
	"swamp": {"weight": 6.0, "themes": ["swamp"]},
	"snow": {"weight": 10.0, "themes": ["snow"]},
	"autumn": {"weight": 10.0, "themes": ["autumn"]},
	"beach": {"weight": 9.0, "themes": ["beach_rocky", "beach_sandy"]},
	"ruins": {"weight": 10.0, "themes": ["ruins"]},
}
## User decision: the low-poly styles are kept in reserve - built and
## tested (forced_theme still reaches them) but never dealt to a player.
## Move one into STYLES (with a weight) to put it back in play.
const RESERVE_STYLES := {
	"forest_conifer": {"weight": 5.0, "themes": ["forest_conifer"]},
	"autumn_lowpoly": {"weight": 11.0, "themes": ["autumn_lowpoly"]},
	"snow_lowpoly": {"weight": 11.0, "themes": ["snow_lowpoly"]},
	"jungle": {"weight": 9.0, "themes": ["jungle"]},
	"savanna": {"weight": 7.0, "themes": ["savanna"]},
	"meadow": {"weight": 8.0, "themes": ["meadow"]},
	"stone_forest": {"weight": 7.0, "themes": ["stone_forest"]},
}

## User feedback: the water's edge is grass, small shrubs, pebbles and
## boardwalks (no big trees or boulders there), with bugs and frogs about.
## Per shore sample: chance of a grass clump / low shrub / pebbles.
const SHORE_ODDS := {"grass": 0.5, "shrub": 0.16, "pebbles": 0.2}
## User request (water plants): per shore sample, on top of the above - a
## reed clump at the waterline, lily pads out on the water, a washed-up
## log. Themes override with "shore_extras".
const SHORE_EXTRAS := {"reeds": 0.12, "lilypad": 0.08, "driftwood": 0.015}
const SHORE_HIDE_BUSH_CHANCE := 0.25  # of shrubs: a bush you can hide in
const SHORE_CRITTERS := ["frog", "frog", "spider", "wasp"]
const SHORE_CRITTER_COUNT := 5

## Dead-wood footpaths: stepping stones every PATH_STEP px, meandering.
const PATH_STEP := 17.0
const PATH_CLEARANCE := 24.0
const PATH_STYLES := [
	["rock_path_1", "rock_path_2", "rock_path_3", "rock_path_round_thin", "rock_path_round_wide"],
	["rock_path_square_1", "rock_path_square_2", "rock_path_square_3", "rock_path_square_thin", "rock_path_square_wide"],
]
const SHORE_SPACING := 26.0
const SHORE_CLEAR_OF_SPAWN := 160.0

## Testing hook: set before Main loads to force a theme (screenshot tools).
static var forced_theme := ""

var theme_name := ""
var theme: Dictionary = {}
## The ruined town's streets and buildings (a theme with "town").
var town: TownBuilder
var _walk_rects: Array[Rect2] = []
## Just outside each walkway's way on - kept clear of trees and rocks.
var _entrances: Array[Vector2] = []
const ENTRANCE_CLEARANCE := 60.0
var _path_points: Array[Vector2] = []
const CRITTER_SCENE := preload("res://scenes/critter.tscn")
## User decision: 6 catchable critters by day, more come out at night.
const CRITTER_COUNT := 6
const NIGHT_CRITTER_COUNT := 6
## User decision: ambient animals follow the map style, ~8 per map.
const AMBIENT_ANIMAL_COUNT := 8

var water_zones: Array = []
## Which map edge a "sea" theme's sea lies along.
var sea_side := Vector2.ZERO


func _ready() -> void:
	theme_name = forced_theme if forced_theme != "" else _pick_theme()
	theme = THEMES[theme_name]
	var ground: CanvasItem = get_parent().get_node_or_null("GroundBackground")
	if ground != null:
		ground.material = _ground_material()
	var darkness := get_parent().get_node_or_null("Darkness")
	if darkness != null and "tint" in darkness:
		darkness.tint = theme.get("tint", Color.WHITE)
	WaterZone.theme_water = theme.get("water", {})
	GameState.night_fell.connect(_on_night_fell)
	_generate_water_zones()
	if theme.get("docks", true):
		_place_docks()
	_place_altar_and_escape()
	if theme.get("town", false):
		town = TownBuilder.new(self)
		town.build(get_parent())
		_lay_streets(ground)
	if theme.has("coast"):
		_lay_coast(ground)
	if theme.get("paths", false):
		_lay_stone_paths()
	# Docks and shores before the trees and rocks, so those can keep clear
	# of every walkway entrance.
	_place_rock_ridges()
	_place_sea_stacks()
	_line_the_beach()
	_dress_shores()
	_scatter_props()
	_scatter_themed_props()
	_scatter_flip_rocks()
	_scatter_ground_cover()
	_scatter_critters()


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


## The town's streets over the ground: asphalt and paving where
## TownBuilder's street map says (see shaders/ground.gdshader).
func _lay_streets(ground: CanvasItem) -> void:
	if ground == null or not (ground.material is ShaderMaterial):
		return
	var mat: ShaderMaterial = ground.material
	mat.set_shader_parameter("streets_on", true)
	mat.set_shader_parameter("streets", town.street_map())
	mat.set_shader_parameter("world_size", Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT))
	for slot in [["road", "asphalt"], ["walk", "sidewalk"]]:
		mat.set_shader_parameter("albedo_" + slot[0], load("res://assets/sprites/ground/%s_albedo.png" % slot[1]))
		mat.set_shader_parameter("normal_" + slot[0], load("res://assets/sprites/ground/%s_normal.png" % slot[1]))


func _pick_theme() -> String:
	var total := 0.0
	for style in STYLES.values():
		total += style.weight
	var roll := randf() * total
	for style in STYLES.values():
		roll -= style.weight
		if roll <= 0.0:
			return style.themes.pick_random()
	return STYLES.forest.themes.pick_random()


func _generate_water_zones() -> void:
	if theme.get("sea", false):
		_generate_sea()
	# The rare one first: it's smaller and solid, so it gets its pick.
	for _i in range(RARE_ZONE_COUNT):
		_spawn_zone(WaterZone.ZoneType.RARE, randf_range(RARE_RADIUS_MIN, RARE_RADIUS_MAX), RARE_EXTRA_LOBES)
	if theme.get("sea", false):
		return
	for _i in range(randi_range(COMMON_ZONE_COUNT.x, COMMON_ZONE_COUNT.y)):
		_spawn_zone(WaterZone.ZoneType.COMMON, randf_range(COMMON_RADIUS_MIN, COMMON_RADIUS_MAX), COMMON_EXTRA_LOBES)


## User request: the beach's water is the sea - one great sweep of it
## along one side of the map, a good third of the view, its coast one long
## wavy line. Made of big common zones in a row along that edge, reaching
## off the map, overlapping so their shores merge (and baked coarser).
func _generate_sea() -> void:
	var w := Player.WORLD_WIDTH
	var h := Player.WORLD_HEIGHT
	sea_side = [Vector2.DOWN, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP].pick_random()
	var across := sea_side.y != 0.0  # the coast runs across the map
	var length := w if across else h
	# How far in from the edge the water comes.
	var reach := randf_range(SEA_REACH.x, SEA_REACH.y) * (h if across else w)
	var r := maxf(SEA_RADIUS, reach * 0.62)
	var n := int(ceil(length / (r * 1.3))) + 1
	for i in n:
		var t := (float(i) + randf_range(-0.15, 0.15)) * length / float(n - 1)
		var inland := reach - r + randf_range(-SEA_WOBBLE, SEA_WOBBLE)
		var pos: Vector2
		match sea_side:
			Vector2.DOWN: pos = Vector2(t, h - inland)
			Vector2.UP: pos = Vector2(t, inland)
			Vector2.LEFT: pos = Vector2(inland, t)
			_: pos = Vector2(w - inland, t)
		# Near the spawn point the sea draws back (a bay) rather than leave
		# a gap in the coast.
		for _step in 12:
			if pos.distance_to(SPAWN_POS) - r >= SPAWN_CLEAR_RADIUS:
				break
			pos += sea_side * 40.0
		# Lobes for a ragged coast - none reaching up to the spawn point.
		var lobes: Array[Vector3] = []
		for lobe in _make_lobes(r, SEA_LOBES):
			if (pos + Vector2(lobe.x, lobe.y)).distance_to(SPAWN_POS) - lobe.z >= SPAWN_CLEAR_RADIUS:
				lobes.append(lobe)
		var zone: WaterZone = WATER_ZONE_SCENE.instantiate()
		zone.field_texel = SEA_FIELD_TEXEL
		zone.setup(WaterZone.ZoneType.COMMON, r, pos, lobes)
		get_parent().add_child.call_deferred(zone)
		water_zones.append(zone)


## The ground shader's beach: a map of the distance from the sea (the
## common zones), COAST_TEXEL px a texel, 0..COAST_RANGE; the sand and the
## stones from the theme's "coast". (About 0.1 s.)
func _lay_coast(ground: CanvasItem) -> void:
	if ground == null or not (ground.material is ShaderMaterial):
		return
	var seas: Array = water_zones.filter(func(z): return not z.is_rare())
	var size := Vector2i(ceili(Player.WORLD_WIDTH / COAST_TEXEL), ceili(Player.WORLD_HEIGHT / COAST_TEXEL))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for y in size.y:
		for x in size.x:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) * COAST_TEXEL
			var d := COAST_RANGE
			for zone in seas:
				if zone.global_position.distance_to(p) - zone.radius < d:
					d = minf(d, zone.distance_to_edge(p))
			img.set_pixel(x, y, Color(d / COAST_RANGE, 0.0, 0.0))
	var coast: Dictionary = theme.coast
	var mat: ShaderMaterial = ground.material
	mat.set_shader_parameter("coast_on", true)
	mat.set_shader_parameter("streets", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("world_size", Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT))
	mat.set_shader_parameter("coast_range", COAST_RANGE)
	mat.set_shader_parameter("sand_width", coast.sand_width)
	mat.set_shader_parameter("stones_width", coast.stones_width)
	mat.set_shader_parameter("sand_patches", coast.patches)
	for slot in [["road", coast.sand], ["walk", coast.stones]]:
		mat.set_shader_parameter("albedo_" + slot[0], load("res://assets/sprites/ground/%s_albedo.png" % slot[1]))
		mat.set_shader_parameter("normal_" + slot[0], load("res://assets/sprites/ground/%s_normal.png" % slot[1]))


## How far `pos` is from the sea (the common zones).
func _sea_distance(pos: Vector2) -> float:
	var best := INF
	for zone in water_zones:
		if not zone.is_rare():
			best = minf(best, zone.distance_to_edge(pos))
	return best


## User request (a palm beach): the coconut palms stand along the beach,
## between the pebbles at the water and the grass behind.
func _line_the_beach() -> void:
	var count: int = theme.get("beach_trees", 0)
	if count == 0:
		return
	var band: float = theme.coast.sand_width
	var made := 0
	for _try in count * 40:
		if made >= count:
			break
		var pos := Vector2(randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN))
		var d := _sea_distance(pos)
		if d < 45.0 or d > band - 30.0 or pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		if _in_any_water(pos) or _themed_spots.any(func(s): return s.distance_to(pos) < 70.0):
			continue
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.position = pos
		_theme_prop(tree)
		get_parent().add_child.call_deferred(tree)
		_themed_spots.append(pos)
		made += 1


## User request (a rocky coast): sea stacks - big rocks standing out in
## the shallows off the coast.
func _place_sea_stacks() -> void:
	var seas: Array = water_zones.filter(func(z): return not z.is_rare())
	if seas.is_empty():
		return
	var made := 0
	for _try in 80:
		if made >= theme.get("sea_stacks", 0):
			break
		var zone: WaterZone = seas.pick_random()
		var samples: Array = zone.shore_samples(50.0)
		if samples.is_empty():
			continue
		var sample: Array = samples.pick_random()
		var pos: Vector2 = sample[0] - (sample[1] as Vector2) * randf_range(40.0, 140.0)
		if not _inside_map(pos, 40.0) or not _in_any_water(pos) \
				or _themed_spots.any(func(s): return s.distance_to(pos) < 90.0):
			continue
		for k in randi_range(1, 3):
			var rock: Node2D = OBSTACLE_SCENE.instantiate()
			rock.position = pos + Vector2(randf_range(-30.0, 30.0), randf_range(-18.0, 18.0)) * float(k)
			rock.size = randf_range(1.5, 2.3) / (1.0 + 0.3 * k)
			rock.variant_pool = theme.get("ridge_pool", theme.get("rock_pool", []))
			rock.modulate = theme.get("rock_tint", Color.WHITE)
			get_parent().add_child.call_deferred(rock)
			_themed_spots.append(rock.position)
		made += 1


## User request: big rocks across the beach break up the way along it, so
## it reads as a coastline: ridges of large boulders running in from the
## sea (starting in the shallows), each open at its landward end so there's
## always a way round.
func _place_rock_ridges() -> void:
	var seas: Array = water_zones.filter(func(z): return not z.is_rare())
	if seas.is_empty():
		return
	var fixed := [SPAWN_POS]
	for name in ["Altar", "EscapePoint", "GhostCage"]:
		var node: Node2D = get_parent().get_node_or_null(name)
		if node != null:
			fixed.append(node.global_position)
	var made := 0
	for _try in 60:
		if made >= theme.get("ridges", 0):
			break
		var zone: WaterZone = seas.pick_random()
		var samples: Array = zone.shore_samples(40.0)
		if samples.is_empty():
			continue
		var sample: Array = samples.pick_random()
		var shore: Vector2 = sample[0]
		if not _inside_map(shore, 80.0) or _in_any_water(shore + sample[1] * 20.0):
			continue
		# Inland, roughly away from the sea.
		var dir: Vector2 = (sample[1] as Vector2 - sea_side).normalized().rotated(randf_range(-0.4, 0.4))
		var land := (Player.WORLD_HEIGHT if sea_side.y != 0.0 else Player.WORLD_WIDTH) \
				- absf(shore.dot(sea_side)) if sea_side.x + sea_side.y < 0.0 else absf(shore.dot(sea_side))
		var length := randf_range(RIDGE_LENGTH.x, RIDGE_LENGTH.y) * land
		var start := shore - dir * 50.0
		var end := shore + dir * length
		# Room to walk round its landward end.
		if not _inside_map(end, 160.0):
			continue
		var clear := true
		for f in fixed:
			var closest := Geometry2D.get_closest_point_to_segment(f, start, end)
			if closest.distance_to(f) < (SPAWN_CLEAR_RADIUS if f == SPAWN_POS else 120.0):
				clear = false
		for spot in _themed_spots:
			if Geometry2D.get_closest_point_to_segment(spot, start, end).distance_to(spot) < 90.0:
				clear = false
		if not clear:
			continue
		var d := 0.0
		var total := start.distance_to(end)
		while d <= total:
			var t := d / total
			var rock: Node2D = OBSTACLE_SCENE.instantiate()
			rock.position = start + dir * d + dir.orthogonal() * randf_range(-14.0, 14.0)
			# Biggest out by the water, smaller toward the land.
			rock.size = lerpf(RIDGE_SIZE.y, RIDGE_SIZE.x, t) * randf_range(0.9, 1.1)
			rock.variant_pool = theme.get("ridge_pool", theme.get("rock_pool", []))
			rock.modulate = theme.get("rock_tint", Color.WHITE)
			get_parent().add_child.call_deferred(rock)
			_themed_spots.append(rock.position)
			d += randf_range(34.0, 46.0) * rock.size / RIDGE_SIZE.y
		made += 1


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


func _spawn_zone(type: int, radius: float, lobe_range: Vector2i) -> void:
	var lobes := _make_lobes(radius, lobe_range)
	# User bug report: the spawn point ended up under water (about 1 map in
	# 25) - when no spot was found, the last random one was used anyway. Now
	# a pond that doesn't fit shrinks and tries again, and is left out if it
	# still doesn't.
	var pos := Vector2.INF
	for _shrink in 3:
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
func _place_docks() -> void:
	var commons: Array = water_zones.filter(func(z): return not z.is_rare())
	commons.shuffle()
	# User request: every common pond gets a dock out into deep water (some
	# get two, on different sides) - no boardwalks lying along the bank.
	var jobs := []
	for zone in commons:
		jobs.append(zone)
	for zone in commons:
		if randf() < SECOND_DOCK_CHANCE:
			jobs.append(zone)
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
		if pos.distance_to(SPAWN_POS) < SPAWN_CLEAR_RADIUS + radius:
			continue
		var overlaps := false
		for zone in water_zones:
			if pos.distance_to(zone.global_position) < radius + zone.radius + ZONE_MIN_GAP:
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
		willow.global_position = altar.global_position + WILLOW_BESIDE_ALTAR
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
	for _try in range(60):
		var pos := Vector2(
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_WIDTH - FIXED_POINT_MARGIN),
			randf_range(FIXED_POINT_MARGIN, Player.WORLD_HEIGHT - FIXED_POINT_MARGIN)
		)
		var spread := INF
		for p in avoid:
			spread = minf(spread, pos.distance_to(p))
		var shore := _shore_distance(pos)
		if spread >= FIXED_POINT_MIN_SEPARATION and shore > 50.0:
			return pos
		var score := minf(spread / FIXED_POINT_MIN_SEPARATION, 1.0) + (1.0 if shore > 50.0 else -2.0)
		if score > best_score:
			best_score = score
			best = pos
	return best


## Distance to the nearest water (0 when inside it).
func _shore_distance(pos: Vector2) -> float:
	var best := INF
	for zone in water_zones:
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
	var placed: Array = []
	for prop_name in PROP_NAMES:
		var prop: Node2D = get_parent().get_node_or_null(prop_name)
		if prop == null:
			continue
		var pos := _pick_prop_position(placed)
		prop.global_position = pos
		placed.append(pos)
		# Scene props haven't run _ready yet (this node is Main's first
		# child), so the theme still decides what they become.
		_theme_prop(prop)


## Spots taken by the themed props (the flip rocks keep clear of them too).
var _themed_spots: Array = []


func _scatter_flip_rocks() -> void:
	for _i in randi_range(FLIP_ROCKS.x, FLIP_ROCKS.y):
		var rock: Node2D = FLIP_ROCK_SCENE.instantiate()
		rock.position = _pick_prop_position(_themed_spots)
		_themed_spots.append(rock.position)
		# Small stones to turn over - not the standing slabs or the props.
		rock.variant_pool = theme.rock_pool.filter(func(e): return not (e is String and e in NOT_FLIPPABLE))
		get_parent().add_child.call_deferred(rock)


func _theme_prop(prop: Node) -> void:
	if "family_weights" in prop:
		prop.family_weights = theme.tree_families
	elif "variant_pool" in prop:
		prop.variant_pool = theme.rock_pool
		prop.modulate = theme.get("rock_tint", Color.WHITE)
	elif "families" in prop:
		prop.families = theme.get("bush_families", [])


## The theme's extra trees, rocks and bushes, spaced like the scene props.
func _scatter_themed_props() -> void:
	var placed: Array = _themed_spots
	for spec in [[TREE_SCENE, theme.trees], [OBSTACLE_SCENE, theme.rocks], [BUSH_SCENE, theme.bushes]]:
		for _i in spec[1]:
			var prop: Node2D = spec[0].instantiate()
			prop.position = _pick_prop_position(placed)
			placed.append(prop.position)
			_theme_prop(prop)
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
					or _near_walkway(p, 26.0) or _near_path(p, PATH_CLEARANCE):
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
				if randf() < SHORE_HIDE_BUSH_CHANCE:
					var bush: Node2D = BUSH_SCENE.instantiate()
					bush.position = pos + n * 10.0
					_theme_prop(bush)
					get_parent().add_child.call_deferred(bush)
				else:
					_add_ground_cover(pos, ["shrub", "flower_bush"].pick_random())
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
		var critter: Critter = CRITTER_SCENE.instantiate()
		critter.species = theme.get("shore_critters", SHORE_CRITTERS).pick_random()
		critter.position = pos
		get_parent().add_child.call_deferred(critter)


## User feedback: dead wood gets proper footpaths - a meandering line of
## stepping stones in one style from the spawn clearing to the bank of
## each common pond, not stray stones.
func _lay_stone_paths() -> void:
	for zone in water_zones:
		if zone.is_rare():
			continue
		var style: Array = PATH_STYLES.pick_random()
		var dir: Vector2 = (zone.global_position - SPAWN_POS).normalized()
		var start := SPAWN_POS + dir * 70.0
		# End on the bank just short of the water, facing the spawn.
		var end: Vector2 = zone.shore_point(-dir) - dir * 12.0
		var length := start.distance_to(end)
		if length < 60.0:
			continue
		var side := dir.orthogonal()
		var amp := randf_range(18.0, 45.0)
		var waves := randf_range(1.0, 2.5)
		var phase := randf() * TAU
		var steps := int(length / PATH_STEP)
		for i in range(steps + 1):
			var t := float(i) / steps
			# Meander, pinned straight at both ends.
			var sway := sin(t * PI * waves + phase) * amp * sin(t * PI)
			var p := start.lerp(end, t) + side * sway
			if _shore_distance(p) < 4.0 or not _inside_map(p, 20.0):
				continue
			_path_points.append(p)
			var stone: Node2D = GROUND_COVER_SCENE.instantiate()
			stone.position = p + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
			stone.kind_override = "path_stone"
			stone.variant_choices = style
			get_parent().add_child.call_deferred(stone)


func _near_path(pos: Vector2, margin: float) -> bool:
	for p in _path_points:
		if p.distance_to(pos) < margin:
			return true
	return false


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
		for _try in range(15):
			pos = Vector2(
				randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
				randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
			)
			if not _in_any_water(pos) and not _near_path(pos, 14.0):
				break
		var plant: Node2D = GROUND_COVER_SCENE.instantiate()
		plant.position = pos
		plant.kind_weights = theme.ground_kinds
		# Main is still mid-setup here; see _spawn_zone().
		get_parent().add_child.call_deferred(plant)


## User request: small animals to catch as bait, spread around the map
## (kept off the spawn point so the first few seconds aren't a chase).
func _scatter_critters() -> void:
	for _i in range(CRITTER_COUNT):
		var pos := _pick_prop_position([])
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
		animal.position = _pick_prop_position([])
		get_parent().add_child.call_deferred(animal)


## Extra catchable critters come out at nightfall, away from the player.
func _on_night_fell() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	for _i in range(NIGHT_CRITTER_COUNT):
		var pos := _pick_prop_position([])
		for _try in range(6):
			if player == null or pos.distance_to(player.global_position) > 250.0:
				break
			pos = _pick_prop_position([])
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


func _pick_prop_position(placed: Array) -> Vector2:
	var fallback := Vector2(-1, -1)
	for _try in range(60):
		var pos := Vector2(
			randf_range(PROP_MARGIN, Player.WORLD_WIDTH - PROP_MARGIN),
			randf_range(PROP_MARGIN, Player.WORLD_HEIGHT - PROP_MARGIN)
		)
		if pos.distance_to(SPAWN_POS) < PROP_AVOID_SPAWN_RADIUS:
			continue
		# Not in the town's streets or buildings.
		if town != null and town.blocked(pos, 24.0):
			continue
		# Clear of the water with room for a rock's footprint or a trunk,
		# and off any footpath.
		if _shore_distance(pos) < 30.0 or _near_path(pos, PATH_CLEARANCE + 10.0):
			continue
		# User bug report: rocks were landing across a boardwalk's way on.
		if _near_entrance(pos, ENTRANCE_CLEARANCE) or _near_walkway(pos, 30.0):
			continue
		if fallback.x < 0.0:
			fallback = pos
		var too_close := false
		for p in placed:
			if pos.distance_to(p) < PROP_MIN_SEPARATION:
				too_close = true
				break
		if not too_close:
			return pos
	# Crowded: staying out of the water beats the spacing rule.
	return fallback if fallback.x >= 0.0 else Vector2(PROP_MARGIN, PROP_MARGIN)
