class_name DragonRig
extends SkeletonModifier3D

## The dragon's own motion, laid over whatever clip plays (tools/build_dragon_sage.py: the third
## make - each wing on fifteen bones, the tail on ten, each hand's five fingers on three). Its wings
## fold, open, beat and fly; its tail swings free, a chain hanging on springs; its right hand closes
## on the lantern's bail; flying, its body leans in and its limbs hang; lured by a fish, it crouches.
##
## The wings. Calm it keeps them folded against its back as a dragon does - the elbow back and down
## behind the shoulder, the forearm up from it so the wrist and its hooked claw stand above the
## shoulder, the fingers folded down along its back; hunting (or holding someone) it opens them (`spread`,
## eased) and beats them slowly; over water it flies. Each of the arm's bones, and each finger's
## first, is pointed where the pose wants it, in the chest's own frame (so the wings go with the
## body); a finger's further bones lie along its first folded, and as modelled open (flying, the whole
## wing's turn - FLY_SPAN), bending at their knuckles: folded, in toward the arm (FOLD_CURL); flying,
## down out of the membrane's plane (CAMBER) - its trailing edge curved as a wing's is, not a board.

## Where each bone points folded / flying (skeleton space with the chest at rest: +x the left side,
## +y up, +z forward) - the left wing's; the right's mirrored. ("": the arm to the elbow; _02 the
## forearm; _03 the hand; _f1.._f3 each finger's first bone.)
const FOLD := {
	"": Vector3(0.22, -0.55, -0.8),
	"_02": Vector3(0.12, 0.95, 0.27),
	"_03": Vector3(0.06, -0.8, -0.6),
	"_f1": Vector3(0.15, -0.86, -0.49),
	"_f2": Vector3(0.1, -0.87, -0.48),
	"_f3": Vector3(0.05, -0.88, -0.47),
}
## Flying, the wing is the one it was made with - open, the membrane spread between its fingers as
## modelled (a fan standing up behind it, facing back) - turned whole about the shoulder to lie out
## to its side, its back up: its span (shoulder to the first finger's last knuckle) along FLY_SPAN,
## its back (the membrane's back) up, so the membrane is neither crushed nor stretched. The faster
## it goes the more it sweeps back (FLY_SWEEP rad).
const FLY_SPAN := Vector3(0.95, 0.16, 0.26)
const FLY_SWEEP := 0.3
## (deg at each knuckle: folded, a finger's further bones in toward the arm; flying, down out of
## the membrane - its camber)
const FOLD_CURL := 11.0
const CAMBER := 5.0
## Open, the beat: how far up and down (deg) at the shoulder, how long one takes (s); calm, a slow
## breath in the folded wings (deg). How fast the wings open and close (1/s).
const BEAT := 24.0
const BEAT_TIME := 1.1
const BREATH := 3.0
const EASE := 2.5
## 0 folded .. 1 open (what it's doing - RunView3D sets it).
var spread := 0.0
## User request: over water it flies - `fly` 0..1 (RunView3D: from when it sees it'll cross): the
## wings out and beating harder; the faster it goes (`hurry` 0..1) the quicker and wider the beat.
## (The beat's phase, kept as it speeds up and slows: `beat_phase`, 0..1 a beat.)
var fly := 0.0
var hurry := 0.0
var beat_phase := 0.0
const FLY_BEAT := 0.6
const HURRY_BEAT := 0.8
## (the beat's share - 0 holds the wings still in their pose: for looking at them)
var beat_scale := 1.0
## The beat runs out the wing, each bone behind those nearer the shoulder (WAVE: the share of a beat
## its tip is behind - each bone by how far out its joint is, so the membrane between two bones as
## far out goes together, unstretched), so it bends like a whip; coming up the
## wing half closes (UPSTROKE_CLOSE: the fan drawn in toward its leading finger) and loses its camber;
## flying, the fingertips flutter. The wings keep level in the air as the body leans into its flight
## (WING_LEVEL: the share of the lean they leave out). Standing open, they sweep forward and back (SWEEP: share of the beat).
const WAVE := 0.21
## (deg, at the top of the upstroke: how far each finger's drawn in toward the leading one)
const UPSTROKE_CLOSE := {"f1": 0.0, "f2": 9.0, "f3": 16.0}
const SWEEP := 0.6
const WING_LEVEL := 0.85
var _lean_now := 0.0
const FLUTTER := 2.5
## The membrane (DragonSkin's shapes): the air on it - pushed up on the downstroke, down a little
## coming up, a little filled all the while it flies; standing open, pushed against its sweep - on a
## spring (stiffness, damping), so it gives and swings past rather than following at once; and
## flying, a ripple running out along it (rad/s: quicker the faster it goes).
const AIR_STIFF := 90.0
const AIR_DAMP := 8.0
const AIR_LIFT := 0.35
const AIR_STROKE := 0.8
const RIPPLE_RATE := Vector2(13.0, 22.0)

## Flying, its body too - after how flyers are animated (and how bats fly): it leans into its
## flight (FLY_PITCH rad: hovering .. at speed), nodding nose-up a little as its wings come down
## (FLY_NOD); its head held steady against all that (HEAD_KEEP: the share of the lean its neck and
## head take back). The lean is its upper body's, spread down its spine - its hips stay as they
## stand. Its arms and legs just hang (HANG_BACK: the legs a little behind straight down, more in
## the wind; knees easy, feet dropped), each a pendulum on a spring (LIMB_SPRING: stiffness /s²,
## damping /s), pushed as the body is: surging ahead on each downstroke (SURGE rad/s², more the
## faster) and as it speeds up or slows (SURGE_PACE per m/s²); the lower joint thrown the other way
## as the one above swings (FOLLOW). Left and right a little apart. The right arm carries the
## lantern: held a little forward and down (LAMP_HANG), steadier (LAMP_STEADY of the swing).
const FLY_PITCH := Vector2(0.32, 0.7)
const FLY_NOD := 0.07
const HEAD_KEEP := 0.7
const HANG_BACK := Vector2(0.08, 0.25)
const KNEE := 0.12
const ANKLE := 0.45
const LIMB_SPRING := {"thigh": Vector2(20.0, 2.6), "calf": Vector2(34.0, 3.4), "foot": Vector2(46.0, 4.0),
	"upperarm": Vector2(26.0, 3.0), "lowerarm": Vector2(40.0, 3.6)}
const SURGE := 6.0
const SURGE_PACE := 2.0
const FOLLOW := 0.55
const LAMP_HANG := Vector3(-0.22, -0.88, 0.42)
const LAMP_ELBOW := 0.35
const LAMP_STEADY := 0.45

## User request: lured by a fish, it crouches down to eat it (`crouch` 0..1 - RunView3D: eating at
## the fish; eased): its hips drop (CROUCH_DROP m, a little back), its feet kept where they stand
## (each leg bent to reach them - knee forward), its back bent over (CROUCH_LEAN rad down its spine)
## and its head down to the fish (CROUCH_LOOK), its tail lifted clear of the ground (CROUCH_TAIL).
var crouch := 0.0
const CROUCH_DROP := Vector2(0.38, 0.1)
const CROUCH_LEAN := 0.55
const CROUCH_LOOK := 0.6
const CROUCH_TAIL := 0.2
const CROUCH_EASE := 2.2
var _crouched := 0.0

## The tail (user request: free, natural): a chain on springs, its joints carried in the world - so
## its swing comes of the body's own going: lagging when it sets off, swinging on when it stops or
## turns, bouncing with its stride - each pulled toward where the pose puts it (TAIL_FOLLOW per
## frame at 60/s: stiff at the root, loose at the tip), its swing kept (TAIL_KEEP per frame), a
## little weight on it (TAIL_SAG m/s²), bent no more than TAIL_BEND (rad) from its pose at any joint,
## never through the ground or its legs. Where the pose puts it: as modelled, a slow wave running
## down it (TAIL_IDLE rad - more toward the tip), swayed by the stride (STRIDE_SWAY deg), turned
## aside out of a tree's way (`tail_turn`), the beat's wave flying, lifted crouching.
const TAIL_FOLLOW := Vector2(0.32, 0.07)
const TAIL_KEEP := 0.9
const TAIL_SAG := 2.5
const TAIL_BEND := 0.55
const TAIL_IDLE := Vector2(0.06, 0.035)
const TAIL_IDLE_TIME := Vector2(3.1, 1.7)
const STRIDE_SWAY := 7.0
const TAIL_WAVE := 0.05
const TAIL_RADIUS := Vector2(0.07, 0.025)
## The tail swung aside (rad, + to its left) - out of a tree's way (RunView3D sets it): the most at
## its root, less down it.
var tail_turn := 0.0
## How it's moving, in its own frame (m/s: x to its left, z ahead - RunView3D sets it); where in its
## walk it is (0..1, `stride`) and how much it's walking (0..1, `pace`).
var motion := Vector3.ZERO
var stride := 0.0
var pace := 0.0
## (the wings' lag behind its change of pace: a spring - deg per m/s², how stiff, how damped)
const LAG := 9.0
const LAG_STIFF := 28.0
const LAG_DAMP := 5.5

## User request: the lantern down at its side as it goes about, held up when someone's near
## (`raise` 0..1, eased): the right arm brought round to hold it up and out ahead, as its Idle_Lamp
## holds it.
var raise := 0.0
const RAISE := {
	"upperarm_r": Vector3(-0.32, -0.25, 0.91),
	"lowerarm_r": Vector3(-0.12, 0.72, 0.68),
	"hand_r": Vector3(-0.08, 0.86, 0.5),
}
## User request: the lantern carried for real, its bail in the fist - not floating at the wrist.
## The right hand closed (each finger's three bones curled toward the palm, deg; the thumb across
## them), and where its fist leaves room for the bail - `grip`, in the skeleton's space: its origin
## the middle of the hole the fingers close round, its x along it (the knuckles' line) - kept each
## frame for the lantern to hang from (RunView3D, once the skeleton's posed).
const FIST := {
	"index": [72.0, 84.0, 58.0], "middle": [74.0, 86.0, 60.0], "ring": [76.0, 86.0, 60.0],
	"pinky": [78.0, 84.0, 58.0], "thumb": [28.0, 40.0, 38.0],
}
var grip := Transform3D.IDENTITY

## (as it last flew, in the skeleton's space: how far its chest's up leans ahead (z), and its left
## thigh's way (z: - trailing) - the skeleton keeps the clip's pose outside the modifier)
var flight_seen := Vector2.ZERO
var _skin_mesh: MeshInstance3D
var _bulge := -1
var _ripple := Vector2i(-1, -1)
var _air := 0.0
var _air_vel := 0.0
var _ripple_t := 0.0
var _body := {}
var _limbs := {}
var _accel := Vector3.ZERO
var _was := Vector3.ZERO
var _lag := Vector2.ZERO
var _lag_vel := Vector2.ZERO
var _raised := 0.0
var _arm: Array = []
var _open := 0.0
var _time := 0.0
## each side: {"arm": [3 × {bone, parent, rest}], "fingers": {f: [4 × {bone, parent, rest}]}, "side"}
var _wings: Array = []
var _chest := -1
var _tail: Array[int] = []
var _tail_len: Array[float] = []
var _tail_p: PackedVector3Array = []
var _tail_prev: PackedVector3Array = []
var _tail_at := Vector3.INF
var _fist: Array = []
var _grip_joints: Array = []
var _knuckles: Array[int] = []
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
	if dt > 0.0:
		var accel := (motion - _was) / dt
		_accel = _accel.lerp(accel.limit_length(12.0), 1.0 - exp(-dt * 10.0))
		_was = motion
		var push := Vector2(-accel.x, -accel.z).limit_length(12.0) * deg_to_rad(LAG)
		_lag_vel += (push - _lag * LAG_STIFF - _lag_vel * LAG_DAMP) * dt
		_lag += _lag_vel * dt
		_lag = _lag.limit_length(deg_to_rad(35.0))
	_fly_body(sk, smoothstep(0.0, 1.0, fly), dt)
	_crouched = move_toward(_crouched, clampf(crouch, 0.0, 1.0), dt * CROUCH_EASE)
	if _crouched > 0.001:
		_crouch_body(sk, smoothstep(0.0, 1.0, _crouched))
	_raised = move_toward(_raised, clampf(raise, 0.0, 1.0), dt * 1.8)
	if _raised > 0.001:
		_raise_arm(sk)
	_close_fist(sk)
	_tail_swing(sk, dt)
	_beat_wings(sk, dt)


# ------------------------------------------------------------------ the wings

func _beat_wings(sk: Skeleton3D, dt: float) -> void:
	if _chest < 0 or _wings.is_empty():
		return
	var flown := smoothstep(0.0, 1.0, fly)
	# The frame the wings are posed in: folded, the chest as it is now against its rest (they lie on
	# its back); open, held square to the body - the clip's turn of the chest (an idle's twist, a
	# walk's sway) left out, only its pitch kept; flying, not even that, only a little of its lean
	# (WING_LEVEL) - so they spread alike both sides and lie level in the air.
	var chest := sk.get_bone_global_pose(_chest).basis.orthonormalized() \
		* sk.get_bone_global_rest(_chest).basis.orthonormalized().inverse()
	var up := chest * Vector3.UP
	var square := Basis(Vector3.RIGHT, lerpf(atan2(up.z, up.y), _lean_now * (1.0 - WING_LEVEL), flown))
	var frame := Basis(chest.get_rotation_quaternion().slerp(square.get_rotation_quaternion(),
		smoothstep(0.0, 1.0, _open)))
	var amp := BEAT * (1.0 + 0.55 * fly + 0.35 * hurry) * _open * beat_scale
	var spans := {}
	for w in _wings:
		var side: float = w.side
		# the arm: each bone to its pose, beaten
		for k in 3:
			var b: Dictionary = w.arm[k]
			var want := _pose_dir(b, flown)
			var wave := TAU * (beat_phase - float(b.lag))
			want = _beaten(want, deg_to_rad(amp * sin(wave)), flown, side)
			if k == 0:
				# (calm, a slow breath in the folded wings; swung by the lag, and a little by the stride)
				var deg: float = BREATH * (1.0 - _open) * sin(TAU * _time / 3.3) \
					+ rad_to_deg(_lag.y) * 0.5 + 3.0 * pace * sin(TAU * stride * 2.0)
				want = Basis(Vector3.BACK, deg_to_rad(deg) * side) * want
				want = Basis(Vector3.UP, _lag.x * 0.4) * want
			_point(sk, b, frame * want)
		# the fingers: the first bone to its pose, the rest turned with it and bent at the knuckles
		var firsts := {}
		for f in w.fingers:
			firsts[f] = _pose_dir(w.fingers[f][0], flown)
		var normal: Vector3 = (firsts["f1"] as Vector3).cross(firsts["f3"]).normalized() * side
		for f in w.fingers:
			var chain: Array = w.fingers[f]
			var rising := 0.0
			for k in chain.size():
				var b: Dictionary = chain[k]
				# (each bone its own way: open, as modelled; flying, the whole wing's turn of it;
				# folded, along its finger's fold)
				var want: Vector3 = firsts[f] if k == 0 else _pose_dir(b, flown)
				var wave := TAU * (beat_phase - float(b.lag))
				rising = maxf(0.0, cos(wave)) * _open
				if k > 0:
					# (folded, in toward the arm; flying, down out of the membrane - less coming up)
					var curl := deg_to_rad(FOLD_CURL * k) * (1.0 - _open) * side
					var camber := deg_to_rad(CAMBER * k) * flown * (1.0 - 0.7 * rising)
					want = Basis(normal, curl) * want
					var bend_axis := want.cross(normal).normalized()
					if bend_axis.length() > 0.5:
						want = Basis(bend_axis, -camber) * want
				# (coming up the wing half closes, as a bat's: its fan drawn in toward its leading finger -
				# the trailing fingers the most; flying, their tips flutter)
				var close := UPSTROKE_CLOSE[f] as float
				if close > 0.0 and rising > 0.0:
					var to_lead: Vector3 = (firsts["f1"] as Vector3)
					var axis := want.cross(to_lead)
					if axis.length() > 0.01:
						want = Basis(axis.normalized(), minf(deg_to_rad(close) * rising * (0.35 + 0.65 * flown),
							want.angle_to(to_lead) * 0.8)) * want
				var a := deg_to_rad(amp * sin(wave))
				a += deg_to_rad(FLUTTER * flown * sin(_time * 13.0 + k * 1.7 + float(f.substr(1)) * 2.3)) * (k + 1) / 4.0
				want = _beaten(want, a, flown, side)
				var world := (frame * want).normalized()
				if k == 0 and (f == "f1" or f == "f3"):
					spans[f + str(side)] = world
				_point(sk, b, world)
	_fill_membrane(dt, amp, flown, spans)


## A wing bone's way in the chest's frame: its rest to its fold as it closes, toward its flight
## as it flies.
func _pose_dir(b: Dictionary, flown: float) -> Vector3:
	var rest: Vector3 = b.rest
	var fold: Vector3 = b.fold
	var want: Vector3 = rest.slerp(fold, 1.0 - _open) if rest.angle_to(fold) < PI - 0.01 \
		else fold.lerp(rest, _open).normalized()
	var flight: Vector3 = b.flight
	if hurry > 0.0:
		flight = Basis(Vector3.UP, -FLY_SWEEP * hurry * float(b.side)) * flight
	return want.slerp(flight, flown).normalized()


## Turned by the beat (`a` rad): flying, up and down about its forward axis; open on its feet,
## forward and back.
func _beaten(want: Vector3, a: float, flown: float, side: float) -> Vector3:
	want = Basis(Vector3.BACK, a * flown * side) * want
	return Basis(Vector3.UP, a * SWEEP * (1.0 - flown) * side) * want


## A bone (`b`: {bone, parent}) pointed along `world` (the skeleton's space), turning it the least way.
func _point(sk: Skeleton3D, b: Dictionary, world: Vector3) -> void:
	var g := sk.get_bone_global_pose(b.bone)
	var dir := (g.basis * Vector3.UP).normalized()
	if dir.angle_to(world) < 0.001:
		return
	var new_basis := Basis(Quaternion(dir, world.normalized())) * g.basis
	var parent_g := sk.get_bone_global_pose(b.parent)
	sk.set_bone_pose_rotation(b.bone, (parent_g.basis.inverse() * new_basis).get_rotation_quaternion())


## The air on the membrane (see AIR_*): its bulge, and its ripple.
func _fill_membrane(dt: float, amp: float, flown: float, spans: Dictionary) -> void:
	if _skin_mesh == null or _bulge < 0:
		return
	var push := 0.0
	if _open > 0.001 and spans.size() == 4:
		# (which way the bulge goes across each wing now - its fingers' plane - against up)
		var l: Vector3 = (spans["f11.0"] as Vector3).cross(spans["f31.0"])
		var r: Vector3 = (spans["f3-1.0"] as Vector3).cross(spans["f1-1.0"])
		var up := clampf((l.normalized().y + r.normalized().y) * 0.5 * 2.5, -1.0, 1.0)
		var stroke := cos(TAU * (beat_phase - WAVE * 0.7))
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


# ------------------------------------------------------------------ the tail

func _tail_swing(sk: Skeleton3D, dt: float) -> void:
	var n := _tail.size()
	if n == 0:
		return
	var flown := smoothstep(0.0, 1.0, fly)
	# Where the pose puts it: its wave, its stride's sway, turned aside, the beat's wave, lifted.
	var stroke := func(lag: float) -> float: return -cos(TAU * (beat_phase - lag))
	for k in n:
		var t := float(k) / maxf(n - 1, 1)
		var share := 1.0 - t * 0.7
		var yaw := tail_turn * (0.25 if k < 3 else 0.06) \
			+ lerpf(TAIL_IDLE.x * 0.4, TAIL_IDLE.x, t) * sin(TAU * _time / TAIL_IDLE_TIME.x - t * 2.4) \
			+ deg_to_rad(STRIDE_SWAY) * pace * sin(TAU * stride - t * 1.6) * share * 0.35
		var pitch: float = lerpf(TAIL_IDLE.y * 0.3, TAIL_IDLE.y, t) * sin(TAU * _time / TAIL_IDLE_TIME.y - t * 1.9 + 0.7) \
			+ flown * TAIL_WAVE * stroke.call(0.1 + 0.05 * k)
		if k < 2:
			pitch += _crouched * CROUCH_TAIL * (1.4 if k == 0 else 0.8)
		_turn_bone(sk, _tail[k], yaw, Vector3.UP)
		_turn_bone(sk, _tail[k], pitch, Vector3.RIGHT)
	# (the pose's joints, in the world)
	var xf := sk.global_transform
	var want := PackedVector3Array()
	want.resize(n + 1)
	want[0] = xf * sk.get_bone_global_pose(_tail[0]).origin
	for k in n:
		var g := sk.get_bone_global_pose(_tail[k])
		want[k + 1] = xf * (g.origin + g.basis.y.normalized() * _tail_len[k])
	var scale := xf.basis.get_scale().x
	if _tail_p.size() != n or dt <= 0.0 or not _tail_at.is_finite() or _tail_at.distance_to(xf.origin) > 3.0 * scale:
		_tail_p = want.slice(1)
		_tail_prev = _tail_p.duplicate()
	_tail_at = xf.origin
	var ground := xf.origin.y
	var legs: Array = []
	for pair in [["thigh_l", "calf_l"], ["calf_l", "foot_l"], ["thigh_r", "calf_r"], ["calf_r", "foot_r"]]:
		var a: int = _body.get(pair[0], -1)
		var b: int = _body.get(pair[1], -1)
		if a >= 0 and b >= 0:
			legs.append([xf * sk.get_bone_global_pose(a).origin, xf * sk.get_bone_global_pose(b).origin])
	var steps := 2
	var h := dt / steps
	var keep := pow(TAIL_KEEP, h * 60.0)
	for _s in steps:
		for k in n:
			var t := float(k) / maxf(n - 1, 1)
			var p: Vector3 = _tail_p[k]
			var v: Vector3 = (p - _tail_prev[k]) * keep
			_tail_prev[k] = p
			p += v + Vector3.DOWN * TAIL_SAG * scale * h * h
			var pull := lerpf(TAIL_FOLLOW.x, TAIL_FOLLOW.y, t)
			p += (want[k + 1] - p) * (1.0 - pow(1.0 - pull, h * 60.0))
			_tail_p[k] = p
		for _pass in 2:
			var from: Vector3 = want[0]
			for k in n:
				var t := float(k) / maxf(n - 1, 1)
				var p: Vector3 = _tail_p[k]
				var link := _tail_len[k] * scale
				var dir := (p - from)
				var pose_dir := (want[k + 1] - want[k]).normalized()
				if dir.length() < 0.0001:
					dir = pose_dir
				dir = dir.normalized()
				# (bent no further than TAIL_BEND from the pose's way)
				var bent := dir.angle_to(pose_dir)
				if bent > TAIL_BEND:
					var axis := pose_dir.cross(dir).normalized()
					if axis.length() > 0.5:
						dir = pose_dir.rotated(axis, TAIL_BEND)
				p = from + dir * link
				var r := lerpf(TAIL_RADIUS.x, TAIL_RADIUS.y, t) * scale
				# (out of its legs, off the ground)
				for leg in legs:
					var a: Vector3 = leg[0]
					var ab: Vector3 = (leg[1] as Vector3) - a
					var q := a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
					var off := p - q
					var room := r + 0.07 * scale
					if off.length() < room:
						p = q + (off.normalized() if off.length() > 0.0001 else Vector3.BACK) * room
				p.y = maxf(p.y, ground + r)
				_tail_p[k] = p
				from = p
	# The bones along it.
	var inv := xf.affine_inverse()
	for k in n:
		var g := sk.get_bone_global_pose(_tail[k])
		var to := inv * _tail_p[k] - g.origin
		_aim(sk, _tail[k], to)


# ------------------------------------------------------------------ the body flying

func _fly_body(sk: Skeleton3D, flown: float, dt: float) -> void:
	if flown <= 0.001 or _body.is_empty():
		_limbs.clear()
		_lean_now = 0.0
		return
	# (+1 mid-downstroke, -1 mid-upstroke: `lag` of a beat after the wings)
	var stroke := func(lag: float) -> float: return -cos(TAU * (beat_phase - lag))
	var lean := lerpf(FLY_PITCH.x, FLY_PITCH.y, hurry)
	var nod: float = FLY_NOD * stroke.call(0.05)
	for spine in ["spine_01", "spine_02", "spine_03"]:
		_turn(sk, spine, flown * (lean - nod) / 3.0)
	_lean_now = flown * (lean - nod)
	_turn(sk, "neck_01", -flown * (lean * HEAD_KEEP - nod) * 0.5)
	_turn(sk, "Head", -flown * (lean * HEAD_KEEP - nod) * 0.5)
	# (limbs: hung straight down, then each its pendulum's swing - + back)
	var surge: float = SURGE * (1.0 + hurry) * stroke.call(0.0) + _accel.z * SURGE_PACE
	for side in ["l", "r"]:
		var out := 1.0 if side == "l" else -1.0
		var own := 1.0 if side == "l" else 1.08
		var hip := _swing("thigh_" + side, surge, own, dt)
		var knee := _swing("calf_" + side, -FOLLOW * _limb_acc("thigh_" + side), own, dt)
		var ankle := _swing("foot_" + side, -FOLLOW * _limb_acc("calf_" + side), own, dt)
		_hang(sk, "thigh_" + side, Vector3(0.18 * out, -1.0, 0.0), lerpf(HANG_BACK.x, HANG_BACK.y, hurry) + hip, flown)
		_turn(sk, "calf_" + side, flown * (KNEE + knee))
		_turn(sk, "foot_" + side, flown * (ANKLE + ankle))
		var arm := _swing("upperarm_" + side, surge * 0.7, own, dt)
		var elbow := _swing("lowerarm_" + side, -FOLLOW * _limb_acc("upperarm_" + side), own, dt)
		if side == "r":
			# (the lantern's arm: a little forward, the elbow easy, steadier)
			_hang(sk, "upperarm_r", LAMP_HANG, arm * LAMP_STEADY, flown)
			_turn(sk, "lowerarm_r", flown * (-LAMP_ELBOW + elbow * LAMP_STEADY))
		else:
			_hang(sk, "upperarm_" + side, Vector3(0.3 * out, -1.0, 0.05), arm, flown)
			_turn(sk, "lowerarm_" + side, flown * elbow)
	flight_seen = Vector2((sk.get_bone_global_pose(_body["spine_03"]).basis * Vector3.UP).normalized().z,
		(sk.get_bone_global_pose(_body["thigh_l"]).basis * Vector3.UP).normalized().z) \
		if _body.has("spine_03") and _body.has("thigh_l") else Vector2.ZERO


## Crouched `c` of the way (see `crouch`).
func _crouch_body(sk: Skeleton3D, c: float) -> void:
	var hips: int = _body.get("pelvis", -1)
	if hips < 0:
		return
	# (where its feet are, and how they lie, before the hips drop)
	var feet := {}
	for side in ["l", "r"]:
		var foot: int = _body.get("foot_" + side, -1)
		if foot >= 0:
			feet[side] = sk.get_bone_global_pose(foot)
	var g := sk.get_bone_global_pose(hips)
	var dropped := g.origin + Vector3(0.0, -CROUCH_DROP.x, -CROUCH_DROP.y) * c
	var pr := sk.get_bone_parent(hips)
	var parent := sk.get_bone_global_pose(pr) if pr >= 0 else Transform3D()
	sk.set_bone_pose_position(hips, parent.affine_inverse() * dropped)
	for side in feet:
		_reach(sk, side, (feet[side] as Transform3D))
	for spine in ["spine_01", "spine_02", "spine_03"]:
		_turn(sk, spine, c * CROUCH_LEAN / 3.0)
	_turn(sk, "neck_01", c * CROUCH_LOOK * 0.5)
	_turn(sk, "Head", c * CROUCH_LOOK * 0.5)


## A leg (`side`) bent to put its foot back where `foot` (its old pose) had it: two bones, the
## knee forward of the line from hip to ankle (as it was).
func _reach(sk: Skeleton3D, side: String, foot: Transform3D) -> void:
	var thigh: int = _body.get("thigh_" + side, -1)
	var calf: int = _body.get("calf_" + side, -1)
	var ankle: int = _body.get("foot_" + side, -1)
	if thigh < 0 or calf < 0 or ankle < 0:
		return
	var hip := sk.get_bone_global_pose(thigh).origin
	var knee_was := sk.get_bone_global_pose(calf).origin
	var upper := sk.get_bone_global_rest(thigh).origin.distance_to(sk.get_bone_global_rest(calf).origin)
	var lower := sk.get_bone_global_rest(calf).origin.distance_to(sk.get_bone_global_rest(ankle).origin)
	var to := foot.origin - hip
	var d := clampf(to.length(), absf(upper - lower) + 0.01, upper + lower - 0.001)
	var along := to.normalized()
	var bend := (knee_was - hip) - along * (knee_was - hip).dot(along)
	if bend.length() < 0.001:
		bend = Vector3.BACK
	bend = bend.normalized()
	var a := (upper * upper - lower * lower + d * d) / (2.0 * d)
	var knee := hip + along * a + bend * sqrt(maxf(upper * upper - a * a, 0.0))
	_aim(sk, thigh, knee - hip)
	_aim(sk, calf, foot.origin - sk.get_bone_global_pose(calf).origin)
	# (the foot laid as it was)
	var pc := sk.get_bone_global_pose(calf)
	sk.set_bone_pose_rotation(ankle, (pc.basis.inverse() * foot.basis).get_rotation_quaternion())


# ------------------------------------------------------------------ the hands

## The right hand closed on the bail (FIST), and the room it leaves for it - `grip`.
func _close_fist(sk: Skeleton3D) -> void:
	for f in _fist:
		sk.set_bone_pose_rotation(f.bone, sk.get_bone_pose_rotation(f.bone) * Quaternion(f.axis, f.angle))
	var h: int = _body.get("hand_r", -1)
	if h < 0:
		return
	# (the hole: the middle of where the index, middle and ring fingers' joints come round to, and
	# their tips)
	var acc := Vector3.ZERO
	for j in _grip_joints:
		var g := sk.get_bone_global_pose(j.bone)
		acc += g.origin + g.basis.y.normalized() * float(j.out)
	var hand := sk.get_bone_global_pose(h)
	var middle := acc / maxf(_grip_joints.size(), 1)
	var across := hand.basis.x.normalized()
	if _knuckles.size() == 2:
		across = (sk.get_bone_global_pose(_knuckles[0]).origin - sk.get_bone_global_pose(_knuckles[1]).origin).normalized()
	var up := hand.basis.y.normalized()
	var z := across.cross(up).normalized()
	grip = Transform3D(Basis(across, z.cross(across).normalized(), z), middle)


## Where the bail goes through the fist, in the world (`grip` mapped through the skeleton).
func grip_world() -> Transform3D:
	var sk := get_skeleton()
	if sk == null or not sk.is_inside_tree():
		return Transform3D.IDENTITY
	return sk.global_transform * grip


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


# ------------------------------------------------------------------ the parts

## A limb's pendulum (`name`: its joint - its spring from LIMB_SPRING by the part before the side),
## pushed by `force` (rad/s²) for `dt`: its angle now (rad, + swung back). `own` - its stiffness's
## share (each limb a little its own).
func _swing(name: String, force: float, own: float, dt: float) -> float:
	var spring: Vector2 = LIMB_SPRING[name.substr(0, name.rfind("_"))]
	var st: Vector3 = _limbs.get(name, Vector3.ZERO)
	var acc := -spring.x * own * st.x - spring.y * st.y + force
	st.y += acc * dt
	st.x = clampf(st.x + st.y * dt, -0.6, 0.6)
	st.z = acc
	_limbs[name] = st
	return st.x


func _limb_acc(name: String) -> float:
	return (_limbs.get(name, Vector3.ZERO) as Vector3).z


## Points a limb's bone (by name) straight down (`down`: in the skeleton's space - a little out to
## its side), swung back `swing` rad about its side to side, `amount` of the way from where the clip
## has it: a limb that just hangs, whatever the body does.
func _hang(sk: Skeleton3D, name: String, down: Vector3, swing: float, amount: float) -> void:
	var bone: int = _body.get(name, -1)
	if bone < 0:
		return
	var g := sk.get_bone_global_pose(bone)
	var dir := (g.basis * Vector3.UP).normalized()
	var want := (Basis(Vector3.RIGHT, swing) * down.normalized()).normalized()
	var to := dir.slerp(want, amount).normalized()
	if dir.angle_to(to) < 0.001:
		return
	var pg := sk.get_bone_global_pose(sk.get_bone_parent(bone))
	sk.set_bone_pose_rotation(bone, (pg.basis.inverse() * (Basis(Quaternion(dir, to)) * g.basis)).get_rotation_quaternion())


## Points a bone (its +Y) along `want` (the skeleton's space), turning it the least way.
func _aim(sk: Skeleton3D, bone: int, want: Vector3) -> void:
	if want.length() < 0.0001:
		return
	var g := sk.get_bone_global_pose(bone)
	var dir := (g.basis * Vector3.UP).normalized()
	var to := want.normalized()
	if dir.angle_to(to) < 0.0005:
		return
	var pg := sk.get_bone_global_pose(sk.get_bone_parent(bone))
	sk.set_bone_pose_rotation(bone, (pg.basis.inverse() * (Basis(Quaternion(dir, to)) * g.basis)).get_rotation_quaternion())


## Turns a bone of the body (by name) about `axis` (the skeleton's: RIGHT its side to side - a +
## turn tips it forward, or swings a limb hanging down back), where it is now.
func _turn(sk: Skeleton3D, name: String, angle: float, axis := Vector3.RIGHT) -> void:
	var bone: int = _body.get(name, -1)
	if bone >= 0:
		_turn_bone(sk, bone, angle, axis)


func _turn_bone(sk: Skeleton3D, bone: int, angle: float, axis: Vector3) -> void:
	if absf(angle) < 0.0001:
		return
	var g := sk.get_bone_global_pose(bone)
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	sk.set_bone_pose_rotation(bone, (pg.basis.inverse() * (Basis(axis, angle) * g.basis)).get_rotation_quaternion())


func _build(sk: Skeleton3D) -> void:
	_built = true
	for name in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "thigh_l", "calf_l", "foot_l",
			"thigh_r", "calf_r", "foot_r", "upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r", "hand_r"]:
		var i := sk.find_bone(name)
		if i >= 0:
			_body[name] = i
	for mi in sk.find_children("*", "MeshInstance3D", false, false):
		if DragonSkin.fit(mi):
			_skin_mesh = mi
			_bulge = (mi as MeshInstance3D).find_blend_shape_by_name("bulge")
			_ripple = Vector2i((mi as MeshInstance3D).find_blend_shape_by_name("ripple_s"),
				(mi as MeshInstance3D).find_blend_shape_by_name("ripple_c"))
			break
	for name in RAISE:
		var i := sk.find_bone(name)
		if i >= 0:
			_arm.append({"bone": i, "parent": sk.get_bone_parent(i), "dir": (RAISE[name] as Vector3).normalized()})
	# the tail, root to tip, and each bone's length (to the next's head; the last as the one before)
	var k := 1
	while sk.find_bone("tail_%02d" % k) >= 0:
		_tail.append(sk.find_bone("tail_%02d" % k))
		k += 1
	for i in _tail.size():
		var here := sk.get_bone_global_rest(_tail[i]).origin
		if i + 1 < _tail.size():
			_tail_len.append(here.distance_to(sk.get_bone_global_rest(_tail[i + 1]).origin))
		else:
			_tail_len.append(_tail_len[i - 1] * 0.9 if i > 0 else 0.1)
	# the fist: each finger bone's curl about its own axis across the palm (the palm faces down at
	# rest - the arm held out)
	for f in FIST:
		for j in 3:
			var b := sk.find_bone("%s_%02d_r" % [f, j + 1])
			if b < 0:
				continue
			var rest := sk.get_bone_global_rest(b)
			var dir := rest.basis.y.normalized()
			var palm := Vector3.DOWN if f != "thumb" else Vector3(1.0, -0.6, 0.0).normalized()
			var axis_g := dir.cross(palm).normalized()
			var axis := (rest.basis.orthonormalized().inverse() * axis_g).normalized()
			_fist.append({"bone": b, "axis": axis, "angle": deg_to_rad(float(FIST[f][j]))})
		if f in ["index", "middle", "ring"]:
			for j in 3:
				var b := sk.find_bone("%s_%02d_r" % [f, j + 1])
				if b >= 0:
					_grip_joints.append({"bone": b, "out": 0.0})
			var last := sk.find_bone("%s_03_r" % f)
			var before := sk.find_bone("%s_02_r" % f)
			if last >= 0 and before >= 0:
				_grip_joints.append({"bone": last,
					"out": sk.get_bone_global_rest(last).origin.distance_to(sk.get_bone_global_rest(before).origin) * 0.8})
	for name in ["index_01_r", "pinky_01_r"]:
		if sk.find_bone(name) >= 0:
			_knuckles.append(sk.find_bone(name))
	_chest = sk.find_bone("spine_03")
	if _chest < 0:
		return
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var w := {"side": s, "arm": [], "fingers": {}}
		var ok := true
		var fly_turn := _fly_turn(sk, side, s)
		for part in ["", "_02", "_03"]:
			var b := _wing_bone(sk, "wing_%s%s" % [side, part], FOLD[part], fly_turn, s)
			if b.is_empty():
				ok = false
				break
			(w.arm as Array).append(b)
		for f in ["f1", "f2", "f3"]:
			var chain: Array = []
			for j in 4:
				var name := "wing_%s_%s" % [side, f] + ("" if j == 0 else "_%02d" % (j + 1))
				var b := _wing_bone(sk, name, FOLD["_" + f], fly_turn, s)
				if b.is_empty():
					ok = false
					break
				chain.append(b)
			w.fingers[f] = chain
		if ok:
			# (each bone's lag: how far out its joint is, against the first finger's last knuckle)
			var root := sk.get_bone_global_rest((w.arm[0] as Dictionary).bone).origin
			var reach := root.distance_to(sk.get_bone_global_rest((w.fingers.f1[3] as Dictionary).bone).origin)
			for b in (w.arm as Array) + w.fingers.f1 + w.fingers.f2 + w.fingers.f3:
				b.lag = WAVE * root.distance_to(sk.get_bone_global_rest(b.bone).origin) / maxf(reach, 0.01)
			_wings.append(w)


func _wing_bone(sk: Skeleton3D, name: String, fold: Vector3, fly_turn: Basis, s: float) -> Dictionary:
	var i := sk.find_bone(name)
	if i < 0:
		return {}
	var rest := (sk.get_bone_global_rest(i).basis * Vector3.UP).normalized()
	return {"bone": i, "parent": sk.get_bone_parent(i), "rest": rest, "side": s,
		"fold": Vector3(fold.x * s, fold.y, fold.z).normalized(),
		"flight": (fly_turn * rest).normalized()}


## The turn that lays a side's wing, as modelled, out flying (see FLY_SPAN).
func _fly_turn(sk: Skeleton3D, side: String, s: float) -> Basis:
	var root := sk.find_bone("wing_" + side)
	var f1 := sk.find_bone("wing_%s_f1_04" % side)
	var f3 := sk.find_bone("wing_%s_f3_04" % side)
	if root < 0 or f1 < 0 or f3 < 0:
		return Basis()
	var h := sk.get_bone_global_rest(root).origin
	var a := sk.get_bone_global_rest(f1).origin - h
	var b := sk.get_bone_global_rest(f3).origin - h
	var back := a.cross(b).normalized()
	if back.dot(Vector3.BACK * -1.0) < 0.0:      # (the membrane's back: toward -z, behind it)
		back = -back
	var span := a.normalized()
	back = (back - span * back.dot(span)).normalized()
	var rest_frame := Basis(span, back, span.cross(back))
	var to_span := Vector3(FLY_SPAN.x * s, FLY_SPAN.y, FLY_SPAN.z).normalized()
	var up := (Vector3.UP - to_span * Vector3.UP.dot(to_span)).normalized()
	var fly_frame := Basis(to_span, up, to_span.cross(up))
	return fly_frame * rest_frame.inverse()
