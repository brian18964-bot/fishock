class_name SurfWade
extends Node3D

## User request (the sandy beach): the traveller's feet and the sea's water as they really meet -
## each foot as it comes down and lifts (SnowTracks.landed / lifted: the model's own ankles, as the
## clip puts them down), by how deep the water is there now and how fast the foot goes (Surf.depth,
## Surf.flow - the water the ground's shader draws):
##   - on dry sand: a little sand kicked up behind the foot;
##   - on wet sand: its print, dark and crisp (SnowTracks, RunView3D._beach_damp);
##   - in the thin sheet: a low, short splash thrown the way the foot goes, a ring spreading;
##   - wading on through deeper water: a little arc of water pushed ahead of each foot, a short
##     drag of it behind;
##   - a foot lifting out: a few drops falling from it, small rings where they fall;
##   - stood still as a wave goes by: the water parting round the feet - rings on the side it comes
##     from, a short wake on the other;
##   - out of the water onto the sand: the feet wet for a while (wet() - their prints dark).
## The feet under the water: the water over them (an overlay on the character's meshes: its tint
## and see-through below the water's surface at the feet, a pale line where it meets them).
## Everything here is small and quick - the scale of the shallows, splashes never higher than a shin.

## (how long a ring lasts (s); the splash's drops (each emitter's); how fast they're thrown (m/s) at a
## run in the sheet; the feet wet this long (s) after they leave the water; the water's colour as the
## night shows it (unlit - never dark against the sand))
const RING_LIFE := 0.9
const DROPS := 18
const THROW := 2.1
const FEET_DRY := 9.0
const TINT := Color(0.5, 0.56, 0.6)
const SAND_TINT := Color(0.55, 0.48, 0.36)
## (a foot moving through the water: an arc ahead of it every this many s, at least this fast (m/s))
const PUSH_EVERY := 0.2
const PUSH_SPEED := 0.35
## (stood still: the water parting round the feet as it flows faster than this (px/s))
const FLOW_MIN := 8.0

## (a ripple: not a drawn white ring but the water itself rising a little and falling as it spreads -
## a low crest and the trough just inside it, its slope lighting and darkening the surface as the
## moon and the lamp catch it; lower and fainter as it widens, gone where the water's too thin to
## hold it - the sheet's own depth, pixel by pixel. One MultiMesh: each ripple's age, arc and
## strength its instance's custom data)
const RING_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_schlick_ggx;
uniform sampler2D sea_tex : filter_linear, repeat_disable;
uniform vec4 sea_box = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 sea_range = vec2(-140.0, 620.0);
uniform vec3 tint : source_color = vec3(0.1, 0.15, 0.17);
""" + Surf.GLSL + """
varying vec4 cust;
varying vec3 wpos;
void vertex() {
	cust = INSTANCE_CUSTOM;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float age = cust.x;
	float t = 1.0 - (1.0 - age) * (1.0 - age);
	float radius = 0.12 + 0.76 * t;
	float wdt = mix(0.06, 0.2, t);
	float x = (r - radius) / wdt;
	float g0 = exp(-x * x);
	float g1 = exp(-(x + 1.4) * (x + 1.4));
	float h = g0 - 0.55 * g1;
	float dh = (-2.0 * x * g0 + 1.1 * (x + 1.4) * g1) / wdt;
	float ang = abs(atan(p.x, -p.y));
	float sector = cust.y > 0.99 ? 1.0 : 1.0 - smoothstep(cust.y * 2.4, cust.y * 3.14159, ang);
	float k = cust.z * (1.0 - age) * (1.0 - age) * sector * (1.0 - smoothstep(0.82, 1.0, r));
	// (only on the water - fading out where it runs onto sand the water's left)
	float shore = -mix(sea_range.x, sea_range.y, surf_smooth(sea_tex, (wpos.xz - sea_box.xy) / sea_box.zw));
	float e; float u; float n; float rr;
	float cover = surf_at(wpos.xz, shore, e, u, n, rr);
	k *= cover * smoothstep(0.5, 8.0, e - shore);
	vec2 dir = r > 0.0001 ? p / r : vec2(0.0);
	vec3 nl = normalize(vec3(-dir.x * dh * k * 0.06, 1.0, -dir.y * dh * k * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mat3(MODEL_MATRIX) * nl), 0.0)).xyz);
	ALBEDO = tint;
	ROUGHNESS = 0.18;
	SPECULAR = 0.55;
	ALPHA = clamp((abs(h) * 0.22 + abs(dh) * wdt * 0.12) * k, 0.0, 0.35);
}
"""

const LINE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// (the water's surface at the feet (m); none when they're out of it)
uniform float water_y = -100.0;
uniform vec3 tint : source_color = vec3(0.1, 0.17, 0.2);
uniform vec3 line_tint : source_color = vec3(0.62, 0.68, 0.72);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float below = water_y - wpos.y;
	// (the line where the water meets the leg, wavering a little)
	float wob = 0.004 * sin(wpos.x * 37.0 + wpos.z * 29.0 + TIME * 7.0);
	float line = 1.0 - smoothstep(0.0, 0.01, abs(below + wob));
	float under = smoothstep(-0.002, 0.02, below + wob);
	ALBEDO = mix(tint, line_tint, line);
	ROUGHNESS = 0.15;
	ALPHA = clamp(under * (0.22 + 1.6 * clamp(below, 0.0, 0.2)) + line * 0.5, 0.0, 0.7);
}
"""

## (the ground's height under a point; px up the sand from the sea's mean edge there - the coast's)
var ground_at: Callable
var shore_at: Callable
## The one wading: its rig (the ankles, its skeleton's), the 3D node it stands in (the pivot).
var rig: CharacterRig
var body: Node3D
## (for tests) splashes, rings, drips and sand kicks made; how wet the feet are now (0..1).
var splashes := 0
var rings := 0
var drips := 0
var kicks := 0
var feet := 0.0
## (for tests) the last step: the water's depth there (m), px up the sand, how fast (m/s).
var last_step := Vector3.ZERO

var _mm: MultiMesh
var _ring_mat: ShaderMaterial
var _ring_xf: Array[Transform3D] = []
var _ring_vel: Array[Vector3] = []
var _ring_cust: Array[Color] = []
var _ring_age: PackedFloat32Array = []
var _ring_life: PackedFloat32Array = []
var _next_ring := 0
var _sprays: Array[CPUParticles3D] = []
var _next_spray := 0
var _line_mat: ShaderMaterial
var _ring_shader: Shader
var _ankle := {}
var _ankle_vel := {}
var _push := {"_l": 0.0, "_r": 0.0}
var _flow_t := 0.0
var _dress_t := 0.0
var _pending: Array = []


func setup(low: bool) -> void:
	_ring_shader = Shader.new()
	_ring_shader.code = RING_SHADER
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = _ring_shader
	Surf.uniforms(_ring_mat)
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	quad.material = _ring_mat
	var n := 20 if low else 32
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.instance_count = n
	_mm.mesh = quad
	for k in n:
		_ring_xf.append(Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		_ring_vel.append(Vector3.ZERO)
		_ring_cust.append(Color(1, 1, 0, 0))
		_ring_age.append(1.0)
		_ring_life.append(RING_LIFE)
		_mm.set_instance_transform(k, _ring_xf[k])
		_mm.set_instance_custom_data(k, _ring_cust[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Ripples"
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	var dot := GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	for k in (4 if low else 8):
		_sprays.append(_emitter(dot))
	var ls := Shader.new()
	ls.code = LINE_SHADER
	_line_mat = ShaderMaterial.new()
	_line_mat.shader = ls


## The water over a point now (m) and its surface's height there (m).
func water_at(at: Vector3) -> Vector2:
	var shore: float = shore_at.call(at)
	var d := Surf.depth(Vector2(at.x, at.z), shore)
	return Vector2(d, float(ground_at.call(at)) + d)


## The sea's depth as the shaders have it (the ripples fade where the water's too thin, pixel by pixel).
func set_sea(tex: Texture2D, box: Vector4, span: Vector2) -> void:
	_ring_mat.set_shader_parameter("sea_tex", tex)
	_ring_mat.set_shader_parameter("sea_box", box)
	_ring_mat.set_shader_parameter("sea_range", span)


## A foot has come down (SnowTracks.landed).
func landed(side: String, at: Vector3, fwd: Vector2, speed: float) -> void:
	var w := water_at(at)
	last_step = Vector3(w.x, float(shore_at.call(at)), speed)
	var pace := clampf(speed / SnowTracks.RUN_SPEED, 0.12, 1.25)
	var f3 := Vector3(fwd.x, 0.0, fwd.y)
	var v: Vector3 = _ankle_vel.get(side, Vector3.ZERO)
	var go := Vector3(v.x, 0.0, v.z)
	var dir := go.normalized() if go.length() > 0.3 else f3
	if w.x > 0.004:
		# (in the water: a low splash the way the foot goes, as hard as it came down and as deep as
		# the water is; a ring spreading from it)
		var k := clampf(w.x / 0.05, 0.35, 1.0) * pace
		var on := Vector3(at.x, w.y + 0.01, at.z)
		_spray(on, dir, k, TINT)
		ring(on, 0.5 + 0.55 * k, 1.0, 0.65 + 0.35 * k, 0.0, RING_LIFE * (0.8 + 0.4 * k))
		feet = 1.0
		splashes += 1
	elif Surf.wetness(Vector2(at.x, at.z), float(shore_at.call(at))) < 0.15 and feet < 0.3:
		# (dry sand: a little of it kicked up behind the foot)
		_spray(at + Vector3(0.0, 0.01, 0.0), -dir * 0.6 + Vector3.UP * 0.2, 0.35 * pace, SAND_TINT)
		kicks += 1


## A foot has lifted (SnowTracks.lifted): out of the water, a few drops off it, rings where they fall.
func lifted(side: String, at: Vector3, speed: float) -> void:
	var w := water_at(at)
	if w.x <= 0.004:
		return
	var on := Vector3(at.x, w.y + 0.01, at.z)
	var p := _sprays[_next_spray]
	_next_spray = (_next_spray + 1) % _sprays.size()
	p.position = at + Vector3(0.0, 0.06, 0.0)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.color = TINT
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.35
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	p.restart()
	p.emitting = true
	drips += 1
	_pending.append([0.32, on, 0.28])
	_pending.append([0.45, on + Vector3(0.05, 0.0, -0.04), 0.22])


## A ring spreading on the water at `at` (`size` m across at its widest; `arc` 1 whole, less an
## arc ahead along `yaw`; `stretch` drawn out along it).
func ring(at: Vector3, size: float, arc: float, strength: float, yaw := 0.0, life := RING_LIFE, stretch := 1.0) -> void:
	var i := _next_ring
	_next_ring = (_next_ring + 1) % _ring_age.size()
	# (drawn out a little and carried along by the water flowing there)
	var fl := Surf.flow(Vector2(at.x, at.z))
	var up := -(MapGenerator.sea_side if MapGenerator.sea_side != Vector2.ZERO else Vector2(0, 1))
	var goes := Vector3(up.x, 0.0, up.y) * signf(fl)
	var pull := clampf(absf(fl) / 60.0, 0.0, 1.0)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size, 1.0, size * stretch))
	if pull > 0.05:
		var along := atan2(goes.x, goes.z)
		basis = Basis(Vector3.UP, along) * Basis().scaled(Vector3(1.0, 1.0, 1.0 + 0.35 * pull)) * Basis(Vector3.UP, -along) * basis
	_ring_xf[i] = Transform3D(basis, at)
	_ring_vel[i] = goes * absf(fl) / 27.108 * 0.3
	_ring_cust[i] = Color(0.0, arc, strength, 0.0)
	_ring_age[i] = 0.0
	_ring_life[i] = life
	_mm.set_instance_transform(i, _ring_xf[i])
	_mm.set_instance_custom_data(i, _ring_cust[i])
	rings += 1


## How wet the feet are (1 just out of the water .. 0 dry again, FEET_DRY s later).
func wet() -> float:
	return feet


func _process(delta: float) -> void:
	_ring_mat.set_shader_parameter("surf_time", Surf.time)
	for i in _ring_age.size():
		if _ring_age[i] >= 1.0:
			continue
		# (aging quicker where the water's drained from under it)
		var dry := water_at(_ring_xf[i].origin).x <= 0.002
		_ring_age[i] = minf(_ring_age[i] + delta / _ring_life[i] * (4.0 if dry else 1.0), 1.0)
		_ring_xf[i].origin += _ring_vel[i] * delta
		_ring_cust[i].r = _ring_age[i]
		if _ring_age[i] >= 1.0:
			_ring_xf[i] = Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
		_mm.set_instance_transform(i, _ring_xf[i])
		_mm.set_instance_custom_data(i, _ring_cust[i])
	for k in range(_pending.size() - 1, -1, -1):
		_pending[k][0] -= delta
		if _pending[k][0] <= 0.0:
			ring(_pending[k][1], _pending[k][2], 1.0, 0.5, 0.0, 0.6)
			_pending.remove_at(k)
	feet = maxf(feet - delta / FEET_DRY, 0.0)
	var skeleton: Skeleton3D = rig.skeleton if rig != null and is_instance_valid(rig) else null
	if skeleton == null or not is_instance_valid(skeleton) or delta <= 0.0:
		_line_mat.set_shader_parameter("water_y", -100.0)
		return
	var g := skeleton.global_transform
	var deepest := -100.0
	for side in ["_l", "_r"]:
		var b := skeleton.find_bone("foot" + side)
		if b < 0:
			continue
		var ankle: Vector3 = g * skeleton.get_bone_global_pose(b).origin
		var last: Vector3 = _ankle.get(side, ankle)
		var vel := (ankle - last) / delta
		_ankle[side] = ankle
		_ankle_vel[side] = vel
		var w := water_at(ankle)
		if w.x <= 0.004:
			continue
		deepest = maxf(deepest, w.y)
		# (the foot in the water - wet)
		if ankle.y < w.y + 0.1:
			feet = 1.0
		var go := Vector2(vel.x, vel.z)
		_push[side] = float(_push[side]) - delta
		if go.length() > PUSH_SPEED and ankle.y < w.y + 0.05 and w.x > 0.02 and float(_push[side]) <= 0.0:
			# (wading on: an arc of water pushed ahead of the foot, a short drag of it behind)
			_push[side] = PUSH_EVERY
			var yaw := atan2(-go.x, -go.y)
			var k := clampf(w.x / 0.08, 0.3, 1.0) * clampf(go.length() / 3.0, 0.3, 1.0)
			var on := Vector3(ankle.x, w.y + 0.01, ankle.z)
			var ahead := Vector3(go.x, 0.0, go.y).normalized()
			ring(on + ahead * 0.06, 0.45 + 0.35 * k, 0.32, 0.55 + 0.4 * k, yaw, 0.55)
			# (going quickly: a short drag of water behind)
			if go.length() > 1.5:
				ring(on - ahead * 0.12, 0.3 + 0.25 * k, 0.28, 0.35 + 0.3 * k, yaw + PI, 0.6, 2.2)
	# (the water over the feet: its surface's height where they are - none out of it; the overlay on
	# the character only while they're in it)
	_line_mat.set_shader_parameter("water_y", deepest)
	_dress_t -= delta
	if _dress_t <= 0.0 or (deepest > -50.0) != _dressed:
		_dress_t = 0.5
		_dress(deepest > -50.0)
	# (stood as a wave goes by: the water parting round the feet)
	if body != null and deepest > -50.0:
		var at := body.global_position
		var fl := Surf.flow(Vector2(at.x, at.z))
		var still := true
		for side in _ankle_vel:
			still = still and Vector2((_ankle_vel[side] as Vector3).x, (_ankle_vel[side] as Vector3).z).length() < PUSH_SPEED
		_flow_t -= delta
		if still and absf(fl) > FLOW_MIN and _flow_t <= 0.0:
			_flow_t = clampf(6.0 / absf(fl), 0.12, 0.4)
			var up := -(MapGenerator.sea_side if MapGenerator.sea_side != Vector2.ZERO else Vector2(0, 1))
			# (the way the water's going)
			var goes := up * signf(fl)
			var yaw := atan2(goes.x, goes.y) + PI
			var k := clampf(absf(fl) / 40.0, 0.3, 1.0)
			for side in _ankle:
				var a: Vector3 = _ankle[side]
				var on := Vector3(a.x, deepest + 0.01, a.z)
				ring(on - Vector3(goes.x, 0.0, goes.y) * 0.05, 0.35 + 0.2 * k, 0.35, 0.6 * k, yaw + PI, 0.6)


## The water over the character's feet: the overlay on its meshes while in the water (checked
## again now and then - it may be rebuilt), taken off out of it.
var _dressed := false


func _dress(on: bool) -> void:
	_dressed = on
	if rig == null or not is_instance_valid(rig):
		return
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if on and m.material_overlay == null:
			m.material_overlay = _line_mat
		elif not on and m.material_overlay == _line_mat:
			m.material_overlay = null


func _spray(at: Vector3, dir: Vector3, k: float, tint: Color) -> void:
	var p := _sprays[_next_spray]
	_next_spray = (_next_spray + 1) % _sprays.size()
	p.position = at
	# (low and short: thrown mostly the way the foot goes, a little up)
	p.direction = (dir.normalized() * 0.75 + Vector3.UP * 0.65).normalized()
	p.spread = 38.0
	p.color = tint
	p.initial_velocity_min = THROW * k * 0.35
	p.initial_velocity_max = THROW * k
	p.scale_amount_min = 0.6 + 0.3 * k
	p.scale_amount_max = 1.0 + 0.6 * k
	p.restart()
	p.emitting = true


func _emitter(dot: Texture2D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	# (all at once - a drop not yet thrown would sit at the emitter, drawn dark)
	p.explosiveness = 1.0
	p.lifetime = 0.38
	p.lifetime_randomness = 0.4
	p.amount = DROPS
	p.local_coords = false
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.04
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = dot
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p
