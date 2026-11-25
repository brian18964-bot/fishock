class_name CrocLook
extends RefCounted

## User request: Mr. Croc in an outfit of his own - not the travellers' (every character wears the
## same white knit and khaki), so nothing about him says he's one of them. His knit dyed SHIRT
## (the picture's white knit found by its colour - near-white, no hue - on his body below the
## head, so his teeth and eyes stay as they are; the knit's own stitches and shading kept), and a
## straw hat on his head. Only on the camp's Mr. Croc (CampCroc); his own picture is untouched.

## (the dye, sRGB; the hat's straw and its band - mine for now, the user can change them)
const SHIRT := Color(0.52, 0.16, 0.11)
const STRAW := Color(0.80, 0.66, 0.38)
const BAND := Color(0.30, 0.12, 0.08)
## (where the hat sits on the Head bone: up from it and back a little, tilted back)
const HAT_AT := Vector3(0.0, 0.215, 0.085)
const HAT_TILT := -0.16
## (the model's height (m) below which the knit is dyed - his collar's under it, his teeth over it)
const DYE_BELOW := 1.34

const DYE_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 rough_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform bool has_normal = false;
uniform bool has_rough = false;
uniform float normal_depth = 1.0;
uniform float roughness = 1.0;
uniform vec3 shirt : source_color = vec3(0.52, 0.16, 0.11);
uniform float below = 1.34;
varying float height;
void vertex() {
	height = VERTEX.y;
}
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = (hi - lo) / max(hi, 0.0001);
	// (the white knit: no hue to it, light - lit or in its folds - and on the body)
	float knit = (1.0 - smoothstep(0.07, 0.16, sat)) * smoothstep(0.12, 0.3, hi) * (1.0 - smoothstep(below - 0.03, below + 0.03, height));
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(c, shirt * clamp(lum / 0.7, 0.0, 1.3), knit);
	ROUGHNESS = has_rough ? dot(texture(rough_tex, UV), rough_channel) * roughness : roughness;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	RIM = 0.25;
	RIM_TINT = 0.5;
}
"""
static var _dye_shader: Shader


## Dresses the camp's Mr. Croc (a CharacterRig of the croc): the knit dyed, the hat on.
static func dress(rig: CharacterRig) -> void:
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null and src.resource_name.ends_with("Skin"):
				m.set_surface_override_material(i, dyed(src as BaseMaterial3D))
	rig.equip_node("head", hat(), Transform3D(Basis(Vector3.RIGHT, HAT_TILT), HAT_AT))


## His skin's material with the knit dyed SHIRT (its pictures, its roughness, its normals kept).
static func dyed(src: BaseMaterial3D) -> ShaderMaterial:
	if _dye_shader == null:
		_dye_shader = Shader.new()
		_dye_shader.code = DYE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _dye_shader
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("shirt", SHIRT)
	m.set_shader_parameter("below", DYE_BELOW)
	m.set_shader_parameter("roughness", src.roughness)
	if src.normal_enabled and src.normal_texture != null:
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("has_normal", true)
		m.set_shader_parameter("normal_depth", src.normal_scale)
	if src.roughness_texture != null:
		m.set_shader_parameter("rough_tex", src.roughness_texture)
		m.set_shader_parameter("has_rough", true)
		var ch := {BaseMaterial3D.TEXTURE_CHANNEL_RED: Vector4(1, 0, 0, 0), BaseMaterial3D.TEXTURE_CHANNEL_GREEN: Vector4(0, 1, 0, 0),
			BaseMaterial3D.TEXTURE_CHANNEL_BLUE: Vector4(0, 0, 1, 0), BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: Vector4(0, 0, 0, 1),
			BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE: Vector4(0.333, 0.333, 0.333, 0)}
		m.set_shader_parameter("rough_channel", ch.get(src.roughness_texture_channel, Vector4(0, 1, 0, 0)))
	return m


## A straw hat: a round crown with a dark band, a wide brim (a little longer front to back, over
## his long head).
static func hat() -> Node3D:
	var root := Node3D.new()
	root.name = "StrawHat"
	var straw := StandardMaterial3D.new()
	straw.albedo_color = STRAW
	straw.roughness = 0.92
	straw.rim_enabled = true
	straw.rim = 0.2
	var band := StandardMaterial3D.new()
	band.albedo_color = BAND
	band.roughness = 0.8
	var brim := MeshInstance3D.new()
	brim.name = "Brim"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.25
	bm.bottom_radius = 0.26
	bm.height = 0.014
	bm.radial_segments = 28
	brim.mesh = bm
	brim.material_override = straw
	brim.scale = Vector3(1.0, 1.0, 1.12)
	root.add_child(brim)
	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.105
	cm.bottom_radius = 0.135
	cm.height = 0.11
	cm.radial_segments = 24
	crown.mesh = cm
	crown.material_override = straw
	crown.position = Vector3(0, 0.062, 0)
	crown.scale = Vector3(1.0, 1.0, 1.1)
	root.add_child(crown)
	var ring := MeshInstance3D.new()
	ring.name = "Band"
	var rm := CylinderMesh.new()
	rm.top_radius = 0.128
	rm.bottom_radius = 0.137
	rm.height = 0.03
	rm.radial_segments = 24
	ring.mesh = rm
	ring.material_override = band
	ring.position = Vector3(0, 0.024, 0)
	ring.scale = Vector3(1.0, 1.0, 1.1)
	root.add_child(ring)
	for c in root.get_children():
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root
