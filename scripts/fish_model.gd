class_name FishModel
extends RefCounted

## A species as a 3D fish, for the menus (user request: out of the game,
## everything in 3D that can be - the fish tank, the fish log, the camp's
## tank): the mesh tools/export_fish_models.py made of it, in its baked
## skin, swimming - a wave runs back along its body to the tail
## (shaders/fish_swim.gdshader). Head toward +x, back up, 1 long.

const MESHES := "res://assets/models/fish/%s.glb"
const SKINS := "res://assets/models/fish/%s.png"
const SWIM := preload("res://shaders/fish_swim.gdshader")

static var _meshes := {}


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(MESHES % id)


## The species' mesh, loaded once (null if it has none).
static func mesh(id: String) -> Mesh:
	if not _meshes.has(id):
		var m: Mesh = null
		if has_model(id):
			var inst: Node = (load(MESHES % id) as PackedScene).instantiate()
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				m = _marked_eyes((mi as MeshInstance3D).mesh)
				break
			inst.free()
		_meshes[id] = m
	return _meshes[id]


## `src` with its eyes marked (vertex colour red 1, the rest 0) for the dead's
## white ones. The model is one mesh, its parts' vertices split along the
## skin's seams, so they're welded by place first; the eyes are the two
## compact roundish clusters, one each side of the midline, near the head.
static func _marked_eyes(src: Mesh) -> Mesh:
	var arr := src.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var parent := PackedInt32Array()
	parent.resize(v.size())
	var weld := {}
	for i in v.size():
		parent[i] = i
		var key := Vector3i((v[i] * 2000.0).round())
		if weld.has(key):
			parent[i] = weld[key]
		else:
			weld[key] = i
	for t in range(0, ix.size(), 3):
		var r0 := _root(parent, ix[t])
		for j in [1, 2]:
			parent[_root(parent, ix[t + j])] = r0
	var comps := {}
	for i in v.size():
		var r := _root(parent, i)
		if not comps.has(r):
			comps[r] = []
		comps[r].append(i)
	var colors := PackedColorArray()
	colors.resize(v.size())
	colors.fill(Color(0, 0, 0, 1))
	for r in comps:
		var list: Array = comps[r]
		if list.size() < 60:
			continue
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for i in list:
			lo = lo.min(v[i])
			hi = hi.max(v[i])
		var d := hi - lo
		var big := maxf(d.x, maxf(d.y, d.z))
		var small := minf(d.x, minf(d.y, d.z))
		var c := (lo + hi) * 0.5
		if big < 0.08 and small > 0.012 and big / small < 1.4 and absf(c.z) > 0.01 and c.x > 0.15:
			for i in list:
				colors[i] = Color(1, 0, 0, 1)
	arr[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


static func _root(parent: PackedInt32Array, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


## Dresses `fish` (the model from make()) as the fish dict `f` is: dead - white
## eyes, dulled; rotten - the body gone purple or green (which, by the fish's
## own luck: its uid), the more the further gone. Nothing for a living one.
static func dress(fish: MeshInstance3D, f: Dictionary) -> void:
	var mat := fish.material_override as ShaderMaterial
	if mat == null:
		return
	var state := FishLife.state(f)
	mat.set_shader_parameter("dead", 0.0 if state == "alive" else 1.0)
	var rot := 1.0 if state == "rotten" else 0.0
	mat.set_shader_parameter("rot", rot)
	var green: bool = (int(f.get("uid", int(float(f.get("value", 0.0)) * 1000.0))) + str(f.get("name", "")).hash()) % 2 == 0
	mat.set_shader_parameter("rot_color", Color(0.4, 0.5, 0.16) if green else Color(0.38, 0.2, 0.45))


## A new fish of species `id` (null if it has no model). Swim it with
## swim(); it holds still until then.
static func make(id: String) -> MeshInstance3D:
	var m := mesh(id)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Fish_" + id
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SWIM
	mat.set_shader_parameter("skin", load(SKINS % id) if ResourceLoader.exists(SKINS % id) else null)
	mat.set_shader_parameter("beat", randf() * TAU)
	mi.material_override = mat
	mi.set_meta("beat", randf() * TAU)
	return mi


## Beats the fish's tail for `delta` seconds at `pace` (0 hanging still ..
## 1 flat out): faster and wider the harder it swims.
static func swim(fish: MeshInstance3D, delta: float, pace: float) -> void:
	var mat := fish.material_override as ShaderMaterial
	if mat == null:
		return
	pace = clampf(pace, 0.0, 1.5)
	var beat: float = fish.get_meta("beat", 0.0) + delta * lerpf(4.0, 13.0, pace)
	fish.set_meta("beat", fmod(beat, TAU * 64.0))
	mat.set_shader_parameter("beat", beat)
	mat.set_shader_parameter("sway", lerpf(0.035, 0.085, minf(pace, 1.0)))


## Lights the fish up (0..1) - the one picked in the tank.
static func glow(fish: MeshInstance3D, amount: float) -> void:
	var mat := fish.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("glow", amount)
