class_name GhostCage
extends Node2D

## User request: the big ghost's cage - an ancient oval iron cage it drags
## caught players into (see BigGhost). Built and rendered by
## tools/render_characters.py as two layers, the bars behind its middle and
## the bars in front, so a prisoner is drawn between them. Solid while
## empty; a prisoner let out walks free, then it closes up again.

const BACK := [preload("res://assets/sprites/cage/cage_back_55deg_albedo.png"), preload("res://assets/sprites/cage/cage_back_55deg_normal.png")]
const FRONT := [preload("res://assets/sprites/cage/cage_front_55deg_albedo.png"), preload("res://assets/sprites/cage/cage_front_55deg_normal.png")]
## A little larger than the render, so a grown man fits inside.
const SPRITE_SCALE := 0.5 * 1.15
## (0, -center_y) * 27.108 for the render's camera.
const OFFSET := Vector2(0.0, -27.76)
## Where a prisoner stands, from the cage's origin (its foot plate's
## middle): back a little, so their feet are on the plate.
const INSIDE := Vector2(0.0, -7.0)
const SHAKE_TIME := 0.35

var prisoner: Node2D = null
var _shake := 0.0

@onready var back: Sprite2D = $Back
@onready var front: Sprite2D = $Front
@onready var body_shape: CollisionShape2D = $Body/CollisionShape2D


func _ready() -> void:
	add_to_group("ghost_cages")
	for pair in [[back, BACK], [front, FRONT]]:
		var tex := CanvasTexture.new()
		tex.diffuse_texture = pair[1][0]
		tex.normal_texture = pair[1][1]
		pair[0].texture = tex
		Art.place(pair[0], OFFSET, SPRITE_SCALE)


func _process(delta: float) -> void:
	if prisoner != null:
		prisoner.global_position = global_position + INSIDE
	elif body_shape.disabled and not _near_player():
		body_shape.set_deferred("disabled", false)
	# The front bars cover a prisoner; otherwise the cage sorts like any prop.
	front.z_index = 1 if prisoner != null else 0
	if _shake > 0.0:
		_shake -= delta
		front.position.x = sin(_shake * 70.0) * 1.2
	else:
		front.position.x = 0.0


func lock(who: Node2D) -> void:
	prisoner = who
	body_shape.set_deferred("disabled", true)
	_shake = SHAKE_TIME


## Rattles the bars (the prisoner struggling).
func rattle() -> void:
	_shake = SHAKE_TIME


func unlock() -> void:
	prisoner = null
	_shake = SHAKE_TIME


func _near_player() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and player.global_position.distance_to(global_position) < 26.0
