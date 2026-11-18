class_name SandDrift
extends Node3D

## User request (the desert map): blown sand. Thin wisps of sand streaming low over the ground
## downwind round the traveller - with the gusts (Foliage's wind, the one the palms bend to): in a
## lull hardly any, faint and slow; in a gust many, quicker and longer, lifted a little higher, and
## clouds of dust rolling over the sand in the strongest. Each wisp follows the ground under it -
## over the dunes and down into their hollows. RunView3D keeps the square on the traveller (a wisp
## blown out of it comes back in upwind). And a little sand kicked up where a foot comes down at a
## run (kick - the prints in the sand, SnowTracks.printed).

## Wisps (a phone half), the square (m, half its side), a wisp's size (m: long, wide).
const STREAKS := 150
const HALF := 12.0
const STREAK := Vector2(0.9, 0.07)
## Dust clouds (a phone half) and their size (m).
const PUFFS := 8
const PUFF := 2.6
## A gust (the trees' formula, times the wind) under CALM hardly blows sand; at STRONG it's full.
const CALM := 0.35
const STRONG := 0.95
## A wisp's speed (m/s) in a lull and in a full gust, and its height over the sand (m).
const SPEED := Vector2(0.6, 5.5)
const RISE := Vector2(0.02, 0.4)
## (paler than the sand it blows over, so it shows against it)
const SAND := Color(1.0, 0.9, 0.74)

var ground: Callable
var water_y := -0.12
var count := STREAKS
var puffs := PUFFS
var _streaks: MultiMeshInstance3D
var _clouds: MultiMeshInstance3D
var _pos := PackedVector3Array()
var _h := PackedFloat32Array()
var _k := PackedFloat32Array()
var _a := PackedFloat32Array()
var _puff_pos := PackedVector3Array()
var _centre := Vector3.ZERO
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _kicks: Array[CPUParticles3D] = []
var _next_kick := 0
var _heights := {}
## How hard the wind's blowing sand round the traveller now (0..1, for the prints' filling-in and
## the tests).
var blowing := 0.0


func setup(centre: Vector3) -> void:
	_rng.seed = 31
	_centre = centre
	top_level = true
	_streaks = _layer(count, _streak_mesh())
	_clouds = _layer(puffs, _puff_mesh())
	_pos.resize(count)
	_h.resize(count)
	_k.resize(count)
	_a.resize(count)
	for i in count:
		_pos[i] = centre + Vector3(_rng.randf_range(-HALF, HALF), 0.0, _rng.randf_range(-HALF, HALF))
		_h[i] = _rng.randf()
		_k[i] = _rng.randf_range(0.6, 1.3)
		_a[i] = _rng.randf_range(0.35, 1.0)
	_puff_pos.resize(puffs)
	for i in puffs:
		_puff_pos[i] = centre + Vector3(_rng.randf_range(-HALF, HALF), 0.0, _rng.randf_range(-HALF, HALF))
	for _i in 4:
		var p := _kick_emitter()
		add_child(p)
		_kicks.append(p)


func follow(centre: Vector3) -> void:
	_centre = centre


func _layer(n: int, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A wisp: a flat streak lying on the air, soft at its ends and sides (lit, so it's dark in the
## night and pale in the lamp's reach).
func _streak_mesh() -> Mesh:
	var q := PlaneMesh.new()
	q.size = Vector2(1.0, 1.0)
	var img := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 64:
			var u := x / 63.0
			var v := (y - 3.5) / 3.5
			var a := sin(PI * u) * (1.0 - v * v) * (0.6 + 0.4 * sin(u * 23.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	q.material = _mat(ImageTexture.create_from_image(img), false)
	return q


## A dust cloud: a soft round billboard.
func _puff_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.6)
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var d := Vector2(x - 23.5, y - 23.5).length() / 23.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	q.material = _mat(ImageTexture.create_from_image(img), true)
	return q


func _mat(tex: Texture2D, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m


func _kick_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(SAND, 0.7), Color(SAND, 0.0)])
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	q.material = m
	p.mesh = q
	p.top_level = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## A foot came down at `at` going `speed` m/s: at a run, a little sand thrown up.
func kick(at: Vector3, speed: float) -> void:
	if speed < 2.6 or _kicks.is_empty():
		return
	var p := _kicks[_next_kick]
	_next_kick = (_next_kick + 1) % _kicks.size()
	p.global_position = at + Vector3(0, 0.03, 0)
	p.amount = int(clampf(6.0 + speed * 2.0, 6.0, 16.0))
	p.restart()


## The ground's height at `p`, looked up once a half-metre square and kept.
func _floor(p: Vector3) -> float:
	var key := Vector2i(floori(p.x * 2.0), floori(p.z * 2.0))
	var h = _heights.get(key)
	if h == null:
		h = float(ground.call(Vector3((key.x + 0.5) * 0.5, 0.0, (key.y + 0.5) * 0.5))) if ground.is_valid() else 0.0
		_heights[key] = h
	return h


## The wind's gust at `p` now (Foliage's formula), times its strength.
func gust(p: Vector3, wind: float) -> float:
	return (0.55 + 0.45 * sin(_time * 0.5 + p.x * 0.05) * sin(_time * 0.31 + p.z * 0.07 + 1.3)) * wind


func step(delta: float, wind: float, wind_dir: Vector2) -> void:
	_time += delta
	var d := Vector3(wind_dir.x, 0.0, wind_dir.y).normalized()
	var side := Vector3(-d.z, 0.0, d.x)
	var mm := _streaks.multimesh
	blowing = clampf((gust(_centre, wind) - CALM) / (STRONG - CALM), 0.0, 1.0)
	for i in count:
		var p := _pos[i]
		var s := clampf((gust(p, wind) - CALM) / (STRONG - CALM), 0.0, 1.0)
		var speed := lerpf(SPEED.x, SPEED.y, s) * _k[i]
		p += (d * speed + side * sin(_time * 1.7 + float(i)) * 0.25) * delta
		var rel := p - _centre
		if absf(rel.x) > HALF or absf(rel.z) > HALF:
			# (blown out of the square: back in upwind, a new height)
			p.x = _centre.x + wrapf(rel.x, -HALF, HALF)
			p.z = _centre.z + wrapf(rel.z, -HALF, HALF)
			_h[i] = _rng.randf()
		var lift := lerpf(RISE.x, RISE.y, _h[i] * (0.25 + 0.75 * s))
		var fl := _floor(p)
		p.y = fl + lift
		_pos[i] = p
		# (faint toward the square's edge, so none pops in or out; none over the water)
		var edge := 1.0 - smoothstep(HALF * 0.7, HALF, maxf(absf(rel.x), absf(rel.z)))
		var dry := 1.0 if fl > water_y + 0.05 else 0.0
		var alpha := s * s * _a[i] * 0.7 * edge * dry
		var length := STREAK.x * (0.5 + 1.2 * s) * _k[i]
		var b := Basis(d * length, Vector3.UP, side * STREAK.y)
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, Color(SAND, alpha))
	var cm := _clouds.multimesh
	for i in puffs:
		var p := _puff_pos[i]
		var s := clampf((gust(p, wind) - 0.7) / 0.35, 0.0, 1.0)
		p += d * lerpf(1.0, 4.5, s) * delta
		var rel := p - _centre
		if absf(rel.x) > HALF or absf(rel.z) > HALF:
			p.x = _centre.x + wrapf(rel.x, -HALF, HALF)
			p.z = _centre.z + wrapf(rel.z, -HALF, HALF)
		var fl := _floor(p)
		p.y = fl + PUFF * 0.22
		_puff_pos[i] = p
		var edge := (1.0 - smoothstep(HALF * 0.6, HALF, maxf(absf(rel.x), absf(rel.z)))) * (1.0 if fl > water_y + 0.05 else 0.0)
		var k := PUFF * (0.8 + 0.4 * sin(float(i) * 2.3))
		cm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(k * 1.6, k, k)), p))
		cm.set_instance_color(i, Color(SAND, 0.16 * s * edge))
