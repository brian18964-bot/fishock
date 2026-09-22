class_name WaterZone
extends StaticBody2D

## Design doc request: the map is no longer "water everywhere" - it's a
## handful of these, generated fresh each run by map_generator.gd. Common
## zones are easy: walk right up (no collision), cast at any range. Rare
## zones are solid ground can't cross (collision stays enabled), reachable
## only by landing a precise cast on them from outside - see
## Player._launch_cast()/_find_water_zone() for how casting reads these,
## and _update_fishing()'s lure branch for the "reel it past the rare
## zone's edge and the catch is done" shortcut.

enum ZoneType { COMMON, RARE }

var zone_type: int = ZoneType.COMMON
var radius: float = 200.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(type: int, r: float, pos: Vector2) -> void:
	zone_type = type
	radius = r
	global_position = pos

	var shape := CircleShape2D.new()
	shape.radius = r
	collision_shape.shape = shape
	collision_shape.disabled = (type == ZoneType.COMMON)

	add_to_group("water_zones")
	add_to_group("water_zones_rare" if is_rare() else "water_zones_common")

	queue_redraw()


func is_rare() -> bool:
	return zone_type == ZoneType.RARE


func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


## 0 if `point` is already inside; otherwise how far outside the edge.
func distance_to_edge(point: Vector2) -> float:
	var d: float = global_position.distance_to(point) - radius
	return max(d, 0.0)


func _draw() -> void:
	if is_rare():
		draw_circle(Vector2.ZERO, radius, Color(0.5, 0.1, 0.65, 0.45))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.8, 0.3, 0.9, 0.9), 3.0)
	else:
		draw_circle(Vector2.ZERO, radius, Color(0.15, 0.45, 0.8, 0.32))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.35, 0.65, 1.0, 0.7), 2.0)
