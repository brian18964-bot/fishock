extends Node2D

## User request: Willow, a harmless NPC by the altar (the user's little
## horned creature with its staff - tools/render_characters.py, 8 facings).
## For now it just stands there breathing and turns to watch the player
## when they come near; talking to the player comes later.

const SHEET := [preload("res://assets/sprites/willow/willow_55deg_albedo.png"), preload("res://assets/sprites/willow/willow_55deg_normal.png")]
const SPRITE_SCALE := 0.5
## (0, -center_y) * 27.108 for the render's camera.
const OFFSET := Vector2(0.0, -14.36)
const DIRS := 8
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]
const WATCH_RANGE := 170.0

var _time := randf() * 5.0

@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	visual.texture = tex
	visual.hframes = DIRS
	Art.place(visual, OFFSET, SPRITE_SCALE)


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var dir := 0  # facing down, out of the altar
	if player != null:
		var to := player.global_position - global_position
		if to.length() < WATCH_RANGE and to.length() > 1.0:
			dir = SECTOR_TO_DIR[posmod(roundi(to.angle() / (PI / 4.0)), 8)]
	visual.frame = dir
	# Breathing.
	var s := 1.0 + sin(_time * 2.1) * 0.02
	visual.scale = Vector2(SPRITE_SCALE / Art.DENSITY, SPRITE_SCALE / Art.DENSITY * s)
