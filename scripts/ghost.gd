extends Node2D

## Basic patrol / suspicious / alert / search loop (design doc §3.2), plus a
## simplified day-interference set (§3.3). "Catch" (night mode) is
## simplified to dropping carried fish rather than the full
## control/drag/rescue chain.

signal state_changed(new_state: String)

enum GhostState { PATROL, SUSPICIOUS, ALERT, SEARCH }

const PATROL_SPEED := 55.0
const SUSPICIOUS_SPEED := 95.0
const CHASE_SPEED := 125.0
const SEARCH_SPEED := 85.0

const PATROL_RADIUS := 240.0
const PATROL_WAIT_TIME := 1.5
const ARRIVE_RADIUS := 12.0

const POINT_BLANK_RADIUS := 45.0
const GHOST_BASE_SIGHT_RADIUS := 70.0
const LIGHT_ALERT_RANGE := 150.0
const SUSPICION_TIME := 3.0
const SEARCH_TIME := 3.5
const ALERT_GRACE_TIME := 1.5
const CATCH_RADIUS := 20.0

const ALTAR_SAFE_RADIUS := 85.0

const INTERFERENCE_RANGE := 140.0
const INTERFERENCE_COOLDOWN := 8.0
const STEAL_RANGE := 60.0
const LINE_CUT_RANGE := 45.0
const LINE_CUT_WINDUP := 1.2

var ghost_state: GhostState = GhostState.PATROL
var home_position: Vector2
var move_target: Vector2
var wait_timer: float = 0.0
var state_timer: float = 0.0
var interference_cooldown: float = 0.0
var line_cut_windup: float = 0.0

var player: Player
var player_lantern: Lantern
var altar: Node2D
var escape_point: Node2D
var stun_timer: float = 0.0

@onready var state_icon: Label = $StateIcon
@onready var visual: ColorRect = $Visual


func _ready() -> void:
	home_position = global_position
	move_target = home_position
	player = get_tree().current_scene.get_node("Player")
	player_lantern = player.get_node("Lantern")
	altar = get_tree().current_scene.get_node("Altar")
	escape_point = get_tree().current_scene.get_node("EscapePoint")
	state_changed.connect(_on_state_changed)
	add_to_group("ghosts")
	_set_state(GhostState.PATROL)


## Design doc §2.3: the strong-light skill briefly freezes the ghost solid -
## no movement, no sensing, no interference - while it's stunned.
func stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)


func _physics_process(delta: float) -> void:
	if stun_timer > 0.0:
		stun_timer -= delta
		visual.color = Color(0.9, 0.85, 0.3, 1)
		return
	visual.color = Color(0.55, 0.08, 0.16, 1)

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

	if ghost_state == GhostState.ALERT:
		line_cut_windup = 0.0
	else:
		_process_interference(delta, sense)


func _sense_player() -> Dictionary:
	var dist := global_position.distance_to(player.global_position)
	var lit := player_lantern.illuminates(global_position)
	# Being lit from far off only makes the ghost curious, not an instant
	# lock-on - the cone's visual reach is much longer than what should
	# give the player away outright (design doc §3.1's "more easily
	# discovered" reads as a speed/probability nudge, not a binary switch).
	var strong := (lit and dist <= LIGHT_ALERT_RANGE) or dist <= POINT_BLANK_RADIUS
	var weak := lit or dist <= GHOST_BASE_SIGHT_RADIUS or dist <= player.current_noise_radius
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

	# Design doc §2.2: fixed light circles (altar, escape point) are hard
	# walls a ghost can never cross, in any state.
	next_position = _clamp_outside_safe_zone(next_position, altar.global_position)
	next_position = _clamp_outside_safe_zone(next_position, escape_point.global_position)

	global_position = next_position


func _clamp_outside_safe_zone(pos: Vector2, zone_center: Vector2) -> Vector2:
	var offset := pos - zone_center
	if offset.length() < ALTAR_SAFE_RADIUS:
		return zone_center + offset.normalized() * ALTAR_SAFE_RADIUS
	return pos


## Design doc §3.3: while not actively chasing, the ghost harasses whatever
## the player is doing instead - scrambling a cast, cutting the line, or
## snatching a carried fish. Bait/lure-specific interference is skipped
## since that gear split doesn't exist yet.
func _process_interference(delta: float, sense: Dictionary) -> void:
	interference_cooldown = max(interference_cooldown - delta, 0.0)

	if interference_cooldown <= 0.0 and sense.dist <= STEAL_RANGE and not GameState.carried_fish.is_empty():
		var stolen: Dictionary = GameState.steal_one_carried()
		if not stolen.is_empty():
			GameState.push_message("鬼摸走了一條 %s！" % stolen.get("name", "魚"))
			interference_cooldown = INTERFERENCE_COOLDOWN
			line_cut_windup = 0.0
		return

	if interference_cooldown <= 0.0 and sense.dist <= INTERFERENCE_RANGE and player.state == Player.State.CHARGING:
		player.apply_cast_jitter()
		interference_cooldown = INTERFERENCE_COOLDOWN
		line_cut_windup = 0.0
		return

	if interference_cooldown <= 0.0 and player.has_line_out():
		var line_dist := _distance_to_segment(global_position, player.global_position, player.cast_target)
		if line_dist <= LINE_CUT_RANGE:
			line_cut_windup += delta
			if line_cut_windup >= LINE_CUT_WINDUP:
				player.cut_line()
				interference_cooldown = INTERFERENCE_COOLDOWN
				line_cut_windup = 0.0
			return

	line_cut_windup = 0.0


func _distance_to_segment(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var seg := seg_b - seg_a
	var len_sq := seg.length_squared()
	if len_sq < 0.0001:
		return point.distance_to(seg_a)
	var t: float = clamp((point - seg_a).dot(seg) / len_sq, 0.0, 1.0)
	var projection := seg_a + seg * t
	return point.distance_to(projection)


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
