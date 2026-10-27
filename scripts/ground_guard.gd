class_name GroundGuard
extends SkeletonModifier3D

## User report: nothing may go into the ground. Some characters' clips
## (made on another body - the Taiwan black bear's, the cat's) put their
## knees, hips and feet under it - kneeling, crouching, sat or lying on the
## ground - and any character's legs dip through it for a moment as one clip
## blends into another. Each frame, after the clips (and SeatFit), the
## lowest of its parts is looked at, each against how high its own bone sits
## over the ground when the skin is just on it (FLOORS: the lowest the
## well-made clips ever take them - the camp's clipping check); one under,
## the whole body (from the hips) goes up by the most any is under. Eased
## down again, so a step's dip doesn't make it bob.

## Bone: the least it's ever over the ground (m, the model's own).
const FLOORS := {
	"ball_l": 0.0, "ball_r": 0.0, "foot_l": 0.04, "foot_r": 0.04, "calf_l": 0.04, "calf_r": 0.04,
	"pelvis": 0.10, "spine_01": 0.12, "spine_02": 0.12, "spine_03": 0.12,
	"hand_l": 0.06, "hand_r": 0.06, "Head": 0.15,
}
## How fast the lift lets go again (m/s; up it goes at once).
const SETTLE := 0.4

## The ground's height is this node's (the rig's own place).
var ground: Node3D
## How far up it is now (m).
var lift := 0.0

var _bones := {}
var _pelvis := -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or ground == null:
		return
	if _pelvis < 0:
		_pelvis = sk.find_bone("pelvis")
		for n in FLOORS:
			var b := sk.find_bone(n)
			if b >= 0:
				_bones[b] = FLOORS[n]
		if _pelvis < 0:
			return
	var k := ground.global_basis.get_scale().y
	var base := ground.global_position.y
	var under := 0.0
	for b in _bones:
		var y := (sk.global_transform * sk.get_bone_global_pose(b)).origin.y - base
		under = maxf(under, float(_bones[b]) * k - y)
	lift = under if under >= lift else move_toward(lift, under, get_process_delta_time() * SETTLE * k)
	if lift < 0.001:
		return
	var up := (sk.global_basis.inverse() * Vector3.UP)
	var hips := sk.get_bone_global_pose(_pelvis)
	# (the skeleton's own up: a world metre, whatever its scale)
	hips.origin += up * lift
	sk.set_bone_global_pose(_pelvis, hips)
