class_name CharacterArt
extends RefCounted

## User request: the animal people in the game (the four, then the deer
## and the sheep), the camp's fire changing who's travelling
## (Profile.character). Each one's pictures:
##   assets/sprites/player/<id>/player_55deg_*        the run sheet, its
##       front layer and rod data (tools/render_player.py --grip)
##   assets/sprites/player/<id>/player_struggle_55deg_*   in the big ghost's
##       grip (tools/render_player_struggle.py)
##   assets/sprites/player/<id>/player_tools_55deg_*   swinging the off
##       hand's thing, and its rod and hand data (tools/render_player_tools.py)
##   assets/sprites/player/<id>/player_moves_55deg_*   the moves (drinking,
##       picking up, cheering...; tools/render_player_moves.py)
##   assets/models/characters/<id>.glb   the camp's 3D character
##       (tools/build_menu_character.py)
## Loaded when asked, for the one travelling (the others stay on disk).

const SPRITES := "res://assets/sprites/player/%s/"
const MODEL := "res://assets/models/characters/%s.glb"
## The status card's portrait: the head in the idle sheet's first cell
## (facing down; texels of the 2x sheet), per character - 44 px square,
## from 2 px over the head's top, centred on it (the deer's lower, its
## face in it with the antlers cut).
const PORTRAIT := {
	"cat": Rect2(34, 11, 44, 44),
	"owl": Rect2(33, 25, 44, 44),
	"dog": Rect2(41, 21, 44, 44),
	"bear": Rect2(33, 27, 44, 44),
	"deer": Rect2(40, 40, 44, 44),
	"sheep": Rect2(34, 23, 44, 44),
}
## Where the left hand gets to reaching out (CharacterRig.REACH_CLIP at
## REACH_AT; the character's frame, +z ahead, +x its left), per character:
## where the camp's lamp hangs to be picked up. Measured on each model (its
## index fingertip, index_04_leaf_l; the Meshy ones - the cat, bear2 on -
## have bigger hands and reach further).
const REACH := {
	"cat": Vector3(0.01, 0.94, 0.62),
	"owl": Vector3(0.13, 1.09, 0.49),
	"dog": Vector3(0.14, 1.16, 0.51),
	"bear": Vector3(0.20, 1.10, 0.50),
	"deer": Vector3(0.14, 1.20, 0.47),
	"sheep": Vector3(0.16, 1.09, 0.49),
	"bear2": Vector3(0.07, 1.00, 0.70),
	"dog2": Vector3(-0.06, 1.18, 0.55),
	"dog3": Vector3(0.00, 1.15, 0.57),
	"deer2": Vector3(-0.01, 1.18, 0.65),
	"owl2": Vector3(-0.06, 1.02, 0.62),
	"croc": Vector3(-0.09, 1.11, 0.67),
}


static func _id(id: String) -> String:
	return id if id != "" else Profile.character


## The run sheet: [albedo, normal].
static func sheet(id := "") -> Array:
	var dir := SPRITES % _id(id)
	return [_pic(dir + "player_55deg_albedo.png"), _pic(dir + "player_55deg_normal.png")]


## (User decision: the game is 3D now - the 2D sheets are gone; the
## character's sheet data, its .json, stays for the run's rules.)
static func _pic(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


## The run sheet's front layer (its alpha the mask).
static func front_mask(id := "") -> Texture2D:
	return _pic(SPRITES % _id(id) + "player_55deg_front_albedo.png")


## The run sheet's rod data (held_rod.gd, body_front.gd).
static func rod_data(id := "") -> Dictionary:
	return (load(SPRITES % _id(id) + "player_55deg_rod.json") as JSON).data


## The struggle sheet: [albedo, normal].
static func struggle(id := "") -> Array:
	var dir := SPRITES % _id(id)
	return [_pic(dir + "player_struggle_55deg_albedo.png"), _pic(dir + "player_struggle_55deg_normal.png")]


## The off hand's swings (user request): [albedo, normal].
## ([] when there's none.)
static func tools(id := "") -> Array:
	var dir := SPRITES % _id(id)
	if not ResourceLoader.exists(dir + "player_tools_55deg_albedo.png"):
		return []
	return [load(dir + "player_tools_55deg_albedo.png"), load(dir + "player_tools_55deg_normal.png")]


## The swings' sheet data: its offset, and per cell the rod (on the back),
## the right hand and the hip (as rod_data()'s); {} when there's none.
static func tools_data(id := "") -> Dictionary:
	var path := SPRITES % _id(id) + "player_tools_55deg_rod.json"
	return (load(path) as JSON).data if ResourceLoader.exists(path) else {}


## The player's moves (user request: the user's Mixamo clips, played as
## the player does things - tools/render_player_moves.py): [albedo, normal]
## ([] when there's none).
static func moves(id := "") -> Array:
	var dir := SPRITES % _id(id)
	if not ResourceLoader.exists(dir + "player_moves_55deg_albedo.png"):
		return []
	return [load(dir + "player_moves_55deg_albedo.png"), load(dir + "player_moves_55deg_normal.png")]


## The moves sheet's data: its cell, offset, clips, sections, and per cell
## the rod on the back, the right hand and the hip; {} when there's none.
static func moves_data(id := "") -> Dictionary:
	var path := SPRITES % _id(id) + "player_moves_55deg_rod.json"
	return (load(path) as JSON).data if ResourceLoader.exists(path) else {}


static func model(id := "") -> PackedScene:
	return load(MODEL % _id(id))


static func portrait(id := "") -> Rect2:
	return PORTRAIT.get(_id(id), PORTRAIT.cat)


## The status card's face, rendered from the 3D model (the 2D sheets are gone).
static func portrait_texture(id := "") -> Texture2D:
	var path := "res://assets/ui/portraits/%s.png" % _id(id)
	return load(path) if ResourceLoader.exists(path) else null


static func reach(id := "") -> Vector3:
	return REACH.get(_id(id), REACH.cat)


## How much further off the drum it stands to lean on it (m; the camp's
## clipping check: the bear's head and belly went into it at the others'
## distance).
const LEAN_BACK := {"bear": 0.1}


static func lean_back(id := "") -> float:
	return float(LEAN_BACK.get(_id(id), 0.0))
