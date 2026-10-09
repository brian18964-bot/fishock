class_name PlayerVisual
extends Sprite2D

## The player on screen: the character travelling (Profile.character - a
## greybox animal person in its trial colours, tools/owl_character.py's
## player(); its sheets from CharacterArt)
## moving as KayKit's clips move (user request: the carrying / casting /
## holding-the-rod animation; KayKit Character Animations, CC0, since the
## user asked to be off Mixamo's), pre-rendered by tools/render_player.py,
## 8 frames per clip (the cell fitted to the character); rows = clips x 8
## facings. Plays:
##   0 idle      breathing, rod across the back
##   1 run       rod across the back
##   2 cast      a long cast, two-handed: winding back with the charge (0-3),
##               whipped on release (4-7)
##   3 hold      rod held out after the cast, waiting
##   4 busy      bent over (sacrificing, rummaging)
##   5 reel      cranking the reel in (reeling a fish, retrieving a lure)
##   6 fight     a running fish pulling: braced on the reel, yanked toward
##               it (frame YANK_FRAME) and hauling back
##   7 hold_run  running with the rod held out
##   8 bite      a bite on the line: the rod twitching (the bite window,
##               and a moment at each nibble)
##   9 tug       striking: the rod snatched up (once, as the fish is hooked)
##  10 catch     landing the fish: the rod raised (once, as it's caught)
##  11 cast_short  a short cast, one-handed (KayKit's): as the long one -
##               user request: casts reaching TWO_HAND_RATIO of the full
##               charge or more are thrown two-handed, shorter ones with one
## (Candidate, user request round 6: the reeling cranked at the air.) In
## hold, reel, fight and hold_run both hands are on the rod: the right on
## the reel's crank, turning it once round over the reel clip.
## Faces where it's running, otherwise where it's aiming. The rod itself is
## drawn by held_rod.gd, from where this frame's hand (or back) puts it.
## User request (Camp v2): in the big ghost's grip it struggles, and
## knocked free it staggers - a sheet of their own, framed like the main
## one (tools/render_player_struggle.py; no rod drawn over them):
##   0 struggle  shoving at the ghost, shaking
##   1 knock     struck free, staggering back
## User request: the off hand's thing swung (Player.swing()) - its own
## sheet too (tools/render_player_tools.py; the rod on the back drawn from
## its data), facing the aim:
##   0 slash     a blade swung at a beast
##   1 chop      the hatchet or machete at a tree
##   2 scoop     the net swept low
##   3 shoot     the pistol fired
## User request: the player's moves - the user's Mixamo clips, a third
## sheet (tools/render_player_moves.py; five facings drawn, the other three
## mirrored - MOVE_FACING), the rod on the back drawn from its data, no
## ears' sway over them: played as Player.perform() says (drink, look,
## eye, pick, lift, throw, cheer, fist, sad, scared, pray, kneel - through
## once over the move, standing still and not fishing; walking off cuts it
## short), and the landing of a fish followed by a fist pumped (a rare one:
## both arms up). And how it's feeling, standing about: poisoned it's dizzy,
## worn right out (Profile.spirit_penalty() 3) it hangs its head; walking
## slowly so (poisoned) it drags its feet.
## Where the rod goes, and the off hand's thing (in the right hand, or at
## the hip), comes from the sheet showing (rod_cell(), hand_cell(),
## belt_cell()).

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
const STRUGGLE_OFFSET := Vector2(0.0, -21.38)
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
const CLIP_BITE := 8
const CLIP_TUG := 9
const CLIP_CATCH := 10
const CLIP_CAST_SHORT := 11
const CLIPS := 12
## Row names in the sheet (and in its rod data, see held_rod.gd).
const CLIP_NAMES := ["idle", "run", "cast", "hold", "busy", "reel", "fight", "hold_run", "bite", "tug", "catch",
	"cast_short"]
const FPS := [2.5, 10.9, 0.0, 3.0, 6.0, 14.0, 9.0, 10.9, 9.0, 16.0, 10.0, 0.0]
## The share of the full charge from which a cast is thrown two-handed.
const TWO_HAND_RATIO := 0.6
## A nibble shows the bite clip this long (s); the strike and the landing
## play their clip through once (FRAMES at their FPS).
const NIBBLE_TIME := 0.45
## The fight clip's frame where the fish yanks: the rod dips, the arms are
## pulled out (render_player.py FIGHT_LEAN, FIGHT_REACH) - and, here, the
## body is jolted YANK_JOLT px toward the fish and the rod bent harder
## (held_rod.gd), easing off over YANK_TIME s.
const YANK_FRAME := 1
const YANK_JOLT := 1.6
const YANK_TIME := 0.18
## The run clip's own pace in world px/s at this scale; faster running
## plays it faster.
const RUN_PACE := 77.4
const WHIP_TIME := 0.3
const STRUGGLE_FPS := 9.0
## The off hand's swings, by Player.swing_kind.
const ACTIONS := ["slash", "chop", "scoop", "shoot"]
## The clips with the rod on the back (the off hand's thing in hand).
const BACK_CLIPS := [CLIP_IDLE, CLIP_RUN, CLIP_BUSY]
const SHAKE := 1.2
## The moves sheet's facings for the game's eight (DIRS order): [its row,
## mirrored].
const MOVE_FACING := [[0, false], [1, false], [2, false], [3, false], [4, false], [3, true], [2, true], [1, true]]
const MOVE_DIRS := 5
## The moves on it (tools/render_player_moves.py's CLIPS, in order).
const MOVE_NAMES := ["drink", "look", "eye", "pick", "lift", "throw", "cheer", "fist", "sad", "scared", "dizzy", "pray",
	"kneel", "sad_idle", "sad_walk", "walk"]
## The moves played by how it's feeling (looping): their pace (frames/s);
## the dragging walk's own pace (world px/s) and the fastest it's used at.
const MOOD_FPS := {"dizzy": 3.0, "sad_idle": 2.5, "sad_walk": 5.3}
const SAD_PACE := 32.0
const SAD_WALK_MAX := 55.0
## User request: the left stick eased off, it walks - not the run slowed
## down, all long strides. Up to WALK_MAX (px/s) a walk (the moves sheet's,
## Mixamo's), slow or brisk with the stick; past it the run. A little
## either side of it before it changes (WALK_SLACK), so it doesn't flicker
## between them. The walk's own pace (world px/s, at the run's 10.9 frames
## a second) is the character's own, in its moves data ("walk_pace").
const WALK_MAX := 62.0
const WALK_SLACK := 5.0
## After a fish is landed (the catch clip): a fist pumped, or both arms up
## for a rare one - for this long.
const CHEER_TIME := 1.4
const CHEER_RARITIES := ["rare", "epic", "legendary"]

## What's showing (read by held_rod.gd).
var clip := CLIP_IDLE
var dir := 0
var frame_in_clip := 0

var _phase := 0.0
## Walking, not running (WALK_MAX).
var walking := false
## The main sheet's offset (its rod data, above).
var _sheet_offset := Vector2.ZERO
var _whip := -1.0
## The cast showing: CLIP_CAST (long, two-handed) or CLIP_CAST_SHORT.
var _cast_clip := CLIP_CAST
## The wind-up frame (0-3) the charge reached, -1 when none showed.
var _wound := -1
## The whip's first frame: the one after where the wind-up got to.
var _whip_from := 4
var _main_tex: CanvasTexture
var _struggle_tex: CanvasTexture
var _action_tex: CanvasTexture
## Showing the struggle sheet (held_rod.gd draws no rod then).
var struggling := false
## Showing a swing (the off hand's sheet): which (ACTIONS index), else -1.
var acting := -1
## Showing a move (the moves sheet): its name, else "".
var move := ""
var move_flip := false
var _move_tex: CanvasTexture
var _move_data: Dictionary
var _move_offset := Vector2.ZERO
var _move_phase := 0.0
## The move to play once the clip played once is over (the landing's cheer).
var _after_once := ""
var _data: Dictionary
var _action_data: Dictionary
var _action_offset := Vector2.ZERO
## A fish's yank, 1 at its frame easing to 0 (read by held_rod.gd).
var yank := 0.0
## A clip played once over the rest (the strike, the landing, a nibble's
## twitch): which, and how long it has left (s).
var _once := -1
var _once_left := 0.0
var _home := Vector2.ZERO

## User request: the ears (the owl's tufts) and the tail move on their own
## - each one's line on the sheet (the data's "sway", named by "sway_names":
## tools/render_player.py) turned about its root by the body's shader
## (shaders/player_body.gdshader): now and then an ear flicks (sometimes
## twice); the tail sways, and now and then flicks - not while it's behind
## the body (seen from the front). Not in the struggle sheet (no data).
## How far an ear flicks and the tail sways and flicks (rad), and how far
## off its line the shader takes in (a share of its length, at least px).
const SWAY_EAR := Vector2(0.3, 0.5)
const SWAY_TAIL := 0.12
const SWAY_TAIL_FLICK := 0.3
const SWAY_REACH := Vector2(0.55, 5.0)
## Each chain's timing: {next, at (the flick's start, -1 none), angle,
## period} - as EarTailSway (the camp's 3D character) times them.
var _sway: Array = []
var _sway_time := 0.0
var _sway_mat: ShaderMaterial
var _sway_lines: Array = []
var _sway_turns := PackedFloat32Array()
var _sway_reaches := PackedFloat32Array()

@onready var _player: Player = get_parent()


func _ready() -> void:
	var sheet := CharacterArt.sheet()
	_data = CharacterArt.rod_data()
	var offset_px: Array = _data.offset
	_sheet_offset = Vector2(offset_px[0], offset_px[1])
	var tools := CharacterArt.tools()
	_action_data = CharacterArt.tools_data()
	if not tools.is_empty() and not _action_data.is_empty():
		_action_tex = CanvasTexture.new()
		_action_tex.diffuse_texture = tools[0]
		_action_tex.normal_texture = tools[1]
		var action_px: Array = _action_data.offset
		_action_offset = Vector2(action_px[0], action_px[1])
	var moves := CharacterArt.moves()
	_move_data = CharacterArt.moves_data()
	if not moves.is_empty() and not _move_data.is_empty():
		_move_tex = CanvasTexture.new()
		_move_tex.diffuse_texture = moves[0]
		_move_tex.normal_texture = moves[1]
		var move_px: Array = _move_data.offset
		_move_offset = Vector2(move_px[0], move_px[1])
	_main_tex = CanvasTexture.new()
	_main_tex.diffuse_texture = sheet[0]
	_main_tex.normal_texture = sheet[1]
	var struggle := CharacterArt.struggle()
	_struggle_tex = CanvasTexture.new()
	_struggle_tex.diffuse_texture = struggle[0]
	_struggle_tex.normal_texture = struggle[1]
	_home = position
	_sway_mat = ShaderMaterial.new()
	_sway_mat.shader = preload("res://shaders/player_body.gdshader")
	material = _sway_mat
	_use_sheet(false)
	Art.place(self, _sheet_offset, SPRITE_SCALE)
	_player.cast_started.connect(func(_t, _tier):
		_whip = 0.0
		_whip_from = whip_start(_wound)
		_cast_clip = cast_clip(_player.charge_time / Player.MAX_CHARGE_TIME))
	# (KayKit's fishing) striking, landing a fish, a nibble at the float.
	_player.hook_success.connect(func(): play_once(CLIP_TUG))
	_player.catch_success.connect(func(fish):
		play_once(CLIP_CATCH)
		_after_once = "cheer" if fish.get("rarity", "") in CHEER_RARITIES or _player.is_epic_catch else "fist")
	_player.nibble.connect(func(_fake): play_once(CLIP_BITE, NIBBLE_TIME))


## Whether what the player does now cuts the clip played once short:
## cranking or a running fish (the strike), the float gone (a nibble).
func _once_cut(state: Player.State) -> bool:
	match _once:
		CLIP_TUG:
			return _player.is_cranking() or _player.fish_run_active_time > 0.0
		CLIP_BITE:
			return state != Player.State.WAITING
	return false


## Plays `which` once over whatever else would show (for `seconds`; by
## default its FRAMES at its FPS).
func play_once(which: int, seconds := -1.0) -> void:
	_once = which
	_once_left = seconds if seconds > 0.0 else FRAMES / FPS[which]
	_phase = 0.0


## The cast clip for a throw at `ratio` of the full charge: two-handed from
## TWO_HAND_RATIO on, one-handed below.
static func cast_clip(ratio: float) -> int:
	return CLIP_CAST if ratio >= TWO_HAND_RATIO else CLIP_CAST_SHORT


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
	acting = -1
	move = ""
	flip_h = false
	move_flip = false
	texture = _struggle_tex if struggle else _main_tex
	hframes = FRAMES if struggle else FRAMES * SHEET_HALVES
	vframes = 2 * DIRS if struggle else CLIPS * DIRS / SHEET_HALVES


## The rod this frame: [grip x, grip y, tip x, tip y, behind] (sheet px
## from the feet; held_rod.gd).
func rod_cell() -> Array:
	if move != "":
		return _mirrored(_move_data.rod[move][MOVE_FACING[dir][0]][frame_in_clip], [0, 2])
	if acting >= 0:
		return _action_data.rod[ACTIONS[acting]][dir][frame_in_clip]
	return _data.rod[CLIP_NAMES[clip]][dir][frame_in_clip]


## The right hand this frame: [x, y, fist axis x, y, fingers x, y, behind]
## ([] without the data) - offhand_prop.gd.
func hand_cell() -> Array:
	if move != "":
		var mh: Dictionary = _move_data.get("hand", {})
		return _mirrored(mh[move][MOVE_FACING[dir][0]][frame_in_clip], [0, 2, 4]) if mh.has(move) else []
	var d: Dictionary = _action_data if acting >= 0 else _data
	var key: String = ACTIONS[acting] if acting >= 0 else CLIP_NAMES[clip]
	return d.hand[key][dir][frame_in_clip] if d.has("hand") and d.hand.has(key) else []


## The right hip this frame: [x, y, thigh x, y, behind] ([] without).
func belt_cell() -> Array:
	if move != "":
		var mb: Dictionary = _move_data.get("belt", {})
		return _mirrored(mb[move][MOVE_FACING[dir][0]][frame_in_clip], [0, 2]) if mb.has(move) else []
	var d: Dictionary = _action_data if acting >= 0 else _data
	var key: String = ACTIONS[acting] if acting >= 0 else CLIP_NAMES[clip]
	return d.belt[key][dir][frame_in_clip] if d.has("belt") and d.belt.has(key) else []


## A moves sheet cell's data as drawn: its x values turned over when the
## facing's mirrored.
func _mirrored(cell, xs: Array) -> Array:
	if cell == null or not (cell is Array):
		return []
	var out: Array = (cell as Array).duplicate()
	if move_flip:
		for i in xs:
			if i < out.size():
				out[i] = -float(out[i])
	return out


## The rod's on the back this frame (the off hand's thing in the hand).
func rod_on_back() -> bool:
	return acting >= 0 or move != "" or (not struggling and clip in BACK_CLIPS and _once < 0 and _whip < 0.0)


## Showing another sheet than the run's (a swing or a move): no front layer
## (body_front.gd), the rod placed by its own data.
func off_main_sheet() -> bool:
	return acting >= 0 or move != ""


## Swinging the off hand's thing (Player.swing_kind): its sheet, facing the
## aim, through its FRAMES over the swing.
func _act() -> bool:
	var which := ACTIONS.find(_player.swing_kind) if _player.swing_left > 0.0 and _action_tex != null else -1
	if which < 0:
		if acting >= 0:
			_use_sheet(false)
			Art.place(self, _sheet_offset, SPRITE_SCALE)
		return false
	if acting < 0:
		move = ""
		flip_h = false
		move_flip = false
		texture = _action_tex
		hframes = FRAMES
		vframes = ACTIONS.size() * DIRS
		Art.place(self, _action_offset, SPRITE_SCALE)
	acting = which
	var face: Vector2 = _player.aim_dir
	if face.length() > 0.01:
		dir = SECTOR_TO_DIR[posmod(roundi(face.angle() / (PI / 4.0)), 8)]
	var t := 1.0 - _player.swing_left / Player.SWING_TIME
	frame_in_clip = clampi(int(t * FRAMES), 0, FRAMES - 1)
	frame = (acting * DIRS + dir) * FRAMES + frame_in_clip
	return true


## A move (see above): Player.perform()'s, standing still and not fishing,
## or how it's feeling. Its sheet, facing the aim (or the way it walks).
func _move(delta: float) -> bool:
	var speed := _player.velocity.length()
	var moving := speed > 8.0
	var idle: bool = _player.state == Player.State.IDLE and not _player.carrying_oil_drum and not _player._lure_charging
	var name := _player.move_kind if _player.move_left > 0.0 else ""
	if name != "" and (moving or not idle):
		# Walked off (or back to fishing): it's cut short.
		_player.move_left = 0.0
		name = ""
	var timed := name != ""
	if not timed and idle and _once < 0 and _whip < 0.0:
		var poisoned: bool = _player.poison_timer > 0.0
		walking = moving and speed < WALK_MAX + (WALK_SLACK if walking else -WALK_SLACK)
		if moving:
			if poisoned and speed <= SAD_WALK_MAX:
				name = "sad_walk"
			elif walking:
				name = "walk"
		elif poisoned:
			name = "dizzy"
		elif Profile.spirit_penalty() >= 3:
			name = "sad_idle"
	if name == "" or _move_tex == null or not (_move_data.clips as Array).has(name):
		if move != "":
			_use_sheet(false)
			Art.place(self, _sheet_offset, SPRITE_SCALE)
		return false
	if move == "":
		texture = _move_tex
		hframes = FRAMES * int(_move_data.sections)
		vframes = int(_move_data.rows_per_section)
		Art.place(self, _move_offset, SPRITE_SCALE)
	if name != move:
		_move_phase = 0.0
	move = name
	var face := _player.velocity if moving else _player.aim_dir
	if face.length() > 0.01:
		dir = SECTOR_TO_DIR[posmod(roundi(face.angle() / (PI / 4.0)), 8)]
	var facing: Array = MOVE_FACING[dir]
	move_flip = facing[1]
	flip_h = move_flip
	if timed:
		var t := 1.0 - _player.move_left / maxf(_player.move_time, 0.01)
		frame_in_clip = clampi(int(t * FRAMES), 0, FRAMES - 1)
	else:
		var fps: float = MOOD_FPS.get(name, 3.0)
		if name == "sad_walk":
			fps *= speed / SAD_PACE
		elif name == "walk":
			fps = FPS[CLIP_RUN] * speed / float(_move_data.get("walk_pace", 60.0))
		_move_phase += delta * fps
		frame_in_clip = int(_move_phase) % FRAMES
	var row: int = (_move_data.clips as Array).find(name) * MOVE_DIRS + int(facing[0])
	var per: int = int(_move_data.rows_per_section)
	frame = (row % per) * hframes + (row / per) * FRAMES + frame_in_clip
	return true


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
	_pick_frame(delta)
	_sway_update(delta)
	apply_sway(_sway_mat)


func _pick_frame(delta: float) -> void:
	if _struggle(delta):
		yank = 0.0
		position = _home
		return
	if _act():
		yank = 0.0
		position = _home
		return
	if _move(delta):
		yank = 0.0
		position = _home
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
		clip = _cast_clip
		frame_in_clip = mini(_whip_from + int(_whip / WHIP_TIME * (FRAMES - _whip_from)), FRAMES - 1)
		if _whip >= WHIP_TIME:
			_whip = -1.0
			_wound = -1
	elif charging and not moving:
		# Winding back with the charge (one-handed until it's a long one).
		clip = cast_clip(_player.charge_time / Player.MAX_CHARGE_TIME)
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
	elif _once >= 0 and not moving and not _once_cut(state):
		# The strike, the landing or a nibble's twitch, once.
		_wound = -1
		_once_left -= delta
		clip = _once
		_phase += delta * FPS[clip]
		frame_in_clip = mini(int(_phase), FRAMES - 1) if clip != CLIP_BITE else int(_phase) % FRAMES
		if _once_left <= 0.0:
			_once = -1
			if _after_once != "":
				_player.perform(_after_once, CHEER_TIME)
				_after_once = ""
	else:
		_wound = -1
		_once = -1
		var fishing := state != Player.State.IDLE
		var cranking := _player.is_cranking()
		var was := clip
		if moving:
			clip = CLIP_HOLD_RUN if fishing else CLIP_RUN
		elif state == Player.State.REELING:
			if _player.fish_run_active_time > 0.0:
				clip = CLIP_FIGHT
			else:
				clip = CLIP_REEL if cranking else CLIP_HOLD
		elif state == Player.State.WAITING and _player.fishing_mode == Player.FishingMode.LURE and cranking:
			clip = CLIP_REEL  # retrieving the lure
		elif state == Player.State.BITE:
			clip = CLIP_BITE  # something's on: strike now
		elif fishing:
			clip = CLIP_HOLD
		elif _player.sacrifice_progress > 0.0:
			clip = CLIP_BUSY
		else:
			clip = CLIP_IDLE
		var fps: float = FPS[clip]
		if clip == CLIP_RUN or clip == CLIP_HOLD_RUN:
			fps *= speed / RUN_PACE
		elif clip == CLIP_REEL and state == Player.State.REELING:
			# The crank turns as fast as the stick's turned (Player.crank).
			fps *= clampf(_player.crank / FishFight.CRANK_NORMAL, 0.4, 1.5)
		if clip == CLIP_FIGHT and was != CLIP_FIGHT:
			# a run starts with the fish's first yank
			_phase = YANK_FRAME - delta * fps
		elif clip == CLIP_REEL and was != CLIP_REEL:
			# the crank turns on from where the hand rests on it (frame 0:
			# the knob where the hold, the fight and the running hold keep it)
			_phase = -delta * fps
		var before := frame_in_clip
		_phase += delta * fps
		frame_in_clip = int(_phase) % FRAMES
		if clip == CLIP_FIGHT and frame_in_clip == YANK_FRAME and (before != YANK_FRAME or was != CLIP_FIGHT):
			yank = 1.0
	_jolt(delta)
	var row := clip * DIRS + dir
	var rows_per_half := CLIPS * DIRS / SHEET_HALVES
	frame = (row % rows_per_half) * hframes + (row / rows_per_half) * FRAMES + frame_in_clip


## The ears' and the tail's turn this frame (see SWAY_EAR).
func _sway_update(delta: float) -> void:
	_sway_time += delta
	_sway_lines.clear()
	_sway_turns.clear()
	_sway_reaches.clear()
	var d: Dictionary = _action_data if acting >= 0 else _data
	var key: String = ACTIONS[acting] if acting >= 0 else CLIP_NAMES[clip]
	if struggling or move != "" or not d.has("sway") or not d.sway.has(key):
		return
	var cells: Array = d.sway[key][dir][frame_in_clip]
	var names: Array = d.get("sway_names", [])
	while _sway.size() < cells.size():
		_sway.append({"next": randf_range(0.5, EarTailSway.EAR_GAP.y), "at": -1.0, "angle": 0.0,
			"period": randf_range(EarTailSway.TAIL_PERIOD.x, EarTailSway.TAIL_PERIOD.y)})
	for i in mini(cells.size(), 5):
		var c: Array = cells[i]
		var tail := i < names.size() and str(names[i]).begins_with("tail")
		var turn := _sway_turn(_sway[i], tail)
		if tail and int(c[4]) == 1:
			turn = 0.0
		var root := Vector2(c[0], c[1]) * Art.DENSITY
		var tip := Vector2(c[2], c[3]) * Art.DENSITY
		_sway_lines.append(Vector4(root.x, root.y, tip.x, tip.y))
		_sway_turns.append(turn)
		_sway_reaches.append(maxf(root.distance_to(tip) * SWAY_REACH.x, SWAY_REACH.y))


## How far chain `s` is turned now (rad); starts its flicks when they're due.
func _sway_turn(s: Dictionary, tail: bool) -> float:
	var span := EarTailSway.TAIL_FLICK_TIME if tail else EarTailSway.EAR_TIME
	if s.at >= 0.0 and _sway_time - s.at > span:
		s.at = -1.0
	if _sway_time >= s.next:
		s.at = _sway_time
		var side := 1.0 if randf() < 0.5 else -1.0
		if tail:
			s.angle = SWAY_TAIL_FLICK * side
			s.next = _sway_time + randf_range(EarTailSway.TAIL_FLICK_GAP.x, EarTailSway.TAIL_FLICK_GAP.y)
		else:
			s.angle = randf_range(SWAY_EAR.x, SWAY_EAR.y) * side
			var again := randf() < EarTailSway.EAR_TWICE
			s.next = _sway_time + (EarTailSway.EAR_TIME + 0.05 if again else randf_range(EarTailSway.EAR_GAP.x, EarTailSway.EAR_GAP.y))
	if tail:
		var turn: float = SWAY_TAIL * sin(TAU * _sway_time / s.period)
		if s.at >= 0.0:
			var u := clampf((_sway_time - s.at) / EarTailSway.TAIL_FLICK_TIME, 0.0, 1.0)
			turn += s.angle * sin(PI * u) * (1.0 - u * 0.5)
		return turn
	return s.angle * EarTailSway.flick(_sway_time - s.at) if s.at >= 0.0 else 0.0


## The sway this frame onto `mat` (the body's, and its layer in front of
## the rod's - body_front.gd): see sway.gdshaderinc.
func apply_sway(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("sway_count", _sway_lines.size())
	if _sway_lines.is_empty():
		return
	mat.set_shader_parameter("sway_line", _sway_lines)
	mat.set_shader_parameter("sway_turn", _sway_turns)
	mat.set_shader_parameter("sway_reach", _sway_reaches)
	if texture != null:
		var cell := Vector2(1.0 / hframes, 1.0 / vframes)
		var at := Vector2(frame % hframes, frame / hframes) * cell
		mat.set_shader_parameter("sway_frame", Vector4(at.x, at.y, cell.x, cell.y))


## (Candidate, user request round 6.) The fish's yank: the body jolted
## toward it, easing back (the rod and the layer in front of it follow the
## body's place).
func _jolt(delta: float) -> void:
	yank = maxf(0.0, yank - delta / YANK_TIME) if yank > 0.0 else 0.0
	var toward: Vector2 = _player.cast_target - _player.global_position
	var jolt := Vector2.ZERO
	if yank > 0.0 and toward.length() > 1.0:
		jolt = toward.normalized() * YANK_JOLT * yank * yank
	position = _home + jolt
