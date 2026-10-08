class_name FishFight
extends RefCounted

## One hooked fish's fight (user decision: the fishing difficulty plan,
## phases 2-4). Player owns one while REELING and feeds it input each
## physics frame; everything here is plain data so a fight can be
## simulated headless for balancing.
##
## The rules, by difficulty (FishData.DIFFICULTY):
## - Stamina: holding the reel wears the fish down (progress 0 -> 1 lands
##   it); tougher fish take longer. Holding also builds tension, which
##   eases off when you let go. Tension 1 snaps the line.
## - Runs: every few seconds the fish runs. Straight out: give line (let
##   go) - holding costs progress and spikes tension. Sideways: pull the
##   rod the other way (drag the cast button / aim stick / walk that way);
##   left unanswered it costs progress and tension.
## - Jumps: the fish leaps; while it's in the air, let go - holding throws
##   a huge spike of tension (it shakes the hook on a tight line).
## - Master fish go berserk at half stamina: a long run, then they pull
##   harder and run more often. User request: berserk, reeling sends the
##   line tension climbing fast (ENRAGE_REEL_TENSION) - ease off in time.
## - User request (as in most fishing games): when the fish dashes sideways
##   there's a moment to flick the right stick the other way. Done in time
##   (SWIPE_WINDOW), the fish loses SWIPE_DAMAGE of its stamina and the
##   dash is broken; missed, the dash drags on and costs as before.
## - "cover" habit: it bolts for the bank; hold hard to haul it back before
##   it reaches the rocks and frays the line.
## - User request: a sweet spot on the tension gauge (diff.sweet wide,
##   around SWEET_CENTER) - reeling while the tension sits in it gains line
##   SWEET_REEL_MULT times as fast, so it pays to ease on and off rather
##   than just hold.
## - User request: a perfect strike (Player, right as the float goes under)
##   starts the fight with the fish PERFECT_HOOK_STAMINA down and the line
##   slack.
## - User request: the reel is cranked - the right stick turned round and
##   round (Player.crank, 0..1): the faster it turns, the faster line comes
##   in, the fish wears down and the tension builds; CRANK_NORMAL reels at
##   the pace holding the button used to (Space on a keyboard).
## - User request: the line out - `distance` (m). Left un-reeled the fish
##   swims off (swim_out m/s, faster on a run; rare, big and wild fish pull
##   away faster - Player sets it); cranking brings it back (REEL_IN). Out
##   past DANGER of the line (line_max) it may snap any moment - more
##   likely the further out (DANGER_SNAP) - and a leap out there snaps it
##   outright; all of it out and it's gone ("line_out").
## - User feedback (fights over too fast): worn out (progress 1) the fish
##   isn't landed yet - it's spent: no more runs or leaps, it drifts out
##   slowly and has to be reeled in to the bank (LAND_DISTANCE). Left
##   un-reeled for RECOVER_AFTER it gets its breath back (RECOVER_TO) and
##   fights on.
## - User request: the strike's first moments (open()): the fish puts its
##   own tension on the line - the harder the catch (its difficulty, rarity,
##   size, temper: `heft`), the higher it starts, or it starts low and next
##   moment surges hard, the way a big fish takes a bait. Hold the stick
##   (`hold`, no turning) and the line rides it, so you can read what's on;
##   let go and the line goes slack (slack too long, it throws the hook);
##   crank straight away and the crank's strain goes on top (a surge snaps
##   it). Then the fight proper.
## - User request: struck, the fish is at its liveliest and swims about the
##   water - out, along the bank, in toward the angler - in bursts, each
##   starting with a jerk on the line; the distance and the tension go
##   with it. It tires as the fight goes (vigor, from 1 down to
##   VIGOR_FLOOR with its stamina); a hard one may rally late on (the
##   difficulty's "rally" chance, at RALLY_AT of the fight). The bigger,
##   harder and rarer (heft, open()), the faster and further it goes and
##   the harder it jerks. Player turns the line by `lateral` (m/s across
##   it) and calls turn_back() when the bank's in the way.
## - User request: a leap snaps the line only out far - a light touch on
##   the crank while it's up (under JUMP_GRACE) is let off, and close in
##   the strain of reeling into it is a share (JUMP_NEAR) of what it is
##   out toward the danger.
## - User request: the line shown is the line out (線長, line_out()) - from
##   the rod's tip out to the fish and down to it, so it starts as long as
##   the cast and grows as the fish goes deep: `depth` (m) - it heads down
##   on its runs, its bursts out and its dashes for cover (the harder,
##   bigger and rarer, the deeper it goes - DEPTH_MAX by heft), comes up as
##   it's reeled and as it tires, and to the top on a leap. The danger and
##   the line running out go by the line out too.

const RUN_TENSION_MULT := 1.8
## Giving line to a run: the drag holds tension nearly level.
const RUN_SLACK_TENSION := 0.15
const RUN_PROGRESS_PENALTY := 0.2
const SIDE_COUNTER_THRESHOLD := 0.35
const JUMP_TIME := 0.7
const JUMP_HELD_TENSION := 2.4
const JUMP_GRACE := 0.18
const JUMP_NEAR := 0.25
const JUMP_FAR_FROM := 0.35
const JUMP_COOLDOWN := 2.5
const JUMPER_JUMP_MULT := 1.8
const ENRAGE_AT := 0.5
const ENRAGE_RUN_TIME := 1.4
const ENRAGE_PULL := 1.15
## User request: berserk, the line tightens fast while you reel - ease off
## (let go) and it drops again. On top of ENRAGE_PULL.
const ENRAGE_REEL_TENSION := 1.7
const ENRAGE_INTERVAL := 0.8
const DIVE_INTERVAL := Vector2(4.0, 7.0)
const DIVE_SPEED := 0.45
const DIVE_HAUL := 0.6
const DIVE_TENSION := 1.5
const SWIPE_WINDOW := 1.0
const SWIPE_DAMAGE := 0.12
const SWIPE_THRESHOLD := 0.6
## Below this stamina the fish reads as tired.
const TIRED_AT := 0.25
const SWEET_CENTER := 0.5
const SWEET_REEL_MULT := 1.6
const PERFECT_HOOK_STAMINA := 0.15
const PERFECT_HOOK_TENSION := 0.05
## The crank (0..1) at which the reel goes as holding the button used to:
## gains and the tension's rise go as crank / CRANK_NORMAL. Below HELD_AT
## it isn't reeling at all (the line's held).
const CRANK_NORMAL := 0.7
const HELD_AT := 0.06
## The line: m reeled in a second at CRANK_NORMAL; the fish swims out
## RUN_OUT_MULT times as fast on a straight run (the drag slipping - the
## crank brings nothing in), SIDE_OUT_MULT on a sideways one not held,
## and only TIRED_OUT of it worn out; never nearer than MIN_DISTANCE.
const REEL_IN := 2.6
const RUN_OUT_MULT := 2.0
const SIDE_OUT_MULT := 1.4
const TIRED_OUT := 0.35
const MIN_DISTANCE := 2.0
## User feedback (the big wild fish couldn't be brought in): while the reel
## turns the fish swims out against the drag, only this share as fast (a
## straight run aside - the drag slips) - line's lost resting the tension,
## won back cranking.
const HELD_OUT := 0.45
## Past this share of the line it's in danger: the chance a second that it
## snaps rises to DANGER_SNAP at the end.
const DANGER := 0.75
const DANGER_SNAP := 0.9
## Spent: landed this near; the tension builds this share as fast; left
## this long un-reeled it recovers to this much progress.
const LAND_DISTANCE := 3.0
## The line out (see above): the fish's depth at the strike, the deepest it
## goes (light .. heaviest fish), how fast it goes down (m/s, times its
## vigor) and is brought up (m/s at CRANK_NORMAL), the depth it rests at
## (a share of its deepest), how high the rod's tip is over the water.
const DEPTH_HOOKED := 1.0
const DEPTH_MAX := Vector2(2.0, 7.0)
const DEPTH_DOWN := 1.4
const DEPTH_UP := 0.8
const DEPTH_REST := 0.4
const DEPTH_SPENT := 0.3
const TIP_HEIGHT := 1.2
const SPENT_TENSION := 0.35
const RECOVER_AFTER := 2.5
const RECOVER_TO := 0.82
## The opening (see open()): how long it lasts (light .. heavy fish), the
## tension it starts at (steady), a surge's start, peak and when it comes,
## how fast it climbs, the wobble; cranking's strain on top (per second,
## at CRANK_NORMAL) and how it eases; slack: the tension, and how long of
## it throws the hook.
const OPEN_TIME := Vector2(1.2, 2.4)
const OPEN_STEADY := Vector2(0.12, 0.62)
const OPEN_SURGE_FROM := Vector2(0.1, 0.25)
const OPEN_SURGE_PEAK := Vector2(0.62, 0.93)
const OPEN_SURGE_AT := Vector2(0.4, 0.9)
const OPEN_SURGE_RISE := 0.35
const OPEN_WOBBLE := Vector2(0.02, 0.07)
const OPEN_FOLLOW := 7.0
const OPEN_CRANK_TENSION := 0.9
const OPEN_CRANK_EASE := 0.6
const OPEN_SLACK_TENSION := 0.03
const OPEN_SLACK_LOSE := 0.9
## On its surge the fish takes line this much faster.
const OPEN_SURGE_OUT := 1.8
## The fish swimming (see above): its vigor at the end of its strength; a
## burst's length and the rest between (s, the rest shorter the livelier),
## its speed and its jerk on the line (light .. heavy fish), the tension
## it adds swimming off (per s, x tension_rise, at the top speed), how
## much of a burst toward the line the angler can take in; a sideways
## run's speed (m/s; held against, RUN_HELD_SIDE of it); the rally.
const VIGOR_FLOOR := 0.2
const BURST_TIME := Vector2(0.6, 1.5)
const BURST_GAP := Vector2(0.4, 1.6)
const BURST_SPEED := Vector2(0.9, 3.0)
const BURST_JERK := Vector2(0.05, 0.2)
const BURST_PULL := 0.5
## How often a burst heads out, and along the bank (the rest come in); a
## burst out takes line this share as fast (the drag).
const BURST_OUT := 0.3
const BURST_ALONG := 0.45
const BURST_OUT_SPEED := 0.6
const SIDE_RUN_SPEED := 2.2
const RUN_HELD_SIDE := 0.35
const RALLY_AT := 0.78
const RALLY_TIME := 5.0
const RALLY_VIGOR := 0.85
const RALLY_STAMINA := 0.08
## A burst this fast (m/s) shows on the panel.
const SWIM_SHOWN := 0.8

var diff: Dictionary
var difficulty_key: String
var habit: String
var reel_speed: float
var tension_rise: float
## The line's tension builds this much as fast (user request, round 7: the
## increase potion eases it; set by Player each frame).
var strain := 1.0
var tension_fall: float
## The rod (Profile.ROD_TIERS): its line strength divides every tension
## gain (the tension cap), and `jump` scales the strain of holding a leap.
var line_strength := 1.0
var jump_strain := 1.0

var progress := 0.0
var tension := 0.15
var enraged := false
## Worn out - being reeled in to the bank (see above).
var spent := false
var _rest := 0.0
## The opening (open()): time left, how long it's been, the fish's
## tension curve ([start, peak, surge at] - start == peak: steady), the
## crank's strain on top, slack so far. `hold`: the stick held (Player
## sets it each frame).
var opening_left := 0.0
var open_age := 0.0
var open_curve := Vector3.ZERO
var heft := 0.0
var hold := false
var _open_extra := 0.0
var slack := 0.0
## Swimming (see above): on once struck (open()); how lively it is; the
## burst it's on - its heading (rad from straight out: 0 out, +-PI/2 along
## the bank, PI in), speed (m/s) and time left; the rest till the next;
## this frame's swim across the line (m/s, + = line_dir.orthogonal()); a
## jerk's share of the opening's tension, easing off; the rally.
var lively := false
var vigor := 1.0
var heading := 0.0
var burst_speed := 0.0
var burst_left := 0.0
var _burst_gap := 0.0
var lateral := 0.0
var _jerk := 0.0
var rallied := false
var rally_left := 0.0
var _run_sign := 0.0
var _line_dir := Vector2.UP
var result := ""  # "", "landed", "line_break", "shook_off", "cover", "line_out"
## The line out (m), how much there is (m), and how fast this fish swims
## off with it (m/s) - see REEL_IN.
var distance := 12.0
var depth := DEPTH_HOOKED
var line_max := 40.0
var swim_out := 1.0
## The crank this frame (0..1).
var crank := 0.0
## Why the line went (for the message): "far" (out in the danger), "leap"
## (a leap out there), "" (the tension).
var snap_why := ""

## Current run: time left, and its sideways direction (ZERO = straight out).
var run_left := 0.0
var run_side := Vector2.ZERO
var jump_left := 0.0
var dive := 0.0
var dive_active := false
## Time left to flick the stick against a sideways dash (0 = none open).
var swipe_left := 0.0
## The flick has to be a fresh one: the stick must not already be held
## that way when the dash starts (or it has to come back first).
var _swipe_armed := false
## Struck perfectly (for the panel's call-out).
var perfect := false
## Seconds since the fish was hooked.
var age := 0.0

var _run_timer := 0.0
var _jump_cooldown := 0.0
var _dive_timer := 0.0


func _init(difficulty: String, fish_habit: String, tier: Dictionary, reel_power: float, rod: Dictionary = {}) -> void:
	difficulty_key = difficulty
	diff = FishData.DIFFICULTY[difficulty]
	habit = fish_habit
	reel_speed = tier.reel_speed * reel_power / diff.stamina
	line_strength = rod.get("strength", 1.0)
	jump_strain = rod.get("jump", 1.0)
	tension_rise = tier.tension_rise / line_strength
	tension_fall = tier.tension_fall
	_run_timer = randf_range(diff.run_interval.x, diff.run_interval.y)
	_jump_cooldown = JUMP_COOLDOWN
	_dive_timer = randf_range(DIVE_INTERVAL.x, DIVE_INTERVAL.y)


func label() -> String:
	return diff.label


## The strike's first moments (see above) for a fish this hard to land
## (0 easy .. 1 the hardest).
func open(fish_heft: float) -> void:
	heft = clampf(fish_heft, 0.0, 1.0)
	opening_left = lerpf(OPEN_TIME.x, OPEN_TIME.y, heft)
	open_age = 0.0
	_open_extra = 0.0
	slack = 0.0
	lively = true
	_burst_gap = randf_range(0.05, 0.3)
	if randf() < clampf((heft - 0.3) * 1.5, 0.0, 0.8):
		open_curve = Vector3(randf_range(OPEN_SURGE_FROM.x, OPEN_SURGE_FROM.y),
			lerpf(OPEN_SURGE_PEAK.x, OPEN_SURGE_PEAK.y, heft) + randf_range(-0.03, 0.03),
			randf_range(OPEN_SURGE_AT.x, OPEN_SURGE_AT.y))
	else:
		var start := clampf(lerpf(OPEN_STEADY.x, OPEN_STEADY.y, heft) + randf_range(-0.05, 0.05), 0.05, 0.8)
		open_curve = Vector3(start, start, 0.0)
	tension = open_curve.x


## Does it surge (start low, then pull hard)?
func surges() -> bool:
	return open_curve.y > open_curve.x + 0.1


## Surging now (in the opening, past the surge's start).
func surging() -> bool:
	return opening_left > 0.0 and surges() and open_age >= open_curve.z


## The fish's own tension on the line at this point of the opening.
func open_tension() -> float:
	var t := open_curve.x
	if surges() and open_age >= open_curve.z:
		var k := clampf((open_age - open_curve.z) / OPEN_SURGE_RISE, 0.0, 1.0)
		t = lerpf(open_curve.x, open_curve.y, k * k * (3.0 - 2.0 * k))
	var wobble := lerpf(OPEN_WOBBLE.x, OPEN_WOBBLE.y, heft)
	return t + wobble * (sin(open_age * 9.0) * 0.6 + sin(open_age * 23.0 + 1.3) * 0.4)


## One frame. reel: the crank (0..1; a bool: held, at CRANK_NORMAL).
## counter: the direction the rod is being pulled (unit or ZERO).
## line_dir: from the angler toward the fish. reel_mult: extra reel-speed
## factor (walking while reeling). Returns the events this frame started:
## "run", "side_run", "jump", "dive", "enrage", "dive_saved", "swipe_hit",
## "swipe_miss", "spent", "recover", "opened".
func update(delta: float, reel: Variant, counter: Vector2, line_dir: Vector2, reel_mult: float = 1.0) -> Array:
	var events := []
	if result != "":
		return events
	if reel is bool:
		reel = CRANK_NORMAL if reel else 0.0
	crank = clampf(float(reel), 0.0, 1.0)
	var held := crank >= HELD_AT
	# How hard it's cranked, against holding the button the old way.
	var k := crank / CRANK_NORMAL
	var pull: float = diff.pull * (ENRAGE_PULL if enraged else 1.0)
	age += delta
	_jump_cooldown -= delta
	# The line: out with the fish, in with the crank (see below).
	var out_mult := 1.0
	var reel_in := k * reel_mult
	# Swimming about: how lively, and this frame's swim (see _swim()).
	lateral = 0.0
	if line_dir != Vector2.ZERO:
		_line_dir = line_dir
	_vigor(delta, events)
	var radial := 0.0
	# (the line's out-take already eased for the rod held against it)
	var resisted := false

	if opening_left > 0.0:
		opening_left -= delta
		open_age += delta
		var want := OPEN_SLACK_TENSION
		if held:
			# Cranked straight away: its strain on top of the fish's pull.
			_open_extra += OPEN_CRANK_TENSION * k * strain / line_strength * delta
			progress += reel_speed * 0.5 * k * delta
			slack = maxf(slack - delta, 0.0)
		else:
			_open_extra = maxf(_open_extra - OPEN_CRANK_EASE * delta, 0.0)
		radial = _swim(delta, held)
		_jerk = maxf(_jerk - delta * 1.5, 0.0)
		if held or hold:
			want = minf(open_tension() + _jerk, 0.96) + _open_extra
			slack = maxf(slack - delta * 0.5, 0.0)
		else:
			slack += delta
			if slack >= OPEN_SLACK_LOSE:
				snap_why = "slack"
				result = "shook_off"
		tension = want if want > tension else lerpf(tension, want, 1.0 - exp(-OPEN_FOLLOW * delta))
		# Held up against it, the rod takes some of its pull (as the reel
		# does); on its surge the drag slips.
		out_mult = (OPEN_SURGE_OUT if surging() else 1.0) * (HELD_OUT if held or hold else 1.0)
		resisted = true
		if surging():
			reel_in = 0.0
		if opening_left <= 0.0:
			opening_left = 0.0
			_open_extra = 0.0
			events.append("opened")
	elif spent:
		if held:
			_rest = 0.0
			tension += tension_rise * strain * pull * SPENT_TENSION * k * delta
		else:
			_rest += delta
			tension -= tension_fall * delta
			if _rest >= RECOVER_AFTER:
				spent = false
				_rest = 0.0
				progress = RECOVER_TO
				_run_timer = randf_range(diff.run_interval.x, diff.run_interval.y)
				events.append("recover")
	elif jump_left > 0.0:
		jump_left -= delta
		reel_in *= 0.5
		# Reeling into a leap: let off a light touch, and close in only a
		# share of the strain (see above).
		var hard := smoothstep(JUMP_GRACE, 1.0, crank) if held else 0.0
		var far := lerpf(JUMP_NEAR, 1.0, smoothstep(JUMP_FAR_FROM, DANGER, line_share()))
		if hard > 0.0:
			tension += JUMP_HELD_TENSION * hard * far * jump_strain / line_strength * delta
		else:
			tension -= tension_fall * delta
	elif dive_active:
		out_mult = 0.0
		if held:
			dive -= DIVE_HAUL * k * delta
			progress += reel_speed * 0.3 * k * delta
			tension += tension_rise * strain * pull * DIVE_TENSION * k * delta
		else:
			dive += DIVE_SPEED * delta
			tension -= tension_fall * delta
		if dive <= 0.0:
			dive_active = false
			dive = 0.0
			_dive_timer = randf_range(DIVE_INTERVAL.x, DIVE_INTERVAL.y)
			events.append("dive_saved")
		elif dive >= 1.0:
			result = "cover"
	elif run_left > 0.0:
		run_left -= delta
		if run_side == Vector2.ZERO:
			# Out it goes: the drag slips, the crank brings nothing in.
			out_mult = RUN_OUT_MULT
			reel_in = 0.0
			if held:
				progress -= RUN_PROGRESS_PENALTY * delta
				tension += tension_rise * strain * RUN_TENSION_MULT * pull * maxf(k, 1.0) * delta
			else:
				tension += tension_rise * strain * RUN_SLACK_TENSION * pull * delta
		elif swipe_left > 0.0 and _swipe_check(delta, counter, events):
			pass
		elif counter.length() > 0.3 and counter.normalized().dot(-run_side) > SIDE_COUNTER_THRESHOLD:
			# Rod pulled against the run: it's held, and you can keep reeling.
			lateral = _run_sign * SIDE_RUN_SPEED * maxf(vigor, 0.4) * RUN_HELD_SIDE
			reel_in *= 0.5
			if held:
				progress += reel_speed * 0.5 * k * delta
				tension += tension_rise * strain * 0.6 * pull * k * delta
			else:
				tension -= tension_fall * 0.5 * delta
		else:
			lateral = _run_sign * SIDE_RUN_SPEED * maxf(vigor, 0.4)
			out_mult = SIDE_OUT_MULT
			reel_in *= 0.5
			progress -= RUN_PROGRESS_PENALTY * delta
			tension += tension_rise * strain * RUN_TENSION_MULT * pull * (maxf(k, 1.0) if held else 0.45) * delta
		if run_left <= 0.0:
			swipe_left = 0.0
	else:
		radial = _swim(delta, held)
		if held:
			progress += reel_speed * reel_mult * k * (SWEET_REEL_MULT if in_sweet() else 1.0) * delta
			tension += tension_rise * strain * pull * k * (ENRAGE_REEL_TENSION if enraged else 1.0) * delta
		else:
			tension -= tension_fall * delta
		events.append_array(_schedule(delta, line_dir))
		if events.has("jump") and danger() > 0.0:
			# A leap that far out: the line can't take it.
			snap_why = "leap"
			result = "line_break"

	if diff.phases > 1 and not enraged and progress >= ENRAGE_AT:
		enraged = true
		run_left = ENRAGE_RUN_TIME
		run_side = Vector2.ZERO
		swipe_left = 0.0
		jump_left = 0.0
		events.append("enrage")

	tension = clampf(tension, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	if held and out_mult != RUN_OUT_MULT and not resisted:
		out_mult *= HELD_OUT
	_depth(delta, k if held else 0.0, radial)
	_line(delta, out_mult, reel_in if held else 0.0, pull, radial)
	if result == "":
		if tension >= 1.0:
			result = "shook_off" if jump_left > 0.0 else "line_break"
			if opening_left > 0.0 and _open_extra > 0.05:
				# Cranked into the fish's first pull.
				snap_why = "rush"
		elif spent and distance <= LAND_DISTANCE:
			result = "landed"
		elif progress >= 1.0 and not spent:
			spent = true
			_rest = 0.0
			run_left = 0.0
			jump_left = 0.0
			swipe_left = 0.0
			dive_active = false
			dive = 0.0
			burst_left = 0.0
			events.append("spent")
	return events


## The line out: the fish takes it (tired, less), the crank brings it in;
## all out, it's gone; out in the danger it may snap.
func _line(delta: float, out_mult: float, reel_in: float, pull: float, radial := 0.0) -> void:
	if result != "":
		return
	var out: float = swim_out * out_mult * pull / diff.pull * lerpf(TIRED_OUT, 1.0, stamina())
	distance = clampf(distance + (out - REEL_IN * reel_in + radial) * delta, MIN_DISTANCE, line_max)
	if line_out() >= line_max:
		snap_why = "far"
		result = "line_out"
	elif danger() > 0.0 and randf() < DANGER_SNAP * danger() * danger() * delta:
		snap_why = "far"
		result = "line_break"


## How far into the danger the line is (0 not yet .. 1 all out).
func danger() -> float:
	return clampf((line_share() - DANGER) / (1.0 - DANGER), 0.0, 1.0)


## The line out as a share of all there is.
func line_share() -> float:
	return minf(line_out() / maxf(line_max, 0.01), 1.0)


## The line out (m, see above): from the rod's tip out to the fish and down.
func line_out() -> float:
	return Vector2(distance, depth + TIP_HEIGHT).length()


## The deepest this fish goes.
func depth_max() -> float:
	return lerpf(DEPTH_MAX.x, DEPTH_MAX.y, heft)


## Down on its runs, its bursts out and its dashes for cover; up to the
## top on a leap, up as it's reeled (`k`, the crank against CRANK_NORMAL)
## and once spent; otherwise it settles to where it rests.
func _depth(delta: float, k: float, radial: float) -> void:
	var deepest := depth_max()
	var down := DEPTH_DOWN * maxf(vigor, 0.4)
	if jump_left > 0.0:
		depth = move_toward(depth, 0.0, 6.0 * delta)
	elif spent:
		depth = move_toward(depth, DEPTH_SPENT, DEPTH_UP * 1.5 * delta)
	elif dive_active or (run_left > 0.0 and run_side == Vector2.ZERO) or radial > 0.0 \
			or (opening_left > 0.0 and surging()):
		depth = move_toward(depth, deepest, down * delta)
	elif run_left > 0.0:
		depth = move_toward(depth, deepest * 0.7, down * 0.6 * delta)
	elif k > 0.0:
		depth = move_toward(depth, 0.5, DEPTH_UP * k * delta)
	else:
		depth = move_toward(depth, deepest * DEPTH_REST, 0.3 * delta)


## How lively it is now (see above) - and its rally, when it comes.
func _vigor(delta: float, events: Array) -> void:
	vigor = lerpf(VIGOR_FLOOR, 1.0, pow(stamina(), 0.8))
	if lively and not rallied and not spent and progress >= RALLY_AT:
		rallied = true
		if randf() < float(diff.get("rally", 0.0)):
			rally_left = RALLY_TIME
			progress = maxf(progress - RALLY_STAMINA, 0.0)
			_burst_gap = 0.0
			events.append("rally")
	if rally_left > 0.0:
		rally_left -= delta
		vigor = maxf(vigor, RALLY_VIGOR)


## Swimming about (see above): bursts this way and that, a jerk on the
## line as each starts. Returns how fast it's taking line (m/s; less with
## the reel turning against it, negative coming in); sets `lateral`.
func _swim(delta: float, held: bool) -> float:
	if not lively:
		return 0.0
	if burst_left > 0.0:
		burst_left -= delta
	else:
		_burst_gap -= delta
		if _burst_gap <= 0.0:
			_start_burst()
	if burst_left <= 0.0:
		return 0.0
	var radial := cos(heading) * burst_speed * (BURST_OUT_SPEED if cos(heading) > 0.0 else 1.0)
	var across := sin(heading) * burst_speed
	lateral += across
	var effort := burst_speed / BURST_SPEED.y
	if radial > 0.0:
		# Off it goes: the line tightens (more with the reel against it).
		tension += tension_rise * strain * BURST_PULL * effort * cos(heading) * (1.0 if held else 0.4) * delta
		radial *= HELD_OUT if held else 1.0
	else:
		# Toward the angler: the line goes slack.
		tension -= tension_fall * 0.4 * -cos(heading) * delta
	tension += tension_rise * strain * BURST_PULL * 0.4 * effort * absf(sin(heading)) * (1.0 if held else 0.3) * delta
	return radial


func _start_burst() -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	var r := randf()
	if r < BURST_OUT:
		heading = randf_range(-0.5, 0.5)
	elif r < BURST_OUT + BURST_ALONG:
		heading = randf_range(0.9, 1.9) * side
	else:
		heading = (PI - randf_range(0.0, 0.6)) * side
	burst_speed = lerpf(BURST_SPEED.x, BURST_SPEED.y, heft) * vigor * randf_range(0.7, 1.15)
	burst_left = randf_range(BURST_TIME.x, BURST_TIME.y) * lerpf(0.8, 1.2, heft)
	_burst_gap = randf_range(BURST_GAP.x, BURST_GAP.y) / maxf(vigor, 0.35)
	var jerk := lerpf(BURST_JERK.x, BURST_JERK.y, heft) * vigor
	if opening_left > 0.0:
		_jerk = maxf(_jerk, jerk)
	elif tension < 0.97:
		tension = minf(tension + jerk, 0.97)


## The bank's in the way: the fish turns back (Player).
func turn_back() -> void:
	if burst_left > 0.0:
		heading = wrapf(heading + PI, -PI, PI)


## Which way it's swimming across the line now (unit, or ZERO).
func swim_side_dir() -> Vector2:
	if burst_left <= 0.0 or absf(sin(heading)) < 0.3:
		return Vector2.ZERO
	return _line_dir.orthogonal() * signf(sin(heading))


## Between events: count down to the next run / leap / dash for cover.
func _schedule(delta: float, line_dir: Vector2) -> Array:
	var events := []
	if habit == "cover":
		_dive_timer -= delta
		if _dive_timer <= 0.0:
			dive_active = true
			dive = 0.05
			events.append("dive")
			return events
	var jump_chance: float = diff.jump * (JUMPER_JUMP_MULT if habit == "jumper" else 1.0)
	if _jump_cooldown <= 0.0 and randf() < jump_chance * delta:
		jump_left = JUMP_TIME
		_jump_cooldown = JUMP_COOLDOWN
		events.append("jump")
		return events
	_run_timer -= delta
	if _run_timer <= 0.0:
		var interval: Vector2 = diff.run_interval * (ENRAGE_INTERVAL if enraged else 1.0)
		_run_timer = randf_range(interval.x, interval.y)
		run_left = diff.run_time
		if randf() < diff.side and line_dir != Vector2.ZERO:
			_run_sign = 1.0 if randf() < 0.5 else -1.0
			run_side = line_dir.orthogonal() * _run_sign
			# Long enough to answer with a flick.
			run_left = maxf(run_left, SWIPE_WINDOW)
			swipe_left = SWIPE_WINDOW
			_swipe_armed = false
			events.append("side_run")
		else:
			run_side = Vector2.ZERO
			events.append("run")
	return events


## During a sideways dash: has the stick been flicked against it? True if
## this frame ended the dash (a hit).
func _swipe_check(delta: float, counter: Vector2, events: Array) -> bool:
	var against := counter.length() > 0.3 and counter.normalized().dot(-run_side) > SWIPE_THRESHOLD
	if not against:
		_swipe_armed = true
	elif _swipe_armed:
		progress += SWIPE_DAMAGE
		tension = maxf(tension - 0.1, 0.0)
		run_left = 0.0
		swipe_left = 0.0
		events.append("swipe_hit")
		return true
	swipe_left -= delta
	if swipe_left <= 0.0:
		swipe_left = 0.0
		events.append("swipe_miss")
	return false


## What the fish is doing, for the fight panel (FightPanel): "jump", "dive",
## "run", "side_run", "enraged", "spent", "tired", "slack", "surge",
## "opening", "rally", "swim_out", "swim_in", "swim_side" or "".
func mood() -> String:
	if opening_left > 0.0:
		if slack > 0.0 and not hold and crank < HELD_AT:
			return "slack"
		return "surge" if surging() else "opening"
	if spent:
		return "spent"
	if jump_left > 0.0:
		return "jump"
	if dive_active:
		return "dive"
	if run_left > 0.0:
		return "side_run" if run_side != Vector2.ZERO else "run"
	if rally_left > 0.0:
		return "rally"
	if burst_left > 0.0 and burst_speed >= SWIM_SHOWN:
		if cos(heading) > 0.6:
			return "swim_out"
		if cos(heading) < -0.6:
			return "swim_in"
		return "swim_side"
	if enraged:
		return "enraged"
	if stamina() < TIRED_AT:
		return "tired"
	return ""


## The tension gauge's sweet spot, low to high.
func sweet_range() -> Vector2:
	var half: float = diff.get("sweet", 0.3) * 0.5
	return Vector2(SWEET_CENTER - half, SWEET_CENTER + half)


func in_sweet() -> bool:
	var r := sweet_range()
	return tension >= r.x and tension <= r.y


## Struck right as the float went under: the fish starts worn and the
## line slack.
func perfect_hook() -> void:
	perfect = true
	progress = minf(progress + PERFECT_HOOK_STAMINA, 0.9)
	tension = PERFECT_HOOK_TENSION


## The fish's stamina as shown on the HUD (1 fresh -> 0 spent).
func stamina() -> float:
	return 1.0 - progress


static func describe(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "右" if dir.x > 0.0 else "左"
	return "下" if dir.y > 0.0 else "上"
