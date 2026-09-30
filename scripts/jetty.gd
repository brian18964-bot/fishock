class_name Jetty
extends Node2D

## User request: the beach and the ruined town have no wooden docks, so
## something else has to take the player out over deep water - on the
## beach a rock jetty (a path of flat stones out into the sea, boulders
## along its sides), in the town a concrete embankment platform (a slab
## with a kerb and mooring bollards). A walkway like a dock (group
## "walkways", walk_rect - see Dock.on_walkway): walked on over the water,
## got on and off at its landward end only. Laid out by map_generator
## (_place_jetties), which also sets the boulders along a rock jetty.

const STYLES := {
	"rock": {"texture": "res://assets/sprites/ground/sea_pebbles_albedo.png", "tint": Color(0.78, 0.76, 0.72),
		"edge": Color(0.32, 0.3, 0.28)},
	"concrete": {"texture": "res://assets/sprites/ground/sidewalk_albedo.png", "tint": Color(0.72, 0.72, 0.7),
		"edge": Color(0.45, 0.45, 0.44)},
}
## World px per texture tile.
const TILE := 256.0

var style := "rock"
## From the water end toward the land (a unit axis direction).
var dir := Vector2.DOWN
var half_length := 60.0
var half_width := 22.0
var walk_rect := Rect2()


func setup(kind: String, center: Vector2, toward_land: Vector2, half_len: float, half_wid: float) -> void:
	style = kind
	position = center
	dir = toward_land
	half_length = half_len
	half_width = half_wid
	var half := Vector2(half_wid, half_len) if dir.x == 0.0 else Vector2(half_len, half_wid)
	walk_rect = Rect2(center - half, half * 2.0)
	z_index = -3
	add_to_group("walkways")
	_build_surface(half)
	_add_walls()


func _build_surface(half: Vector2) -> void:
	var spec: Dictionary = STYLES[style]
	var slab := Polygon2D.new()
	var pts := PackedVector2Array()
	if style == "rock":
		# Uneven stone edges: the outline wobbles a little.
		var n := 28
		for i in n:
			var a := TAU * i / n
			var p := Vector2(cos(a), sin(a))
			var box := Vector2(signf(p.x) * minf(absf(p.x) * 1.6, 1.0), signf(p.y) * minf(absf(p.y) * 1.6, 1.0))
			pts.append(box * half * randf_range(0.92, 1.04))
	else:
		pts = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	slab.polygon = pts
	slab.texture = load(spec.texture)
	slab.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	slab.texture_scale = Vector2.ONE * (1024.0 / TILE)
	slab.texture_offset = position
	slab.color = spec.tint
	add_child(slab)
	var rim := Line2D.new()
	rim.points = pts
	rim.closed = true
	rim.width = 5.0 if style == "concrete" else 2.0
	rim.default_color = spec.edge
	add_child(rim)
	if style == "concrete":
		# Mooring bollards along the water end's sides.
		for s in [-1.0, 1.0]:
			var along := -dir * (half_length - 10.0)
			var across: Vector2 = Vector2(dir.y, dir.x) * s * (half_width - 7.0)
			var post := Polygon2D.new()
			var circle := PackedVector2Array()
			for i in 12:
				circle.append(Vector2(cos(TAU * i / 12.0), sin(TAU * i / 12.0) * 0.8) * 4.5)
			post.polygon = circle
			post.color = Color(0.2, 0.21, 0.23)
			post.position = along + across
			add_child(post)


## Walls along the sides and the water end: on and off at the land end.
func _add_walls() -> void:
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
		if side.is_equal_approx(dir):
			continue
		var seg := SegmentShape2D.new()
		seg.a = edges[side][0]
		seg.b = edges[side][1]
		var shape := CollisionShape2D.new()
		shape.shape = seg
		body.add_child(shape)
	add_child(body)
	body.position = Vector2.ZERO


## Points along the two long sides, just outside (for the boulders).
func side_points(step: float) -> Array:
	var out := []
	var across := Vector2(absf(dir.y), absf(dir.x))
	var n := int(half_length * 2.0 / step)
	for s in [-1.0, 1.0]:
		for i in n + 1:
			var along: float = -half_length + i * step
			out.append(position + dir * along + across * s * (half_width + 9.0))
	# And round the water end.
	out.append(position - dir * (half_length + 10.0))
	return out
