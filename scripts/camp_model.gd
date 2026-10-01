class_name CampModel
extends RefCounted

## The camp's models (tools/build_camp_models.py: the user's packs made
## light - one mesh, its colours baked into <name>_albedo.png, sometimes a
## normal and a glow picture beside it), dressed here. Metres, standing on
## y = 0, front toward +z.
##   CampModel.make("crate")      a MeshInstance3D in its own material
## Trees keep two surfaces, bark and leaves, each with its family's picture
## (the leaves cut out by their alpha).

const DIR := "res://assets/models/camp/"
const TREE_FAMILY := {"pine": "pine", "dead": "dead_tree", "twisted": "twisted_tree"}

static var _meshes := {}
static var _materials := {}


static func mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		var m: Mesh = null
		var path := DIR + name + ".glb"
		if ResourceLoader.exists(path):
			var inst: Node = (load(path) as PackedScene).instantiate()
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				m = (mi as MeshInstance3D).mesh
				break
			inst.free()
		_meshes[name] = m
	return _meshes[name]


static func _tex(file: String) -> Texture2D:
	var path := DIR + file
	return load(path) if ResourceLoader.exists(path) else null


## The material of a baked model: its colours, its surface detail and what
## glows (`glow` how strongly), if it has those pictures.
static func material(name: String, glow := 1.0) -> StandardMaterial3D:
	var key := "%s@%s" % [name, glow]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex(name + "_albedo.png")
		m.roughness = 0.9
		var n := _tex(name + "_normal.png")
		if n != null:
			m.normal_enabled = true
			m.normal_texture = n
		var g := _tex(name + "_glow.png")
		if g != null and glow > 0.0:
			m.emission_enabled = true
			m.emission_texture = g
			m.emission_energy_multiplier = glow
		_materials[key] = m
	return _materials[key]


static func _tree_material(family: String, part: String) -> StandardMaterial3D:
	var key := family + "/" + part
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("%s_%s.png" % [family, part])
		m.roughness = 0.95
		if part == "leaves":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.45
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = m
	return _materials[key]


## A model as a MeshInstance3D (null if there's no such model).
static func make(name: String, glow := 1.0) -> MeshInstance3D:
	var m := mesh(name)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var family := ""
	for prefix in TREE_FAMILY:
		if name.begins_with(prefix + "_"):
			family = TREE_FAMILY[prefix]
	if family != "":
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			var part := "leaves" if mat != null and mat.resource_name.begins_with("leaves") else "bark"
			mi.set_surface_override_material(s, _tree_material(family, part))
	else:
		mi.material_override = material(name, glow)
	return mi


## A tree's mesh with its two pictures set on its surfaces (for a MultiMesh).
static func tree_mesh(name: String) -> Mesh:
	var key := name + "#dressed"
	if not _meshes.has(key):
		var src := mesh(name)
		if src == null:
			return null
		var m: Mesh = src.duplicate()
		var family := ""
		for prefix in TREE_FAMILY:
			if name.begins_with(prefix + "_"):
				family = TREE_FAMILY[prefix]
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			var part := "leaves" if mat != null and mat.resource_name.begins_with("leaves") else "bark"
			m.surface_set_material(s, _tree_material(family, part))
		_meshes[key] = m
	return _meshes[key]
