class_name DragonRig
extends SkeletonModifier3D

## The dragon's own motion, laid over whatever clip plays (tools/build_dragon_sage.py: the third
## make - each wing on fifteen bones, the tail on ten, each hand's five fingers on three, its jaw,
## its skirt on eight chains of three). Its wings fold, open, beat and fly; its tail, its free arm and
## its skirt swing free, chains on springs in the world; its right hand closes on the lantern's bail,
## the thumb wrapped over; its head and neck carry their own weight, look about and breathe, its jaw
## opens; flying, its body leans in and its limbs hang; lured by a fish, it crouches.
##
## The wings. Calm, and chasing on land, it keeps them folded against its back as a dragon does -
## the elbow back and down behind the shoulder, the forearm up from it so the wrist and its hooked
## claw stand above the shoulder, the fingers folded down along its back; searching (or holding
## someone) it half raises them as modelled (`spread`); over water it takes off and flies, the wings
## fully spread (SPREAD_*), opened and folded stage by stage (OPEN_RATE); not freeing whoever it holds,
## it spreads them wide to show it (`display`). Each of the arm's bones, and each finger's first, is
## pointed where the pose wants it, in the chest's own frame (so the wings go with the body); a
## finger's further bones lie along its first folded, and as modelled or spread open, bending at
## their knuckles: folded, in toward the arm (FOLD_CURL); spread, down out of the membrane's plane
## (CAMBER) - its trailing edge curved as a wing's is, not a board.

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
## User request: spread as a dragon's wing is, not the model's half-open one (its wrist up by its
## shoulder) turned flat - its arm stretched out to its side as the leading edge, the elbow a little
## back and the wrist ahead (each arm bone: deg back from straight out, deg up), its fingers fanned
## out behind from the wrist, the last back toward its hips (each finger's first bone the same way),
## each finger keeping its own curve, straightened by SPREAD_STRAIGHT. The membrane, made folded
## half shut, is stretched to it (its weights shared among the spars smoothly - build_dragon_sage.py
## SPAR_POWER - so it opens as a fan does, evenly). The faster it flies the more the spread wing
## sweeps back (FLY_SWEEP rad).
const FLY_SWEEP := 0.3
const SPREAD_ARM := {"": Vector2(30.0, 25.0), "_02": Vector2(-35.0, 8.0), "_03": Vector2(-10.0, 5.0)}
const SPREAD_FAN := {"f1": Vector2(2.0, 4.0), "f2": Vector2(50.0, 0.0), "f3": Vector2(100.0, -4.0)}
const SPREAD_STRAIGHT := 0.6
## User request: the wings open the way a dragon's do - stage by stage out from the shoulder: the
## upper arm lifts the wing off the back, the forearm swings out, the hand and the fan come open,
## last the fingers straighten; folding, the other way round (the fingers first). Each stage moves at
## OPEN_RATE (1/s), only once the one before is OPEN_GATE of the way open (closing: once the one after
## is that far closed) - so a change of mind halfway is smooth.
const OPEN_RATE := 2.6
const OPEN_GATE := 0.45
## User request: crossing water on its rounds it takes off deliberately, in about two seconds:
## its wings unfold stage by stage as it walks on (TAKEOFF.unfold s), it crouching a little and
## leaning in, the wings rising high at the last; then it beats them down hard and slow, twice
## (TAKEOFF.power s - POWER_AMP of the flying beat), each stroke lifting it, its feet off the ground
## on the second; then it flies, beating evenly. Coming to the far shore it lands as fully: its
## wings swept forward and their front tilted up into the air to brake (LANDING.flare s - FLARE),
## sinking onto its feet, which take the weight (a dip), the wings held out a moment (LANDING.settle
## s), then folding back the other way round. The faster it goes the quicker it does it all (up to
## twice as quick, `hurry` 1). RunView3D says whether it means to fly (`want_fly`) and, come late to
## the shore, how much quicker it must be (`fly_rate`); it reads how far up it is (`airborne`).
const TAKEOFF := {"unfold": 0.9, "power": 1.1}
const LANDING := {"flare": 0.6, "settle": 0.45}
const POWER_BEATS := 2
const POWER_AMP := 1.6
## (deg: the wing's front tilted up, swept forward)
const FLARE := Vector2(50.0, 28.0)
const PREP_CROUCH := 0.28
const LAND_DIP := 0.32
enum Air { GROUND, UNFOLD, POWER, CRUISE, FLARE, SETTLE }
var auto_fly := false
var want_fly := false
var fly_rate := 1.0
var airborne := 0.0
var air_state := Air.GROUND
## User request: not freed in time, it shows the traveller it has them - its wings spread wide and
## high, their faces turned to the front, slowly heaving (`display` 0..1 - RunView3D: BigGhost's
## claim), its chest up.
var display := 0.0
const DISPLAY := Vector2(34.0, 22.0)
var _air_t := 0.0
var _stage: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _kind := 0.0
var _ready := 0.0
var _amp_mul := 1.0
var _stroke_v := 0.0
var _flare := 0.0
var _prep := 0.0
var _shown := 0.0
var _beat_rate := 0.0
## (deg at each knuckle: folded, a finger's further bones in toward the arm; flying, down out of
## the membrane - its camber)
const FOLD_CURL := 11.0
const CAMBER := 5.0
## Open, the beat: how far up and down (deg) at the shoulder, how long one takes (s); calm, a slow
## breath in the folded wings (deg).
const BEAT := 24.0
const BEAT_TIME := 1.1
const BREATH := 3.0
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
const STROKE_DOWN := 0.6
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
## User request: the thumb closed too - not stuck up beside the fist: from FIST's curl, it's laid
## across the front of the curled fingers' middle bones (over their backs, THUMB_ON.z m out) as a
## thumb locks a grip - its last knuckle brought onto them THUMB_ON.x of the way from the index to the
## little finger's (its first two bones bent round the outside of the fist to put it there), its last
## bone on across them toward THUMB_ON.y.
const THUMB_ON := Vector3(0.3, 1.2, 0.016)
var grip := Transform3D.IDENTITY
## (where the thumb's last knuckle and its tip were meant to go and went - the skeleton's space - as
## it last closed: [knuckle meant, knuckle, tip meant, tip])
var thumb_seen: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]

## User request: none of it stiff. Its free (left) arm swings after its body - each joint lagging
## the one before (a chain on springs in the world, as the tail: ARM_SWING - how hard each joint is
## pulled to the clip's pose, root .. tip, per frame at 60/s; how much swing it keeps; how far it may
## bend from the pose, rad), so a stride's swing runs out through the forearm to the hand and on,
## a stop swings it on past and back; its fingers rest easy, half curled (RELAX deg each joint,
## breathing open and closed a little - RELAX_BREATH deg), and flick with the hand's swing
## (RELAX_FLICK deg per rad it lags).
const ARM_SWING := {"follow": Vector2(0.16, 0.07), "keep": 0.9, "sag": 1.0, "bend": 0.5}
const RELAX := {
	"index": [16.0, 20.0, 14.0], "middle": [20.0, 24.0, 16.0], "ring": [24.0, 28.0, 18.0],
	"pinky": [28.0, 30.0, 20.0], "thumb": [8.0, 12.0, 10.0],
}
const RELAX_BREATH := 4.0
const RELAX_FLICK := 22.0
## User request: its head and neck alive - not held as the clip holds them. Its head has weight: its
## body's going swings it on its neck (HEAD_SPRING: stiffness /s², damping /s - the neck's, the head's
## after it, FOLLOW its neck's swing): each step's rise and fall nods it (HEAD_BOB rad per m/s² up),
## setting off tips it back and stopping forward (HEAD_SURGE per m/s² ahead), going aside sways it
## (HEAD_SIDE). It looks at whoever it's after (`look_at`, in the world - RunView3D: the traveller
## near it), from where the clip has its face, its neck taking NECK_SHARE of the turn, as far round /
## down as LOOK_MAX (rad), easing to it (LOOK_EASE /s); with no one to look at, turning, it leads
## with its head (TURN_LEAD rad per rad/s), and standing, it glances about now and then (GLANCE s
## apart, as far as GLANCE_REACH rad). It breathes (BREATHE: s a breath, rad its neck rises and falls).
const HEAD_SPRING := {"neck": Vector2(55.0, 7.0), "head": Vector2(85.0, 8.5)}
const HEAD_BOB := 0.03
const HEAD_SURGE := 0.035
const HEAD_SIDE := 0.03
const HEAD_FOLLOW := 0.6
const HEAD_MOST := 0.3
const TURN_LEAD := 0.25
const NECK_SHARE := 0.4
const LOOK_MAX := Vector3(1.0, 0.45, 0.25)
const LOOK_EASE := 6.0
const GLANCE := Vector2(2.2, 5.0)
const GLANCE_REACH := Vector2(0.6, 0.15)
const BREATHE := Vector2(3.6, 0.02)
var look_at := Vector3.INF
## User request: its mouth opens (build_dragon_sage.py: the jaw parted from the head at its lips,
## a dark maw inside): breathing, its lips part a little and close; showing its wings over whoever
## it's taken, it roars - wide open, rumbling; eating, it bites; after a chase it pants. (`mouth` 0..1
## opens it more from outside.) As far as JAW_OPEN deg, on a spring (JAW_SPRING).
const JAW_OPEN := 30.0
const JAW_SPRING := Vector2(140.0, 15.0)
var mouth := 0.0
## User request: its robe flows. The skirt's chains (build_dragon_sage.py SKIRT_CHAINS) swing as the
## tail does, but looser - cloth (SKIRT_SWING as ARM_SWING; `drag`: how the air holds it back, /s),
## off its legs as they stride through it (SKIRT_ROOM m beyond their bones), on the ground if it
## comes down to it; a breeze stirring it standing (SKIRT_BREEZE m/s), fluttering it flying
## (SKIRT_FLUTTER m/s).
const SKIRT_SWING := {"follow": Vector2(0.05, 0.02), "keep": 0.95, "sag": 1.0, "bend": 0.6, "drag": 3.0}
const SKIRT_ROOM := 0.05
const SKIRT_BREEZE := 0.35
const SKIRT_FLUTTER := 1.6
## (how far its skirt's bones swing from where the pose has them, on average - rad, as it last swung)
var skirt_swing := 0.0

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
## (each chain swinging free in the world - see `_chain_step`)
var _tail_c := {}
var _arm_c := {}
var _skirt: Array = []
var _fist: Array = []
var _thumb: Array = []
var _relax: Array = []
var _jaw := -1
var _jaw_st := Vector2.ZERO
## (how it's going, from where its skeleton is in the world: velocity m/s; acceleration in its own
## frame, m/s² - x its left, y up, z ahead; turning, rad/s - + to its left)
var _w_at := Vector3.INF
var _w_yaw := 0.0
var _w_vel := Vector3.ZERO
var _w_acc := Vector3.ZERO
var _w_turn := 0.0
var _hips_at: PackedVector3Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _hips_acc := Vector3.ZERO
var _neck_st := Vector4.ZERO
var _head_st := Vector4.ZERO
var _look := Vector2.ZERO
var _look_v := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_t := 1.5
var _rng := RandomNumberGenerator.new()
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
	_sense(sk, dt)
	if auto_fly:
		_air_step(dt)
	_open_wings(dt)
	var cruise := (1.0 + HURRY_BEAT * hurry + FLY_BEAT * fly) / BEAT_TIME
	var rate := cruise
	match air_state:
		Air.UNFOLD:
			rate = 0.0
		Air.POWER:
			rate = POWER_BEATS / _span(TAKEOFF.power)
	if not auto_fly:
		rate = cruise
	rate = lerpf(rate, 0.55, _shown)
	_beat_rate = rate if air_state in [Air.UNFOLD, Air.POWER] else lerpf(_beat_rate, rate, 1.0 - exp(-dt * 3.0))
	beat_phase = fmod(beat_phase + dt * _beat_rate, 1.0)
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
	elif _prep > 0.001:
		# (gathering itself to spring up, or taking its weight as it lands: its hips down, its head kept)
		_crouch_body(sk, _prep, 0.3, -0.3)
	if _shown > 0.001:
		# (showing its wings: its chest up and out, its head up)
		for spine in ["spine_02", "spine_03"]:
			_turn(sk, spine, -0.09 * _shown)
		_turn(sk, "Head", -0.12 * _shown)
	_raised = move_toward(_raised, clampf(raise, 0.0, 1.0), dt * 1.8)
	if _raised > 0.001:
		_raise_arm(sk)
	_close_fist(sk)
	_head_life(sk, dt)
	_jaw_life(sk, dt)
	_arm_life(sk, dt)
	_tail_swing(sk, dt)
	_skirt_swing(sk, dt)
	_beat_wings(sk, dt)


# ------------------------------------------------------------------ the wings

func _beat_wings(sk: Skeleton3D, dt: float) -> void:
	if _chest < 0 or _wings.is_empty():
		return
	var flown := smoothstep(0.0, 1.0, fly)
	var vert := _stroke_v
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
	var amp := BEAT * (1.0 + 0.55 * fly + 0.35 * hurry) * _open * beat_scale * _amp_mul
	var spans := {}
	for w in _wings:
		var side: float = w.side
		# the arm: each bone to its pose, beaten
		for k in 3:
			var b: Dictionary = w.arm[k]
			var want := _pose_dir(b, _stage[k])
			var wave := TAU * (beat_phase - float(b.lag))
			want = _beaten(want, _stroke(amp, b), vert, side)
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
			firsts[f] = _pose_dir(w.fingers[f][0], _stage[2])
		var normal: Vector3 = (firsts["f1"] as Vector3).cross(firsts["f3"]).normalized() * side
		for f in w.fingers:
			var chain: Array = w.fingers[f]
			var rising := 0.0
			for k in chain.size():
				var b: Dictionary = chain[k]
				# (each bone its own way: open, as modelled; flying, the whole wing's turn of it;
				# folded, along its finger's fold)
				var want: Vector3 = firsts[f] if k == 0 else _pose_dir(b, _stage[3])
				var wave := TAU * (beat_phase - float(b.lag))
				rising = maxf(0.0, cos(wave)) * _open * (1.0 if _beat_rate > 0.0 else 0.0)
				if k > 0:
					# (folded, in toward the arm; spread, down out of the membrane - less coming up)
					var curl := deg_to_rad(FOLD_CURL * k) * (1.0 - _stage[3]) * side
					var camber := deg_to_rad(CAMBER * k) * _kind * _stage[3] * (1.0 - 0.7 * rising)
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
						want = Basis(axis.normalized(), minf(deg_to_rad(close) * rising * (0.35 + 0.65 * vert),
							want.angle_to(to_lead) * 0.8)) * want
				var a := _stroke(amp, b)
				a += deg_to_rad(FLUTTER * flown * sin(_time * 13.0 + k * 1.7 + float(f.substr(1)) * 2.3)) * (k + 1) / 4.0
				want = _beaten(want, a, vert, side)
				var world := (frame * want).normalized()
				if k == 0 and (f == "f1" or f == "f3"):
					spans[f + str(side)] = world
				_point(sk, b, world)
	_fill_membrane(dt, amp, maxf(flown, vert * _open), spans)


## A wing bone's way in the chest's frame, its stage `g` of the way open: from its fold toward how
## it's opening to - as modelled (on its feet), or spread (flying, or showing them; `_kind`) - the
## spread wing swept back the faster it flies, swept forward and tilted up braking to land, raised
## and turned to the front showing them.
func _pose_dir(b: Dictionary, g: float) -> Vector3:
	var fold: Vector3 = b.fold
	var side: float = b.side
	var to: Vector3 = (b.rest as Vector3).slerp(b.flight, _kind).normalized()
	if hurry > 0.0:
		to = Basis(Vector3.UP, -FLY_SWEEP * hurry * side * _kind) * to
	if _flare > 0.0:
		to = Basis(Vector3.RIGHT, -deg_to_rad(FLARE.x) * _flare) * (Basis(Vector3.UP, deg_to_rad(FLARE.y) * _flare * side) * to)
	if _shown > 0.0:
		to = Basis(Vector3.RIGHT, -deg_to_rad(DISPLAY.y) * _shown) * (Basis(Vector3.BACK, deg_to_rad(DISPLAY.x) * _shown * side) * to)
	if fold.angle_to(to) > PI - 0.01:
		return fold.lerp(to, g).normalized()
	return fold.slerp(to.normalized(), g).normalized()


## The beat's angle for bone `b` now (rad): its wave down the wing - in the air, high above and
## less far below (STROKE_DOWN of it: the wings beat down to under the body's side, not round
## its front), smoothly.
func _stroke(amp: float, b: Dictionary) -> float:
	var wave := TAU * (beat_phase - float(b.lag))
	var down := lerpf(1.0, STROKE_DOWN, _stroke_v)
	return deg_to_rad(amp * ((1.0 - down) * 0.5 + (1.0 + down) * 0.5 * sin(wave)))


## Turned by the beat (`a` rad): in the air (or about to be - `vert`), up and down about its
## forward axis; open on its feet, forward and back.
func _beaten(want: Vector3, a: float, vert: float, side: float) -> Vector3:
	want = Basis(Vector3.BACK, a * vert * side) * want
	return Basis(Vector3.UP, a * SWEEP * (1.0 - vert) * side) * want


## The wings' stages (see OPEN_RATE) toward open as far as it means them to be - flying, landing,
## showing them: wholly, spread; else `spread`, as modelled.
func _open_wings(dt: float) -> void:
	var aloft := air_state != Air.GROUND or (not auto_fly and fly > 0.0)
	var target := 1.0 if aloft or display > 0.0 else clampf(maxf(spread, fly), 0.0, 1.0)
	var opening := target > _stage[0] or target > _stage[3]
	for i in 4:
		var want: float = target
		if want > _stage[i] and i > 0 and _stage[i - 1] < minf(target, 1.0) * OPEN_GATE:
			want = _stage[i]
		elif want < _stage[i] and i < 3 and _stage[i + 1] > maxf(_stage[i] - (1.0 - OPEN_GATE) * 0.5, 0.001):
			want = _stage[i]
		_stage[i] = move_toward(_stage[i], want, dt * OPEN_RATE * (1.0 + hurry) * fly_rate)
	_open = (_stage[0] + _stage[1] + _stage[2] + _stage[3]) * 0.25
	# (spread, not as modelled: flying or showing; back as modelled only once mostly folded)
	var kind := 1.0 if aloft or display > 0.0 else (fly if not auto_fly else 0.0)
	if kind < _kind and _open > 0.3 and not opening:
		kind = _kind
	_kind = move_toward(_kind, kind, dt * 2.0)
	_shown = move_toward(_shown, clampf(display, 0.0, 1.0) * smoothstep(0.6, 1.0, _stage[3]), dt * 1.6)
	var vert := 1.0 if aloft or display > 0.0 else 0.0
	_stroke_v = move_toward(_stroke_v, vert, dt * 2.5)
	if not auto_fly:
		_amp_mul = lerpf(1.0, 0.35, _shown)


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


# ------------------------------------------------------------------ taking off, landing

## Seconds a stage of taking off or landing takes, as quick as it's going.
func _span(t: float) -> float:
	return t / ((1.0 + hurry) * maxf(fly_rate, 0.2))


## A step of its flight (see TAKEOFF, LANDING): what it's doing, and so how much its body flies
## (`fly`), how far up it is (`airborne`), its beat's strength, its crouch, its wings' brake.
func _air_step(dt: float) -> void:
	_air_t += dt
	var p := 0.0
	match air_state:
		Air.GROUND:
			_amp_mul = lerpf(_amp_mul, lerpf(1.0, 0.35, _shown), 1.0 - exp(-dt * 3.0))
			fly = move_toward(fly, 0.0, dt * 2.0)
			airborne = move_toward(airborne, 0.0, dt * 2.0)
			_prep = move_toward(_prep, 0.0, dt * 2.0)
			_ready = 0.0
			if want_fly:
				_to(Air.UNFOLD)
		Air.UNFOLD:
			p = clampf(_air_t / _span(TAKEOFF.unfold), 0.0, 1.0)
			_prep = PREP_CROUCH * smoothstep(0.25, 1.0, p)
			# (the wings rising high to the top of the first stroke, the beat held there)
			_ready = smoothstep(0.45, 1.0, p)
			beat_phase = 0.25
			_amp_mul = POWER_AMP * _ready
			fly = move_toward(fly, 0.15, dt)
			if not want_fly:
				_to(Air.GROUND)
			elif p >= 1.0 and _stage[3] > 0.96:
				_to(Air.POWER)
		Air.POWER:
			p = clampf(_air_t / _span(TAKEOFF.power), 0.0, 1.0)
			_amp_mul = POWER_AMP
			_ready = 1.0
			# (sprung up on the first stroke; each down-stroke lifting it, a little sinking between)
			_prep = PREP_CROUCH * (1.0 - smoothstep(0.0, 0.12, p))
			airborne = maxf(airborne, 0.42 * smoothstep(0.0, 0.25, p) - 0.06 * smoothstep(0.25, 0.5, p)
				+ 0.64 * smoothstep(0.5, 0.78, p))
			fly = maxf(fly, smoothstep(0.05, 0.8, p))
			if p >= 1.0:
				_to(Air.CRUISE)
		Air.CRUISE:
			_amp_mul = lerpf(_amp_mul, 1.0, 1.0 - exp(-dt * 2.5))
			fly = move_toward(fly, 1.0, dt * 2.0)
			airborne = move_toward(airborne, 1.0, dt * 1.5)
			_prep = 0.0
			if not want_fly:
				_to(Air.FLARE)
		Air.FLARE:
			p = clampf(_air_t / _span(LANDING.flare), 0.0, 1.0)
			# (one strong stroke forward against the air, then held, sinking)
			_flare = smoothstep(0.0, 0.45, p)
			_amp_mul = lerpf(_amp_mul, 0.25, 1.0 - exp(-dt * 6.0))
			airborne = minf(airborne, 1.0 - smoothstep(0.0, 1.0, p))
			# (its legs down to stand as it comes in)
			fly = minf(fly, 1.0 - smoothstep(0.3, 1.0, p))
			if want_fly:
				_to(Air.CRUISE)
			elif p >= 1.0:
				_to(Air.SETTLE)
		Air.SETTLE:
			p = clampf(_air_t / _span(LANDING.settle), 0.0, 1.0)
			airborne = 0.0
			fly = 0.0
			_prep = LAND_DIP * sin(PI * minf(p * 1.6, 1.0))
			_amp_mul = lerpf(_amp_mul, 0.1, 1.0 - exp(-dt * 6.0))
			_flare = 1.0 - smoothstep(0.2, 1.0, p)
			if want_fly:
				_to(Air.UNFOLD)
			elif p >= 1.0:
				_to(Air.GROUND)
	if air_state != Air.FLARE and air_state != Air.SETTLE:
		_flare = move_toward(_flare, 0.0, dt * 3.0)


func _to(state: Air) -> void:
	if state == Air.POWER:
		beat_phase = 0.25
	air_state = state
	_air_t = 0.0


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
	_chain_step(sk, _tail_c, _chain_want(sk, _tail_c), dt, _leg_capsules(sk))


# ------------------------------------------------------------------ chains swinging free

## Where the pose puts a chain's joints, in the world: its root, then each bone's end.
func _chain_want(sk: Skeleton3D, c: Dictionary) -> PackedVector3Array:
	var xf := sk.global_transform
	var bones: Array = c.bones
	var lens: Array = c.len
	var want := PackedVector3Array()
	want.resize(bones.size() + 1)
	want[0] = xf * sk.get_bone_global_pose(bones[0]).origin
	for k in bones.size():
		var g := sk.get_bone_global_pose(bones[k])
		want[k + 1] = xf * (g.origin + g.basis.y.normalized() * float(lens[k]))
	return want


## The legs as capsules in the world: [from, to] for each thigh and calf.
func _leg_capsules(sk: Skeleton3D) -> Array:
	var xf := sk.global_transform
	var legs: Array = []
	for pair in [["thigh_l", "calf_l"], ["calf_l", "foot_l"], ["thigh_r", "calf_r"], ["calf_r", "foot_r"]]:
		var a: int = _body.get(pair[0], -1)
		var b: int = _body.get(pair[1], -1)
		if a >= 0 and b >= 0:
			legs.append([xf * sk.get_bone_global_pose(a).origin, xf * sk.get_bone_global_pose(b).origin])
	return legs


## A chain of bones (`c`: "bones", each one's "len"gth; how it swings - "follow" root .. tip, the
## share of the way to its pose each joint's pulled per frame at 60/s; "keep", the share of its swing
## it keeps per frame; "sag", its weight, m/s²; "bend", rad it may bend from its pose at a joint;
## "radius" root .. tip and "room" beyond it, m, kept off the legs; "drag" /s and "wind" m/s, the air
## on it) swinging free in the world toward its pose's joints `want`: its swing comes of the body's
## own going - lagging when it sets off, swinging on when it stops or turns - never through the
## ground or its legs. Its joints are kept in `c` ("p", "prev", "at" - where the skeleton was).
func _chain_step(sk: Skeleton3D, c: Dictionary, want: PackedVector3Array, dt: float, legs: Array) -> void:
	var bones: Array = c.bones
	var lens: Array = c.len
	var n := bones.size()
	if n == 0:
		return
	var xf := sk.global_transform
	var scale := xf.basis.get_scale().x
	var p: PackedVector3Array = c.get("p", PackedVector3Array())
	var prev: PackedVector3Array = c.get("prev", PackedVector3Array())
	var at: Vector3 = c.get("at", Vector3.INF)
	if p.size() != n or dt <= 0.0 or not at.is_finite() or at.distance_to(xf.origin) > 3.0 * scale:
		p = want.slice(1)
		prev = p.duplicate()
	c.at = xf.origin
	var ground := xf.origin.y
	var steps := 2
	var h := dt / steps
	var keep := pow(float(c.keep), h * 60.0)
	var follow: Vector2 = c.follow
	var radius: Vector2 = c.get("radius", Vector2.ZERO)
	var room: float = c.get("room", 0.0)
	var drag: float = c.get("drag", 0.0)
	var wind: Vector3 = c.get("wind", Vector3.ZERO) * scale
	var limit: float = c.bend
	for _s in steps:
		for k in n:
			var t := float(k) / maxf(n - 1, 1)
			var q: Vector3 = p[k]
			var v: Vector3 = (q - prev[k]) * keep
			prev[k] = q
			var acc := Vector3.DOWN * float(c.sag) * scale
			if drag > 0.0 and h > 0.0:
				acc += (wind - v / h) * drag
			q += v + acc * h * h
			var pull := lerpf(follow.x, follow.y, t)
			q += (want[k + 1] - q) * (1.0 - pow(1.0 - pull, h * 60.0))
			p[k] = q
		for _pass in 2:
			var from: Vector3 = want[0]
			for k in n:
				var t := float(k) / maxf(n - 1, 1)
				var q: Vector3 = p[k]
				var link := float(lens[k]) * scale
				var dir := (q - from)
				var pose_dir := (want[k + 1] - want[k]).normalized()
				if dir.length() < 0.0001:
					dir = pose_dir
				dir = dir.normalized()
				# (bent no further than its limit from the pose's way)
				var bent := dir.angle_to(pose_dir)
				if bent > limit:
					var axis := pose_dir.cross(dir).normalized()
					if axis.length() > 0.5:
						dir = pose_dir.rotated(axis, limit)
				q = from + dir * link
				var r := lerpf(radius.x, radius.y, t) * scale
				# (out of its legs, off the ground)
				for leg in legs:
					var a: Vector3 = leg[0]
					var ab: Vector3 = (leg[1] as Vector3) - a
					var on := a + ab * clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
					var off := q - on
					var space := r + room * scale
					if off.length() < space:
						q = on + (off.normalized() if off.length() > 0.0001 else Vector3.BACK) * space
				q.y = maxf(q.y, ground + r)
				p[k] = q
				from = q
	c.p = p
	c.prev = prev
	# The bones along it.
	var inv := xf.affine_inverse()
	for k in n:
		var g := sk.get_bone_global_pose(bones[k])
		_aim(sk, bones[k], inv * p[k] - g.origin)


## The skirt's chains swinging (see SKIRT_SWING).
func _skirt_swing(sk: Skeleton3D, dt: float) -> void:
	if _skirt.is_empty():
		return
	var legs := _leg_capsules(sk)
	var flown := smoothstep(0.0, 1.0, fly)
	var still := 1.0 - clampf(_w_vel.length() / 1.5, 0.0, 1.0)
	var swung := 0.0
	var n := 0
	for k in _skirt.size():
		var c: Dictionary = _skirt[k]
		var ph := float(k) * 0.9
		c.wind = Vector3(sin(_time * 0.71 + ph * 0.3) + 0.4 * sin(_time * 1.9 + ph), 0.0,
				cos(_time * 0.53 + ph * 0.2) + 0.4 * sin(_time * 2.3 + ph * 1.3)) * SKIRT_BREEZE * still \
			+ Vector3(sin(_time * 11.0 + ph * 1.7), 0.5 * sin(_time * 8.3 + ph), cos(_time * 13.0 + ph * 2.1)) \
				* SKIRT_FLUTTER * flown
		var want := _chain_want(sk, c)
		_chain_step(sk, c, want, dt, legs)
		var p: PackedVector3Array = c.p
		for i in p.size():
			swung += (p[i] - (want[0] if i == 0 else p[i - 1])).angle_to(want[i + 1] - want[i])
			n += 1
	skirt_swing = swung / maxf(n, 1)


# ------------------------------------------------------------------ alive

## How it's going, from where its skeleton is in the world (see `_w_vel`), and the clip's own rise
## and fall (and sway) of its hips.
func _sense(sk: Skeleton3D, dt: float) -> void:
	var xf := sk.global_transform
	var scale := maxf(xf.basis.get_scale().x, 0.0001)
	var fwd := xf.basis.z
	var yaw := atan2(fwd.x, fwd.z)
	var hips: int = _body.get("pelvis", -1)
	var hp := sk.get_bone_global_pose(hips).origin if hips >= 0 else Vector3.ZERO
	if not _w_at.is_finite() or dt <= 0.0 or _w_at.distance_to(xf.origin) > 2.0 * scale:
		_w_at = xf.origin
		_w_yaw = yaw
		_w_vel = Vector3.ZERO
		_hips_at = [hp, hp, hp]
		return
	var v := (xf.origin - _w_at) / dt / scale
	var acc := xf.basis.orthonormalized().inverse() * ((v - _w_vel) / dt)
	_w_vel = _w_vel.lerp(v, 1.0 - exp(-dt * 14.0))
	_w_acc = _w_acc.lerp(acc.limit_length(12.0), 1.0 - exp(-dt * 10.0))
	_w_turn = lerpf(_w_turn, wrapf(yaw - _w_yaw, -PI, PI) / dt, 1.0 - exp(-dt * 6.0))
	_w_at = xf.origin
	_w_yaw = yaw
	_hips_at = [hp, _hips_at[0], _hips_at[1]]
	var hips_acc := (_hips_at[0] - 2.0 * _hips_at[1] + _hips_at[2]) / (dt * dt)
	_hips_acc = _hips_acc.lerp(hips_acc.limit_length(8.0), 1.0 - exp(-dt * 20.0))


## A spring's state (x angle, y its speed; z, w the same for a second angle) pushed by `force`
## (rad/s², each angle) on `spring` (stiffness, damping) for `dt`; its acceleration out in `acc`.
func _spring2(st: Vector4, force: Vector2, spring: Vector2, dt: float) -> Vector4:
	var a := Vector2(-spring.x * st.x - spring.y * st.y + force.x, -spring.x * st.z - spring.y * st.w + force.y)
	st.y += a.x * dt
	st.w += a.y * dt
	st.x = clampf(st.x + st.y * dt, -HEAD_MOST, HEAD_MOST)
	st.z = clampf(st.z + st.w * dt, -HEAD_MOST, HEAD_MOST)
	return st


## The head and neck (see HEAD_SPRING).
func _head_life(sk: Skeleton3D, dt: float) -> void:
	var neck: int = _body.get("neck_01", -1)
	var head: int = _body.get("Head", -1)
	if neck < 0 or head < 0 or dt <= 0.0:
		return
	var flown := smoothstep(0.0, 1.0, fly)
	# Its weight swung on its neck: up and down (pitch: + nods it), aside (roll: + to its right).
	var up := _hips_acc.y + _w_acc.y
	var push := Vector2((up * HEAD_BOB - _w_acc.z * HEAD_SURGE), (_w_acc.x + _hips_acc.x) * HEAD_SIDE)
	var ns: Vector2 = HEAD_SPRING.neck
	var hs: Vector2 = HEAD_SPRING.head
	var was := Vector2(_neck_st.y, _neck_st.w)
	_neck_st = _spring2(_neck_st, push * ns.x, ns, dt)
	var neck_acc := (Vector2(_neck_st.y, _neck_st.w) - was) / dt
	_head_st = _spring2(_head_st, (push * 0.4 * hs.x) - neck_acc * HEAD_FOLLOW, hs, dt)
	# Where it looks: whoever it's after; else, standing, about it now and then; turning, into the turn.
	# (from where the clip has its head facing - its own frame against its rest)
	var face := sk.get_bone_global_pose(head).basis.orthonormalized() \
		* sk.get_bone_global_rest(head).basis.orthonormalized().inverse()
	var want := Vector2.ZERO
	if look_at.is_finite() and sk.is_inside_tree():
		var d := face.inverse() * (sk.global_transform.affine_inverse() * look_at - sk.get_bone_global_pose(head).origin)
		var yaw := atan2(d.x, d.z)
		if absf(yaw) < 2.4:
			want = Vector2(clampf(yaw, -LOOK_MAX.x, LOOK_MAX.x),
				clampf(atan2(-d.y, Vector2(d.x, d.z).length()), -LOOK_MAX.z, LOOK_MAX.y))
	else:
		_glance_t -= dt
		if _glance_t <= 0.0:
			_glance_t = _rng.randf_range(GLANCE.x, GLANCE.y)
			_glance = Vector2(_rng.randf_range(-1.0, 1.0) * GLANCE_REACH.x, _rng.randf_range(-0.3, 1.0) * GLANCE_REACH.y) \
				if _rng.randf() < 0.75 else Vector2.ZERO
		want = _glance * (1.0 - clampf(pace * 1.5, 0.0, 1.0)) * (1.0 - flown)
	if not look_at.is_finite():
		want.x += clampf(_w_turn * TURN_LEAD, -0.5, 0.5)
	want *= (1.0 - _crouched) * (1.0 - 0.5 * flown)
	# (critically damped toward it)
	var k := LOOK_EASE
	_look_v += ((want - _look) * k * k - _look_v * 2.0 * k) * dt
	_look += _look_v * dt
	var side := face * Vector3.RIGHT
	var turn_up := face * Vector3.UP
	var ahead := face * Vector3.BACK
	var breath := BREATHE.y * sin(TAU * _time / BREATHE.x)
	_turn_bone(sk, neck, _look.x * NECK_SHARE, turn_up)
	_turn_bone(sk, neck, _look.y * NECK_SHARE + _neck_st.x + breath, side)
	_turn_bone(sk, neck, _neck_st.z, ahead)
	_turn_bone(sk, head, _look.x * (1.0 - NECK_SHARE), turn_up)
	_turn_bone(sk, head, _look.y * (1.0 - NECK_SHARE) + _head_st.x - breath * 0.6, side)
	_turn_bone(sk, head, _head_st.z, ahead)


## The jaw (see JAW_OPEN).
func _jaw_life(sk: Skeleton3D, dt: float) -> void:
	var head: int = _body.get("Head", -1)
	if _jaw < 0 or head < 0 or dt <= 0.0:
		return
	var want := 0.035 + 0.045 * (0.5 + 0.5 * sin(TAU * _time / BREATHE.x - 0.6))
	want = maxf(want, hurry * 0.22 * (0.6 + 0.4 * sin(_time * 9.0)))
	if _crouched > 0.6:
		want = maxf(want, 0.55 * maxf(0.0, sin(_time * 6.5)))
	if _shown > 0.05:
		want = maxf(want, smoothstep(0.05, 0.6, _shown) * (0.85 + 0.06 * sin(_time * 31.0)))
	want = maxf(want, clampf(mouth, 0.0, 1.0))
	var a := -JAW_SPRING.x * (_jaw_st.x - want) - JAW_SPRING.y * _jaw_st.y
	_jaw_st.y += a * dt
	_jaw_st.x = clampf(_jaw_st.x + _jaw_st.y * dt, 0.0, 1.05)
	var hg := sk.get_bone_global_pose(head).basis.orthonormalized() * sk.get_bone_global_rest(head).basis.orthonormalized().inverse()
	_turn_bone(sk, _jaw, deg_to_rad(JAW_OPEN) * _jaw_st.x, hg * Vector3.RIGHT)


## The free arm and its fingers (see ARM_SWING, RELAX).
func _arm_life(sk: Skeleton3D, dt: float) -> void:
	var lag := 0.0
	if not _arm_c.is_empty():
		var want := _chain_want(sk, _arm_c)
		_chain_step(sk, _arm_c, want, dt, [])
		# (how far its hand lags its pose, across its palm: its fingers flick with it)
		var hand: int = (_arm_c.bones as Array)[2]
		var g := sk.get_bone_global_pose(hand)
		var now := (g.basis * Vector3.UP).normalized()
		var was := sk.global_transform.basis.inverse() * (want[3] - want[2])
		var palm := (g.basis.orthonormalized() * sk.get_bone_global_rest(hand).basis.orthonormalized().inverse()) * Vector3.DOWN
		lag = clampf(now.cross(was.normalized()).length() * signf(was.normalized().dot(palm) - now.dot(palm)), -0.5, 0.5) \
			if was.length() > 0.0001 else 0.0
	var breath := sin(TAU * _time / BREATHE.x + 1.1)
	for f in _relax:
		var ang: float = f.angle + deg_to_rad(RELAX_BREATH * breath + RELAX_FLICK * lag) * float(f.share)
		sk.set_bone_pose_rotation(f.bone, sk.get_bone_pose_rotation(f.bone) * Quaternion(f.axis, maxf(ang, 0.0)))


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
func _crouch_body(sk: Skeleton3D, c: float, lean := 1.0, look := 1.0) -> void:
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
		_turn(sk, spine, c * CROUCH_LEAN * lean / 3.0)
	_turn(sk, "neck_01", c * CROUCH_LOOK * look * 0.5)
	_turn(sk, "Head", c * CROUCH_LOOK * look * 0.5)


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
	_wrap_thumb(sk, middle)
	var across := hand.basis.x.normalized()
	if _knuckles.size() == 2:
		across = (sk.get_bone_global_pose(_knuckles[0]).origin - sk.get_bone_global_pose(_knuckles[1]).origin).normalized()
	var up := hand.basis.y.normalized()
	var z := across.cross(up).normalized()
	grip = Transform3D(Basis(across, z.cross(across).normalized(), z), middle)


## The thumb laid over the curled fingers (see THUMB_ON): each of its bones turned in turn toward
## putting its tip there - its first any way, the others only about their knuckles' own axis.
func _wrap_thumb(sk: Skeleton3D, hole: Vector3) -> void:
	if _thumb.size() != 3:
		return
	# (the curled fingers' front, index to little: their middle bones' middles, out over their backs -
	# away from the hole they close round)
	var front := PackedVector3Array()
	for f in ["index", "middle", "ring", "pinky"]:
		var b: int = _body.get(f + "_02_r", -1)
		var e: int = _body.get(f + "_03_r", -1)
		if b < 0 or e < 0:
			return
		var mid := (sk.get_bone_global_pose(b).origin + sk.get_bone_global_pose(e).origin) * 0.5
		var out := mid - hole
		front.append(mid + (out.normalized() if out.length() > 0.0001 else Vector3.DOWN) * THUMB_ON.z)
	var at := func(u: float) -> Vector3:
		var k := mini(int(u), front.size() - 2)
		return front[k].lerp(front[k + 1], u - k)
	var knuckle_at: Vector3 = at.call(THUMB_ON.x)
	var tip_at: Vector3 = at.call(THUMB_ON.y)
	var last: Dictionary = _thumb[2]
	var knuckle := func() -> Vector3: return sk.get_bone_global_pose(last.bone).origin
	var tip := func() -> Vector3:
		var gl := sk.get_bone_global_pose(last.bone)
		return gl.origin + gl.basis.y.normalized() * float(last.len)
	# its last knuckle onto the front by its first two bones - bent outward, round the fist, not
	# into it (two bones: where its middle knuckle must be) - then its last bone on across it
	var root := sk.get_bone_global_pose(_thumb[0].bone).origin
	var l0: float = _thumb[0].len
	var l1: float = _thumb[1].len
	var to := knuckle_at - root
	var d := clampf(to.length(), absf(l0 - l1) + 0.001, l0 + l1 - 0.0005)
	var along := to.normalized()
	var bulge := (root + knuckle_at) * 0.5 - hole
	bulge = (bulge - along * bulge.dot(along))
	if bulge.length() < 0.0001:
		bulge = along.cross(Vector3.UP)
	bulge = bulge.normalized()
	var a := (l0 * l0 - l1 * l1 + d * d) / (2.0 * d)
	var mid := root + along * a + bulge * sqrt(maxf(l0 * l0 - a * a, 0.0))
	_aim(sk, _thumb[0].bone, mid - root)
	_aim(sk, _thumb[1].bone, knuckle_at - sk.get_bone_global_pose(_thumb[1].bone).origin)
	_aim(sk, _thumb[2].bone, tip_at - sk.get_bone_global_pose(_thumb[2].bone).origin)
	thumb_seen = [knuckle_at, knuckle.call(), tip_at, tip.call()]


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
	_rng.seed = hash(get_instance_id())
	for name in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "thigh_l", "calf_l", "foot_l",
			"thigh_r", "calf_r", "foot_r", "upperarm_l", "lowerarm_l", "upperarm_r", "lowerarm_r", "hand_r", "hand_l",
			"index_02_r", "middle_02_r", "ring_02_r", "pinky_02_r", "index_03_r", "middle_03_r", "ring_03_r", "pinky_03_r"]:
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
	_tail_c = {"bones": _tail, "len": _tail_len, "follow": TAIL_FOLLOW, "keep": TAIL_KEEP, "sag": TAIL_SAG,
		"bend": TAIL_BEND, "radius": TAIL_RADIUS, "room": 0.07}
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
			if f == "thumb":
				var nxt := sk.find_bone("thumb_%02d_r" % (j + 2))
				var length := sk.get_bone_global_rest(nxt).origin.distance_to(rest.origin) if nxt >= 0 \
					else float((_thumb[j - 1] as Dictionary).len) if j > 0 else 0.03
				_thumb.append({"bone": b, "len": length})
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
	# the free hand at rest: each finger bone's easy curl, as the fist's (its palm down at rest)
	for f in RELAX:
		for j in 3:
			var b := sk.find_bone("%s_%02d_l" % [f, j + 1])
			if b < 0:
				continue
			var rest := sk.get_bone_global_rest(b)
			var dir := rest.basis.y.normalized()
			var palm := Vector3.DOWN if f != "thumb" else Vector3(-1.0, -0.6, 0.0).normalized()
			var axis := (rest.basis.orthonormalized().inverse() * dir.cross(palm).normalized()).normalized()
			_relax.append({"bone": b, "axis": axis, "angle": deg_to_rad(float(RELAX[f][j])), "share": 0.5 + 0.25 * j})
	_jaw = sk.find_bone("jaw")
	# the chains swinging free: the free arm (to its knuckles), the skirt's
	var arm: Array = []
	for name in ["upperarm_l", "lowerarm_l", "hand_l"]:
		if sk.find_bone(name) >= 0:
			arm.append(sk.find_bone(name))
	var knuckle := sk.find_bone("middle_01_l")
	if arm.size() == 3 and knuckle >= 0:
		var lens: Array = []
		for ai in 3:
			var to := knuckle if ai == 2 else int(arm[ai + 1])
			lens.append(sk.get_bone_global_rest(arm[ai]).origin.distance_to(sk.get_bone_global_rest(to).origin))
		_arm_c = ARM_SWING.duplicate()
		_arm_c.bones = arm
		_arm_c.len = lens
	for ci in 16:
		var chain: Array = []
		for j in 3:
			var b := sk.find_bone("skirt_%d_%02d" % [ci, j + 1])
			if b >= 0:
				chain.append(b)
		if chain.size() != 3:
			break
		var lens: Array = []
		for j in 3:
			lens.append(sk.get_bone_global_rest(chain[j]).origin.distance_to(sk.get_bone_global_rest(chain[j + 1]).origin)
				if j < 2 else float(lens[1]))
		var c := SKIRT_SWING.duplicate()
		c.bones = chain
		c.len = lens
		c.radius = Vector2(0.02, 0.015)
		c.room = SKIRT_ROOM
		_skirt.append(c)
	_chest = sk.find_bone("spine_03")
	if _chest < 0:
		return
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var w := {"side": s, "arm": [], "fingers": {}}
		var ok := true
		for part in ["", "_02", "_03"]:
			var b := _wing_bone(sk, "wing_%s%s" % [side, part], FOLD[part], s)
			if b.is_empty():
				ok = false
				break
			(w.arm as Array).append(b)
		for f in ["f1", "f2", "f3"]:
			var chain: Array = []
			for j in 4:
				var name := "wing_%s_%s" % [side, f] + ("" if j == 0 else "_%02d" % (j + 1))
				var b := _wing_bone(sk, name, FOLD["_" + f], s)
				if b.is_empty():
					ok = false
					break
				chain.append(b)
			w.fingers[f] = chain
		if ok:
			_spread_wing(sk, w, s)
			# (each bone's lag: how far out its joint is, against the first finger's last knuckle)
			var root := sk.get_bone_global_rest((w.arm[0] as Dictionary).bone).origin
			var reach := root.distance_to(sk.get_bone_global_rest((w.fingers.f1[3] as Dictionary).bone).origin)
			for b in (w.arm as Array) + w.fingers.f1 + w.fingers.f2 + w.fingers.f3:
				b.lag = WAVE * root.distance_to(sk.get_bone_global_rest(b.bone).origin) / maxf(reach, 0.01)
			_wings.append(w)


func _wing_bone(sk: Skeleton3D, name: String, fold: Vector3, s: float) -> Dictionary:
	var i := sk.find_bone(name)
	if i < 0:
		return {}
	var rest := (sk.get_bone_global_rest(i).basis * Vector3.UP).normalized()
	return {"bone": i, "parent": sk.get_bone_parent(i), "rest": rest, "side": s,
		"fold": Vector3(fold.x * s, fold.y, fold.z).normalized(), "flight": rest}


## Each bone of a side's wing (`w`) its way spread (SPREAD_*): its `flight`.
func _spread_wing(sk: Skeleton3D, w: Dictionary, s: float) -> void:
	var out := Vector3(s, 0.0, 0.0)
	var aim := func(deg: Vector2) -> Vector3:
		var az := deg_to_rad(deg.x)
		var el := deg_to_rad(deg.y)
		return (out * cos(az) * cos(el) + Vector3.FORWARD * sin(az) * cos(el) + Vector3.UP * sin(el)).normalized()
	for k in 3:
		(w.arm[k] as Dictionary).flight = aim.call(SPREAD_ARM[["", "_02", "_03"][k]])
	# (the fan's back at rest - it stands behind, facing back - laid up)
	var f1: Vector3 = (w.fingers.f1[0] as Dictionary).rest
	var f3: Vector3 = (w.fingers.f3[0] as Dictionary).rest
	var back := f1.cross(f3).normalized()
	if back.z > 0.0:
		back = -back
	for f in w.fingers:
		var chain: Array = w.fingers[f]
		var base: Vector3 = (chain[0] as Dictionary).rest
		var to: Vector3 = aim.call(SPREAD_FAN[f])
		var rn := (back - base * back.dot(base)).normalized()
		var tn := (Vector3.UP - to * Vector3.UP.dot(to)).normalized()
		var turn := Basis(to, tn, to.cross(tn)) * Basis(base, rn, base.cross(rn)).inverse()
		for k in chain.size():
			var b: Dictionary = chain[k]
			var d: Vector3 = (turn * (b.rest as Vector3)).normalized()
			b.flight = to if k == 0 else d.slerp(to, SPREAD_STRAIGHT).normalized()
