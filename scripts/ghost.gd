extends Node2D

## The floating ghosts (the design doc's day ghosts). User request: they
## only get in the way now and then - drifting about the map most of the
## time, and every so often (at least GameState.GHOST_INTERFERENCE_GAP s
## apart, at most GHOST_INTERFERENCE_MAX times a run between all of them)
## one comes over to make trouble: it muddles the player (a dizzy spell),
## snatches a carried fish, cuts the line, or slips into the water to steal
## the bait off the bobber. Then it drifts off again. Harmless otherwise -
## the killing is the big ghost's (BigGhost).

signal state_changed(new_state: String)

enum GhostState { WANDER, HAUNT, LEAVE }

## User request: the ghost model (Ghoooooost by Nikki Morin) pre-rendered
## facing down/left/right/up (tools/render_dirs.py, x1.3 --facing 39,
## 120x96 cells, origin at its head). It floats - hovering and bobbing over
## a soft shadow - faces the way it drifts, and its state reads as a tint
## on the pale sheet: stunned yellow, frenzied pink, the night hunt red.
const GHOST_SHEET := [preload("res://assets/sprites/ghost/ghost_55deg_albedo.png"), preload("res://assets/sprites/ghost/ghost_55deg_normal.png")]
const GHOST_OFFSET := Vector2(0.0, 15.52)
const GHOST_DIRS := 4  # sheet columns: down, left, right, up
const HOVER := 18.0
const BOB := 3.0
const TINT_NORMAL := Color(0.92, 0.86, 0.95, 0.82)
const TINT_STUNNED := Color(1.0, 0.95, 0.5, 0.85)
const TINT_FRENZY := Color(1.0, 0.5, 0.75, 0.9)
const TINT_NIGHT := Color(1.0, 0.35, 0.4, 0.95)

var _tint := TINT_NORMAL
var _bob_time := 0.0
var _last_pos := Vector2.ZERO

## User feedback: everything moved too fast - the player and every creature
## slowed 20%, ghosts with them.
const PACE := 0.8
const WANDER_SPEED := 55.0
const HAUNT_SPEED := 110.0
const LEAVE_SPEED := 85.0
const NIGHT_MULT := 1.25
const WANDER_WAIT := Vector2(1.0, 3.5)
const ARRIVE_RADIUS := 12.0
## A ghost this close to the player (or lit up by their lamp) is the one
## that comes over when trouble is due.
const HAUNT_RANGE := 320.0
## Gives up on a visit that takes longer than this.
const HAUNT_TIMEOUT := 12.0
const REACH := 18.0
const LEAVE_DISTANCE := 420.0
const CONFUSE_TIME := 4.0

const FIXED_LIGHT_SAFE_RADIUS := 85.0

## Design doc request: a rotten offering can make the ghosts more dangerous
## for a while; a storm too.
const FRENZY_SPEED_MULT := 1.35
const STORM_SPEED_MULT := 1.15

var frenzy_timer: float = 0.0

var ghost_state: GhostState = GhostState.WANDER
var move_target: Vector2
var wait_timer: float = 0.0
var state_timer: float = 0.0

var player: Player
var player_lantern: Lantern
var escape_point: Node2D
var escape_light: PointLight2D
var fuel_station: FuelStation
var fuel_light: PointLight2D
var stun_timer: float = 0.0

@onready var state_icon: Label = $StateIcon
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	_setup_visual()
	move_target = global_position
	player = get_tree().current_scene.get_node("Player")
	player_lantern = player.get_node("Lantern")
	escape_point = get_tree().current_scene.get_node("EscapePoint")
	escape_light = escape_point.get_node("Light")
	fuel_station = get_tree().current_scene.get_node("FuelStation")
	fuel_light = fuel_station.get_node("Light")
	state_changed.connect(_on_state_changed)
	add_to_group("ghosts")
	_set_state(GhostState.WANDER)


## Design doc §2.3: the strong-light skill briefly freezes the ghost solid.
## Caught in it on the way over, it thinks better of the visit.
func stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)
	if ghost_state == GhostState.HAUNT:
		_leave()


func enter_frenzy(duration: float) -> void:
	frenzy_timer = max(frenzy_timer, duration)


func _speed_mult() -> float:
	var mult := PACE
	if frenzy_timer > 0.0:
		mult *= FRENZY_SPEED_MULT
	if GameState.weather == GameState.Weather.STORM:
		mult *= STORM_SPEED_MULT
	if GameState.is_night:
		mult *= NIGHT_MULT
	return mult


func _physics_process(delta: float) -> void:
	if frenzy_timer > 0.0:
		frenzy_timer -= delta
	if stun_timer > 0.0:
		stun_timer -= delta
		_tint = TINT_STUNNED
		return
	_tint = TINT_NIGHT if GameState.is_night else (TINT_FRENZY if frenzy_timer > 0.0 else TINT_NORMAL)

	match ghost_state:
		GhostState.WANDER:
			_wander(delta, WANDER_SPEED)
			if _should_haunt():
				GameState.ghost_haunter = self
				state_timer = HAUNT_TIMEOUT
				_set_state(GhostState.HAUNT)
		GhostState.HAUNT:
			_haunt(delta)
		GhostState.LEAVE:
			_move_toward(move_target, LEAVE_SPEED * _speed_mult(), delta)
			if global_position.distance_to(move_target) <= ARRIVE_RADIUS:
				wait_timer = randf_range(WANDER_WAIT.x, WANDER_WAIT.y)
				_set_state(GhostState.WANDER)


func _should_haunt() -> bool:
	if not GameState.ghost_may_interfere():
		return false
	var other = GameState.ghost_haunter
	if other != null and is_instance_valid(other) and other != self:
		return false
	var dist := global_position.distance_to(player.global_position)
	return dist <= HAUNT_RANGE or player_lantern.illuminates(global_position)


## Drifting between random spots anywhere on the map, pausing now and then.
func _wander(delta: float, speed: float) -> void:
	if global_position.distance_to(move_target) <= ARRIVE_RADIUS:
		wait_timer -= delta
		if wait_timer <= 0.0:
			move_target = Vector2(randf_range(60.0, Player.WORLD_WIDTH - 60.0), randf_range(60.0, Player.WORLD_HEIGHT - 60.0))
			wait_timer = randf_range(WANDER_WAIT.x, WANDER_WAIT.y)
	else:
		_move_toward(move_target, speed * _speed_mult(), delta)


## On its way over to make trouble - to the bobber if there's bait on it,
## along the line if it's out, otherwise to the player.
func _haunt(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_leave()
		return
	var bobber_waiting := player.fishing_mode == Player.FishingMode.BOBBER and player.state == Player.State.WAITING
	var target := player.global_position
	if bobber_waiting:
		target = player.cast_target
	elif player.has_line_out():
		target = (player.global_position + player.get_line_target_position()) * 0.5
	# Straight over the water to the bobber: no keeping to the shore.
	_move_toward(target, HAUNT_SPEED * _speed_mult(), delta, not bobber_waiting)
	if global_position.distance_to(target) > REACH:
		return
	if bobber_waiting:
		player.spoil_bait()
		GameState.push_message("鬼突然飄進水裡，把浮標上的餌偷吃了！")
	elif player.has_line_out():
		player.cut_line()
		GameState.push_message("鬼把釣線剪斷了！")
	elif not GameState.carried_fish.is_empty():
		var stolen: Dictionary = GameState.steal_one_carried()
		GameState.push_message("鬼摸走了一條 %s！" % stolen.get("name", "魚"))
	else:
		if player.state == Player.State.CHARGING:
			player.apply_cast_jitter()
		player.ghost_confuse(CONFUSE_TIME)
		GameState.push_message("鬼從你身上穿過，一陣頭昏眼花...")
	GameState.ghost_interfered()
	_leave()


func _leave() -> void:
	if GameState.ghost_haunter == self:
		GameState.ghost_haunter = null
	var away := global_position - player.global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	move_target = global_position + away.normalized().rotated(randf_range(-0.7, 0.7)) * LEAVE_DISTANCE
	move_target.x = clampf(move_target.x, 60.0, Player.WORLD_WIDTH - 60.0)
	move_target.y = clampf(move_target.y, 60.0, Player.WORLD_HEIGHT - 60.0)
	_set_state(GhostState.LEAVE)


func _move_toward(target: Vector2, speed: float, delta: float, keep_out := true) -> void:
	var to_target := target - global_position
	var next_position := global_position
	if to_target.length() > 1.0:
		next_position = global_position + to_target.limit_length(speed * delta)
	# Design doc §2.2: a lit fixed light is a wall it can't cross.
	if keep_out:
		if escape_light.visible:
			next_position = _clamp_outside_safe_zone(next_position, escape_point.global_position)
		if fuel_light.visible:
			next_position = _clamp_outside_safe_zone(next_position, fuel_station.global_position)
	global_position = next_position


func _clamp_outside_safe_zone(pos: Vector2, zone_center: Vector2) -> Vector2:
	var offset := pos - zone_center
	if offset.length() < FIXED_LIGHT_SAFE_RADIUS:
		return zone_center + offset.normalized() * FIXED_LIGHT_SAFE_RADIUS
	return pos


func _set_state(new_state: GhostState) -> void:
	ghost_state = new_state
	state_changed.emit(GhostState.keys()[new_state])


func _on_state_changed(new_state: String) -> void:
	state_icon.text = "!" if new_state == "HAUNT" else ""


func _process(delta: float) -> void:
	_bob_time += delta
	visual.position.y = -HOVER + sin(_bob_time * 2.3) * BOB
	visual.modulate = visual.modulate.lerp(_tint, minf(1.0, delta * 6.0))
	var moved := global_position - _last_pos
	_last_pos = global_position
	if moved.length() > 0.2:
		var dir := 0
		if absf(moved.x) > absf(moved.y):
			dir = 2 if moved.x > 0.0 else 1
		else:
			dir = 0 if moved.y > 0.0 else 3
		visual.frame = dir


func _setup_visual() -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = GHOST_SHEET[0]
	tex.normal_texture = GHOST_SHEET[1]
	visual.texture = tex
	visual.hframes = GHOST_DIRS
	Art.place(visual, GHOST_OFFSET, 0.5)
	visual.modulate = _tint
	_last_pos = global_position
	_bob_time = randf() * TAU
	# A soft shadow on the ground under it.
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = LightTextureFactory.make_radial_texture(64, 0.5)
	shadow.scale = Vector2(0.55, 0.22)
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.show_behind_parent = true
	add_child(shadow)
