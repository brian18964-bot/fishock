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
## User request: the tail and the wings swing with its going - they lag
## behind when it sets off, swing on when it stops or turns, and the tail
## sways with its stride. `motion`: how it's moving, in its own frame
## (m/s: x to its left, z ahead - RunView3D sets it); `stride`: where in
## its walk it is (0..1) and `pace` how much it's walking (0..1).
var motion := Vector3.ZERO
var stride := 0.0
var pace := 0.0
## (the lag: a spring - deg per m/s² of its change of pace, how stiff, how
## damped; the stride's sway of the tail, deg)
const LAG := 9.0
const LAG_STIFF := 28.0
const LAG_DAMP := 5.5
const STRIDE_SWAY := 9.0
var _was := Vector3.ZERO
var _lag := Vector2.ZERO
var _lag_vel := Vector2.ZERO
## User request: the lantern down at its side as it goes about, held up
## when someone's near (`raise` 0..1, eased): the right arm brought round
## to hold it up and out ahead, as its Idle_Lamp holds it.
var raise := 0.0
const RAISE := {
	"upperarm_r": Vector3(-0.32, -0.25, 0.91),
	"lowerarm_r": Vector3(-0.12, 0.72, 0.68),
	"hand_r": Vector3(-0.08, 0.86, 0.5),
}
var _raised := 0.0
var _arm: Array = []
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
	# The lag: its change of pace (side to side, ahead and back) drives a
	# spring the tail and wings hang on.
	if dt > 0.0:
		var accel := (motion - _was) / dt
		_was = motion
		var push := Vector2(-accel.x, -accel.z).limit_length(12.0) * deg_to_rad(LAG)
		_lag_vel += (push - _lag * LAG_STIFF - _lag_vel * LAG_DAMP) * dt
		_lag += _lag_vel * dt
		_lag = _lag.limit_length(deg_to_rad(35.0))
	var sway := deg_to_rad(STRIDE_SWAY) * pace * sin(TAU * stride)
	for k in _tail.size():
		var bone: int = _tail[k]
		var share := float(TAIL_SHARE[k])
		var yaw := _tail_now * share + (_lag.x * 0.8 + sway) * (0.5 + 0.5 * share)
		var pitch := _lag.y * 0.6 * share
		if absf(yaw) + absf(pitch) < 0.0005:
			continue
		var gt := sk.get_bone_global_pose(bone)
		var pt := sk.get_bone_global_pose(sk.get_bone_parent(bone))
		var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		sk.set_bone_pose_rotation(bone, (pt.basis.inverse() * (turn * gt.basis)).get_rotation_quaternion())
	_raised = move_toward(_raised, clampf(raise, 0.0, 1.0), dt * 1.8)
	if _raised > 0.001:
		_raise_arm(sk)
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
			# right wing mirrored; swung by the lag, and a little by the stride)
			var deg: float = BEAT * _open * beat + BREATH * (1.0 - _open) * sin(TAU * _time / 3.3) \
				+ rad_to_deg(_lag.y) * 0.5 + 3.0 * pace * sin(TAU * stride * 2.0)
			want = Basis(Vector3.BACK, deg_to_rad(deg) * float(w.side)) * want
			want = Basis(Vector3.UP, _lag.x * 0.4) * want
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


## The right arm toward RAISE (in the chest's frame), as far as `_raised`.
func _raise_arm(sk: Skeleton3D) -> void:
	if _chest < 0:
		return
	var frame := sk.get_bone_global_pose(_chest).basis.orthonormalized() \
		* sk.get_bone_global_rest(_chest).basis.orthonormalized().inverse()
	for a in _arm:
		var g := sk.get_bone_global_pose(a.bone)
		var dir := (g.basis * Vector3.UP).normalized()
		var want: Vector3 = (frame * (a.dir as Vector3)).normalized()
		want = dir.slerp(want, _raised).normalized()
		if dir.angle_to(want) < 0.001:
			continue
		var new_basis := Basis(Quaternion(dir, want)) * g.basis
		var pg := sk.get_bone_global_pose(a.parent)
		sk.set_bone_pose_rotation(a.bone, (pg.basis.inverse() * new_basis).get_rotation_quaternion())


func _build(sk: Skeleton3D) -> void:
	_built = true
	for name in RAISE:
		var i := sk.find_bone(name)
		if i >= 0:
			_arm.append({"bone": i, "parent": sk.get_bone_parent(i), "dir": (RAISE[name] as Vector3).normalized()})
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
