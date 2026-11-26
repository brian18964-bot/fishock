class_name StreetProp
extends StaticBody2D

## User request (the ruined human world - the city): what's left in its streets - cars abandoned by
## the kerb or slewed across the road, street lamps along the pavements (a few, on their own
## panels, still lit at night: to find one's way by), and (user request - the user's models, made
## ours by tools/make_city_assets.py) oil drums, crates and benches about. This is one's place and
## its solid ground; RunView3D shows it (CityBuild.props: the remade jeeps, drums, crates and
## benches; the lamps our own shapes).

## (a car's length and width, a lamp post's thickness - px)
const CAR := Vector2(119.0, 55.0)
const LAMP_R := 8.0
## (user request - the user's models, made ours: an oil drum, a crate, a bench too; how big round
## each is (px) - a bench two circles along its length)
const ROUND := {"drum": 10.0, "crate": 16.0, "bench": 10.0}
const BENCH_LONG := 37.0
## User request (the countryside - an ordinary place; the user's farm set, made ours by
## tools/make_farm_assets.py): what stands about its farms - a lantern post by the tracks (a few lit
## at night), a well, a pile of logs or a stack of lumber, a barrel, a hay wagon, a wheelbarrow, a
## trough, a milk can, a round hay bale lying in a field after the harvest, a fruit tree of an
## orchard (its low branches in the way). Each [radius, length] (px; a long one two circles along
## its length, 0 a round one) - about its model's size.
const FARM := {"lantern": [7.0, 0.0], "well": [40.0, 0.0], "logs": [16.0, 0.0], "lumber": [15.0, 86.0],
	"barrel": [9.0, 0.0], "wagon": [20.0, 119.0], "barrow": [15.0, 68.0], "trough": [10.0, 54.0],
	"milk": [6.0, 0.0], "bale": [19.0, 34.0], "fruit": [30.0, 0.0]}

var kind := "car"
## Its heading (rad, on the map: 0 along +x).
var yaw := 0.0
## A lamp still lit at night.
var lit := false
var seed_value := 0
var _bases: Array = []


func _ready() -> void:
	add_to_group("solids")
	add_to_group("street_props")
	var shape := shape_of(kind)
	if shape.y > 0.0:
		# (two circles along its length)
		var along := Vector2(cos(yaw), sin(yaw)) * (shape.y * 0.5 - shape.x)
		for at in [along, -along]:
			_add_circle(at, shape.x)
	else:
		_add_circle(Vector2.ZERO, shape.x)


func _add_circle(at: Vector2, r: float) -> void:
	var shape := CircleShape2D.new()
	shape.radius = r
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = at
	add_child(col)
	_bases.append([at, Vector2(r, r)])


func solids() -> Array:
	var out := []
	for b in _bases:
		out.append([global_position + (b[0] as Vector2), b[1]])
	return out


## How far it reaches from its middle (px) - kept clear by what's placed round it.
func reach() -> float:
	return reach_of(kind)


static func reach_of(which: String) -> float:
	var shape := shape_of(which)
	return maxf(shape.x, shape.y * 0.5)


## Its solid ground: (radius, length) px - a length 0 for a round one.
static func shape_of(which: String) -> Vector2:
	match which:
		"car":
			return Vector2(CAR.y * 0.5, CAR.x)
		"bench":
			return Vector2(float(ROUND.bench), BENCH_LONG)
		"lamp":
			return Vector2(LAMP_R, 0.0)
	if FARM.has(which):
		return Vector2(float(FARM[which][0]), float(FARM[which][1]))
	return Vector2(float(ROUND.get(which, LAMP_R)), 0.0)
