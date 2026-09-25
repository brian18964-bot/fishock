class_name WaterGhost
extends Node2D

## User request: the water ghost is the user's zombie (Zombie.FBX, rendered
## by tools/render_water_ghost.py) - when its ambush fires (see
## Player._maybe_trigger_water_ghost()) it actually shows up: its head
## breaks the surface out in the water nearest the player with a splash,
## and it walks out of the water - rising out of it step by step as it
## gets shallower - lurches over with its arms out, clings to them for a
## moment (that's when the bait, a fish and their footing go), then wades
## back in and sinks out of sight.

const SHEET := [preload("res://assets/sprites/water_ghost/water_ghost_55deg_albedo.png"),
	preload("res://assets/sprites/water_ghost/water_ghost_55deg_normal.png")]
const SPRITE_SCALE := 0.5
## (0, -center_y) * 27.108 for the render's camera.
const OFFSET := Vector2(0.0, -17.76)
const FRAMES := 6
const DIRS := 8
## Sheet row by 45deg sector clockwise from +X (same order as the player).
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]
const WALK_FPS := 8.0
## How far out in the water it comes up (less in a narrow pond).
const IN_FROM_SHORE := 44.0
const RISE_TIME := 0.5
const SINK_TIME := 0.8
## User request: 20% slower than it was (125 / 80).
const LUNGE_SPEED := 100.0
const CLING_TIME := 1.6
const CLING_GAP := 9.0
const RETREAT_SPEED := 64.0
## How much of it the water hides per px of depth, and at most.
const SUBMERGE_PER_PX := 0.85
const MAX_SUBMERGE := 40.0
const WATER_LINE := preload("res://shaders/water_line.gdshader")
const TINT := Color(0.78, 0.95, 0.9, 0.92)

enum Phase { RISE, LUNGE, CLING, RETREAT, SINK }

var _player: Node2D
var _home := Vector2.ZERO
var _phase := Phase.RISE
var _t := 0.0
var _dir := 0
var _anim := 0.0
var _water_line: ShaderMaterial
var _visual: Sprite2D


## Brings one up by the water nearest `player` (if it's near any, and
## there isn't one out already).
static func summon(player: Node2D) -> WaterGhost:
	if not player.get_tree().get_nodes_in_group("water_ghosts").is_empty():
		return null
	var spot = _water_spot(player)
	if spot == null:
		return null
	var ghost := WaterGhost.new()
	ghost._player = player
	ghost._home = spot
	ghost.position = spot
	player.get_parent().add_child(ghost)
	return ghost


## A point just inside the shore of the water closest to `player`.
static func _water_spot(player: Node2D):
	var best = null
	var best_d := INF
	for zone in player.get_tree().get_nodes_in_group("water_zones_common"):
		var dir: Vector2 = player.global_position - zone.global_position
		if dir.length() < 1.0:
			continue
		var shore: Vector2 = zone.shore_point(dir.normalized())
		var d := shore.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = shore - dir.normalized() * 8.0
			for back in [IN_FROM_SHORE, IN_FROM_SHORE * 0.6, IN_FROM_SHORE * 0.35]:
				var p: Vector2 = shore - dir.normalized() * back
				if zone.is_deep(p, back * 0.6):
					best = p
					break
	return best


func _ready() -> void:
	add_to_group("water_ghosts")
	_visual = Sprite2D.new()
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	_visual.texture = tex
	_visual.hframes = FRAMES
	_visual.vframes = DIRS
	_visual.modulate = TINT
	Art.place(_visual, OFFSET, SPRITE_SCALE)
	_water_line = ShaderMaterial.new()
	_water_line.shader = WATER_LINE
	_visual.material = _water_line
	add_child(_visual)
	_face(_player.global_position - global_position)
	_submerge(MAX_SUBMERGE + 30.0)
	SplashFx.play(get_parent(), "splash_bite", global_position)
	Ripple.spawn(get_parent(), global_position, 30.0, 1.3)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return
	_t += delta
	match _phase:
		Phase.RISE:
			# Its head comes up to the surface where it stands.
			_face(_player.global_position - global_position)
			var k := smoothstep(0.0, 1.0, _t / RISE_TIME)
			_submerge(lerpf(MAX_SUBMERGE + 30.0, _water_cover(), k))
			if _t >= RISE_TIME:
				_next(Phase.LUNGE)
		Phase.LUNGE:
			var target := _cling_spot()
			_walk_to(target, LUNGE_SPEED, delta)
			_submerge(_water_cover())
			if global_position.distance_to(target) < 2.0:
				_next(Phase.CLING)
		Phase.CLING:
			# Hangs on as they stagger about.
			global_position = global_position.lerp(_cling_spot(), minf(delta * 8.0, 1.0))
			_submerge(_water_cover())
			_face(_player.global_position - global_position)
			_anim += delta * WALK_FPS * 0.5
			if _t >= CLING_TIME:
				_next(Phase.RETREAT)
		Phase.RETREAT:
			_walk_to(_home, RETREAT_SPEED, delta)
			_submerge(_water_cover())
			if global_position.distance_to(_home) < 1.5:
				Ripple.spawn(get_parent(), global_position, 24.0, 1.0)
				_next(Phase.SINK)
		Phase.SINK:
			var k := smoothstep(0.0, 1.0, _t / SINK_TIME)
			_submerge(lerpf(_water_cover(), MAX_SUBMERGE + 30.0, k))
			if _t >= SINK_TIME:
				queue_free()
	_visual.frame = _dir * FRAMES + int(_anim) % FRAMES


func _next(phase: Phase) -> void:
	_phase = phase
	_t = 0.0


## Right up against the player, on the side it came from.
func _cling_spot() -> Vector2:
	var from := global_position - _player.global_position
	if from.length() < 0.5:
		from = _home - _player.global_position
	return _player.global_position + from.normalized() * CLING_GAP


func _walk_to(target: Vector2, speed: float, delta: float) -> void:
	var to := target - global_position
	_face(to)
	global_position += to.limit_length(speed * delta)
	_anim += delta * WALK_FPS


func _face(to: Vector2) -> void:
	if to.length() > 0.5:
		_dir = SECTOR_TO_DIR[posmod(roundi(to.angle() / (PI / 4.0)), 8)]


## How much of it the water where it stands hides (world px).
func _water_cover() -> float:
	var zone := Ripple.water_at(get_tree(), global_position)
	if zone == null:
		return 0.0
	return minf(zone.depth(global_position) * SUBMERGE_PER_PX, MAX_SUBMERGE)


## Lowered `px` below the water line (its feet), and only drawn above it.
func _submerge(px: float) -> void:
	_visual.position = Vector2(0.0, px)
	_water_line.set_shader_parameter("cut_y", -px / _visual.scale.y if px > 0.0 else 100000.0)
