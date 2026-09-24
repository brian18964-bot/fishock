extends Sprite2D

## What hangs on the end of the line (Quaternius, CC0). Lure mode: one of
## Lure_1-6 picked per cast, pre-rendered lying flat with the nose toward
## -X (tools/render_sprite.py, x0.8 --recenter, 56x16 canvas centered on
## the lure) and kept nose-toward-the-player as it's reeled in. Bobber mode:
## the worm on the hook (x1.2 --recenter, 32x24) - the packs have no float.

const SPRITE_SCALE := 0.5
const OFFSET := Vector2(0, 1.08)
const WORM_OFFSET := Vector2(0, -3.39)
const WORM := [preload("res://assets/sprites/lure/worm_55deg_albedo.png"), preload("res://assets/sprites/lure/worm_55deg_normal.png")]
const LURES := [
	[preload("res://assets/sprites/lure/lure_1_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_1_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_2_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_2_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_3_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_3_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_4_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_4_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_5_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_5_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_6_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_6_55deg_normal.png")],
]


var is_lure: bool = true


func _ready() -> void:
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	pick(true)


## A random lure, or the worm when `lure` is false.
func pick(lure: bool) -> void:
	is_lure = lure
	var pair: Array = LURES.pick_random() if lure else WORM
	var tex := CanvasTexture.new()
	tex.diffuse_texture = pair[0]
	tex.normal_texture = pair[1]
	texture = tex
	offset = OFFSET if lure else WORM_OFFSET
	rotation = 0.0


## Nose (-X) toward `target`.
func face(target: Vector2) -> void:
	rotation = (target - global_position).angle() + PI
