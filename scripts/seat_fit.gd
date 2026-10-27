class_name SeatFit
extends SkeletonModifier3D

## User report: sat on a log at the camp, some characters sank into it -
## the sitting clips are the same for all, each body its own height
## (tools/measure_seats.py: fit.json "seat"). Sat, the hips are put on the
## log's top (`lift` m, up or down - CampLife works it out from the log under
## them), the legs bent or stretched (two bones, the knee kept in its own
## plane) so the feet stay where the clip has them, on the ground. Raised
## (a short one on a high log), the legs keep the clip's bend and hang -
## stretched down to the ground, they'd go into the log's front.
## How much of `lift` goes on follows the hips down: none standing (the
## pelvis at `stand`), all of it sat (at `seat`) - so the sitting down and
## the getting up carry it in and out smoothly.

## Up (+) or down (-) the hips go, sat (m).
var lift := 0.0
## The pelvis' height standing and sat (m, the model's own; fit.json).
var stand := 1.0
## (fit.json "seat"[1])
var seat := 0.5
## Off: none at all (whatever the clip - only on a log).
var on := false
## How much of it is on now (eased: CampLife turns it off as it stands).
var weight := 0.0

const EASE := 6.0
## The legs never quite straight (share of their length).
const REACH := 0.97

var _legs: Array = []
var _pelvis := -1


func _setup(sk: Skeleton3D) -> void:
	_pelvis = sk.find_bone("pelvis")
	_legs.clear()
	for s in ["_l", "_r"]:
		var leg := [sk.find_bone("thigh" + s), sk.find_bone("calf" + s), sk.find_bone("foot" + s)]
		if not leg.has(-1):
			_legs.append(leg)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _pelvis < 0:
		_setup(sk)
		if _pelvis < 0:
			return
	weight = move_toward(weight, 1.0 if on else 0.0, get_process_delta_time() * EASE) if is_inside_tree() else 0.0
	if weight <= 0.0 or absf(lift) < 0.002:
		return
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized()
	var hips := sk.get_bone_global_pose(_pelvis)
	var low := clampf((stand - up.dot(hips.origin)) / maxf(stand - seat, 0.01), 0.0, 1.0)
	var dy := lift * low * weight
	if absf(dy) < 0.001:
		return
	var feet := []
	for leg in _legs if dy < 0.0 else []:
		feet.append(sk.get_bone_global_pose(leg[2]))
	hips.origin += up * dy
	sk.set_bone_global_pose(_pelvis, hips)
	if dy >= 0.0:
		return
	for k in _legs.size():
		_reach(sk, _legs[k], feet[k])


## The leg's thigh and calf turned so its foot comes to `foot`'s place (as
## near as it reaches), the foot as it was.
func _reach(sk: Skeleton3D, leg: Array, foot: Transform3D) -> void:
	var thigh := sk.get_bone_global_pose(leg[0])
	var calf := sk.get_bone_global_pose(leg[1])
	var h := thigh.origin
	var k := calf.origin
	var f := sk.get_bone_global_pose(leg[2]).origin
	var a := h.distance_to(k)
	var b := k.distance_to(f)
	var to := foot.origin - h
	var d := clampf(to.length(), absf(a - b) + 0.001, (a + b) * REACH)
	if to.length() < 0.001:
		return
	var u := to.normalized()
	# (the knee's way out - its plane, as the clip bends it)
	var bend := (k - h) - u * u.dot(k - h)
	if bend.length() < 0.001:
		bend = (f - h).cross(Vector3.RIGHT).cross(u)
	var v := bend.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var knee := h + (u * cos_a + v * sqrt(1.0 - cos_a * cos_a)) * a
	var t := h + u * d
	var turn1 := _turn(k - h, knee - h)
	thigh.basis = turn1 * thigh.basis
	sk.set_bone_global_pose(leg[0], thigh)
	var turn2 := _turn(turn1 * (f - k), t - knee)
	calf.basis = turn2 * turn1 * calf.basis
	calf.origin = knee
	sk.set_bone_global_pose(leg[1], calf)
	sk.set_bone_global_pose(leg[2], Transform3D(foot.basis, t))


## The turn taking `from`'s way onto `to`'s.
static func _turn(from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	var axis := f.cross(t)
	if axis.length() < 1e-6:
		return Basis()
	return Basis(axis.normalized(), f.angle_to(t))
