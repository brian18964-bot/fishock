extends Sprite2D

## (Candidate, user request round 4: the hand holds the rod.) The player's
## pixels that are in front of the rod - the fingers round its handle, an
## arm or the head it passes behind - cut from the sheet by
## tools/render_player.py --grip (per frame and facing, ROD_DATA "front")
## and drawn over the rod, which held_rod.gd then draws over the body.

const FRONT := [preload("res://assets/sprites/player/player_55deg_front_albedo.png"),
	preload("res://assets/sprites/player/player_55deg_front_normal.png")]
const ROD_DATA := preload("res://assets/sprites/player/player_55deg_rod.json")

var _front: Dictionary = ROD_DATA.data.get("front", {})

@onready var _body: PlayerVisual = get_parent().get_node("Body")
@onready var _rod: Sprite2D = get_parent().get_node("Rod")


func _ready() -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = FRONT[0]
	tex.normal_texture = FRONT[1]
	texture = tex
	region_enabled = true
	z_index = 2


func _process(_delta: float) -> void:
	visible = _rod.visible and not _body.struggling and not _front.is_empty()
	if not visible:
		return
	var piece: Variant = _front[PlayerVisual.CLIP_NAMES[_body.clip]][_body.dir][_body.frame_in_clip]
	if piece == null:
		visible = false
		return
	position = _body.position
	scale = _body.scale
	region_rect = Rect2(piece[0], piece[1], piece[2], piece[3])
	var cell := Vector2(_body.texture.get_width() / float(_body.hframes), _body.texture.get_height() / float(_body.vframes))
	offset = _body.offset + Vector2(piece[4] + piece[2] * 0.5, piece[5] + piece[3] * 0.5) - cell * 0.5
