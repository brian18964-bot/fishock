class_name CampLife
extends Node

## User request (Camp v2): the character lives at the camp on its own -
## sits by the fire, mends the tent, opens the crate and has a bite,
## crouches over the fish, leans on the drum looking at the lake, has a
## word with the merchant, warms itself, keeps watch with the lamp held up
## at the edge of the dark, dances when it's in high spirits - less and
## less of it as its spirit (Profile.spirit) runs down. (Chopping wood and
## carrying it, gathering sticks: dropped - user request, the hands didn't
## close on what they held.)
##   70-100  busy    all of it (dancing only over 90)
##   50-69   tired   no mending; slower; sits more
##   30-49   worn    mostly sits, a long while
##   0-29    spent   only sits
## A tap (tap()): it waves - nods, shakes its head as it wearies; seated,
## it talks. And the set pieces: setting out (depart(): the lamp from the
## drum - it lights - and off, the game fading in as it goes), coming home
## through the 渡石 (come_home("escaped")) and waking by the fire after a
## run lost (come_home("lost")).
##
## A plan is a list of steps, each a Dictionary:
##   {do: "walk", to}            walk there round things (CampStage.route)
##   {do: "face", at}            turn to look at a point
##   {do: "play", clip, at, fn}  a clip through once (fn called `at` of
##                               the way through)
##   {do: "loop", clip, time}    a looping clip a while
##   {do: "wait", time}          stand a moment
##   {do: "hold", time}          keep still, the clip paused where it is
##   {do: "call", fn}            do something (pick up, put down...)

signal plan_done(tag: String)

## The Walk clip's own pace (m/s).
const WALK_SPEED := 0.8
const TURN_RATE := 7.0
## How often it does each thing, by how it feels: [spent, worn, tired, busy].
const WEIGHTS := {
	"sit": [1.0, 6.0, 3.0, 2.0],
	"tent": [0.0, 0.0, 0.0, 0.7],
	"crate": [0.0, 0.0, 0.5, 0.9],
	"trough": [0.0, 0.6, 1.0, 1.0],
	"lean": [0.0, 0.0, 1.2, 0.8],
	"lake": [0.0, 0.0, 1.0, 0.8],
	"merchant": [0.0, 0.0, 0.5, 0.7],
	"warm": [0.0, 0.6, 1.2, 1.0],
	"dance": [0.0, 0.0, 0.0, 1.2],
	"watch": [0.0, 0.0, 0.3, 0.6],
	"stand": [0.0, 0.4, 1.0, 0.5],
}
## Walking pace, how long it sits, the pause between things - by tier.
const PACE := [0.7, 0.75, 0.85, 1.0]
const SIT_TIME := [Vector2(60, 90), Vector2(25, 45), Vector2(12, 20), Vector2(8, 14)]
const REST_TIME := [Vector2(0.5, 1), Vector2(3, 6), Vector2(2, 4), Vector2(1, 3)]

var stage: CampStage
var rig: CharacterRig
var pivot: Node3D
var paused := false
## Sat on a log (stands up first, whatever comes next).
var seated := false
## Doing a set piece (depart, come_home): no taps, no choosing.
var busy := ""
var activity := ""

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
	_play("Sitting_Idle", 0.0)
	_plan.clear()
	_step = {}


## A page over the camp: it holds still (and costs nothing) till it closes.
func hold(on: bool) -> void:
	paused = on
	if rig != null and rig.anim != null:
		rig.anim.speed_scale = 0.0 if on else (_pace if _step.get("do", "") == "walk" else 1.0)


## A tap on it: a wave (a nod, a shake of the head as it wearies); seated,
## a few words. Then on with what it was doing.
func tap() -> void:
	if busy != "" or paused:
		return
	var react: Array = []
	if seated:
		react = [{"do": "loop", "clip": "Sitting_Talking", "time": 2.9}]
		if not _step.is_empty() and _step.do == "loop":
			# Back to sitting after.
			react.append(_step.duplicate())
	else:
		var clip: String = ["Idle_No", "Idle_No", "Yes", "Interact"][tier()]
		react = [{"do": "face", "at": stage.camera.global_position}, {"do": "play", "clip": clip}]
		if not _step.is_empty() and _step.do in ["walk", "face", "play", "loop"]:
			react.append(_step.duplicate())
	_plan = react + _plan
	_step = {}
	_next()


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
				_path = stage.route(pivot.position, _step.to)
				# Set pieces go briskly (a tap skips them anyway).
				_pace = PACE[tier()] if busy == "" else 1.25
				_play("Walk", 0.25)
				rig.anim.speed_scale = _pace
			"face":
				_yaw_to = _yaw_of(_step.at - pivot.position)
				if not seated and rig.anim.current_animation != "Idle":
					_play("Idle", 0.25)
			"play":
				_play(_step.clip, 0.25)
				_len = rig.anim.current_animation_length
			"loop":
				_play(_step.clip, 0.3)
				_len = float(_step.time)
			"wait":
				if not seated:
					_play("Idle", 0.3)
				_len = float(_step.time)
			"hold":
				rig.anim.pause()
				_len = float(_step.time)
		return
	_step = {}
	_rest = _rng.randf_range(REST_TIME[tier()].x, REST_TIME[tier()].y)
	if not seated and rig.anim.current_animation != "Idle":
		_play("Idle", 0.3)


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
	var total := 0.0
	var options := []
	for name in WEIGHTS:
		var w: float = WEIGHTS[name][t]
		if name == "dance" and Profile.spirit < 90.0:
			w = 0.0
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
	if seated and pick != "sit":
		plan = _stand_up() + plan
	return plan


func _stand_up() -> Array:
	return [{"do": "play", "clip": "Sitting_Exit"}, {"do": "call", "fn": func(): seated = false}]


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
			if t >= 1 and _rng.randf() < 0.5:
				plan.append({"do": "loop", "clip": "Sitting_Talking", "time": 2.9})
			plan.append({"do": "loop", "clip": "Sitting_Idle", "time": long * 0.4})
			if t > 0:
				plan += _stand_up()
			return plan
		"tent":
			return _go("tent") + [{"do": "play", "clip": "Fixing_Kneeling"}]
		"crate":
			return _go("crate") + [{"do": "play", "clip": "Chest_Open"}, {"do": "wait", "time": 0.4},
				{"do": "play", "clip": "Consume"}]
		"trough":
			return _go("trough") + [{"do": "loop", "clip": "Crouch_Idle", "time": _rng.randf_range(4.0, 8.0)}]
		"lean":
			return _go("lean") + [{"do": "loop", "clip": "Idle_Rail", "time": _rng.randf_range(5.0, 9.0)}]
		"lake":
			return _go("lake") + [{"do": "loop", "clip": "Idle_FoldArms", "time": _rng.randf_range(5.0, 8.0)}]
		"merchant":
			return _go("merchant") + [{"do": "loop", "clip": "Idle_Talking", "time": _rng.randf_range(4.0, 7.0)},
				{"do": "play", "clip": "Yes"}]
		"warm":
			var plan := _go("warm") + [{"do": "loop", "clip": "Idle", "time": _rng.randf_range(3.0, 5.0)}]
			if _rng.randf() < 0.5:
				plan.append({"do": "play", "clip": "Consume"})
			return plan
		"dance":
			return _go("dance") + [{"do": "loop", "clip": "Dance", "time": _rng.randf_range(3.0, 5.0)}]
		"watch":
			# On watch: the lamp lit and held up at the edge of the dark.
			var edge := "gather_%d" % _rng.randi_range(0, 2)
			return _go("lamp") + [_reach(func(): take_lamp(true))] \
				+ _go(edge) + [{"do": "loop", "clip": "Idle_Torch", "time": _rng.randf_range(3.0, 5.0)}] \
				+ _go("lamp") + [_reach(func(): put_lamp(true))]
	# "stand": a while where it is, arms folded.
	return [{"do": "loop", "clip": "Idle_FoldArms", "time": _rng.randf_range(3.0, 6.0)}]


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
	var plan: Array = _stand_up() if seated else []
	plan += _go("lamp") + [_reach(func(): take_lamp(true))]
	plan += [{"do": "call", "fn": func(): plan_done.emit("depart")}, {"do": "walk", "to": stage.spots.stone.at}]
	_plan = plan
	_next()


## Home again (user request): "escaped" - out of the 渡石's light, the lamp
## put back on the drum, then to the fire; "lost" -
## waking up by the fire.
func come_home(how: String) -> void:
	_plan.clear()
	_step = {}
	seated = false
	if how == "lost":
		busy = "wake"
		var s: Dictionary = stage.spots.wake
		pivot.position = s.at
		pivot.rotation.y = _yaw_of(s.face - s.at)
		# Lying still a moment (the clip held at its start), then up.
		_play("LayToIdle", 0.0)
		rig.anim.seek(0.0, true)
		_plan = [{"do": "hold", "time": 1.2}, {"do": "play", "clip": "LayToIdle"}, {"do": "play", "clip": "Idle_No"}]
		_next()
		return
	busy = "home"
	take_lamp()
	var s2: Dictionary = stage.spots.stone_in
	pivot.position = s2.at
	pivot.rotation.y = 0.0
	stage.stone_flare()
	_plan = [{"do": "walk", "to": stage.spots.stone.at}]
	_plan += _go("lamp") + [_reach(func(): put_lamp(true))]
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
