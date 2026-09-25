class_name LureVisual
extends Sprite2D

## What hangs on the end of the line (Quaternius, CC0). Lure mode: the
## lure on the line (Profile.LURES "sprite" picks one of Lure_1-6), pre-rendered lying flat with the nose toward
## -X (tools/render_sprite.py, x0.8 --recenter, 56x16 canvas centered on
## the lure) and kept nose-toward-the-player as it's reeled in. Bobber mode:
## a red-and-white float (the packs have none - built by
## tools/render_bobber.py, 24x40), the worm hanging out of sight under it.
## User request: it rides the water, bobbing, and gets dragged under when a
## fish bites - sinking is drawn by trimming the sprite from the bottom (the
## waterline) while moving it down, so the float slips below the surface.

const SPRITE_SCALE := 0.5
## User feedback: the float read too big - drawn at 70%, then half that.
const FLOAT_SCALE := 0.35
const OFFSET := Vector2(0, 1.08)
const FLOAT_OFFSET := Vector2(0, -8.26)
const FLOAT := [preload("res://assets/sprites/lure/bobber_55deg_albedo.png"), preload("res://assets/sprites/lure/bobber_55deg_normal.png")]
## How far under (texture px) the float sits: at rest, dunked by a bite,
## and held down while a fish is on.
const SINK_REST := 4.0
const SINK_DUNK := 22.0
const SINK_HOOKED := 16.0
## Test nibbles before the real bite: a little twitch, or (harder fish) a
## fake dunk right under that pops straight back up - no splash.
const DIP_NIBBLE := 9.0
const DIP_FAKE := 22.0
const DIP_TIME := 0.22

var _dip := 0.0
var _dip_timer := 0.0


func dip(depth: float) -> void:
	_dip = depth
	_dip_timer = DIP_TIME
const LURES := [
	[preload("res://assets/sprites/lure/lure_1_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_1_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_2_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_2_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_3_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_3_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_4_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_4_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_5_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_5_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_6_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_6_55deg_normal.png")],
]


var is_lure: bool = true

enum FloatState { RESTING, BITING, HOOKED }
var float_state: FloatState = FloatState.RESTING
var _sink: float = SINK_REST
var _time: float = 0.0


func _ready() -> void:
	pick(true)


## Lure `index` (LURES; -1 for a random one), or the float when `lure` is
## false.
func pick(lure: bool, index: int = -1) -> void:
	is_lure = lure
	var pair: Array = FLOAT
	if lure:
		pair = LURES[index] if index >= 0 and index < LURES.size() else LURES.pick_random()
	var tex := CanvasTexture.new()
	tex.diffuse_texture = pair[0]
	tex.normal_texture = pair[1]
	texture = tex
	Art.place(self, OFFSET if lure else FLOAT_OFFSET, SPRITE_SCALE * (1.0 if lure else FLOAT_SCALE))
	region_enabled = not lure
	float_state = FloatState.RESTING
	_sink = SINK_REST
	rotation = 0.0


func _process(delta: float) -> void:
	if is_lure or texture == null:
		return
	_time += delta
	var target := SINK_REST + sin(_time * 2.4) * 1.5
	match float_state:
		FloatState.BITING:
			# Sharp tugs under and back up.
			target = SINK_DUNK if fmod(_time, 0.45) < 0.22 else SINK_REST + 6.0
		FloatState.HOOKED:
			target = SINK_HOOKED + sin(_time * 13.0) * 3.0
	if _dip_timer > 0.0:
		_dip_timer -= delta
		target = maxf(target, _dip)
	_sink = move_toward(_sink, target, delta * 140.0)
	# _sink is in original-density px (Art); the texture has DENSITY x as many.
	var size: Vector2 = FLOAT[0].get_size()
	var cut := clampf(_sink * Art.DENSITY, 0.0, size.y - 4.0 * Art.DENSITY)
	region_rect = Rect2(0.0, 0.0, size.x, size.y - cut)
	# Trimming the bottom recentres the sprite; shift so the top drops by
	# `cut` - the float slides down through the waterline.
	offset = FLOAT_OFFSET * Art.DENSITY + Vector2(0.0, cut * 0.5)


## Nose (-X) toward `target`.
func face(target: Vector2) -> void:
	rotation = (target - global_position).angle() + PI
