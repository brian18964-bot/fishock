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

## User request (damage numbers): the fish's stamina is a monster's health (`max_hp`,
## by its rarity and size - hp_for) and what takes it down is a number: the reel's
## (every TICK_EVERY s, gold in the sweet spot), a flicked dash's (a crit, and a
## perfect one if it was quick), the strike's. The tension is the damage the angler
## takes (TENSION_HP of it is all the line holds): what the fish does to it - a run,
## a leap, a dash for cover, a surge - is added up and shown with its name, a
## move answered in time with no tension taken is a parry. All of it is queued in
## `hits` (FightPanel shows them: drain_hits()); see _account().
##
## User request (the pull and the way back): a move has a way it pulls (`pull_dir`, on the
## clock face from the angler, 12 straight out over the water): a dash 10-2, a sideways
## dash 8-10 or 2-4, a dash for the rocks or into the weed 5-7, berserk any way (a new
## one each second), a rally any way (it tightens the line till it's answered). The left
## hand answers by dragging the other way (`counter` within ANSWER_DOT of it: 45 deg):
## the fish is held - a dash takes little line and the reel keeps going, the dive is
## hauled back, the weed frays slower, the berserk and the rally build less tension.
## Not answered, it's as it was.
##
## User request (the field - distance and depth, `field`): where the fish is on the
## water is used against the angler. The water shelves away from the bank, so how
## deep it can go depends on how far out it is (bottom_depth(): near the bank it
## can only skim, far out it can sound). The range changes the fight (range_zone()):
## close in the line has no give - the tension builds faster but the reel brings
## line in faster; far out the line gives - tension builds
## slower but the reel is slow; the middle is where the tension's sweet spot is
## widest. Some water has a snag - weed and rock at a stretch of the bottom
## (snag_from..snag_to m out, deeper than SNAG_TOP): a fish that gets into it frays
## the line (`fray`, 0..1, snaps it at 1; it mends outside) - a fish that hides in
## cover heads for it. Pull it out: reel it back (it comes up as it's reeled).
##
## User request (fish came in to the bank still fresh): a hooked fish keeps
## to its water - within `roam` m of where it took the bait (`home`, the
## line out at the strike), the harder, bigger and rarer the wider (ROAM,
## light .. heavy). Its bursts turn back toward it once it's strayed. Fresh,
## it won't be brought nearer than the near edge of it: reeled past that
## (near_limit()) the reel brings only HOLD_REEL of the line in and the
## tension climbs (HOLD_TENSION) - the line and the tension go with how far
## it's dragged from its water; let be, it swims back out (HOME_BACK m/s).
## As it tires the near edge comes in, all the way once it's spent.
const ROAM := Vector2(2.5, 8.0)
const HOLD_REEL := 0.15
const HOLD_TENSION := 1.6
const HOME_BACK := 0.9
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
## User request (stats): what the four stats do in a fight (Player sets them at the
## strike: Stats.total).
##   力量 might: the stamina a perfect strike and a flicked dash take x (1 + might/100),
##     the reel brings line in x (1 + might/200)
##   反應 react: the time to flick against a dash x (1 + react/150) (and, before the
##     fight, the time to strike and the perfect strike's - Player)
##   韌性 resil: the line's tension builds /(1 + resil/150); the tension sweet spot
##     (1 + resil/300) wider; the danger far out starts resil/1000 later and a leap
##     out there snaps it only 1/(1 + resil/150) of the time
##   耐力 endure: how long the arms last - FATIGUE_BASE + endure/5 s into the fight,
##     over FATIGUE_SPAN s the other three's help fades away (their numbers count
##     x (1 - fatigue)), the reel slows by REEL_TIRED and the tension builds
##     (1 + TENSION_TIRED x fatigue) as fast
const FATIGUE_BASE := 15.0
const FATIGUE_PER_ENDURE := 0.2
const FATIGUE_SPAN := 30.0
const REEL_TIRED := 0.3
const TENSION_TIRED := 0.5
## The pull and the answer (see above).
const RUN_ARC := 1.05
const SIDE_ARC := 0.52
const DIVE_ARC := 0.52
const RAGE_ARC := 1.75
const RAGE_REROLL := Vector2(0.8, 1.2)
const RALLY_ARC := 2.5
const RALLY_REROLL := 1.5
const RALLY_JERK := 0.1
const RALLY_TIGHT := 0.35
const RALLY_TIGHT_TO := 0.85
const ANSWER_DOT := 0.7
const HELD_RUN_OUT := 1.0
## The field (see above).
const BOTTOM_NEAR := 1.2
const BOTTOM_OVER := 1.0
const BOTTOM_REACH := 0.6
const NEAR_END := 0.25
const MID_END := 0.6
const NEAR_TENSION := 1.3
const FAR_TENSION := 0.85
const NEAR_REEL := 1.15
const FAR_REEL := 0.8
const MID_SWEET := 1.15
const SNAG_CHANCE := 0.5
const SNAG_WIDTH := 5.0
const SNAG_TOP := 1.6
const FRAY_RATE := 0.3
const FRAY_MEND := 0.4
const SNAG_HEAD := 0.6
const SNAG_HURT_EVERY := 0.8
## The damage numbers' scale: the fish's health, by rarity and size.
const HP_BASE := {"common": 300.0, "rare": 900.0, "epic": 3000.0, "legend": 9000.0}
const HP_SIZE := {"small": 0.7, "medium": 1.0, "large": 1.5, "huge": 2.2}
## A flick within this share of the window is a perfect one (and hits this much harder).
const PERFECT_SWIPE_SHARE := 0.4
const PERFECT_SWIPE_MULT := 1.5
const TICK_EVERY := 0.45
const TENSION_HP := 100.0
## The least tension taken (in TENSION_HP) that's shown; how often a long move shows
## its total; how long a move must go on with nothing taken to count as parried.
const HURT_MIN := 4.0
const HURT_EVERY := 0.7
const PARRY_AFTER := 0.5
## What a fish's moves are called when they hurt (mood()), and the ones a parry
## can answer.
const HURT_SRC := {"run": "衝刺", "side_run": "橫衝", "jump": "躍出", "dive": "鑽石縫", "surge": "猛拉", "rally": "反撲"}
const PARRY_SRC := ["run", "side_run", "jump", "dive", "rally"]
const WARN_OF := {"snag_in": "水草區", "run": "衝刺", "side_run": "橫衝", "jump": "躍出", "dive": "鑽石縫", "enrage": "狂暴", "rally": "反撲"}
var stat_might := 0.0
var stat_react := 0.0
var stat_resil := 0.0
var stat_endure := 0.0


## How worn the angler's arms are (0 fresh .. 1 spent) at this point of the fight.
func fatigue() -> float:
	return clampf((age - (FATIGUE_BASE + stat_endure * FATIGUE_PER_ENDURE)) / FATIGUE_SPAN, 0.0, 1.0)


func might_mult() -> float:
	return 1.0 + stat_might * (1.0 - fatigue()) / 100.0


func react_mult() -> float:
	return 1.0 + stat_react * (1.0 - fatigue()) / 150.0


func resil_mult() -> float:
	return 1.0 + stat_resil * (1.0 - fatigue()) / 150.0


## How fast the line comes in, against the plain reel.
func reel_boost() -> float:
	return (1.0 + stat_might * (1.0 - fatigue()) / 200.0) * (1.0 - REEL_TIRED * fatigue()) * range_reel()


## What the tension builds x (Player folds it into `strain` each frame).
func stat_strain() -> float:
	return (1.0 + TENSION_TIRED * fatigue()) / resil_mult() * range_tension()


func swipe_damage() -> float:
	return SWIPE_DAMAGE * might_mult()


func swipe_window() -> float:
	return SWIPE_WINDOW * react_mult()
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
## Its water (see ROAM): the line out at the strike (-1 till the first
## frame), how far it'll roam, how far it's gone across the line (m).
var home := -1.0
var roam := 4.0
var side_off := 0.0
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

## Which way the move on pulls (a unit vector from the angler's line, ZERO none) and
## whether the counter asked for answers it now.
var pull_dir := Vector2.ZERO
var answering := false
var _run_dir := Vector2.ZERO
var _dive_dir := Vector2.ZERO
var _snag_dir := Vector2.ZERO
var _rally_dir := Vector2.ZERO
var _rage_t := 0.0
var _rally_t := 0.0
## The field (see above): on, where the snag is (if there is one), the line's fray.
var field := false
var snag_on := false
var snag_from := 0.0
var snag_to := 0.0
var fray := 0.0
var _in_snag := false
var _snag_hurt := 0.0
## The damage numbers (see above): the fish's health, and what's queued to show.
var max_hp := 1000.0
var hits: Array = []
var _acc_dmg := 0.0
var _acc_sweet := 0.0
var _tick_t := 0.0
var _explicit := 0.0
var _sweet_frame := false
var _hurt_src := ""
var _hurt_acc := 0.0
var _hurt_t := 0.0
var _hurt_since := 0.0

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


## The line's way (angler to fish): what the clock face is turned to.
func line_way() -> Vector2:
	return _line_dir


## A way `arc` either side of the line's way turned by `turn` (rad, clockwise).
func _way(turn: float, arc: float) -> Vector2:
	return _line_dir.rotated(turn + randf_range(-arc, arc))


## Which way the move on pulls, this frame (see above).
func _refresh_pull(delta: float) -> void:
	var d := Vector2.ZERO
	if opening_left > 0.0 or spent or jump_left > 0.0:
		d = Vector2.ZERO
	elif _in_snag:
		d = _snag_dir
	elif dive_active:
		d = _dive_dir
	elif run_left > 0.0:
		if run_side != Vector2.ZERO:
			d = run_side.normalized()
		else:
			if enraged:
				_rage_t -= delta
				if _rage_t <= 0.0:
					_run_dir = _way(0.0, RAGE_ARC)
					_rage_t = randf_range(RAGE_REROLL.x, RAGE_REROLL.y)
			d = _run_dir
	elif rally_left > 0.0:
		_rally_t -= delta
		if _rally_t <= 0.0:
			_rally_dir = _way(0.0, RALLY_ARC)
			_rally_t = RALLY_REROLL
			tension = minf(tension + RALLY_JERK, 0.97)
		d = _rally_dir
	pull_dir = d


## A fish's health for the damage numbers: its rarity ("common" .. "legend") and
## size ("small" .. "huge").
static func hp_for(rarity_key: String, size_key: String) -> float:
	return roundf(float(HP_BASE.get(rarity_key, 300.0)) * float(HP_SIZE.get(size_key, 1.0)) / 10.0) * 10.0


## What's left of its health.
func hp() -> float:
	return stamina() * max_hp


func _push(hit: Dictionary) -> void:
	hits.append(hit)
	if hits.size() > 40:
		hits.pop_front()


## The queued numbers, taken (FightPanel).
func drain_hits() -> Array:
	var out := hits
	hits = []
	return out


## What's added up so far shown now (the end of a fight, or a pause).
func flush_hits() -> void:
	_flush_dmg()
	_flush_hurt(false)


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
	if tension * TENSION_HP >= 10.0:
		_push({"type": "hurt", "src": "咬鉤", "n": roundi(tension * TENSION_HP)})


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
## "swipe_miss", "spent", "recover", "opened", "snag_in", "snag_out".
func update(delta: float, reel: Variant, counter: Vector2, line_dir: Vector2, reel_mult: float = 1.0) -> Array:
	var events := []
	if result != "":
		return events
	if reel is bool:
		reel = CRANK_NORMAL if reel else 0.0
	crank = clampf(float(reel), 0.0, 1.0)
	var held := crank >= HELD_AT
	var p_before := progress
	var t_before := tension
	_refresh_pull(delta)
	answering = pull_dir != Vector2.ZERO and counter.length() > 0.3 and counter.normalized().dot(-pull_dir) > ANSWER_DOT
	_explicit = 0.0
	_sweet_frame = false
	if home < 0.0:
		home = distance
		roam = lerpf(ROAM.x, ROAM.y, heft)
		_place_snag()
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
		# (answered - pulled the other way - it's held: hauled back, less strain)
		var soften := 0.4 if answering else 1.0
		if held:
			dive -= DIVE_HAUL * k * delta * (1.5 if answering else 1.0)
			progress += reel_speed * 0.3 * k * delta
			tension += tension_rise * strain * pull * DIVE_TENSION * k * soften * delta
		else:
			dive += DIVE_SPEED * (0.35 if answering else 1.0) * delta
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
			if answering:
				# Pulled the other way: held - little line taken, and the reel goes on.
				out_mult = HELD_RUN_OUT
				reel_in = k * reel_mult * 0.5
				if held:
					progress += reel_speed * 0.4 * k * delta
					tension += tension_rise * strain * 0.6 * pull * k * delta
				else:
					tension -= tension_fall * 0.5 * delta
			elif held:
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
			_sweet_frame = in_sweet()
			progress += reel_speed * reel_mult * k * (SWEET_REEL_MULT if in_sweet() else 1.0) * reel_boost() * delta
			tension += tension_rise * strain * pull * k * (ENRAGE_REEL_TENSION if enraged else 1.0) * delta
		else:
			tension -= tension_fall * delta
		events.append_array(_schedule(delta, line_dir))
		if events.has("jump") and danger() > 0.0 and randf() < 1.0 / resil_mult():
			# A leap that far out: the line can't take it (a tougher line - 韌性 - sometimes can).
			snap_why = "leap"
			result = "line_break"

	# (a rally pulls the line tight till it's answered)
	if rally_left > 0.0 and not spent and opening_left <= 0.0:
		if answering:
			tension -= tension_fall * 0.5 * delta
		elif tension < RALLY_TIGHT_TO:
			# (held tight by the fish itself, up to where the next thing breaks it)
			tension = minf(tension + (tension_fall + RALLY_TIGHT * strain) * delta, RALLY_TIGHT_TO)
	if diff.phases > 1 and not enraged and progress >= ENRAGE_AT:
		enraged = true
		run_left = ENRAGE_RUN_TIME
		run_side = Vector2.ZERO
		_run_dir = _way(0.0, RAGE_ARC)
		_rage_t = randf_range(RAGE_REROLL.x, RAGE_REROLL.y)
		swipe_left = 0.0
		jump_left = 0.0
		events.append("enrage")

	tension = clampf(tension, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	if held and out_mult != RUN_OUT_MULT and not resisted:
		out_mult *= HELD_OUT
	_depth(delta, k if held else 0.0, radial)
	side_off += lateral * delta
	_line(delta, out_mult, reel_in if held else 0.0, pull, radial)
	_snag(delta, events)
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
	_account(delta, p_before, t_before, events)
	return events


## The damage numbers of this frame (see above): the stamina lost that the reel
## took (the flicks and the strike are queued as they happen - `_explicit`), and
## the tension the fish's own moves put on.
func _account(delta: float, p_before: float, t_before: float, events: Array) -> void:
	for ev in events:
		if WARN_OF.has(ev):
			_push({"type": "warn", "src": WARN_OF[ev]})
	var gained := progress - p_before - _explicit
	if gained > 0.0:
		_acc_dmg += gained
		if _sweet_frame:
			_acc_sweet += gained
	_tick_t += delta
	if _tick_t >= TICK_EVERY:
		_flush_dmg()
	var src := mood()
	if not HURT_SRC.has(src):
		src = ""
	if src != _hurt_src:
		_flush_hurt(true)
		_hurt_src = src
		_hurt_t = 0.0
		_hurt_since = 0.0
	if src != "":
		_hurt_t += delta
		_hurt_since += delta
		_hurt_acc += maxf(tension - t_before, 0.0)
		if _hurt_since >= HURT_EVERY:
			_hurt_since = 0.0
			_flush_hurt(false)
	if result != "":
		flush_hits()


func _flush_dmg() -> void:
	_tick_t = 0.0
	var n := _acc_dmg * max_hp
	if n >= 0.5:
		_push({"type": "dmg", "style": "sweet" if _acc_sweet > _acc_dmg * 0.5 else "tick", "n": roundi(n)})
	_acc_dmg = 0.0
	_acc_sweet = 0.0


## The tension a move put on, shown: `ended` - the move's over, so with none taken
## it was parried.
func _flush_hurt(ended: bool) -> void:
	var n := _hurt_acc * TENSION_HP
	if n >= HURT_MIN:
		_push({"type": "hurt", "src": HURT_SRC.get(_hurt_src, ""), "n": roundi(n)})
	elif ended and PARRY_SRC.has(_hurt_src) and _hurt_t >= PARRY_AFTER and _hurt_acc * TENSION_HP < HURT_MIN:
		_push({"type": "parry"})
	_hurt_acc = 0.0


## The line out: the fish takes it (tired, less), the crank brings it in;
## all out, it's gone; out in the danger it may snap.
func _line(delta: float, out_mult: float, reel_in: float, pull: float, radial := 0.0) -> void:
	if result != "":
		return
	var out: float = swim_out * out_mult * pull / diff.pull * lerpf(TIRED_OUT, 1.0, stamina())
	var reeled := REEL_IN * reel_in
	var limit := near_limit()
	if not spent and home > 0.0:
		var past := limit + 0.2 - distance
		if past > 0.0 and reel_in > 0.0:
			# Dragged out of its water: it pulls back (see ROAM) - the
			# further, the harder.
			reeled *= HOLD_REEL
			out += HOME_BACK * vigor * clampf(past, 0.0, 1.5)
			tension = minf(tension + tension_rise * strain * pull * HOLD_TENSION * clampf(past / 1.5 + 0.4, 0.4, 1.6) * reel_in * delta, 1.0)
		elif reel_in <= 0.0 and distance < home:
			# Let be, it heads back to its water.
			out += HOME_BACK * vigor * clampf((home - distance) / maxf(roam, 0.1), 0.0, 1.0)
	distance = clampf(distance + (out - reeled + radial) * delta, MIN_DISTANCE, line_max)
	if line_out() >= line_max:
		snap_why = "far"
		result = "line_out"
	elif danger() > 0.0 and randf() < DANGER_SNAP * danger() * danger() * delta:
		snap_why = "far"
		result = "line_break"


## The nearest the fish lets itself be brought now (see ROAM): the near
## edge of its water fresh, in to the bank as it tires.
func near_limit() -> float:
	if spent or home < 0.0:
		return MIN_DISTANCE
	return lerpf(MIN_DISTANCE, maxf(home - roam, MIN_DISTANCE), pow(stamina(), 0.7))


## How far into the danger the line is (0 not yet .. 1 all out).
func danger() -> float:
	# (韌性: the danger starts further out - 100 more moves it a tenth)
	var from := minf(DANGER + stat_resil * (1.0 - fatigue()) / 1000.0, 0.95)
	return clampf((line_share() - from) / (1.0 - from), 0.0, 1.0)


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
	if field:
		depth = minf(depth, bottom_depth())


## How lively it is now (see above) - and its rally, when it comes.
func _vigor(delta: float, events: Array) -> void:
	vigor = lerpf(VIGOR_FLOOR, 1.0, pow(stamina(), 0.8))
	if lively and not rallied and not spent and progress >= RALLY_AT:
		rallied = true
		if randf() < float(diff.get("rally", 0.0)):
			rally_left = RALLY_TIME
			_rally_dir = _way(0.0, RALLY_ARC)
			_rally_t = RALLY_REROLL
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
	# (strayed from its water: back toward it - see ROAM)
	if home > 0.0 and absf(side_off) > roam:
		side = -signf(side_off)
	var r := randf()
	var out_share := BURST_OUT
	var in_share := 1.0 - BURST_OUT - BURST_ALONG
	if home > 0.0 and distance < home - roam * 0.5:
		out_share = 0.65
		in_share = 0.05
	elif home > 0.0 and distance > home + roam:
		out_share = 0.05
		in_share = 0.65
	if r < out_share:
		heading = randf_range(-0.5, 0.5)
	elif r < 1.0 - in_share:
		heading = randf_range(0.9, 1.9) * side
	else:
		heading = (PI - randf_range(0.0, 0.6)) * side
	# (a fish that hides in cover heads for the snag, one that's raging too)
	if field and snag_on and not spent and randf() < (SNAG_HEAD if habit == "cover" else (SNAG_HEAD * 0.4 if enraged else 0.0)):
		var centre := (snag_from + snag_to) * 0.5
		heading = randf_range(-0.3, 0.3) if distance < centre else PI - randf_range(0.0, 0.3)
	burst_speed = lerpf(BURST_SPEED.x, BURST_SPEED.y, heft) * vigor * randf_range(0.7, 1.15)
	burst_left = randf_range(BURST_TIME.x, BURST_TIME.y) * lerpf(0.8, 1.2, heft)
	_burst_gap = randf_range(BURST_GAP.x, BURST_GAP.y) / maxf(vigor, 0.35)
	var jerk := lerpf(BURST_JERK.x, BURST_JERK.y, heft) * vigor
	if opening_left > 0.0:
		_jerk = maxf(_jerk, jerk)
	elif tension < 0.97:
		var before := tension
		tension = minf(tension + jerk, 0.97)
		if (tension - before) * TENSION_HP >= HURT_MIN:
			_push({"type": "hurt", "src": "拉扯", "n": roundi((tension - before) * TENSION_HP)})


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
			_dive_dir = _line_dir.rotated(PI + randf_range(-DIVE_ARC, DIVE_ARC))
			events.append("dive")
			return events
	var jump_chance: float = diff.jump * (JUMPER_JUMP_MULT if habit == "jumper" else 1.0)
	if field:
		# (it leaps from the shallows, not from the deep)
		jump_chance *= 1.5 if depth < 1.5 else (0.6 if depth > 3.5 else 1.0)
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
			run_side = line_dir.rotated(_run_sign * (PI * 0.5 + randf_range(-SIDE_ARC, SIDE_ARC)))
			# Long enough to answer with a flick.
			run_left = maxf(run_left, swipe_window())
			swipe_left = swipe_window()
			_swipe_armed = false
			events.append("side_run")
		else:
			run_side = Vector2.ZERO
			_run_dir = _way(0.0, RUN_ARC)
			events.append("run")
	return events


## During a sideways dash: has the stick been flicked against it? True if
## this frame ended the dash (a hit).
func _swipe_check(delta: float, counter: Vector2, events: Array) -> bool:
	var against := counter.length() > 0.3 and counter.normalized().dot(-run_side) > SWIPE_THRESHOLD
	if not against:
		_swipe_armed = true
	elif _swipe_armed:
		var quick := (swipe_window() - swipe_left) <= swipe_window() * PERFECT_SWIPE_SHARE
		var dmg := minf(swipe_damage() * (PERFECT_SWIPE_MULT if quick else 1.0), 1.0 - progress)
		progress += dmg
		_explicit += dmg
		_push({"type": "dmg", "style": "perfect" if quick else "swipe", "n": roundi(dmg * max_hp)})
		tension = maxf(tension - 0.1, 0.0)
		run_left = 0.0
		swipe_left = 0.0
		events.append("swipe_hit")
		return true
	swipe_left -= delta
	if swipe_left <= 0.0:
		swipe_left = 0.0
		_push({"type": "miss"})
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
	if _in_snag:
		return "snag"
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
	var half: float = diff.get("sweet", 0.3) * 0.5 * (1.0 + stat_resil * (1.0 - fatigue()) / 300.0)
	if field and range_zone() == "mid":
		half *= MID_SWEET
	return Vector2(SWEET_CENTER - half, SWEET_CENTER + half)


## How far out it is: "near" (the line has no give), "mid" (the best), "far" (the
## line gives, the reel is slow). "mid" when the field's off.
func range_zone() -> String:
	if not field:
		return "mid"
	var share := line_share()
	if share < NEAR_END:
		return "near"
	return "mid" if share < MID_END else "far"


func range_tension() -> float:
	match range_zone():
		"near":
			return NEAR_TENSION
		"far":
			return FAR_TENSION
	return 1.0


func range_reel() -> float:
	match range_zone():
		"near":
			return NEAR_REEL
		"far":
			return FAR_REEL
	return 1.0


## How deep the water is where the fish is: it shelves away from the bank, down to a
## little past the deepest this fish goes.
func bottom_depth(at := -1.0) -> float:
	var d := distance if at < 0.0 else at
	return lerpf(BOTTOM_NEAR, depth_max() + BOTTOM_OVER, clampf((d - MIN_DISTANCE) / (line_max * BOTTOM_REACH), 0.0, 1.0))


## Is it down in the snag?
func in_snag() -> bool:
	return snag_on and distance >= snag_from and distance <= snag_to and depth > SNAG_TOP


## Where the snag is, picked at the strike: beyond or short of where it took the bait.
func _place_snag() -> void:
	snag_on = field and (habit == "cover" or randf() < SNAG_CHANCE)
	if not snag_on:
		return
	var centre := clampf(home + randf_range(3.0, 8.0) * (1.0 if randf() < 0.7 else -1.0), 6.0, line_max * 0.62)
	if absf(centre - home) < SNAG_WIDTH:
		centre = clampf(home + SNAG_WIDTH * 1.4, 6.0, line_max * 0.62)
	snag_from = centre - SNAG_WIDTH * 0.5
	snag_to = centre + SNAG_WIDTH * 0.5


## In the snag the line frays; out of it, it mends. Frayed through, it snaps.
func _snag(delta: float, events: Array) -> void:
	if not snag_on or result != "":
		return
	var now := in_snag() and not spent
	if now and not _in_snag:
		_snag_dir = _line_dir.rotated(PI + randf_range(-DIVE_ARC, DIVE_ARC))
		events.append("snag_in")
	elif _in_snag and not now:
		events.append("snag_out")
	_in_snag = now
	if now:
		# (pulled the other way, it's held: the line frays slower and it's lifted)
		fray = minf(fray + FRAY_RATE * (0.35 if answering else 1.0) * delta, 1.0)
		if answering:
			depth = move_toward(depth, 0.5, 0.8 * delta)
		_snag_hurt += delta
		if _snag_hurt >= SNAG_HURT_EVERY:
			_snag_hurt = 0.0
			_push({"type": "hurt", "src": "割線", "n": roundi(FRAY_RATE * SNAG_HURT_EVERY * TENSION_HP)})
		if fray >= 1.0:
			snap_why = "snag"
			result = "line_break"
	else:
		fray = maxf(fray - FRAY_MEND * delta, 0.0)
		_snag_hurt = 0.0


func in_sweet() -> bool:
	var r := sweet_range()
	return tension >= r.x and tension <= r.y


## Struck right as the float went under: the fish starts worn and the
## line slack.
## Worn down from the start by this share of its stamina (a lure struck
## true - Player.LURE_TRUE_WORN).
func wear(share: float) -> void:
	var before := progress
	progress = minf(progress + share, 0.9)
	if progress > before:
		_push({"type": "dmg", "style": "wear", "n": roundi((progress - before) * max_hp)})


func perfect_hook() -> void:
	perfect = true
	var before := progress
	progress = minf(progress + PERFECT_HOOK_STAMINA * might_mult(), 0.9)
	_push({"type": "dmg", "style": "strike", "n": roundi((progress - before) * max_hp)})
	tension = PERFECT_HOOK_TENSION


## The fish's stamina as shown on the HUD (1 fresh -> 0 spent).
func stamina() -> float:
	return 1.0 - progress


static func describe(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "右" if dir.x > 0.0 else "左"
	return "下" if dir.y > 0.0 else "上"
