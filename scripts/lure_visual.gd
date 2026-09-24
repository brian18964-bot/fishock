extends Sprite2D

## The lure on the end of the line in lure mode (Quaternius, CC0: Lure_1,
## Lure_3, Lure_5), pre-rendered lying flat, nose toward -X (tools/
## render_sprite.py, x0.8 --recenter, 56x16 canvas centered on the lure).
## main.gd shows it instead of the bobber square in lure mode, picks one at
## random per cast, and keeps its nose turned toward the player as it's
## reeled in.

const SPRITE_SCALE := 0.5
const OFFSET := Vector2(0, 1.08)
const LURES := [
	[preload("res://assets/sprites/lure/lure_1_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_1_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_3_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_3_55deg_normal.png")],
	[preload("res://assets/sprites/lure/lure_5_55deg_albedo.png"), preload("res://assets/sprites/lure/lure_5_55deg_normal.png")],
]


func _ready() -> void:
	offset = OFFSET
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	pick()


func pick() -> void:
	var lure: Array = LURES.pick_random()
	var tex := CanvasTexture.new()
	tex.diffuse_texture = lure[0]
	tex.normal_texture = lure[1]
	texture = tex


## Nose (-X) toward `target`.
func face(target: Vector2) -> void:
	rotation = (target - global_position).angle() + PI
