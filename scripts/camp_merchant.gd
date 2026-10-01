class_name CampMerchant
extends Node3D

## The frog merchant (CampModel "frog_merchant", a model with no skeleton)
## pottering about his stall (user request: he wanders near the shop, now
## and then inside it): from place to place along `links`, a waddle as he
## goes - rocking side to side, a little bob at each step - then a while
## standing, looking at `look`.
##   places: name -> [where (stage), what he looks at there]
##   links:  name -> the places he can go on to from there

const SPEED := 0.32
const STAY := Vector2(4.0, 10.0)

var places := {}
var links := {}
var at := ""

var _body: MeshInstance3D
var _to := ""
var _wait := 0.0
var _step := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 23
	_body = CampModel.make("frog_merchant")
	if _body != null:
		add_child(_body)
	if at == "" and not places.is_empty():
		at = places.keys()[0]
	if at != "":
		position = places[at][0]
		rotation.y = _yaw_to(places[at][1])
	_wait = _rng.randf_range(STAY.x * 0.5, STAY.y)


## The model (for the shop's hotspot).
func body() -> MeshInstance3D:
	return _body


func _process(delta: float) -> void:
	if _to == "":
		_settle(delta)
		_wait -= delta
		if _wait <= 0.0 and links.has(at):
			var next: Array = links[at]
			_to = next[_rng.randi() % next.size()]
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
		return
	var dir := way.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 6.0, 1.0))
	var stride := minf(SPEED * delta, way.length())
	position += dir * stride
	position.y += rise * stride / way.length()
	# The waddle.
	_step += delta * 9.0
	if _body != null:
		_body.rotation.z = sin(_step) * 0.09
		_body.position.y = absf(sin(_step)) * 0.03


## Standing: turned to what he looks at, the waddle dying away.
func _settle(delta: float) -> void:
	if at != "":
		rotation.y = lerp_angle(rotation.y, _yaw_to(places[at][1]), minf(delta * 3.0, 1.0))
	if _body != null:
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, minf(delta * 8.0, 1.0))
		_body.position.y = lerpf(_body.position.y, 0.0, minf(delta * 8.0, 1.0))


func _yaw_to(target: Vector3) -> float:
	var d := target - position
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.01 else rotation.y
