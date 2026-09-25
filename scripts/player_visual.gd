extends Sprite2D

## The player on screen: a stand-in mannequin from Quaternius' Universal
## Animation Library (CC0; the final character's look comes later on the
## same skeleton). Pre-rendered by tools/render_sprite.py anim, x1.3, 8
## frames per clip, 72x80 cells; rows = clips x 8 facings. Plays:
##   0 idle (Idle_Torch_Loop - holding the lamp up)
##   1 moving (Jog_Fwd_Loop, sped up to the walking pace)
##   2 casting (Sword_Attack: wound back with the charge, whipped through
##     on release)
##   3 fishing (Pistol_Idle_Loop - both hands out on the rod)
##   4 busy (Interact - sacrificing, rummaging)
## Faces where it's walking, otherwise where it's aiming.

const SHEET := [preload("res://assets/sprites/player/player_55deg_albedo.png"), preload("res://assets/sprites/player/player_55deg_normal.png")]
const FRAMES := 8
const DIRS := 8
const SPRITE_SCALE := 0.5
## (0, -center_y * 27.108) for the sheet's camera; the feet sit at the
## node origin, which is placed at the bottom of the player's collision box.
const OFFSET := Vector2(0.0, -16.67)
## Sheet column order: down, down_left, left, up_left, up, up_right, right,
## down_right. Index by 45deg sector clockwise from +X (right).
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]

const CLIP_IDLE := 0
const CLIP_MOVE := 1
const CLIP_CAST := 2
const CLIP_FISH := 3
const CLIP_BUSY := 4
const FPS := [6.4, 8.7, 0.0, 4.8, 8.0]
## The jog clip's own pace in world px/s at this scale; faster walking
## plays it faster.
const JOG_PACE := 60.0
const WHIP_TIME := 0.3

var _phase := 0.0
var _dir := 0
var _whip := -1.0

@onready var _player: Player = get_parent()


func _ready() -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	texture = tex
	hframes = FRAMES
	vframes = 5 * DIRS
	Art.place(self, OFFSET, SPRITE_SCALE)
	_player.cast_started.connect(func(_t, _tier): _whip = 0.0)


func _process(delta: float) -> void:
	var speed := _player.velocity.length()
	var moving := speed > 8.0
	# User feedback: which way a cast will go has to read on the character -
	# it faces its aim whenever it's fishing, and when standing still.
	# While charging it faces the aim; otherwise walking faces the way it
	# walks (legs and all - user feedback: walking with a fish on used to
	# glide in the rod stance).
	var charging := _player.state == Player.State.CHARGING
	var face := _player.velocity if moving and not charging else _player.aim_dir
	if face.length() > 0.01:
		var sector := posmod(roundi(face.angle() / (PI / 4.0)), 8)
		_dir = SECTOR_TO_DIR[sector]

	var clip := CLIP_IDLE
	var frame_in_clip := 0
	if _whip >= 0.0:
		# The cast: second half of the swing, fast.
		_whip += delta
		clip = CLIP_CAST
		frame_in_clip = mini(4 + int(_whip / WHIP_TIME * 4.0), FRAMES - 1)
		if _whip >= WHIP_TIME:
			_whip = -1.0
	elif _player.state == Player.State.CHARGING:
		# Winding up with the charge: the first half of the swing.
		clip = CLIP_CAST
		frame_in_clip = mini(int(_player.charge_time / Player.MAX_CHARGE_TIME * 4.0), 3)
	else:
		if moving:
			clip = CLIP_MOVE
		elif _player.state != Player.State.IDLE:
			clip = CLIP_FISH
		elif _player.sacrifice_progress > 0.0 or _player.rummage_progress > 0.0:
			clip = CLIP_BUSY
		var fps: float = FPS[clip]
		if clip == CLIP_MOVE:
			fps *= speed / JOG_PACE
		_phase += delta * fps
		frame_in_clip = int(_phase) % FRAMES
	frame = (clip * DIRS + _dir) * FRAMES + frame_in_clip
