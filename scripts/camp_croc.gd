class_name CampCroc
extends Node3D

## User request: Mr. Croc (CrocQuests) on the camp's lakeside - our crocodile in an outfit of his own
## (CrocLook: not the travellers' white knit, a straw hat) - ambling along the shore, stopping a
## while to look out over the water or back at the camp, saying a short line now and then
## (`line`, shown over his head by TitleScreen: a few words as he turns up - "這裡挺溫暖的……" - then
## one every so often). What he wants and what he pays is only told when he's talked to
## (TitleScreen._croc_talk); over his head a list's sign says there's something to talk about
## (TitleScreen's mark: an errand on offer, or one done to hand in).
##
## Tapped, the traveller comes over (CampLife "croc"): he stops, turns to them (visit), talks (talk)
## and stays till the talk's closed (release) - or VISIT_TIMEOUT.

## (how far up the shore he wanders: the lake's edge from x SHORE_X.x to SHORE_X.y, this far in from
## the water - clear of the dock and the drums)
const SHORE_X := Vector2(-3.6, 0.6)
const SHORE_IN := 0.45
const SHORE_POINTS := 6
## (his stroll: this share of his legs' own walking pace; how long he stays at a place, s)
const STROLL := 0.7
const STAY := Vector2(5.0, 11.0)
## His lines: the first as he turns up (FIRST_AT s in), then one every LINE_EVERY s, each held
## LINE_HOLD s (eased in and out over LINE_FADE).
const FIRST_AT := 1.5
const LINE_EVERY := Vector2(14.0, 26.0)
const LINE_HOLD := 4.5
const LINE_FADE := 0.4
const VISIT_TIMEOUT := 40.0
## (all of these are mine for now - the user can change any of them)
const OPENING := ["這裡挺溫暖的……", "喔，火燒得正旺。", "今晚的水，聞起來不錯。", "嗯……又是個好夜晚。"]
const IDLE_LINES := ["火光映在水面上，真好看。", "年輕時，我能在這湖裡游上一整夜。", "嗯……有魚在跳。",
	"夜裡的東西可不講道理，別太晚回來。", "腳底的泥巴軟軟的，舒服。", "那隻青蛙又在跟人討價還價了。",
	"月亮今天特別亮。", "年紀大了，水還是一樣冷。", "你又帶著竿子出門啦？", "風從湖那邊吹過來了。",
	"這湖裡的魚，一天比一天精。", "呼……打個盹也不錯。"]
## (with an errand on offer - not saying what; with fish to hand him - noticing)
const OFFER_LINES := ["嗯……有件事，想找個人幫忙。", "要是有空，過來聊兩句吧。"]
const DONE_LINES := ["喔？看你的樣子，事情辦好了？", "過來過來，讓我瞧瞧。"]

var stage: CampStage
var rig: CharacterRig
## What he's saying now ("" nothing), and how far it's shown (0..1).
var line := ""
var line_alpha := 0.0
var visitor: Node3D
var _shore: Array = []
var _goal := -1
var _at := 0
var _wait := 0.0
var _say_in := FIRST_AT
var _line_left := 0.0
var _first := true
var _visit_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in SHORE_POINTS:
		var x := lerpf(SHORE_X.x, SHORE_X.y, float(i) / float(SHORE_POINTS - 1))
		_shore.append(shore_point(x))
	_at = _rng.randi() % _shore.size()
	position = _shore[_at]
	rotation.y = _rng.randf_range(-0.6, 0.9)
	rig = CharacterRig.new()
	rig.fixed = CrocQuests.ID
	rig.hold_gear = false
	add_child(rig)
	CrocLook.dress(rig)
	_idle()
	_wait = _rng.randf_range(STAY.x * 0.6, STAY.y)


## The shore at `x`: the lake's edge there, SHORE_IN in from the water.
static func shore_point(x: float) -> Vector3:
	var r := CampStage.LAKE_RADIUS
	var z := CampStage.LAKE_CENTER.z + sqrt(maxf(r * r - x * x, 0.0)) + SHORE_IN
	return Vector3(x, 0.0, z)


## Where his name and the list's sign go (world): over his head.
func head_point() -> Vector3:
	var bone := rig.skeleton.find_bone("Head") if rig != null and rig.skeleton != null else -1
	if bone < 0:
		return global_position + Vector3(0, 1.7, 0)
	return (rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(bone)).origin


## Someone coming over: he stops where he is and turns to them.
func visit(who: Node3D) -> void:
	visitor = who
	_visit_time = 0.0
	_goal = -1
	_idle()


## Where a visitor stands to talk to him: in front of him, on their side (the camp's).
func visit_spot(from: Vector3) -> Vector3:
	var d := from - global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.BACK
	# (never out over the water: toward the camp if they'd stand lakeward of him)
	if d.z < 0.2:
		d = (d + Vector3(0, 0, 0.8)).normalized()
	var p := global_position + d * 1.15
	return Vector3(p.x, 0.0, p.z)


func talk() -> void:
	line = ""
	line_alpha = 0.0
	_play("Idle_Talking")


## The talk over: a moment, then on along the shore.
func release() -> void:
	visitor = null
	_wait = _rng.randf_range(2.5, 5.0)
	_idle()


func _process(delta: float) -> void:
	_lines(delta)
	if stage != null and stage.hotspots.has("croc"):
		for part in stage.hotspots.croc.parts:
			part[1] = global_position + Vector3(0, 0.9, 0)
	if visitor != null:
		_visit_time += delta
		if not is_instance_valid(visitor) or _visit_time > VISIT_TIMEOUT:
			release()
			return
		_turn_to(visitor.global_position, delta, 5.0)
		return
	if _goal < 0:
		_wait -= delta
		if _wait <= 0.0:
			# (on to another place along the shore - never the one he's at)
			var next := _rng.randi() % (_shore.size() - 1)
			_goal = next if next < _at else next + 1
			_play("Walk")
		return
	var goal: Vector3 = _shore[_goal]
	var way := goal - position
	way.y = 0.0
	var speed := CharacterArt.walk_pace(CrocQuests.ID, 0.8) * STROLL
	if way.length() <= speed * delta + 0.01:
		position = goal
		_at = _goal
		_goal = -1
		_wait = _rng.randf_range(STAY.x, STAY.y)
		_idle()
		return
	rotation.y = lerp_angle(rotation.y, atan2(way.x, way.z), minf(delta * 5.0, 1.0))
	position += way.normalized() * speed * delta


func _turn_to(at: Vector3, delta: float, rate: float) -> void:
	var d := at - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(delta * rate, 1.0))


## His lines: one on, held, eased out; the next after a while (none while he's being talked to).
func _lines(delta: float) -> void:
	if _line_left > 0.0:
		_line_left -= delta
		var shown := LINE_HOLD - _line_left
		line_alpha = clampf(minf(shown, _line_left) / LINE_FADE, 0.0, 1.0)
		if _line_left <= 0.0:
			line = ""
			line_alpha = 0.0
		return
	if visitor != null:
		return
	_say_in -= delta
	if _say_in <= 0.0:
		say(next_line())


## Says `text` over his head (LINE_HOLD s).
func say(text: String) -> void:
	line = text
	_line_left = LINE_HOLD
	_say_in = _rng.randf_range(LINE_EVERY.x, LINE_EVERY.y)


## What he says next: an opening line first; then, now and then, about the errand (never what it is).
func next_line() -> String:
	if _first:
		_first = false
		return OPENING[_rng.randi() % OPENING.size()]
	if CrocQuests.ready_to_hand_in() and _rng.randf() < 0.6:
		return DONE_LINES[_rng.randi() % DONE_LINES.size()]
	if not CrocQuests.offered().is_empty() and _rng.randf() < 0.35:
		return OFFER_LINES[_rng.randi() % OFFER_LINES.size()]
	return IDLE_LINES[_rng.randi() % IDLE_LINES.size()]


func _idle() -> void:
	if rig != null and rig.anim != null:
		rig.anim.speed_scale = 1.0
		rig.play_idle()


func _play(clip: String) -> void:
	if rig == null or rig.anim == null or not rig.anim.has_animation(clip):
		return
	rig.anim.speed_scale = STROLL if clip == "Walk" else 1.0
	if rig.anim.current_animation != clip:
		rig.anim.play(clip, 0.3)
