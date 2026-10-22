class_name GlowMushroom
extends Node2D

## User request: the glow mushroom (發光蘑菇, Profile.USABLES "glow_mushroom")
## - found only under the trees (MapGenerator._scatter_mushrooms: by a
## trunk's foot), glowing quietly blue on the map, breathing in and out.
## The player by it is offered 採集 (Player.interaction()): crouched, it's
## picked and into the bag. RunView3D shows it as its model
## (assets/models/items/glow_mushroom.glb), glowing, with a small light;
## here (the 2D run) its picture and a faint blue light.

## How close to stand to pick it (px).
const PICK_RANGE := 30.0
## How far out from a trunk's edge it grows (px), and how many to a map
## (the campaign's smaller ones fewer: Campaign.area_share()).
const FROM_TRUNK := Vector2(4.0, 12.0)
const PER_MAP := Vector2i(4, 7)
## Its glow: blue, breathing over BREATH s.
const GLOW := Color(0.42, 0.72, 1.0)
const BREATH := 3.6
const ICON_SIZE := 22.0

static var _glow_tex: Texture2D
## Where it is in its breath (each its own).
var phase := 0.0
var _sprite: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	add_to_group("glow_mushrooms")
	phase = randf() * TAU
	_sprite = Sprite2D.new()
	_sprite.texture = Items.icon("glow_mushroom")
	if _sprite.texture != null:
		_sprite.scale = Vector2.ONE * ICON_SIZE / maxf(_sprite.texture.get_width(), _sprite.texture.get_height())
	_sprite.offset = Vector2(0, -ICON_SIZE * 0.4 / maxf(_sprite.scale.y, 0.001))
	add_child(_sprite)
	_light = PointLight2D.new()
	if _glow_tex == null:
		_glow_tex = LightTextureFactory.make_radial_texture(64)
	_light.texture = _glow_tex
	_light.color = GLOW
	_light.texture_scale = 0.9
	_light.energy = 0.5
	add_child(_light)


## How bright it is now (0..1), breathing.
func glow() -> float:
	return 0.55 + 0.45 * sin(phase)


func _process(delta: float) -> void:
	phase += delta * TAU / BREATH
	_light.energy = 0.3 + 0.35 * glow()
	_sprite.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.5, 1.8), glow() * 0.5)


## Picked (Player._pick_mushroom): no longer to be picked at once, gone
## from the map `after` s on (when the hands reach it).
func pick(after := 0.0) -> void:
	remove_from_group("glow_mushrooms")
	if after <= 0.0 or not is_inside_tree():
		queue_free()
		return
	get_tree().create_timer(after).timeout.connect(queue_free)
