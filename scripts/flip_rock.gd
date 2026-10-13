class_name FlipRock
extends Node2D

## User request: no more roadside junk pile - instead 8-10 of each run's
## rocks are small ones the player can turn over (a tap, see
## Player._turn_rock()) for a chance at bait - or a black spider. Turned
## over, the rock tips off to the side (user request: only just - a heave,
## not a throw), baring the damp patch where it lay; each one can be
## turned once a run. User decision (3D): RunView3D shows the stone, sized
## to its solid base here (_roller: where it's rolled to, its tilt).

const SIZE := 0.42
const FIND_CHANCE := 0.6
## User request: sometimes a black spider is under it instead (Critter).
const SPIDER_CHANCE := 0.18
const BAIT_FLAVORS := ["蚯蚓", "蟲子", "青蛙"]
## How close the player has to be to turn it.
const REACH := 26.0
## How far it shifts (px; at least ROLL_BARE of the patch's radius, so the
## patch shows), how far it leans over (rad), how long it takes.
const ROLL_DISTANCE := Vector2(9.0, 13.0)
const ROLL_BARE := 1.4
const ROLL_LEAN := Vector2(0.25, 0.5)
const ROLL_TIME := 0.7

## Map theme (map_generator.gd): Obstacle.KINDS indices.
var variant_pool: Array = []
var active := true
## The stone's base (px radius) and the model it's shown as.
var radius := 8.0
var model := "rock_medium_2"
## How far over it's turned (0 - 1).
var turned := 0.0

var _roller: Node2D
var _spin := 0.0


func _ready() -> void:
	add_to_group("solids")
	var pool := variant_pool.filter(func(v): return v is int and v >= 0 and v < Obstacle.KINDS.size())
	var kind: Dictionary = Obstacle.KINDS[pool.pick_random() if not pool.is_empty() else randi() % Obstacle.KINDS.size()]
	model = kind.model
	radius = maxf(minf(kind.base.x, kind.base.y) * 0.5 * SIZE, 5.0)
	_roller = Node2D.new()
	_roller.name = "Roller"
	add_child(_roller)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	_roller.add_child(body)

	var zone := Area2D.new()
	var zone_shape := CollisionShape2D.new()
	var reach := CircleShape2D.new()
	reach.radius = REACH
	zone_shape.shape = reach
	zone.add_child(zone_shape)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)


## Where its name/button goes (ActionPrompt).
func prompt_anchor() -> Vector2:
	return global_position + Vector2(0, -22)


## One completed turn: it rolls away from `from` (the player) and says
## whether there was bait under it.
func turn_over(from: Vector2) -> Dictionary:
	active = false
	Sfx.play_at("rock_flip", global_position, -2.0)
	var away := global_position - from
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var dir := away.normalized().rotated(randf_range(-0.6, 0.6))
	var offset := dir * maxf(randf_range(ROLL_DISTANCE.x, ROLL_DISTANCE.y), radius * ROLL_BARE)
	_spin = signf(dir.x if absf(dir.x) > 0.1 else 1.0) * randf_range(ROLL_LEAN.x, ROLL_LEAN.y)
	var tween := create_tween()
	tween.tween_method(_roll.bind(offset), 0.0, 1.0, ROLL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if randf() < SPIDER_CHANCE:
		return {"found": false, "spider": true}
	if randf() < FIND_CHANCE:
		return {"found": true, "flavor": BAIT_FLAVORS[randi() % BAIT_FLAVORS.size()]}
	return {"found": false}


func _roll(t: float, offset: Vector2) -> void:
	_roller.position = offset * t
	_roller.rotation = _spin * t
	turned = t


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_rock"):
		body.set_in_rock(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_rock"):
		body.set_in_rock(false, self)


func solids() -> Array:
	return [[_roller.global_position if _roller != null else global_position, Vector2(radius, radius)]]
