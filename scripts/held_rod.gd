extends Sprite2D

## The fishing rod (Quaternius, CC0), pre-rendered lying flat along +X
## through the 55deg pipeline (tools/render_sprite.py, x0.42 --tip 90); the
## node sits at the grip, so it turns about it. Its tier (the pack's Lvl1-5
## rods) is the rod bought in the shop (Profile.rod_tier).
##
## User request (the carrying / casting / holding animation): the rod goes
## where the player's animation puts it - in the left hand while fishing,
## across the back otherwise. tools/render_player.py recorded, for every
## frame of every clip and facing, the grip and tip on screen and whether
## the rod is behind the body (ROD_DATA); this points the sprite from that
## grip to that tip, foreshortened to its on-screen length.

const SPRITE_SCALE := 0.5
## User feedback: the rod was a thin dark sliver on a phone screen - drawn
## much thicker, and brighter.
const THICKNESS_SCALE := 1.6
const BRIGHTNESS := 1.6
## Grip to tip along the sprite, in original-density texture px (Art).
const TIP_X := 82.0
const ROD_DATA := preload("res://assets/sprites/player/player_55deg_rod.json")

## A bite jerks it; while fighting a fish it shudders, harder while
## reeling and during a run, and leans the way it's pulled.
const MAX_LEAN := 0.5

## offset: canvas center relative to the grip, (center_x, -center_y) *
## 27.108 for the shared 104x16 canvas (center 1.18, 0.06).
const OFFSET := Vector2(31.99, -1.63)
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
var _rod: Dictionary = ROD_DATA.data.rod

@onready var _body: PlayerVisual = _player.get_node("Body")


func _ready() -> void:
	offset = OFFSET * Art.DENSITY
	self_modulate = Color(BRIGHTNESS, BRIGHTNESS, BRIGHTNESS)
	Profile.profile_changed.connect(_apply_tier)
	_player.bite_started.connect(_on_bite)
	_player.nibble.connect(func(_fake): _tween_swing([[0.08, 0.04], [0.0, 0.1]]))
	_apply_tier()


func _process(delta: float) -> void:
	_time += delta
	var cell: Array = _rod[PlayerVisual.CLIP_NAMES[_body.clip]][_body.dir][_body.frame_in_clip]
	var grip := Vector2(cell[0], cell[1]) * SPRITE_SCALE
	var along := (Vector2(cell[2], cell[3]) * SPRITE_SCALE) - grip
	var extra := _swing
	match _player.state:
		Player.State.BITE:
			# The fish keeps tugging until the hook is set.
			extra += pow(maxf(0.0, sin(_time * 13.0)), 6.0) * 0.2
		Player.State.REELING:
			var shake := 0.02
			if _player._is_action_pressed():
				shake = 0.04
			if _player.fish_run_active_time > 0.0:
				shake = 0.09
			extra += sin(_time * 31.0) * shake + sin(_time * 17.0) * shake * 0.5
			# Leaning the rod the way it's being pulled (against a sideways
			# run - see FishFight).
			var pull: Vector2 = _player._counter_dir()
			if pull != Vector2.ZERO:
				extra += clampf(angle_difference(along.angle(), pull.angle()), -MAX_LEAN, MAX_LEAN)
	position = _body.position + grip
	rotation = along.angle() + extra
	# Foreshortened: pointing toward or away from the camera it's shorter.
	scale = Vector2(along.length() / (TIP_X * Art.DENSITY), SPRITE_SCALE * THICKNESS_SCALE / Art.DENSITY)
	z_index = -1 if cell[4] else 1


## Where the line leaves the rod: the far end of the sprite, so the line
## follows the rod through its swing and shudder.
func tip_position() -> Vector2:
	var half_width: float = texture.get_width() * 0.5 if texture != null else 0.0
	return to_global(offset + Vector2(half_width - 2.0 * Art.DENSITY, 0.0))


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
	var tex := CanvasTexture.new()
	tex.diffuse_texture = TIERS[tier][0]
	tex.normal_texture = TIERS[tier][1]
	texture = tex
