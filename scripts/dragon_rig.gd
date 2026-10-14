class_name DragonRig
extends SkeletonModifier3D

## The dragon's wings (tools/build_dragon_meshy.py: each on five bones -
## wing_<side>, wing_<side>_02, three fingers wing_<side>_f1..f3; modelled
## spread). User request: wings and tail that move. Calm it keeps them
## folded against its back - the arm raised behind the shoulder, the
## forearm and the fingers down along it; hunting (or holding someone) it
## opens them (`spread`, eased) and beats them slowly. Laid over whatever
## clip plays: each bone pointed where the fold wants it, in the chest's
## own frame, so the wings go with the body. (The tail: EarTailSway.)

## Where each wing bone points folded, with the chest (spine_03) at rest
## (skeleton space: +x the left side, +y up, +z forward) - the left wing's;
## the right's mirrored.
const FOLD := {
	"": Vector3(0.28, 0.84, -0.46),
	"_02": Vector3(0.12, -0.72, -0.68),
	"_f1": Vector3(0.1, -0.93, -0.35),
	"_f2": Vector3(0.06, -0.96, -0.28),
	"_f3": Vector3(0.03, -0.98, -0.2),
}
## Open, the beat: how far up and down (deg) at the shoulder, how long one
## takes (s); calm, a slow breath in the folded wings (deg).
const BEAT := 24.0
const BEAT_TIME := 1.1
const BREATH := 3.0
## How fast the wings open and close (1/s).
const EASE := 2.5

## 0 folded .. 1 open (what it's doing - RunView3D sets it).
var spread := 0.0
## The tail swung aside (rad, + to its left) - out of a tree's way
## (RunView3D sets it): the most at its root, less down it.
var tail_turn := 0.0
const TAIL_SHARE := [0.6, 0.3, 0.1]
var _tail_now := 0.0
var _tail: Array = []
var _open := 0.0
var _time := 0.0
var _last := -1.0
## [{bone, parent, rest (the way it points at rest), fold, side, root}]
var _wings: Array = []
var _chest := -1
var _built := false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _built:
		_build(sk)
	var now := Time.get_ticks_usec() / 1000000.0
	var dt := clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 0.0
	_last = now
	_time += dt
	_open = move_toward(_open, clampf(spread, 0.0, 1.0), dt * EASE)
	_tail_now = lerpf(_tail_now, tail_turn, 1.0 - exp(-dt * 4.0))
	for k in _tail.size():
		var bone: int = _tail[k]
		var a: float = _tail_now * float(TAIL_SHARE[k])
		if absf(a) < 0.001:
			continue
		var gt := sk.get_bone_global_pose(bone)
		var pt := sk.get_bone_global_pose(sk.get_bone_parent(bone))
		sk.set_bone_pose_rotation(bone, (pt.basis.inverse() * (Basis(Vector3.UP, a) * gt.basis)).get_rotation_quaternion())
	if _chest < 0 or _wings.is_empty():
		return
	# The chest as it is now against its rest: the frame the fold is in.
	var chest_now := sk.get_bone_global_pose(_chest).basis.orthonormalized()
	var chest_rest := sk.get_bone_global_rest(_chest).basis.orthonormalized()
	var frame := chest_now * chest_rest.inverse()
	var beat := sin(TAU * _time / BEAT_TIME)
	for w in _wings:
		var rest_dir: Vector3 = w.rest
		var want: Vector3 = rest_dir.slerp(w.fold, 1.0 - _open) if rest_dir.angle_to(w.fold) < PI - 0.01 \
			else w.fold.lerp(rest_dir, _open).normalized()
		if w.root:
			# (up and down about the body's forward axis, the left and the
			# right wing mirrored)
			var deg: float = BEAT * _open * beat + BREATH * (1.0 - _open) * sin(TAU * _time / 3.3)
			want = Basis(Vector3.BACK, deg_to_rad(deg) * float(w.side)) * want
		want = (frame * want).normalized()
		var g := sk.get_bone_global_pose(w.bone)
		var dir := (g.basis * Vector3.UP).normalized()
		if dir.angle_to(want) < 0.001:
			continue
		var turn := Basis(Quaternion(dir, want))
		var new_basis := turn * g.basis
		var parent_g := sk.get_bone_global_pose(w.parent)
		var local := parent_g.basis.inverse() * new_basis
		sk.set_bone_pose_rotation(w.bone, local.get_rotation_quaternion())


func _build(sk: Skeleton3D) -> void:
	_built = true
	for i in TAIL_SHARE.size():
		var t := sk.find_bone("tail_%02d" % (i + 1))
		if t >= 0:
			_tail.append(t)
	_chest = sk.find_bone("spine_03")
	if _chest < 0:
		return
	for side in ["l", "r"]:
		var k := 1.0 if side == "l" else -1.0
		for part in ["", "_02", "_f1", "_f2", "_f3"]:
			var i := sk.find_bone("wing_%s%s" % [side, part])
			if i < 0:
				continue
			var rest_dir := (sk.get_bone_global_rest(i).basis * Vector3.UP).normalized()
			var f: Vector3 = FOLD[part]
			_wings.append({"bone": i, "parent": sk.get_bone_parent(i), "side": k, "root": part == "",
				"rest": rest_dir,
				"fold": Vector3(f.x * k, f.y, f.z).normalized()})
