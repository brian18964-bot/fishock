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
				m = (mi as MeshInstance3D).mesh
				break
			inst.free()
		_meshes[id] = m
	return _meshes[id]


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
