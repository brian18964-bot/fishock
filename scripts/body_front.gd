extends Sprite2D

## (Candidate, user request round 4: the hand holds the rod.) The player's
## pixels that are in front of the rod - the fingers round its handle, an
## arm or the head it passes behind - drawn over the rod, which held_rod.gd
## then draws over the body. Where (per frame and facing, the rod data's "front")
## comes from tools/render_player.py --grip.
##
## User request (round 5: no notches or blocks of colour where the layer
## meets the rod): it draws the body's own texture again - the same
## sheet, lighting and filtering, so it can only differ from the body
## where the rod is - masked by the front atlas's alpha
## (shaders/body_front.gdshader); a copy of the pixels in an atlas of its
## own came out a little different (compressed apart, filtered at its own
## edges), and the rod showed through as a faint line.

## (The character travelling's: CharacterArt.)
var _mask: Texture2D = CharacterArt.front_mask()
var _front: Dictionary = CharacterArt.rod_data().get("front", {})
var _mat: ShaderMaterial

@onready var _body: PlayerVisual = get_parent().get_node("Body")
@onready var _rod: Node2D = get_parent().get_node("Rod")


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/body_front.gdshader")
	_mat.set_shader_parameter("mask", _mask)
	material = _mat
	region_enabled = true
	z_index = 2


func _process(_delta: float) -> void:
	visible = _rod.visible and not _body.struggling and not _body.off_main_sheet() and not _front.is_empty()
	if not visible:
		return
	var piece: Variant = _front[PlayerVisual.CLIP_NAMES[_body.clip]][_body.dir][_body.frame_in_clip]
	if piece == null:
		visible = false
		return
	texture = _body.texture
	position = _body.position
	scale = _body.scale
	var size := Vector2(texture.get_width(), texture.get_height())
	var cell := Vector2(size.x / _body.hframes, size.y / _body.vframes)
	var at := Vector2(_body.frame % _body.hframes, _body.frame / _body.hframes) * cell
	region_rect = Rect2(at.x + piece[4], at.y + piece[5], piece[2], piece[3])
	offset = _body.offset + Vector2(piece[4] + piece[2] * 0.5, piece[5] + piece[3] * 0.5) - cell * 0.5
	var msize := Vector2(_mask.get_width(), _mask.get_height())
	_mat.set_shader_parameter("region_uv", Vector4(region_rect.position.x / size.x, region_rect.position.y / size.y,
		region_rect.size.x / size.x, region_rect.size.y / size.y))
	_mat.set_shader_parameter("mask_uv", Vector4(piece[0] / msize.x, piece[1] / msize.y, piece[2] / msize.x, piece[3] / msize.y))
	_mat.set_shader_parameter("mask_half", Vector2(0.5 / msize.x, 0.5 / msize.y))
	# (the ears and tail swayed as the body's are)
	_body.apply_sway(_mat)
