class_name BigGhost
extends Node2D

## User request: the big ghost (the user's hooded ghoul rising out of a
## smoke cloud, a lantern in one hand and a chain in the other -
## tools/render_characters.py, 8 facings). Unlike the floating ghosts, which
## only get in the way, this one kills: it catches the player, drags them
## off to its cage (GhostCage) and does away with them there - unless
## they're carrying a heart, which is spent to break the cage open. No heart
## and the run is over.
##
## Asleep in its cage for the first quarter of the day, it then wanders the
## map. User request: it doesn't hound the player - it's the light that
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

enum Mode { ASLEEP, WANDER, SUSPICIOUS, CHASE, SEARCH, EAT, CARRY, CAGED, REST }

const SHEET := [preload("res://assets/sprites/big_ghost/big_ghost_55deg_albedo.png"), preload("res://assets/sprites/big_ghost/big_ghost_55deg_normal.png")]
## Drawn larger than the render: it towers over the player.
const SIZE := 1.25
const SPRITE_SCALE := 0.5 * SIZE
## (0, -center_y) * 27.108 for the render's camera.
const OFFSET := Vector2(0.0, -30.39)
## Its lantern per facing (world px from its origin), from the render.
const LAMP := [Vector2(-7.16, -0.88), Vector2(-21.14, -10.48), Vector2(-22.74, -25.37), Vector2(-11.02, -36.82), Vector2(7.16, -38.13), Vector2(21.14, -28.53), Vector2(22.74, -13.64), Vector2(11.02, -2.19)]
const DIRS := 8
## Sheet column by 45deg sector clockwise from +X (same order as the player).
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]
const HOVER := 4.0
## Where it waits by its cage: beside it, so the cage stays in view.
const HOME := Vector2(40.0, 12.0)
const BOB := 2.0

const ACTIVE_FROM_STAGE := 1
const WANDER_SPEED := 34.0
const LOOK_SPEED := 46.0
const CHASE_SPEED := 70.0
const NIGHT_SPEED := 84.0
const CARRY_SPEED := 64.0
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
const CAGE_TIME := 3.2
## After a heart breaks the cage open it keeps away this long.
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
var _cage: GhostCage
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
	visual.hframes = DIRS
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
	# Not while it has the player in hand or caged, nor asleep.
	if mode not in [Mode.ASLEEP, Mode.CARRY, Mode.CAGED]:
		stun_timer = maxf(stun_timer, duration)


func enter_frenzy(duration: float) -> void:
	frenzy_timer = maxf(frenzy_timer, duration)


func _physics_process(delta: float) -> void:
	frenzy_timer = maxf(frenzy_timer - delta, 0.0)
	if _cage == null or GameState.run_over:
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
			global_position = _cage.global_position + HOME
			if GameState.run_started and (GameState.is_night or GameState.light_stage() >= ACTIVE_FROM_STAGE):
				_set_mode(Mode.WANDER)
				GameState.push_message("遠處傳來鐵鍊拖地的聲音...大鬼出籠了")
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
				_bob += delta * 3.0  # gnawing
				if _timer <= 0.0:
					_fish.eaten()
					_fed()
		Mode.CARRY:
			var to_cage := _cage.global_position + HOME - global_position
			if to_cage.length() < 6.0:
				_cage.lock(_player)
				_timer = CAGE_TIME
				_set_mode(Mode.CAGED)
				GameState.push_message("你被大鬼關進了籠子...")
			else:
				_move_toward(global_position + to_cage, CARRY_SPEED, delta, false)
				_player.global_position = global_position + Vector2(0, 4)
		Mode.CAGED:
			_timer -= delta
			if fmod(_timer, 0.9) < delta:
				_cage.rattle()
			if _timer <= 0.0:
				if GameState.use_heart():
					_cage.unlock()
					_player.release()
					GameState.push_message("心臟救了你一命！籠門被震開了，大鬼一時退開")
					_timer = REST_TIME
					_set_mode(Mode.REST)
					_pick_wander_target(true)
				else:
					GameState.end_run(false, "被大鬼關進籠子殺死了")


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
			and not _in_safe_zone(_player.global_position):
		_player.seize()
		_set_mode(Mode.CARRY)
		GameState.push_message("大鬼抓住你了！牠要把你拖回籠子！")


## User request: a fish thrown its way (the drop-fish button) draws it off.
func _check_fish() -> bool:
	var best: Node2D = null
	var best_d := FISH_SMELL
	for fish in get_tree().get_nodes_in_group("dropped_fish"):
		var d := global_position.distance_to(fish.global_position)
		if d < best_d:
			best_d = d
			best = fish
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
		var sector := posmod(roundi(moved.angle() / (PI / 4.0)), 8)
		_dir = SECTOR_TO_DIR[sector]
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
	_cage = get_tree().get_first_node_in_group("ghost_cages") as GhostCage
	mode = Mode.ASLEEP
	stun_timer = 0.0
	if _cage != null:
		global_position = _cage.global_position + HOME


## A new run (the debug reset restarts in place): back to its cage.
func _on_day_phase(phase: String) -> void:
	if phase == "FISHING" and mode != Mode.ASLEEP and not GameState.run_over:
		if _cage != null and _cage.prisoner != null:
			_cage.unlock()
		_player.release()
		_go_home()


func _process(delta: float) -> void:
	_bob += delta
	var lift := -HOVER - sin(_bob * 1.7) * BOB
	visual.frame = _dir
	visual.position = Vector2(0, lift)
	visual.modulate = TINT_STUNNED if stun_timer > 0.0 else TINT
	var lamp: Vector2 = LAMP[_dir] * SIZE + Vector2(0, lift)
	lamp_light.position = lamp
	glow.position = lamp
	var flicker := 1.0 + sin(_bob * 9.0) * 0.06 + sin(_bob * 23.0) * 0.04
	lamp_light.energy = 0.9 * flicker
	glow.scale = Vector2.ONE * 0.3 * flicker
	# Sleeping in its cage it's dark; its lamp only lights once it's out.
	var awake := mode != Mode.ASLEEP
	lamp_light.visible = awake
	glow.visible = awake
