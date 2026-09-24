extends Node2D

## Basic patrol / suspicious / alert / search loop (design doc §3.2), plus a
## simplified day-interference set (§3.3). Day "catch" (an ALERT chase
## landing) is simplified to dropping carried fish rather than the full
## control/drag/rescue chain. Night is a separate, simpler unescapable
## hunt (§3.4) that ends the run outright on catch - see
## _process_night_hunt().

signal state_changed(new_state: String)

enum GhostState { PATROL, SUSPICIOUS, ALERT, SEARCH }

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
## slowed 20%, ghosts with them so the chase balance holds.
const PACE := 0.8
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

const FIXED_LIGHT_SAFE_RADIUS := 85.0

const INTERFERENCE_RANGE := 140.0
const INTERFERENCE_COOLDOWN := 8.0
const STEAL_RANGE := 60.0
const BAIT_STEAL_RANGE := 45.0
const LINE_CUT_RANGE := 45.0
const LINE_CUT_WINDUP := 1.2

## Faster than the player's 140 - design doc §3.4: once night falls the
## ghost "無視一切防禦" (ignores every defense), so this is meant to be
## unescapable rather than a fair chase.
const NIGHT_CHASE_SPEED := 155.0

## Design doc request: sacrificing a rotten offering can gamble on making
## the ghost(s) more dangerous for a while instead of a normal payout.
const FRENZY_SPEED_MULT := 1.35
const FRENZY_COOLDOWN_MULT := 2.0

## User feedback: a storm should make the ghost(s) more dangerous too, on
## top of the water-ghost chance bump (see player.gd).
const STORM_SPEED_MULT := 1.15
const STORM_COOLDOWN_MULT := 1.3

var frenzy_timer: float = 0.0

var ghost_state: GhostState = GhostState.PATROL
var home_position: Vector2
var move_target: Vector2
var wait_timer: float = 0.0
var state_timer: float = 0.0
var interference_cooldown: float = 0.0
var line_cut_windup: float = 0.0

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
	home_position = global_position
	move_target = home_position
	player = get_tree().current_scene.get_node("Player")
	player_lantern = player.get_node("Lantern")
	escape_point = get_tree().current_scene.get_node("EscapePoint")
	escape_light = escape_point.get_node("Light")
	fuel_station = get_tree().current_scene.get_node("FuelStation")
	fuel_light = fuel_station.get_node("Light")
	state_changed.connect(_on_state_changed)
	add_to_group("ghosts")
	_set_state(GhostState.PATROL)


## Design doc §2.3: the strong-light skill briefly freezes the ghost solid -
## no movement, no sensing, no interference - while it's stunned.
func stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)


## Design doc request: a rotten-offering sacrifice can roll this instead of
## a normal payout - temporarily faster and more aggressive.
func enter_frenzy(duration: float) -> void:
	frenzy_timer = max(frenzy_timer, duration)


func _speed_mult() -> float:
	var mult := PACE
	if frenzy_timer > 0.0:
		mult *= FRENZY_SPEED_MULT
	if GameState.weather == GameState.Weather.STORM:
		mult *= STORM_SPEED_MULT
	return mult


func _physics_process(delta: float) -> void:
	if frenzy_timer > 0.0:
		frenzy_timer -= delta

	if GameState.is_night:
		_process_night_hunt(delta)
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		_tint = TINT_STUNNED
		return
	_tint = TINT_FRENZY if frenzy_timer > 0.0 else TINT_NORMAL

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
		_move_toward(move_target, PATROL_SPEED * _speed_mult(), delta)


func _process_suspicious(delta: float, sense: Dictionary) -> void:
	if sense.strong:
		_set_state(GhostState.ALERT)
		return
	if sense.weak:
		move_target = player.global_position
		state_timer = SUSPICION_TIME
	else:
		state_timer -= delta

	_move_toward(move_target, SUSPICIOUS_SPEED * _speed_mult(), delta)

	var arrived := global_position.distance_to(move_target) <= ARRIVE_RADIUS
	if state_timer <= 0.0 or arrived:
		_start_search(move_target)


func _process_alert(delta: float, sense: Dictionary) -> void:
	# Design doc request: the altar no longer protects - only a fixed
	# light that's actually still lit (checked inside _move_toward) does.
	_move_toward(player.global_position, CHASE_SPEED * _speed_mult(), delta)

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
		_move_toward(move_target, SEARCH_SPEED * _speed_mult(), delta)
	else:
		state_timer -= delta
		if state_timer <= 0.0:
			_set_state(GhostState.PATROL)


## Design doc §3.4: ignores stun, fixed lights, and the whole day FSM - it
## just beelines the player, unescapably fast, until it catches them.
func _process_night_hunt(delta: float) -> void:
	_tint = TINT_NIGHT
	var to_player := player.global_position - global_position
	if to_player.length() > 1.0:
		global_position += to_player.normalized() * NIGHT_CHASE_SPEED * PACE * delta

	if global_position.distance_to(player.global_position) <= CATCH_RADIUS:
		if GameState.use_heart():
			GameState.push_message("心臟救了你一命！鬼被震退了")
			var away := global_position - player.global_position
			if away.length() < 1.0:
				away = Vector2.UP
			global_position = player.global_position + away.normalized() * 260.0
		else:
			GameState.end_run(false, "被鬼拖進水裡了，你沒能撐過夜晚")


func _start_search(at: Vector2) -> void:
	move_target = at
	state_timer = SEARCH_TIME
	_set_state(GhostState.SEARCH)


func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var to_target := target - global_position
	var next_position := global_position
	if to_target.length() > 1.0:
		next_position = global_position + to_target.normalized() * speed * delta

	# Design doc §2.2/request: fixed light circles are hard walls a ghost
	# can't cross, but only while actually lit - the altar isn't one of
	# these anymore (no protection function), and a fuel station or
	# escape point that's gone dark (out of charges, or night) stops
	# blocking too.
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


## Design doc §3.3: while not actively chasing, the ghost harasses whatever
## the player is doing instead - scrambling a cast, spoiling the bobber's
## bait, cutting the line (knocking a lure off is a harsher variant of
## this, handled inside Player.cut_line()), or snatching a carried fish.
func _process_interference(delta: float, sense: Dictionary) -> void:
	var cooldown_rate: float = FRENZY_COOLDOWN_MULT if frenzy_timer > 0.0 else 1.0
	if GameState.weather == GameState.Weather.STORM:
		cooldown_rate *= STORM_COOLDOWN_MULT
	interference_cooldown = max(interference_cooldown - delta * cooldown_rate, 0.0)

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

	var bobber_waiting := player.fishing_mode == Player.FishingMode.BOBBER and player.state == Player.State.WAITING
	if interference_cooldown <= 0.0 and bobber_waiting and global_position.distance_to(player.cast_target) <= BAIT_STEAL_RANGE:
		player.spoil_bait()
		interference_cooldown = INTERFERENCE_COOLDOWN
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
	visual.scale = Vector2(0.5, 0.5)
	visual.offset = GHOST_OFFSET
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
