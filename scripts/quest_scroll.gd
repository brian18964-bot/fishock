class_name QuestScroll
extends RefCounted

## User request (the sign over Mr. Croc's head, after a picture of one the user gave): a rolled
## scroll - its roll across the top, its end showing the turns of the paper, the sheet hanging below
## with a wavy edge and a little curl at its foot, written on - drawn here line by line in our own
## colours (the user's picture only shown the look). With a tick in a green ring when there are fish
## to hand him. Drawn over his head (TitleScreen's mark), by each errand in his window (CrocTalk) and
## at the head of the errands' list (QuestTracker).

const PAPER := Color(0.94, 0.84, 0.6)
const ROLL := Color(0.84, 0.68, 0.43)
const END := Color(0.62, 0.42, 0.24)
const INK := Color(0.33, 0.2, 0.1)
const WRITING := Color(0.55, 0.42, 0.28, 0.75)


## The scroll filling `r` of `ci`, its paper tinted `tint` (white: as it is); `done`, the tick.
static func draw(ci: CanvasItem, r: Rect2, tint := Color.WHITE, done := false) -> void:
	var p := func(u: float, v: float) -> Vector2: return r.position + Vector2(u * r.size.x, v * r.size.y)
	var line_w := maxf(1.0, r.size.x / 22.0)
	# The sheet: from under the roll down to a wavy foot.
	var sheet := PackedVector2Array([p.call(0.17, 0.2), p.call(0.83, 0.2), p.call(0.86, 0.48), p.call(0.82, 0.84),
		p.call(0.62, 0.8), p.call(0.42, 0.88), p.call(0.2, 0.84), p.call(0.14, 0.52)])
	ci.draw_colored_polygon(sheet, PAPER * tint)
	ci.draw_polyline(sheet + PackedVector2Array([sheet[0]]), INK, line_w, true)
	# (its writing)
	for k in 3:
		var v := 0.38 + k * 0.13
		ci.draw_line(p.call(0.27, v), p.call(0.73 - k * 0.06, v), WRITING, maxf(1.0, line_w * 0.8), true)
	# The curl at its foot.
	var curl_c: Vector2 = p.call(0.8, 0.84)
	_ellipse(ci, curl_c, Vector2(r.size.x * 0.08, r.size.y * 0.055), ROLL * tint, INK, line_w)
	_ellipse(ci, curl_c, Vector2(r.size.x * 0.035, r.size.y * 0.025), END, Color(0, 0, 0, 0), 0.0)
	# The roll across the top, longer than the sheet is wide, its right end showing the paper's turns.
	var roll := PackedVector2Array()
	var left_c: Vector2 = p.call(0.12, 0.13)
	var right_c: Vector2 = p.call(0.88, 0.13)
	var ry := r.size.y * 0.1
	var rx := r.size.x * 0.06
	for i in 9:
		var a := PI * 0.5 + PI * float(i) / 8.0
		roll.append(left_c + Vector2(cos(a) * rx, -sin(a) * ry))
	for i in 9:
		var a := -PI * 0.5 + PI * float(i) / 8.0
		roll.append(right_c + Vector2(cos(a) * rx, -sin(a) * ry))
	ci.draw_colored_polygon(roll, ROLL * tint)
	ci.draw_polyline(roll + PackedVector2Array([roll[0]]), INK, line_w, true)
	# (a highlight along it)
	ci.draw_line(p.call(0.15, 0.09), p.call(0.82, 0.09), Color(1, 1, 1, 0.35), maxf(1.0, line_w * 0.8), true)
	_ellipse(ci, right_c, Vector2(rx, ry), END, INK, line_w)
	_ellipse(ci, right_c + Vector2(rx * 0.15, 0), Vector2(rx * 0.55, ry * 0.55), END.darkened(0.25), Color(0, 0, 0, 0), 0.0)
	if done:
		var c: Vector2 = p.call(0.78, 0.74)
		var rad := r.size.x * 0.24
		ci.draw_circle(c, rad + line_w, INK)
		ci.draw_circle(c, rad, Color(0.3, 0.72, 0.36))
		ci.draw_polyline(PackedVector2Array([c + Vector2(-0.5, 0.0) * rad, c + Vector2(-0.12, 0.38) * rad, c + Vector2(0.55, -0.38) * rad]),
			Color.WHITE, maxf(1.5, line_w * 1.2), true)


static func _ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, fill: Color, edge: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_colored_polygon(pts, fill)
	if width > 0.0 and edge.a > 0.0:
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), edge, width, true)
