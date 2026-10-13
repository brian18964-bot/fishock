class_name Dock
extends Sprite2D

## Wooden docks (user decision: the game is 3D now - RunView3D builds
## them from planks and posts; this is where one is and where it can be
## walked, no picture). map_generator.gd lays one across the edge of a few common water zones,
## pointing at the zone's center: about 30% on land, 70% over water; some
## get stairs at the water end stepping down toward the zone's center
## (setup_stairs(); the same node type, one sprite per piece). Drawn flat under everything
## y-sorted (z_index -3: above water and ground cover), so the player walks
## out on it. The docks are symmetric end to end, so a vertical and a
## horizontal render cover all four directions; the stairs aren't, so they
## have one render per direction they descend toward.

## Ground half-length along the dock in world px: 3.69 units x 13.554,
## foreshortened by sin 55deg when it runs up/down the screen.
const HALF_LENGTH_VERTICAL := 41.0
const HALF_LENGTH_HORIZONTAL := 50.0
## Stairs: 1.61 units x 13.554 (x sin 55deg vertically).
const STAIRS_HALF_VERTICAL := 17.9
const STAIRS_HALF_HORIZONTAL := 21.8

## Half the width across each dock kind in world px (units x 13.554, x sin
## 55deg across a horizontal dock), and the boat's half-beam likewise - for
## mooring a boat alongside.
const HALF_WIDTH := {"long_rope": 21.2, "long": 21.2, "wide": 33.7}
const BOAT_HALF_BEAM := 12.6



## Stairs' half extents across/along in world px (8.7 x 9.5 units x 0.34).
const STAIRS_HALF_WIDTH := 20.0

var _is_boat := false
## (a boat's bow, a flight of steps' way down - for the 3D run's models)
var bow := ""
var descend := ""
## World-space area the player can walk on over deep water (docks and
## stairs; empty for boats).
var walk_rect := Rect2()


static func half_length(vertical: bool) -> float:
	return HALF_LENGTH_VERTICAL if vertical else HALF_LENGTH_HORIZONTAL


static func stairs_half_length(vertical: bool) -> float:
	return STAIRS_HALF_VERTICAL if vertical else STAIRS_HALF_HORIZONTAL


## Whether `pos` is on any dock or stairs (see Player's wading limit).
static func on_walkway(tree: SceneTree, pos: Vector2) -> bool:
	for node in tree.get_nodes_in_group("walkways"):
		if node.walk_rect.has_point(pos):
			return true
	return false


func setup(vertical: bool, kind: String) -> void:
	var along := half_length(vertical)
	var across := half_width(vertical, kind)
	_set_walkway(Vector2(across, along) if vertical else Vector2(along, across))


static func half_width(vertical: bool, kind: String) -> float:
	return HALF_WIDTH[kind] * (1.0 if vertical else sin(deg_to_rad(55.0)))


static func boat_half_beam(vertical: bool) -> float:
	return BOAT_HALF_BEAM * (1.0 if vertical else sin(deg_to_rad(55.0)))


## bow: "down", "up", "left" or "right".
func setup_boat(toward: String) -> void:
	_is_boat = true
	bow = toward


## descend: "down", "up", "left" or "right" - the way the steps lead.
func setup_stairs(down: String) -> void:
	descend = down
	var vertical := descend == "up" or descend == "down"
	var along := stairs_half_length(vertical)
	var across := STAIRS_HALF_WIDTH * (1.0 if vertical else sin(deg_to_rad(55.0)))
	_set_walkway(Vector2(across, along) if vertical else Vector2(along, across), STAIRS_LIFT)


## `position` must already be set (map_generator sets it before setup).
## User bug report: the walkable area sat ~10 px below the drawn deck (the
## deck stands up on its posts, so the render draws it higher than the
## node's ground point) - you had to come at it from above, and could only
## use part of it. The rect is lifted to match the boards.
const DECK_LIFT := 9.5
const STAIRS_LIFT := 9.5  # same as the deck, so dock and stairs rects meet


func _set_walkway(half: Vector2, lift: float = DECK_LIFT) -> void:
	# A little slack so walking off the end onto the stairs isn't snagged.
	var center := position - Vector2(0.0, lift)
	walk_rect = Rect2(center - half - Vector2(2, 2), half * 2.0 + Vector2(4, 4))
	add_to_group("walkways")


## User request: once on a dock or boardwalk you can't just step off its
## side - you get on and off at its entrance only. Walls run along the
## walkway's edges except on the `open` ends (unit axis directions: the
## land end, plus where stairs join on). Built in world space (top_level),
## as the sprite itself is scaled.
func add_walls(open: Array) -> void:
	var body := StaticBody2D.new()
	body.name = "Rails"
	body.top_level = true
	var r := walk_rect
	var edges := {
		Vector2.UP: [r.position, Vector2(r.end.x, r.position.y)],
		Vector2.DOWN: [Vector2(r.position.x, r.end.y), r.end],
		Vector2.LEFT: [r.position, Vector2(r.position.x, r.end.y)],
		Vector2.RIGHT: [Vector2(r.end.x, r.position.y), r.end],
	}
	for side in edges:
		if open.any(func(o): return o.is_equal_approx(side)):
			continue
		var seg := SegmentShape2D.new()
		seg.a = edges[side][0]
		seg.b = edges[side][1]
		var shape := CollisionShape2D.new()
		shape.shape = seg
		body.add_child(shape)
	add_child(body)
	body.position = Vector2.ZERO  # top_level: this is the world origin
