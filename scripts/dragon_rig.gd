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
## User request: over water it flies - `fly` 0..1 (RunView3D: from when it sees it'll cross): the
## wings open and beat harder; and the faster it goes (`hurry` 0..1) the quicker and wider the
## beat. (The beat's phase, kept as it speeds up and slows: `beat_phase`, 0..1 a beat.)
var fly := 0.0
var hurry := 0.0
var beat_phase := 0.0
const FLY_BEAT := 0.6
const HURRY_BEAT := 0.8
## User report: the beat was stiff - the open wing (spread up behind its back, a fan facing back)
## swung about its forward axis, i.e. within its own plane, like a wiper, the forearm and fingers
## not following. Flying now the wings go out to its sides, flat - the arm the leading edge, the
## fingers swept back from the wrist (where each bone points, as FOLD) - and beat through the air,
## up and down; standing open, they sweep forward and back. The beat runs out the wing, each joint
## behind the one before (WAVE: share of a beat), so it bends like a whip rather than a board;
## coming up, the fingers draw in toward the arm, the membrane eased (UPSTROKE_FOLD); flying, the
## fingertips flutter.
const FLIGHT := {
	"": Vector3(0.86, 0.45, 0.2),
	"_02": Vector3(0.96, 0.16, 0.16),
	"_f1": Vector3(0.88, -0.1, -0.46),
	"_f2": Vector3(0.6, -0.18, -0.78),
	"_f3": Vector3(0.24, -0.28, -0.93),
}
const WAVE := {"": 0.0, "_02": 0.07, "_f1": 0.14, "_f2": 0.16, "_f3": 0.18}
const UPSTROKE_FOLD := 0.22
const SWEEP := 0.6
const FLUTTER := 2.5
## The membrane (WingMembrane's shapes): the air on it - pushed up on the downstroke, down a little
## coming up, a little filled all the while it flies; standing open, pushed against its sweep - on
## a spring (stiffness, damping), so it gives and swings past rather than following at once; and
## flying, a ripple running out along it (rad/s: quicker the faster it goes).
const AIR_STIFF := 90.0
const AIR_DAMP := 8.0
const AIR_LIFT := 0.35
const AIR_STROKE := 0.8
const RIPPLE_RATE := Vector2(13.0, 22.0)
## User request: flying, its body too - after how flyers are animated (and how bats fly): it
## leans into its flight (FLY_PITCH rad: hovering .. at speed), nodding nose-up a little as its
## wings come down (FLY_NOD); its head held steady against all that (HEAD_KEEP: the share of the
## lean its neck and head take back - the nod they take back whole); its legs trailing behind
## (LEG_TRAIL: the hips, hovering .. at speed, the wind pushing them back), knees bent and feet
## pointed, swinging forward with the downstroke and back after it - a little behind the wings
## (LIMB_LAG of a beat), the knee behind the hip; its arms drawn in (ARM_TUCK: shoulder, elbow),
## swinging after the beat too; its tail out behind as its counterweight (TAIL_DROOP),
## going up as the wings go down, the wave running down it, a slow sway side to side. (The
## lean is its hips', about them - not the whole of it tipped about its feet.)
const FLY_PITCH := Vector2(0.32, 0.7)
const FLY_NOD := 0.07
const HEAD_KEEP := 0.7
const LEG_TRAIL := Vector2(0.3, 0.55)
const KNEE := 0.45
const ANKLE := 0.5
const LIMB_SWING := 0.14
const LIMB_LAG := 0.12
## (the free left arm folded in against it; the right, the lantern's, held a little ahead and
## down so the lantern hangs clear of it)
const ARM_TUCK := {"l": Vector2(0.25, -1.5), "r": Vector2(-0.35, -0.5)}
## (the tail flying: each bone pointed back along a gentle droop - the root most, the tip least,
## as m down per m back - for TAIL_HOLD of the way; its own curve up would curl it over its back)
const TAIL_DROOP := Vector2(0.3, 0.02)
const TAIL_HOLD := 0.85
const TAIL_WAVE := 0.1
const TAIL_SWAY := 0.06
## {bone name: index} of the body's bones the flight moves
var _body := {}
## (as it last flew, in the skeleton's space: how far its hips' up leans ahead (z), and its left
## thigh's way (z: - trailing) - the skeleton keeps the clip's pose outside the modifier)
var flight_seen := Vector2.ZERO
var _skin_mesh: MeshInstance3D
var _bulge := -1
var _ripple := Vector2i(-1, -1)
var _air := 0.0
var _air_vel := 0.0
var _ripple_t := 0.0
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
## [{bone, parent, rest (the way it points at rest), fold, side, root}]
var _wings: Array = []
var _chest := -1
var _built := false


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _built:
		_build(sk)
	# (game time - not the clock's: a recording or a hitch doesn't hurry it)
	var dt := clampf(delta, 0.0, 0.1)
	_time += dt
	_open = move_toward(_open, clampf(maxf(spread, fly), 0.0, 1.0), dt * EASE)
	beat_phase = fmod(beat_phase + dt / BEAT_TIME * (1.0 + HURRY_BEAT * hurry + FLY_BEAT * fly), 1.0)
	_tail_now = lerpf(_tail_now, tail_turn, 1.0 - exp(-dt * 4.0))
	_fly_body(sk, smoothstep(0.0, 1.0, fly))
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
	var amp := BEAT * (1.0 + 0.55 * fly + 0.35 * hurry) * _open
	var flown := smoothstep(0.0, 1.0, fly)
	var forearm := Vector3.ZERO
	var spans := {}
	for w in _wings:
		var part: String = w.part
		var side: float = w.side
		var rest_dir: Vector3 = w.rest
		var want: Vector3 = rest_dir.slerp(w.fold, 1.0 - _open) if rest_dir.angle_to(w.fold) < PI - 0.01 \
			else w.fold.lerp(rest_dir, _open).normalized()
		want = want.slerp(w.flight, flown).normalized()
		# (the beat where this joint is in it: later the further out)
		var wave := TAU * (beat_phase - float(WAVE[part]))
		var a := deg_to_rad(amp * sin(wave))
		if part.begins_with("_f"):
			# (coming up the fingers draw in toward the arm; flying, their tips flutter)
			var rising := maxf(0.0, cos(wave)) * _open
			if forearm != Vector3.ZERO:
				want = want.slerp(forearm, UPSTROKE_FOLD * rising * (0.4 + 0.6 * flown)).normalized()
			a += deg_to_rad(FLUTTER * flown * sin(_time * 13.0 + float(WAVE[part]) * 40.0))
		# Flying: up and down about its forward axis; open on its feet: forward and back.
		want = Basis(Vector3.BACK, a * flown * side) * want
		want = Basis(Vector3.UP, a * SWEEP * (1.0 - flown) * side) * want
		if w.root:
			# (calm, a slow breath in the folded wings; swung by the lag, and a little by the stride)
			var deg: float = BREATH * (1.0 - _open) * sin(TAU * _time / 3.3) \
				+ rad_to_deg(_lag.y) * 0.5 + 3.0 * pace * sin(TAU * stride * 2.0)
			want = Basis(Vector3.BACK, deg_to_rad(deg) * side) * want
			want = Basis(Vector3.UP, _lag.x * 0.4) * want
		if part == "_02":
			forearm = want
		want = (frame * want).normalized()
		if part == "_f1" or part == "_f3":
			spans[part + str(side)] = want
		var g := sk.get_bone_global_pose(w.bone)
		var dir := (g.basis * Vector3.UP).normalized()
		if dir.angle_to(want) < 0.001:
			continue
		var turn := Basis(Quaternion(dir, want))
		var new_basis := turn * g.basis
		var parent_g := sk.get_bone_global_pose(w.parent)
		var local := parent_g.basis.inverse() * new_basis
		sk.set_bone_pose_rotation(w.bone, local.get_rotation_quaternion())
	_fill_membrane(dt, amp, flown, spans)


## The air on the membrane (see AIR_*): its bulge, and its ripple.
func _fill_membrane(dt: float, amp: float, flown: float, spans: Dictionary) -> void:
	if _skin_mesh == null or _bulge < 0:
		return
	var push := 0.0
	if _open > 0.001 and spans.size() == 4:
		# (which way the bulge goes across each wing now - its fingers' plane - against up)
		var l: Vector3 = (spans["_f11.0"] as Vector3).cross(spans["_f31.0"])
		var r: Vector3 = (spans["_f3-1.0"] as Vector3).cross(spans["_f1-1.0"])
		var up := clampf((l.normalized().y + r.normalized().y) * 0.5 * 2.5, -1.0, 1.0)
		var stroke := cos(TAU * (beat_phase - float(WAVE["_f2"])))
		var flying := (AIR_LIFT - AIR_STROKE * stroke) * up
		var standing := -0.6 * cos(TAU * beat_phase) * amp / BEAT
		push = _open * (flown * flying + (1.0 - flown) * standing)
	_air_vel += ((push - _air) * AIR_STIFF - _air_vel * AIR_DAMP) * dt
	_air = clampf(_air + _air_vel * dt, -1.0, 1.0)
	_skin_mesh.set_blend_shape_value(_bulge, _air)
	if _ripple.x >= 0:
		var flutter := flown * _open * (0.35 + 0.65 * hurry)
		_ripple_t = fmod(_ripple_t + dt * lerpf(RIPPLE_RATE.x, RIPPLE_RATE.y, hurry), TAU)
		_skin_mesh.set_blend_shape_value(_ripple.x, flutter * cos(_ripple_t))
		_skin_mesh.set_blend_shape_value(_ripple.y, -flutter * sin(_ripple_t))


## The flying body (see FLY_PITCH): its hips, head, legs, arms and tail, `flown` of the way.
func _fly_body(sk: Skeleton3D, flown: float) -> void:
	if flown <= 0.001 or _body.is_empty():
		return
	# (+1 mid-downstroke, -1 mid-upstroke: `lag` of a beat after the wings)
	var stroke := func(lag: float) -> float: return -cos(TAU * (beat_phase - lag))
	var lean := lerpf(FLY_PITCH.x, FLY_PITCH.y, hurry)
	var nod: float = FLY_NOD * stroke.call(0.05)
	_turn(sk, "pelvis", flown * (lean - nod))
	_turn(sk, "neck_01", -flown * (lean * HEAD_KEEP - nod) * 0.5)
	_turn(sk, "Head", -flown * (lean * HEAD_KEEP - nod) * 0.5)
	for side in ["l", "r"]:
		# (the right a touch behind the left: never quite in step)
		var late := 0.0 if side == "l" else 0.04
		var hip: float = LIMB_SWING * stroke.call(LIMB_LAG + late)
		var knee: float = LIMB_SWING * stroke.call(LIMB_LAG * 2.0 + late)
		_turn(sk, "thigh_" + side, flown * (lerpf(LEG_TRAIL.x, LEG_TRAIL.y, hurry) - hip))
		_turn(sk, "calf_" + side, flown * (KNEE - knee * 0.8))
		_turn(sk, "foot_" + side, flown * (ANKLE - knee * 0.5))
		var tuck: Vector2 = ARM_TUCK[side]
		_turn(sk, "upperarm_" + side, flown * (tuck.x + hip * 0.5))
		_turn(sk, "lowerarm_" + side, flown * (tuck.y + knee * 0.4))
	flight_seen = Vector2((sk.get_bone_global_pose(_body["pelvis"]).basis * Vector3.UP).normalized().z,
		(sk.get_bone_global_pose(_body["thigh_l"]).basis * Vector3.UP).normalized().z) \
		if _body.has("pelvis") and _body.has("thigh_l") else Vector2.ZERO
	# (the tail: out behind, going up as the wings go down - the wave running down it, each bone a
	# little later - and swaying slowly side to side; the faster, the straighter)
	for k in 7:
		var name := "tail_%02d" % (k + 1)
		var bone: int = _body.get(name, -1)
		if bone < 0:
			continue
		var droop := lerpf(TAIL_DROOP.x, TAIL_DROOP.y, k / 6.0) * (1.0 - 0.5 * hurry)
		var want := Vector3(0.0, -droop, -1.0).normalized()
		want = Basis(Vector3.RIGHT, TAIL_WAVE * stroke.call(0.1 + 0.06 * k)) * want
		want = Basis(Vector3.UP, TAIL_SWAY * sin(TAU * _time / 2.6 - k * 0.45)) * want
		var g := sk.get_bone_global_pose(bone)
		var dir := (g.basis * Vector3.UP).normalized()
		var to := dir.slerp(want, flown * TAIL_HOLD).normalized()
		if dir.angle_to(to) < 0.001:
			continue
		var pg := sk.get_bone_global_pose(sk.get_bone_parent(bone))
		var turned := Basis(Quaternion(dir, to)) * g.basis
		sk.set_bone_pose_rotation(bone, (pg.basis.inverse() * turned).get_rotation_quaternion())


## Turns a bone of the body (by name) about `axis` (the skeleton's: RIGHT its side to side - a
## + turn tips it forward, or swings a limb hanging down back), where it is now.
func _turn(sk: Skeleton3D, name: String, angle: float, axis := Vector3.RIGHT) -> void:
	var bone: int = _body.get(name, -1)
	if bone < 0 or absf(angle) < 0.0001:
		return
	var g := sk.get_bone_global_pose(bone)
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	sk.set_bone_pose_rotation(bone, (pg.basis.inverse() * (Basis(axis, angle) * g.basis)).get_rotation_quaternion())


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
	for name in ["pelvis", "neck_01", "Head", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
			"upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r", "tail_01", "tail_02", "tail_03",
			"tail_04", "tail_05", "tail_06", "tail_07"]:
		var i := sk.find_bone(name)
		if i >= 0:
			_body[name] = i
	for mi in sk.find_children("*", "MeshInstance3D", false, false):
		if WingMembrane.fit(mi):
			_skin_mesh = mi
			_bulge = (mi as MeshInstance3D).find_blend_shape_by_name("bulge")
			_ripple = Vector2i((mi as MeshInstance3D).find_blend_shape_by_name("ripple_s"),
				(mi as MeshInstance3D).find_blend_shape_by_name("ripple_c"))
			break
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
			var fl: Vector3 = FLIGHT[part]
			_wings.append({"bone": i, "parent": sk.get_bone_parent(i), "side": k, "root": part == "",
				"part": part, "rest": rest_dir,
				"fold": Vector3(f.x * k, f.y, f.z).normalized(),
				"flight": Vector3(fl.x * k, fl.y, fl.z).normalized()})
