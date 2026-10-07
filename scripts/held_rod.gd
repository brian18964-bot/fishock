extends Node2D

## The fishing rod (Quaternius, CC0), pre-rendered lying flat along +X
## through the 55deg pipeline (tools/render_sprite.py, x0.42 --tip 90); the
## node sits at the grip, so it turns about it. Its tier (the pack's Lvl1-5
## rods) is the rod bought in the shop (Profile.rod_tier).
##
## User request (the carrying / casting / holding animation): the rod goes
## where the player's animation puts it - in the left hand while fishing,
## across the back otherwise. tools/render_player.py recorded, for every
## frame of every clip and facing, the grip and tip on screen and whether
## the rod is behind the body (CharacterArt.rod_data()); this points the rod from that
## grip to that tip, foreshortened to its on-screen length.
##
## (Candidate, user request round 6: the fight has to show the fish pulling
## the rod.) The rod bends toward the line: a little with a fish on, more as
## the line's tension rises, harder through a run and at each yank of the
## fight clip (PlayerVisual.yank), in tugs at a bite. It's drawn as a strip
## of the rod's own sprite along the bent curve - the bend gathering toward
## the tip, the butt behind the hand straight - and the line leaves its bent
## tip. The reel is drawn with the character now (its rods' sprites have
## theirs cut out, render_sprite.py --cut).

const SPRITE_SCALE := 0.5
## User feedback: the rod was a thin dark sliver on a phone screen - drawn
## much thicker, and brighter.
const THICKNESS_SCALE := 1.6
const BRIGHTNESS := 1.6
## Grip to tip along the sprite, in original-density texture px (Art).
const TIP_X := 82.0

## A bite jerks it; while fighting a fish it shudders, harder while
## reeling and during a run, and leans the way it's pulled.
const MAX_LEAN := 0.5

## The bend: the angle the tip turns off the rod's line (rad) - BEND_FISH
## with a fish on, BEND_TENSION more at full tension, BEND_RUN more through
## a run (pulsing), BEND_YANK at a yank - BEND_MAX at most (the front
## layer covers it bent that far: render_player.py FRONT_BENDS); the bite's
## tugs; a retrieved lure. It follows within about 1 / BEND_EASE s.
## BEND_GATHER: the bend's angle along the rod goes as (distance / length)
## ^ BEND_GATHER (stiff butt, soft tip). It bends to the side the line pulls - the line runs down to
## the water from a tip held up, so its pull on screen leans BEND_DOWN
## down - least (BEND_ALONG of the most) where the line runs along the
## rod on screen.
const BEND_FISH := 0.1
const BEND_TENSION := 0.95
const BEND_RUN := 0.25
const BEND_YANK := 0.5
const BEND_BITE := 0.4
const BEND_LURE := 0.12
const BEND_MAX := 1.3
const BEND_EASE := 12.0
const BEND_GATHER := 2.0
const BEND_ALONG := 0.6
const BEND_DOWN := 0.5
## Strips the sprite is drawn in; curve points per rod length.
const STRIPS := 26
const CURVE_STEPS := 32

## offset: canvas center relative to the grip, (center_x, -center_y) *
## 27.108 for the shared 104x16 canvas (center 1.18, 0.06).
const OFFSET := Vector2(31.99, -1.63)
## (Candidate, user request round 4: the hand on the rod.) Where each
## tier's hand goes along its rod (orig px past the model's origin): at
## the reel seat - the lvl3-5 rods' origins are at their butts, the hand
## held them by the very end - and where each one's visible tip is (the
## line leaves there; lvl1-2 end at 56 of TIP_X's 82 px).
const GRIP_SHIFT := [0.0, 0.0, 11.8, 7.5, 7.9]
const TIP_END := [56.0, 56.0, 75.0, 75.5, 79.5]
const TIERS := [
	[preload("res://assets/sprites/rod/rod_lvl1_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl1_55deg_normal.png")],
	[preload("res://assets/sprites/rod/rod_lvl2_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl2_55deg_normal.png")],
	[preload("res://assets/sprites/rod/rod_lvl3_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl3_55deg_normal.png")],
	[preload("res://assets/sprites/rod/rod_lvl4_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl4_55deg_normal.png")],
	[preload("res://assets/sprites/rod/rod_lvl5_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl5_55deg_normal.png")],
]

@onready var _player: Node2D = get_parent()

## Extra turn from a bite or a nibble, on top of the animation.
var _swing: float = 0.0
var _swing_tween: Tween
var _time: float = 0.0
## User request (the off hand): fishing, the rod's drawn off the back into
## the hand - and put back after - eased over DRAW_TIME rather than cut
## from one to the other (PlayerVisual.rod_on_back()).
const DRAW_TIME := 0.22
var _was_back := true
var _draw_from: Array = []
var _draw_left := 0.0
var _last_cell: Array = []
## The sheet's pixels in front of the rod (BodyFront) when it has them:
## the rod is then drawn over the body, and they over the rod.
var _has_front: bool = CharacterArt.rod_data().has("front")
var _tier := 0
var _tex: CanvasTexture
## The sprite's canvas centre from the grip (texels), as a Sprite2D offset.
var _offset := Vector2.ZERO
## On screen: the rod's length grip to tip as drawn (px), and its bend - the
## tip's turn off the line (rad, + toward the node's +y).
var _length := 0.0
## (read by the tests)
var bend := 0.0
## The bent centre line, CURVE_STEPS + 1 points from the grip to the
## visible tip, and the rod's direction at each (rad).
var _curve := PackedVector2Array()
var _angles := PackedFloat32Array()

@onready var _body: PlayerVisual = _player.get_node("Body")


func _ready() -> void:
	self_modulate = Color(BRIGHTNESS, BRIGHTNESS, BRIGHTNESS)
	Profile.profile_changed.connect(_apply_tier)
	_player.bite_started.connect(_on_bite)
	_player.nibble.connect(func(_fake): _tween_swing([[0.08, 0.04], [0.0, 0.1]]))
	_apply_tier()


func _process(delta: float) -> void:
	# Struggling in the big ghost's grip (a sheet of its own): no rod.
	visible = not _body.struggling
	if not visible:
		return
	_time += delta
	_update_draw(delta)
	var extra := _swing
	var want := 0.0
	match _player.state:
		Player.State.BITE:
			# The fish keeps tugging until the hook is set.
			var tug := pow(maxf(0.0, sin(_time * 13.0)), 6.0)
			extra += tug * 0.2
			want = tug * BEND_BITE
		Player.State.REELING:
			var shake := 0.02
			if _player.is_cranking():
				shake = 0.04
			if _player.fish_run_active_time > 0.0:
				shake = 0.09
			extra += sin(_time * 31.0) * shake + sin(_time * 17.0) * shake * 0.5
			# Leaning the rod the way it's being pulled (against a sideways
			# run - see FishFight).
			var pull: Vector2 = _player._counter_dir()
			if pull != Vector2.ZERO:
				extra += clampf(angle_difference(_cell_along().angle(), pull.angle()), -MAX_LEAN, MAX_LEAN)
			want = BEND_FISH + BEND_TENSION * _player.tension + BEND_YANK * _body.yank
			if _player.fish_run_active_time > 0.0:
				want += BEND_RUN * (0.6 + 0.4 * sin(_time * 7.0))
		Player.State.WAITING:
			if _player.fishing_mode == Player.FishingMode.LURE and _player._is_action_pressed():
				want = BEND_LURE
	place(extra)
	bend = lerpf(bend, bend_toward(_player.get_line_target_position(), want), 1.0 - exp(-BEND_EASE * delta))
	_bend_curve()


## The rod off the back and into the hand, or back: starts the ease.
func _update_draw(delta: float) -> void:
	var back := _body.rod_on_back()
	if back != _was_back and not _last_cell.is_empty():
		_draw_from = _last_cell
		_draw_left = DRAW_TIME
	_was_back = back
	_draw_left = maxf(_draw_left - delta, 0.0)


## The body's frame's rod (PlayerVisual.rod_cell()), eased from where it
## was while it's being drawn or put back.
func _cell() -> Array:
	var cell: Array = _body.rod_cell()
	if _draw_left > 0.0 and _draw_from.size() >= 4:
		var t := 1.0 - _draw_left / DRAW_TIME
		t = t * t * (3.0 - 2.0 * t)
		cell = [lerpf(_draw_from[0], cell[0], t), lerpf(_draw_from[1], cell[1], t),
			lerpf(_draw_from[2], cell[2], t), lerpf(_draw_from[3], cell[3], t), cell[4]]
	_last_cell = cell
	return cell


func _cell_along() -> Vector2:
	var cell := _cell()
	return (Vector2(cell[2], cell[3]) - Vector2(cell[0], cell[1])) * SPRITE_SCALE


## Where the body's frame puts the rod (turned `extra` more), bent as it
## is (`bend`).
func place(extra := 0.0) -> void:
	var cell := _cell()
	var grip := Vector2(cell[0], cell[1]) * SPRITE_SCALE
	var along := (Vector2(cell[2], cell[3]) - Vector2(cell[0], cell[1])) * SPRITE_SCALE
	position = _body.position + grip
	rotation = along.angle() + extra
	_length = along.length()
	# (a swing's sheet has no front layer: behind the body or in front)
	z_index = 1 if _has_front and _body.acting < 0 else (-1 if cell[4] else 1)
	_bend_curve()


## The bend that `amount` (rad, the most at the tip) makes toward the line
## to `target` (global): to the side it pulls (leaning BEND_DOWN down the
## screen), all of it across the rod, BEND_ALONG of it along; BEND_MAX at
## most.
func bend_toward(target: Vector2, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var to_line := to_local(target).normalized()
	var pull := to_line + (Vector2.DOWN * BEND_DOWN).rotated(-global_rotation)
	var side := signf(pull.y) if absf(pull.y) > 0.01 else signf(bend)
	if side == 0.0:
		side = 1.0
	return minf(amount, BEND_MAX) * lerpf(BEND_ALONG, 1.0, absf(to_line.y)) * side


## The rod's px per texel along it (foreshortened) and across.
func _scale() -> Vector2:
	return Vector2(_length / (TIP_X * Art.DENSITY), SPRITE_SCALE * THICKNESS_SCALE / Art.DENSITY)


## The visible rod's length grip to tip on screen (px).
func _tip_along() -> float:
	return (TIP_END[_tier] - GRIP_SHIFT[_tier]) * Art.DENSITY * _scale().x


func _bend_curve() -> void:
	queue_redraw()
	var length := maxf(_tip_along(), 0.001)
	_curve.resize(CURVE_STEPS + 1)
	_angles.resize(CURVE_STEPS + 1)
	var p := Vector2.ZERO
	var step := length / CURVE_STEPS
	_curve[0] = p
	_angles[0] = 0.0
	for i in range(1, CURVE_STEPS + 1):
		var mid := bend * pow((i - 0.5) / CURVE_STEPS, BEND_GATHER)
		p += Vector2(cos(mid), sin(mid)) * step
		_curve[i] = p
		_angles[i] = bend * pow(float(i) / CURVE_STEPS, BEND_GATHER)


## The bent centre line at `a` px along the rod from the grip (behind it,
## the butt, straight; past the visible tip, on along its last direction):
## [point, the curve's normal there].
func _at(a: float) -> Array:
	if a <= 0.0 or _curve.size() < 2:
		return [Vector2(a, 0.0), Vector2(0.0, 1.0)]
	var length := maxf(_tip_along(), 0.001)
	var t := a / length * CURVE_STEPS
	var ang: float
	var point: Vector2
	if t >= CURVE_STEPS:
		ang = _angles[CURVE_STEPS]
		point = _curve[CURVE_STEPS] + Vector2(cos(ang), sin(ang)) * (a - length)
	else:
		var i := int(t)
		var f := t - i
		point = _curve[i].lerp(_curve[i + 1], f)
		ang = lerpf(_angles[i], _angles[i + 1], f)
	return [point, Vector2(-sin(ang), cos(ang))]


func _draw() -> void:
	if _tex == null:
		return
	var w := float(_tex.get_width())
	var h := float(_tex.get_height())
	var s := _scale()
	var x0 := _offset.x - w * 0.5
	var y0 := (_offset.y - h * 0.5) * s.y
	var y1 := (_offset.y + h * 0.5) * s.y
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var last: Array = []
	for i in STRIPS + 1:
		var u := w * i / STRIPS
		var c: Array = _at((x0 + u) * s.x)
		var edge := [c[0] + c[1] * y0, c[0] + c[1] * y1, u / w]
		if i > 0:
			draw_primitive(PackedVector2Array([last[0], edge[0], edge[1], last[1]]), colors,
				PackedVector2Array([Vector2(last[2], 0.0), Vector2(edge[2], 0.0), Vector2(edge[2], 1.0), Vector2(last[2], 1.0)]), _tex)
		last = edge


## Where the line leaves the rod: the far end of the sprite, so the line
## follows the rod through its swing, shudder and bend.
func tip_position() -> Vector2:
	var c: Array = _at(_tip_along())
	return to_global(c[0] + c[1] * _offset.y * _scale().y)


## User request: the rod is visibly yanked when a fish takes the bait.
func _on_bite() -> void:
	_tween_swing([[0.35, 0.05], [-0.12, 0.08], [0.25, 0.06], [-0.05, 0.08], [0.0, 0.2]])


func _tween_swing(steps: Array) -> void:
	if _swing_tween != null:
		_swing_tween.kill()
	_swing_tween = create_tween()
	for step in steps:
		_swing_tween.tween_property(self, "_swing", step[0], step[1]).set_trans(Tween.TRANS_SINE)


func _apply_tier() -> void:
	var tier: int = clampi(Profile.rod_tier, 0, TIERS.size() - 1)
	_tex = CanvasTexture.new()
	_tex.diffuse_texture = TIERS[tier][0]
	_tex.normal_texture = TIERS[tier][1]
	_tier = tier
	_offset = (OFFSET - Vector2(GRIP_SHIFT[tier], 0.0)) * Art.DENSITY
	queue_redraw()
