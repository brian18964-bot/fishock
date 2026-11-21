class_name SurfSplash
extends Node3D

## User request (the sea cliff): the waves breaking on the rocks out in the sea and on the cliff's
## foot - the wave broken up, its water flung up white and falling back.
##
## Each place the waves strike (a rock: where, how wide; the cliff's foot: where, which way it
## faces) watches the swell (Surf's - the sea's own shader's): as a crest reaches it, a burst of
## spray thrown up from it - up and on over a rock the way the wave was going, up the face and back
## out from the cliff - the bigger the wave the higher and wider, falling back under its own weight
## (gravity, the air slowing the drops); with it a slower puff of mist that hangs and drifts. Only
## the places near the player (NEAR m) are watched, from a few emitters kept and used again (the
## oldest taken when all are busy).

## (how near the player (m) a place splashes; the emitters kept (fewer on a phone); drops in a
## rock's burst at its biggest; their speed up (m/s) at a wave's biggest; gravity (m/s²))
const NEAR := 26.0
const POOL := 10
const POOL_LOW := 5
const DROPS := 64
const LAUNCH := 5.2
const GRAVITY := 9.8
## (its colour as the night shows it - not lit, so never dark against the water: the foam's own)
const SPRAY_TINT := Color(0.62, 0.68, 0.72)

## The places the waves strike (each: {at: Vector3 at the water, out: Vector2 its way out to sea
## (x, z), size: m, d: px out in the sea, wall: bool, last: int the last crest seen}).
var spots: Array = []
## Bursts thrown (for tests).
var bursts := 0
var _spray: Array[CPUParticles3D] = []
var _mist: Array[CPUParticles3D] = []
var _next := 0


func setup(low: bool) -> void:
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.75))
	dot.gradient = g
	for k in (POOL_LOW if low else POOL):
		_spray.append(_emitter(dot, false))
		_mist.append(_emitter(dot, true))


## A place a rock stands in the sea (`at` its foot at the water, `size` its radius m, `d` px out).
func add_rock(at: Vector3, size: float, out: Vector2, d: float) -> void:
	spots.append({"at": at, "out": out.normalized(), "size": size, "d": d, "wall": false, "last": -1})


## A stretch of the cliff's foot (`at` at the water, facing `out`, `d` px out in the sea).
func add_wall(at: Vector3, out: Vector2, d: float) -> void:
	spots.append({"at": at, "out": out.normalized(), "size": 2.2, "d": d, "wall": true, "last": -1})


## Watch the swell at the places near `near` (3D): a burst where a crest has just come.
func update(near: Vector3) -> void:
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
	var strong := 0.45 + 0.75 * size
	var out: Vector2 = s.out
	var spray := _spray[_next]
	var mist := _mist[_next]
	_next = (_next + 1) % _spray.size()
	var at: Vector3 = s.at
	var r := float(s.size)
	var dir: Vector3
	if bool(s.wall):
		# (up the face, falling back out to sea off it; along the foot a stretch wide)
		dir = Vector3(out.x * 0.35, 1.0, out.y * 0.35)
		for e in [spray, mist]:
			var p := e as CPUParticles3D
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(r, 0.15, 0.25)
			p.basis = Basis(Vector3.UP, atan2(out.x, out.y))
	else:
		# (round the rock's face, up and on over it the way the wave was going)
		dir = Vector3(-out.x * 0.45, 1.0, -out.y * 0.45)
		for e in [spray, mist]:
			var p := e as CPUParticles3D
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = r * 0.85
			p.emission_ring_inner_radius = r * 0.5
			p.emission_ring_height = 0.2
			p.basis = Basis.IDENTITY
	spray.position = at + Vector3(0.0, 0.05, 0.0)
	spray.direction = dir.normalized()
	spray.initial_velocity_min = LAUNCH * strong * 0.45
	spray.initial_velocity_max = LAUNCH * strong
	spray.scale_amount_min = 0.5 + 0.2 * size
	spray.scale_amount_max = 1.2 + 0.9 * size
	spray.restart()
	spray.emitting = true
	mist.position = at + Vector3(0.0, 0.2, 0.0)
	mist.direction = dir.normalized()
	mist.initial_velocity_min = 0.6 * strong
	mist.initial_velocity_max = 1.6 * strong
	mist.scale_amount_min = 0.5 + 0.2 * size
	mist.scale_amount_max = 0.8 + 0.4 * size
	mist.restart()
	mist.emitting = true
	bursts += 1


## An emitter kept for the bursts: drops (or mist) thrown once, falling under gravity, slowed by
## the air, shrinking and fading as they go.
func _emitter(dot: Texture2D, mist: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	# (all thrown at once - a drop not yet thrown would sit at the emitter, drawn dark - their lives
	# of different lengths instead)
	p.explosiveness = 1.0
	p.lifetime_randomness = 0.45 if not mist else 0.35
	p.lifetime = 1.35 if not mist else 2.4
	p.amount = DROPS if not mist else 5
	p.local_coords = false
	p.spread = 42.0 if not mist else 70.0
	p.gravity = Vector3(0.0, -GRAVITY if not mist else -0.6, 0.0)
	p.damping_min = 0.4 if not mist else 1.4
	p.damping_max = 1.2 if not mist else 2.2
	p.angle_max = 180.0
	var fade := Gradient.new()
	fade.set_color(0, Color(SPRAY_TINT, 0.95 if not mist else 0.3))
	fade.set_color(1, Color(SPRAY_TINT, 0.0))
	fade.add_point(0.6 if not mist else 0.3, Color(SPRAY_TINT, 0.7 if not mist else 0.16))
	p.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6 if not mist else 0.5))
	shrink.add_point(Vector2(0.25, 1.0))
	shrink.add_point(Vector2(1.0, 0.45 if not mist else 1.0))
	p.scale_amount_curve = shrink
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.2 if not mist else 1.1)
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
