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
## Art: 55deg sprite sheets from tools/render_animals.py - `frames` a clip
## (12 critters, 16 ambient), cells clip by clip, facing by facing, frame
## by frame, `cols` to a row; clip 0 moves, clip 1 idles, `flee_clip` runs.
## User feedback: they walked stiffly - they turn through 8 facings now: 5
## rendered (ROWS), the right-hand three drawn as the left-hand ones
## mirrored (flip_h mirrors the normal map with the picture, so the light
## still falls right).

const SPRITE_SCALE := 0.5
const ROWS := 5
## Art.facing8 index -> [rendered row, mirrored].
const FACING_ROW := [[0, false], [1, false], [2, false], [3, false], [4, false], [3, true], [2, true], [1, true]]

const FLEE_RADIUS := 70.0
const CALM_RADIUS := 140.0
const WANDER_RADIUS := 90.0
const RESPAWN_DELAY := 30.0
const MARGIN := 80.0
## User request: the ones you can catch for bait drawn 20% smaller.
const BAIT_SIZE := 0.8

## offset: ground point relative to one cell's center (-center_y * 27.108).
## move_fps / idle_fps: 8 samples over each clip's 24fps loop length.
## size: extra draw scale - user feedback: the small ones (frog, spider,
## wasp) were hard to spot on a phone, drawn at least ~20 px now.
## bait: the live bait (Profile.LIVE_BAITS) it goes in the bag as when
## caught (round 8, user request - was a flavor for the next cast).
## shore_only: only turns up where a map style puts it along the water
## (MapGenerator "shore_critters") - never dealt at random, and comes back
## as itself, on a shore. sideways: walks side-on, as crabs do.
const SPECIES := {
	# Round 8 (user request): the rat, frog, snake and bee are the user's
	# models now (tools/prep_critters.py), and the grasshopper turns up too.
	"rat": {"label": "老鼠", "bait": "rat",
		"albedo": preload("res://assets/sprites/critter/rat_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/rat_55deg_normal.png"),
		"frames": 12, "cols": 39, "clips": 2, "offset": Vector2(0, -5.42), "move_fps": 24.0, "idle_fps": 5.05,
		"wander_speed": 45.0, "flee_speed": 120.0},
	"frog": {"label": "青蛙", "bait": "frog",
		"albedo": preload("res://assets/sprites/critter/frog_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/frog_55deg_normal.png"),
		"frames": 12, "cols": 64, "clips": 2, "offset": Vector2(0, -2.27), "move_fps": 13.85, "idle_fps": 4.8, "size": 1.3,
		"wander_speed": 35.0, "flee_speed": 95.0},
	# User request (round 8): snakes and bees may poison too (venom: the
	# chance a catch is bitten or stung).
	"snake": {"label": "蛇", "bait": "snake", "venom": 0.3,
		"albedo": preload("res://assets/sprites/critter/snake_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/snake_55deg_normal.png"),
		"frames": 12, "cols": 85, "clips": 2, "offset": Vector2(0, -0.42), "move_fps": 12.0, "idle_fps": 12.0,
		"wander_speed": 30.0, "flee_speed": 85.0},
	"spider": {"label": "蜘蛛", "bait": "spider",
		"albedo": preload("res://assets/sprites/critter/spider_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/spider_55deg_normal.png"),
		"frames": 12, "cols": 73, "clips": 2, "offset": Vector2(0, -0.81), "move_fps": 14.4, "idle_fps": 2.88, "size": 1.3,
		"wander_speed": 40.0, "flee_speed": 110.0},
	# User request: the beach style's crab (tools/render_crab.py).
	"crab": {"label": "螃蟹", "bait": "crab", "shore_only": true, "sideways": true,
		"albedo": preload("res://assets/sprites/critter/crab_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/crab_55deg_normal.png"),
		"frames": 8, "cols": 73, "clips": 2, "offset": Vector2(0, -5.02), "move_fps": 16.0, "idle_fps": 5.71,
		"size": 1.25, "wander_speed": 34.0, "flee_speed": 100.0},
	# One clip (flying) for both moving and hovering; floats above the ground.
	"wasp": {"label": "蜜蜂", "bait": "bee", "venom": 0.25, "sting": true,
		"albedo": preload("res://assets/sprites/critter/wasp_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/wasp_55deg_normal.png"),
		"frames": 12, "cols": 60, "clips": 1, "offset": Vector2(0, -3.62), "move_fps": 12.0, "idle_fps": 12.0, "size": 1.6,
		"wander_speed": 40.0, "flee_speed": 115.0, "hover": 14.0},
	# User request (round 8): grasshoppers can be caught on the map (the
	# 蚱蜢 bait the shop sells).
	"grasshopper": {"label": "蚱蜢", "bait": "cricket",
		"albedo": preload("res://assets/sprites/critter/grasshopper_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/critter/grasshopper_55deg_normal.png"),
		"frames": 12, "cols": 120, "clips": 2, "offset": Vector2(0, -5.19), "move_fps": 18.0, "idle_fps": 12.0, "size": 1.5,
		"wander_speed": 36.0, "flee_speed": 110.0},

	# User request: the real black spider (tools/prep_black_spider.py) - in
	# 8 colourings, one drawn at random (skins: a picture sheet each over
	# one normal sheet). Good bait (two of it, Player.BLACK_SPIDER_BAIT)
	# but its bite may poison (venom, see Player._catch_critter). Also turns
	# up under rocks and out of chopped trees (spawn_black_spider).
	"black_spider": {"label": "黑蜘蛛", "bait": "black_spider", "venom": 0.35,
		"albedo": "res://assets/sprites/critter/black_spider_1_55deg_albedo.png",
		"skins": ["res://assets/sprites/critter/black_spider_1_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_2_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_3_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_4_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_5_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_6_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_7_55deg_albedo.png",
			"res://assets/sprites/critter/black_spider_8_55deg_albedo.png"],
		"normal": "res://assets/sprites/critter/black_spider_55deg_normal.png",
		"frames": 12, "cols": 56, "clips": 2, "offset": Vector2(0, -5.79), "move_fps": 10.0, "idle_fps": 6.0,
		"size": 1.3, "wander_speed": 38.0, "flee_speed": 105.0},

	# Ambient animals: not catchable. Grazers and dogs ignore the player
	# (flee_speed 0); deer, stag, fox and wolf bolt at a gallop, faster than the
	# player can follow.
	"cow": {"label": "牛", "ambient": true, "frames": 16, "cols": 34,
		"albedo": "res://assets/sprites/animal/cow_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/cow_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -18.25), "move_fps": 13.71, "idle_fps": 2.67,
		"wander_speed": 18.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"bull": {"label": "公牛", "ambient": true, "frames": 16, "cols": 34,
		"albedo": "res://assets/sprites/animal/bull_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/bull_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -18.42), "move_fps": 13.71, "idle_fps": 2.67,
		"wander_speed": 18.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"donkey": {"label": "驢子", "ambient": true, "frames": 16, "cols": 46,
		"albedo": "res://assets/sprites/animal/donkey_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/donkey_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -15.13), "move_fps": 13.71, "idle_fps": 2.67,
		"wander_speed": 20.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"alpaca": {"label": "羊駝", "ambient": true, "frames": 16, "cols": 39,
		"albedo": "res://assets/sprites/animal/alpaca_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/alpaca_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -15.24), "move_fps": 10.97, "idle_fps": 2.13,
		"wander_speed": 20.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"deer": {"label": "鹿", "ambient": true, "frames": 16, "cols": 42,
		"albedo": "res://assets/sprites/animal/deer_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/deer_55deg_normal.png",
		"clips": 3, "offset": Vector2(0, -19.1), "move_fps": 13.71, "idle_fps": 2.67,
		"flee_fps": 32.0, "flee_clip": 2, "flee_radius": 120.0, "calm_radius": 260.0,
		"wander_speed": 28.0, "flee_speed": 170.0, "idle_time": Vector2(3, 8)},
	"horse": {"label": "馬", "ambient": true, "frames": 16, "cols": 34,
		"albedo": "res://assets/sprites/animal/horse_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/horse_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -21.77), "move_fps": 13.71, "idle_fps": 2.67,
		"wander_speed": 22.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"stag": {"label": "雄鹿", "ambient": true, "frames": 16, "cols": 39,
		"albedo": "res://assets/sprites/animal/stag_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/stag_55deg_normal.png",
		"clips": 3, "offset": Vector2(0, -22.28), "move_fps": 13.71, "idle_fps": 4.8,
		"flee_fps": 32.0, "flee_clip": 2, "flee_radius": 120.0, "calm_radius": 260.0,
		"wander_speed": 28.0, "flee_speed": 170.0, "idle_time": Vector2(3, 8)},
	"fox": {"label": "狐狸", "ambient": true, "frames": 16, "cols": 73,
		"albedo": "res://assets/sprites/animal/fox_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/fox_55deg_normal.png",
		"clips": 3, "offset": Vector2(0, -7.87), "move_fps": 15.36, "idle_fps": 4.8,
		"flee_fps": 29.54, "flee_clip": 2, "flee_radius": 100.0, "calm_radius": 220.0,
		"wander_speed": 32.0, "flee_speed": 160.0, "idle_time": Vector2(2, 6)},
	# User decision: dogs trot after the player for a little while when
	# they come close (just company - no game effect).
	"husky": {"label": "哈士奇", "ambient": true, "frames": 16, "cols": 64, "follow": true,
		"albedo": "res://assets/sprites/animal/husky_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/husky_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -10.38), "move_fps": 15.36, "idle_fps": 4.8,
		"wander_speed": 34.0, "flee_speed": 0.0, "idle_time": Vector2(2, 6)},
	"shiba": {"label": "柴犬", "ambient": true, "frames": 16, "cols": 85, "follow": true,
		"albedo": "res://assets/sprites/animal/shiba_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/shiba_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -8.23), "move_fps": 15.36, "idle_fps": 4.8,
		"wander_speed": 34.0, "flee_speed": 0.0, "idle_time": Vector2(2, 6)},
	# User decision: wolves (and the meat-eating dinosaurs below) hunt the
	# player - see Mode.CHASE. flee_speed is only used when scared off.
	"wolf": {"label": "狼", "ambient": true, "frames": 16, "cols": 56,
		"albedo": "res://assets/sprites/animal/wolf_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/wolf_55deg_normal.png",
		"clips": 3, "offset": Vector2(0, -10.74), "move_fps": 15.36, "idle_fps": 4.8,
		"flee_fps": 29.54, "flee_clip": 2,
		"chase_radius": 150.0, "chase_speed": 118.0,
		"wander_speed": 32.0, "flee_speed": 160.0, "idle_time": Vector2(2, 6)},
	"white_horse": {"label": "白馬", "ambient": true, "frames": 16, "cols": 34,
		"albedo": "res://assets/sprites/animal/white_horse_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/white_horse_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -21.77), "move_fps": 13.71, "idle_fps": 2.67,
		"wander_speed": 22.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	# Dinosaurs (prehistoric maps only): scaled well below life size so they
	# fit the screen. Plant-eaters are slow, unbothered wanderers; the T-rex
	# and raptor hunt like wolves. The sauropod's 125-frame walk plays ~1.7x
	# fast.
	"stegosaurus": {"label": "劍龍", "ambient": true, "frames": 16, "cols": 18,
		"albedo": "res://assets/sprites/animal/stegosaurus_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/stegosaurus_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -10.16), "move_fps": 5.49, "idle_fps": 6.3,
		"wander_speed": 16.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"apatosaurus": {"label": "迷惑龍", "ambient": true, "frames": 16, "cols": 14,
		"albedo": "res://assets/sprites/animal/apatosaurus_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/apatosaurus_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -15.42), "move_fps": 3.07, "idle_fps": 3.76,
		"wander_speed": 14.0, "flee_speed": 0.0, "idle_time": Vector2(5, 12)},
	"parasaurolophus": {"label": "副櫛龍", "ambient": true, "frames": 16, "cols": 28,
		"albedo": "res://assets/sprites/animal/parasaurolophus_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/parasaurolophus_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -15.57), "move_fps": 13.71, "idle_fps": 6.4,
		"wander_speed": 24.0, "flee_speed": 0.0, "idle_time": Vector2(3, 8)},
	"trex": {"label": "暴龍", "ambient": true, "frames": 16, "cols": 16,
		"albedo": "res://assets/sprites/animal/trex_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/trex_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -35.69), "move_fps": 11.64, "idle_fps": 6.4,
		"chase_radius": 170.0, "chase_speed": 96.0,
		"wander_speed": 20.0, "flee_speed": 110.0, "idle_time": Vector2(4, 10)},
	"triceratops": {"label": "三角龍", "ambient": true, "frames": 16, "cols": 23,
		"albedo": "res://assets/sprites/animal/triceratops_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/triceratops_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -11.39), "move_fps": 5.49, "idle_fps": 6.3,
		"wander_speed": 14.0, "flee_speed": 0.0, "idle_time": Vector2(4, 10)},
	"velociraptor": {"label": "迅猛龍", "ambient": true, "frames": 16, "cols": 34,
		"albedo": "res://assets/sprites/animal/velociraptor_55deg_albedo.png",
		"normal": "res://assets/sprites/animal/velociraptor_55deg_normal.png",
		"clips": 2, "offset": Vector2(0, -12.69), "move_fps": 6.62, "idle_fps": 6.4,
		"chase_radius": 170.0, "chase_speed": 126.0,
		"wander_speed": 30.0, "flee_speed": 150.0, "idle_time": Vector2(2, 6)},
}

enum Mode { IDLE, WANDER, FLEE, FOLLOW, CHASE }

## User feedback: the player and every creature 20% slower - applied to all
## the per-species speeds below and to the animation rates with them, so
## feet don't slide.
const PACE := 0.8
## Steering: reaches full speed in 1 / ACCEL_RATE s, eases in over the last
## ARRIVE_DIST px; below MOVING_SPEED it counts as standing (idle clip).
const ACCEL_RATE := 3.5
const ARRIVE_DIST := 24.0
const MOVING_SPEED := 5.0

## Dogs: start following within FOLLOW_RADIUS, for FOLLOW_TIME seconds,
## then lose interest for FOLLOW_COOLDOWN.
const FOLLOW_RADIUS := 90.0
const FOLLOW_TIME := Vector2(6.0, 10.0)
const FOLLOW_COOLDOWN := 15.0
const FOLLOW_GAP := 34.0
const FOLLOW_SPEED := 120.0
## Hunters: give up past chase_radius * CHASE_GIVE_UP or after CHASE_TIME;
## a hit (ATTACK_RANGE) or a flash sends them off for SCARED_TIME, then they
## leave the player alone for HUNT_COOLDOWN.
const CHASE_GIVE_UP := 1.8
const CHASE_TIME := 8.0
const ATTACK_RANGE := 20.0
const SCARED_TIME := 1.5
const HUNT_COOLDOWN := 12.0

var species: String = ""
var active: bool = true
## Spawned by a turned rock or a chopped tree (spawn_black_spider): gone
## for good once caught, rather than coming back elsewhere.
var one_shot := false
## Which colouring it wears (a "skins" species), 1-based; 0 for none.
var skin := 0
## Draw from the ambient (scenery) animals instead of the catchable ones.
@export var ambient: bool = false

var _data: Dictionary
var _mode: Mode = Mode.IDLE
var _mode_timer: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _dir: int = 0
var _anim_time: float = 0.0
var _anim_phase: float = 0.0
var _respawn_timer: float = 0.0
var _player: Node2D
## Counts down between follows (dogs) / hunts (wolves, carnivores).
var _cooldown: float = 0.0

@onready var sprite: Sprite2D = $Visual
@onready var catch_area: Area2D = $CatchArea


func _ready() -> void:
	catch_area.body_entered.connect(_on_body_entered)
	catch_area.body_exited.connect(_on_body_exited)
	if species == "":
		species = _pick_species()
	set_species(species)
	if _hunts():
		add_to_group("hunters")
	if not ambient:
		add_to_group("critters")
	_player = get_tree().get_first_node_in_group("player")
	_anim_time = randf() * 2.0
	_anim_phase = randf() * 8.0
	_cooldown = randf_range(4.0, 10.0)
	_enter_idle()


func set_species(name: String) -> void:
	species = name
	_data = SPECIES[name]
	var tex := CanvasTexture.new()
	# Ambient animals name their sheets by path, loaded when one spawns:
	# preloading every species held them all in memory at once, though a
	# map only uses a few (and the sharper props need the room, see Art).
	var albedo = _data.albedo
	skin = 0
	if _data.has("skins"):
		skin = randi() % _data.skins.size() + 1
		albedo = _data.skins[skin - 1]
	tex.diffuse_texture = albedo if albedo is Texture2D else load(albedo)
	tex.normal_texture = _data.normal if _data.normal is Texture2D else load(_data.normal)
	sprite.texture = tex
	var cells: int = _data.get("frames", 12) * _data.clips * ROWS
	sprite.hframes = _data.cols
	sprite.vframes = ceili(float(cells) / _data.cols)
	sprite.scale = Vector2.ONE * SPRITE_SCALE * _data.get("size", 1.0) * (1.0 if _data.get("ambient", false) else BAIT_SIZE)
	sprite.offset = _data.offset


func _physics_process(delta: float) -> void:
	if not active:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	_update_mode(delta)
	var speed := _speed()
	var to_target := _target - global_position
	# User feedback: the animals moved stiffly. They now steer - speed up,
	# ease in to where they're going and turn through an arc - instead of
	# snapping between full speed and a dead stop.
	var desired := Vector2.ZERO
	if speed > 0.0 and to_target.length() > 4.0:
		desired = to_target.normalized() * speed * clampf(to_target.length() / ARRIVE_DIST, 0.35, 1.0)
	elif _mode == Mode.WANDER:
		_enter_idle()
	var accel := maxf(speed, _data.wander_speed * PACE) * ACCEL_RATE
	velocity = velocity.move_toward(desired, accel * delta)
	if velocity.length() > 1.0:
		var before := global_position
		move_and_slide()
		if _in_water(global_position):
			global_position = before
			if not _skirt_water(delta):
				velocity *= 0.5
				_pick_target(_mode == Mode.FLEE)
		global_position.x = clamp(global_position.x, 16.0, Player.WORLD_WIDTH - 16.0)
		global_position.y = clamp(global_position.y, 16.0, Player.WORLD_HEIGHT - 16.0)
		if velocity.length() > MOVING_SPEED:
			# A crab faces across the way it goes (it walks side-on).
			_dir = Art.facing8(-velocity.orthogonal() if _data.get("sideways", false) else velocity, _dir)
	_animate(delta)


## Blocked by water: step along the bank instead (sideways to the way it
## wanted to go), so a hunter or a following dog works its way round a
## pond rather than pressing into the shore.
func _skirt_water(delta: float) -> bool:
	if _mode != Mode.CHASE and _mode != Mode.FOLLOW:
		return false
	var want := velocity
	for side in [want.orthogonal(), -want.orthogonal()]:
		var step: Vector2 = (side.normalized() * 0.8 + want.normalized() * 0.2) * want.length() * delta
		if not _in_water(global_position + step * 3.0):
			global_position += step
			velocity = step / delta
			return true
	return false


func _speed() -> float:
	match _mode:
		Mode.WANDER:
			return _data.wander_speed * PACE
		Mode.FLEE:
			return _data.flee_speed * PACE
		Mode.FOLLOW:
			return FOLLOW_SPEED * PACE
		Mode.CHASE:
			return _data.chase_speed * PACE
	return 0.0


func _hunts() -> bool:
	return _data.has("chase_speed")


func _update_mode(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	if _data.get("follow", false):
		_update_follow(delta, dist)
		return
	if _hunts():
		_update_hunt(delta, dist)
		return
	var near: bool = _data.flee_speed > 0.0 and dist < _data.get("flee_radius", FLEE_RADIUS)
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


func _update_follow(delta: float, dist: float) -> void:
	if _mode == Mode.FOLLOW:
		_mode_timer -= delta
		if _mode_timer <= 0.0:
			_cooldown = FOLLOW_COOLDOWN
			_enter_idle()
			return
		# Trail a little way off the player's side facing the dog.
		var away := (global_position - _player.global_position).normalized()
		_target = _player.global_position + away * FOLLOW_GAP
		return
	if _cooldown <= 0.0 and dist < FOLLOW_RADIUS:
		_mode = Mode.FOLLOW
		_mode_timer = randf_range(FOLLOW_TIME.x, FOLLOW_TIME.y)
		return
	_wander_tick(delta)


func _update_hunt(delta: float, dist: float) -> void:
	match _mode:
		Mode.CHASE:
			_mode_timer -= delta
			if dist < ATTACK_RANGE:
				_player.animal_attack(_data.label)
				scare()
				return
			if _mode_timer <= 0.0 or dist > _data.chase_radius * CHASE_GIVE_UP:
				_cooldown = HUNT_COOLDOWN * 0.5
				_enter_idle()
				return
			_target = _player.global_position
			return
		Mode.FLEE:
			_mode_timer -= delta
			if _mode_timer <= 0.0:
				_enter_idle()
			else:
				_pick_target(true)
			return
	if _cooldown <= 0.0 and dist < _data.chase_radius and _can_hunt():
		# User request (the pistol): shot at as it comes - it bolts.
		if _player.has_method("shoot_at") and _player.shoot_at(self):
			scare()
			_mode_timer = SCARED_TIME * 2.0
			_cooldown = HUNT_COOLDOWN * 1.5
			return
		GameState.report("%s盯上你了！" % _data.label)
		Campaign.stat("beast_seen")
		_mode = Mode.CHASE
		_mode_timer = CHASE_TIME
		_target = _player.global_position
		return
	_wander_tick(delta)


## Hunters leave the player be outside of a running round (title fade,
## results screen).
func _can_hunt() -> bool:
	return GameState.run_started and not GameState.run_over


## A hunter that bit, or got caught by the strong light (see Lantern), runs
## off for a moment and leaves the player alone for a while after.
func scare() -> void:
	if not _hunts():
		return
	_mode = Mode.FLEE
	_mode_timer = SCARED_TIME
	_cooldown = HUNT_COOLDOWN
	_pick_target(true)


func is_hunting() -> bool:
	return _mode == Mode.CHASE


## A beast that hunts the player (wolves, the meat-eaters): one a blade or a
## shot can drive off.
func is_hunter() -> bool:
	return _hunts()


func _wander_tick(delta: float) -> void:
	_mode_timer -= delta
	if _mode == Mode.IDLE and _mode_timer <= 0.0:
		_mode = Mode.WANDER
		_pick_target(false)


func _enter_idle() -> void:
	_mode = Mode.IDLE
	var idle_time: Vector2 = _data.get("idle_time", Vector2(1.5, 4.0))
	_mode_timer = randf_range(idle_time.x, idle_time.y)


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


func _animate(delta: float) -> void:
	_anim_time += delta
	var spd := velocity.length()
	var moving := spd > MOVING_SPEED
	var clip := 0 if (moving or _data.clips == 1) else 1
	var fps: float = _data.idle_fps
	if moving:
		# Legs keep pace with the actual speed (easing in and out included),
		# so feet don't slide while it accelerates or slows.
		var gait_speed: float = _data.wander_speed * PACE
		fps = _data.move_fps
		var running := spd > gait_speed * 1.6
		if running and _data.has("flee_clip"):
			clip = _data.flee_clip
			fps = _data.flee_fps
			gait_speed = _data.flee_speed * PACE
		fps *= clampf(spd / gait_speed, 0.5, 3.0)
	_anim_phase += delta * fps
	var frames: int = _data.get("frames", 12)
	var facing: Array = FACING_ROW[_dir]
	sprite.frame = (clip * ROWS + facing[0]) * frames + int(_anim_phase) % frames
	sprite.flip_h = facing[1]
	var hover: float = _data.get("hover", 0.0)
	if hover > 0.0:
		sprite.position.y = -hover + sin(_anim_time * 3.0) * 2.0


func get_label() -> String:
	return _data.label


## The chance catching it poisons (a black spider's or a snake's bite, a
## bee's sting); 0 for the harmless ones.
func venom() -> float:
	return float(_data.get("venom", 0.0))


func is_venomous() -> bool:
	return venom() > 0.0


## Stings (a bee) rather than bites.
func stings() -> bool:
	return _data.get("sting", false)


## The live bait it becomes (Profile.LIVE_BAITS key).
func bait_key() -> String:
	return _data.get("bait", "")


## User request: a black spider out from under a turned rock or a chopped
## tree, at `at`, scuttling off away from `from` (the player) - catchable,
## gone once caught (one_shot).
static func spawn_black_spider(parent: Node, at: Vector2, from: Vector2) -> Critter:
	var c: Critter = load("res://scenes/critter.tscn").instantiate()
	c.species = "black_spider"
	c.one_shot = true
	parent.add_child(c)
	c.global_position = at
	c._mode = Mode.FLEE
	c._target = at + (at - from).normalized() * 60.0 if at != from else at + Vector2(60, 0)
	return c


## Called by the player on a successful catch; returns the live bait it
## becomes (bait_key()).
func catch() -> String:
	active = false
	visible = false
	catch_area.set_deferred("monitoring", false)
	_respawn_timer = RESPAWN_DELAY
	if one_shot:
		queue_free()
	return bait_key()


func _respawn() -> void:
	if _data.get("shore_only", false):
		_respawn_on_shore()
		return
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
	velocity = Vector2.ZERO
	active = true
	visible = true
	catch_area.monitoring = true
	_enter_idle()


func _pick_species() -> String:
	var pool := []
	for key in SPECIES:
		if SPECIES[key].get("ambient", false) == ambient and not SPECIES[key].get("shore_only", false):
			pool.append(key)
	return pool.pick_random()


## A shore creature comes back as itself, somewhere along a pond's edge
## out of the player's sight.
func _respawn_on_shore() -> void:
	var zones := get_tree().get_nodes_in_group("water_zones_common")
	for _try in range(20):
		if zones.is_empty():
			break
		var samples: Array = zones.pick_random().shore_samples(60.0)
		if samples.is_empty():
			continue
		var sample: Array = samples.pick_random()
		var pos: Vector2 = sample[0] + sample[1] * randf_range(14.0, 30.0)
		if not _in_water(pos) and (_player == null or pos.distance_to(_player.global_position) > 300.0):
			global_position = pos
			break
	velocity = Vector2.ZERO
	active = true
	visible = true
	catch_area.monitoring = true
	_enter_idle()


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
