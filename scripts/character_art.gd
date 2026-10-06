class_name CharacterArt
extends RefCounted

## User request: the four animal people in the game, the camp's fire
## changing who's travelling (Profile.character). Each one's pictures:
##   assets/sprites/player/<id>/player_55deg_*        the run sheet, its
##       front layer and rod data (tools/render_player.py --grip)
##   assets/sprites/player/<id>/player_struggle_55deg_*   in the big ghost's
##       grip (tools/render_player_struggle.py)
##   assets/models/characters/<id>.glb   the camp's 3D character
##       (tools/build_menu_character.py)
## Loaded when asked, for the one travelling (the others stay on disk).

const SPRITES := "res://assets/sprites/player/%s/"
const MODEL := "res://assets/models/characters/%s.glb"
## The status card's portrait: the head in the idle sheet's first cell
## (facing down; texels of the 2x sheet), per character - 44 px square,
## from 2 px over the head's top, centred on it.
const PORTRAIT := {
	"cat": Rect2(34, 11, 44, 44),
	"owl": Rect2(33, 25, 44, 44),
	"dog": Rect2(41, 21, 44, 44),
	"bear": Rect2(33, 27, 44, 44),
}
## Where the left hand gets to reaching out (CharacterRig.REACH_CLIP at
## REACH_AT; the character's frame, +z ahead, +x its left), per character:
## where the camp's lamp hangs to be picked up. Measured on each model (its
## index fingertip, index_04_leaf_l).
const REACH := {
	"cat": Vector3(0.10, 1.00, 0.42),
	"owl": Vector3(0.13, 1.09, 0.49),
	"dog": Vector3(0.14, 1.16, 0.51),
	"bear": Vector3(0.20, 1.10, 0.50),
}


static func _id(id: String) -> String:
	return id if id != "" else Profile.character


## The run sheet: [albedo, normal].
static func sheet(id := "") -> Array:
	var dir := SPRITES % _id(id)
	return [load(dir + "player_55deg_albedo.png"), load(dir + "player_55deg_normal.png")]


## The run sheet's front layer (its alpha the mask).
static func front_mask(id := "") -> Texture2D:
	return load(SPRITES % _id(id) + "player_55deg_front_albedo.png")


## The run sheet's rod data (held_rod.gd, body_front.gd).
static func rod_data(id := "") -> Dictionary:
	return (load(SPRITES % _id(id) + "player_55deg_rod.json") as JSON).data


## The struggle sheet: [albedo, normal].
static func struggle(id := "") -> Array:
	var dir := SPRITES % _id(id)
	return [load(dir + "player_struggle_55deg_albedo.png"), load(dir + "player_struggle_55deg_normal.png")]


static func model(id := "") -> PackedScene:
	return load(MODEL % _id(id))


static func portrait(id := "") -> Rect2:
	return PORTRAIT.get(_id(id), PORTRAIT.cat)


static func reach(id := "") -> Vector3:
	return REACH.get(_id(id), REACH.cat)
