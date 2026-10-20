class_name SkinPoints
extends RefCounted
## A character's skinned mesh posed on the CPU - where its surface is now,
## for measuring bodies (tools/measure_bodies.gd) and clipping checks (the
## tests), not drawn. Each point's part is the bones it mostly follows.

enum Part { BODY, HAND_L, HAND_R, ARM_L, ARM_R }

var skeleton: Skeleton3D
var part := PackedInt32Array()
var _points := PackedVector3Array()
var _normals := PackedVector3Array()
var _bones := PackedInt32Array()      # 4 a point, into _binds
var _weights := PackedFloat32Array()
var _binds: Array[Transform3D] = []
var _bind_bone := PackedInt32Array()


## Every `step`th point of the first skinned mesh under `model`.
func _init(model: Node, step := 1) -> void:
	var mi: MeshInstance3D = null
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
			break
	if mi == null:
		return
	skeleton = mi.get_node(mi.skeleton) as Skeleton3D
	var skin := mi.skin
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = skeleton.find_bone(skin.get_bind_name(i))
		_bind_bone.append(b)
		_binds.append(skin.get_bind_pose(i))
	var kinds := PackedInt32Array()
	for i in _bind_bone.size():
		kinds.append(_kind(skeleton.get_bone_name(_bind_bone[i])))
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var we: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var no: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var per := bo.size() / maxi(v.size(), 1)
		for i in range(0, v.size(), step):
			_points.append(v[i])
			_normals.append(no[i] if i < no.size() else Vector3.UP)
			var share := [0.0, 0.0, 0.0, 0.0, 0.0]
			for k in 4:
				var bi := bo[i * per + k] if k < per else 0
				var w := we[i * per + k] if k < per else 0.0
				_bones.append(bi)
				_weights.append(w)
				share[kinds[bi]] += w
			var best := 0
			for p in 5:
				if share[p] > share[best]:
					best = p
			part.append(best)


static func _kind(bone: String) -> int:
	var hand := bone.begins_with("hand") or bone.begins_with("index") or bone.begins_with("middle") \
		or bone.begins_with("ring") or bone.begins_with("pinky") or bone.begins_with("thumb")
	var arm := bone.begins_with("upperarm") or bone.begins_with("lowerarm")
	if bone.ends_with("_l"):
		return Part.HAND_L if hand else (Part.ARM_L if arm else Part.BODY)
	if bone.ends_with("_r"):
		return Part.HAND_R if hand else (Part.ARM_R if arm else Part.BODY)
	return Part.BODY


func size() -> int:
	return _points.size()


## Where the points are now (world), as the skeleton's posed - those of
## `parts` (others left at zero).
func world(parts := [Part.BODY, Part.HAND_L, Part.HAND_R, Part.ARM_L, Part.ARM_R]) -> PackedVector3Array:
	var mats: Array[Transform3D] = []
	var g := skeleton.global_transform
	for i in _binds.size():
		mats.append(g * skeleton.get_bone_global_pose(_bind_bone[i]) * _binds[i])
	var out := PackedVector3Array()
	out.resize(_points.size())
	for i in _points.size():
		if not part[i] in parts:
			continue
		var p := Vector3.ZERO
		for k in 4:
			var w := _weights[i * 4 + k]
			if w > 0.0:
				p += (mats[_bones[i * 4 + k]] * _points[i]) * w
		out[i] = p
	return out


## Which way the surface faces at each point now (world) - those of `parts`.
func world_normals(parts := [Part.BODY, Part.HAND_L, Part.HAND_R, Part.ARM_L, Part.ARM_R]) -> PackedVector3Array:
	var mats: Array[Basis] = []
	var g := skeleton.global_transform
	for i in _binds.size():
		mats.append((g * skeleton.get_bone_global_pose(_bind_bone[i]) * _binds[i]).basis)
	var out := PackedVector3Array()
	out.resize(_normals.size())
	for i in _normals.size():
		if not part[i] in parts:
			continue
		var n := Vector3.ZERO
		for k in 4:
			var w := _weights[i * 4 + k]
			if w > 0.0:
				n += (mats[_bones[i * 4 + k]] * _normals[i]) * w
		out[i] = n.normalized()
	return out


## How deep the forearms and hands are in the body (m, the deepest), posed
## so (world(), world_normals()): a point's in if it's behind each of the
## body's nearest few points' surface. From the elbow on only - the inside
## of the upper arm against the chest isn't seen.
func forearms_into_body(w: PackedVector3Array, n: PackedVector3Array) -> float:
	var cell := 0.04
	var grid := {}
	for i in w.size():
		if part[i] == Part.BODY:
			var key := Vector3i((w[i] / cell).floor())
			if not grid.has(key):
				grid[key] = []
			grid[key].append(i)
	var g := func(b: String) -> Vector3:
		return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(b)).origin
	var worst := 0.0
	for i in w.size():
		if part[i] == Part.BODY:
			continue
		var p := w[i]
		var s := "_l" if part[i] in [Part.HAND_L, Part.ARM_L] else "_r"
		var shoulder: Vector3 = g.call("upperarm" + s)
		if p.distance_to(shoulder) < (g.call("lowerarm" + s) as Vector3).distance_to(shoulder) * 1.05:
			continue
		var c := Vector3i((p / cell).floor())
		var near := []
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var k := c + Vector3i(dx, dy, dz)
					if grid.has(k):
						near.append_array(grid[k])
		if near.size() < 3:
			continue
		near.sort_custom(func(a, b): return p.distance_squared_to(w[a]) < p.distance_squared_to(w[b]))
		var inside := true
		var d := INF
		for j in near.slice(0, 4):
			var into := n[j].dot(p - w[j])
			if into > -0.004:
				inside = false
				break
			d = minf(d, -into)
		if inside:
			worst = maxf(worst, d)
	return worst

