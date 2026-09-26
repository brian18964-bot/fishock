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

const RUN_TENSION_MULT := 1.8
## Giving line to a run: the drag holds tension nearly level.
const RUN_SLACK_TENSION := 0.15
const RUN_PROGRESS_PENALTY := 0.2
const SIDE_COUNTER_THRESHOLD := 0.35
const JUMP_TIME := 0.7
const JUMP_HELD_TENSION := 2.4
const JUMP_COOLDOWN := 2.5
const JUMPER_JUMP_MULT := 1.8
const ENRAGE_AT := 0.5
const ENRAGE_RUN_TIME := 1.4
const ENRAGE_PULL := 1.15
## User request: berserk, the line tightens fast while you reel - ease off
## (let go) and it drops again. On top of ENRAGE_PULL.
const ENRAGE_REEL_TENSION := 2.2
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

var diff: Dictionary
var difficulty_key: String
var habit: String
var reel_speed: float
var tension_rise: float
var tension_fall: float
## The rod (Profile.ROD_TIERS): its line strength divides every tension
## gain (the tension cap), and `jump` scales the strain of holding a leap.
var line_strength := 1.0
var jump_strain := 1.0

var progress := 0.0
var tension := 0.15
var enraged := false
var result := ""  # "", "landed", "line_break", "shook_off", "cover"

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


## One frame. held: reeling in. counter: the direction the rod is being
## pulled (unit or ZERO). line_dir: from the angler toward the fish.
## reel_mult: extra reel-speed factor (walking while reeling). Returns the
## events this frame started: "run", "side_run", "jump", "dive", "enrage",
## "dive_saved", "swipe_hit", "swipe_miss".
func update(delta: float, held: bool, counter: Vector2, line_dir: Vector2, reel_mult: float = 1.0) -> Array:
	var events := []
	if result != "":
		return events
	var pull: float = diff.pull * (ENRAGE_PULL if enraged else 1.0)
	age += delta
	_jump_cooldown -= delta

	if jump_left > 0.0:
		jump_left -= delta
		if held:
			tension += JUMP_HELD_TENSION * jump_strain / line_strength * delta
		else:
			tension -= tension_fall * delta
	elif dive_active:
		if held:
			dive -= DIVE_HAUL * delta
			progress += reel_speed * 0.3 * delta
			tension += tension_rise * pull * DIVE_TENSION * delta
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
			if held:
				progress -= RUN_PROGRESS_PENALTY * delta
				tension += tension_rise * RUN_TENSION_MULT * pull * delta
			else:
				tension += tension_rise * RUN_SLACK_TENSION * pull * delta
		elif swipe_left > 0.0 and _swipe_check(delta, counter, events):
			pass
		elif counter.length() > 0.3 and counter.normalized().dot(-run_side) > SIDE_COUNTER_THRESHOLD:
			# Rod pulled against the run: it's held, and you can keep reeling.
			if held:
				progress += reel_speed * 0.5 * delta
				tension += tension_rise * 0.6 * pull * delta
			else:
				tension -= tension_fall * 0.5 * delta
		else:
			progress -= RUN_PROGRESS_PENALTY * delta
			tension += tension_rise * RUN_TENSION_MULT * pull * (1.0 if held else 0.45) * delta
		if run_left <= 0.0:
			swipe_left = 0.0
	else:
		if held:
			progress += reel_speed * reel_mult * (SWEET_REEL_MULT if in_sweet() else 1.0) * delta
			tension += tension_rise * pull * (ENRAGE_REEL_TENSION if enraged else 1.0) * delta
		else:
			tension -= tension_fall * delta
		events.append_array(_schedule(delta, line_dir))

	if diff.phases > 1 and not enraged and progress >= ENRAGE_AT:
		enraged = true
		run_left = ENRAGE_RUN_TIME
		run_side = Vector2.ZERO
		swipe_left = 0.0
		jump_left = 0.0
		events.append("enrage")

	tension = clampf(tension, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	if result == "":
		if tension >= 1.0:
			result = "shook_off" if jump_left > 0.0 else "line_break"
		elif progress >= 1.0:
			result = "landed"
	return events


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
			run_side = line_dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
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
## "run", "side_run", "enraged", "tired" or "".
func mood() -> String:
	if jump_left > 0.0:
		return "jump"
	if dive_active:
		return "dive"
	if run_left > 0.0:
		return "side_run" if run_side != Vector2.ZERO else "run"
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
