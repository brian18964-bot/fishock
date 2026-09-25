extends Sprite2D

## The fishing rod in the player's hand (Quaternius, CC0), pre-rendered
## lying flat along +X through the 55deg pipeline (tools/render_sprite.py,
## x0.42 --tip 90) and turned to follow Player.aim_dir. The node sits at the
## grip, so rotation pivots there. Its tier (the pack's Lvl1-5 rods) is the
## rod bought in the shop (Profile.rod_tier).

const SPRITE_SCALE := 0.5
## User feedback: the rod was a thin dark sliver on a phone screen - drawn
## longer, much thicker, and brighter.
## With the mannequin in place (and the camera close) it's back to about a
## 3 m rod.
const LENGTH_SCALE := 0.8
const THICKNESS_SCALE := 1.6
const BRIGHTNESS := 1.6

## User request: the rod moves. Charging swings it back over the shoulder
## (up to SWING_BACK rad with the charge), a cast whips it forward past the
## aim and it settles; a bite jerks it; while fighting a fish it's held off
## to one side and shudders, harder while reeling and during a run.
const SWING_BACK := 2.3
const WHIP_OVERSHOOT := 0.35
const WHIP_TIME := 0.12
const SETTLE_TIME := 0.25
const FIGHT_ANGLE := 0.3

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

## Extra rotation from the cast/bite animation, on top of the aim.
var _swing: float = 0.0
var _swing_tween: Tween
var _time: float = 0.0


func _ready() -> void:
	offset = OFFSET
	scale = Vector2(SPRITE_SCALE * LENGTH_SCALE, SPRITE_SCALE * THICKNESS_SCALE)
	self_modulate = Color(BRIGHTNESS, BRIGHTNESS, BRIGHTNESS)
	Profile.profile_changed.connect(_apply_tier)
	_player.cast_started.connect(_on_cast)
	_player.bite_started.connect(_on_bite)
	_player.nibble.connect(func(_fake): _tween_swing([[0.12, 0.04], [0.0, 0.1]]))
	_apply_tier()


func _process(delta: float) -> void:
	_time += delta
	var aim: Vector2 = _player.aim_dir
	# A charge let go without a cast (cancelled) drifts back onto the aim.
	if _player.state != Player.State.CHARGING and (_swing_tween == null or not _swing_tween.is_running()):
		_swing = move_toward(_swing, 0.0, delta * 6.0)
	var extra := _swing
	match _player.state:
		Player.State.CHARGING:
			extra = -SWING_BACK * _player.charge_time / Player.MAX_CHARGE_TIME
			_swing = extra
		Player.State.BITE:
			# The fish keeps tugging until the hook is set.
			extra += pow(maxf(0.0, sin(_time * 13.0)), 6.0) * 0.35
		Player.State.REELING:
			var shake := 0.03
			if _player._is_action_pressed():
				shake = 0.07
			if _player.fish_run_active_time > 0.0:
				shake = 0.14
			extra += FIGHT_ANGLE + sin(_time * 31.0) * shake + sin(_time * 17.0) * shake * 0.5
			# Leaning the rod the way it's being pulled (against a sideways
			# run - see FishFight).
			var pull: Vector2 = _player._counter_dir()
			if pull != Vector2.ZERO:
				extra = clampf(angle_difference(aim.angle(), pull.angle()), -0.7, 0.7)
	rotation = aim.angle() + extra
	# Pointing away from the camera, the rod belongs behind the player.
	var pointing: Vector2 = Vector2.RIGHT.rotated(rotation)
	z_index = -1 if pointing.y < -0.3 else 1


## Where the line leaves the rod: the far end of the sprite, so the line
## follows the rod through its swing and shudder.
func tip_position() -> Vector2:
	var half_width: float = texture.get_width() * 0.5 if texture != null else 0.0
	return to_global(offset + Vector2(half_width - 2.0, 0.0))


## Whip forward past the aim, then settle back onto it.
func _on_cast(_target: Vector2, _tier: String) -> void:
	_tween_swing([[WHIP_OVERSHOOT, WHIP_TIME], [0.0, SETTLE_TIME]])


## User request: the rod is visibly yanked when a fish takes the bait.
func _on_bite() -> void:
	_tween_swing([[0.7, 0.05], [-0.25, 0.08], [0.5, 0.06], [-0.1, 0.08], [0.0, 0.2]])


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
