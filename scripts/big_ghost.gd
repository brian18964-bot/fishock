class_name BigGhost
extends Node2D

## User request: the big ghost (the user's hooded ghoul rising out of a
## smoke cloud, a lantern in one hand and a chain in the other -
## tools/render_characters.py, 8 facings). Unlike the floating ghosts, which
## only get in the way, this one kills. User request (Camp v2): it seizes
## the player where they stand and the player has GRAB_TIME seconds to
## struggle free - the heart (spent by hand: the HUD's button), the strong
## light in its face, or a fish thrown to it (誘惑). Free, the player
## staggers back and it keeps off a while; not free in time, the run is
## lost - the player wakes back at the camp, shaken (spirit down).
##
## Asleep in its lair (GhostCage) for the first quarter of the day, it then
## wanders the map. User request: it doesn't hound the player - it's the light that
## draws it. Walk close past it and it comes over to look (and grabs you if
## you let it reach you); keep your lamp on it and it charges, and keeps
## coming as long as the light stays on it. Out of the light for a couple
## of seconds, it loses you, searches about, and goes back to wandering.
## It can't cross into a lit fuel station's or escape point's circle, and
## the strong light stuns it like any ghost. User request: or throw it a
## fish (the drop-fish button tosses one ahead): it goes and eats it, and
## leaves you be for a while. Its own lantern glows, so it's seen coming.
## User request: when the time runs out and night falls, it comes for you -
## it hunts the player down wherever they are, light or no light (a thrown
## fish or the strong light still hold it off for a while).

signal mode_changed(mode: String)

enum Mode { ASLEEP, WANDER, SUSPICIOUS, CHASE, SEARCH, EAT, GRAB, REST }

const SHEET := [preload("res://assets/sprites/big_ghost/big_ghost_55deg_albedo.png"), preload("res://assets/sprites/big_ghost/big_ghost_55deg_normal.png")]
## User feedback: it was stiff - one still pose per facing. It moves now
## (tools/render_big_ghost.py - clips from the user's animation library
## laid over the sculpt's own pose): swaying and lolling as it floats about,
## lurching forward when it charges or carries you off, gnawing a thrown
## fish, its smoke churning all the while. Cells run clip by clip, facing by
## facing (Art.facing8), frame by frame, COLS to a row.
const CLIPS := {"float": 8, "chase": 8, "eat": 6}
const CLIP_FPS := {"float": 7.0, "chase": 11.0, "eat": 9.0}
const COLS := 16
## Its lantern per cell (world px from its origin at scale 0.5), from the
## render - it swings with the hand that holds it.
const META := "res://assets/sprites/big_ghost/big_ghost_meta.json"
## Drawn larger than the render: it towers over the player.
const SIZE := 1.25
const SPRITE_SCALE := 0.5 * SIZE
## (0, -center_y) * 27.108 for the render's camera.
const OFFSET := Vector2(0.0, -26.11)
const DIRS := 8
const HOVER := 4.0
## Where it sleeps, from its lair's mark.
const HOME := Vector2(40.0, 12.0)
const BOB := 2.0

const ACTIVE_FROM_STAGE := 1
const WANDER_SPEED := 34.0
const LOOK_SPEED := 46.0
const CHASE_SPEED := 70.0
const NIGHT_SPEED := 84.0
## Walk this close past it and it comes over to look.
const NOTICE := 90.0
const NIGHT_NOTICE := 130.0
## Lit by the player's lamp within this range, it charges.
const LIT_SIGHT := 260.0
## Out of the light this long, it has lost the player.
const LOSE_TIME := 2.0
const LOOK_TIME := 3.0
const SEARCH_TIME := 3.5
const CATCH_RADIUS := 16.0
## A dropped fish this near draws it off to eat.
const FISH_SMELL := 240.0
const EAT_TIME := 4.0
## Full, it leaves the player alone this long.
const FED_TIME := 14.0
## Caught: this long to get free.
const GRAB_TIME := 4.0
## Shaken off, it keeps away this long.
const REST_TIME := 18.0
const WANDER_REPICK := Vector2(7.0, 13.0)
const SAFE_RADIUS := 85.0
const LAMP_COLOR := Color(0.55, 1.0, 0.6)
const TINT := Color(0.9, 0.95, 0.9, 0.93)
const TINT_STUNNED := Color(1.0, 0.95, 0.5, 0.9)

var mode := Mode.ASLEEP
## GameState and the flash treat it like any ghost ("ghosts" group).
var frenzy_timer := 0.0
var stun_timer := 0.0

var _target := Vector2.ZERO
var _repick := 0.0
var _lost := 0.0
## The night hunt's been announced (once a night).
var _hunt_announced := false
var _fish: Node2D
var _timer := 0.0
var _dir := 0
var _bob := 0.0
var _anim := 0.0
var _speed := 0.0
var _last_pos := Vector2.ZERO
static var _lamps: Array = []
var _lair: GhostCage
var _player: Player

@onready var visual: Sprite2D = $Visual
@onready var lamp_light: PointLight2D = $LampLight
@onready var glow: Sprite2D = $Glow


func _ready() -> void:
	add_to_group("ghosts")
	_player = get_tree().current_scene.get_node("Player")
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	visual.texture = tex
	var cells := 0
	for n in CLIPS.values():
		cells += n * DIRS
	visual.hframes = COLS
	visual.vframes = ceili(float(cells) / COLS)
	if _lamps.is_empty():
		var meta = JSON.parse_string(FileAccess.get_file_as_string(META))
		for p in meta.lamp:
			_lamps.append(Vector2(p[0], p[1]))
	_last_pos = global_position
	Art.place(visual, OFFSET, SPRITE_SCALE)
	lamp_light.texture = LightTextureFactory.make_radial_texture()
	lamp_light.texture_scale = 0.45
	lamp_light.color = LAMP_COLOR
	lamp_light.energy = 0.9
	lamp_light.height = Lantern.LIGHT_HEIGHT
	LightTwin.attach(lamp_light, false)
	glow.texture = LightTextureFactory.make_radial_texture(64, 0.5)
	glow.scale = Vector2(0.3, 0.3)
	glow.modulate = Color(LAMP_COLOR, 0.8)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = add
	GameState.day_phase_changed.connect(_on_day_phase)
	_go_home.call_deferred()


func stun(duration: float) -> void:
	if mode == Mode.ASLEEP:
		return
	if mode == Mode.GRAB:
		# The strong light in its face: it lets go.
		_let_go("強光照得大鬼鬆開了手！趁現在逃！")
	stun_timer = maxf(stun_timer, duration)


## The heart, spent by hand while it holds you: it lets go and keeps off.
func escape_with_heart() -> bool:
	if mode != Mode.GRAB or not GameState.use_heart():
		return false
	_let_go("心臟猛地一跳，震開了大鬼的手！")
	return true


## Seconds left to get free (0 when it isn't holding anyone).
func grip_left() -> float:
	return maxf(_timer, 0.0) if mode == Mode.GRAB else 0.0


## Lets the player go: they stagger back, it keeps off a while.
func _let_go(message: String) -> void:
	_player.break_free(global_position)
	_timer = REST_TIME
	_set_mode(Mode.REST)
	_pick_wander_target(true)
	GameState.push_message(message)


func enter_frenzy(duration: float) -> void:
	frenzy_timer = maxf(frenzy_timer, duration)


func _physics_process(delta: float) -> void:
	frenzy_timer = maxf(frenzy_timer - delta, 0.0)
	if _lair == null or GameState.run_over:
		return
	if stun_timer > 0.0:
		stun_timer -= delta
		return
	if not GameState.is_night:
		_hunt_announced = false
	elif mode in [Mode.WANDER, Mode.SEARCH, Mode.SUSPICIOUS]:
		_start_hunt()
	match mode:
		Mode.ASLEEP:
			global_position = _lair.global_position + HOME
			if GameState.run_started and (GameState.is_night or GameState.light_stage() >= ACTIVE_FROM_STAGE):
				_set_mode(Mode.WANDER)
				GameState.push_message("遠處傳來鐵鍊拖地的聲音...大鬼醒了")
		Mode.WANDER, Mode.REST:
			if mode == Mode.REST:
				_timer -= delta
				if _timer <= 0.0:
					_set_mode(Mode.WANDER)
			_roam(delta)
			if mode == Mode.WANDER:
				_watch()
		Mode.SUSPICIOUS:
			_timer -= delta
			if _near_player():
				_target = _player.global_position
				_timer = LOOK_TIME
			_move_toward(_target, LOOK_SPEED, delta)
			_try_catch()
			if mode == Mode.SUSPICIOUS:
				if _lit():
					_start_chase()
				elif _timer <= 0.0 or global_position.distance_to(_target) < 8.0:
					_start_search(_target)
			if mode == Mode.SUSPICIOUS:
				_check_fish()
		Mode.CHASE:
			_chase(delta)
			if mode == Mode.CHASE:
				_check_fish()
		Mode.SEARCH:
			_timer -= delta
			_move_toward(_target, LOOK_SPEED, delta)
			_watch()
			if mode == Mode.SEARCH and _timer <= 0.0:
				_set_mode(Mode.WANDER)
		Mode.EAT:
			if not is_instance_valid(_fish) or not _fish.is_in_group("dropped_fish"):
				# Picked back up before it got there: nothing eaten.
				_fish = null
				_set_mode(Mode.WANDER)
			elif global_position.distance_to(_fish.global_position) > 6.0:
				_move_toward(_fish.global_position, CHASE_SPEED, delta, false)
			else:
				_timer -= delta
				if _timer <= 0.0:
					_fish.eaten()
					_fed()
		Mode.GRAB:
			# Holding the player fast: a fish thrown to it, it drops them for
			# that; time up, they're taken.
			_timer -= delta
			_dir = Art.facing8(_player.global_position - global_position, _dir)
			if _fish_near() != null:
				var fish := _fish_near()
				_player.break_free(global_position)
				_fish = fish
				_timer = EAT_TIME
				_set_mode(Mode.EAT)
				GameState.push_message("大鬼丟下你撲向那條魚！快跑！")
			elif _timer <= 0.0:
				GameState.caught()


## Charging - for as long as the lamp stays on it.
func _chase(delta: float) -> void:
	var speed := NIGHT_SPEED if GameState.is_night else CHASE_SPEED
	if frenzy_timer > 0.0:
		speed *= 1.25
	if GameState.is_night:
		# The night hunt: straight for the player, never losing them.
		_target = _player.global_position
		_move_toward(_target, speed, delta)
		_try_catch()
		return
	# Only while the light is on it does it home in on the player; out of
	# it, it slows to a prowl towards where the light last was.
	if _lit():
		_lost = 0.0
		_target = _player.global_position
		_move_toward(_target, speed, delta)
	else:
		_lost += delta
		_move_toward(_target, LOOK_SPEED, delta)
	_try_catch()
	if mode == Mode.CHASE and _lost >= LOSE_TIME:
		GameState.push_message("大鬼失去了你的蹤影")
		_start_search(_target)


func _start_chase() -> void:
	_target = _player.global_position
	_lost = 0.0
	_set_mode(Mode.CHASE)
	GameState.push_message("大鬼被燈光吸引，衝過來了！把燈移開或熄掉就能甩掉牠")


func _start_hunt() -> void:
	_target = _player.global_position
	_lost = 0.0
	_set_mode(Mode.CHASE)
	if not _hunt_announced:
		_hunt_announced = true
		GameState.push_message("大鬼循著你的氣味直直追過來了！丟魚或強光能拖住牠")


func _start_search(at: Vector2) -> void:
	_target = at
	_timer = SEARCH_TIME
	_set_mode(Mode.SEARCH)


## Wandering or searching: the lamp on it sets it charging; passing close
## makes it come and look.
func _watch() -> void:
	if _check_fish():
		return
	if _lit():
		_start_chase()
	elif _near_player():
		_target = _player.global_position
		_timer = LOOK_TIME
		_set_mode(Mode.SUSPICIOUS)
		GameState.push_message("大鬼注意到附近有動靜...")


func _lit() -> bool:
	var lamp: Lantern = _player.get_node("Lantern")
	return lamp.lit and global_position.distance_to(_player.global_position) <= LIT_SIGHT \
		and lamp.illuminates(global_position)


func _near_player() -> bool:
	var reach := NIGHT_NOTICE if GameState.is_night else NOTICE
	return global_position.distance_to(_player.global_position) <= reach


func _try_catch() -> void:
	if global_position.distance_to(_player.global_position) <= CATCH_RADIUS and not _player.held \
			and not _player.knocked() and not _in_safe_zone(_player.global_position):
		_player.seize(global_position)
		_timer = GRAB_TIME
		_set_mode(Mode.GRAB)
		GameState.push_message("大鬼抓住你了！快掙脫——心臟、強光、或丟魚給牠！")


## The nearest dropped fish it can smell, or null.
func _fish_near() -> Node2D:
	var best: Node2D = null
	var best_d := FISH_SMELL
	for fish in get_tree().get_nodes_in_group("dropped_fish"):
		var d := global_position.distance_to(fish.global_position)
		if d < best_d:
			best_d = d
			best = fish
	return best


## User request: a fish thrown its way (the drop-fish button) draws it off.
func _check_fish() -> bool:
	var best := _fish_near()
	if best == null:
		return false
	_fish = best
	_timer = EAT_TIME
	_set_mode(Mode.EAT)
	GameState.push_message("大鬼被丟下的魚吸引過去，大口啃了起來...")
	return true


func _fed() -> void:
	_fish = null
	_timer = FED_TIME
	_set_mode(Mode.REST)
	_pick_wander_target(true)


func _roam(delta: float) -> void:
	_repick -= delta
	if _repick <= 0.0 or global_position.distance_to(_target) < 12.0:
		_pick_wander_target()
	_move_toward(_target, WANDER_SPEED, delta)


func _move_toward(target: Vector2, speed: float, delta: float, keep_out := true) -> void:
	var to := target - global_position
	if to.length() < 0.5:
		return
	var step := to.normalized() * minf(speed * delta, to.length())
	var next := global_position + step
	if keep_out:
		for station in get_tree().get_nodes_in_group("fuel_stations"):
			if station.light.visible:
				next = _outside(next, station.global_position)
		var escape := get_tree().current_scene.get_node_or_null("EscapePoint")
		if escape != null and escape.get_node("Light").visible:
			next = _outside(next, escape.global_position)
	next.x = clampf(next.x, 20.0, Player.WORLD_WIDTH - 20.0)
	next.y = clampf(next.y, 20.0, Player.WORLD_HEIGHT - 20.0)
	var moved := next - global_position
	if moved.length() > 0.01:
		_dir = Art.facing8(moved, _dir)
	global_position = next


func _outside(pos: Vector2, center: Vector2) -> Vector2:
	var off := pos - center
	if off.length() < SAFE_RADIUS:
		return center + (off.normalized() if off.length() > 0.01 else Vector2.UP) * SAFE_RADIUS
	return pos


func _in_safe_zone(pos: Vector2) -> bool:
	for station in get_tree().get_nodes_in_group("fuel_stations"):
		if station.light.visible and pos.distance_to(station.global_position) < SAFE_RADIUS:
			return true
	return false


func _pick_wander_target(away_from_player := false) -> void:
	_repick = randf_range(WANDER_REPICK.x, WANDER_REPICK.y)
	for _i in 12:
		_target = Vector2(randf_range(80.0, Player.WORLD_WIDTH - 80.0), randf_range(80.0, Player.WORLD_HEIGHT - 80.0))
		if not away_from_player or _target.distance_to(_player.global_position) > 600.0:
			break


func _set_mode(m: Mode) -> void:
	mode = m
	_lost = 0.0
	mode_changed.emit(Mode.keys()[m])


func _go_home() -> void:
	_lair = get_tree().get_first_node_in_group("ghost_cages") as GhostCage
	mode = Mode.ASLEEP
	stun_timer = 0.0
	if _lair != null:
		global_position = _lair.global_position + HOME


## A new run (the debug reset restarts in place): back to its lair.
func _on_day_phase(phase: String) -> void:
	if phase == "FISHING" and mode != Mode.ASLEEP and not GameState.run_over:
		_player.release()
		_go_home()


func _process(delta: float) -> void:
	_bob += delta
	# Smoothed: it moves on physics ticks, which don't line up with frames.
	var step := global_position.distance_to(_last_pos) / maxf(delta, 0.001)
	_last_pos = global_position
	_speed = lerpf(_speed, minf(step, NIGHT_SPEED * 2.0), minf(delta * 6.0, 1.0))
	var clip := "float"
	if mode == Mode.EAT:
		var at_fish := is_instance_valid(_fish) and global_position.distance_to(_fish.global_position) <= 6.5
		clip = "eat" if at_fish else "chase"
	elif mode in [Mode.CHASE, Mode.GRAB]:
		clip = "chase"
	var fps: float = CLIP_FPS[clip]
	if mode == Mode.GRAB:
		# Wrestling with its catch.
		fps *= 0.8
	elif clip == "chase":
		# The lurch keeps pace with how fast it's actually going.
		fps *= clampf(_speed / CHASE_SPEED, 0.6, 1.4)
	_anim += delta * fps
	var cell := 0
	for name in CLIPS:
		if name == clip:
			break
		cell += CLIPS[name] * DIRS
	var frames: int = CLIPS[clip]
	cell += _dir * frames + int(_anim) % frames
	var lift := -HOVER - sin(_bob * 1.7) * BOB
	visual.frame = cell
	visual.position = Vector2(0, lift)
	visual.modulate = TINT_STUNNED if stun_timer > 0.0 else TINT
	var lamp: Vector2 = _lamps[cell] * SIZE + Vector2(0, lift)
	lamp_light.position = lamp
	glow.position = lamp
	var flicker := 1.0 + sin(_bob * 9.0) * 0.06 + sin(_bob * 23.0) * 0.04
	lamp_light.energy = 0.9 * flicker
	glow.scale = Vector2.ONE * 0.3 * flicker
	# Asleep it's dark; its lamp only lights once it's out.
	var awake := mode != Mode.ASLEEP
	lamp_light.visible = awake
	glow.visible = awake
