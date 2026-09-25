class_name PlayerVisual
extends Sprite2D

## The player on screen. Trial (user request: the carrying / casting /
## holding-the-rod animation): Mixamo's Y Bot - a stand-in, the final
## character's look comes later - pre-rendered by tools/render_player.py,
## 8 frames per clip, 72x80 cells; rows = clips x 8 facings. Plays:
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
const OFFSET := Vector2(0.0, -17.52)
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

## What's showing (read by held_rod.gd).
var clip := CLIP_IDLE
var dir := 0
var frame_in_clip := 0

var _phase := 0.0
var _whip := -1.0

@onready var _player: Player = get_parent()


func _ready() -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	texture = tex
	hframes = FRAMES * SHEET_HALVES
	vframes = CLIPS * DIRS / SHEET_HALVES
	Art.place(self, OFFSET, SPRITE_SCALE)
	_player.cast_started.connect(func(_t, _tier): _whip = 0.0)


func _process(delta: float) -> void:
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
		frame_in_clip = mini(4 + int(_whip / WHIP_TIME * 4.0), FRAMES - 1)
		if _whip >= WHIP_TIME:
			_whip = -1.0
	elif charging:
		# Winding back with the charge.
		clip = CLIP_CAST
		frame_in_clip = mini(int(_player.charge_time / Player.MAX_CHARGE_TIME * 4.0), 3)
	else:
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
