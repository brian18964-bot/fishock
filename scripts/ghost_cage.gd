class_name GhostCage
extends Node2D

## The big ghost's lair: where it sleeps out the first part of the day
## (see BigGhost). User request (Camp v2): it no longer drags the player
## off to a cage - caught, the player has a few seconds to struggle free
## where they stand - so there's no cage to see; this only marks the spot.
## (The map generator places it like the altar and the escape point.)


func _ready() -> void:
	add_to_group("ghost_cages")
