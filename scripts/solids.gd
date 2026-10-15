class_name Solids
extends RefCounted

## User request (3D): nothing walks into anything. The trees, rocks, the
## camp, the altar and the rune stones are solid bodies the player and the
## animals (physics bodies) bump against; the ghosts, the willow and the
## water ghost move by hand, so they ask here: each step is kept out of
## every solid's base (its radius grown by the mover's own), sliding round
## it rather than stopping dead.
##
## A solid is in the "solids" group with solids() -> [[centre, radii], ...]
## (world px; radii an ellipse's, equal for a circle).


static var _cache := []
static var _cache_frame := -1


## Every solid base in the world: [[centre, radii], ...] (gathered once a
## frame, however many ask).
static func all(tree: SceneTree) -> Array:
	var frame := Engine.get_process_frames()
	if frame == _cache_frame:
		return _cache
	var out := []
	for n in tree.get_nodes_in_group("solids"):
		if n.has_method("solids"):
			out.append_array(n.solids())
	_cache = out
	_cache_frame = frame
	return out


## How far `p` sits inside the solid (centre `c`, radii `r`) grown by
## `pad`: > 1 outside, < 1 inside; and the way out (unit).
static func _inside(p: Vector2, c: Vector2, r: Vector2, pad: float) -> Array:
	var d := p - c
	var g := r + Vector2(pad, pad)
	var e := Vector2(d.x / g.x, d.y / g.y)
	var out := Vector2(e.x / g.x, e.y / g.y)
	return [e.length(), out.normalized() if out.length() > 0.0001 else Vector2.UP]


## `p` moved out of every solid (grown by `pad`).
static func clear(tree: SceneTree, p: Vector2, pad: float, bases: Array = []) -> Vector2:
	if bases.is_empty():
		bases = all(tree)
	for _pass in 2:
		for b in bases:
			var c: Vector2 = b[0]
			var r: Vector2 = b[1]
			var hit := _inside(p, c, r, pad)
			if float(hit[0]) < 1.0:
				var d := p - c
				var g := r + Vector2(pad, pad)
				var e := Vector2(d.x / g.x, d.y / g.y)
				e = e.normalized() if e.length() > 0.0001 else Vector2.UP
				p = c + Vector2(e.x * g.x, e.y * g.y) * 1.001
	return p


## The step from `from` toward `to` for a mover of radius `pad`: as far
## as it goes, round any solid in the way (along its side, the way that's
## nearer the aim), never into one.
static func step(tree: SceneTree, from: Vector2, to: Vector2, pad: float) -> Vector2:
	var bases := all(tree)
	var move := to - from
	if move.length() < 0.0001:
		return clear(tree, from, pad, bases)
	for b in bases:
		var hit := _inside(to, b[0], b[1], pad)
		if float(hit[0]) < 1.0:
			# Along the side instead: the inward part of the step dropped.
			var n: Vector2 = hit[1]
			var side := n.orthogonal()
			if side.dot(move) < 0.0:
				side = -side
			to = from + side * move.length()
			break
	return clear(tree, to, pad, bases)


## Whether `p` is clear of every solid (grown by `pad`).
static func is_free(tree: SceneTree, p: Vector2, pad: float) -> bool:
	for b in all(tree):
		if float(_inside(p, b[0], b[1], pad)[0]) < 1.0:
			return false
	return true


## User report: a beast or a ghost after you on the far side of the camp
## pressed into it and stuck there (sliding to and fro along its near
## side). The way to `to` round whatever's in the straight line from
## `from` (the solids - each as the circle round it - and `extra` circles
## [[centre, radius], ...], the lit camp's keep-out): the nearer side's
## tangent point, a little past it - kept to that side (`memo`, the mover's
## own) while it's going round the same thing, so it doesn't dither. `to`
## itself when the way is clear.
static func detour(tree: SceneTree, from: Vector2, to: Vector2, pad: float, memo: Dictionary, extra: Array = []) -> Vector2:
	var way := to - from
	var length := way.length()
	if length < 1.0:
		memo.clear()
		return to
	var u := way / length
	var hit_c := Vector2.ZERO
	var hit_r := 0.0
	var best := INF
	# (the camp gone round as one - its drums, fire and tent - not one by one)
	var circles := []
	for st in tree.get_nodes_in_group("fuel_stations"):
		var round_camp: Array = FuelStation.bounds()
		var at: Vector2 = (st as Node2D).global_position + (round_camp[0] as Vector2)
		# (already inside the circle round it - between its fire, drums and
		# tent: those gone round one by one instead)
		if from.distance_to(at) >= float(round_camp[1]):
			circles.append([at, float(round_camp[1])])
	var camps := circles.duplicate()
	for b in all(tree):
		var r: Vector2 = b[1]
		var inside := false
		for c in camps:
			inside = inside or (b[0] as Vector2).distance_to(c[0]) < float(c[1])
		if not inside:
			circles.append([b[0], maxf(r.x, r.y)])
	circles.append_array(extra)
	for c in circles:
		var centre: Vector2 = c[0]
		var reach: float = float(c[1]) + pad
		# (in it already, or what's wanted is: nothing to go round)
		if (from - centre).length() < float(c[1]) or (to - centre).length() < float(c[1]):
			continue
		var t := (centre - from).dot(u)
		if t < 0.0 or t > length:
			continue
		if (from + u * t - centre).length() >= reach:
			continue
		if t < best:
			best = t
			hit_c = centre
			hit_r = reach
	if best == INF:
		memo.clear()
		return to
	var key := Vector2i(hit_c.round())
	var away := from - hit_c
	var dist := away.length()
	var round_r := hit_r * 1.15
	var theta := acos(clampf(round_r / maxf(dist, round_r), -1.0, 1.0))
	var sides := [away.normalized().rotated(theta), away.normalized().rotated(-theta)]
	var side: int
	if memo.get("key") == key:
		side = int(memo.side)
	else:
		# (the side whose way round is the shorter to the target)
		var a: Vector2 = hit_c + sides[0] * round_r
		var b: Vector2 = hit_c + sides[1] * round_r
		side = 0 if a.distance_to(to) + a.distance_to(from) <= b.distance_to(to) + b.distance_to(from) else 1
		memo.key = key
		memo.side = side
	var tangent: Vector2 = hit_c + (sides[side] as Vector2) * round_r
	if dist <= round_r * 1.02:
		# (up against it already: along its rim, the chosen way)
		var along := away.orthogonal().normalized() * (1.0 if side == 1 else -1.0)
		return from + along * hit_r
	return tangent + (tangent - from).normalized() * hit_r * 0.5
