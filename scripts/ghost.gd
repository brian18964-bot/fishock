extends Node2D

## Basic patrol / suspicious / alert / search loop (design doc §3.2). No day
## interference (steal bait, cut line, etc.) yet, and "catch" is simplified
## to dropping carried fish rather than the full control/drag/rescue chain.

signal state_changed(new_state: String)

enum GhostState { PATROL, SUSPICIOUS, ALERT, SEARCH }

const PATROL_SPEED := 55.0
const SUSPICIOUS_SPEED := 95.0
const CHASE_SPEED := 125.0
const SEARCH_SPEED := 85.0

const PATROL_RADIUS := 160.0
const PATROL_WAIT_TIME := 1.5
const ARRIVE_RADIUS := 12.0

const POINT_BLANK_RADIUS := 45.0
const GHOST_BASE_SIGHT_RADIUS := 70.0
const SUSPICION_TIME := 3.0
const SEARCH_TIME := 3.5
const ALERT_GRACE_TIME := 1.5
const CATCH_RADIUS := 20.0

const ALTAR_SAFE_RADIUS := 85.0

var ghost_state: GhostState = GhostState.PATROL
var home_position: Vector2
var move_target: Vector2
var wait_timer: float = 0.0
var state_timer: float = 0.0

var player: Node2D
var player_lantern: PointLight2D
var altar: Node2D

@onready var state_icon: Label = $StateIcon


func _ready() -> void:
	home_position = global_position
	move_target = home_position
	player = get_tree().current_scene.get_node("Player")
	player_lantern = player.get_node("Lantern")
	altar = get_tree().current_scene.get_node("Altar")
	state_changed.connect(_on_state_changed)
	_set_state(GhostState.PATROL)


func _physics_process(delta: float) -> void:
	var sense := _sense_player()
	match ghost_state:
		GhostState.PATROL:
			_process_patrol(delta, sense)
		GhostState.SUSPICIOUS:
			_process_suspicious(delta, sense)
		GhostState.ALERT:
			_process_alert(delta, sense)
		GhostState.SEARCH:
			_process_search(delta, sense)


func _sense_player() -> Dictionary:
	var dist := global_position.distance_to(player.global_position)
	var lit := player_lantern.illuminates(global_position)
	var strong := lit or dist <= POINT_BLANK_RADIUS
	var weak := dist <= GHOST_BASE_SIGHT_RADIUS or dist <= player.current_noise_radius
	return {"strong": strong, "weak": weak, "dist": dist}


func _process_patrol(delta: float, sense: Dictionary) -> void:
	if sense.strong:
		_set_state(GhostState.ALERT)
		return
	if sense.weak:
		move_target = player.global_position
		state_timer = SUSPICION_TIME
		_set_state(GhostState.SUSPICIOUS)
		return

	if global_position.distance_to(move_target) <= ARRIVE_RADIUS:
		wait_timer -= delta
		if wait_timer <= 0.0:
			var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * PATROL_RADIUS
			move_target = home_position + offset
			wait_timer = PATROL_WAIT_TIME
	else:
		_move_toward(move_target, PATROL_SPEED, delta)


func _process_suspicious(delta: float, sense: Dictionary) -> void:
	if sense.strong:
		_set_state(GhostState.ALERT)
		return
	if sense.weak:
		move_target = player.global_position
		state_timer = SUSPICION_TIME
	else:
		state_timer -= delta

	_move_toward(move_target, SUSPICIOUS_SPEED, delta)

	var arrived := global_position.distance_to(move_target) <= ARRIVE_RADIUS
	if state_timer <= 0.0 or arrived:
		_start_search(move_target)


func _process_alert(delta: float, sense: Dictionary) -> void:
	if player.in_altar_zone:
		_start_search(player.global_position)
		return

	_move_toward(player.global_position, CHASE_SPEED, delta)

	if sense.dist <= CATCH_RADIUS:
		_catch_player()
		return

	if sense.strong or sense.weak:
		state_timer = ALERT_GRACE_TIME
	else:
		state_timer -= delta
		if state_timer <= 0.0:
			_start_search(player.global_position)


func _process_search(delta: float, sense: Dictionary) -> void:
	if sense.strong:
		_set_state(GhostState.ALERT)
		return
	if sense.weak:
		move_target = player.global_position
		state_timer = SUSPICION_TIME
		_set_state(GhostState.SUSPICIOUS)
		return

	if global_position.distance_to(move_target) > ARRIVE_RADIUS:
		_move_toward(move_target, SEARCH_SPEED, delta)
	else:
		state_timer -= delta
		if state_timer <= 0.0:
			_set_state(GhostState.PATROL)


func _start_search(at: Vector2) -> void:
	move_target = at
	state_timer = SEARCH_TIME
	_set_state(GhostState.SEARCH)


func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var to_target := target - global_position
	var next_position := global_position
	if to_target.length() > 1.0:
		next_position = global_position + to_target.normalized() * speed * delta

	# Design doc §2.2: a fixed light circle (the altar) is a hard wall a
	# ghost can never cross, in any state.
	var to_altar := next_position - altar.global_position
	if to_altar.length() < ALTAR_SAFE_RADIUS:
		next_position = altar.global_position + to_altar.normalized() * ALTAR_SAFE_RADIUS

	global_position = next_position


func _catch_player() -> void:
	var dropped: int = GameState.drop_all_carried()
	if dropped > 0:
		GameState.push_message("被鬼抓到了！身上 %d 條魚掉了" % dropped)
	else:
		GameState.push_message("被鬼抓到了！")
	_start_search(player.global_position)


func _set_state(new_state: GhostState) -> void:
	ghost_state = new_state
	state_changed.emit(GhostState.keys()[new_state])


func _on_state_changed(new_state: String) -> void:
	state_icon.text = {"PATROL": "", "SUSPICIOUS": "?", "ALERT": "!", "SEARCH": "…"}.get(new_state, "")
