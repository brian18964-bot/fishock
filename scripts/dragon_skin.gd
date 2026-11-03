class_name DragonSkin
extends RefCounted

## The dragon's skin (its mesh, rebuilt once when it's made - fit): its wing membrane given the air
## (below), its horns kept off its wings (_free_head), none of it on the skeleton's root
## (_off_root), and the model's stray second tail folded into its tail (_fold_fork).

## (And its horns kept still - see _free_head.)
## User report: the dragon's wingbeat was stiff - no membrane filled by the air between its wing
## bones. The skin between them (the mesh's vertices weighted to the wing bones, away from the
## bones themselves) gets blend shapes - offsets made at rest, so its bones carry them along:
## `bulge`, the membrane pushed out across the wing, the most midway between two bones and
## nothing along them; `ripple_s` / `ripple_c`, a ripple out from the wrist in two shapes a
## quarter-wave apart, so weighted in turn (DragonRig) it runs out along the wing. Both pushed the
## same way across the wing (`across`: at rest its back - the open wing faces back - the right
## wing's mirrored), so the membrane's two faces move together and it bends, not swells.
const SIDES := ["l", "r"]
## (m: the bulge at the middle of a panel; the ripple's height, its length)
const BULGE := 0.2
const RIPPLE := 0.04
const RIPPLE_LEN := 0.45
## (m: from a bone, how far the membrane is still held by it - and where it's free)
const HELD := Vector2(0.02, 0.18)
const SHAPES := ["bulge", "ripple_s", "ripple_c"]
## The wings' rest frame each side: {"across": the push, at rest} - DragonRig's sense of it.
static var across := {}
static var _made := {}


## Gives `mi` the membrane's shapes (the made mesh shared by every dragon). False if its mesh
## isn't one it can make them for.
static func fit(mi: MeshInstance3D) -> bool:
	var src := mi.mesh as ArrayMesh
	if src == null or mi.skin == null:
		return false
	if src.get_blend_shape_count() > 0:
		return src.has_meta("membrane")
	if not _made.has(src):
		_made[src] = _make(src, mi.skin)
	var made: ArrayMesh = _made[src]
	if made == null:
		return false
	mi.mesh = made
	return true


static func _make(src: ArrayMesh, skin: Skin) -> ArrayMesh:
	if src.get_surface_count() != 1:
		return null
	# The wing bones at rest, in the mesh's space (its skin's binds): each side's arm and forearm
	# (from one joint to the next) and fingers (out of the wrist).
	var by_name := {}
	for b in skin.get_bind_count():
		by_name[skin.get_bind_name(b)] = b
	var head := {}
	var axis := {}
	var bind_side := {}
	for s in SIDES:
		for part in ["", "_02", "_f1", "_f2", "_f3"]:
			var name: String = "wing_%s%s" % [s, part]
			if not by_name.has(name):
				return null
			var t := skin.get_bind_pose(by_name[name]).affine_inverse()
			head[name] = t.origin
			axis[name] = t.basis.y.normalized()
			bind_side[by_name[name]] = s
		var f1: Vector3 = axis["wing_%s_f1" % s]
		var f3: Vector3 = axis["wing_%s_f3" % s]
		across[s] = (f1.cross(f3) if s == "l" else f3.cross(f1)).normalized()
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var n := verts.size()
	if n == 0 or bones.size() % n != 0:
		return null
	var per := bones.size() / n
	weights = _free_head(verts, bones, weights, per, by_name, bind_side, skin)
	if by_name.has("root") and by_name.has("pelvis"):
		var moved_off: Array = _off_root(bones, weights, per, by_name["root"], by_name["pelvis"])
		bones = moved_off[0]
		weights = moved_off[1]
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_VERTEX] = verts
	_fold_fork(arrays, bones, weights, per, by_name, skin)
	verts = arrays[Mesh.ARRAY_VERTEX]
	# (relative shapes: each vertex's offset from the base, its normal's and tangent's - unchanged)
	var shapes: Array[PackedVector3Array] = []
	for _i in SHAPES.size():
		var none := PackedVector3Array()
		none.resize(n)
		shapes.append(none)
	var moved := 0
	for v in n:
		var on := {"l": 0.0, "r": 0.0}
		for k in per:
			var b: int = bones[v * per + k]
			if bind_side.has(b):
				on[bind_side[b]] += weights[v * per + k]
		var s: String = "l" if on.l >= on.r else "r"
		var share: float = on[s]
		if share < 0.3:
			continue
		var p := verts[v]
		var wrist: Vector3 = head["wing_%s_f1" % s]
		var d := minf(_to_segment(p, head["wing_%s" % s], head["wing_%s_02" % s]),
			_to_segment(p, head["wing_%s_02" % s], wrist))
		for f in ["_f1", "_f2", "_f3"]:
			d = minf(d, _to_ray(p, wrist, axis["wing_%s%s" % [s, f]]))
		var free := smoothstep(HELD.x, HELD.y, d) * smoothstep(0.3, 0.85, share)
		if free <= 0.0:
			continue
		moved += 1
		var push: Vector3 = across[s]
		var out := p.distance_to(wrist)
		var rip := free * smoothstep(0.15, 0.6, out) * RIPPLE
		shapes[0][v] = push * BULGE * free
		shapes[1][v] = push * rip * sin(TAU * out / RIPPLE_LEN)
		shapes[2][v] = push * rip * cos(TAU * out / RIPPLE_LEN)
	if moved == 0:
		return null
	var made := ArrayMesh.new()
	made.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	for name in SHAPES:
		made.add_blend_shape(name)
	var still_n := PackedVector3Array()
	still_n.resize(n)
	var still_t := PackedFloat32Array()
	still_t.resize(n * 4)
	var blend: Array = []
	for sh in shapes:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = sh
		a[Mesh.ARRAY_NORMAL] = still_n
		if arrays[Mesh.ARRAY_TANGENT] != null:
			a[Mesh.ARRAY_TANGENT] = still_t
		blend.append(a)
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend, {},
		src.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	made.surface_set_material(0, src.surface_get_material(0))
	made.surface_set_name(0, src.surface_get_name(0))
	made.set_meta("membrane", true)
	return made


## User report: its horns bent with its wings. The head's and the neck's skin had a little of the
## wing bones' weight (Blender's bone heat - the horns rise beside the wing's second joint), so
## every beat dragged at them. A vertex on the head or neck - some weight there, and more of it
## than the wings', or any at all from the head bone up - loses the wings' share, the rest scaled
## back up to the whole.
static func _free_head(verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array,
		per: int, by_name: Dictionary, bind_side: Dictionary, skin: Skin) -> PackedFloat32Array:
	if not by_name.has("Head"):
		return weights
	var head_y := skin.get_bind_pose(by_name["Head"]).affine_inverse().origin.y
	var head := {}
	for name in ["Head", "neck_01"]:
		if by_name.has(name):
			head[by_name[name]] = true
	for v in verts.size():
		var on_head := 0.0
		var on_wing := 0.0
		for k in per:
			var b: int = bones[v * per + k]
			if head.has(b):
				on_head += weights[v * per + k]
			elif bind_side.has(b):
				on_wing += weights[v * per + k]
		if on_wing <= 0.0 or on_head < 0.05 or (on_head < on_wing and verts[v].y < head_y):
			continue
		var rest := maxf(1.0 - on_wing, 0.0001)
		for k in per:
			if bind_side.has(bones[v * per + k]):
				weights[v * per + k] = 0.0
			else:
				weights[v * per + k] /= rest
	return weights


## A strand of skin behind its hips, by the tail's root, had a little weight (~0.1) on the
## skeleton's root - the bone at its feet, which never moves with the body: whenever the hips moved
## (walking, flying), that share stayed behind and stretched the strand. The root's share goes to
## the hips (`pelvis`) - in place, or added to the hips' own share if the vertex has one.
## ([bones, weights], changed.)
static func _off_root(bones: PackedInt32Array, weights: PackedFloat32Array, per: int, root: int, pelvis: int) -> Array:
	for v in bones.size() / per:
		for k in per:
			var i := v * per + k
			if bones[i] != root:
				continue
			var hips := -1
			for j in per:
				if bones[v * per + j] == pelvis:
					hips = v * per + j
			if hips >= 0:
				weights[hips] += weights[i]
				weights[i] = 0.0
			else:
				bones[i] = pelvis
	return [bones, weights]


## User report: two tails (and after a first try, its root still showing). The model itself has a
## second tail. Cut across, the tail behind the hips is one ring down to ~0.78 m; below that a lobe
## swells out on its left (+x) and, under the crotch at ~0.645 m (FORK_CROTCH), is a tube of its own
## hanging straight down beside the left leg to ~0.15 m, while the real tail turns back. Its skin
## below the crotch is found by what joins to its tip (the lowest of the tail's skin out on its
## left), so none of the real tail's comes with it; all of it is drawn into one point inside the
## real tail's root, its faces gone to nothing. Above the crotch, up to FORK_TOP, the lobe's skin
## (nearer the stray tube's line than the real tail's) is pressed back onto the real tail's round -
## its own radius at that height, from its skin - the more the nearer the crotch.
const FORK_CROTCH := 0.645
const FORK_TOP := 0.78
## (in the real tail's root: this share of its radius out toward the stray tube)
const FORK_IN := 0.35
const FORK_SLICE := 0.03


static func _fold_fork(arrays: Array, bones: PackedInt32Array, weights: PackedFloat32Array,
		per: int, by_name: Dictionary, skin: Skin) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty():
		return
	var line: Array[Vector3] = []
	var tail_binds := {}
	for k in 7:
		var name := "tail_%02d" % (k + 1)
		if not by_name.has(name):
			return
		line.append(skin.get_bind_pose(by_name[name]).affine_inverse().origin)
		tail_binds[by_name[name]] = true
	var leg_binds := {}
	for name in ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]:
		if by_name.has(name):
			leg_binds[by_name[name]] = true
	# (the tail's skin, not the legs' or the robe's over them)
	var tailish := PackedByteArray()
	tailish.resize(verts.size())
	for v in verts.size():
		var on_tail := 0.0
		var on_leg := 0.0
		for k in per:
			if tail_binds.has(bones[v * per + k]):
				on_tail += weights[v * per + k]
			elif leg_binds.has(bones[v * per + k]):
				on_leg += weights[v * per + k]
		tailish[v] = 1 if on_tail >= 0.15 and on_leg <= 0.35 else 0
	# (one vertex where the mesh splits a place for its seams; who touches whom)
	var same := PackedInt32Array()
	same.resize(verts.size())
	var at := {}
	for v in verts.size():
		var key := Vector3i((verts[v] / 0.0002).round())
		same[v] = at.get(key, v)
		if not at.has(key):
			at[key] = v
	var touch := {}
	for t in index.size() / 3:
		for e in 3:
			var a := same[index[t * 3 + e]]
			var b := same[index[t * 3 + (e + 1) % 3]]
			# (plain Arrays: a packed one in a Dictionary is handed out as a copy)
			if not touch.has(a):
				touch[a] = []
			if not touch.has(b):
				touch[b] = []
			(touch[a] as Array).append(b)
			(touch[b] as Array).append(a)
	# (its tip; all the skin joined to it below the crotch)
	var tip := -1
	for v in verts.size():
		if tailish[v] == 1 and verts[v].x > 0.2 and (tip < 0 or verts[v].y < verts[tip].y):
			tip = v
	if tip < 0:
		return
	var stray := {same[tip]: true}
	var todo: Array[int] = [same[tip]]
	while not todo.is_empty():
		var u: int = todo.pop_back()
		for w in (touch.get(u, []) as Array):
			if not stray.has(w) and tailish[w] == 1 and verts[w].y < FORK_CROTCH:
				stray[w] = true
				todo.append(w)
	# (its line: the middle of it at each level - and at its top)
	var levels := {}
	var top := Vector3.ZERO
	var top_n := 0.0
	for v in verts.size():
		if not stray.has(same[v]):
			continue
		var level := int(floor(verts[v].y / FORK_SLICE))
		if not levels.has(level):
			levels[level] = [Vector3.ZERO, 0]
		levels[level][0] += verts[v]
		levels[level][1] += 1
		if verts[v].y > FORK_CROTCH - 0.06:
			top += verts[v]
			top_n += 1.0
	if top_n < 1.0:
		return
	top /= top_n
	# (the real tail at each level above the crotch: how far its skin lies from its line)
	var round_at := {}
	var lobe := PackedFloat32Array()
	lobe.resize(verts.size())
	for v in verts.size():
		var p := verts[v]
		if tailish[v] == 0 or stray.has(same[v]) or p.y < FORK_CROTCH or p.y > FORK_TOP:
			continue
		var c := _nearest(p, line)
		var to_stray := Vector2(p.x - top.x, p.z - top.z).length()
		if p.x > 0.0 and to_stray < p.distance_to(c):
			lobe[v] = 1.0
			continue
		var level := int(floor(p.y / FORK_SLICE))
		if not round_at.has(level):
			round_at[level] = []
		(round_at[level] as Array).append(p.distance_to(c))
	# The lobe pressed onto the real tail's round, the more the nearer the crotch.
	var dressed := PackedFloat32Array()
	dressed.resize(verts.size())
	for v in verts.size():
		if lobe[v] <= 0.0:
			continue
		var p := verts[v]
		var rs: Array = round_at.get(int(floor(p.y / FORK_SLICE)), [])
		if rs.is_empty():
			continue
		rs.sort()
		var r: float = rs[rs.size() / 2]
		var c := _nearest(p, line)
		var off := p - c
		if off.length() <= r:
			continue
		var press := 1.0 - smoothstep(FORK_CROTCH + 0.02, FORK_TOP, p.y)
		verts[v] = p.lerp(c + off.normalized() * r, press)
		dressed[v] = press
	# The tube below the crotch drawn into one point inside the real tail's root.
	var root := _nearest(top, line)
	var into := root + (top - root).normalized() * minf(top.distance_to(root), 0.15) * FORK_IN
	for v in verts.size():
		if stray.has(same[v]):
			verts[v] = into
			dressed[v] = 1.0
	arrays[Mesh.ARRAY_VERTEX] = verts
	_dress_fork(arrays, dressed, tail_binds, bones, weights, per)


## The nearest point of `line` (a polyline) to `p`.
static func _nearest(p: Vector3, line: Array[Vector3]) -> Vector3:
	var best := line[0]
	var d := INF
	for i in line.size() - 1:
		var ab := line[i + 1] - line[i]
		var c := line[i] + ab * clampf((p - line[i]).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		if p.distance_to(c) < d:
			d = p.distance_to(c)
			best = c
	return best


## The folded-in lobe's skin dressed as the real tail's around it (its pale underside showed where
## it's drawn in at its root): each of its vertices takes the texture place, the normal and the
## tangent of the nearest of the real tail's (found in FORK_CELL m cells).
const FORK_CELL := 0.06


static func _dress_fork(arrays: Array, fold: PackedFloat32Array, tail_binds: Dictionary,
		bones: PackedInt32Array, weights: PackedFloat32Array, per: int) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	if uv.is_empty():
		return
	# (the real tail's vertices, by cell)
	var cells := {}
	for v in verts.size():
		if fold[v] > 0.0:
			continue
		var on_tail := 0.0
		for k in per:
			if tail_binds.has(bones[v * per + k]):
				on_tail += weights[v * per + k]
		if on_tail < 0.5:
			continue
		var key := Vector3i((verts[v] / FORK_CELL).floor())
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(v)
	for v in verts.size():
		if fold[v] <= 0.05:
			continue
		var home := Vector3i((verts[v] / FORK_CELL).floor())
		var best := -1
		var best_d := INF
		for reach in [1, 2, 3]:
			for dx in range(-reach, reach + 1):
				for dy in range(-reach, reach + 1):
					for dz in range(-reach, reach + 1):
						var cell: Array = cells.get(home + Vector3i(dx, dy, dz), [])
						for u in cell:
							var d := verts[v].distance_squared_to(verts[u])
							if d < best_d:
								best_d = d
								best = u
			if best >= 0:
				break
		if best < 0:
			continue
		uv[v] = uv[best]
		normals[v] = normals[best]
		if tangents.size() >= verts.size() * 4:
			for k in 4:
				tangents[v * 4 + k] = tangents[best * 4 + k]
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not tangents.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = tangents


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _to_ray(p: Vector3, from: Vector3, dir: Vector3) -> float:
	return p.distance_to(from + dir * maxf((p - from).dot(dir), 0.0))
