class_name StreetProp
extends StaticBody2D

## User request (the ruined human world - the city): what's left in its streets - cars abandoned by
## the kerb or slewed across the road, street lamps along the pavements (a few, on their own
## panels, still lit at night: to find one's way by). This is one's place and its solid ground;
## RunView3D shows it (CityBuild.props: shapes of our own making till the user's models come).

## (a car's length and width, a lamp post's thickness - px)
const CAR := Vector2(114.0, 50.0)
const LAMP_R := 8.0

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
	if kind == "car":
		# (two circles along its length)
		var r := CAR.y * 0.5
		var along := Vector2(cos(yaw), sin(yaw)) * (CAR.x * 0.5 - r)
		for at in [along, -along]:
			_add_circle(at, r)
	else:
		_add_circle(Vector2.ZERO, LAMP_R)


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
	return CAR.x * 0.5 if kind == "car" else LAMP_R
