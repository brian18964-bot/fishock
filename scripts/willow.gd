extends Node2D

## User request: Willow, a harmless NPC by the altar (the user's little
## horned creature with its staff - tools/render_characters.py, 8 facings).
## It potters about near the altar at random, stopping now and then; when
## the player comes close while it's standing still it turns to watch
## them. Talking to the player comes later.

const SHEET := [preload("res://assets/sprites/willow/willow_55deg_albedo.png"), preload("res://assets/sprites/willow/willow_55deg_normal.png")]
const SPRITE_SCALE := 0.5
## (0, -center_y) * 27.108 for the render's camera.
const OFFSET := Vector2(0.0, -14.36)
const DIRS := 8
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]
const WATCH_RANGE := 170.0
## Its stroll: this far out from the altar's middle, at this pace.
const RING := Vector2(52.0, 100.0)
const SPEED := 20.0
const PAUSE := Vector2(1.5, 4.5)

var _time := randf() * 5.0
var _target := Vector2.ZERO
var _pause := 1.0
var _walking := false
var _dir := 0

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
	var altar := get_tree().current_scene.get_node_or_null("Altar") as Node2D
	if _walking:
		var to := _target - global_position
		if to.length() < 2.0:
			_walking = false
			_pause = randf_range(PAUSE.x, PAUSE.y)
		else:
			global_position += to.limit_length(SPEED * delta)
			_dir = SECTOR_TO_DIR[posmod(roundi(to.angle() / (PI / 4.0)), 8)]
	else:
		_pause -= delta
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var seen := player.global_position - global_position
			if seen.length() < WATCH_RANGE and seen.length() > 1.0:
				_dir = SECTOR_TO_DIR[posmod(roundi(seen.angle() / (PI / 4.0)), 8)]
		if _pause <= 0.0 and altar != null:
			for _try in 8:  # somewhere dry
				_target = altar.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(RING.x, RING.y) * Vector2(1.0, 0.7)
				if Ripple.water_at(get_tree(), _target) == null:
					_walking = true
					break
			_pause = randf_range(PAUSE.x, PAUSE.y)
	visual.frame = _dir
	# A little hop in its step; breathing when it stands.
	var hop := absf(sin(_time * 9.0)) * 1.5 if _walking else 0.0
	visual.position.y = -hop
	var s := 1.0 + sin(_time * 2.1) * 0.02
	visual.scale = Vector2(SPRITE_SCALE / Art.DENSITY, SPRITE_SCALE / Art.DENSITY * s)
