class_name Dock
extends Sprite2D

## Wooden docks (Quaternius, CC0: long with/without rope, wide) pre-rendered
## through the 55deg pipeline (tools/render_sprite.py, x0.34, --yaw 0 / 90).
## map_generator.gd lays one across the edge of a few common water zones,
## pointing at the zone's center: about 30% on land, 70% over water; some
## get stairs at the water end stepping down toward the zone's center
## (setup_stairs(); the same node type, one sprite per piece). Drawn flat under everything
## y-sorted (z_index -3: above water and ground cover), so the player walks
## out on it. The docks are symmetric end to end, so a vertical and a
## horizontal render cover all four directions; the stairs aren't, so they
## have one render per direction they descend toward.

const SPRITE_SCALE := 0.5

## Ground half-length along the dock in world px: 3.69 units x 13.554,
## foreshortened by sin 55deg when it runs up/down the screen.
const HALF_LENGTH_VERTICAL := 41.0
const HALF_LENGTH_HORIZONTAL := 50.0
## Stairs: 1.61 units x 13.554 (x sin 55deg vertically).
const STAIRS_HALF_VERTICAL := 17.9
const STAIRS_HALF_HORIZONTAL := 21.8

## offset: (center_x, -center_y) * 27.108 of each render's canvas.
const VARIANTS := {
	"vertical": {
		"long_rope": {"offset": Vector2(0, -18.70), "textures": [preload("res://assets/sprites/dock/dock_long_vertical_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_vertical_55deg_normal.png")]},
		"long": {"offset": Vector2(0, -18.70), "textures": [preload("res://assets/sprites/dock/dock_long_no_rope_vertical_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_no_rope_vertical_55deg_normal.png")]},
		"wide": {"offset": Vector2(0.0, -18.54), "textures": [preload("res://assets/sprites/dock/dock_wide_vertical_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_wide_vertical_55deg_normal.png")]},
	},
	"horizontal": {
		"long_rope": {"offset": Vector2(0, -19.38), "textures": [preload("res://assets/sprites/dock/dock_long_horizontal_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_horizontal_55deg_normal.png")]},
		"long": {"offset": Vector2(0, -19.38), "textures": [preload("res://assets/sprites/dock/dock_long_no_rope_horizontal_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_long_no_rope_horizontal_55deg_normal.png")]},
		"wide": {"offset": Vector2(-0.0, -18.35), "textures": [preload("res://assets/sprites/dock/dock_wide_horizontal_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_wide_horizontal_55deg_normal.png")]},
	},
}

## Rowboat (x0.4), keyed by the direction its bow points.
const BOATS := {
	"down": {"offset": Vector2(0.0, -11.66), "textures": [preload("res://assets/sprites/dock/boat_down_55deg_albedo.png"), preload("res://assets/sprites/dock/boat_down_55deg_normal.png")]},
	"up": {"offset": Vector2(-0.0, -6.26), "textures": [preload("res://assets/sprites/dock/boat_up_55deg_albedo.png"), preload("res://assets/sprites/dock/boat_up_55deg_normal.png")]},
	"left": {"offset": Vector2(3.44, -6.8), "textures": [preload("res://assets/sprites/dock/boat_left_55deg_albedo.png"), preload("res://assets/sprites/dock/boat_left_55deg_normal.png")]},
	"right": {"offset": Vector2(-3.44, -6.8), "textures": [preload("res://assets/sprites/dock/boat_right_55deg_albedo.png"), preload("res://assets/sprites/dock/boat_right_55deg_normal.png")]},
}

## Half the width across each dock kind in world px (units x 13.554, x sin
## 55deg across a horizontal dock), and the boat's half-beam likewise - for
## mooring a boat alongside.
const HALF_WIDTH := {"long_rope": 21.2, "long": 21.2, "wide": 33.7}
const BOAT_HALF_BEAM := 12.6

## Stairs, keyed by the direction they step down toward.
const STAIRS := {
	"down": {"offset": Vector2(1.36, -16.08), "textures": [preload("res://assets/sprites/dock/dock_stairs_down_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_stairs_down_55deg_normal.png")]},
	"up": {"offset": Vector2(-1.36, -13.96), "textures": [preload("res://assets/sprites/dock/dock_stairs_up_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_stairs_up_55deg_normal.png")]},
	"left": {"offset": Vector2(-0.73, -16.48), "textures": [preload("res://assets/sprites/dock/dock_stairs_left_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_stairs_left_55deg_normal.png")]},
	"right": {"offset": Vector2(0.73, -18.87), "textures": [preload("res://assets/sprites/dock/dock_stairs_right_55deg_albedo.png"), preload("res://assets/sprites/dock/dock_stairs_right_55deg_normal.png")]},
}


## A moored boat rocks: a faint ring off its hull every few seconds.
const BOAT_RIPPLE_INTERVAL := Vector2(2.5, 4.5)

## Stairs' half extents across/along in world px (8.7 x 9.5 units x 0.34).
const STAIRS_HALF_WIDTH := 20.0

var _is_boat := false
## World-space area the player can walk on over deep water (docks and
## stairs; empty for boats).
var walk_rect := Rect2()
var _ripple_timer := 0.0


func _ready() -> void:
	set_process(_is_boat)
	_ripple_timer = randf_range(0.0, BOAT_RIPPLE_INTERVAL.y)


func _process(delta: float) -> void:
	_ripple_timer -= delta
	if _ripple_timer <= 0.0:
		_ripple_timer = randf_range(BOAT_RIPPLE_INTERVAL.x, BOAT_RIPPLE_INTERVAL.y)
		Ripple.spawn(get_parent(), global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0)), 30.0, 0.35, 2.2)


static func half_length(vertical: bool) -> float:
	return HALF_LENGTH_VERTICAL if vertical else HALF_LENGTH_HORIZONTAL


static func stairs_half_length(vertical: bool) -> float:
	return STAIRS_HALF_VERTICAL if vertical else STAIRS_HALF_HORIZONTAL


## Whether `pos` is on any dock or stairs (see Player's wading limit).
static func on_walkway(tree: SceneTree, pos: Vector2) -> bool:
	for node in tree.get_nodes_in_group("walkways"):
		if node.walk_rect.has_point(pos):
			return true
	return false


func setup(vertical: bool, kind: String) -> void:
	_apply(VARIANTS["vertical" if vertical else "horizontal"][kind])
	var along := half_length(vertical)
	var across := half_width(vertical, kind)
	_set_walkway(Vector2(across, along) if vertical else Vector2(along, across))


static func half_width(vertical: bool, kind: String) -> float:
	return HALF_WIDTH[kind] * (1.0 if vertical else sin(deg_to_rad(55.0)))


static func boat_half_beam(vertical: bool) -> float:
	return BOAT_HALF_BEAM * (1.0 if vertical else sin(deg_to_rad(55.0)))


## bow: "down", "up", "left" or "right".
func setup_boat(bow: String) -> void:
	_is_boat = true
	_apply(BOATS[bow])


## descend: "down", "up", "left" or "right" - the way the steps lead.
func setup_stairs(descend: String) -> void:
	_apply(STAIRS[descend])
	var vertical := descend == "up" or descend == "down"
	var along := stairs_half_length(vertical)
	var across := STAIRS_HALF_WIDTH * (1.0 if vertical else sin(deg_to_rad(55.0)))
	_set_walkway(Vector2(across, along) if vertical else Vector2(along, across))


## `position` must already be set (map_generator sets it before setup).
func _set_walkway(half: Vector2) -> void:
	# A little slack so walking off the end onto the stairs isn't snagged.
	walk_rect = Rect2(position - half - Vector2(2, 2), half * 2.0 + Vector2(4, 4))
	add_to_group("walkways")


func _apply(variant: Dictionary) -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = variant.textures[0]
	tex.normal_texture = variant.textures[1]
	texture = tex
	offset = variant.offset
	scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
