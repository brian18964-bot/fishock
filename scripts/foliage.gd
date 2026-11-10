class_name Foliage
extends RefCounted

## User request: every map's trees and plants swaying in the wind, a chopped tree shaking. Their
## materials as shaders/foliage.gdshader (the model's own picture, cut out by its alpha, bent by
## the wind - the foot still, the top leaning), and the one wind they all bend to: project-wide
## shader globals (project.godot's foliage_wind, foliage_wind_dir), set here - the night's
## (RunView3D: stronger in a storm), the camp's.

const SHADER := preload("res://shaders/foliage.gdshader")
static var _two_sided: Shader

## How each sways: [the top's lean, a share of its height, in an ordinary wind; the parts out from
## the trunk's bob a metre out; the leaves' flutter (m)].
const TREE := [0.012, 0.006, 0.0]
const LEAVES := [0.012, 0.006, 0.03]
const PLANT := [0.09, 0.0, 0.012]
## The wind's strength: a night's, a storm's, the camp's.
const WIND := 1.0
const STORM_WIND := 2.6
const CAMP_WIND := 0.8
const WIND_DIR := Vector2(0.8, 0.6)


## `src` (a model's plain material) as a swaying one: `height` the model's own (m, unscaled),
## `how` one of TREE / LEAVES / PLANT. Cut-out or two-sided surfaces drawn from both sides.
static func material(src: StandardMaterial3D, height: float, how: Array) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if src.cull_mode == BaseMaterial3D.CULL_DISABLED or src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		if _two_sided == null:
			_two_sided = Shader.new()
			_two_sided.code = SHADER.code.replace("render_mode specular_schlick_ggx,", "render_mode specular_schlick_ggx, cull_disabled,")
		m.shader = _two_sided
	else:
		m.shader = SHADER
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("tint", src.albedo_color)
	m.set_shader_parameter("scissor", src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	m.set_shader_parameter("scissor_cut", src.alpha_scissor_threshold)
	m.set_shader_parameter("height", maxf(height, 0.05))
	m.set_shader_parameter("sway", how[0])
	m.set_shader_parameter("branch", how[1])
	m.set_shader_parameter("flutter", how[2])
	return m


## Whether `src` is a tree's leaves (cut out by their alpha) rather than its bark.
static func leafy(src: StandardMaterial3D) -> bool:
	return src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED


## A copy of `mesh` with every plain surface swaying: a tree's (bark TREE, leaves LEAVES) or, with
## `plant`, a small plant's (PLANT). Its height its own (the top of its bounds; feet at 0).
static func dress(mesh: Mesh, plant := false) -> Mesh:
	if mesh == null:
		return null
	var m: Mesh = mesh.duplicate()
	var tall := m.get_aabb().end.y
	for s in m.get_surface_count():
		var src := m.surface_get_material(s)
		if src is StandardMaterial3D:
			var how: Array = PLANT if plant else (LEAVES if leafy(src) else TREE)
			m.surface_set_material(s, material(src as StandardMaterial3D, tall, how))
	return m


## The wind everything sways in: its strength (WIND, STORM_WIND, CAMP_WIND...) and way (x, z).
static func set_wind(strength: float, dir := WIND_DIR) -> void:
	RenderingServer.global_shader_parameter_set("foliage_wind", strength)
	RenderingServer.global_shader_parameter_set("foliage_wind_dir", dir.normalized())
