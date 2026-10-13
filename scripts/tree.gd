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
const KINDS := {"pine_b": 0.8, "pine_c": 0.94}
const SCALE := Vector2(0.78, 1.0)
## (pine_b's lowest branches are at 2.87 m: not under 0.9, so they clear
## the big ghost's 2.3 m)
const SCALE_OF := {"pine_b": Vector2(0.9, 1.0), "pine_c": Vector2(0.78, 1.0)}
## Its branches' reach (m, at scale 1).
const CANOPY := {"pine_b": 3.44, "pine_c": 3.26}
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


## Which pine and how big (from `roll`, any number).
func pick(roll: int) -> void:
	var kinds := KINDS.keys()
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
func chop(_from: Vector2, power: int) -> Dictionary:
	chopped = true
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
