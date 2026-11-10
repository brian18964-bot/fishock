class_name MapTree
extends Node2D

## A pine of the lakeside forest (user decision: the game is 3D now -
## RunView3D shows it as a pine model, CampModel's; this is its place, its
## trunk's solid base and what a chop does, no picture). Which pine and how
## big are picked here, so the trunk's base is as wide as the model's
## (user request: nothing walks into anything). Only the pines whose
## lowest branches clear the character's head (KINDS).

## The pines (CampModel.tree_mesh) and their trunks' radius at the ground
## (m, at scale 1 - the root flare); the size range.
const KINDS := {"pine_b": 0.8, "pine_c": 0.94,
	"autumn_a": 0.47, "autumn_b": 0.49, "autumn_c": 0.47, "autumn_d": 0.42, "dead_a": 1.05, "dead_b": 1.41,
	"dead_c": 0.57, "dead_d": 0.67, "dead_e": 0.57}
const SCALE := Vector2(0.78, 1.0)
## (pine_b's lowest branches are at 2.87 m: not under 0.9, so they clear
## the big ghost's 2.3 m; dead_b's at 2.39 m: not under 1.0; dead_d's 2.14 m: not under 1.1)
const SCALE_OF := {"pine_b": Vector2(0.9, 1.0), "pine_c": Vector2(0.78, 1.0),
	"autumn_a": Vector2(0.85, 1.05), "autumn_b": Vector2(0.85, 1.05), "autumn_c": Vector2(0.85, 1.0),
	"autumn_d": Vector2(0.8, 0.95), "dead_a": Vector2(0.85, 1.0), "dead_b": Vector2(1.0, 1.1),
	"dead_c": Vector2(0.85, 1.0), "dead_d": Vector2(1.1, 1.2), "dead_e": Vector2(0.85, 1.05)}
## Its branches' reach (m, at scale 1).
const CANOPY := {"pine_b": 3.44, "pine_c": 3.26,
	"autumn_a": 4.54, "autumn_b": 3.98, "autumn_c": 4.39, "autumn_d": 5.84, "dead_a": 2.47, "dead_b": 2.85,
	"dead_c": 4.1, "dead_d": 4.2, "dead_e": 3.78}
## User request (the autumn map - bare, dead trees, few with their last leaves): its own trees
## (tools/make_autumn_trees.py; the camp's two dead ones and, user request, three more made from
## them - tools/make_dead_variants.py, two with the autumn trees' leaves), the bare ones likelier.
## A map style not here has the pines.
const THEME_KINDS := {
	"autumn": ["autumn_a", "autumn_b", "autumn_b", "autumn_c", "autumn_d", "dead_a", "dead_b", "dead_c", "dead_c",
		"dead_d", "dead_e"],
}
const PINES := ["pine_b", "pine_c"]
const PX := 27.108

var kind := "pine_b"
var tree_scale := 0.9
## The trunk's base (px).
var trunk_radius := 20.0
## Kind and size already chosen (map_generator picks them first, to space
## the trees by their branches).
var picked := false


## User request (the hatchet and the machete): chopped once a run (see
## chop()).
var chopped := false
## What a chop turns up, by the weapon's chop power (Profile.WEAPONS):
## [black spider, bait].
const CHOP_ODDS := {1: [0.22, 0.3], 2: [0.28, 0.45]}
const CHOP_BAIT := ["蟲子", "蟲子", "蚯蚓"]


func _ready() -> void:
	add_to_group("trees")
	add_to_group("solids")
	if not picked:
		pick(absi(hash(name + str(global_position))))
	trunk_radius = float(KINDS[kind]) * tree_scale * PX
	var trunk := CircleShape2D.new()
	trunk.radius = trunk_radius
	$TrunkBody.position = Vector2.ZERO
	$TrunkBody/CollisionShape2D.shape = trunk
	for n in [$TrunkBody/LightOccluder2D, $Canopy/Visual]:
		n.queue_free()


## The trees a map style grows (the pines, but for THEME_KINDS's).
static func kinds_for(theme: String) -> Array:
	return THEME_KINDS.get(theme, PINES)


## Which tree and how big (from `roll`, any number) - one of this map's (kinds_for).
func pick(roll: int) -> void:
	var kinds := kinds_for(MapGenerator.current_theme)
	kind = kinds[roll % kinds.size()]
	var lo: Vector2 = SCALE_OF.get(kind, SCALE)
	tree_scale = lo.x + (lo.y - lo.x) * float((roll / 7) % 1000) / 999.0
	picked = true


## How far its branches reach (px) - for spacing them (no two trees'
## branches through each other; none over the fishing bank).
static func canopy_of(which: String, s: float) -> float:
	return float(CANOPY.get(which, 3.44)) * s * PX


func canopy() -> float:
	return canopy_of(kind, tree_scale)


func solids() -> Array:
	return [[global_position, Vector2(trunk_radius, trunk_radius)]]


## A chop (Player._chop_tree): the tree shudders and says what fell out -
## {"spider": true}, {"found": true, "flavor": ...} or {"found": false}.
## A chop landed (from where - RunView3D shakes the tree's model away from it).
signal chopped_by(from: Vector2)


func chop(_from: Vector2, power: int) -> Dictionary:
	chopped = true
	chopped_by.emit(_from)
	Sfx.play_at("chop", global_position, -2.0)
	var canopy: Node2D = $Canopy
	var t := create_tween()
	for a in [0.05, -0.04, 0.025, -0.012, 0.0]:
		t.tween_property(canopy, "rotation", a, 0.09).set_trans(Tween.TRANS_SINE)
	var odds: Array = CHOP_ODDS.get(clampi(power, 1, 2))
	if randf() < float(odds[0]):
		return {"found": false, "spider": true}
	if randf() < float(odds[1]):
		return {"found": true, "flavor": CHOP_BAIT.pick_random()}
	return {"found": false}
