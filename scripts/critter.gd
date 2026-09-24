class_name Critter
extends CharacterBody2D

## User request: small animals (Quaternius animal pack, CC0) that wander the
## map and can be caught as bait, plus larger ambient animals (farm animals
## and a deer) that are just scenery - `ambient` picks which pool a node
## draws from. They idle, amble about, and run from the
## player once they get close; stand on one and press the action key to
## catch it (see Player._catch_critter()), which also sets the next cast's
## bait flavor. A caught critter reappears elsewhere after RESPAWN_DELAY.
##
## Art: 55deg sprite sheets from tools/render_sprite.py's "anim" command -
## `frames` per row (8 critters, 12 ambient), rows = clips x directions
## (down, left, right, up); clip 0 moves, clip 1 idles, `flee_clip` runs. Never
## flip_h a direction: the normal map's X channel would stay mirrored.

const SPRITE_SCALE := 0.5
const DIRS := ["down", "left", "right", "up"]

const FLEE_RADIUS := 70.0
const CALM_RADIUS := 140.0
const WANDER_RADIUS := 90.0
const RESPAWN_DELAY := 30.0
const MARGIN := 80.0

## offset: ground point relative to one cell's center (-center_y * 27.108).
## move_fps / idle_fps: 8 samples over each clip's 24fps loop length.
## flavor: the bait flavor it becomes - 青蛙 and 蟲子 reuse the roadside
## flavors' effects; 老鼠 and 蛇 are "big bait" (see Player).
const SPECIES := {
	"rat": {"label": "老鼠", "flavor": "老鼠",
		"albedo": preload("res://assets/sprites/critter/rat_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/rat_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -6.99), "move_fps": 16.0, "idle_fps": 3.4,
		"wander_speed": 45.0, "flee_speed": 120.0},
	"frog": {"label": "青蛙", "flavor": "青蛙",
		"albedo": preload("res://assets/sprites/critter/frog_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/frog_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -2.95), "move_fps": 9.1, "idle_fps": 3.2,
		"wander_speed": 35.0, "flee_speed": 95.0},
	"snake": {"label": "蛇", "flavor": "蛇",
		"albedo": preload("res://assets/sprites/critter/snake_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/snake_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -11.66), "move_fps": 9.6, "idle_fps": 3.8,
		"wander_speed": 30.0, "flee_speed": 85.0},
	"spider": {"label": "蜘蛛", "flavor": "蟲子",
		"albedo": preload("res://assets/sprites/critter/spider_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/spider_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -1.11), "move_fps": 9.6, "idle_fps": 1.9,
		"wander_speed": 40.0, "flee_speed": 110.0},
	# One clip (flying) for both moving and hovering; floats above the ground.
	"wasp": {"label": "黃蜂", "flavor": "蟲子",
		"albedo": preload("res://assets/sprites/critter/wasp_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/wasp_55deg_normal.png"),
		"clips": 1, "offset": Vector2(0, -12.36), "move_fps": 10.7, "idle_fps": 10.7,
		"wander_speed": 40.0, "flee_speed": 115.0, "hover": 14.0},

	# Ambient animals: not catchable. Grazers ignore the player (flee_speed
	# 0); the deer bolts at a gallop, faster than the player can follow.
	"cow": {"label": "牛", "ambient": true, "frames": 12,
		"albedo": preload("res://assets/sprites/animal/cow_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/animal/cow_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -18.41), "move_fps": 10.3, "idle_fps": 2.0,
		"wander_speed": 18.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"bull": {"label": "公牛", "ambient": true, "frames": 12,
		"albedo": preload("res://assets/sprites/animal/bull_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/animal/bull_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -18.49), "move_fps": 10.3, "idle_fps": 2.0,
		"wander_speed": 18.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"donkey": {"label": "驢子", "ambient": true, "frames": 12,
		"albedo": preload("res://assets/sprites/animal/donkey_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/animal/donkey_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -14.96), "move_fps": 10.3, "idle_fps": 2.0,
		"wander_speed": 20.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"alpaca": {"label": "羊駝", "ambient": true, "frames": 12,
		"albedo": preload("res://assets/sprites/animal/alpaca_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/animal/alpaca_55deg_normal.png"),
		"clips": 2, "offset": Vector2(0, -15.61), "move_fps": 8.2, "idle_fps": 1.6,
		"wander_speed": 20.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"deer": {"label": "鹿", "ambient": true, "frames": 12,
		"albedo": preload("res://assets/sprites/animal/deer_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/animal/deer_55deg_normal.png"),
		"clips": 3, "offset": Vector2(0, -19.14), "move_fps": 10.3, "idle_fps": 2.0,
		"flee_fps": 24.0, "flee_clip": 2, "flee_radius": 120.0, "calm_radius": 260.0,
		"wander_speed": 28.0, "flee_speed": 170.0, "idle_time": Vector2(3, 8)},
}

enum Mode { IDLE, WANDER, FLEE }

var species: String = ""
var active: bool = true
## Draw from the ambient (scenery) animals instead of the catchable ones.
@export var ambient: bool = false

var _data: Dictionary
var _mode: Mode = Mode.IDLE
var _mode_timer: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _dir: int = 0
var _anim_time: float = 0.0
var _respawn_timer: float = 0.0
var _player: Node2D

@onready var sprite: Sprite2D = $Visual
@onready var catch_area: Area2D = $CatchArea


func _ready() -> void:
	catch_area.body_entered.connect(_on_body_entered)
	catch_area.body_exited.connect(_on_body_exited)
	if species == "":
		species = _pick_species()
	set_species(species)
	_player = get_tree().get_first_node_in_group("player")
	_anim_time = randf() * 2.0
	_enter_idle()


func set_species(name: String) -> void:
	species = name
	_data = SPECIES[name]
	var tex := CanvasTexture.new()
	tex.diffuse_texture = _data.albedo
	tex.normal_texture = _data.normal
	sprite.texture = tex
	sprite.hframes = _data.get("frames", 8)
	sprite.vframes = _data.clips * DIRS.size()
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.offset = _data.offset


func _physics_process(delta: float) -> void:
	if not active:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	_update_mode(delta)
	var speed := 0.0
	if _mode == Mode.WANDER:
		speed = _data.wander_speed
	elif _mode == Mode.FLEE:
		speed = _data.flee_speed
	var to_target := _target - global_position
	if speed > 0.0 and to_target.length() > 4.0:
		velocity = to_target.normalized() * speed
		var before := global_position
		move_and_slide()
		if _in_water(global_position):
			global_position = before
			_pick_target(_mode == Mode.FLEE)
		global_position.x = clamp(global_position.x, 16.0, Player.WORLD_WIDTH - 16.0)
		global_position.y = clamp(global_position.y, 16.0, Player.WORLD_HEIGHT - 16.0)
		_dir = _dir_index(velocity)
	elif _mode == Mode.WANDER:
		_enter_idle()
	_animate(delta)


func _update_mode(delta: float) -> void:
	var near: bool = _data.flee_speed > 0.0 and _player != null \
		and global_position.distance_to(_player.global_position) < _data.get("flee_radius", FLEE_RADIUS)
	if near:
		if _mode != Mode.FLEE:
			_mode = Mode.FLEE
		_pick_target(true)
		return
	if _mode == Mode.FLEE:
		if _player == null or global_position.distance_to(_player.global_position) > _data.get("calm_radius", CALM_RADIUS):
			_enter_idle()
		return
	_mode_timer -= delta
	if _mode == Mode.IDLE and _mode_timer <= 0.0:
		_mode = Mode.WANDER
		_pick_target(false)


func _enter_idle() -> void:
	_mode = Mode.IDLE
	var idle_time: Vector2 = _data.get("idle_time", Vector2(1.5, 4.0))
	_mode_timer = randf_range(idle_time.x, idle_time.y)
	velocity = Vector2.ZERO


## Wandering: a random point nearby. Fleeing: straight away from the player,
## nudged sideways when that way is water so it doesn't pin itself.
func _pick_target(fleeing: bool) -> void:
	if fleeing and _player != null:
		var away := (global_position - _player.global_position).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		for angle in [0.0, 0.6, -0.6, 1.2, -1.2, PI / 2.0, -PI / 2.0]:
			var candidate: Vector2 = global_position + away.rotated(angle) * 60.0
			if not _in_water(candidate):
				_target = candidate
				return
		_target = global_position + away * 60.0
		return
	for _try in range(8):
		var candidate := global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, WANDER_RADIUS)
		if not _in_water(candidate):
			_target = candidate
			return
	_target = global_position


func _dir_index(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 2 if v.x > 0.0 else 1
	return 0 if v.y > 0.0 else 3


func _animate(delta: float) -> void:
	_anim_time += delta
	var moving := _mode != Mode.IDLE and velocity != Vector2.ZERO
	var clip := 0 if (moving or _data.clips == 1) else 1
	var fps: float = _data.move_fps if moving else _data.idle_fps
	if moving and _mode == Mode.FLEE and _data.has("flee_clip"):
		clip = _data.flee_clip
		fps = _data.flee_fps
	var frames: int = _data.get("frames", 8)
	sprite.frame = (clip * DIRS.size() + _dir) * frames + int(_anim_time * fps) % frames
	var hover: float = _data.get("hover", 0.0)
	if hover > 0.0:
		sprite.position.y = -hover + sin(_anim_time * 3.0) * 2.0


func get_label() -> String:
	return _data.label


## Called by the player on a successful catch; returns the bait flavor.
func catch() -> String:
	active = false
	visible = false
	catch_area.set_deferred("monitoring", false)
	_respawn_timer = RESPAWN_DELAY
	return _data.flavor


func _respawn() -> void:
	var pos := global_position
	for _try in range(20):
		pos = Vector2(
			randf_range(MARGIN, Player.WORLD_WIDTH - MARGIN),
			randf_range(MARGIN, Player.WORLD_HEIGHT - MARGIN)
		)
		if not _in_water(pos) and (_player == null or pos.distance_to(_player.global_position) > 300.0):
			break
	global_position = pos
	set_species(_pick_species())
	active = true
	visible = true
	catch_area.monitoring = true
	_enter_idle()


func _pick_species() -> String:
	var pool := []
	for key in SPECIES:
		if SPECIES[key].get("ambient", false) == ambient:
			pool.append(key)
	return pool.pick_random()


func _in_water(pos: Vector2) -> bool:
	for zone in get_tree().get_nodes_in_group("water_zones"):
		if zone.contains(pos):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if active and not _data.get("ambient", false) and body.has_method("set_in_critter"):
		body.set_in_critter(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_critter"):
		body.set_in_critter(false, self)
