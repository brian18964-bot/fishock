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
