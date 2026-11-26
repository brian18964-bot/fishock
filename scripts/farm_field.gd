class_name FarmField
extends Node2D

## User request (the countryside): a field - ploughed ("plough"), its stubble after the harvest with
## round bales lying on it ("stubble"), or in rows of pumpkins ("pumpkin") or leafy greens
## ("greens"); (the English village) a pasture walled in, its grass the meadow's ("pasture").
## Nothing solid: walked across freely (only its fences and bales are in the way). This is its place
## (`rect`, px, square to the map); RunView3D paints its ground and grows its rows (FarmBuild).

const CROPS := ["plough", "stubble", "pumpkin", "greens", "pasture"]

var rect := Rect2()
var crop := "plough"
var seed_value := 0


func _ready() -> void:
	add_to_group("farm_fields")
