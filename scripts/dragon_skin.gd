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
	verts = _fold_fork(verts, bones, weights, per, by_name, skin)
	arrays[Mesh.ARRAY_VERTEX] = verts
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


## User report: two tails. The model itself has a second, spiky strand forking down from under its
## tail's root, behind its left leg (seen from above or behind, a second tail). Its skin - on the
## tail's bones (not the legs' - the robe's there), on its left (x past FORK_SIDE), below
## FORK_TOP, ahead of FORK_BACK, and away from the tail's line (FORK: from this far, m, all of it
## by the next) - shrinks toward where it springs from (the middle of its eased edge) to FORK_LEFT
## of its size: a nub under the tail's root, its own skin kept whole (drawn onto the tail's line it
## showed as a sliced flap). (The tail's line: its bones' heads, on to its tip.)
const FORK := Vector2(0.17, 0.25)
const FORK_LEFT := 0.08
const FORK_SIDE := Vector2(0.1, 0.16)
const FORK_TOP := Vector2(0.66, 0.72)
const FORK_BACK := -0.55


static func _fold_fork(verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array,
		per: int, by_name: Dictionary, skin: Skin) -> PackedVector3Array:
	var line: Array[Vector3] = []
	var tail_binds := {}
	for k in 7:
		var name := "tail_%02d" % (k + 1)
		if not by_name.has(name):
			return verts
		line.append(skin.get_bind_pose(by_name[name]).affine_inverse().origin)
		tail_binds[by_name[name]] = true
	var last := skin.get_bind_pose(by_name["tail_07"]).affine_inverse()
	line.append(last.origin + last.basis.y.normalized() * 0.3)
	var leg_binds := {}
	for name in ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]:
		if by_name.has(name):
			leg_binds[by_name[name]] = true
	# (how much of each vertex is the fork; where its edge is)
	var fold := PackedFloat32Array()
	fold.resize(verts.size())
	var edge := Vector3.ZERO
	var edge_n := 0.0
	for v in verts.size():
		var p := verts[v]
		if p.z < FORK_BACK:
			continue
		var on_tail := 0.0
		var on_leg := 0.0
		for k in per:
			if tail_binds.has(bones[v * per + k]):
				on_tail += weights[v * per + k]
			elif leg_binds.has(bones[v * per + k]):
				on_leg += weights[v * per + k]
		# (the tail's, not the legs' or the robe's over them)
		if on_tail < 0.3 or on_leg > 0.35:
			continue
		var d := 99.0
		for i in line.size() - 1:
			d = minf(d, _to_segment(p, line[i], line[i + 1]))
		var f := smoothstep(FORK.x, FORK.y, d) * smoothstep(FORK_SIDE.x, FORK_SIDE.y, p.x) \
			* (1.0 - smoothstep(FORK_TOP.x, FORK_TOP.y, p.y))
		fold[v] = f
		if f > 0.02 and f < 0.35:
			edge += p
			edge_n += 1.0
	if edge_n < 1.0:
		return verts
	edge /= edge_n
	for v in verts.size():
		if fold[v] > 0.0:
			verts[v] = edge + (verts[v] - edge) * lerpf(1.0, FORK_LEFT, fold[v])
	return verts


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _to_ray(p: Vector3, from: Vector3, dir: Vector3) -> float:
	return p.distance_to(from + dir * maxf((p - from).dot(dir), 0.0))
