class_name GroundLeaves
extends MultiMeshInstance3D

## User request (stage two of the wind): the leaves lying on the ground blown about by the wind,
## and kicked up by whoever walks through them. The ground's own picture has its litter painted
## in; these are real leaves over it, a few hundred about the traveller (RunView3D keeps this
## node's square on them - a leaf blown or walked out of it comes back in at the far side, so
## there are always as many about). A gust over GUST_LIFT sends them scurrying downwind, tumbling,
## and they settle when it drops; a traveller, an animal or the big ghost moving through them
## kicks them up and away, and they flutter back down. The wind is Foliage's, the same the trees
## bend to.

## How many (a phone half), the square they lie in (m, half its side) and their size (m).
const COUNT := 220
const HALF := 11.0
const SIZE := Vector2(0.13, 0.085)
## A gust (the trees' formula, times the wind) past this lifts them; how hard it pushes (m/s per
## unit over), how much they rise (m/s) and how fast they stop on the ground (per s).
const GUST_LIFT := 0.8
const GUST_PUSH := 2.6
const GUST_RISE := 0.7
const GROUND_DRAG := 5.0
const AIR_DRAG := 1.2
const GRAVITY := 3.2
## A mover within KICK_REACH (m) going over KICK_SPEED (m/s) kicks a leaf: away from it with
## KICK_AWAY of its speed, up KICK_UP (m/s).
const KICK_REACH := 0.9
const KICK_SPEED := 0.6
const KICK_AWAY := 0.9
const KICK_UP := 1.6

## Where the ground is (RunView3D._ground_at: a 3D point -> its height) and its water's level (a
## leaf on a pond floats).
var ground: Callable
var water_y := -0.12
## The ones that kick them: a callable giving [[position (3D), velocity (3D)], ...] each frame.
var movers: Callable
var colors: PackedColorArray = PackedColorArray([Color(0.85, 0.35, 0.1), Color(0.72, 0.18, 0.08),
	Color(0.9, 0.62, 0.15), Color(0.55, 0.32, 0.12), Color(0.42, 0.26, 0.12)])
var count := COUNT

var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _turn: PackedFloat32Array = PackedFloat32Array()
## Each leaf's ground height where it was last looked up (a lying leaf's isn't looked up again).
var _fy: PackedFloat32Array = PackedFloat32Array()
var _centre := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _time := 0.0
## How many are off the ground now (for the tests).
var airborne := 0
## Each leaf's height over the ground last frame (for the tests).
var lift: PackedFloat32Array = PackedFloat32Array()


func setup(centre: Vector3, leaf_picture: Texture2D) -> void:
	_rng.seed = 23
	_centre = centre
	var q := QuadMesh.new()
	q.size = SIZE
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = leaf_picture
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = count
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	_pos.resize(count)
	_vel.resize(count)
	_spin.resize(count)
	_turn.resize(count)
	_fy.resize(count)
	lift.resize(count)
	for i in count:
		var p := centre + Vector3(_rng.randf_range(-HALF, HALF), 0.0, _rng.randf_range(-HALF, HALF))
		p.y = _floor(p)
		_fy[i] = p.y
		_pos[i] = p
		_vel[i] = Vector3.ZERO
		_spin[i] = _rng.randf() * TAU
		_turn[i] = 0.0
		mm.set_instance_color(i, colors[_rng.randi() % colors.size()] * _rng.randf_range(0.75, 1.05))
	_write()


## The square follows the traveller: `centre` its middle now.
func follow(centre: Vector3) -> void:
	_centre = centre


## The ground's height at `p` (a leaf's lying height): looked up once per half-metre square and
## kept - the ground doesn't change, and working it out (the ponds' depths) is the dear part.
var _heights := {}


func _floor(p: Vector3) -> float:
	var key := Vector2i(floori(p.x * 2.0), floori(p.z * 2.0))
	var h = _heights.get(key)
	if h == null:
		var g: float = ground.call(Vector3((key.x + 0.5) * 0.5, 0.0, (key.y + 0.5) * 0.5)) if ground.is_valid() else 0.0
		h = maxf(g, water_y + 0.012) + 0.012
		_heights[key] = h
	return h


## The wind's gust at `p` now (Foliage's formula, shaders/foliage.gdshader), times its strength.
func gust(p: Vector3, wind: float) -> float:
	return (0.55 + 0.45 * sin(_time * 0.5 + p.x * 0.05) * sin(_time * 0.31 + p.z * 0.07 + 1.3)) * wind


func step(delta: float, wind: float, wind_dir: Vector2) -> void:
	_time += delta
	var d := Vector3(wind_dir.x, 0.0, wind_dir.y).normalized()
	var kickers: Array = movers.call() if movers.is_valid() else []
	airborne = 0
	for i in count:
		var p := _pos[i]
		var v := _vel[i]
		var fl := _fy[i]
		var up := p.y - fl
		var over := gust(p, wind) - GUST_LIFT
		if over > 0.0:
			# (blown: pushed downwind, a little sideways, lifted off now and then)
			var side := Vector3(-d.z, 0.0, d.x) * sin(_time * 3.1 + float(i) * 1.7) * 0.35
			v += (d + side) * over * GUST_PUSH * delta * 4.0
			if up < 0.03 and _rng.randf() < over * delta * 3.0:
				v.y += GUST_RISE * (0.5 + over)
			_turn[i] = lerpf(_turn[i], (6.0 + 8.0 * over) * (1.0 if i % 2 == 0 else -1.0), delta * 3.0)
		for k in kickers:
			var at: Vector3 = k[0]
			var kv: Vector3 = k[1]
			var speed := Vector2(kv.x, kv.z).length()
			if speed < KICK_SPEED:
				continue
			var off := Vector2(p.x - at.x, p.z - at.z)
			if off.length() > KICK_REACH:
				continue
			var away := off.normalized() if off.length() > 0.01 else Vector2(kv.x, kv.z).normalized()
			var push := Vector3(away.x, 0.0, away.y) * speed * KICK_AWAY + Vector3(kv.x, 0.0, kv.z) * 0.3
			v += push * (1.0 - off.length() / KICK_REACH)
			v.y = maxf(v.y, KICK_UP * minf(speed / 3.0, 1.0) * _rng.randf_range(0.6, 1.0))
			_turn[i] = _rng.randf_range(-14.0, 14.0)
		if up > 0.02 or v.y > 0.0:
			# (in the air: falling, slowed by it, fluttering down)
			airborne += 1
			v.y -= GRAVITY * delta
			v = v * maxf(0.0, 1.0 - AIR_DRAG * delta)
			v.x += sin(_time * 4.0 + float(i)) * 0.3 * delta
		else:
			v = v * maxf(0.0, 1.0 - GROUND_DRAG * delta)
			v.y = 0.0
			_turn[i] = _turn[i] * maxf(0.0, 1.0 - GROUND_DRAG * delta)
		if v.length_squared() < 0.000001 and up <= 0.02:
			# (lying still: nothing to work out - only its turn eases, and it's redrawn only while
			# it turns)
			if absf(_turn[i]) > 0.01:
				_spin[i] += _turn[i] * delta
				_turn[i] = _turn[i] * maxf(0.0, 1.0 - GROUND_DRAG * delta)
				_put(i)
			lift[i] = up
			continue
		p += v * delta
		var fl2 := _floor(p)
		_fy[i] = fl2
		if p.y < fl2:
			p.y = fl2
			if v.y < 0.0:
				v.y = 0.0
		# (off the square: back in at the far side, lying still)
		var rel := p - _centre
		if absf(rel.x) > HALF or absf(rel.z) > HALF:
			p.x = _centre.x + wrapf(rel.x, -HALF, HALF)
			p.z = _centre.z + wrapf(rel.z, -HALF, HALF)
			p.y = _floor(p)
			_fy[i] = p.y
			v = Vector3.ZERO
		_spin[i] += _turn[i] * delta
		_pos[i] = p
		_vel[i] = v
		lift[i] = p.y - _fy[i]
		_put(i)


func _write() -> void:
	for i in count:
		_put(i)


## Leaf `i` drawn where it is: lying flat on the ground, tilted as it tumbles in the air.
func _put(i: int) -> void:
	var p := _pos[i]
	var up := p.y - _fy[i]
	var tilt := clampf(up * 3.0, 0.0, 1.2) * sin(_spin[i] * 1.7)
	var b := Basis(Vector3.UP, _spin[i]) * Basis(Vector3.RIGHT, tilt)
	multimesh.set_instance_transform(i, Transform3D(b, p))
