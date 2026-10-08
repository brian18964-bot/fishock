class_name FlipRock
extends Node2D

## User request: no more roadside junk pile - instead 8-10 of each run's
## rocks are small ones the player can turn over (a tap, see
## Player._turn_rock()) for a chance at bait - or a black spider. Turned over, the rock
## tips off to the side and leaves a bare, damp patch where it lay (user
## request: only just - a heave, not a throw; it shifts enough to bare the
## patch and leans over a little); each
## one can be turned once a run. Same rock art as the obstacles
## (obstacle.gd), smaller.

const ROCK := preload("res://scripts/obstacle.gd")
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

## Map theme (map_generator.gd): obstacle rock pool (Obstacle.resolve_pool).
var variant_pool: Array = []
var active := true

var _roller: Node2D
var _visual: Sprite2D
var _scar: Node2D
var _patch := Vector2.ZERO
var _patch_radius := 6.0
var _scar_alpha := 0.0


func _ready() -> void:
	y_sort_enabled = true
	var pool: Array = ROCK.resolve_pool(variant_pool)
	var index: int = pool.pick_random() if not pool.is_empty() else randi() % ROCK.VARIANTS.size()
	var variant: Dictionary = ROCK.variants()[index]
	var footprint: Rect2 = variant.footprint
	_patch = footprint.get_center() * SIZE
	_patch_radius = maxf(minf(footprint.size.x, footprint.size.y) * 0.5 * SIZE, 5.0)

	_scar = Node2D.new()
	_scar.z_index = -1
	_scar.draw.connect(_draw_scar)
	add_child(_scar)

	_roller = Node2D.new()
	add_child(_roller)
	_visual = Sprite2D.new()
	var tex := CanvasTexture.new()
	tex.diffuse_texture = Art.tex(variant.albedo)
	tex.normal_texture = Art.tex(variant.normal)
	_visual.texture = tex
	_visual.flip_h = randf() < 0.5
	Art.place(_visual, variant.offset, 0.5 * SIZE)
	_roller.add_child(_visual)
	SilhouetteShadow.attach(_roller, _visual)
	# Spin about the stone's middle, not its foot, when it rolls.
	_visual.position = _visual.offset * _visual.scale
	_visual.offset = Vector2.ZERO

	var body := StaticBody2D.new()
	# User request (no walking onto the rocks): solid where its base is -
	# the rock's traced outline (tools/rock_footprints.py), scaled and
	# flipped as it's drawn; a circle where there's none.
	var traced: Array = ROCK.footprints().get(variant.albedo, []) if variant.albedo is String else []
	if traced.size() >= 3:
		var poly := CollisionPolygon2D.new()
		var pts := PackedVector2Array()
		for pt in traced:
			pts.append(Vector2(-pt[0] if _visual.flip_h else pt[0], pt[1]) * SIZE)
		poly.polygon = pts
		body.add_child(poly)
	else:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = _patch_radius * 0.8
		shape.shape = circle
		shape.position = _patch
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
	var offset := dir * maxf(randf_range(ROLL_DISTANCE.x, ROLL_DISTANCE.y), _patch_radius * ROLL_BARE)
	var spin := signf(dir.x if absf(dir.x) > 0.1 else 1.0) * randf_range(ROLL_LEAN.x, ROLL_LEAN.y)
	var tween := create_tween()
	tween.tween_method(_roll.bind(offset, spin), 0.0, 1.0, ROLL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if randf() < SPIDER_CHANCE:
		return {"found": false, "spider": true}
	if randf() < FIND_CHANCE:
		return {"found": true, "flavor": BAIT_FLAVORS[randi() % BAIT_FLAVORS.size()]}
	return {"found": false}


func _roll(t: float, offset: Vector2, spin: float) -> void:
	# Heaved up a touch as it tips, then it settles.
	_roller.position = offset * t + Vector2(0, -sin(minf(t * 2.0, 1.0) * PI) * 1.5)
	_visual.rotation = spin * t
	_scar_alpha = t
	_scar.queue_redraw()


func _draw_scar() -> void:
	if _scar_alpha <= 0.0:
		return
	_scar.draw_set_transform(_patch, 0.0, Vector2(1.0, 0.62))
	_scar.draw_circle(Vector2.ZERO, _patch_radius * 1.1, Color(0.07, 0.05, 0.03, 0.55 * _scar_alpha))
	_scar.draw_circle(Vector2(-1.5, -1.0), _patch_radius * 0.7, Color(0.03, 0.02, 0.01, 0.35 * _scar_alpha))


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_rock"):
		body.set_in_rock(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_rock"):
		body.set_in_rock(false, self)
