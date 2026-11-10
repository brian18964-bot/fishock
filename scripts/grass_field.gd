class_name GrassField
extends Node3D

## User request (stage three of the wind): real grass about the traveller - bending in the wind
## and pushed aside by whoever walks through it, springing back slowly behind (shaders/grass.gdshader).
## Grown where the ground is grass (its paint: not under the trees, not on the mud of the shore, the
## paths or the walkways, not in the water), in square chunks round the traveller (CHUNK m, RANGE
## chunks each way) - a chunk made when it comes in range, one a frame, and let go when it's left
## well behind. Each chunk's clumps are the same each time (seeded by where it is). Fewer and
## nearer on a phone.

const CHUNK := 4.0
const RANGE := 3
const RANGE_LOW := 2
## Clumps a square metre where the ground is all grass (the style's own share - Profile).
const DENSITY := 9.0
## A clump's blades, their height (m) and width at the root (m).
const BLADES := 5
const HEIGHT := Vector2(0.28, 0.5)
const WIDTH := 0.045

## Where the grass grows: (x, z) -> Vector2(its share there 0..1, the ground's height).
var grows: Callable
var density := DENSITY
var range_chunks := RANGE
var material: ShaderMaterial
var _mesh: ArrayMesh
var _chunks := {}
## Each made chunk's clumps' roots (m) - where the grass is (the tests; the drawing's own copy is
## the GPU's).
var roots := {}
var _queue: Array = []
var _centre := Vector2i(1 << 20, 0)
## How many chunks are made (for the tests), and how many clumps in them.
var made := 0
var clumps := 0


func setup(base: Color, tip: Color, fade: Vector2) -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/grass.gdshader")
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("tip_color", tip)
	material.set_shader_parameter("fade_near", fade.x)
	material.set_shader_parameter("fade_far", fade.y)
	_mesh = _clump()


## One clump: BLADES tapered blades about its root, each three segments high, leaning out a little.
func _clump() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in BLADES:
		var a := TAU * float(b) / BLADES + rng.randf_range(-0.4, 0.4)
		var root := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.08)
		var lean := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.08, 0.3)
		var face := Vector3(-sin(a + 0.6), 0.0, cos(a + 0.6))
		var tall := rng.randf_range(0.7, 1.0)
		var shade := Color.WHITE * rng.randf_range(0.8, 1.1)
		var rows := []
		for k in 4:
			var t := float(k) / 3.0
			var c := root + lean * t * t + Vector3(0.0, t * tall, 0.0)
			var w := WIDTH * (1.0 - t) * 0.5 / maxf(HEIGHT.y, 0.01)
			rows.append([c - face * w, c + face * w, t])
		for k in 3:
			var r0: Array = rows[k]
			var r1: Array = rows[k + 1]
			for v in [[r0[0], r0[2]], [r0[1], r0[2]], [r1[0], r1[2]], [r0[1], r0[2]], [r1[1], r1[2]], [r1[0], r1[2]]]:
				st.set_color(shade)
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0.0, v[1]))
				st.add_vertex(v[0])
	return st.commit()


## The traveller is at `at` now: chunks coming in range queued (nearest first), those left well
## behind let go; and one queued made.
func follow(at: Vector3) -> void:
	var c := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
	if c != _centre:
		_centre = c
		for key in _chunks.keys():
			if absi(key.x - c.x) > range_chunks + 1 or absi(key.y - c.y) > range_chunks + 1:
				var node = _chunks[key]
				if node != null and is_instance_valid(node):
					(node as Node).queue_free()
				_chunks.erase(key)
				roots.erase(key)
		_queue.clear()
		for j in range(-range_chunks, range_chunks + 1):
			for i in range(-range_chunks, range_chunks + 1):
				var key := c + Vector2i(i, j)
				if not _chunks.has(key):
					_queue.append(key)
		_queue.sort_custom(func(p, q): return (p - c).length_squared() < (q - c).length_squared())
	if not _queue.is_empty():
		_make(_queue.pop_front())


## Every chunk in range made now (the start, the tests).
func fill(at: Vector3) -> void:
	follow(at)
	while not _queue.is_empty():
		_make(_queue.pop_front())


func _make(key: Vector2i) -> void:
	if _chunks.has(key):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var xfs := []
	var tries := int(roundf(CHUNK * CHUNK * density))
	for _i in tries:
		var x := (key.x + rng.randf()) * CHUNK
		var z := (key.y + rng.randf()) * CHUNK
		var spin := rng.randf() * TAU
		var tall := rng.randf_range(HEIGHT.x, HEIGHT.y)
		var keep := rng.randf()
		var here: Vector2 = grows.call(x, z)
		if keep >= here.x:
			continue
		var wide := tall * rng.randf_range(0.8, 1.2)
		xfs.append(Transform3D(Basis(Vector3.UP, spin).scaled(Vector3(wide, tall, wide)), Vector3(x, here.y - 0.01, z)))
	made += 1
	if xfs.is_empty():
		_chunks[key] = null
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = xfs.size()
	var at := PackedVector3Array()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		at.append((xfs[i] as Transform3D).origin)
	roots[key] = at
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = (range_chunks + 1) * CHUNK
	add_child(mmi)
	_chunks[key] = mmi
	clumps += xfs.size()


## Who pushes the grass now: up to 12 of [position (3D), reach (m)].
func push(movers: Array) -> void:
	var arr := PackedVector4Array()
	arr.resize(12)
	for i in mini(movers.size(), 12):
		var m: Array = movers[i]
		var p: Vector3 = m[0]
		arr[i] = Vector4(p.x, p.y, p.z, float(m[1]))
	material.set_shader_parameter("movers", arr)
