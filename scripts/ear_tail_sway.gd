class_name EarTailSway
extends SkeletonModifier3D

## User request: the characters' ears (the owl's tufts) and tails move on
## their own, at random. On the camp's 3D character (CharacterRig): its
## ear chains ("ear_*", tools/owl_character.py) mostly still, now and then
## one flicks back - sometimes twice - a drop ear swings a little as well;
## its tail ("tail_*") sways slowly side to side, the sway running down it,
## and now and then gives a bigger flick. The clips don't key these bones,
## so the motion goes on top of whatever plays.

## Between an ear's flicks (s), how long one takes, how far it goes (deg),
## and the chance it flicks again straight after.
const EAR_GAP := Vector2(1.8, 5.5)
const EAR_TIME := 0.45
const EAR_ANGLE := Vector2(14.0, 26.0)
const EAR_TWICE := 0.3
## A drop ear (hanging down) also swings a little, always.
const DROP_SWAY := 4.0
const DROP_PERIOD := 1.9
## The tail's sway (deg, a bone; s a swing), how far behind each bone down
## it lags (s), its flicks (gap s, deg, s).
const TAIL_SWAY := 7.0
const TAIL_PERIOD := Vector2(2.4, 3.4)
const TAIL_LAG := 0.16
const TAIL_FLICK_GAP := Vector2(3.0, 7.0)
const TAIL_FLICK := 16.0
const TAIL_FLICK_TIME := 0.9

## User request (the cat): the tail and the ears go with its steps as well -
## they hang on a spring from the hips, so the clip's bob and sway and the
## character's own setting off, stopping and turning swing them (deg they
## settle at per m/s² of the hips' change of pace, how stiff, how damped,
## the most).
## Off unless asked for (the dragon swings its own tail - DragonRig).
var follow_steps := false
const STEP_LAG := 2.5
const STEP_STIFF := 38.0
const STEP_DAMP := 5.0
const STEP_MOST := 22.0
## How much of the swing the ears take.
const STEP_EARS := 0.5
## The hips' twist with each step swings the tail's root across as well,
## as if this far behind them (m).
const STEP_TWIST := 1.2
var _twist_was := 0.0
var _twist_vel := 0.0
var _hips := -1
var _hip_was := Vector3.ZERO
var _hip_vel := Vector3.ZERO
var _hip_seen := 0
var _lag := Vector3.ZERO
var _lag_vel := Vector3.ZERO

## [{bones: [index], kind: "ear"|"drop"|"tail", axis: Vector3 (skeleton
## space), next: s, at: s (the flick's start, -1 none), angle: deg,
## period: s}]
var chains: Array = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _last := -1.0
var _built := false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _built:
		_build(sk)
	var now := Time.get_ticks_usec() / 1000000.0
	var dt := clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 0.0
	_time += dt
	_last = now
	if follow_steps:
		_step(sk, get_process_delta_time())
	for c in chains:
		_schedule(c)
		var bones: Array = c.bones
		for k in bones.size():
			var deg := _angle(c, k, bones.size())
			if follow_steps and c.kind != "tail":
				deg += _lag.y * STEP_EARS / bones.size()
			_turn(sk, bones[k], c.axis, deg)
		if follow_steps and c.kind == "tail":
			# (side to side about the up; up and down, ahead and back
			# about the across - spread down the tail)
			var n := float(bones.size())
			for k in bones.size():
				_turn(sk, bones[k], Vector3.UP, -_lag.x / n)
				_turn(sk, bones[k], Vector3.RIGHT, (_lag.y + _lag.z) / n)


## Bone `i` turned `deg` about `axis` (skeleton space) on top of its pose.
static func _turn(sk: Skeleton3D, i: int, axis: Vector3, deg: float) -> void:
	if absf(deg) < 0.01:
		return
	var basis := sk.get_bone_global_pose(i).basis
	var local: Vector3 = (basis.inverse() * axis).normalized()
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(local, deg_to_rad(deg)))


## The spring: the hips' change of pace (in the skeleton's frame: x across,
## y up, z ahead) pushes the hanging tail and ears the other way.
func _step(sk: Skeleton3D, dt: float) -> void:
	if _hips < 0:
		_hips = sk.find_bone("pelvis")
		if _hips < 0:
			follow_steps = false
			return
	if dt <= 0.0:
		return
	var at := sk.global_transform * sk.get_bone_global_pose(_hips).origin
	var vel := (at - _hip_was) / dt
	_hip_was = at
	# (a jump - placed somewhere new - is no step)
	if vel.length() > 20.0:
		_hip_seen = 0
	_hip_seen += 1
	if _hip_seen < 3:
		_hip_vel = vel if _hip_seen == 2 else Vector3.ZERO
		var ahead0 := sk.get_bone_global_pose(_hips).basis * sk.get_bone_global_rest(_hips).basis.inverse() * Vector3.BACK
		var twist0 := atan2(ahead0.x, ahead0.z)
		_twist_vel = angle_difference(_twist_was, twist0) / dt if _hip_seen == 2 else 0.0
		_twist_was = twist0
		return
	var accel := (vel - _hip_vel) / dt
	_hip_vel = vel
	var local := sk.global_transform.basis.orthonormalized().inverse() * accel
	# (the twist: the hips' turn about the up from their rest, its change
	# of pace a push across at the tail's root)
	var ahead := sk.get_bone_global_pose(_hips).basis * sk.get_bone_global_rest(_hips).basis.inverse() * Vector3.BACK
	var twist := atan2(ahead.x, ahead.z)
	var spin := angle_difference(_twist_was, twist) / dt
	_twist_was = twist
	local.x -= (spin - _twist_vel) / dt * STEP_TWIST
	_twist_vel = spin
	var push := -local.limit_length(15.0) * STEP_LAG * STEP_STIFF
	_lag_vel += (push - _lag * STEP_STIFF - _lag_vel * STEP_DAMP) * dt
	_lag += _lag_vel * dt
	_lag = _lag.limit_length(STEP_MOST)


## The ear and tail chains, by their bones' names (root first).
func _build(sk: Skeleton3D) -> void:
	_built = true
	_rng.randomize()
	var groups := {}
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.begins_with("ear_") or n.begins_with("tail_"):
			var key := n.substr(0, n.rfind("_"))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(i)
	for key in groups:
		var bones: Array = groups[key]
		bones.sort_custom(func(a, b): return sk.get_bone_name(a) < sk.get_bone_name(b))
		var root := sk.get_bone_global_rest(bones[0]).origin
		var tip := sk.get_bone_global_rest(bones[-1]).origin
		var along := (tip - root).normalized()
		var c := {"bones": bones, "at": -1.0, "angle": 0.0, "period": 1.0}
		if key.begins_with("tail"):
			c.kind = "tail"
			c.axis = Vector3.UP
			c.period = _rng.randf_range(TAIL_PERIOD.x, TAIL_PERIOD.y)
			c.next = _rng.randf_range(TAIL_FLICK_GAP.x, TAIL_FLICK_GAP.y)
		else:
			c.kind = "drop" if along.y < -0.3 else "ear"
			# Back (and a little out): about the axis across the ear and
			# the way it faces.
			var side := signf(root.x) if absf(root.x) > 0.001 else 1.0
			var across := along.cross(Vector3.BACK)
			if across.length() < 0.1:
				across = Vector3.RIGHT
			c.axis = (across.normalized() + Vector3.BACK * side * 0.35).normalized()
			c.next = _rng.randf_range(0.3, EAR_GAP.y)
		chains.append(c)


## Starts a flick when one's due.
func _schedule(c: Dictionary) -> void:
	var span := TAIL_FLICK_TIME if c.kind == "tail" else EAR_TIME
	if c.at >= 0.0 and _time - c.at > span:
		c.at = -1.0
	if _time < c.next:
		return
	c.at = _time
	if c.kind == "tail":
		c.angle = TAIL_FLICK * (1.0 if _rng.randf() < 0.5 else -1.0)
		c.next = _time + _rng.randf_range(TAIL_FLICK_GAP.x, TAIL_FLICK_GAP.y)
	else:
		c.angle = _rng.randf_range(EAR_ANGLE.x, EAR_ANGLE.y) * (0.6 if c.kind == "drop" else 1.0)
		var again := _rng.randf() < EAR_TWICE
		c.next = _time + (EAR_TIME + 0.05 if again else _rng.randf_range(EAR_GAP.x, EAR_GAP.y))


## How far bone `k` (of `n`, root first) of chain `c` turns now (deg).
func _angle(c: Dictionary, k: int, n: int) -> float:
	var deg := 0.0
	match c.kind:
		"tail":
			var t := _time - TAIL_LAG * k
			deg = TAIL_SWAY * sin(TAU * t / c.period) * (0.6 + 0.4 * float(k) / maxf(n - 1, 1))
			if c.at >= 0.0:
				var u := clampf((_time - c.at - TAIL_LAG * k) / TAIL_FLICK_TIME, 0.0, 1.0)
				deg += c.angle * sin(PI * u) * (1.0 - u * 0.5)
		_:
			if c.kind == "drop":
				deg = DROP_SWAY * sin(TAU * _time / DROP_PERIOD + float(c.bones[0]))
			if c.at >= 0.0:
				deg += c.angle * flick(_time - c.at) / n
	return deg


## An ear's flick at `t` s in (0..1): snapped back quick, eased home.
static func flick(t: float) -> float:
	if t <= 0.0 or t >= EAR_TIME:
		return 0.0
	if t < 0.07:
		return smoothstep(0.0, 0.07, t)
	return 1.0 - smoothstep(0.12, EAR_TIME, t)
