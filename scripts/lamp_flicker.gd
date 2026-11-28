class_name LampFlicker
extends Node
## User request ("路邊有設計一些燈具，燈籠要亮在燈籠中，微微的紅色燈色、時不時還會稍微暗一些些；路燈也沒有亮在
## 燈罩中，也是要隨機暗一些，製造無人詭異的感覺"): a lit lamp's light and the glow in its lamp, now and then
## dimmed, each on its own dice. A lantern's flame wavers a little and now and then sinks softly; a lamp
## post's (the countryside's posts, the city's street lamps) stays steady, then stutters - a few quick
## drops - or browns out a while, as if nobody's been tending it.

## (how each kind dims: its steady waver (of its light); how long between dimmings (s); how low a dip
## goes and how long it lasts (s); how many dips in a run; how likely a run is a long brown-out instead,
## how low and how long - all mine for now)
const STYLES := {
	"lantern": {"waver": 0.05, "gap": Vector2(3.0, 9.0), "dip": Vector2(0.6, 0.85), "hold": Vector2(0.18, 0.6),
		"runs": Vector2i(1, 1), "brown": 0.0, "brown_dip": Vector2(1.0, 1.0), "brown_hold": Vector2(0.0, 0.0), "soft": true},
	"lamp": {"waver": 0.0, "gap": Vector2(2.5, 8.0), "dip": Vector2(0.25, 0.6), "hold": Vector2(0.05, 0.16),
		"runs": Vector2i(1, 3), "brown": 0.2, "brown_dip": Vector2(0.4, 0.6), "brown_hold": Vector2(0.6, 1.6), "soft": false},
}

## The glow in a lamp: a soft ball of light, brightest at its middle, added over what's behind it (the
## lamp's paper, its glass, the dark of a stone lantern's fire box) - so the lamp looks lit from within.
const GLOW_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.4);
uniform float energy = 1.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = colour * energy * f * f;
}
"""
static var _glow_shader: Shader

var style := "lantern"
var light: OmniLight3D
var base_energy := 1.0
## (the glows' materials - a glow ball's (its `energy`), a lit lamp head's (its emission) - and how
## bright each is at full)
var glows: Array = []
var _full: Array = []
## How bright it is now, of its full (0..1).
var level := 1.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _next := 0.0
## (the dips to come: [start s, length s, how low])
var _dips: Array = []


## A glow ball `size` (m: its radii across, up, deep) of `colour` at `at` in `holder`; its material.
static func glow(holder: Node3D, at: Vector3, size: Vector3, colour: Color, energy: float) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("colour", colour)
	mat.set_shader_parameter("energy", energy)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 16
	ball.rings = 8
	var mi := MeshInstance3D.new()
	# (a lamp with two - the red post's lanterns: LanternGlow, LanternGlow2)
	mi.name = "LanternGlow"
	var n := 2
	while holder.has_node(NodePath(str(mi.name))):
		mi.name = "LanternGlow%d" % n
		n += 1
	mi.mesh = ball
	mi.material_override = mat
	mi.scale = size
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	return mat


## Dims `the_light` and `the_glows` (their materials, as bright as they are now at full) the `kind`'s way
## (STYLES), on dice of its own (`seed_value`).
func setup(kind: String, the_light: OmniLight3D, the_glows: Array, seed_value: int) -> void:
	name = "LampFlicker"
	style = kind
	light = the_light
	base_energy = the_light.light_energy if the_light != null else 1.0
	glows = the_glows
	_full = []
	for mat in glows:
		_full.append(float((mat as ShaderMaterial).get_shader_parameter("energy")) if mat is ShaderMaterial
			else (mat as BaseMaterial3D).emission_energy_multiplier)
	_rng.seed = seed_value
	_t = _rng.randf() * 10.0
	_next = _t + _rng.randf_range(0.5, float(STYLES[style].gap.y))


func _process(delta: float) -> void:
	step(delta)


## On `delta` s: how bright it is now (level), its light and glows set to it.
func step(delta: float) -> float:
	var s: Dictionary = STYLES[style]
	_t += delta
	if _t >= _next:
		_plan(s)
	var low := 1.0
	var keep := []
	for d: Array in _dips:
		var u := (_t - float(d[0])) / float(d[1])
		if u > 1.0:
			continue
		keep.append(d)
		if u < 0.0:
			continue
		# (a lantern sinks and comes back softly; a lamp post drops and comes back at once)
		var k := sin(PI * u) if s.soft else 1.0
		low = minf(low, 1.0 - (1.0 - float(d[2])) * k)
	_dips = keep
	var waver := float(s.waver) * (0.6 * sin(_t * 7.3) + 0.4 * sin(_t * 13.1 + 1.7)) * 0.5
	level = clampf(low * (1.0 - float(s.waver) * 0.5 + waver), 0.0, 1.0)
	if light != null:
		light.light_energy = base_energy * level
	for i in glows.size():
		if glows[i] is ShaderMaterial:
			(glows[i] as ShaderMaterial).set_shader_parameter("energy", float(_full[i]) * level)
		else:
			(glows[i] as BaseMaterial3D).emission_energy_multiplier = float(_full[i]) * level
	return level


## (the next run of dips - or a brown-out - from now, and when the one after it comes)
func _plan(s: Dictionary) -> void:
	var at := _t
	if _rng.randf() < float(s.brown):
		var hold := _rng.randf_range(s.brown_hold.x, s.brown_hold.y)
		_dips.append([at, hold, _rng.randf_range(s.brown_dip.x, s.brown_dip.y)])
		at += hold
	else:
		for _i in _rng.randi_range(s.runs.x, s.runs.y):
			var hold := _rng.randf_range(s.hold.x, s.hold.y)
			_dips.append([at, hold, _rng.randf_range(s.dip.x, s.dip.y)])
			at += hold + _rng.randf_range(0.04, 0.2)
	_next = at + _rng.randf_range(s.gap.x, s.gap.y)
