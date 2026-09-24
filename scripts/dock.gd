class_name Dock
extends Sprite2D

## Wooden docks (Quaternius, CC0) pre-rendered through the 55deg pipeline
## (tools/render_sprite.py, x0.34, --yaw 0 / 90). map_generator.gd lays one
## across the edge of a few common water zones, pointing at the zone's
## center: about 30% on land, 70% over water. Drawn flat under everything
## y-sorted (z_index -3: above water and ground cover), so the player walks
## out on it. The model is symmetric end to end, so a vertical and a
## horizontal render cover all four directions.

const SPRITE_SCALE := 0.5

## Ground half-length along the dock in world px: 3.69 units x 13.554,
## foreshortened by sin 55deg when it runs up/down the screen.
const HALF_LENGTH_VERTICAL := 41.0
const HALF_LENGTH_HORIZONTAL := 50.0

## offset: -center_y * 27.108 (vertical 96x184 canvas, center_y 0.69;
## horizontal 208x120, center_y 0.715).
const VARIANTS := {
	"vertical": {"offset": Vector2(0, -18.70), "textures": {
		true: [preload("res://assets/sprites/dock/dock_long_vertical_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_vertical_55deg_normal.png")],
		false: [preload("res://assets/sprites/dock/dock_long_no_rope_vertical_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_no_rope_vertical_55deg_normal.png")],
	}},
	"horizontal": {"offset": Vector2(0, -19.38), "textures": {
		true: [preload("res://assets/sprites/dock/dock_long_horizontal_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_horizontal_55deg_normal.png")],
		false: [preload("res://assets/sprites/dock/dock_long_no_rope_horizontal_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_no_rope_horizontal_55deg_normal.png")],
	}},
}


static func half_length(vertical: bool) -> float:
	return HALF_LENGTH_VERTICAL if vertical else HALF_LENGTH_HORIZONTAL


func setup(vertical: bool, with_rope: bool) -> void:
	var variant: Dictionary = VARIANTS["vertical" if vertical else "horizontal"]
	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.textures[with_rope][0]
	tex.normal_texture = variant.textures[with_rope][1]
	texture = tex
	offset = variant.offset
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
