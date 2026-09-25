class_name DroppedFish
extends Area2D

## Design doc request: fish dropped on the ground (via Player's drop-fish
## key) lose value the longer they sit - anyone can walk up and pick them
## back up, including the player who dropped them (e.g. after ducking out
## of a ghost's sight). Past ROT_TIME they flip to permanently "rotten":
## no longer worth normal quota credit, but sacrificeable for a gamble -
## see GameState.sacrifice_one()'s rotten branch.

const ROT_TIME := 70.0
const MIN_VALUE_RATIO := 0.15

var fish_name: String = "魚"
var base_value: float = 0.0
## Its size in the backpack (Inventory).
var size: String = "small"
var age: float = 0.0

@onready var visual: ColorRect = $Visual
@onready var label: Label = $Label

const FRESH_COLOR := Color(0.9, 0.75, 0.2, 1)
const ROTTEN_COLOR := Color(0.35, 0.3, 0.15, 1)


func _ready() -> void:
	# The big ghost goes for these (BigGhost._check_fish()).
	add_to_group("dropped_fish")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func setup(fish: Dictionary) -> void:
	fish_name = fish.get("name", "魚")
	base_value = float(fish.get("value", 0))
	size = Inventory.fish_size(fish)


func _process(delta: float) -> void:
	age += delta
	var freshness: float = _freshness()
	if is_rotten():
		visual.color = ROTTEN_COLOR
		label.text = "腐敗的%s" % fish_name
	else:
		visual.color = FRESH_COLOR.lerp(ROTTEN_COLOR, 1.0 - freshness)
		label.text = "%s（%.0f）" % [fish_name, current_value()]


func is_rotten() -> bool:
	return age >= ROT_TIME


func current_value() -> float:
	var value: float = base_value * lerp(MIN_VALUE_RATIO, 1.0, _freshness())
	return value


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
	if is_rotten():
		return {"name": fish_name, "value": 0.0, "tier": "rotten", "rotten": true, "size": size}
	return {"name": fish_name, "value": current_value(), "tier": "dropped", "rotten": false, "size": size}


## Eaten by the big ghost: gone, and no longer on offer to a player
## standing over it.
func eaten() -> void:
	remove_from_group("dropped_fish")
	for body in get_overlapping_bodies():
		if body.has_method("set_in_dropped_fish"):
			body.set_in_dropped_fish(false, self)
	queue_free()


func _freshness() -> float:
	var f: float = clamp(1.0 - age / ROT_TIME, 0.0, 1.0)
	return f


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_dropped_fish"):
		body.set_in_dropped_fish(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_dropped_fish"):
		body.set_in_dropped_fish(false, self)
