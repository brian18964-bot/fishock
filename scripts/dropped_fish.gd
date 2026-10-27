class_name DroppedFish
extends Area2D

## Design doc request: fish dropped on the ground (via Player's drop-fish
## key) go on as they were - anyone can walk up and pick them back up,
## including the player who dropped them (e.g. after ducking out of a
## ghost's sight). Their life goes on (FishLife: vitality, then freshness;
## a rotten one is no longer worth normal quota credit, but sacrificeable
## for a gamble - see GameState.sacrifice_one()'s rotten branch).

var fish_name: String = "魚"
var fish_id := ""
## The catch itself (its length, weight, traits, life...) kept for picking
## it up.
var life := {}
## Its size in the backpack (Inventory).
var size: String = "small"
var age: float = 0.0

@onready var visual: Sprite2D = $Visual
@onready var label: Label = $Label

## User request: the fish itself on the ground (FishData.icon), going
## grey-brown as it rots.
const FRESH_COLOR := Color(1, 1, 1, 1)
const ROTTEN_COLOR := Color(0.5, 0.45, 0.3, 1)
## Its length on the ground (world px), by size.
const LENGTH := {"small": 22.0, "medium": 30.0, "large": 40.0}


func _ready() -> void:
	# The big ghost goes for these (BigGhost._check_fish()).
	add_to_group("dropped_fish")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func setup(fish: Dictionary) -> void:
	fish_name = fish.get("name", "魚")
	fish_id = fish.get("id", FishData.id_for(fish_name))
	size = Inventory.fish_size(fish)
	life = fish.duplicate()
	FishLife.ensure(life)
	var tex := FishData.icon(fish_id, fish_name)
	if tex != null:
		visual.texture = tex
		visual.scale = Vector2.ONE * LENGTH.get(size, 26.0) / tex.get_width()
		# Lying there at an angle, flipped either way.
		visual.rotation = randf_range(-0.5, 0.5)
		visual.flip_h = randf() < 0.5


## Thrown (the 誘惑 throw): flies in an arc to `to` and lands there.
func fly_to(to: Vector2, time := 0.5) -> void:
	var from := global_position
	var lift := minf(from.distance_to(to) * 0.35, 80.0)
	var tween := create_tween()
	tween.tween_method(func(k: float):
		global_position = from.lerp(to, k)
		visual.position.y = -sin(k * PI) * lift
		visual.rotation += 0.25, 0.0, 1.0, time)


func _process(delta: float) -> void:
	age += delta
	FishLife.tick(life, delta, GameState.is_night)
	match FishLife.state(life):
		"rotten":
			visual.modulate = ROTTEN_COLOR
			label.text = "腐敗的%s" % fish_name
		"dead":
			visual.modulate = FRESH_COLOR.lerp(ROTTEN_COLOR, 1.0 - float(life.fresh))
			label.text = "%s（已死亡 %.0f）" % [fish_name, current_value()]
		_:
			visual.modulate = FRESH_COLOR
			label.text = "%s（%.0f）" % [fish_name, current_value()]


## How lively it is (RunView3D: a living one flaps, a dead one lies still).
func _freshness() -> float:
	return 0.3 + 0.7 * float(life.get("vit", 0.0)) if FishLife.state(life) == "alive" else 0.0


func is_rotten() -> bool:
	return FishLife.state(life) == "rotten"


func current_value() -> float:
	return FishLife.worth(life)


## Removes this node from the world and hands back a carried_fish-shaped
## dict for GameState.add_carried_fish() - rotten pickups carry no normal
## value, only the "rotten" flag that unlocks the sacrifice gamble.
func pick_up() -> Dictionary:
	remove_from_group("dropped_fish")
	var fish := as_fish()
	queue_free()
	return fish


## What it'd be back in the backpack.
func as_fish() -> Dictionary:
	var fish := life.duplicate()
	fish.merge({"name": fish_name, "id": fish_id, "size": size}, true)
	if not is_rotten():
		fish["tier"] = "dropped"
	return fish


## Eaten by the big ghost: gone, and no longer on offer to a player
## standing over it.
func eaten() -> void:
	remove_from_group("dropped_fish")
	for body in get_overlapping_bodies():
		if body.has_method("set_in_dropped_fish"):
			body.set_in_dropped_fish(false, self)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_dropped_fish"):
		body.set_in_dropped_fish(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_dropped_fish"):
		body.set_in_dropped_fish(false, self)
