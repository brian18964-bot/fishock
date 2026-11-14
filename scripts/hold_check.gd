class_name HoldCheck
extends RefCounted
## Whether a character's forearms and hands are in its body, by its real surface as it's posed
## now (user report: holding the rod, a round one's forearm went through its chest and only
## the hand showed). For fitting each one's hold (tools/fit_holds.gd) and the tests - not for
## play: it poses the whole mesh on the CPU.
##
## The trunk (everything but the arms, the hands and the head) is taken as what's in front of
## the character: per cell across and up, how far forward its surface comes. A point of a
## forearm or a hand behind that surface by more than SKIN is in the body.

const CELL := 0.03
const SKIN := 0.015

var _pts: SkinPoints
## Each point: 0 the trunk, 1 a right forearm or hand, 2 a left one, -1 left out (the head,
## the upper arms - they join the body at the shoulder).
var _kind := PackedInt32Array()


## (`step`: every so many points of the mesh - the fitting's many looks needn't all of them)
func _init(rig: CharacterRig, step := 1) -> void:
	_pts = SkinPoints.new(rig, step)
	var sk := _pts.skeleton
	if sk == null:
		return
	var of_bone := PackedInt32Array()
	for i in sk.get_bone_count():
		var name := sk.get_bone_name(i)
		var kind := 0
		var b := i
		while b >= 0:
			if sk.get_bone_name(b).to_lower() == "head":
				kind = -1
				break
			b = sk.get_bone_parent(b)
		if name.begins_with("upperarm") or name.begins_with("clavicle"):
			kind = -1 if name.begins_with("upperarm") else 0
		elif SkinPoints._kind(name) in [SkinPoints.Part.HAND_R, SkinPoints.Part.ARM_R]:
			kind = 1
		elif SkinPoints._kind(name) in [SkinPoints.Part.HAND_L, SkinPoints.Part.ARM_L]:
			kind = 2
		of_bone.append(kind)
	for i in _pts.size():
		var share := {-1: 0.0, 0: 0.0, 1: 0.0, 2: 0.0}
		for k in 4:
			share[of_bone[_pts._bind_bone[_pts._bones[i * 4 + k]]]] += _pts._weights[i * 4 + k]
		var best := 0
		for key in share:
			if share[key] > share[best]:
				best = key
		# (a forearm's points count only where they're all the forearm's: not the sleeve
		# shared with the upper arm at the elbow)
		if best > 0 and share[best] < 0.8:
			best = -1
		_kind.append(best)


## The share (0..1) of each forearm-and-hand's points in the body now: {r, l}. `frame`: the
## character's place and facing (+z ahead, +x its left; the run's pivot). Call it as the
## skeleton's updated (skeleton_updated), where the arms' IK shows in the pose.
func buried(frame: Transform3D) -> Dictionary:
	var out := {"r": 0.0, "l": 0.0}
	if _pts == null or _pts.skeleton == null:
		return out
	var inv := Transform3D(frame.basis.orthonormalized(), frame.origin).affine_inverse()
	var k := frame.basis.get_scale().x
	var world := _pts.world()
	var front := {}
	var local := PackedVector3Array()
	local.resize(world.size())
	for i in world.size():
		var p := inv * world[i] / maxf(k, 0.001)
		local[i] = p
		if _kind[i] == 0:
			var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
			if p.z > float(front.get(cell, -INF)):
				front[cell] = p.z
	var total := [0, 0, 0]
	var inside := [0, 0, 0]
	for i in local.size():
		var kind := _kind[i]
		if kind < 1:
			continue
		total[kind] += 1
		var p := local[i]
		var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
		# (well inside its outline: not the cells at the body's edge, where its side falls
		# away behind an arm that's only beside it)
		if front.has(cell) and front.has(cell + Vector2i(1, 0)) and front.has(cell - Vector2i(1, 0)) \
				and p.z < minf(float(front[cell]), minf(float(front[cell + Vector2i(1, 0)]), float(front[cell - Vector2i(1, 0)]))) - SKIN:
			inside[kind] += 1
	out.r = float(inside[1]) / maxi(total[1], 1)
	out.l = float(inside[2]) / maxi(total[2], 1)
	return out
