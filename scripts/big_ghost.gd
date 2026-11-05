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
## (a line said - DragonLines; RunView3D puts it over its head)
signal said(text: String)

enum Mode { ASLEEP, WANDER, SUSPICIOUS, CHASE, SEARCH, EAT, GRAB, REST }

## Its body's reach (px): RunView3D's model, 1.9 m deep.
const BODY := 26.0

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

## User request: it comes onto the map when night falls (down out of the sky, roaring) - not before;
## a level (or a curse) can still have it out from a light stage of its own (Campaign.rules.big_wake).
const ACTIVE_FROM_STAGE := -1
const WANDER_SPEED := 34.0
const LOOK_SPEED := 46.0
const CHASE_SPEED := 70.0
const NIGHT_SPEED := 84.0
## Walk this close past it and it comes over to look.
const NOTICE := 90.0
const NIGHT_NOTICE := 130.0
## Lit by the player's lamp within this range, it charges.
const LIT_SIGHT := 260.0
## User request: the red dragon (the forest's - the snowy map's is the black one) finds the
## traveller from RED_SIGHT times as far (passing close, and the lamp on it - its light seen that
## much farther off), and once it has (looking, after them), goes RED_HASTE times as fast.
const RED_SIGHT := 1.5
const RED_HASTE := 1.15
## User request: the black dragon's red lamp lights BLACK_LAMP_REACH times as far as the red one's
## green (its 2D light and so its 3D one); its light on the traveller, they're under stress (Player).
const LAMP_SCALE := 0.45
const BLACK_LAMP_REACH := 1.5
## User request: night falls, the dragon comes - wherever the traveller is: its roar (ROAR_TIME s:
## Sfx "dragon_roar", heard all over the map; its maw open in 3D), the view trembling (main.rumble,
## ROAR_SHAKE), and in the feed 進入暗夜，龍鬼來了...; not out yet, it comes now. Every coming onto
## the map is down out of the sky: DESCEND_TIME s (`descending`) it flies down and lands (RunView3D),
## doing nothing else meanwhile - not after anyone, catching no one.
const ROAR_TIME := 2.6
const ROAR_SHAKE := 2.2
const DESCEND_TIME := 3.3
var descending := 0.0
## (how many times it's come down: RunView3D sets its flight going afresh each one)
var descents := 0
## User request (the user's second lot of moves): come down at nightfall it lands hard and roars
## where it landed (`arriving` s: ARRIVE_LAND, then its roar - one of ROARS, `roar_clip`, as long as
## the clip is), stood, after no one yet; its roar's sound heard all over the map then, the view
## trembling. (`roar_left` of `roar_total` s: its maw open - RunView3D.)
const ARRIVE_LAND := 1.0
const ROARS := ["Roar", "Roar_2", "Roar_3"]
const CAME_SAID := "龍來了……"
const HUNT_SAID := "進入暗夜，龍循著你的氣味追過來了"
## User request (the night's own clock): about the map before the night it's drawn the traveller's
## way - each new place it makes for is near them (NEAR_FROM..NEAR_TO px off, 8-15 m) this share of
## the time, more as the night comes (PATROL_NEAR, at its coming .. at the night).
const PATROL_NEAR := Vector2(0.5, 0.8)
## User request (its words, DragonLines): walking the map before the night, seen on the traveller's
## screen (a new sighting) it may say something - SAY_FIRST the first time, SAY_AGAIN after - or the
## moment it finds them; SAY_GAP s at least between lines, SAY_MOST of them a run (one or the
## other), none twice; SAY_ANY of the time a line anyone might hear. Over its head (RunView3D),
## down the left (GameState.report), a low growl under it.
const SAY_FIRST := 0.3
const SAY_AGAIN := 0.25
const SAY_GAP := 20.0
const SAY_MOST := Vector2i(3, 4)
const SAY_ANY := 0.3
var _said := {}
var _says := 0
var _say_cap := 3
var _said_at := -1.0e9
var _rolled := false
var _was_seen := false
var _clock := 0.0
## (its own dice for its words - the game's draws, seeded, go on as they were)
var say_rng := RandomNumberGenerator.new()
const NEAR_FROM := 216.0
const NEAR_TO := 405.0
var arriving := 0.0
var roar_clip := "Roar"
var roar_left := 0.0
var roar_total := ROAR_TIME
var _roar_due := false
var _arrive_after := false
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
## User request: not free in time, it shows it has them - a moment (CLAIM_TIME s: its wings spread
## wide - RunView3D) before they're taken; nothing frees them then (`claiming`).
const CLAIM_TIME := 1.6
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
var claiming := false
var _claim := 0.0
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
	add_to_group("big_ghost")
	_player = get_tree().current_scene.get_node("Player")
	var tex := CanvasTexture.new()
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
	GameState.night_fell.connect(_on_night_fell)
	GameState.dragon_came.connect(_on_dragon_came)
	GameState.camp_doused.connect(_on_camp_doused)
	Art.place(visual, OFFSET, SPRITE_SCALE)
	lamp_light.texture = LightTextureFactory.make_radial_texture()
	lamp_light.texture_scale = LAMP_SCALE * (1.0 if is_red() else BLACK_LAMP_REACH)
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
		if claiming:
			return
		# The strong light in its face: it lets go.
		_let_go("強光照得大鬼鬆開了手！趁現在逃！")
	stun_timer = maxf(stun_timer, duration)


## The heart, spent by hand while it holds you: it lets go and keeps off.
func escape_with_heart() -> bool:
	if mode != Mode.GRAB or claiming or not GameState.use_heart():
		return false
	_let_go("心臟猛地一跳，震開了大鬼的手！")
	return true


## Seconds left to get free (0 when it isn't holding anyone).
func grip_left() -> float:
	return maxf(_timer, 0.0) if mode == Mode.GRAB and not claiming else 0.0


## Lets the player go: they stagger back, it keeps off a while.
func _let_go(message: String) -> void:
	Campaign.stat("grab_escaped")
	_player.break_free(global_position)
	_timer = REST_TIME
	_set_mode(Mode.REST)
	_pick_wander_target(true)
	GameState.push_message(message)


## Onto the map: somewhere on it at random, away from the traveller - down out of the sky.
func _appear() -> void:
	global_position = _spawn_point()
	_last_pos = global_position
	_set_mode(Mode.WANDER)
	descending = DESCEND_TIME
	descents += 1
	# (at its coming or the nightfall, landed it roars)
	_arrive_after = GameState.is_night or GameState.dragon_out
	roar_clip = ROARS[randi() % ROARS.size()]


## How long roar `clip` is (s) - its clip's, for the model it is (DragonMoves); ROAR_TIME else.
func roar_length(clip: String) -> float:
	var m: Dictionary = DragonMoves.MOVES.get("dragon" if is_red() else "dragon_black", {}).get(clip, {})
	return float(m.get("length", ROAR_TIME))


## Stood where it is, roaring (`land`: first its hard landing's ARRIVE_LAND s).
func _stand_and_roar(land: bool) -> void:
	arriving = (ARRIVE_LAND if land else 0.0) + roar_length(roar_clip)
	_roar_due = true


func _roar_now() -> void:
	_roar_due = false
	roar_total = roar_length(roar_clip)
	roar_left = roar_total
	Sfx.play("dragon_roar", 0.0, 0.0)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("rumble"):
		scene.rumble(minf(roar_total, ROAR_TIME), ROAR_SHAKE)


## User request (the night's own clock): five minutes in (GameState.DRAGON_AT of the day) it comes
## down out of the sky, roars - heard wherever the traveller is - and walks the map, drawn more and
## more their way; out already (a level's own wake), it roars where it stands.
func _on_dragon_came() -> void:
	if _lair == null or GameState.run_over:
		return
	GameState.push_message(CAME_SAID)
	GameState.report(CAME_SAID)
	if mode == Mode.ASLEEP:
		_appear()
	elif mode in [Mode.WANDER, Mode.REST, Mode.SEARCH, Mode.SUSPICIOUS] and descending <= 0.0 and arriving <= 0.0:
		roar_clip = ROARS[randi() % ROARS.size()]
		_stand_and_roar(false)


## User request: three minutes into the hunt it tears into the camp's oil - heard all over the map,
## the view shaking; the hunt goes on, the camp no shelter now (its fire's out - _in_safe_zone).
func _on_camp_doused() -> void:
	if _lair == null or GameState.run_over:
		return
	Sfx.play("dragon_roar", 0.0, 0.0)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("rumble"):
		scene.rumble(ROAR_TIME, ROAR_SHAKE)


## The night: the hunt - it's after the traveller by their scent, never losing them (_start_hunt).
## Not out yet (no day's clock to bring it), it comes down first.
func _on_night_fell() -> void:
	if _lair == null or GameState.run_over:
		return
	GameState.push_message(HUNT_SAID)
	GameState.report(HUNT_SAID)
	_hunt_announced = true
	if mode == Mode.ASLEEP:
		_appear()


## User request (the pistol): a shot heard at `at` - asleep, it wakes;
## wandering, resting or searching, it comes to look there (as when it
## notices someone close). Already after someone, or eating, it carries on.
func hear(at: Vector2) -> void:
	if GameState.run_over or mode in [Mode.CHASE, Mode.EAT, Mode.GRAB]:
		return
	if mode == Mode.ASLEEP:
		GameState.push_message("槍聲在夜裡迴盪...大鬼被吵醒了")
	else:
		GameState.push_message("槍聲驚動了大鬼，牠往這邊來了！")
	GameState.report("槍聲引來了大鬼")
	_target = at
	_timer = LOOK_TIME * 2.0
	_set_mode(Mode.SUSPICIOUS)


func enter_frenzy(duration: float) -> void:
	frenzy_timer = maxf(frenzy_timer, duration)


## How far its lamp's light reaches (px) - the 2D light's radius.
func lamp_reach() -> float:
	var half := 128.0 if lamp_light.texture == null else lamp_light.texture.get_width() * 0.5
	return half * lamp_light.texture_scale


## Is the traveller in its lamp's light (it out on the map, its lamp lit)?
func lamp_on_player() -> bool:
	return _player != null and lamp_light.visible and mode != Mode.ASLEEP \
		and _player.global_position.distance_to(lamp_light.global_position) <= lamp_reach()


func _physics_process(delta: float) -> void:
	frenzy_timer = maxf(frenzy_timer - delta, 0.0)
	_clock += delta
	if _lair == null or GameState.run_over:
		return
	# (the black dragon's red light: stress - Player)
	if not is_red() and lamp_on_player():
		_player.red_lamp_on()
	roar_left = maxf(roar_left - delta, 0.0)
	if descending > 0.0:
		# (coming down out of the sky - nothing else till it's landed)
		descending = maxf(descending - delta, 0.0)
		_last_pos = global_position
		if descending <= 0.0 and _arrive_after:
			_arrive_after = false
			_stand_and_roar(true)
		return
	if arriving > 0.0:
		# (landed at nightfall: its roar, stood where it is)
		arriving = maxf(arriving - delta, 0.0)
		if _roar_due and arriving <= roar_length(roar_clip):
			_roar_now()
		_last_pos = global_position
		return
	if stun_timer > 0.0:
		stun_timer -= delta
		return
	if not GameState.is_night:
		_hunt_announced = false
	elif mode in [Mode.WANDER, Mode.SEARCH, Mode.SUSPICIOUS]:
		_start_hunt()
	# (seen anew on the traveller's screen as it walks the map: it may say something)
	var seen := patrolling() and _on_screen()
	if seen and not _was_seen:
		_maybe_say("far")
	_was_seen = seen
	match mode:
		Mode.ASLEEP:
			# (user request: not on the map at all till it sets out - then
			# somewhere on it at random, away from the traveller)
			global_position = _lair.global_position + HOME
			var wake: int = int(Campaign.rules.big_wake) if int(Campaign.rules.big_wake) >= 0 else ACTIVE_FROM_STAGE
			if GameState.run_started and (GameState.is_night or GameState.dragon_out or (wake >= 0 and GameState.light_stage() >= wake)):
				_appear()
				if not GameState.is_night and not GameState.dragon_out:
					GameState.push_message("遠處傳來鐵鍊拖地的聲音...大鬼出現了")
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
			_move_toward(_target, LOOK_SPEED * haste(), delta)
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
			_amble(_target, LOOK_SPEED, delta)
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
			if claiming:
				_claim -= delta
				if _claim <= 0.0:
					GameState.caught()
			elif _fish_near() != null:
				var fish := _fish_near()
				_player.break_free(global_position)
				_fish = fish
				_timer = EAT_TIME
				_set_mode(Mode.EAT)
				GameState.push_message("大鬼丟下你撲向那條魚！快跑！")
			elif _timer <= 0.0:
				claiming = true
				_claim = CLAIM_TIME


## Is it the red dragon (not the snowy map's black one)?
static func is_red() -> bool:
	return not MapGenerator.current_theme.begins_with("snow")


## How far it sees, as a share of its own (RED_SIGHT for the red one).
static func sight() -> float:
	return RED_SIGHT if is_red() else 1.0


## Its pace after someone, as a share (RED_HASTE for the red one).
static func haste() -> float:
	return RED_HASTE if is_red() else 1.0


## Charging - for as long as the lamp stays on it.
func _chase(delta: float) -> void:
	var speed := (NIGHT_SPEED if GameState.is_night else CHASE_SPEED) * haste()
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
		_move_toward(_target, LOOK_SPEED * haste(), delta)
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
		GameState.push_message(HUNT_SAID)


func _start_search(at: Vector2) -> void:
	_target = at
	_timer = SEARCH_TIME
	_set_mode(Mode.SEARCH)


## Wandering or searching: the lamp on it sets it charging; passing close
## makes it come and look.
func _watch() -> void:
	if _check_fish():
		return
	var walking := patrolling()
	if _lit():
		_start_chase()
		if walking:
			_maybe_say("see")
	elif _near_player():
		_target = _player.global_position
		_timer = LOOK_TIME
		_set_mode(Mode.SUSPICIOUS)
		GameState.push_message("大鬼注意到附近有動靜...")
		if walking:
			_maybe_say("see")


## Walking the map before the night (down, not roaring, not after anyone yet).
func patrolling() -> bool:
	return GameState.dragon_out and not GameState.is_night and not GameState.run_over \
		and mode in [Mode.WANDER, Mode.SEARCH, Mode.SUSPICIOUS, Mode.REST] and descending <= 0.0 and arriving <= 0.0


## On the traveller's screen (its body, in 3D; else where the 2D camera looks).
func _on_screen() -> bool:
	if RunView3D.active != null and is_instance_valid(RunView3D.active):
		return RunView3D.active.dragon_on_screen(self)
	var at := get_viewport().get_canvas_transform() * global_position
	return get_viewport().get_visible_rect().has_point(at)


## Its chance to say something (`kind` "far" or "see" - DragonLines), as the rules above let it.
func _maybe_say(kind: String) -> void:
	if _says >= _say_cap or _clock - _said_at < SAY_GAP:
		return
	var chance := SAY_AGAIN if _rolled else SAY_FIRST
	_rolled = true
	if say_rng.randf() >= chance:
		return
	var line := pick_line(kind)
	if line != "":
		say(line)


## A line not said yet this run: the traveller's own (Profile.character), SAY_ANY of the time one
## anyone might hear ("" when all are said).
func pick_line(kind: String) -> String:
	var own := DragonLines.of(Profile.character, is_red(), kind).filter(func(l): return not _said.has(l))
	var any := DragonLines.of("any", is_red(), kind).filter(func(l): return not _said.has(l))
	if not any.is_empty() and (own.is_empty() or say_rng.randf() < SAY_ANY):
		return any[say_rng.randi() % any.size()]
	return own[say_rng.randi() % own.size()] if not own.is_empty() else ""


func say(line: String) -> void:
	_said[line] = true
	_says += 1
	_said_at = _clock
	said.emit(line)
	Sfx.play("dragon_growl", -6.0, 0.08)
	GameState.report("龍：「%s」" % line)
	if RunView3D.active != null and is_instance_valid(RunView3D.active):
		RunView3D.active.dragon_say(self, line)


func _lit() -> bool:
	var lamp: Lantern = _player.get_node("Lantern")
	return lamp.lit and global_position.distance_to(_player.global_position) <= LIT_SIGHT * sight() \
		and lamp.illuminates(global_position, sight())


func _near_player() -> bool:
	var reach := (NIGHT_NOTICE if GameState.is_night else NOTICE) * sight()
	return global_position.distance_to(_player.global_position) <= reach


func _try_catch() -> void:
	if global_position.distance_to(_player.global_position) <= CATCH_RADIUS and not _player.held \
			and not _player.knocked() and not _in_safe_zone(_player.global_position) and _player.ward_timer <= 0.0:
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
	_amble(_target, WANDER_SPEED, delta)


## User request (its walk natural - an NPC's moves are much of the game's feel): about its own
## business it doesn't turn on a coin. It walks round (AMBLE_TURN rad/s - a big beast's turn, as its
## turns' clips take it); to go back the way it came
## (past AMBLE_PIVOT rad) it stops and turns where it stands (PIVOT_TURN), then goes - as its body,
## in 3D, steps round (DragonGait). After someone it turns as it did (_move_toward).
const AMBLE_TURN := 0.75
const AMBLE_PIVOT := 1.92
const PIVOT_TURN := 3.2
var _heading := Vector2.ZERO
## (it's stood turning round - to `pivot_to`)
var pivoting := false
var pivot_to := Vector2.ZERO
const AMBLE_SPEED_UP := 1.6
var _amble_pace := 0.0


## Which way it faces, stood (RunView3D: as its body in 3D does) - it sets off from there.
func face(dir: Vector2) -> void:
	if dir.length() > 0.01:
		_heading = dir.normalized()


func _amble(target: Vector2, speed: float, delta: float) -> void:
	var to := target - global_position
	if to.length() < 0.5:
		return
	var want := to.normalized()
	if _heading == Vector2.ZERO:
		_heading = want
	var off := _heading.angle_to(want)
	pivoting = absf(off) > AMBLE_PIVOT or (pivoting and absf(off) > 0.35)
	pivot_to = want
	var turn := (PIVOT_TURN if pivoting else AMBLE_TURN) * delta
	_heading = _heading.rotated(clampf(off, -turn, turn)).normalized()
	if pivoting:
		_amble_pace = 0.0
		return
	# (from a stand it gets going over AMBLE_SPEED_UP s, as a big beast does)
	_amble_pace = minf(_amble_pace + speed * delta / AMBLE_SPEED_UP, speed)
	# (where it's headed now, a step on; the way round things, the lit places, as ever)
	_move_toward(global_position + _heading * maxf(speed * delta * 6.0, 8.0), _amble_pace, delta)


## (Solids.detour: the way round something, kept)
var _detour := {}


func _move_toward(target: Vector2, speed: float, delta: float, keep_out := true) -> void:
	# (user report: stuck pressing into the camp from its far side, after
	# someone on the other - round it, and round a lit light)
	var walls := []
	if keep_out:
		for station in get_tree().get_nodes_in_group("fuel_stations"):
			if station.light.visible:
				walls.append([station.global_position, SAFE_RADIUS])
		var lit := get_tree().current_scene.get_node_or_null("EscapePoint")
		if lit != null and lit.get_node("Light").visible:
			walls.append([lit.global_position, SAFE_RADIUS])
	target = Solids.detour(get_tree(), global_position, target, BODY, _detour, walls)
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
	# User request (round 7): the ghost-ward potion keeps it off the player.
	if is_instance_valid(_player) and _player.ward_timer > 0.0:
		var off := next - _player.global_position
		if off.length() < Player.WARD_RADIUS:
			next = _player.global_position + (off.normalized() if off.length() > 0.01 else Vector2.UP) * Player.WARD_RADIUS
	next.x = clampf(next.x, 20.0, Player.WORLD_WIDTH - 20.0)
	next.y = clampf(next.y, 20.0, Player.WORLD_HEIGHT - 20.0)
	# User request (3D): round the trees and rocks, not through them.
	next = Solids.step(get_tree(), global_position, next, BODY)
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


## Where it comes out when it sets out: on dry land, out of the lit
## circles, SPAWN_AWAY px or more from the traveller (the farthest of a
## few tries if none is).
const SPAWN_AWAY := 600.0


func _spawn_point() -> Vector2:
	var best := global_position
	var best_d := -1.0
	for _i in 40:
		var at := Vector2(randf_range(120.0, Player.WORLD_WIDTH - 120.0), randf_range(120.0, Player.WORLD_HEIGHT - 120.0))
		if _in_safe_zone(at) or _wet(at):
			continue
		var d := at.distance_to(_player.global_position) if _player != null else 0.0
		if d >= SPAWN_AWAY:
			return at
		if d > best_d:
			best = at
			best_d = d
	return best


func _wet(pos: Vector2) -> bool:
	for zone in get_tree().get_nodes_in_group("water_zones"):
		if zone.contains(pos):
			return true
	return false


func _pick_wander_target(away_from_player := false) -> void:
	_repick = randf_range(WANDER_REPICK.x, WANDER_REPICK.y)
	if not away_from_player and GameState.dragon_out and not GameState.is_night and _player != null \
			and randf() < lerpf(PATROL_NEAR.x, PATROL_NEAR.y, GameState.patrol_progress()):
		var at: Vector2 = _player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(NEAR_FROM, NEAR_TO)
		_target = Vector2(clampf(at.x, 80.0, Player.WORLD_WIDTH - 80.0), clampf(at.y, 80.0, Player.WORLD_HEIGHT - 80.0))
		return
	for _i in 12:
		_target = Vector2(randf_range(80.0, Player.WORLD_WIDTH - 80.0), randf_range(80.0, Player.WORLD_HEIGHT - 80.0))
		if not away_from_player or _target.distance_to(_player.global_position) > 600.0:
			break


func _set_mode(m: Mode) -> void:
	# Under the character card (user request): it's after you, or you've
	# lost it.
	if m == Mode.GRAB and mode != Mode.GRAB:
		Campaign.stat("grabbed")
	elif m == Mode.EAT and mode != Mode.EAT:
		Campaign.stat("big_ghost_lured")
	if m == Mode.CHASE and mode != Mode.CHASE:
		GameState.report("大鬼盯上你了！")
	elif m in [Mode.WANDER, Mode.REST] and mode in [Mode.CHASE, Mode.SEARCH]:
		GameState.report("甩掉大鬼了", "good")
	mode = m
	_lost = 0.0
	# (stood holding someone, eating, asleep: it sets off again from a stand)
	if m in [Mode.GRAB, Mode.EAT, Mode.ASLEEP]:
		_amble_pace = 0.0
	claiming = false
	mode_changed.emit(Mode.keys()[m])


func _go_home() -> void:
	_lair = get_tree().get_first_node_in_group("ghost_cages") as GhostCage
	_said.clear()
	_says = 0
	_say_cap = say_rng.randi_range(SAY_MOST.x, SAY_MOST.y)
	_said_at = -1.0e9
	_rolled = false
	_was_seen = false
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
	# (asleep it isn't on the map - see _spawn_point)
	visible = mode != Mode.ASLEEP
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
