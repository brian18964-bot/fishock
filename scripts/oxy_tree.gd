class_name OxyTree
extends GlowMushroom

## User request: the oxygen algae (魚氧樹, Profile.USABLES "oxy_tree") -
## a tuft of water plant in the shallows along a shore (MapGenerator
## ._scatter_oxy_trees), picked like the glow mushroom (採集), used on a carried
## fish to slow its vitality's run-down (FishLife.use_oxy_tree). The same
## sort of thing as the mushroom - it doesn't glow, and sways instead.

## How many to a map (the campaign's smaller ones fewer).
const TREES_PER_MAP := Vector2i(3, 5)
## How far in from the shore's edge it grows (px).
const FROM_SHORE := Vector2(6.0, 14.0)


func _init() -> void:
	item_id = "oxy_tree"
	label = "魚氧樹"
	group_name = "oxy_tree"
	lit = false


## (it only sways: nothing to breathe)
func glow() -> float:
	return 0.5
