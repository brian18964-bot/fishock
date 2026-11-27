extends RefCounted
## User request ("所有物件不可以有穿圖、卡圖的情況，動物們也不能被物件卡住跟穿圖"): a built run's world gone
## over for things in one another as they're drawn, and its animals followed - tools/verify/
## overlap_work.gd (every level) and test_nothing_in_anything (a few) use it.
##
## The things: every building's and yard thing's own outline read from its 3D model (its meshes' box
## in its own frame, turned and scaled as it stands - eaves, porches and sheds included), the trees'
## trunks and their crowns (a crown counted only over a building taller than its lowest leaves; a
## bamboo clump's or a fruit tree's leaves as a crown, their stems as trunks - a grove's leaves meet,
## as in a thicket), the rocks and stones, the fences and walls (long thin boxes), the bridges and
## docks. Two overlapping by more than SLACK px (a crown CROWN_SLACK) count - the camp's own parts
## aside, laid out by hand; so does a thing standing in the water further than WET px (a rock: its
## middle; the sea cliff's rocks aside, in the sea on purpose).

const SLACK := 4.0
const CROWN_SLACK := 14.0
const WET := 6.0
const BODY_SHARE := 0.6
const STUCK_FOR := 4.0
const STUCK_MOVE := 6.0
## (the camp's own parts, laid out by hand: nothing within this of its middle is counted)
const CAMP_CLEAR := 170.0


# ------------------------------------------------------------------ the things

## Every thing that stands somewhere, as drawn: {kind, name, shape: "box"/"circle", c (px), ax, ay
## (unit), h (half extents px) / r (px), top (m), low (m: a tree's lowest leaf), node}.
static func things(tree: SceneTree, view: RunView3D) -> Array:
	var out := []
	# (buildings and yard things: their 3D models' own outlines)
	for n in view.get_children():
		var nm := str(n.name)
		var kind := ""
		if nm.begins_with("RuinModel"):
			kind = "building"
		elif nm.begins_with("FarmProp") or nm.begins_with("StreetPropModel"):
			kind = "thing"
		elif nm == "Bridge" or nm.begins_with("Bridge"):
			kind = "bridge"
		if kind == "" or not n is Node3D:
			continue
		var box := outline(n as Node3D)
		if box.is_empty():
			continue
		box.kind = kind
		box.name = label(tree, n as Node3D, kind)
		var sp := prop_of(tree, n as Node3D)
		if sp != null and sp.kind in LEAFY:
			# (a bamboo clump, a fruit tree: as a tree - its stems' own ground, its leaves only over a
			# building; a grove's leaves meet, as in a thicket)
			for s in sp.solids():
				var rr: Vector2 = s[1]
				out.append({"kind": "trunk", "name": box.name, "shape": "circle", "c": s[0], "r": maxf(rr.x, rr.y), "node": n})
			box.kind = "crown"
			box.low = 1.6
		out.append(box)
	for t: MapTree in tree.get_nodes_in_group("trees"):
		out.append({"kind": "trunk", "name": "tree %s" % t.kind, "shape": "circle", "c": t.global_position, "r": t.trunk_radius,
			"node": t})
		var low := 2.6
		out.append({"kind": "crown", "name": "tree %s crown" % t.kind, "shape": "circle", "c": t.global_position, "r": t.canopy(),
			"low": low * t.tree_scale, "node": t})
	for f: Fence in tree.get_nodes_in_group("fences"):
		var e: Array = f.ends()
		var along := ((e[1] as Vector2) - (e[0] as Vector2)).normalized()
		out.append({"kind": "fence", "name": "%s fence" % f.style, "shape": "box", "c": f.global_position, "ax": along,
			"ay": along.orthogonal(), "h": Vector2(f.half, Fence.thick_of(f.style) * 0.5), "top": 1.2, "node": f})
	for w: Dock in tree.get_nodes_in_group("walkways"):
		if w._is_boat or w.bridge != "":
			continue
		var r: Rect2 = w.walk_rect
		if r.size == Vector2.ZERO:
			continue
		out.append({"kind": "dock", "name": "dock" if w.descend == "" else "stairs", "shape": "box", "c": r.get_center(),
			"ax": Vector2.RIGHT, "ay": Vector2.DOWN, "h": r.size * 0.5, "top": 1.0, "node": w})
	# (the rest that's solid: rocks, stones, the altar, the rune stones - their own circles)
	for n in tree.get_nodes_in_group("solids"):
		if n is MapTree or n is Ruin or n is StreetProp or n is Fence or not n.has_method("solids"):
			continue
		for s in n.solids():
			var rr: Vector2 = s[1]
			out.append({"kind": "stone", "name": str(n.name), "shape": "circle", "c": s[0], "r": maxf(rr.x, rr.y), "node": n})
	return out


## A 3D thing's outline on the ground: its meshes' box in its own frame, as it stands (px).
static func outline(node: Node3D) -> Dictionary:
	var inv := node.global_transform.affine_inverse()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var any := false
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if str(m.name) == "LanternGlow":
			continue
		var bb := m.get_aabb()
		var to := inv * m.global_transform
		for i in 8:
			var p: Vector3 = to * bb.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
		any = true
	if not any:
		return {}
	var g := node.global_transform
	var mid: Vector3 = g * ((lo + hi) * 0.5)
	var bx := g.basis.x
	var bz := g.basis.z
	var ax := Vector2(bx.x, bx.z)
	var ay := Vector2(bz.x, bz.z)
	var half := Vector2((hi.x - lo.x) * 0.5 * ax.length(), (hi.z - lo.z) * 0.5 * ay.length()) * RunView3D.PX
	var top: float = (g * hi).y - node.global_position.y
	return {"shape": "box", "c": Vector2(mid.x, mid.z) * RunView3D.PX, "ax": ax.normalized(), "ay": ay.normalized(), "h": half,
		"top": top, "node": node}


## (the street prop a FarmProp/StreetPropModel node draws)
static func prop_of(tree: SceneTree, node: Node3D) -> StreetProp:
	var nm := str(node.name)
	if not (nm.begins_with("FarmProp") or nm.begins_with("StreetPropModel")):
		return null
	var k := int(nm.trim_prefix("FarmProp").trim_prefix("StreetPropModel"))
	var props := tree.get_nodes_in_group("street_props")
	return props[k] as StreetProp if k < props.size() else null


## (yard things that grow: leafy over their stems)
const LEAFY := ["bamboo", "fruit"]


static func label(tree: SceneTree, node: Node3D, kind: String) -> String:
	if kind == "building":
		var k := int(str(node.name).trim_prefix("RuinModel"))
		var ruins := tree.get_nodes_in_group("ruins")
		if k < ruins.size():
			var r := ruins[k] as Ruin
			return "building %s" % (r.model if r.model != "" else r.kind)
	if kind == "thing":
		var k := int(str(node.name).trim_prefix("FarmProp").trim_prefix("StreetPropModel"))
		var props := tree.get_nodes_in_group("street_props")
		if k < props.size():
			var sp := props[k] as StreetProp
			return "%s %s" % [sp.kind, sp.model]
	return kind


# ------------------------------------------------------------------ overlaps

## How far `a` is into `b` (px; <= 0 apart).
static func pen(a: Dictionary, b: Dictionary) -> float:
	if a.shape == "circle" and b.shape == "circle":
		return float(a.r) + float(b.r) - (a.c as Vector2).distance_to(b.c)
	if a.shape == "box" and b.shape == "box":
		return _box_box(a, b)
	var box := a if a.shape == "box" else b
	var cir := b if a.shape == "box" else a
	return _box_circle(box, cir.c, float(cir.r))


static func _box_box(a: Dictionary, b: Dictionary) -> float:
	var least := INF
	for axis: Vector2 in [a.ax, a.ay, b.ax, b.ay]:
		var ra := absf((a.h as Vector2).x * (a.ax as Vector2).dot(axis)) + absf((a.h as Vector2).y * (a.ay as Vector2).dot(axis))
		var rb := absf((b.h as Vector2).x * (b.ax as Vector2).dot(axis)) + absf((b.h as Vector2).y * (b.ay as Vector2).dot(axis))
		var d := absf(((b.c as Vector2) - (a.c as Vector2)).dot(axis))
		least = minf(least, ra + rb - d)
		if least <= 0.0:
			return least
	return least


static func _box_circle(box: Dictionary, c: Vector2, r: float) -> float:
	var d := c - (box.c as Vector2)
	var lx := d.dot(box.ax)
	var ly := d.dot(box.ay)
	var h: Vector2 = box.h
	if absf(lx) <= h.x and absf(ly) <= h.y:
		return r + minf(h.x - absf(lx), h.y - absf(ly))
	var q := Vector2(clampf(lx, -h.x, h.x), clampf(ly, -h.y, h.y))
	return r - Vector2(lx, ly).distance_to(q)


## Which pairs of kinds count (a crown only over a building: _crowns).
const PAIRS := {
	"building": ["building", "thing", "trunk", "fence", "stone", "bridge", "dock"],
	"thing": ["thing", "trunk", "fence", "stone", "bridge", "dock"],
	"trunk": ["trunk", "fence", "stone", "bridge", "dock"],
	"fence": ["stone", "bridge", "dock"],
	"stone": ["stone", "bridge", "dock"],
	"bridge": ["dock", "bridge"],
}


static func near_camp(t: Dictionary, camp: Vector2) -> bool:
	return (t.c as Vector2).distance_to(camp) < CAMP_CLEAR


## Any two things in each other by more than SLACK px: [[px, what, where], ...].
static func each_other(things: Array, camp: Vector2) -> Array:
	var out := []
	for i in things.size():
		var a: Dictionary = things[i]
		if a.kind == "crown":
			continue
		for j in range(i + 1, things.size()):
			var b: Dictionary = things[j]
			if b.kind == "crown" or a.node == b.node:
				continue
			var ok: bool = PAIRS.get(a.kind, []).has(b.kind) or PAIRS.get(b.kind, []).has(a.kind)
			if not ok or (near_camp(a, camp) and near_camp(b, camp)):
				continue
			# (a quick skip: far apart)
			if (a.c as Vector2).distance_to(b.c) > reach(a) + reach(b):
				continue
			var p := pen(a, b)
			if p > SLACK:
				out.append([p, "%s in %s by %.0f px (%.2f m) at %s" % [a.name, b.name, p, p / RunView3D.PX, at(a, b)], (a.c + b.c) * 0.5])
	return out


## A tree's crown in a building taller than its lowest leaves by more than CROWN_SLACK px.
static func crowns(things: Array) -> Array:
	var out := []
	for a: Dictionary in things:
		if a.kind != "crown":
			continue
		for b: Dictionary in things:
			if b.kind != "building" or float(b.get("top", 0.0)) < float(a.low):
				continue
			if (a.c as Vector2).distance_to(b.c) > reach(a) + reach(b):
				continue
			var p := pen(a, b)
			if p > CROWN_SLACK:
				out.append([p, "%s in %s by %.0f px (%.2f m) at %s" % [a.name, b.name, p, p / RunView3D.PX, at(a, b)], (a.c + b.c) * 0.5])
	return out


## A thing standing in the water further than WET px.
static func in_water(tree: SceneTree, things: Array) -> Array:
	var out := []
	var zones := tree.get_nodes_in_group("water_zones")
	for a: Dictionary in things:
		if a.kind in ["crown", "bridge", "dock", "fence"]:
			continue
		# (the sea cliff's rocks stand in the sea on purpose)
		if str(a.name).begins_with("CoastRock"):
			continue
		var deepest := -INF
		# (a rock may lie at the water's edge, its foot in the shallows - in it only if its middle is)
		for p in ([a.c] if a.kind == "stone" else points(a)):
			for z in zones:
				deepest = maxf(deepest, z.depth(p))
		if deepest > WET:
			out.append([deepest, "%s in the water by %.0f px at %s" % [a.name, deepest, str(Vector2i(a.c))], a.c])
	return out


## A thing's outline's points (a box's corners and middle; a circle's middle and four edge points).
static func points(a: Dictionary) -> Array:
	var c: Vector2 = a.c
	if a.shape == "circle":
		var r := float(a.r)
		return [c, c + Vector2(r, 0), c - Vector2(r, 0), c + Vector2(0, r), c - Vector2(0, r)]
	var h: Vector2 = a.h
	var x: Vector2 = a.ax * h.x
	var y: Vector2 = a.ay * h.y
	return [c, c + x + y, c + x - y, c - x + y, c - x - y]


static func reach(a: Dictionary) -> float:
	return float(a.r) if a.shape == "circle" else (a.h as Vector2).length()


static func at(a: Dictionary, b: Dictionary) -> String:
	return str(Vector2i(((a.c as Vector2) + (b.c as Vector2)) * 0.5))


# ------------------------------------------------------------------ the animals

## A fresh record for following the animals (animal_step each physics frame).
static func animal_watch(things: Array) -> Dictionary:
	return {"solid": things.filter(func(t): return t.kind in ["building", "thing", "trunk", "fence", "stone"]),
		"inside": {}, "water": {}, "stuck": {}, "watch": {}, "seen": {}}


## One step of following every animal on `main` (`dt` s of the game gone by): its body (BODY_SHARE of
## its own radius) in something solid by more than SLACK px, in the water, or meaning to go somewhere
## and hardly moving for STUCK_FOR s.
static func animal_step(tree: SceneTree, main: Node, w: Dictionary, dt: float) -> void:
	var zones := tree.get_nodes_in_group("water_zones")
	for n in main.get_children():
		if not n is Critter:
			continue
		var c := n as Critter
		if not c.active or c.fade > 0.5:
			continue
		var key := c.get_instance_id()
		w.seen[key] = c.species
		var here := c.global_position
		var body := float(c._data.get("body", 6.0)) * BODY_SHARE
		var me := {"shape": "circle", "c": here, "r": body}
		for s: Dictionary in w.solid:
			if (s.c as Vector2).distance_to(here) > reach(s) + body:
				continue
			var p := pen(me, s)
			if p > SLACK:
				var k := "%d|%s" % [key, s.name]
				if not w.inside.has(k) or float(w.inside[k][0]) < p:
					w.inside[k] = [p, "%s in %s by %.0f px at %s" % [c.species, s.name, p, str(Vector2i(here))], here]
		for z in zones:
			if z.depth(here) > WET:
				w.water[key] = [z.depth(here), "%s in the water at %s" % [c.species, str(Vector2i(here))], here]
		var f: Dictionary = w.watch.get(key, {"from": here, "t": 0.0, "worst": 0.0})
		var going: bool = c._mode != Critter.Mode.IDLE and c._target.distance_to(here) > 30.0 and c._speed() > 0.0
		if not going:
			f = {"from": here, "t": 0.0, "worst": f.worst}
		else:
			f.t = float(f.t) + dt
			if here.distance_to(f.from) > STUCK_MOVE * maxf(1.0, float(f.t) / STUCK_FOR):
				f = {"from": here, "t": 0.0, "worst": f.worst}
			elif float(f.t) > STUCK_FOR:
				f.worst = maxf(float(f.worst), float(f.t))
				w.stuck[key] = [f.worst, "%s stuck %.1f s at %s (going to %s)" % [c.species, f.worst, str(Vector2i(here)), str(Vector2i(c._target))], here]
		w.watch[key] = f
