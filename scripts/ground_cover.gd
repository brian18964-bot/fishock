extends Sprite2D

## A plant or a thing lying about (user decision: the game is 3D now -
## RunView3D shows each as its model by `kind`; no picture): a fern
## ("plant", "shrub"), a lily pad ("lilypad", on the water), a washed-up
## log ("driftwood"). Purely decorative (no collision). User request: not
## crowded - map_generator.gd scatters few.

## Map theme (map_generator.gd): kind -> weight, or one forced kind (a
## lily pad, driftwood). Set before the plant enters the tree.
var kind_weights: Dictionary = {}
var kind_override := ""
## (kept for the generator's calls; one look per kind now)
var variant_choices: Array = []
var kind := ""

const KINDS := ["plant", "shrub", "lilypad", "driftwood"]


func _ready() -> void:
	kind = kind_override if kind_override != "" else _pick_kind()


func _pick_kind() -> String:
	if kind_weights.is_empty():
		return "plant"
	var total := 0.0
	for k in kind_weights:
		total += kind_weights[k]
	var roll := randf() * total
	for k in kind_weights:
		roll -= kind_weights[k]
		if roll <= 0.0:
			return k
	return kind_weights.keys()[0]
