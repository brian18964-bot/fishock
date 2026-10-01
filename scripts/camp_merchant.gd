class_name CampMerchant
extends Node3D

## The frog merchant (assets/models/camp/frog_merchant.glb: the sculpt
## rigged and animated by tools/rig_frog.py - Idle, Walk, Talk) pottering
## about his stall (user request: he wanders near the shop, now and then
## inside it): from place to place along `links`, walking, then a while
## standing, looking at `look`.
##   places: name -> [where (stage), what he looks at there]
##   links:  name -> the places he can go on to from there
## And visited (CampLife "merchant"; user request: the two of them meet):
## visit() stops him where he is, turned to the visitor; talk() as they
## talk; release() and he goes on his way.

const MODEL := "res://assets/models/camp/frog_merchant.glb"
const SPEED := 0.32
## Walk's own pace (full size): the ground a cycle (a second) covers.
const WALK_PACE := 0.55
const STAY := Vector2(4.0, 10.0)
## A visit that never comes to talk (the visitor called away) ends itself.
const VISIT_TIMEOUT := 25.0

var places := {}
var links := {}
var at := ""
## Being visited: the visitor (it faces it), or null.
var visitor: Node3D

var _body: MeshInstance3D
var _anim: AnimationPlayer
var _to := ""
var _wait := 0.0
var _visit_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 23
	if ResourceLoader.exists(MODEL):
		var model: Node3D = (load(MODEL) as PackedScene).instantiate()
		add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			_body = mi
			_body.material_override = CampModel.material("frog_merchant")
			break
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_anim = players[0]
			for clip in ["Idle", "Walk", "Talk"]:
				if _anim.has_animation(clip):
					_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if at == "" and not places.is_empty():
		at = places.keys()[0]
	if at != "":
		position = places[at][0]
		rotation.y = _yaw_to(places[at][1])
	_wait = _rng.randf_range(STAY.x * 0.5, STAY.y)
	_play("Idle")


## The model (for the shop's hotspot).
func body() -> MeshInstance3D:
	return _body


## Someone coming over: he stops where he is and turns to them.
func visit(who: Node3D) -> void:
	visitor = who
	_visit_time = 0.0
	if _to != "":
		# Stopped on the way: wherever he is now counts as where he was going.
		at = _to
		_to = ""
	_play("Idle")


## Where a visitor stands to talk to him: in front of him, on their side -
## or, him inside the stall, at its counter.
func visit_spot(from: Vector3) -> Vector3:
	if at == "inside" and places.has("counter"):
		return places.counter[0]
	var d := from - global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.BACK
	var p := global_position + d * 1.1
	return Vector3(p.x, 0.0, p.z)


func talk() -> void:
	_play("Talk")


## The visit over: a moment, then on his way.
func release() -> void:
	visitor = null
	_wait = _rng.randf_range(2.0, 4.0)
	_play("Idle")


func _process(delta: float) -> void:
	if visitor != null:
		_visit_time += delta
		if not is_instance_valid(visitor) or _visit_time > VISIT_TIMEOUT:
			release()
			return
		var to := _yaw_to(visitor.global_position)
		rotation.y = lerp_angle(rotation.y, to, minf(delta * 5.0, 1.0))
		return
	if _to == "":
		if at != "":
			rotation.y = lerp_angle(rotation.y, _yaw_to(places[at][1]), minf(delta * 3.0, 1.0))
		_wait -= delta
		if _wait <= 0.0 and links.has(at):
			var next: Array = links[at]
			_to = next[_rng.randi() % next.size()]
			_play("Walk")
		return
	var goal: Vector3 = places[_to][0]
	var way := goal - position
	# Up onto the stall's floor (or down) as he goes.
	var rise := way.y
	way.y = 0.0
	if way.length() < 0.02:
		position = goal
		at = _to
		_to = ""
		_wait = _rng.randf_range(STAY.x, STAY.y)
		_play("Idle")
		return
	var dir := way.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 6.0, 1.0))
	var stride := minf(SPEED * delta, way.length())
	position += dir * stride
	position.y += rise * stride / way.length()


func _play(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation != clip:
		_anim.play(clip, 0.3)
	# The legs keep pace with the ground covered (his size counted).
	_anim.speed_scale = SPEED / (WALK_PACE * scale.x) if clip == "Walk" else 1.0


func _yaw_to(target: Vector3) -> float:
	var d := target - global_position
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.01 else rotation.y
