class_name SkinPoints
extends RefCounted
## A character's skinned mesh posed on the CPU - where its surface is now,
## for measuring bodies (tools/measure_bodies.gd) and clipping checks (the
## tests), not drawn. Each point's part is the bones it mostly follows.

enum Part { BODY, HAND_L, HAND_R, ARM_L, ARM_R }

var skeleton: Skeleton3D
var part := PackedInt32Array()
var _points := PackedVector3Array()
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
		var per := bo.size() / maxi(v.size(), 1)
		for i in range(0, v.size(), step):
			_points.append(v[i])
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
