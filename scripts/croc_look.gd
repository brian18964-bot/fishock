class_name CrocLook
extends RefCounted

## User request: Mr. Croc in an outfit of his own - not the travellers' (every character wears the
## same white knit and khaki), so nothing about him says he's one of them. His knit dyed (the
## picture's white knit found by its colour - near-white, no hue - on his body below the head, so
## his teeth and eyes stay as they are; the knit's own stitches and shading kept), and a hat. Only on
## the camp's Mr. Croc (CampCroc); his own picture is untouched.
##
## User request: three hats, any of them or none as he turns up, his knit's colour going with the
## hat - each of OUTFITS a hat ("" bare-headed) and its knit's dye (sRGB), one picked each time he's by
## the water (pick). The hats our own (tools/make_croc_props.py, from the user's three: a trilby, a
## wide sun hat, a leather cowboy hat), each fitted to his head - its crown just over it, its brim
## wide - so all sit the same way on his Head bone (HAT_AT, HAT_TILT: the tool's SEAT and TILT).
## (all of these mine for now - the user can change any)
const OUTFITS := [
	{"hat": "trilby", "shirt": Color(0.52, 0.16, 0.11)},
	{"hat": "sun", "shirt": Color(0.44, 0.64, 0.52)},
	{"hat": "cowboy", "shirt": Color(0.66, 0.48, 0.14)},
	{"hat": "", "shirt": Color(0.17, 0.23, 0.40)},
]
const HATS := {
	"trilby": preload("res://assets/models/camp/croc_hat_trilby.glb"),
	"sun": preload("res://assets/models/camp/croc_hat_sun.glb"),
	"cowboy": preload("res://assets/models/camp/croc_hat_cowboy.glb"),
}
## (where a hat's brim sits on the Head bone: up from it and forward a little, tipped back)
const HAT_AT := Vector3(0.0, 0.195, 0.085)
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


## One of OUTFITS, each as likely.
static func pick() -> Dictionary:
	return OUTFITS[randi() % OUTFITS.size()]


## Dresses the camp's Mr. Croc (a CharacterRig of the croc) in `outfit` (one of OUTFITS): the knit
## dyed, the hat on (or none).
static func dress(rig: CharacterRig, outfit: Dictionary) -> void:
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null and src.resource_name.ends_with("Skin"):
				m.set_surface_override_material(i, dyed(src as BaseMaterial3D, outfit.shirt))
	if outfit.hat != "":
		rig.equip_node("head", hat(outfit.hat), Transform3D(Basis(Vector3.RIGHT, HAT_TILT), HAT_AT))
	else:
		rig.equip("head", null)


## His skin's material with the knit dyed `shirt` (its pictures, its roughness, its normals kept).
static func dyed(src: BaseMaterial3D, shirt: Color) -> ShaderMaterial:
	if _dye_shader == null:
		_dye_shader = Shader.new()
		_dye_shader.code = DYE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _dye_shader
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("shirt", shirt)
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


## One of his hats (HATS) - standing on its brim at the origin, its crown's opening there.
static func hat(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Hat_" + kind
	var model: Node3D = (HATS[kind] as PackedScene).instantiate()
	root.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root
