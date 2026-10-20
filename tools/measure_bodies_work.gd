extends Node
## tools/measure_bodies.gd's measuring (see there).
const BIN := 0.04

var ids: Array = []


func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	ids = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		for c in Profile.CHARACTERS:
			ids.append(c[0])
	for id in ids:
		await _measure(id)
	get_tree().quit()


func _measure(id: String) -> void:
	var rig := CharacterRig.new()
	rig.hold_gear = false
	rig.auto_idle = false
	add_child(rig)
	rig.set_character(id)
	await get_tree().process_frame
	var sk := rig.skeleton
	var fit := {}
	_pose(rig, "Idle", 0.0)
	var to_rig := rig.global_transform.affine_inverse()
	var at := func(bone: String) -> Vector3:
		return to_rig * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin)
	var pts := SkinPoints.new(rig)
	var world := pts.world()
	fit.shoulder = at.call("upperarm_l").y
	fit.pelvis = at.call("pelvis").y
	fit.hips_z = snappedf(at.call("pelvis").z, 0.001)
	fit.arm = at.call("upperarm_l").distance_to(at.call("lowerarm_l")) + at.call("lowerarm_l").distance_to(at.call("hand_l"))
	fit.leg = at.call("thigh_l").distance_to(at.call("calf_l")) + at.call("calf_l").distance_to(at.call("foot_l"))
	# The hands: how far past the wrist (to the furthest fingertip).
	for side in ["l", "r"]:
		var wrist: Vector3 = at.call("hand_" + side)
		var far := 0.0
		for f in ["index", "middle", "ring", "pinky", "thumb"]:
			if sk.find_bone("%s_04_leaf_%s" % [f, side]) >= 0:
				far = maxf(far, (at.call("%s_04_leaf_%s" % [f, side]) as Vector3).distance_to(wrist))
		fit["hand_" + side] = snappedf(far, 0.001)
	# The forearm's thickness (round the left one, elbow to wrist - its
	# middling, not a loose sleeve's furthest).
	var elbow: Vector3 = at.call("lowerarm_l")
	var wrist_l: Vector3 = at.call("hand_l")
	var radii := []
	var at_elbow := []
	var fore := elbow.distance_to(wrist_l)
	for i in world.size():
		if pts.part[i] != SkinPoints.Part.ARM_L:
			continue
		var p := to_rig * world[i]
		var along := (p - elbow).dot((wrist_l - elbow).normalized())
		if along > 0.0 and along < fore:
			var r := p.distance_to(elbow + (wrist_l - elbow).normalized() * along)
			radii.append(r)
			if along < 0.25 * fore:
				at_elbow.append(r)
	radii.sort()
	at_elbow.sort()
	fit.forearm = snappedf(float(radii[int(radii.size() * 0.5)]) if radii.size() else 0.04, 0.001)
	# (and round the elbow - a sleeve's bunched there - its furthest)
	fit.elbow = snappedf(float(at_elbow[int(at_elbow.size() * 0.8)]) if at_elbow.size() else fit.forearm, 0.001)
	# The body's (not the arms') furthest forward, back and out to each side
	# per height - standing and over a walk (its hips sway): the
	# sides at the hips' depth only (not a tail swung out behind).
	var hips_z: float = at.call("pelvis").z
	var prof := {"front": [], "back": [], "side": [], "side_r": []}
	var poses := [["Idle", 0.0]]
	for clip in ["Walk"]:
		if rig.anim.has_animation(clip):
			for i in 6:
				poses.append([clip, rig.anim.get_animation(clip).length * i / 6.0])
	for pose in poses:
		_pose(rig, pose[0], pose[1])
		var now := pts.world([SkinPoints.Part.BODY])
		for i in now.size():
			if pts.part[i] != SkinPoints.Part.BODY:
				continue
			var p := to_rig * now[i]
			var k := int(floor(p.y / BIN))
			if k < 0:
				continue
			while prof.front.size() <= k:
				prof.front.append(-1.0)
				prof.back.append(1.0)
				prof.side.append(0.0)
				prof.side_r.append(0.0)
			prof.front[k] = maxf(prof.front[k], p.z)
			prof.back[k] = minf(prof.back[k], p.z)
			if absf(p.z - hips_z) < 0.3:
				prof.side[k] = maxf(prof.side[k], p.x)
				prof.side_r[k] = maxf(prof.side_r[k], -p.x)
	_pose(rig, "Idle", 0.0)
	for key in prof:
		fit[key] = prof[key].map(func(v): return snappedf(v, 0.001))
	_grip(rig, pts, world, fit)
	fit.walk = snappedf(_pace(rig, "Walk"), 0.01)
	fit.run = snappedf(_pace(rig, "Run"), 0.01)
	var path := "res://assets/sprites/player/%s/fit.json" % id
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_write(path, fit)
	CharacterArt._fits.erase(id)
	print("FIT %s grip %s room %.3f hands %.3f/%.3f walk %.2f run %.2f" % [id, fit.grip, fit.grip_room,
		fit.hand_l, fit.hand_r, fit.walk, fit.run])
	rig.queue_free()
	await get_tree().process_frame


func _pose(rig: CharacterRig, clip: String, t: float) -> void:
	rig.anim.play(clip)
	rig.anim.seek(t, true)
	rig.anim.pause()
	rig.skeleton.force_update_all_bone_transforms()


## The hole the curled fingers make: looked for in slices across the hand
## (index to pinky), each a grid in the plane the fingers curl in; a point
## counts if the hand's surface goes round it (no gap wider than OPEN), and
## the one with the most room to the surface is it.
const OPEN := deg_to_rad(110.0)


func _grip(rig: CharacterRig, pts: SkinPoints, world: PackedVector3Array, fit: Dictionary) -> void:
	var sk := rig.skeleton
	var g := func(bone: String) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	var wrist: Vector3 = g.call("hand_l")
	var k: Vector3 = (g.call("pinky_01_l") - g.call("index_01_l")).normalized()
	var u: Vector3 = g.call("middle_01_l") - wrist
	u = (u - k * u.dot(k)).normalized()
	var n := k.cross(u)
	var hand := PackedVector3Array()
	for i in world.size():
		if pts.part[i] == SkinPoints.Part.HAND_L:
			hand.append(world[i])
	var reach: float = fit.hand_l
	var span: float = (g.call("pinky_01_l") - g.call("index_01_l")).dot(k)
	var mid: Vector3 = (g.call("index_01_l") + g.call("pinky_01_l")) * 0.5
	var best := Vector3.ZERO
	var room := -1.0
	var steps := 22
	for o in [-0.25, 0.0, 0.25]:
		var base: Vector3 = mid + k * span * float(o)
		var slab := []
		for h in hand:
			if absf((h - base).dot(k)) < 0.012:
				slab.append(h)
		if slab.size() < 8:
			continue
		for ia in steps + 1:
			for ib in steps + 1:
				var a := lerpf(-0.6, 0.9, float(ia) / steps) * reach
				var b := lerpf(-0.8, 0.8, float(ib) / steps) * reach
				var p := base + u * a + n * b
				var near := INF
				for h in hand:
					near = minf(near, p.distance_squared_to(h))
				near = sqrt(near)
				if near <= room or not _enclosed(p, slab, u, n, reach):
					continue
				room = near
				best = p
	var bone := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_l"))
	var inv := bone.affine_inverse()
	if room < 0.0:
		# (no hole: the fist shut - between the middle finger's first joints)
		best = (g.call("middle_01_l") + g.call("middle_02_l")) * 0.5
		room = 0.0
		push_warning("%s: no hole in the fist" % rig.character)
	var local := inv * best
	var axis := (bone.basis.inverse() * k).normalized()
	fit.grip = [snappedf(local.x, 0.0001), snappedf(local.y, 0.0001), snappedf(local.z, 0.0001)]
	fit.grip_axis = [snappedf(axis.x, 0.001), snappedf(axis.y, 0.001), snappedf(axis.z, 0.001)]
	fit.grip_room = snappedf(room, 0.0001)


func _enclosed(p: Vector3, slab: Array, u: Vector3, n: Vector3, reach: float) -> bool:
	var angles := PackedFloat32Array()
	for h in slab:
		var d: Vector3 = h - p
		if d.length() < reach * 0.8:
			angles.append(atan2(d.dot(n), d.dot(u)))
	if angles.size() < 6:
		return false
	angles.sort()
	var gap := angles[0] + TAU - angles[angles.size() - 1]
	for i in range(1, angles.size()):
		gap = maxf(gap, angles[i] - angles[i - 1])
	return gap < OPEN


## The ground speed a clip's feet keep: while a foot's down (within 2 cm
## of its lowest), how fast it goes back under the body.
func _pace(rig: CharacterRig, clip: String) -> float:
	if not rig.anim.has_animation(clip):
		return 0.0
	var len := rig.anim.get_animation(clip).length
	var sk := rig.skeleton
	var n := 90
	var speeds := []
	for side in ["l", "r"]:
		var ys := []
		var zs := []
		for i in n + 1:
			_pose(rig, clip, len * i / n)
			var p := rig.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("ball_" + side)).origin)
			ys.append(p.y)
			zs.append(p.z)
		var low: float = ys.min()
		for i in n:
			if ys[i] < low + 0.02 and ys[i + 1] < low + 0.02:
				speeds.append((zs[i] - zs[i + 1]) / (len / n))
	if speeds.is_empty():
		return 0.0
	speeds.sort()
	return speeds[speeds.size() / 2]


func _write(path: String, fit: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(fit, "", false))
	f.close()
