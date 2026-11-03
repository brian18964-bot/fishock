class_name DragonSkin
extends RefCounted

## The dragon's skin (its mesh, rebuilt once when it's made - fit): its wing membrane given the air.
## (tools/build_dragon_sage.py: each wing on fifteen bones - the arm to the elbow, to the wrist, the
## hand, wing_<side>, _02, _03; three fingers out of the hand, four bones each at their knuckles,
## wing_<side>_f1, _f1_02 .. _f1_04 and so on. Its weights already keep the head, the arms and the
## robe off the wings, and the membrane shared between its two nearest spars.)
##
## User report (the second make): the wingbeat was stiff - no membrane filled by the air between
## the wing bones. The skin between them (the mesh's vertices weighted to the wing bones, away from
## the spars themselves) gets blend shapes - offsets made at rest, so its bones carry them along:
## `bulge`, the membrane pushed out across the wing, the most midway between two spars and nothing
## along them; `ripple_s` / `ripple_c`, a ripple out from the hand in two shapes a quarter-wave
## apart, so weighted in turn (DragonRig) it runs out along the wing. Both pushed the same way across
## the wing (`across`: at rest its back - the open wing faces back - the right wing's mirrored), so
## the membrane's two faces move together and it bends, not swells.
const SIDES := ["l", "r"]
## (m: the bulge at the middle of a panel; the ripple's height, its length)
const BULGE := 0.16
const RIPPLE := 0.035
const RIPPLE_LEN := 0.4
## (m: from a spar, how far the membrane is still held by it - and where it's free)
const HELD := Vector2(0.015, 0.15)
const SHAPES := ["bulge", "ripple_s", "ripple_c"]
## Each wing's spars: the arm, then each finger, bone by bone (the bones' names after the side).
const SPARS := {
	"arm": ["", "_02", "_03"],
	"f1": ["_f1", "_f1_02", "_f1_03", "_f1_04"],
	"f2": ["_f2", "_f2_02", "_f2_03", "_f2_04"],
	"f3": ["_f3", "_f3_02", "_f3_03", "_f3_04"],
}
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
	var by_name := {}
	for b in skin.get_bind_count():
		by_name[skin.get_bind_name(b)] = b
	# Each side's spars at rest, in the mesh's space (its skin's binds): joint to joint, the last
	# bone of each a ray out along it.
	var lines := {}
	var bind_side := {}
	var wrist := {}
	for s in SIDES:
		var sl := {}
		for spar in SPARS:
			var pts: Array[Vector3] = []
			var last_axis := Vector3.ZERO
			for part in SPARS[spar]:
				var name: String = "wing_%s%s" % [s, part]
				if not by_name.has(name):
					return null
				var t := skin.get_bind_pose(by_name[name]).affine_inverse()
				pts.append(t.origin)
				last_axis = t.basis.y.normalized()
				bind_side[by_name[name]] = s
			sl[spar] = {"pts": pts, "axis": last_axis}
		lines[s] = sl
		wrist[s] = (sl.arm.pts as Array)[2]
		var f1: Vector3 = ((sl.f1.pts as Array)[1] - (sl.f1.pts as Array)[0]).normalized()
		var f3: Vector3 = ((sl.f3.pts as Array)[1] - (sl.f3.pts as Array)[0]).normalized()
		across[s] = (f1.cross(f3) if s == "l" else f3.cross(f1)).normalized()
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var n := verts.size()
	if n == 0 or bones.size() % n != 0:
		return null
	var per := bones.size() / n
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
		var d := 99.0
		for spar in lines[s]:
			var pts: Array = lines[s][spar].pts
			for i in pts.size() - 1:
				d = minf(d, _to_segment(p, pts[i], pts[i + 1]))
			d = minf(d, _to_ray(p, pts[pts.size() - 1], lines[s][spar].axis))
		var free := smoothstep(HELD.x, HELD.y, d) * smoothstep(0.3, 0.85, share)
		if free <= 0.0:
			continue
		moved += 1
		var push: Vector3 = across[s]
		var out := p.distance_to(wrist[s])
		var rip := free * smoothstep(0.12, 0.5, out) * RIPPLE
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


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _to_ray(p: Vector3, from: Vector3, dir: Vector3) -> float:
	return p.distance_to(from + dir * maxf((p - from).dot(dir), 0.0))
