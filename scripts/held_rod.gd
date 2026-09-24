extends Sprite2D

## The fishing rod in the player's hand (Quaternius, CC0), pre-rendered
## lying flat along +X through the 55deg pipeline (tools/render_sprite.py,
## x0.42 --tip 90) and turned to follow Player.aim_dir. The node sits at the
## grip, so rotation pivots there. Its tier follows the rod_distance
## upgrade: level 0 plain wood, 1-2 the metal-reeled rod, max the gold one
## (the pack has no Lvl3 rod).

const SPRITE_SCALE := 0.5

## offset: canvas center relative to the grip, (center_x, -center_y) *
## 27.108 for the shared 96x16 canvas (center 1.105, 0.06).
const OFFSET := Vector2(29.95, -1.63)
const TIERS := [
	[preload("res://assets/sprites/rod/rod_lvl1_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl1_55deg_normal.png")],
	[preload("res://assets/sprites/rod/rod_lvl2_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl2_55deg_normal.png")],
	[preload("res://assets/sprites/rod/rod_lvl4_55deg_albedo.png"), preload("res://assets/sprites/rod/rod_lvl4_55deg_normal.png")],
]

@onready var _player: Node2D = get_parent()


func _ready() -> void:
	offset = OFFSET
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	Profile.profile_changed.connect(_apply_tier)
	_apply_tier()


func _process(_delta: float) -> void:
	var aim: Vector2 = _player.aim_dir
	rotation = aim.angle()
	# Pointing away from the camera, the rod belongs behind the player.
	z_index = -1 if aim.y < -0.3 else 1


func _apply_tier() -> void:
	var level: int = Profile.upgrade_levels.get("rod_distance", 0)
	var tier := 0 if level == 0 else (2 if level >= 3 else 1)
	var tex := CanvasTexture.new()
	tex.diffuse_texture = TIERS[tier][0]
	tex.normal_texture = TIERS[tier][1]
	texture = tex
