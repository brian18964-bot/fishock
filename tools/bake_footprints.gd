extends SceneTree

## Bakes each character's footprint from its own model (user request: the prints in the snow in the
## shape of the feet as they were made, not drawn): the part of each foot that meets the ground -
## the triangles of the mesh skinned to that foot's bones (foot, ball, ball_leaf) lying in a thin
## slab over the sole's lowest point, in the rest pose - laid flat in the foot's own frame and
## drawn into a cell of an atlas, deeper (darker) where it's lower.
##
##   godot --headless --path . -s tools/bake_footprints.gd
##
## Writes assets/sprites/footprints/soles.png (a row per character, the left foot then the right)
## and soles.json: for each character its row and, per side, the cell's box in the foot's frame
## (forward f / side s, in foot lengths - the ankle's to the toe tip's distance, at the ground -
## from the ankle) and the ankle's and toe tip's heights over the sole (also in foot lengths). The
## game (SnowTracks) lays a cell at the ankle, along the foot, sized by the foot's length there.

const IDS := ["cat", "dog", "dog3", "bear", "bear2", "deer", "deer2", "sheep", "sheep2", "owl", "owl2", "croc"]
const CELL := 64
## The slab over the sole's lowest point that counts as touching (foot lengths).
const SLAB := 0.14
## Room round the sole in the cell (foot lengths).
const MARGIN := 0.06
const OUT := "res://assets/sprites/footprints/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var atlas := Image.create(CELL * 2, CELL * IDS.size(), false, Image.FORMAT_L8)
	atlas.fill(Color.BLACK)
	var meta := {}
	for row in IDS.size():
		var id: String = IDS[row]
		var root: Node = (load("res://assets/models/characters/%s.glb" % id) as PackedScene).instantiate()
		var entry := {"row": row}
		var col := 0
		for side in ["_l", "_r"]:
			var got := _bake_side(root, side)
			if got.is_empty():
				push_error("%s%s: no sole found" % [id, side])
				col += 1
				continue
			atlas.blit_rect(got.image, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
			entry[side.substr(1)] = got.box
			entry["foot_h"] = got.foot_h
			entry["leaf_h"] = got.leaf_h
			col += 1
		meta[id] = entry
		print("%s: %s" % [id, entry])
		root.free()
	atlas.save_png(ProjectSettings.globalize_path(OUT + "soles.png"))
	var f := FileAccess.open(OUT + "soles.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	quit()


## One foot of the character in `root`: {image, box [f0, f1, s0, s1], foot_h, leaf_h}.
func _bake_side(root: Node, side: String) -> Dictionary:
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var foot_b := skel.find_bone("foot" + side)
	var leaf_b := skel.find_bone("ball_leaf" + side)
	var mine := [foot_b, skel.find_bone("ball" + side), leaf_b]
	var ankle := skel.get_bone_global_rest(foot_b).origin
	var toe := skel.get_bone_global_rest(leaf_b).origin
	var fwd := Vector2(toe.x - ankle.x, toe.z - ankle.z)
	var length := fwd.length()
	fwd = fwd / length
	# (the foot's side: to its right, looking along it from above)
	var right := Vector2(-fwd.y, fwd.x)
	# Every triangle of the mesh mostly skinned to this foot, posed at rest.
	var tris: Array = []
	var lowest := INF
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var skin := mi.skin
		# (a bind's bone, by its name - the skin may leave the index unset)
		var bind_bone := PackedInt32Array()
		var bind_xf: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = skel.find_bone(skin.get_bind_name(b))
			bind_bone.append(bone)
			bind_xf.append(skel.get_bone_global_rest(maxi(bone, 0)) * skin.get_bind_pose(b))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if bones.is_empty() or verts.is_empty():
				continue
			var per := bones.size() / verts.size()
			var posed := PackedVector3Array()
			posed.resize(verts.size())
			var ours := PackedByteArray()
			ours.resize(verts.size())
			for v in verts.size():
				var p := Vector3.ZERO
				var w_mine := 0.0
				var w_all := 0.0
				for k in per:
					var w := weights[v * per + k]
					if w <= 0.0:
						continue
					var b := bones[v * per + k]
					p += (bind_xf[b] * verts[v]) * w
					w_all += w
					if bind_bone[b] in mine:
						w_mine += w
				posed[v] = p / maxf(w_all, 0.0001)
				ours[v] = 1 if w_mine > 0.5 * w_all else 0
			if idx.is_empty():
				idx = PackedInt32Array(range(verts.size()))
			for t in range(0, idx.size(), 3):
				var a := idx[t]
				var b2 := idx[t + 1]
				var c := idx[t + 2]
				if ours[a] + ours[b2] + ours[c] < 3:
					continue
				tris.append([posed[a], posed[b2], posed[c]])
				lowest = minf(lowest, minf(posed[a].y, minf(posed[b2].y, posed[c].y)))
	if tris.is_empty():
		return {}
	# The sole: what lies in the slab over the lowest point, flat in the foot's frame (foot lengths
	# from the ankle: f along, s across) with how deep (1 at the bottom of the slab).
	var slab := SLAB * length
	var flat: Array = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for tri in tris:
		var pts: Array = []
		var deep := 0.0
		var in_slab := true
		for p: Vector3 in tri:
			if p.y > lowest + slab:
				in_slab = false
				break
			var d := Vector2(p.x - ankle.x, p.z - ankle.z)
			var q := Vector2(d.dot(fwd), d.dot(right)) / length
			pts.append(q)
			deep += 1.0 - (p.y - lowest) / slab
		if not in_slab:
			continue
		flat.append([pts, deep / 3.0])
		for q: Vector2 in pts:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if flat.is_empty():
		return {}
	lo -= Vector2.ONE * MARGIN
	hi += Vector2.ONE * MARGIN
	# Drawn in a square cell (the box stretched to it; the game lays it back out to the box): the
	# toe at the cell's top (y 0), the foot's right at the cell's right.
	var img := Image.create(CELL, CELL, false, Image.FORMAT_L8)
	img.fill(Color.BLACK)
	var to_px := func(q: Vector2) -> Vector2:
		return Vector2((q.y - lo.y) / (hi.y - lo.y) * CELL, (hi.x - q.x) / (hi.x - lo.x) * CELL)
	for item in flat:
		var px: Array = []
		for q: Vector2 in item[0]:
			px.append(to_px.call(q))
		_fill(img, px[0], px[1], px[2], 0.45 + 0.55 * float(item[1]))
	_soften(img)
	return {"image": img, "box": [lo.x, hi.x, lo.y, hi.y],
		"foot_h": (ankle.y - lowest) / length, "leaf_h": (toe.y - lowest) / length}


## A triangle filled into `img` at value `v` (kept where something deeper's already drawn).
func _fill(img: Image, a: Vector2, b: Vector2, c: Vector2, v: float) -> void:
	var x0 := clampi(int(floor(minf(a.x, minf(b.x, c.x)))), 0, CELL - 1)
	var x1 := clampi(int(ceil(maxf(a.x, maxf(b.x, c.x)))), 0, CELL - 1)
	var y0 := clampi(int(floor(minf(a.y, minf(b.y, c.y)))), 0, CELL - 1)
	var y1 := clampi(int(ceil(maxf(a.y, maxf(b.y, c.y)))), 0, CELL - 1)
	var area := (b - a).cross(c - a)
	if absf(area) < 0.000001:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var w0 := (b - p).cross(c - p) / area
			var w1 := (c - p).cross(a - p) / area
			var w2 := 1.0 - w0 - w1
			# (a little past the edges: thin parts - a claw, a toe - still get their pixels)
			if w0 >= -0.08 and w1 >= -0.08 and w2 >= -0.08:
				if img.get_pixel(x, y).r < v:
					img.set_pixel(x, y, Color(v, v, v))


## A light blur, so the edges are soft in the snow.
func _soften(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in CELL:
		for x in CELL:
			var sum := 0.0
			var n := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx < 0 or yy < 0 or xx >= CELL or yy >= CELL:
						continue
					var w := 2.0 if dx == 0 and dy == 0 else 1.0
					sum += src.get_pixel(xx, yy).r * w
					n += w
			var v := sum / n
			img.set_pixel(x, y, Color(v, v, v))
