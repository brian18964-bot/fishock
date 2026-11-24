class_name SurfSplash
extends Node3D

## User request (the sea cliff): the waves striking the rocks out in the sea and the cliff's foot -
## "the wave reaching the rock -> its water climbing the face -> spray thrown up -> falling back under
## its own weight -> froth and a swirl of it left behind".
##
## Each place the waves strike (a rock: where, how wide; the cliff's foot where the sea meets the wall
## as it's built: where, which way it faces) watches the swell - Surf's, the sea's own shader's - and
## as a crest reaches it: first a sheet of water climbing the rock (fine drops shot up close along its
## face, falling straight back), a moment later the spray bursting up and out from it (drops of many
## sizes, speeds and lives - up and on over a rock the way the wave was going, up and back out from
## the wall), and a slow drift of mist - the bigger the wave the higher; all of it lit as the night is
## (the cliff's cool fill and the lamp; no glow of its own - no bright specks). The froth it leaves,
## swirling, is the sea's shader's (its rocks and its wall). Only the places near the player (NEAR m)
## are watched, from a few emitters kept and used again (the oldest taken when all are busy).

## (how near the player (m) a place splashes; the emitters kept (fewer on a phone); drops in a burst at
## its biggest; their speed up (m/s) at a wave's biggest; gravity (m/s²); how long the water climbs
## the face before the spray bursts (s))
const NEAR := 26.0
const POOL := 8
const POOL_LOW := 4
const DROPS := 40
const LAUNCH := 4.6
const GRAVITY := 9.8
const CLIMB_LEAD := 0.12
const SPRAY_TINT := Color(0.78, 0.83, 0.86)
## 浪擊強度 (x the wave's own size and how square it meets the rock); 水花高度 (m, a wave at its
## biggest striking a wall); how long the sheet of water stands (s). (The rock's wet band is the
## wall's own colour - RunView3D._cliff_wet - as high as the spray reaches.)
const STRIKE := 1.0
const SHEET_HIGH := 1.7
const SHEET_LIFE := 0.95

## (the sheet of water a wave throws up against the rock: a ring of it (or the part of one facing
## the sea, against the wall) rising and opening out, thinning and tearing into drops from its top
## edge, slumping back - lit as the night is)
const SHEET_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float age = 1.0;
uniform float rise = 1.0;
uniform float flare = 0.6;
uniform float arc = 1.0;
uniform vec3 tint : source_color = vec3(0.72, 0.78, 0.82);
varying float vv;
varying vec2 dir;
void vertex() {
	float v = VERTEX.y + 0.5;
	dir = normalize(VERTEX.xz + vec2(0.00001));
	float up = sin(clamp(age * 1.7, 0.0, 1.0) * 1.5708) * (1.0 - 0.75 * smoothstep(0.5, 1.0, age));
	float r = 0.5 + flare * v * (0.35 + 0.9 * age);
	VERTEX = vec3(dir.x * r, v * rise * up, dir.y * r);
	vv = v;
}
float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float a0 = atan(dir.x, -dir.y);
	float sector = arc > 0.99 ? 1.0 : 1.0 - smoothstep(arc * 2.6, arc * 3.14159, abs(a0));
	float n = vn(vec2(a0 * 6.0, vv * 5.0 - age * 3.0)) * 0.6 + vn(vec2(a0 * 15.0, vv * 12.0 + 3.0)) * 0.4;
	float edge = 0.22 + 0.62 * age + 0.3 * vv;
	float torn = smoothstep(edge, edge + 0.16, n);
	float a = sector * torn * (1.0 - smoothstep(0.72, 1.0, vv)) * smoothstep(0.0, 0.06, vv) * (1.0 - smoothstep(0.55, 1.0, age));
	ALBEDO = tint;
	ROUGHNESS = 0.25;
	SPECULAR = 0.5;
	ALPHA = clamp(a * 0.5, 0.0, 0.6);
}
"""

## The places the waves strike (each: {at: Vector3 at the water, out: Vector2 its way out to sea
## (x, z), size: m, d: px out in the sea, wall: bool, last: int the last crest seen}).
var spots: Array = []
## Bursts thrown (for tests).
var bursts := 0
var _climb: Array[CPUParticles3D] = []
var _spray: Array[CPUParticles3D] = []
var _mist: Array[CPUParticles3D] = []
var _next := 0
var _pending: Array = []
var _layers := 1
var _sheets: Array[MeshInstance3D] = []
var _sheet_age: PackedFloat32Array = []


func setup(low: bool, layers := 1) -> void:
	_layers = layers
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.7))
	dot.gradient = g
	for k in (POOL_LOW if low else POOL):
		_climb.append(_emitter(dot, "climb"))
		_spray.append(_emitter(dot, "spray"))
		_mist.append(_emitter(dot, "mist"))
	var sh := Shader.new()
	sh.code = SHEET_SHADER
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 28
	cyl.rings = 6
	cyl.cap_top = false
	cyl.cap_bottom = false
	for k in (POOL_LOW if low else POOL):
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		var m := ShaderMaterial.new()
		m.shader = sh
		mi.material_override = m
		mi.visible = false
		mi.layers = _layers
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_sheets.append(mi)
		_sheet_age.append(1.0)



## A place a rock stands in the sea (`at` its foot at the water, `size` its radius m, `d` px out,
## `high` how far it stands up out of the water m - a low one the waves wash over).
func add_rock(at: Vector3, size: float, out: Vector2, d: float, high := 1.0) -> void:
	spots.append({"at": at, "out": out.normalized(), "size": size, "d": d, "wall": false, "last": -1, "high": high})


## A stretch of the cliff's foot (`at` at the water, facing `out`, `d` px out in the sea).
func add_wall(at: Vector3, out: Vector2, d: float) -> void:
	spots.append({"at": at, "out": out.normalized(), "size": 2.0, "d": d, "wall": true, "last": -1, "high": 3.0})


## Watch the swell at the places near `near` (3D): the water climbing a rock where a crest has just
## come, its spray a moment after.
func update(near: Vector3, delta := 0.0) -> void:
	for k in _sheets.size():
		if _sheet_age[k] < 1.0:
			_sheet_age[k] = minf(_sheet_age[k] + delta / SHEET_LIFE, 1.0)
			(_sheets[k].material_override as ShaderMaterial).set_shader_parameter("age", _sheet_age[k])
			_sheets[k].visible = _sheet_age[k] < 1.0
	for k in range(_pending.size() - 1, -1, -1):
		_pending[k][0] -= delta
		if _pending[k][0] <= 0.0:
			_throw(_pending[k][1], _pending[k][2], _pending[k][3])
			_pending.remove_at(k)
	for s in spots:
		var at: Vector3 = s.at
		var w := Vector2(at.x, at.z)
		var k := floori(Surf.crest(w, float(s.d)))
		if int(s.last) == k:
			continue
		var was := int(s.last)
		s.last = k
		# (the first look only learns where the swell is; far off, nothing to see)
		if was < 0 or Vector2(near.x - at.x, near.z - at.z).length() > NEAR:
			continue
		# (the wave that's come: crest() counts them seaward-first, so it's the one numbered k)
		_burst(s, Surf.size_of(k))


func _burst(s: Dictionary, size: float) -> void:
	var i := _next
	_next = (_next + 1) % _spray.size()
	# (how hard it strikes: the wave's size, how square it meets the face - a wall facing along the
	# coast takes it glancing)
	var sea := MapGenerator.sea_side if MapGenerator.sea_side != Vector2.ZERO else Vector2(0, 1)
	var facing := clampf((s.out as Vector2).dot(sea), 0.25, 1.0) if bool(s.wall) else 1.0
	var strong := (0.45 + 0.75 * size) * facing * STRIKE
	_sheet(i, s, size, strong)
	var out: Vector2 = s.out
	var at: Vector3 = s.at
	var r := float(s.size)
	# (first the water climbing the face: fine drops shot up close along it, falling straight back)
	var climb := _climb[i]
	_place(climb, s, r)
	climb.position = at + Vector3(0.0, 0.02, 0.0)
	climb.direction = Vector3(-out.x * 0.12, 1.0, -out.y * 0.12).normalized() if bool(s.wall) else Vector3.UP
	climb.initial_velocity_min = 2.0 * strong
	climb.initial_velocity_max = 3.6 * strong
	climb.restart()
	climb.emitting = true
	_pending.append([CLIMB_LEAD, s, size, i])
	bursts += 1


## The sheet of water thrown up first where it struck, and the rock wet as high as it went.
func _sheet(i: int, s: Dictionary, size: float, strong: float) -> void:
	var out: Vector2 = s.out
	var at: Vector3 = s.at
	var high := float(s.get("high", 1.0))
	var r := float(s.size)
	var mi := _sheets[i]
	var m := mi.material_override as ShaderMaterial
	var rise: float
	if bool(s.wall):
		# (against the wall: straight up it and out, the part facing the sea)
		rise = SHEET_HIGH * (0.55 + 0.45 * size) * strong
		m.set_shader_parameter("arc", 0.42)
		m.set_shader_parameter("flare", 0.5)
		mi.basis = Basis(Vector3.UP, atan2(-out.x, -out.y)).scaled(Vector3(r * 1.3, 1.0, 1.1))
	elif high < 0.45:
		# (a low rock: washed over - a low, wide spill of it all round)
		rise = (0.35 + 0.35 * size) * strong
		m.set_shader_parameter("arc", 1.0)
		m.set_shader_parameter("flare", 1.5)
		mi.basis = Basis.IDENTITY.scaled(Vector3(r * 2.2, 1.0, r * 2.2))
	else:
		# (a rock standing up: thrown up its seaward face and round it, as high as it is and more)
		rise = clampf(0.5 + 0.55 * high, 0.5, SHEET_HIGH * 1.2) * (0.55 + 0.45 * size) * strong
		m.set_shader_parameter("arc", 0.62)
		m.set_shader_parameter("flare", 0.8)
		mi.basis = Basis(Vector3.UP, atan2(-out.x, -out.y)).scaled(Vector3(r * 2.1, 1.0, r * 2.1))
	m.set_shader_parameter("rise", rise)
	m.set_shader_parameter("age", 0.0)
	mi.position = at + Vector3(0.0, -0.05, 0.0)
	mi.visible = true
	_sheet_age[i] = 0.0


## The spray bursting from where the water climbed, and its mist.
func _throw(s: Dictionary, size: float, i: int) -> void:
	var strong := 0.45 + 0.75 * size
	var out: Vector2 = s.out
	var at: Vector3 = s.at
	var r := float(s.size)
	# (over a rock: up and on the way the wave was going; off the wall: up and back out from it)
	var dir := Vector3(out.x * 0.4, 1.0, out.y * 0.4) if bool(s.wall) else Vector3(-out.x * 0.45, 1.0, -out.y * 0.45)
	var spray := _spray[i]
	var mist := _mist[i]
	_place(spray, s, r)
	_place(mist, s, r)
	spray.position = at + Vector3(0.0, 0.25 + 0.25 * size, 0.0)
	spray.direction = dir.normalized()
	spray.initial_velocity_min = LAUNCH * strong * 0.3
	spray.initial_velocity_max = LAUNCH * strong
	spray.restart()
	spray.emitting = true
	mist.position = at + Vector3(0.0, 0.5 + 0.4 * size, 0.0)
	mist.direction = dir.normalized()
	mist.initial_velocity_min = 0.4 * strong
	mist.initial_velocity_max = 1.2 * strong
	mist.restart()
	mist.emitting = true


## An emitter set to a place: along the wall's foot a stretch wide, or round a rock's face.
func _place(p: CPUParticles3D, s: Dictionary, r: float) -> void:
	var out: Vector2 = s.out
	if bool(s.wall):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(r, 0.08, 0.15)
		p.basis = Basis(Vector3.UP, atan2(out.x, out.y))
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = r * 0.9
		p.emission_ring_inner_radius = r * 0.6
		p.emission_ring_height = 0.15
		p.basis = Basis.IDENTITY


## An emitter kept for the bursts - all its drops thrown at once (a drop not yet thrown would sit at
## the emitter, drawn dark), their lives, sizes and speeds each their own; falling under gravity,
## slowed by the air, fading as they go. Lit as the night is.
func _emitter(dot: Texture2D, kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.angle_max = 180.0
	var quad := QuadMesh.new()
	var fade := Gradient.new()
	var shrink := Curve.new()
	match kind:
		"climb":
			p.amount = 64
			p.lifetime = 0.6
			p.lifetime_randomness = 0.5
			p.spread = 5.0
			p.gravity = Vector3(0.0, -GRAVITY, 0.0)
			p.damping_min = 0.2
			p.damping_max = 0.8
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.3
			quad.size = Vector2.ONE * 0.07
			fade.set_color(0, Color(SPRAY_TINT, 0.6))
			fade.set_color(1, Color(SPRAY_TINT, 0.0))
			shrink.add_point(Vector2(0.0, 1.0))
			shrink.add_point(Vector2(1.0, 0.6))
		"spray":
			p.amount = DROPS
			p.lifetime = 1.25
			p.lifetime_randomness = 0.6
			p.spread = 40.0
			p.gravity = Vector3(0.0, -GRAVITY, 0.0)
			p.damping_min = 0.3
			p.damping_max = 1.4
			p.scale_amount_min = 0.5
			p.scale_amount_max = 2.2
			quad.size = Vector2.ONE * 0.09
			fade.set_color(0, Color(SPRAY_TINT, 0.75))
			fade.set_color(1, Color(SPRAY_TINT, 0.0))
			fade.add_point(0.55, Color(SPRAY_TINT, 0.45))
			shrink.add_point(Vector2(0.0, 0.7))
			shrink.add_point(Vector2(0.2, 1.0))
			shrink.add_point(Vector2(1.0, 0.5))
		_:
			p.amount = 5
			p.lifetime = 2.2
			p.lifetime_randomness = 0.35
			p.spread = 70.0
			p.gravity = Vector3(0.0, -0.5, 0.0)
			p.damping_min = 1.4
			p.damping_max = 2.2
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.1
			quad.size = Vector2.ONE * 1.0
			fade.set_color(0, Color(SPRAY_TINT, 0.14))
			fade.set_color(1, Color(SPRAY_TINT, 0.0))
			fade.add_point(0.3, Color(SPRAY_TINT, 0.09))
			shrink.add_point(Vector2(0.0, 0.5))
			shrink.add_point(Vector2(1.0, 1.0))
	p.color_ramp = fade
	p.scale_amount_curve = shrink
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = dot
	mat.roughness = 0.35
	mat.disable_receive_shadows = true
	quad.material = mat
	p.mesh = quad
	p.layers = _layers
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p
