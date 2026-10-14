extends Node3D

## User request (after Vaultbreakers - 龍窟破壞者 - its picture: the
## camera's angle, how big the characters are, how its places are built):
## a trial of the run in true 3D perspective - one hand-built place, a
## lakeside clearing at night, to see the look before anything of the run
## itself moves over. Walk and run about it (the left stick, or WASD /
## arrows): the camera follows from up and behind at CAMERA_PITCH, the
## character about CHARACTER_SHARE of the screen's height.
##
## How it's built, after the reference:
##   the ground    not one flat picture - grass, forest floor, a dirt path
##                 with stepping stones down it, a round stone place, a mud
##                 shore going down under the water (vertex-painted, one
##                 shader, the run's own ground pictures)
##   the props     in groups at the edges (drums and crates, the tent and
##                 its woodpile, rocks along the shore), the middle left
##                 open to move about in
##   the frame     dark trees round the edge, some near the camera, so it's
##                 seen from among them
##   the light     cold moonlight over all (shadows), warm lanterns on
##                 posts and the fire, the 渡石's runes cold blue-green;
##                 the character's own lamp
## Models: the camp's (CampModel) and a few of the run's own nature models
## (assets/models/proto3d, Quaternius, CC0).

const PROTO := "res://assets/models/proto3d/"
## The camera: how far it looks down (degrees from level), how far back,
## its field of view - the character about CHARACTER_SHARE of the height.
const CAMERA_PITCH := 46.0
const CAMERA_DISTANCE := 9.5
const CAMERA_FOV := 42.0
const CAMERA_EASE := 5.0
## Walking up to WALK_MAX m/s (its clip at its own pace WALK_PACE), past it
## running (RUN_PACE); RUN_SPEED at the stick's full push.
const WALK_MAX := 1.9
const WALK_PACE := 0.8
const RUN_PACE := 3.0
const RUN_SPEED := 4.2
const TURN_RATE := 12.0
## The ground: its size (m) and how fine its grid is.
const SIZE := Vector2(60.0, 52.0)
const CELL := 0.5
const WATER_Y := -0.28
const MOON_DIR := Vector3(0.35, 0.55, -1.0)
## The path from the near edge to the dock, and the round stone place on
## it (centre, radius).
const PATH := [Vector3(-0.5, 0, 20.0), Vector3(-1.2, 0, 11.0), Vector3(-0.4, 0, 4.0), Vector3(0.0, 0, 0.0),
	Vector3(1.4, 0, -4.5), Vector3(2.2, 0, -8.6)]
const PATH_HALF := 1.1
const PLAZA := Vector3(0.0, 0, 0.0)
const PLAZA_R := 3.4
const START := Vector3(-0.8, 0, 8.0)

var character: CharacterRig
var pivot: Node3D
var camera: Camera3D
## [centre, radius] on the ground: what it can't walk through.
var blockers: Array = []
var _joystick: Node
var _fire_light: OmniLight3D
var _lanterns: Array = []
var _stone_mat: StandardMaterial3D
## The dock's reach along z (from, to).
var _dock_span := [0.0, 0.0]
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## (for the 3D camp built on this - scripts/camp3d.gd: the stone place and
## stepping stones laid, the grass and ferns strewn, each place's model by
## name, and how much bigger it's set)
var stones := true
var strew := true
var places := {}
var prop_scale := {}


func _ready() -> void:
	_rng.seed = 7
	_environment()
	_ground()
	_water()
	_places()
	_trees()
	if strew:
		_cover()
	_character()
	_hud()
	camera.global_transform = _camera_at(pivot.position)


# ---------------------------------------------------------------- the land

## Below sea level where the lake is: the shore wanders (x), the ground
## going down under the water past it.
func _shore_z(x: float) -> float:
	return -9.0 + 1.4 * sin(x * 0.31) + 0.7 * sin(x * 0.83 + 1.3) + 0.3 * sin(x * 1.9)


func _height(x: float, z: float) -> float:
	var past := _shore_z(x) - z
	if past <= 0.0:
		return 0.03 * sin(x * 0.7) * sin(z * 0.6)
	return -1.1 * smoothstep(0.0, 3.0, past)


## How far `p` is from the path (m).
func _path_dist(p: Vector3) -> float:
	var best := INF
	for i in PATH.size() - 1:
		var a: Vector3 = PATH[i]
		var b: Vector3 = PATH[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func _ground() -> void:
	var n := Vector2i(int(SIZE.x / CELL) + 1, int(SIZE.y / CELL) + 1)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.08
	for j in n.y:
		for i in n.x:
			var x := -SIZE.x * 0.5 + i * CELL
			var z := -SIZE.y * 0.6 + j * CELL
			var p := Vector3(x, 0, z)
			var wob := noise.get_noise_2d(x, z)
			# r: the dirt path, g: the stone place, b: the mud shore, a: the
			# forest floor (else grass)
			var path := 1.0 - smoothstep(PATH_HALF - 0.35, PATH_HALF + 0.35, _path_dist(p) + wob * 0.5)
			var plaza := 1.0 - smoothstep(PLAZA_R - 0.25, PLAZA_R + 0.25, p.distance_to(PLAZA) + wob * 0.3)
			if not stones:
				plaza = 0.0
			var shore := 1.0 - smoothstep(0.3, 2.2 + wob, z - _shore_z(x))
			var forest := clampf(0.5 + noise.get_noise_2d(x * 0.6 + 40.0, z * 0.6) * 1.6, 0.0, 1.0)
			forest = maxf(forest, smoothstep(9.0, 15.0, absf(x)))
			verts.append(Vector3(x, _height(x, z), z))
			cols.append(Color(path, plaza, shore, forest))
			uvs.append(Vector2(x, z))
	var idx := PackedInt32Array()
	for j in n.y - 1:
		for i in n.x - 1:
			var a := j * n.x + i
			idx.append_array([a, a + 1, a + n.x, a + 1, a + n.x + 1, a + n.x])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in verts.size():
		st.set_color(cols[k])
		st.set_uv(uvs[k])
		st.add_vertex(verts[k])
	for k in idx:
		st.add_index(k)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for pair in [["grass", "grass"], ["forest", "forest_floor"], ["path", "dirt"], ["stone", "lp_stone"], ["mud", "mud"]]:
		mat.set_shader_parameter(pair[0] + "_tex", load("res://assets/sprites/ground/%s_albedo.png" % pair[1]))
		mat.set_shader_parameter(pair[0] + "_nrm", load("res://assets/sprites/ground/%s_normal.png" % pair[1]))
	mi.material_override = mat
	add_child(mi)
	# Stepping stones down the path, a ring of them round the stone place.
	if not stones:
		return
	var stone_kinds := ["rock_path_1", "rock_path_round_wide", "rock_path_square_1"]
	var d := 0.0
	for i in PATH.size() - 1:
		var a: Vector3 = PATH[i]
		var b: Vector3 = PATH[i + 1]
		var len := a.distance_to(b)
		while d < len:
			var p := a.lerp(b, d / len)
			if p.distance_to(PLAZA) > PLAZA_R + 0.3:
				var side := Vector3(-(b - a).z, 0, (b - a).x).normalized()
				p += side * _rng.randf_range(-0.45, 0.45)
				_prop(stone_kinds[_rng.randi() % stone_kinds.size()], p, _rng.randf_range(0.5, 0.75),
					_rng.randf() * TAU, false, 0.0, true)
			d += _rng.randf_range(0.9, 1.3)
		d -= len
	for k in 22:
		var a := k * TAU / 22.0
		_prop(stone_kinds[k % 3], PLAZA + Vector3(cos(a), 0, sin(a)) * (PLAZA_R + 0.05), 0.55, a, false, 0.0, true)


func _water() -> void:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var n := FastNoiseLite.new()
	n.seed = 17
	n.frequency = 0.04
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.as_normal_map = true
	t.bump_strength = 6.0
	mat.set_shader_parameter("wave_tex", t)
	mat.set_shader_parameter("moon_dir", MOON_DIR)
	var q := PlaneMesh.new()
	q.size = Vector2(SIZE.x + 40.0, 40.0)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = q
	mi.material_override = mat
	mi.position = Vector3(0, WATER_Y, -30.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- the props

func _places() -> void:
	# The fire in the stone place, logs to sit on round it.
	var fire := CampModel.make("campfire", 1.6)
	fire.position = PLAZA
	fire.scale = Vector3.ONE * float(prop_scale.get("campfire", 1.0))
	add_child(fire)
	places["fire"] = fire
	_block(PLAZA, 0.7)
	_fire_light = _light(PLAZA + Vector3(0, 0.9, 0), Color(1.0, 0.55, 0.22), 2.6, 7.5)
	for k in 2:
		var a := 0.6 + k * 2.3
		var log := CampModel.make("log")
		log.position = PLAZA + Vector3(cos(a), 0, sin(a)) * 2.1
		log.rotation.y = -a
		add_child(log)
		places["log_%d" % k] = log
		_block(log.position, 0.55)
	# Lantern posts along the path and at the dock.
	for at in [Vector3(1.8, 0, 6.5), Vector3(-2.9, 0, 2.2), Vector3(3.3, 0, -3.8), Vector3(0.9, 0, -8.2)]:
		_lantern_post(at)
	# Left of the place: the drums, crates and a pack - a stores corner.
	var left := Vector3(-6.8, 0, -1.6)
	for spec in [["drum", Vector3(0, 0, 0), 0.3], ["drum", Vector3(0.85, 0, -0.35), 1.2],
			["crate", Vector3(-0.4, 0, 1.3), 0.5], ["backpack", Vector3(0.9, 0, 0.9), 2.2],
			["drum_trough", Vector3(-1.6, 0, -0.6), 1.4]]:
		var m := CampModel.make(spec[0])
		m.position = left + spec[1]
		m.rotation.y = spec[2]
		if spec[0] == "drum":
			m.scale = Vector3.ONE * 1.15
		m.scale *= float(prop_scale.get(spec[0], 1.0))
		if spec[0] != "drum":
			places[spec[0]] = m
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(m)
	_block(left + Vector3(0.0, 0, 0.2), 1.6)
	_block(left + Vector3(-1.6, 0, -0.6), 0.8)
	# Right of it: the tent and its woodpile.
	var tent := CampModel.make("tent_3")
	tent.position = Vector3(7.4, 0, 0.6)
	tent.rotation.y = -1.9
	tent.scale = Vector3.ONE * 0.85 * float(prop_scale.get("tent", 1.0))
	places["tent"] = tent
	tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(tent)
	_block(tent.position, 2.0)
	for k in 3:
		var log := CampModel.make("log")
		log.position = Vector3(5.2, 0.22 * k, 3.4) + Vector3(0, 0, 0.42 * (k % 2))
		log.rotation.y = 0.25
		log.scale = Vector3(0.9, 0.75, 0.75)
		add_child(log)
	_block(Vector3(5.2, 0, 3.5), 0.9)
	# The 渡石 by the water, its runes glowing.
	var stone := CampModel.make("ferry_stone", 1.0)
	stone.position = Vector3(-5.2, 0, -7.6)
	stone.rotation.y = 0.4
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	places["stone"] = stone
	_stone_mat = stone.material_override as StandardMaterial3D
	_stone_mat.emission = Color(0.4, 0.85, 1.0)
	_stone_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	add_child(stone)
	_block(stone.position, 0.7)
	_light(stone.position + Vector3(0.4, 0.6, 0.8), Color(0.35, 0.85, 1.0), 1.2, 4.5)
	# The dock out over the water (planks on posts), the boat beside it.
	_dock(Vector3(2.4, 0, _shore_z(2.4) + 1.0), 8.0)
	var boat := CampModel.make("boat")
	boat.position = Vector3(4.1, WATER_Y - 0.55, _shore_z(2.4) - 4.5)
	boat.rotation.y = 0.2
	boat.scale = Vector3(0.6, 0.6, 0.6)
	add_child(boat)
	# Rocks along the shore and at the edges.
	for k in 26:
		var x := _rng.randf_range(-26.0, 26.0)
		var z := _shore_z(x) + _rng.randf_range(-0.3, 1.6)
		if absf(x - 2.4) < 1.6:
			continue
		var r := _prop("rock_medium" if k % 2 == 0 else "rock_medium_2", Vector3(x, _height(x, z), z),
			_rng.randf_range(0.35, 1.0), _rng.randf() * TAU, true)
		if r != null and k % 3 == 0:
			_block(Vector3(x, 0, z), 0.5)


## A plank walk `length` m out north from `start`, on posts.
func _dock(start: Vector3, length: float) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.2, 0.12)
	wood.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.11, 0.07)
	var n := int(length / 0.32)
	for k in n:
		var plank := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.4, 0.06, 0.28)
		plank.mesh = b
		plank.material_override = wood if k % 3 != 1 else dark
		plank.position = start + Vector3(_rng.randf_range(-0.03, 0.03), 0.3, -k * 0.32)
		plank.rotation.y = _rng.randf_range(-0.02, 0.02)
		add_child(plank)
	for k in int(length / 1.6) + 1:
		for side in [-0.66, 0.66]:
			var post := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.07
			c.bottom_radius = 0.08
			c.height = 1.6
			post.mesh = c
			post.material_override = dark
			post.position = start + Vector3(side, -0.2, -k * 1.6)
			add_child(post)
	_dock_span = [start.z - length, start.z + 0.4]


func _lantern_post(at: Vector3) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.14, 0.08)
	wood.roughness = 0.9
	var post := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.08
	c.height = 2.1
	post.mesh = c
	post.material_override = wood
	post.position = at + Vector3(0, 1.05, 0)
	add_child(post)
	var arm := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.62, 0.07, 0.07)
	arm.mesh = b
	arm.material_override = wood
	arm.position = at + Vector3(0.28, 2.0, 0)
	add_child(arm)
	var lamp: Node3D = load("res://assets/models/oil_lamp.glb").instantiate()
	lamp.scale = Vector3.ONE * 0.9
	lamp.position = at + Vector3(0.52, 1.58, 0)
	add_child(lamp)
	var flame := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	flame.mesh = s
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.82, 0.5)
	flame.material_override = fm
	flame.position = at + Vector3(0.52, 1.72, 0)
	add_child(flame)
	_lanterns.append(_light(at + Vector3(0.52, 1.75, 0), Color(1.0, 0.68, 0.35), 1.5, 5.5))
	_block(at, 0.25)


func _trees() -> void:
	var spots := []
	for k in 220:
		var x := _rng.randf_range(-29.0, 29.0)
		var z := _rng.randf_range(-8.0, 24.0)
		var p := Vector3(x, 0, z)
		if z < _shore_z(x) + 1.0 or _path_dist(p) < 2.6 or p.distance_to(PLAZA) < 6.5:
			continue
		# (the middle kept open; thick toward the sides, a few near the camera)
		if absf(x) < 8.0 and z < 12.0:
			continue
		spots.append(p)
	# The far shore: a dark line of them.
	for k in 40:
		spots.append(Vector3(_rng.randf_range(-40.0, 40.0), WATER_Y, _rng.randf_range(-48.0, -42.0)))
	var models := ["pine_a", "pine_b", "pine_c"]
	for m in models.size():
		var mine := []
		for i in spots.size():
			if i % models.size() == m:
				mine.append(spots[i])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = CampModel.tree_mesh(models[m])
		mm.instance_count = mine.size()
		for i in mine.size():
			var s := _rng.randf_range(0.55, 1.0)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), mine[i]))
			if mine[i].y == 0.0:
				_block(mine[i], 0.45)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)


## Grass and ferns over the grass, off the path and the
## stone place; mushrooms under the trees.
func _cover() -> void:
	# [model, size (m), how many, sized by its width]
	var kinds := [["grass_wispy", 0.45, 260, false], ["tall_grass", 0.6, 90, false],
		["fern", 0.9, 60, true], ["mushroom", 0.22, 30, false]]
	for kind in kinds:
		var mesh := _model_mesh(kind[0], kind[3])
		if mesh == null:
			continue
		var at := []
		var tries := 0
		while at.size() < int(kind[2]) and tries < 3000:
			tries += 1
			var p := Vector3(_rng.randf_range(-24.0, 24.0), 0, _rng.randf_range(-8.0, 22.0))
			if p.z < _shore_z(p.x) + 0.6 or _path_dist(p) < PATH_HALF + 0.2 or p.distance_to(PLAZA) < PLAZA_R + 0.4:
				continue
			if kind[0] == "fern" and _path_dist(p) > 6.0 and absf(p.x) < 9.0:
				continue  # (ferns edge the path and the clusters, not the open middle)
			at.append(p)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh[0]
		mm.instance_count = at.size()
		for i in at.size():
			var s: float = float(kind[1]) / maxf(mesh[1], 0.01) * _rng.randf_range(0.7, 1.3)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), at[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## A nature model's first mesh and its height (for a MultiMesh).
func _model_mesh(name: String, wide := false) -> Array:
	var path := PROTO + name + ".glb"
	if not ResourceLoader.exists(path):
		return []
	var inst: Node = (load(path) as PackedScene).instantiate()
	var found: Array = []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		var box := m.get_aabb()
		found = [m, maxf(box.size.x, box.size.z) if wide else box.size.y]
		break
	inst.free()
	return found


## A nature model placed `height` m high (0: as it comes).
func _prop(name: String, at: Vector3, height: float, yaw: float, shadow := true, sink := 0.0, wide := false) -> Node3D:
	var path := PROTO + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	add_child(n)
	if height > 0.0:
		# (`wide`: `height` is how wide it is - a flat stone)
		var box := _aabb(n)
		var along := maxf(box.size.x, box.size.z) if wide else box.size.y
		if along > 0.001:
			n.scale = Vector3.ONE * (height / along)
	n.position = at - Vector3(0, sink, 0)
	n.rotation.y = yaw
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## The dock stretched to `length` m along it, its deck `deck` m up.
func _fit_length(n: Node3D, length: float, deck: float) -> void:
	n.scale = Vector3.ONE
	var box := _aabb(n)
	var long := maxf(box.size.x, box.size.z)
	var k := length / maxf(long, 0.01)
	n.scale = Vector3.ONE * k
	box = _aabb(n)
	n.position.y += deck - box.end.y + n.position.y * 0.0
	# Out from the shore into the lake (its far end to the north).
	n.position.z -= length * 0.5


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _block(at: Vector3, r: float) -> void:
	blockers.append([Vector3(at.x, 0, at.z), r])


func _light(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.position = at
	add_child(l)
	return l


# ---------------------------------------------------------------- the night

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.26, 0.38)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.11)
	env.fog_density = 0.018
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 0.95)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 32.0
	add_child(moon)
	moon.look_at(moon.global_position - MOON_DIR.normalized(), Vector3.UP)
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.far = 120.0
	add_child(camera)
	camera.current = true


# ---------------------------------------------------------------- the traveller

func _character() -> void:
	pivot = Node3D.new()
	pivot.name = "Traveller"
	pivot.position = START
	pivot.rotation.y = PI
	add_child(pivot)
	character = CharacterRig.new()
	character.auto_idle = false
	pivot.add_child(character)
	await get_tree().process_frame
	# Its lamp lit in its hand.
	var att: Node = character.attachments.get("hand_l")
	if att != null and att.get_child_count() > 0:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.4)
		l.light_energy = 1.6
		l.omni_range = 5.0
		l.position = Vector3(0, 0.15, 0)
		(att.get_child(0) as Node3D).add_child(l)


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := UiKit.label("3D 試作：夜釣湖畔", 18, UiKit.GOLD_BRIGHT, true, 3)
	title.position = Vector2(16, 12)
	layer.add_child(title)
	var hint := UiKit.label("左搖桿／WASD 移動：輕推走路、推到底奔跑", 13, UiKit.DIM, false, 2)
	hint.position = Vector2(16, 40)
	layer.add_child(hint)
	var back := UiKit.button("返回營地", 16, "red")
	back.position = Vector2(820, 12)
	back.custom_minimum_size = Vector2(124, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file(Camp3D.SCENE))
	layer.add_child(back)
	var stick: Control = load("res://addons/virtual_joystick/virtual_joystick_scene.tscn").instantiate()
	stick.name = "MoveJoystick"
	stick.set("use_input_actions", false)
	# (where the thumb comes down; its rings shown only while it's held)
	stick.set("joystick_mode", 1)
	stick.set("visibility_mode", 2)
	layer.add_child(stick)
	stick.position = Vector2(40, 300)
	_joystick = stick


func _input_dir() -> Vector2:
	var v := Vector2.ZERO
	if _joystick != null and _joystick.get("output") != null:
		v = _joystick.output
	if v.length() < 0.05:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v.y += 1.0
		# (a shift held: walking, from the keyboard)
		v = v.normalized() * (0.35 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	return v.limit_length(1.0)


func _process(delta: float) -> void:
	_time += delta
	if character == null or character.anim == null:
		return
	var stick := _input_dir()
	var move := Vector3(stick.x, 0, stick.y) * RUN_SPEED
	var held := _held_clip()
	var speed := move.length()
	if speed > 0.05:
		var to := pivot.position + move * delta
		for b in blockers:
			var off: Vector3 = to - b[0]
			off.y = 0.0
			var r: float = b[1] + 0.3
			if off.length() < r:
				to = b[0] + off.normalized() * r
		# (not into the lake)
		if to.z < _shore_z(to.x) + 0.4 and not _on_dock(to):
			to.z = maxf(to.z, _shore_z(to.x) + 0.4)
		to.y = 0.32 if _on_dock(to) else maxf(_height(to.x, to.z), 0.0)
		pivot.position = to
		pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(move.x, move.z), minf(1.0, delta * TURN_RATE))
	var anim := character.anim
	var clip := "Idle"
	var rate := 1.0
	if held != "":
		# (an act of the 3D camp's own - camp3d.gd)
		if anim.current_animation != held and anim.has_animation(held):
			anim.play(held, 0.25)
		anim.speed_scale = 1.0
	elif speed > 0.05:
		if speed <= WALK_MAX or not anim.has_animation("Run"):
			clip = "Walk"
			rate = speed / WALK_PACE
		else:
			clip = "Run"
			rate = speed / RUN_PACE
	if held == "":
		if anim.current_animation != clip and anim.has_animation(clip):
			anim.play(clip, 0.2)
		anim.speed_scale = clampf(rate, 0.4, 2.2) if clip != "Idle" else 1.0
	# The camera after it, eased.
	var want := _camera_at(pivot.position)
	camera.global_transform = camera.global_transform.interpolate_with(want, minf(1.0, delta * CAMERA_EASE))
	# The fire and the lanterns flicker; the runes breathe.
	if _fire_light != null:
		_fire_light.light_energy = 2.6 + 0.35 * sin(_time * 9.0) + 0.2 * sin(_time * 23.0)
	for i in _lanterns.size():
		(_lanterns[i] as OmniLight3D).light_energy = 1.5 + 0.08 * sin(_time * 7.0 + i)
	if _stone_mat != null:
		_stone_mat.emission_energy_multiplier = 0.9 + 0.35 * sin(_time * 1.3)


## A clip the traveller's held in, whatever the stick says ("": none).
func _held_clip() -> String:
	return ""


func _on_dock(p: Vector3) -> bool:
	return absf(p.x - 2.4) < 0.65 and p.z > float(_dock_span[0]) and p.z < float(_dock_span[1])


## Up and behind the traveller, looking down at CAMERA_PITCH.
func _camera_at(target: Vector3) -> Transform3D:
	var pitch := deg_to_rad(CAMERA_PITCH)
	var look := target + Vector3(0, 0.8, 0)
	var at := look + Vector3(0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE
	return Transform3D(Basis.looking_at(look - at, Vector3.UP), at)


const GROUND_SHADER := """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec4 paint;
void vertex() { paint = COLOR; }
void fragment() {
	vec2 uv = UV * 0.25;
	vec3 c = mix(texture(grass_tex, uv).rgb, texture(forest_tex, uv * 0.9).rgb, paint.a);
	vec3 n = mix(texture(grass_nrm, uv).rgb, texture(forest_nrm, uv * 0.9).rgb, paint.a);
	c = mix(c, texture(mud_tex, uv).rgb * 0.8, paint.b);
	n = mix(n, texture(mud_nrm, uv).rgb, paint.b);
	c = mix(c, texture(path_tex, uv * 1.2).rgb, paint.r);
	n = mix(n, texture(path_nrm, uv * 1.2).rgb, paint.r);
	c = mix(c, texture(stone_tex, uv * 0.8).rgb * 0.6, paint.g);
	n = mix(n, texture(stone_nrm, uv * 0.8).rgb, paint.g);
	ALBEDO = c * 0.85;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = 0.92;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D wave_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.012, 0.03, 0.05);
uniform vec3 shallow : source_color = vec3(0.04, 0.085, 0.11);
uniform vec3 moon_dir = vec3(0.25, 0.22, -1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.08;
	vec3 a = texture(wave_tex, uv + vec2(TIME * 0.012, TIME * 0.006)).rgb;
	vec3 b = texture(wave_tex, uv * 1.7 - vec2(TIME * 0.009, -TIME * 0.011)).rgb;
	vec3 nm = normalize(mix(a, b, 0.5));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.55;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep, shallow, fres);
	vec3 wn = normalize(vec3((nm.x - 0.5) * 0.9, 1.0, (nm.y - 0.5) * 0.9));
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	vec3 r = reflect(-VIEW, vn);
	vec3 m = normalize((VIEW_MATRIX * vec4(normalize(moon_dir), 0.0)).xyz);
	float g = pow(max(dot(r, m), 0.0), 90.0);
	EMISSION = vec3(0.65, 0.72, 0.85) * g * 0.7;
	ROUGHNESS = 0.22;
	SPECULAR = 0.35;
}
"""
