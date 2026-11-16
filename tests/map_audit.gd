extends RefCounted
## User report: stuck at the water's edge, the stick doing nothing - "a place to get stuck is not
## allowed to happen". A run's map gone over for it, by the game's own rules (the traveller's
## body against everything solid, Player._too_deep for the water, Player._update_movement for
## the steps):
##   - where the traveller can stand: a grid, CELL px a side, from where it starts on;
##   - whether the altar, the escape stone, the fuel station and every common water's shore
##     are among those places;
##   - the places walked between by the game's own steps (a lattice LATTICE px apart: from each
##     one near something, the stick pushed each of WAYS ways for a lattice step, and where that
##     got to noted): any place that can be walked to from the start but not back from is a
##     trap - the stick moves the traveller about in it, but never out.
## Used by tools/map_audit.gd (many maps) and test_no_stuck_spots (a few).

const CELL := 6.0
## (a place this near is reached: talked to, walked into)
const REACH := 48.0
const STEPS := 6
## How many places next to something to push from, at most (spread over them all).
const PUSH_MAX := 2500


static func audit(p: Player, main: Node) -> Dictionary:
	var out := {"traps": [], "unreached": [], "pockets": [], "cells": 0, "pushed": 0}
	var space := p.get_world_2d().direct_space_state
	var body := p.get_node("CollisionShape2D") as CollisionShape2D
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = body.shape
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	var cols := int(Player.WORLD_WIDTH / CELL)
	var rows := int(Player.WORLD_HEIGHT / CELL)
	var walk := PackedByteArray()
	walk.resize(cols * rows)
	var was := p.position
	for r in rows:
		for c in cols:
			var at := Vector2((c + 0.5) * CELL, (r + 0.5) * CELL)
			if at.x < p.edge or at.y < p.edge or at.x > Player.WORLD_WIDTH - p.edge or at.y > Player.WORLD_HEIGHT - p.edge:
				continue
			if p._too_deep(at):
				continue
			q.transform = Transform2D(0.0, at + body.position)
			if space.intersect_shape(q, 1).is_empty():
				walk[r * cols + c] = 1
	# From where it starts: every place it can walk to.
	var start := _nearest(walk, cols, rows, was)
	var comp := PackedInt32Array()
	comp.resize(cols * rows)
	comp.fill(-1)
	var sizes := []
	var id := 0
	for i in walk.size():
		if walk[i] == 0 or comp[i] >= 0:
			continue
		var n := _flood(walk, comp, cols, rows, i, id)
		sizes.append(n)
		id += 1
	var main_id := comp[start] if start >= 0 else -1
	out.cells = sizes[main_id] if main_id >= 0 else 0
	for k in sizes.size():
		if k != main_id and sizes[k] >= 6:
			out.pockets.append({"cells": sizes[k], "at": _centre(comp, cols, k)})
	# The places that must be got to.
	var places := []
	for n in ["Altar", "EscapePoint"]:
		var node := main.get_node_or_null(n) as Node2D
		if node != null:
			places.append([n, node.global_position])
	for st in p.get_tree().get_nodes_in_group("fuel_stations"):
		places.append(["FuelStation", (st as Node2D).global_position])
	for z in p.get_tree().get_nodes_in_group("water_zones_common"):
		var best := Vector2.INF
		for k in 24:
			var sp: Vector2 = z.shore_point(Vector2.from_angle(TAU * k / 24.0))
			if _reached(comp, cols, rows, main_id, sp, REACH * 0.6):
				best = sp
				break
		if best == Vector2.INF:
			out.unreached.append(["shore of the water at %s" % str((z as Node2D).global_position.round())])
	for pl in places:
		if not _reached(comp, cols, rows, main_id, pl[1], REACH):
			out.unreached.append(["%s at %s" % [pl[0], str((pl[1] as Vector2).round())]])
	# The places next to something, pushed from.
	var edge_cells := []
	for i in walk.size():
		if comp[i] != main_id:
			continue
		var c := i % cols
		var r := i / cols
		var by := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var cc: int = c + d.x
			var rr: int = r + d.y
			if cc < 0 or rr < 0 or cc >= cols or rr >= rows or walk[rr * cols + cc] == 0:
				by = true
				break
		if by:
			edge_cells.append(i)
	var stride := maxi(1, ceili(float(edge_cells.size()) / PUSH_MAX))
	var stick: TouchJoystick = p._move_joystick
	var was_v := p.velocity
	for k in range(0, edge_cells.size(), stride):
		var i: int = edge_cells[k]
		var at := Vector2((i % cols + 0.5) * CELL, (i / cols + 0.5) * CELL)
		var best := 0.0
		for w in 8:
			p.position = at
			p.velocity = Vector2.ZERO
			if "_stuck_for" in p:
				p._stuck_for = 0.0
				p._stuck_moved = 0.0
			stick.output = Vector2.from_angle(TAU * w / 8.0)
			stick.is_pressed = true
			for _s in STEPS:
				p._update_movement()
			best = maxf(best, p.position.distance_to(at))
			if best > 2.0:
				break
		out.pushed += 1
		if best <= 2.0:
			out.traps.append(at)
	stick.output = Vector2.ZERO
	stick.is_pressed = false
	p.position = was
	p.velocity = was_v
	return out


static func _nearest(walk: PackedByteArray, cols: int, rows: int, at: Vector2) -> int:
	var c0 := int(at.x / CELL)
	var r0 := int(at.y / CELL)
	for rad in 30:
		for dr in range(-rad, rad + 1):
			for dc in range(-rad, rad + 1):
				var c := c0 + dc
				var r := r0 + dr
				if c >= 0 and r >= 0 and c < cols and r < rows and walk[r * cols + c] == 1:
					return r * cols + c
	return -1


static func _flood(walk: PackedByteArray, comp: PackedInt32Array, cols: int, rows: int, from: int, id: int) -> int:
	var todo := [from]
	comp[from] = id
	var n := 0
	while not todo.is_empty():
		var i: int = todo.pop_back()
		n += 1
		var c := i % cols
		var r := i / cols
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cc: int = c + d.x
			var rr: int = r + d.y
			if cc < 0 or rr < 0 or cc >= cols or rr >= rows:
				continue
			var j := rr * cols + cc
			if walk[j] == 1 and comp[j] < 0:
				comp[j] = id
				todo.append(j)
	return n


static func _reached(comp: PackedInt32Array, cols: int, rows: int, id: int, at: Vector2, reach: float) -> bool:
	var span := int(ceil(reach / CELL))
	var c0 := int(at.x / CELL)
	var r0 := int(at.y / CELL)
	for dr in range(-span, span + 1):
		for dc in range(-span, span + 1):
			var c := c0 + dc
			var r := r0 + dr
			if c >= 0 and r >= 0 and c < cols and r < rows and comp[r * cols + c] == id \
					and Vector2((c + 0.5) * CELL, (r + 0.5) * CELL).distance_to(at) <= reach:
				return true
	return false


static func _centre(comp: PackedInt32Array, cols: int, id: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for i in comp.size():
		if comp[i] == id:
			sum += Vector2((i % cols + 0.5) * CELL, (i / cols + 0.5) * CELL)
			n += 1
	return (sum / maxi(n, 1)).round()


## (the lattice's spacing, px; a place clear of everything this far round needn't be walked from)
## (6 px: a strip of shore narrower than a coarser lattice's spacing would slip between its places)
const LATTICE := 6.0
const CLEAR := 22.0
const WAYS := 12


## The traps: places the traveller's steps get it into from `p`'s start but never back out of
## (each a place on the lattice, px). Also how many places were walked from.
static func walk_traps(p: Player) -> Dictionary:
	var space := p.get_world_2d().direct_space_state
	var body := p.get_node("CollisionShape2D") as CollisionShape2D
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = body.shape
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	var free := func(at: Vector2) -> bool:
		if at.x < p.edge or at.y < p.edge or at.x > Player.WORLD_WIDTH - p.edge or at.y > Player.WORLD_HEIGHT - p.edge:
			return false
		if p._too_deep(at):
			return false
		q.transform = Transform2D(0.0, at + body.position)
		return space.intersect_shape(q, 1).is_empty()
	var cols := int(Player.WORLD_WIDTH / LATTICE)
	var rows := int(Player.WORLD_HEIGHT / LATTICE)
	var ok := PackedByteArray()
	ok.resize(cols * rows)
	var clear := PackedByteArray()
	clear.resize(cols * rows)
	for r in rows:
		for c in cols:
			var at := Vector2((c + 0.5) * LATTICE, (r + 0.5) * LATTICE)
			if not free.call(at):
				continue
			ok[r * cols + c] = 1
			var all := true
			for k in 12:
				for d in [CLEAR * 0.5, CLEAR]:
					if not free.call(at + Vector2.from_angle(TAU * k / 12.0) * d):
						all = false
						break
				if not all:
					break
			if all:
				clear[r * cols + c] = 1
	var node_at := func(at: Vector2) -> int:
		var c := clampi(int(at.x / LATTICE), 0, cols - 1)
		var r := clampi(int(at.y / LATTICE), 0, rows - 1)
		var near := []
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				var cc := c + dc
				var rr := r + dr
				if cc < 0 or rr < 0 or cc >= cols or rr >= rows or ok[rr * cols + cc] == 0:
					continue
				var node := Vector2((cc + 0.5) * LATTICE, (rr + 0.5) * LATTICE)
				near.append([node.distance_to(at), rr * cols + cc, node])
		near.sort_custom(func(a, b): return a[0] < b[0])
		# The nearest - but not one across a sliver of deep water from it: a place on the shore
		# isn't the dry speck past the sliver, however near.
		for n in near:
			if not (p.has_method("_crosses_deep") and p._crosses_deep(at, n[2])):
				return n[1]
		return -1
	# The ways from each place.
	var out_ways := {}
	var stick: TouchJoystick = p._move_joystick
	var was := p.position
	var was_v := p.velocity
	var steps := maxi(ceili(LATTICE * 1.5 / (Player.SPEED / 60.0)), 4)
	var walked := 0
	for i in ok.size():
		if ok[i] == 0:
			continue
		var c := i % cols
		var r := i / cols
		var to := []
		if clear[i] == 1:
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					var cc := c + dc
					var rr := r + dr
					if (dr != 0 or dc != 0) and cc >= 0 and rr >= 0 and cc < cols and rr < rows and ok[rr * cols + cc] == 1:
						to.append(rr * cols + cc)
		else:
			walked += 1
			var at := Vector2((c + 0.5) * LATTICE, (r + 0.5) * LATTICE)
			for w in WAYS:
				p.position = at
				p.velocity = Vector2.ZERO
				# (the movement's own way, not the safety nets': they're the last resort, not the map)
				if "_stuck_for" in p:
					p._stuck_for = 0.0
					p._stuck_moved = 0.0
				if "_pocket_for" in p:
					p._pocket_for = 0.0
					p._pocket_from = at
				stick.output = Vector2.from_angle(TAU * w / WAYS)
				stick.is_pressed = true
				for _s in steps:
					p._update_movement()
				if p.position.distance_to(at) < LATTICE * 0.6:
					continue
				var j: int = node_at.call(p.position)
				if j >= 0 and j != i and not to.has(j):
					to.append(j)
		out_ways[i] = to
	stick.output = Vector2.ZERO
	stick.is_pressed = false
	p.position = was
	p.velocity = was_v
	var start: int = node_at.call(was)
	if start < 0:
		return {"traps": [], "walked": walked, "reach": 0}
	# Got to from the start; and got back to the start from.
	var reach := {start: true}
	var todo := [start]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		for j in out_ways.get(i, []):
			if not reach.has(j):
				reach[j] = true
				todo.append(j)
	var back_ways := {}
	for i in out_ways:
		for j in out_ways[i]:
			if not back_ways.has(j):
				back_ways[j] = []
			back_ways[j].append(i)
	var home := {start: true}
	todo = [start]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		for j in back_ways.get(i, []):
			if not home.has(j):
				home[j] = true
				todo.append(j)
	var traps := []
	for i in reach:
		if not home.has(i):
			traps.append(Vector2((i % cols + 0.5) * LATTICE, (i / cols + 0.5) * LATTICE))
	return {"traps": traps, "walked": walked, "reach": reach.size()}
