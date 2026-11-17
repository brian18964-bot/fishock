class_name BodyLayer
extends SkeletonModifier3D

## Moves laid over whatever clip plays (CharacterRig; set by RunView3D each
## frame), each 0..1:
##   shiver  user request: scared, it stands shaking on the spot - fast small
##           trembles through the back, the head, the arms and the knees
##           (the clip under it the cower - RunView3D)
##   pull    user request: the fish pulling hard, the body's drawn after it -
##           leant forward from the hips, the knees bent to brace (the feet
##           kept where they are), the head kept up on the water; a sharp rise
##           (the fish's surge) jerks it forward a little further and lets go
##   snatch  user request: a live bait grabbed on the run - the legs keep
##           running, only the body dips and the arms reach down for it
## The character faces +z on its skeleton, +y up.

## The pull's lean (deg): the back's three bones, the neck and head back up.
const PULL_BACK := [12.0, 11.0, 8.0]
const PULL_NECK := -9.0
const PULL_HEAD := -6.0
## The knees' bend (deg at the thigh; the shin twice that, the foot back).
const PULL_KNEE := 20.0
## A surge's jerk: the extra lean it gives (deg) per unit the pull jumps by in
## a second, its spring (stiff, damped), the most.
const JERK_GAIN := 6.0
const JERK_STIFF := 60.0
const JERK_DAMP := 9.0
const JERK_MOST := 9.0
## The shiver: how fast (Hz, two mixed so it never settles into a beat),
## how far (deg) each part goes.
const SHIVER_HZ := Vector2(13.0, 17.7)
const SHIVER_BACK := 1.6
const SHIVER_NECK := 2.2
const SHIVER_HEAD := 2.8
const SHIVER_ARM := 3.4
const SHIVER_KNEE := 1.4
## The snatch: the back's dip (deg over its three bones), the arms' reach.
const SNATCH_BACK := 30.0
const SNATCH_ARM := 38.0
const SNATCH_KNEE := 10.0

var shiver := 0.0
var pull := 0.0
var snatch := 0.0

var _built := false
var _b := {}
var _len := 0.0
var _time := 0.0
var _last := -1.0
var _pull_was := 0.0
var _jerk := 0.0
var _jerk_vel := 0.0
var _stepped := -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _built:
		_build(sk)
	var now := Time.get_ticks_usec() / 1000000.0
	var dt := clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 0.0
	_last = now
	if Engine.get_process_frames() != _stepped:
		_stepped = Engine.get_process_frames()
		_time += dt
		_spring(dt)
	if shiver <= 0.001 and pull <= 0.001 and snatch <= 0.001 and absf(_jerk) < 0.05:
		return
	var side := Vector3.RIGHT
	# (forward lean: about the character's side, the top going to +z)
	var lean := pull + snatch
	if lean > 0.001 or absf(_jerk) > 0.05:
		var back := [pull * PULL_BACK[0] + snatch * SNATCH_BACK * 0.4,
			pull * PULL_BACK[1] + snatch * SNATCH_BACK * 0.35,
			pull * PULL_BACK[2] + snatch * SNATCH_BACK * 0.25]
		back[1] += _jerk
		for i in 3:
			_turn(sk, "spine_0%d" % (i + 1), side, back[i])
		_turn(sk, "neck_01", side, pull * PULL_NECK - snatch * 6.0 - _jerk * 0.5)
		_turn(sk, "Head", side, pull * PULL_HEAD)
		var knee := pull * PULL_KNEE + snatch * SNATCH_KNEE
		if knee > 0.01:
			_bend_knees(sk, knee)
		if snatch > 0.001:
			# (both arms brought forward and down toward the ground ahead)
			for s in ["l", "r"]:
				_turn(sk, "upperarm_" + s, side, -snatch * SNATCH_ARM)
				_turn(sk, "lowerarm_" + s, side, -snatch * SNATCH_ARM * 0.4)
	if shiver > 0.001:
		var t := _time * TAU
		var k := shiver
		_turn(sk, "spine_02", side, k * SHIVER_BACK * _wob(t, 0.0))
		_turn(sk, "spine_03", Vector3.BACK, k * SHIVER_BACK * _wob(t, 1.3))
		_turn(sk, "neck_01", side, k * SHIVER_NECK * _wob(t, 2.1))
		_turn(sk, "Head", Vector3.UP, k * SHIVER_HEAD * _wob(t, 0.7))
		for s in ["l", "r"]:
			var ph := 0.0 if s == "l" else 2.6
			_turn(sk, "upperarm_" + s, side, k * SHIVER_ARM * _wob(t, 3.0 + ph))
			_turn(sk, "lowerarm_" + s, Vector3.BACK, k * SHIVER_ARM * _wob(t, 4.4 + ph))
		# (the knees knocking: a small shared bob)
		_bend_knees(sk, k * SHIVER_KNEE * (1.0 + _wob(t, 5.2)))


## The surge's jerk: a spring kicked by how fast the pull rises.
func _spring(dt: float) -> void:
	if dt <= 0.0:
		return
	var rise := maxf(pull - _pull_was, 0.0) / dt
	_pull_was = pull
	_jerk_vel += rise * JERK_GAIN * dt * JERK_STIFF * 0.1
	_jerk_vel += (-JERK_STIFF * _jerk - JERK_DAMP * _jerk_vel) * dt
	_jerk = clampf(_jerk + _jerk_vel * dt, -JERK_MOST, JERK_MOST)


## Two mixed trembles, -1..1.
static func _wob(t: float, phase: float) -> float:
	return 0.6 * sin(t * SHIVER_HZ.x + phase) + 0.4 * sin(t * SHIVER_HZ.y + phase * 1.7)


func _build(sk: Skeleton3D) -> void:
	_built = true
	for n in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "upperarm_l", "upperarm_r",
			"lowerarm_l", "lowerarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]:
		_b[n] = sk.find_bone(n)
	# (the leg's length: hip to knee to ankle, for how far the hips come down)
	if _b.thigh_l >= 0 and _b.calf_l >= 0 and _b.foot_l >= 0:
		var hip := sk.get_bone_global_rest(_b.thigh_l).origin
		var knee := sk.get_bone_global_rest(_b.calf_l).origin
		var ankle := sk.get_bone_global_rest(_b.foot_l).origin
		_len = hip.distance_to(knee) + knee.distance_to(ankle)


func _turn(sk: Skeleton3D, bone: String, axis: Vector3, deg: float) -> void:
	var i: int = _b.get(bone, -1)
	if i >= 0:
		EarTailSway._turn(sk, i, axis, deg)


## The knees bent by `deg` (the thigh forward, the shin back twice as far, the
## foot level again) and the hips brought down so the feet stay put.
func _bend_knees(sk: Skeleton3D, deg: float) -> void:
	for s in ["l", "r"]:
		_turn(sk, "thigh_" + s, Vector3.RIGHT, -deg)
		_turn(sk, "calf_" + s, Vector3.RIGHT, deg * 2.0)
		_turn(sk, "foot_" + s, Vector3.RIGHT, -deg)
	var p: int = _b.get("pelvis", -1)
	if p < 0 or _len <= 0.0:
		return
	var drop := _len * 0.5 * (1.0 - cos(deg_to_rad(deg))) * 2.0
	var parent := sk.get_bone_parent(p)
	var down := Vector3.DOWN * drop
	if parent >= 0:
		down = sk.get_bone_global_pose(parent).basis.inverse() * down
	sk.set_bone_pose_position(p, sk.get_bone_pose_position(p) + down)
