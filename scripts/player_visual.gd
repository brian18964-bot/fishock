class_name PlayerVisual
extends Sprite2D

## The player on screen: the black cat (a greybox animal person in its
## trial colours, tools/owl_character.py's player())
## moving as Mixamo's clips move (user request: the carrying / casting /
## holding-the-rod animation), pre-rendered by tools/render_player.py,
## 8 frames per clip (the cell fitted to the character); rows = clips x 8
## facings. Plays:
##   0 idle      breathing, rod across the back
##   1 run       rod across the back
##   2 cast      winding back with the charge (0-3), whipped on release (4-7)
##   3 hold      rod held out after the cast, waiting
##   4 busy      bent over (sacrificing, rummaging)
##   5 reel      cranking the reel in (reeling a fish, retrieving a lure)
##   6 fight     cranking, leaning back against a running fish
##   7 hold_run  running with the rod held out
## Faces where it's running, otherwise where it's aiming. The rod itself is
## drawn by held_rod.gd, from where this frame's hand (or back) puts it.
## User request (Camp v2): in the big ghost's grip it struggles, and
## knocked free it staggers - a sheet of their own, framed like the main
## one (tools/render_player_struggle.py; no rod drawn over them):
##   0 struggle  shoving at the ghost, shaking
##   1 knock     struck free, staggering back

const SHEET := [preload("res://assets/sprites/player/player_55deg_albedo.png"), preload("res://assets/sprites/player/player_55deg_normal.png")]
const FRAMES := 8
const DIRS := 8
## Performance on phones: the rows are split into halves side by side (the
## second four clips to the right of the first four) - one tall column was
## over 8192 px, more than many phone GPUs take. See render_player.py.
const SHEET_HALVES := 2
const SPRITE_SCALE := 0.5
## (0, -center_y * 27.108) for the sheet's camera; the feet sit at the
## node origin, which is placed at the bottom of the player's collision box.
## The main sheet's comes with it (render_player.py writes it into the rod
## data: its cell is fitted to the character, so it changes with the
## character and the clips); the struggle sheet's is fixed
## (render_player_struggle.py CELL, CENTER_Y).
const ROD_DATA := preload("res://assets/sprites/player/player_55deg_rod.json")
const STRUGGLE_OFFSET := Vector2(0.0, -15.38)
## Sheet column order: down, down_left, left, up_left, up, up_right, right,
## down_right. Index by 45deg sector clockwise from +X (right).
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]

const CLIP_IDLE := 0
const CLIP_RUN := 1
const CLIP_CAST := 2
const CLIP_HOLD := 3
const CLIP_BUSY := 4
const CLIP_REEL := 5
const CLIP_FIGHT := 6
const CLIP_HOLD_RUN := 7
const CLIPS := 8
## Row names in the sheet (and in its rod data, see held_rod.gd).
const CLIP_NAMES := ["idle", "run", "cast", "hold", "busy", "reel", "fight", "hold_run"]
const FPS := [2.5, 10.9, 0.0, 3.0, 6.0, 14.0, 16.0, 10.9]
## The run clip's own pace in world px/s at this scale; faster running
## plays it faster.
const RUN_PACE := 77.4
const WHIP_TIME := 0.3
const STRUGGLE := [preload("res://assets/sprites/player/player_struggle_55deg_albedo.png"),
	preload("res://assets/sprites/player/player_struggle_55deg_normal.png")]
const STRUGGLE_FPS := 9.0
const SHAKE := 1.2

## What's showing (read by held_rod.gd).
var clip := CLIP_IDLE
var dir := 0
var frame_in_clip := 0

var _phase := 0.0
## The main sheet's offset (ROD_DATA, above).
var _sheet_offset := Vector2(ROD_DATA.data.offset[0], ROD_DATA.data.offset[1])
var _whip := -1.0
## The wind-up frame (0-3) the charge reached, -1 when none showed.
var _wound := -1
## The whip's first frame: the one after where the wind-up got to.
var _whip_from := 4
var _main_tex: CanvasTexture
var _struggle_tex: CanvasTexture
## Showing the struggle sheet (held_rod.gd draws no rod then).
var struggling := false

@onready var _player: Player = get_parent()


func _ready() -> void:
	_main_tex = CanvasTexture.new()
	_main_tex.diffuse_texture = SHEET[0]
	_main_tex.normal_texture = SHEET[1]
	_struggle_tex = CanvasTexture.new()
	_struggle_tex.diffuse_texture = STRUGGLE[0]
	_struggle_tex.normal_texture = STRUGGLE[1]
	_use_sheet(false)
	Art.place(self, _sheet_offset, SPRITE_SCALE)
	_player.cast_started.connect(func(_t, _tier):
		_whip = 0.0
		_whip_from = whip_start(_wound))


## User request (round 5: no jump from the charge into the release): a
## cast let go before the wind-up's top (a tap, a short charge) used to cut
## from the rod low at frame 0 or 1 to the top of the whip (frame 4); it
## plays on from the next frame through the rest of the wind-up and the
## whip instead, in the same WHIP_TIME - one frame at a time.
static func whip_start(wound: int) -> int:
	if wound < 0:
		return 4
	return clampi(wound + 1, 1, 4)


func _use_sheet(struggle: bool) -> void:
	struggling = struggle
	texture = _struggle_tex if struggle else _main_tex
	hframes = FRAMES if struggle else FRAMES * SHEET_HALVES
	vframes = 2 * DIRS if struggle else CLIPS * DIRS / SHEET_HALVES


## In the ghost's grip, or staggering free: the struggle sheet.
func _struggle(delta: float) -> bool:
	var held: bool = _player.struggling
	var knocked: bool = _player.knocked()
	if not held and not knocked:
		if struggling:
			_use_sheet(false)
			Art.place(self, _sheet_offset, SPRITE_SCALE)
		return false
	if not struggling:
		_use_sheet(true)
	var toward: Vector2 = _player.grab_from - _player.global_position
	if toward.length() > 0.5:
		dir = SECTOR_TO_DIR[posmod(roundi(toward.angle() / (PI / 4.0)), 8)]
	var row := 0
	if held:
		_phase += delta * STRUGGLE_FPS
		frame_in_clip = int(_phase) % FRAMES
		# Shaking in its grip.
		var jolt := Vector2(randf_range(-SHAKE, SHAKE), randf_range(-SHAKE, SHAKE) * 0.5)
		offset = STRUGGLE_OFFSET * Art.DENSITY + jolt * Art.DENSITY / SPRITE_SCALE
	else:
		row = 1
		frame_in_clip = mini(int(_player.knock_progress() * FRAMES), FRAMES - 1)
		Art.place(self, STRUGGLE_OFFSET, SPRITE_SCALE)
	frame = (row * DIRS + dir) * FRAMES + frame_in_clip
	return true


func _process(delta: float) -> void:
	if _struggle(delta):
		return
	var speed := _player.velocity.length()
	var moving := speed > 8.0
	# User feedback: which way a cast will go has to read on the character -
	# it faces its aim whenever it's fishing, and when standing still.
	# While charging it faces the aim; otherwise running faces the way it
	# runs (legs and all - user feedback: walking with a fish on used to
	# glide in the rod stance).
	var state: Player.State = _player.state
	var charging := state == Player.State.CHARGING
	var face := _player.velocity if moving and not charging else _player.aim_dir
	if face.length() > 0.01:
		var sector := posmod(roundi(face.angle() / (PI / 4.0)), 8)
		dir = SECTOR_TO_DIR[sector]

	if _whip >= 0.0:
		# The cast: the whip and follow-through, fast.
		_whip += delta
		clip = CLIP_CAST
		frame_in_clip = mini(_whip_from + int(_whip / WHIP_TIME * (FRAMES - _whip_from)), FRAMES - 1)
		if _whip >= WHIP_TIME:
			_whip = -1.0
			_wound = -1
	elif charging and not moving:
		# Winding back with the charge.
		clip = CLIP_CAST
		frame_in_clip = mini(int(_player.charge_time / Player.MAX_CHARGE_TIME * 4.0), 3)
		_wound = frame_in_clip
	elif charging:
		# User feedback: walking while holding the cast froze the legs (the
		# wind-up is one still frame) - it runs with the rod out instead,
		# still facing the aim.
		clip = CLIP_HOLD_RUN
		_phase += delta * FPS[clip] * speed / RUN_PACE
		frame_in_clip = int(_phase) % FRAMES
		_wound = -1
	else:
		_wound = -1
		var fishing := state != Player.State.IDLE
		var cranking := _player._is_action_pressed()
		if moving:
			clip = CLIP_HOLD_RUN if fishing else CLIP_RUN
		elif state == Player.State.REELING:
			if _player.fish_run_active_time > 0.0:
				clip = CLIP_FIGHT
			else:
				clip = CLIP_REEL if cranking else CLIP_HOLD
		elif state == Player.State.WAITING and _player.fishing_mode == Player.FishingMode.LURE and cranking:
			clip = CLIP_REEL  # retrieving the lure
		elif fishing:
			clip = CLIP_HOLD
		elif _player.sacrifice_progress > 0.0:
			clip = CLIP_BUSY
		else:
			clip = CLIP_IDLE
		var fps: float = FPS[clip]
		if clip == CLIP_RUN or clip == CLIP_HOLD_RUN:
			fps *= speed / RUN_PACE
		_phase += delta * fps
		frame_in_clip = int(_phase) % FRAMES
	var row := clip * DIRS + dir
	var rows_per_half := CLIPS * DIRS / SHEET_HALVES
	frame = (row % rows_per_half) * hframes + (row / rows_per_half) * FRAMES + frame_in_clip
