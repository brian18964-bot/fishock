class_name CampLife
extends Node

## User request (Camp v2): the character lives at the camp on its own -
## sits by the fire, mends the tent, opens the crate and has a bite,
## crouches over the fish, leans on the drum looking at the lake, has a
## word with the merchant, warms itself, keeps watch with the lamp held up
## at the edge of the dark - less and less of it as its spirit
## (Profile.spirit) runs down. (Chopping wood and carrying it, gathering
## sticks: dropped - user request, the hands didn't close on what they
## held. Dancing: dropped too, user request.)
## User request: the user's Mixamo clips too (tools/build_menu_character.py)
## - a nap in the tent (lying down, asleep, up again), sitting on the
## ground by the fire, a rest on the log, stretching, looking about at the
## edge of the dark (or peeking into it), a wave to the merchant as it goes
## over and as he goes, low (head down) when worn out, and home again a
## cheer (escaped) or a sigh (lost).
## User request (it was never still - restless to watch): mostly it stands
## at the fire looking into it or sits on a log resting, a good while each,
## and only now and then does something else. Nothing that means something
## to another (a clap, talking to no one, a wave at no one) while it's on
## its own - kept for when there are others at the camp. A cup of tea on
## the log only when the merchant's tea was bought (treat()), a bite at the
## fire when his food was; lying down only in the tent. No taps on it: a
## tap spun it round mid-whatever (user request: taken out, a word with it
## to come, done properly).
##   70-100  busy    all of it
##   50-69   tired   no mending; slower; sits more
##   30-49   worn    mostly sits, a long while, or naps; stands low
##   0-29    spent   only sits
## And the set pieces: setting out (depart(): the lamp from the drum - it
## lights - and off to the 渡石, the game fading in as it goes), coming home
## through the 渡石 (come_home("escaped")) and waking in the tent after a
## run lost (come_home("lost")).
##
## A plan is a list of steps, each a Dictionary:
##   {do: "walk", to}            walk there round things (CampStage.route;
##                               `straight`: straight there - into the tent)
##   {do: "face", at}            turn to look at a point (`node`: at
##                               someone, where they are by then)
##   {do: "play", clip, at, fn}  a clip through once (fn called `at` of
##                               the way through; `back`: backwards;
##                               `time`: cut short at that)
##   {do: "loop", clip, time}    a looping clip a while
##   {do: "wait", time}          stand a moment
##   {do: "hold", time}          keep still, the clip paused where it is
##   {do: "call", fn}            do something (pick up, put down...)

signal plan_done(tag: String)

## The Walk clip's own pace (m/s).
const WALK_SPEED := 0.8
const TURN_RATE := 7.0
## How often it does each thing, by how it feels: [spent, worn, tired, busy].
## (The fire and the log far the most: user request.)
const WEIGHTS := {
	"sit": [1.0, 6.0, 4.0, 3.0],
	"fire": [0.0, 2.0, 4.0, 4.0],
	"nap": [0.0, 0.5, 0.2, 0.0],
	"ground": [0.0, 0.4, 0.3, 0.2],
	"tent": [0.0, 0.0, 0.0, 0.3],
	"crate": [0.0, 0.0, 0.2, 0.3],
	"trough": [0.0, 0.2, 0.3, 0.4],
	"lean": [0.0, 0.0, 0.5, 0.5],
	"lake": [0.0, 0.0, 0.5, 0.5],
	"look": [0.0, 0.0, 0.2, 0.3],
	"stretch": [0.0, 0.0, 0.2, 0.3],
	"merchant": [0.0, 0.0, 0.2, 0.3],
	"watch": [0.0, 0.0, 0.1, 0.2],
	"stand": [0.0, 0.2, 0.3, 0.2],
}
## Walking pace, how long it sits, how long it stands at the fire, the
## pause between things - by tier.
const PACE := [0.7, 0.75, 0.85, 1.0]
const SIT_TIME := [Vector2(60, 90), Vector2(40, 70), Vector2(30, 50), Vector2(25, 40)]
const FIRE_TIME := [Vector2(25, 40), Vector2(25, 40), Vector2(20, 35), Vector2(18, 30)]
const REST_TIME := [Vector2(1, 2), Vector2(4, 8), Vector2(4, 8), Vector2(3, 6)]
## How long a nap's sleep lasts, by tier.
const NAP_TIME := [Vector2(30, 50), Vector2(25, 40), Vector2(20, 30), Vector2(15, 25)]
## The longest a wave goes on (s; Mixamo's are long).
const WAVE_TIME := 2.6
## Room it wants round it to stand about in - arms out, a stretch (m past
## a thing's edge). User report:
## leant on the drum, then stretching where it stood, its arms went into
## the drum; so somewhere tight (by the drum, the crate, a log) it steps out
## first (_step_clear()) - far enough that a long tail, turned to the
## camera, is clear too.
const ROOM := 0.4

var stage: CampStage
var rig: CharacterRig
var pivot: Node3D
var paused := false
## Sat on a log (stands up first, whatever comes next).
var seated := false
## Lying or sat on the ground: the clip that gets it up ("" standing).
var down := ""
## Doing a set piece (depart, come_home): no choosing.
var busy := ""
var activity := ""
## Something bought from the merchant to have (treat()): "tea", "food".
var treat_due := ""

var _plan: Array = []
var _step := {}
var _path: Array = []
var _t := 0.0
var _len := 0.0
var _fired := false
var _yaw_to := 0.0
var _rest := 2.0
var _pace := 1.0
var _rng := RandomNumberGenerator.new()
var _lamp_light: OmniLight3D


func _ready() -> void:
	_rng.randomize()
	pivot = stage.character_pivot
	rig = stage.character
	rig.auto_idle = false
	# Worn out, it's found sitting by the fire.
	if tier() <= 1:
		sit_now()
	if not Profile.snack_had.is_connected(treat):
		Profile.snack_had.connect(treat)


## How it feels: 3 busy, 2 tired, 1 worn, 0 spent (Profile.spirit).
static func tier() -> int:
	var s := Profile.spirit
	return 3 if s >= 70.0 else (2 if s >= 50.0 else (1 if s >= 30.0 else 0))


## Seated on the first log at once (no walking there).
func sit_now() -> void:
	var seat: Dictionary = stage.spots.seat_0
	pivot.position = seat.at
	pivot.rotation.y = _yaw_of(seat.face - seat.at)
	seated = true
	down = ""
	_play("Sitting_Idle", 0.0)
	_plan.clear()
	_step = {}


## Another character took over (CampStage.set_character, the fire tapped):
## it carries on from where this one was - sat, still sat; standing, a
## moment's rest before what's next.
func restart() -> void:
	_plan.clear()
	_step = {}
	var lying: String = {"LayToIdle": "Sleep_B", "Ground_Stand": "Ground_Sit"}.get(down, "")
	_play("Sitting_Idle" if seated else (lying if lying != "" else _idle()), 0.0)
	_rest = 1.0


## A page over the camp: it holds still (and costs nothing) till it closes.
## Back from the merchant's with his tea or food (treat()), it sees to that
## first.
func hold(on: bool) -> void:
	paused = on
	if rig != null and rig.anim != null:
		rig.anim.speed_scale = 0.0 if on else (_pace if _step.get("do", "") == "walk" else 1.0)
	if not on and treat_due != "" and busy == "":
		# (what it was about let go - the sitting or the standing about - or
		# finished first if it's on its way somewhere)
		_plan.clear()
		if _step.get("do", "") in ["loop", "wait", "hold"]:
			_step = {}
			if not seated and down == "":
				_play(_idle(), 0.3)
		_rest = 0.4


## The merchant's tea or food bought (Profile.snack_had - had there and
## then): tea, a cup of it sat on the log; food, a bite at the fire.
func treat(key: String) -> void:
	treat_due = "tea" if key == "tea" else "food"


## A step out to where there's room (ROOM) if it's somewhere tight - by the
## drum it leant on, the crate, a log - else nothing.
func _step_clear() -> Array:
	var here := pivot.position
	if stage.roomy(here, ROOM):
		return []
	# (the nearest ring of places with room; of those, the one furthest from
	# anything - not hugging the end of a log)
	for r in [0.35, 0.55, 0.8, 1.1, 1.5]:
		var best := Vector3.INF
		var best_room := -INF
		for k in 16:
			var a := k * TAU / 16.0
			var p: Vector3 = here + Vector3(cos(a), 0.0, sin(a)) * float(r)
			var room := stage.clearance(p)
			if stage.roomy(p, ROOM) and room > best_room:
				best = p
				best_room = room
		if best != Vector3.INF:
			return [{"do": "walk", "to": best}]
	return []


func _process(delta: float) -> void:
	if paused or rig == null or rig.anim == null:
		return
	if _step.is_empty():
		if _plan.is_empty():
			if busy != "":
				var tag := busy
				busy = ""
				plan_done.emit(tag)
				return
			_rest -= delta
			if _rest > 0.0:
				return
			_plan = _choose()
		_next()
		return
	match _step.do:
		"walk":
			_walk(delta)
		"face":
			_face(delta)
		_:
			_timed(delta)


# ---------------------------------------------------------------- doing

func _next() -> void:
	while not _plan.is_empty():
		_step = _plan.pop_front()
		_t = 0.0
		_fired = false
		match _step.do:
			"call":
				(_step.fn as Callable).call()
				_step = {}
				continue
			"walk":
				# A place worked out as it sets off ("spot", e.g. by the
				# merchant wherever he is) or fixed when planned ("to").
				var to: Vector3 = _step.to if _step.has("to") else stage.spots[_step.spot].at
				_path = [to] if _step.get("straight", false) else stage.route(pivot.position, to)
				# Set pieces go briskly (a tap skips them anyway).
				_pace = PACE[tier()] if busy == "" else 1.25
				_play("Walk", 0.25)
				rig.anim.speed_scale = _pace
			"face":
				var look: Vector3 = _step.at if _step.has("at") else stage.spots[_step.spot].face
				# (someone, wherever they are now)
				if _step.has("node") and is_instance_valid(_step.node):
					look = (_step.node as Node3D).global_position
				_yaw_to = _yaw_of(look - pivot.position)
				if not seated and down == "" and rig.anim.current_animation != _idle():
					_play(_idle(), 0.25)
			"play":
				if _step.get("back", false) and rig.anim.has_animation(_step.clip):
					rig.anim.speed_scale = 1.0
					rig.anim.play_backwards(_step.clip, 0.25)
				else:
					_play(_step.clip, 0.25)
				_len = rig.anim.current_animation_length
				if _step.has("time"):
					_len = minf(_len, float(_step.time))
			"loop":
				_play(_step.clip, 0.3)
				_len = float(_step.time)
			"wait":
				if not seated and down == "":
					_play(_idle(), 0.3)
				_len = float(_step.time)
			"hold":
				rig.anim.pause()
				_len = float(_step.time)
		return
	_step = {}
	_rest = _rng.randf_range(REST_TIME[tier()].x, REST_TIME[tier()].y)
	if not seated and down == "" and rig.anim.current_animation != _idle():
		_play(_idle(), 0.3)


## Standing about: worn out, head down (user request), else at ease.
func _idle() -> String:
	return "Sad" if tier() <= 1 and rig.anim.has_animation("Sad") else "Idle"


func _play(clip: String, blend: float) -> void:
	rig.anim.speed_scale = 1.0
	if rig.anim.has_animation(clip):
		rig.anim.play(clip, blend)


func _yaw_of(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


func _walk(delta: float) -> void:
	if _path.is_empty():
		_step = {}
		_next()
		return
	var target: Vector3 = _path[0]
	var to := target - pivot.position
	to.y = 0.0
	var speed := WALK_SPEED * _pace
	if to.length() <= speed * delta + 0.01:
		pivot.position = Vector3(target.x, 0.0, target.z)
		_path.pop_front()
		return
	pivot.rotation.y = lerp_angle(pivot.rotation.y, _yaw_of(to), minf(1.0, delta * TURN_RATE))
	pivot.position += to.normalized() * speed * delta


func _face(delta: float) -> void:
	pivot.rotation.y = lerp_angle(pivot.rotation.y, _yaw_to, minf(1.0, delta * TURN_RATE))
	if absf(angle_difference(pivot.rotation.y, _yaw_to)) < 0.04:
		pivot.rotation.y = _yaw_to
		_step = {}
		_next()


func _timed(delta: float) -> void:
	_t += delta
	if not _fired and _step.has("fn") and _t >= float(_step.get("at", 0.5)) * _len:
		_fired = true
		(_step.fn as Callable).call()
	if _t >= _len:
		_step = {}
		_next()


# ---------------------------------------------------------------- choosing

func _choose() -> Array:
	var t := tier()
	if treat_due != "":
		var what := treat_due
		treat_due = ""
		activity = what
		var had := _activity(what, t)
		if (seated and what != "tea") or down != "":
			had = _get_up() + had
		return had
	var total := 0.0
	var options := []
	for name in WEIGHTS:
		var w: float = WEIGHTS[name][t]
		if name == activity and name != "sit":
			w *= 0.2
		if w > 0.0:
			options.append([name, w])
			total += w
	var roll := _rng.randf() * total
	var pick := "sit"
	for o in options:
		roll -= o[1]
		if roll <= 0.0:
			pick = o[0]
			break
	activity = pick
	var plan := _activity(pick, t)
	if (seated and pick != "sit") or down != "":
		plan = _get_up() + plan
	return plan


func _stand_up() -> Array:
	return [{"do": "play", "clip": "Sitting_Exit"}, {"do": "call", "fn": func(): seated = false}]


## Up off the log or the ground, if it's on one.
func _get_up() -> Array:
	if seated:
		return _stand_up()
	if down != "":
		return _get_up_from(down)
	return []


## Down on the ground (`up`: the clip that gets it up again).
func _lie(up: String) -> Dictionary:
	return {"do": "call", "fn": func(): down = up}


func _go(spot: String) -> Array:
	var s: Dictionary = stage.spots[spot]
	return [{"do": "walk", "to": s.at}, {"do": "face", "at": s.face}]


func _span(v: Vector2) -> float:
	return _rng.randf_range(v.x, v.y)


## The steps of doing `name`, feeling `t`.
func _activity(name: String, t: int) -> Array:
	match name:
		"sit":
			var plan: Array = []
			if not seated:
				plan = _go("seat_%d" % _rng.randi_range(0, CampStage.SEATS.size() - 1))
				plan += [{"do": "play", "clip": "Sitting_Enter"}, {"do": "call", "fn": func(): seated = true}]
			var long := _span(SIT_TIME[t])
			plan.append({"do": "loop", "clip": "Sitting_Idle", "time": long * 0.6})
			# Now and then a lean back while it sits.
			if _rng.randf() < 0.4:
				plan.append({"do": "loop", "clip": "Seat_Rest", "time": long * 0.3})
			plan.append({"do": "loop", "clip": "Sitting_Idle", "time": long * 0.4})
			if t > 0:
				plan += _stand_up()
			return plan
		"nap":
			# A nap in the tent (user request: not just anywhere): in
			# under it, down on its back, a while stirring, asleep, stirring
			# again, up and out.
			return _into_tent() + [_lie("LayToIdle"), {"do": "play", "clip": "Lie_Down"},
				{"do": "loop", "clip": "Lying", "time": _rng.randf_range(3.0, 5.0)},
				{"do": "loop", "clip": "Sleep_B", "time": _span(NAP_TIME[t])},
				{"do": "loop", "clip": "Lying", "time": 3.5}] + _get_up_from("LayToIdle") + _out_of_tent()
		"fire":
			# Stood at the fire looking into it a good while (user request).
			var at := "warm" if _rng.randf() < 0.5 else "fire_%d" % _rng.randi_range(0, 1)
			return _go(at) + [{"do": "loop", "clip": _idle(), "time": _span(FIRE_TIME[t])}]
		"tea":
			# The merchant's tea, sat on the log by the fire.
			var plan: Array = []
			if not seated:
				plan = _go("seat_0") + [{"do": "play", "clip": "Sitting_Enter"}, {"do": "call", "fn": func(): seated = true}]
			return plan + [{"do": "loop", "clip": "Sitting_Idle", "time": 1.5}, {"do": "play", "clip": "Seat_Drink"},
				{"do": "loop", "clip": "Sitting_Idle", "time": _span(SIT_TIME[t]) * 0.5}]
		"food":
			# His food, a bite stood at the fire.
			return _go("warm") + [{"do": "loop", "clip": _idle(), "time": 1.5}, {"do": "play", "clip": "Consume"},
				{"do": "loop", "clip": _idle(), "time": _span(FIRE_TIME[t]) * 0.5}]
		"ground":
			# Sat on the ground by the fire (sitting down: the getting up
			# played backwards).
			return _go("ground") + [_lie("Ground_Stand"), {"do": "play", "clip": "Ground_Stand", "back": true},
				{"do": "loop", "clip": "Ground_Sit", "time": _rng.randf_range(8.0, 14.0) * (1.5 if t <= 1 else 1.0)}] \
				+ _get_up_from("Ground_Stand")
		"look":
			# At the edge of the dark: a look about, or a peek into it from a
			# crouch.
			var edge := "gather_%d" % _rng.randi_range(0, 2)
			return _go(edge) + [{"do": "play", "clip": "Look_Around" if _rng.randf() < 0.6 else "Peek"}]
		"stretch":
			return _step_clear() + [{"do": "play", "clip": "Stretch_Neck" if _rng.randf() < 0.5 else "Stretch_Arms"}]
		"tent":
			return _go("tent") + [{"do": "play", "clip": "Fixing_Kneeling"}]
		"crate":
			return _go("crate") + [{"do": "play", "clip": "Chest_Open"}, {"do": "wait", "time": 0.4},
				{"do": "play", "clip": "Consume"}]
		"trough":
			return _go("trough") + [{"do": "loop", "clip": "Crouch_Idle", "time": _rng.randf_range(4.0, 8.0)}]
		"lean":
			var lean: Dictionary = stage.spots.lean
			var off: Vector3 = (lean.at - lean.face).normalized() * CharacterArt.lean_back(rig.character)
			return [{"do": "walk", "to": lean.at + off}, {"do": "face", "at": lean.face}] \
				+ [{"do": "loop", "clip": "Idle_Rail", "time": _rng.randf_range(5.0, 9.0)}]
		"lake":
			return _go("lake") + [{"do": "loop", "clip": "Idle_FoldArms", "time": _rng.randf_range(5.0, 8.0)}]
		"merchant":
			# A word with the frog merchant (user request): he stops where he
			# is and turns to it; it walks up to him, face to face; he talks
			# back; then he goes on his way.
			var m := stage.merchant
			if m == null:
				return [{"do": "loop", "clip": "Idle_FoldArms", "time": 3.0}]
			# (A wave to him first, from where it is; a wave as he goes.)
			return [{"do": "call", "fn": func():
					m.visit(pivot)
					stage.spots["visit"] = {"at": m.visit_spot(pivot.position), "face": m.global_position}},
				{"do": "face", "spot": "visit"}, {"do": "play", "clip": "Wave_Big", "time": WAVE_TIME},
				{"do": "walk", "spot": "visit"}, {"do": "face", "spot": "visit", "node": m},
				{"do": "call", "fn": func(): m.talk()},
				{"do": "loop", "clip": "Idle_Talking", "time": _rng.randf_range(4.0, 7.0)},
				{"do": "play", "clip": "Yes"}, {"do": "call", "fn": func(): m.release()},
				{"do": "play", "clip": "Wave", "time": WAVE_TIME}]
		"watch":
			# On watch: the lamp lit and held up at the edge of the dark.
			var edge := "gather_%d" % _rng.randi_range(0, 2)
			return _go("lamp") + [_reach(func(): take_lamp(true))] \
				+ _go(edge) + [{"do": "loop", "clip": "Idle_Torch", "time": _rng.randf_range(3.0, 5.0)}] \
				+ _go("lamp") + [_reach(func(): put_lamp(true))]
	# "stand": a while where it is, arms folded - worn out, head down.
	var low: String = ["Sad", "Sad_B"][_rng.randi_range(0, 1)]
	return _step_clear() + [{"do": "loop", "clip": low if t <= 1 else "Idle_FoldArms", "time": _rng.randf_range(3.0, 6.0)}]


## In under the tent: to its mouth, straight in, turned to face out.
func _into_tent() -> Array:
	var bed: Dictionary = stage.spots.bed
	return _go("tent") + [{"do": "walk", "to": bed.at, "straight": true}, {"do": "face", "at": bed.face}]


## Out of it again, to its mouth.
func _out_of_tent() -> Array:
	return [{"do": "walk", "to": stage.spots.tent.at, "straight": true}]


## Getting up (`clip`), down no longer.
func _get_up_from(clip: String) -> Array:
	return [{"do": "play", "clip": clip}, {"do": "call", "fn": func(): down = ""}]


## One of [[name, weight], ...] at random by weight.
func _weighted(options: Array) -> String:
	var total := 0.0
	for o in options:
		total += float(o[1])
	var roll := _rng.randf() * total
	for o in options:
		roll -= float(o[1])
		if roll <= 0.0:
			return o[0]
	return options[-1][0]


# ---------------------------------------------------------------- set pieces

## Setting out (user request): the lamp taken from the drum - it lights -
## and off toward the water; plan_done("depart") as soon as it's in hand,
## the game fading in while it walks. (Shouldering the backpack and taking
## the rod first, as asked, would need a clip that lifts a pack onto the
## back - the animation libraries have none, and swapping it from hand to
## back would jump; so, as the user allowed, the lamp and away.)
func depart() -> void:
	busy = "depart"
	_plan.clear()
	_step = {}
	rig.equip("hand_r", null)
	rig.equip("back", null)
	var plan: Array = _get_up()
	plan += _go("lamp") + [_reach(func(): take_lamp(true))]
	plan += [{"do": "call", "fn": func(): plan_done.emit("depart")}, {"do": "walk", "to": stage.spots.stone.at}]
	_plan = plan
	_next()


## Home again (user request): "escaped" - out of the 渡石's light, the lamp
## put back on the drum, a cheer (both arms up, in high spirits, else a
## fist pumped), then to the fire; "lost" - waking up by the fire, and a
## sigh.
func come_home(how: String) -> void:
	_plan.clear()
	_step = {}
	seated = false
	down = ""
	if how == "lost":
		busy = "wake"
		var s: Dictionary = stage.spots.bed
		pivot.position = s.at
		pivot.rotation.y = _yaw_of(s.face - s.at)
		# Lying still in the tent a moment (the clip held at its start), then
		# up, out, and a sigh.
		_play("LayToIdle", 0.0)
		rig.anim.seek(0.0, true)
		_plan = [{"do": "hold", "time": 1.2}, {"do": "play", "clip": "LayToIdle"}] + _out_of_tent() \
			+ [{"do": "face", "at": CampStage.FIRE_AT}, {"do": "play", "clip": "Disappointed"}]
		_next()
		return
	busy = "home"
	take_lamp()
	var s2: Dictionary = stage.spots.stone_in
	pivot.position = s2.at
	pivot.rotation.y = CampStage.STONE_YAW
	stage.stone_flare()
	_plan = [{"do": "walk", "to": stage.spots.stone.at}]
	_plan += _go("lamp") + [_reach(func(): put_lamp(true))]
	_plan.append({"do": "play", "clip": "Victory" if tier() == 3 else "Fist_Pump"})
	# Then to the fire.
	_plan += _go("warm")
	_next()


## Skips a set piece to its end (a tap): gone, or home with the lamp put
## away.
func finish() -> void:
	if busy == "":
		return
	var tag := busy
	busy = ""
	_plan.clear()
	_step = {}
	down = ""
	if tag == "depart":
		plan_done.emit(tag)
		return
	put_lamp()
	var warm: Dictionary = stage.spots.warm
	pivot.position = warm.at
	pivot.rotation.y = _yaw_of(warm.face - warm.at)
	_play("Idle", 0.2)
	plan_done.emit(tag)


## Reaching out to the lamp on the drum (the hand gets to its bail just as
## `fn` - taking it, putting it back - is called).
func _reach(fn: Callable) -> Dictionary:
	return {"do": "play", "clip": CharacterRig.REACH_CLIP, "at": CharacterRig.REACH_AT, "fn": fn}


## The lamp in hand, lit; `from_drum`: lifted off the drum (eased from it
## into the hand), else just there (home through the stone).
func take_lamp(from_drum := false) -> void:
	var place: Variant = stage.drum_lamp_place() if from_drum else null
	stage.lamp_on_drum(false)
	rig.equip_lamp(place)
	# Lit, in the hand.
	var held: Node3D = rig.attachments.hand_l.get_child(0) if rig.attachments.hand_l.get_child_count() > 0 else null
	if held != null:
		_lamp_light = OmniLight3D.new()
		_lamp_light.name = "LampLight"
		_lamp_light.light_color = Color(1.0, 0.72, 0.38)
		_lamp_light.light_energy = 1.4
		_lamp_light.omni_range = 4.5
		_lamp_light.position = Vector3(0, 0.15, 0)
		held.add_child(_lamp_light)
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.025
		fm.height = 0.05
		flame.mesh = fm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.45)
		flame.material_override = mat
		flame.position = Vector3(0, 0.13, 0)
		held.add_child(flame)


## The lamp back on the drum (`eased`: set down from the hand).
func put_lamp(eased := false) -> void:
	var att: BoneAttachment3D = rig.attachments.get("hand_l")
	var held: Variant = null
	if eased and att != null and att.get_child_count() > 0:
		held = (att.get_child(0) as Node3D).global_transform
	rig.equip("hand_l", null)
	_lamp_light = null
	stage.lamp_on_drum(true, held)
