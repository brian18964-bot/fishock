class_name DragonGait
extends RefCounted

## The dragon's feet (user request: it goes about on its own, so as natural as can be - an NPC's moves
## are much of the game's feel; not to be skimped). BigGhost moves it; this picks which of its moves
## plays (the user's Mixamo clips, taken off the spot - DragonMoves, tools/dragon_moves.py), how fast,
## from where in it, and which way its body faces:
##
##   stood (Idle / Idle_Lamp) -> it starts off (Start) -> walks (Walk; Prowl when it's looking for
##   someone) -> stops (Stop) - or, after you, runs (Chase) and pulls up (Run_Stop);
##   turning as it walks: a veer (Veer_L / Veer_R, ~36 deg), a quarter turn (Turn_L / Turn_R, ~90),
##   right round (Turn_180) - its body turned with the clip's own feet (the clip's turn, sampled,
##   scaled to the turn it has to make, the way it has to make it), not slid round;
##   stood and facing someone behind it: it turns on the spot.
##
## Each move's speed is matched to the ground (how far its feet go in it - its hips' path times its
## stride, at the model's size - against how fast it's going), and one move goes on from another at
## the same step (its feet's lead, `feet`, matched: the left foot ahead in one, ahead in the next).

## (m/s) it starts off above MOVE_ON, stops under STOP_BELOW (a moment: STOP_WAIT s); runs above
## RUN_ABOVE when after someone, back to a walk under RUN_BELOW; pulls up from a run (Run_Stop) when,
## slowing as it is, it would be stood within HALT_LOOK s - under RUN_HALT; easing back, it walks on
const MOVE_ON := 0.18
const STOP_BELOW := 0.1
const STOP_WAIT := 0.18
const RUN_ABOVE := 1.9
const RUN_BELOW := 1.5
const RUN_HALT := 0.5
const HALT_LOOK := 0.3
## (deg) how far off its way it has to be for each turn: under VEER it steers; under QUARTER it veers;
## under ROUND a quarter turn; past it right round (Turn_180, or Turn_180_L - it mirrored - to its left)
const VEER := 22.0
const QUARTER := 62.0
const ROUND := 135.0
## (m/s) right round on the spot only slower than this
const PIVOT_BELOW := 0.45
## (rad/s) how fast it steers between turns: walking, running
const STEER_WALK := 1.3
const STEER_RUN := 3.2
## (deg) stood, past this it steps round on the spot to face someone (a right-round turn, as far as
## it has to); under it only its head comes round (DragonRig's look) - turned, its body slid its feet
const STOOD_TURN := 40.0
## (s) a turn's not begun again for this long after one ends (no turning back and forth)
const TURN_REST := 0.35
## how far a move's speed is stretched to keep its feet on the ground (its rate)
const RATE := Vector2(0.65, 1.45)
## (s) crossfades: into a loop, out of a one-off, to standing
const BLEND := 0.3
const BLEND_STAND := 0.45

var anim: AnimationPlayer
var moves: Dictionary
var size := 1.0
var state := "idle"
var clip := ""
## its body's heading (rad: the model's yaw, as RunView3D's - turning left is up)
var yaw := 0.0
var _from := 0.0
var _by := 0.0
var _slow := 0.0
## (m/s²) how fast it's speeding up (-: slowing), smoothed; and its speed the frame before
var _accel := 0.0
var _was_speed := 0.0
var _rest := 0.0
var _start_at := 0.0
var _start_out := 0.0
var _stop_at := 0.0
## (for the probes and the tests: each move it went into, and when)
var log: Array = []
var _t := 0.0


func _init(p_anim: AnimationPlayer, p_moves: Dictionary, p_size: float, p_yaw: float) -> void:
	anim = p_anim
	moves = p_moves
	size = p_size
	yaw = p_yaw
	for c in moves:
		if anim.has_animation(c):
			anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR if bool(moves[c].get("loop", false)) \
				else Animation.LOOP_NONE
	# Where it starts off from in Start (its first stir), where it's into its stride (its pace up to
	# its walk's), and where Stop's last steps begin (its last ~STOP_LAST m to go)
	var st: Dictionary = moves.get("Start", {})
	if not st.is_empty():
		var f: Array = st.fwd
		var r := float(st.rate)
		var walk := _pace("Walk") / maxf(size * float(st.stride), 1e-4)
		_start_at = 0.0
		for i in f.size():
			if float(f[i]) > 0.02:
				_start_at = maxf(0.0, (i - 2) / r)
				break
		_start_out = float(st.length) * 0.8
		for i in range(int(_start_at * r) + 2, f.size() - 1):
			if (float(f[i + 1]) - float(f[i])) * r >= walk * 0.9:
				_start_out = (i + 1) / r
				break
	var sp: Dictionary = moves.get("Stop", {})
	if not sp.is_empty():
		var f: Array = sp.fwd
		var r := float(sp.rate)
		var last := float(f[-1])
		_stop_at = 0.0
		for i in f.size():
			if last - float(f[i]) <= STOP_LAST / maxf(size, 1e-4):
				_stop_at = i / r
				break


## (m) how much of Stop it plays: its last steps, this far from where it ends
const STOP_LAST := 0.55


## Put somewhere else (not walked there): stood, as it was facing.
func reset(stand: String) -> void:
	state = "idle"
	_slow = 0.0
	_accel = 0.0
	_was_speed = 0.0
	_rest = 0.0
	_play(stand, 0.0)


## How fast (m/s) clip `c` goes over the ground at its own pace: its feet's way over its length.
func _pace(c: String) -> float:
	var m: Dictionary = moves.get(c, {})
	if m.is_empty():
		return 1.0
	# (measured off its toes as it was made: how fast the planted one goes back)
	if float(m.get("planted", 0.0)) > 0.01:
		return float(m.planted) * size
	var way := float(m.get("trip", 0.0))
	if not bool(m.get("loop", false)):
		way = Vector2(float(m.fwd[-1]), float(m.side[-1])).length()
	return way * float(m.get("stride", 1.0)) * size / maxf(float(m.length), 0.01)


## Sample `key` of clip `c` at time `t` (s).
func _at(c: String, key: String, t: float) -> float:
	var m: Dictionary = moves[c]
	var a: Array = m[key]
	var x := t * float(m.rate)
	if bool(m.get("loop", false)):
		x = fposmod(x, float(a.size()))
		var i := int(x)
		return lerpf(float(a[i]), float(a[(i + 1) % a.size()]), x - i)
	x = clampf(x, 0.0, a.size() - 1.0)
	var j := mini(int(x), a.size() - 2)
	return lerpf(float(a[j]), float(a[j + 1]), x - j)


## Where in clip `to` (s, within lo..hi) its step is as it is now in the clip playing: its left
## foot's lead the same, and going the same way.
func _same_step(to: String, lo := 0.0, hi := -1.0) -> float:
	if clip == "" or not moves.has(clip) or not moves.has(to):
		return lo
	var now := anim.current_animation_position
	var lead := _at(clip, "feet", now)
	var going := signf(_at(clip, "feet", now + 0.05) - lead)
	var m: Dictionary = moves[to]
	var end := float(m.length) if hi < 0.0 else hi
	var best := lo
	var score := INF
	var t := lo
	while t <= end:
		var v := _at(to, "feet", t)
		var s := absf(v - lead) + (0.0 if signf(_at(to, "feet", t + 0.05) - v) == going else 0.2)
		if s < score:
			score = s
			best = t
		t += 1.0 / 30.0
	return best


func _play(c: String, blend: float, at := -1.0) -> void:
	if not anim.has_animation(c):
		return
	if c == clip and at < 0.0:
		return
	anim.play(c, blend)
	if at >= 0.0:
		anim.seek(at, true)
	clip = c
	log.append([snappedf(_t, 0.01), state, c])
	if log.size() > 64:
		log.pop_front()


func _done() -> bool:
	return not anim.is_playing() or anim.current_animation != clip \
		or anim.current_animation_position >= anim.get_animation(clip).length - 0.12


## A turn begun: clip `c`, by `by` rad (its way: left is up).
func _turn(c: String, by: float) -> void:
	state = "turn"
	_from = yaw
	_by = by
	_play(c, 0.25, _same_step(c, 0.0, 0.35) if moves.get(c, {}).get("kind", "") == "turn" and c != "Turn_180" else 0.0)


## The loop it goes on in (walking): its prowl when it's looking for someone.
func _walk_clip(gait: String) -> String:
	return "Prowl" if gait == "prowl" and anim.has_animation("Prowl") else "Walk"


## Picks a turn for being `err` rad off its way; false: under a veer, it steers.
func _pick_turn(err: float) -> bool:
	var e := rad_to_deg(err)
	if absf(e) < VEER or _rest > 0.0:
		return false
	# (right round on the spot only nearly stood; on the move, a quarter turn walked round further)
	if absf(e) >= ROUND and _speed < PIVOT_BELOW and anim.has_animation("Turn_180") and anim.has_animation("Turn_180_L"):
		_turn("Turn_180_L" if e > 0.0 else "Turn_180", err)
	elif absf(e) >= QUARTER:
		_turn("Turn_L" if e > 0.0 else "Turn_R", err)
	else:
		_turn("Veer_L" if e > 0.0 else "Veer_R", err)
	return true


## One frame: `speed` (m/s) and `heading` (rad) it's moving at, `gait` ("walk", "prowl", "run",
## "fly", or "act:<clip>" - caught someone, eating), `face` the way to face stood (or NAN), and the
## clip it stands in.
var _speed := 0.0
var _acting := ""
## (rad/s) how fast its way's coming round, smoothed
var _turning := 0.0
var _last_heading := NAN


func step(delta: float, speed: float, heading: float, gait: String, face: float, stand: String) -> void:
	_t += delta
	_speed = speed
	if not is_nan(_last_heading) and delta > 0.0:
		_turning = lerpf(_turning, absf(wrapf(heading - _last_heading, -PI, PI)) / delta, 1.0 - exp(-delta * 4.0))
	_last_heading = heading
	_rest = maxf(_rest - delta, 0.0)
	var err := wrapf(heading - yaw, -PI, PI)
	var rate := 1.0
	_slow = _slow + delta if speed < STOP_BELOW else 0.0
	if delta > 0.0:
		_accel = lerpf(_accel, (speed - _was_speed) / delta, 1.0 - exp(-delta * 12.0))
	_was_speed = speed
	if gait.begins_with("act:") or gait == "fly":
		var c := gait.substr(4) if gait.begins_with("act:") else stand
		if state != "act" or (_acting != c):
			state = "act"
			_acting = c
			_play(c, 0.25 if c != "Grab" else 0.12)
		elif not bool(moves.get(c, {}).get("loop", true)) and clip == c and _done():
			# (user request: caught - one swipe as it takes you, then it holds you, its lantern up
			# over you)
			_play("Idle_Lamp" if anim.has_animation("Idle_Lamp") else stand, BLEND_STAND)
		if speed > STOP_BELOW:
			yaw = lerp_angle(yaw, heading, 1.0 - exp(-delta * STEER_RUN))
		anim.speed_scale = 1.0
		return
	if state == "act":
		state = "idle"
		_acting = ""
		_play(stand, BLEND_STAND)
	match state:
		"idle":
			if speed > MOVE_ON:
				# (after someone it doesn't stop to turn: it wheels round as it breaks into a run)
				if gait == "run":
					state = "run"
					_play("Chase", BLEND)
				elif absf(rad_to_deg(err)) >= QUARTER:
					_pick_turn(err)
				else:
					state = "start"
					_play("Start", BLEND, _start_at)
			else:
				if clip != stand:
					_play(stand, BLEND_STAND)
				if gait == "run" and not is_nan(face):
					# (after someone, stood a moment: it wheels to them, no stepping round)
					yaw = lerp_angle(yaw, face, 1.0 - exp(-delta * STEER_RUN))
				elif not is_nan(face) and _rest <= 0.0:
					var fe := wrapf(face - yaw, -PI, PI)
					var round_clip := "Turn_180_L" if fe > 0.0 else "Turn_180"
					if absf(rad_to_deg(fe)) > STOOD_TURN and anim.has_animation(round_clip):
						state = "pivot"
						_from = yaw
						_by = fe
						_play(round_clip, BLEND)
		"start":
			yaw = lerp_angle(yaw, heading, 1.0 - exp(-delta * STEER_WALK * 1.5))
			# (its pace as it gets going - the clip's own, there, against its own)
			var here := anim.current_animation_position
			var going := (_at("Start", "fwd", here + 0.2) - _at("Start", "fwd", here - 0.2)) / 0.4 \
				* float(moves.Start.stride) * size
			rate = clampf(speed / going, 0.7, 1.4) if going > 0.15 else 1.0
			if _slow > STOP_WAIT:
				state = "idle"
				_play(stand, BLEND_STAND)
			elif gait == "run" and speed > RUN_ABOVE:
				state = "run"
				_play("Chase", BLEND, _same_step("Chase"))
			elif anim.current_animation_position >= _start_out or _done():
				state = "walk"
				_play(_walk_clip(gait), BLEND, _same_step(_walk_clip(gait)))
		"walk":
			var w := _walk_clip(gait)
			if w != clip:
				_play(w, BLEND, _same_step(w))
			rate = clampf(speed / maxf(_pace(w), 0.01), RATE.x, RATE.y)
			if _slow > STOP_WAIT:
				state = "stop"
				_play("Stop", BLEND, _same_step("Stop", _stop_at, _stop_at + 0.6))
			elif gait == "run" and speed > RUN_ABOVE:
				state = "run"
				_play("Chase", BLEND, _same_step("Chase"))
			elif not _pick_turn(err):
				yaw = lerp_angle(yaw, heading, 1.0 - exp(-delta * STEER_WALK))
		"turn", "pivot":
			if gait == "run" and speed > MOVE_ON:
				state = "run"
				_play("Chase", BLEND)
				anim.speed_scale = 1.0
				return
			var m: Dictionary = moves.get(clip, {})
			var total := float(m.turn[-1]) if not m.is_empty() else 1.0
			var part := clampf(_at(clip, "turn", anim.current_animation_position) / total, -0.1, 1.05) \
				if absf(total) > 0.5 else 1.0
			# (its way still changing as it turns: the turn follows, till it's half done)
			if state == "turn" and part < 0.5 and speed > STOP_BELOW:
				var now := wrapf(heading - _from, -PI, PI)
				if signf(now) == signf(_by):
					_by = now
			yaw = _from + _by * part
			# (its feet turning it as fast as it's turning: the clip's own turn pace against how fast
			# its way's coming round)
			if state == "turn" and speed > 0.1 and absf(total) > 0.5:
				var clip_turn := deg_to_rad(absf(total)) / maxf(float(m.length), 0.1)
				rate = clampf(_turning / clip_turn, 0.75, 1.35) if _turning > 0.05 else 1.0
			if _done():
				yaw = _from + _by
				_rest = TURN_REST
				if state == "pivot" or speed < STOP_BELOW:
					state = "idle"
					_play(stand, BLEND_STAND)
				elif gait == "run" and speed > RUN_ABOVE:
					state = "run"
					_play("Chase", BLEND, _same_step("Chase"))
				else:
					state = "walk"
					_play(_walk_clip(gait), BLEND, _same_step(_walk_clip(gait)))
		"stop":
			if speed > MOVE_ON:
				state = "walk"
				_play(_walk_clip(gait), BLEND, _same_step(_walk_clip(gait)))
			elif _done():
				state = "idle"
				_play(stand, BLEND_STAND)
		"run":
			rate = clampf(speed / maxf(_pace("Chase"), 0.01), 0.75, 1.35)
			yaw = lerp_angle(yaw, heading, 1.0 - exp(-delta * STEER_RUN))
			# (pulling up short - where it'd be stood in a moment, slowing as it is - or nearly stood)
			var soon := speed + minf(_accel, 0.0) * HALT_LOOK
			if speed < RUN_BELOW + 0.3 and (soon < MOVE_ON or speed < RUN_HALT):
				state = "halt"
				_play("Run_Stop", 0.2, 0.0)
			elif speed < RUN_BELOW:
				# (no longer after anyone, it runs on till it's slowed to a walk)
				state = "walk"
				_play(_walk_clip(gait), BLEND, _same_step(_walk_clip(gait)))
		"halt":
			if _done():
				if speed > MOVE_ON:
					state = "walk"
					_play(_walk_clip(gait), BLEND, _same_step(_walk_clip(gait)))
				else:
					state = "idle"
					_play(stand, BLEND_STAND)
	anim.speed_scale = rate
