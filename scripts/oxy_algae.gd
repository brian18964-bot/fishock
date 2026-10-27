class_name OxyAlgae
extends GlowMushroom

## User request: the oxygen algae (魚氧藻, Profile.USABLES "oxy_algae") -
## a tuft of water plant in the shallows along a shore (MapGenerator
## ._scatter_algae), picked like the glow mushroom (採集), used on a carried
## fish to slow its vitality's run-down (FishLife.use_algae). The same
## sort of thing as the mushroom - it doesn't glow, and sways instead.

## How many to a map (the campaign's smaller ones fewer).
const ALGAE_PER_MAP := Vector2i(3, 5)
## How far in from the shore's edge it grows (px).
const FROM_SHORE := Vector2(6.0, 14.0)


func _init() -> void:
	item_id = "oxy_algae"
	label = "魚氧藻"
	group_name = "oxy_algae"
	lit = false


## (it only sways: nothing to breathe)
func glow() -> float:
	return 0.5
