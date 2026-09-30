class_name CampStage
extends Node3D

## The main screen's 3D camp (user request: out of the game, show as much
## as can be in 3D, like an MMO's character-select camp): a clearing by a
## lake at night - a campfire, a tent, the merchant's stall, the storage
## chest, the fish tank on its table, a dock into the water, dark pines all
## round, the moon over the far shore - and the player's character by the
## fire. Everything is built here from simple shapes, lit by the fire and
## the moon (few lights, no shadows - light and shade are in the colours,
## as a hand-painted game does it; cheap on a phone).
##
## Each menu page has a spot in the camp (STATIONS); go_to() glides the
## camera there when the page opens. A ghost drifts between the trees now
## and then.

const STATIONS := {
	"home": [Vector3(0.45, 1.85, 5.9), Vector3(-0.25, 0.85, -1.3), 40.0],
	"equipment": [Vector3(-0.55, 1.25, 2.6), Vector3(-0.95, 1.0, 0.3), 36.0],
	"warehouse": [Vector3(-0.6, 1.5, 3.0), Vector3(-2.2, 0.5, 0.8), 40.0],
	"shop": [Vector3(1.2, 1.55, 2.6), Vector3(2.6, 1.0, -1.4), 40.0],
	"fish_tank": [Vector3(0.6, 1.5, 0.9), Vector3(1.55, 0.95, -2.2), 38.0],
	"fish_log": [Vector3(0.6, 1.5, 0.9), Vector3(1.55, 0.95, -2.2), 38.0],
}
const CHARACTER_AT := Vector3(-0.95, 0.0, 0.35)
const FIRE_AT := Vector3(0.15, 0.0, -0.1)
const LAKE_CENTER := Vector3(0.0, 0.0, -17.0)
const LAKE_RADIUS := 13.5
const MOON_DIR := Vector3(0.1, 0.17, -1.0)
const BIG_GHOST := preload("res://assets/sprites/big_ghost/big_ghost_55deg_albedo.png")

var camera: Camera3D
var character: CharacterRig
var character_pivot: Node3D
var _fire_light: OmniLight3D
var _fire_glow: MeshInstance3D
var _ghost: Sprite3D
var _ghost_timer := 8.0
var _ghost_life := 0.0
var _time := 0.0
var _cam_tween: Tween
var _fish: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	_environment()
	_ground()
	_lake()
	_forest()
	_rocks()
	_tent()
	_fire()
	_stall()
	_chest()
	_tank()
	_dock()
	_character()
	_ghost_sprite()
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	go_to("home", false)


# ---------------------------------------------------------------- camera

## Glides the camera to a station ("home", "shop", ...); `done` is called
## once it's there.
func go_to(station: String, animate := true, done := Callable()) -> void:
	var spot: Array = STATIONS.get(station, STATIONS.home)
	var to := Transform3D(Basis.IDENTITY, spot[0]).looking_at(spot[1], Vector3.UP)
	if _cam_tween != null:
		_cam_tween.kill()
	if not animate or not is_inside_tree():
		camera.transform = to
		camera.fov = spot[2]
		if done.is_valid():
			done.call()
		return
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(camera, "transform", to, 0.7)
	_cam_tween.tween_property(camera, "fov", spot[2], 0.7)
	if done.is_valid():
		_cam_tween.chain().tween_callback(done)


## Turns the character by `amount` (radians), as a drag on it does.
func turn_character(amount: float) -> void:
	character_pivot.rotation.y += amount


func _process(delta: float) -> void:
	_time += delta
	# The fire breathes: its light flickers, its glow swells.
	var flick := 0.85 + 0.1 * sin(_time * 7.3) + 0.06 * sin(_time * 13.1 + 1.3) + 0.04 * sin(_time * 23.0)
	_fire_light.light_energy = 3.2 * flick
	_fire_glow.scale = Vector3.ONE * (0.95 + 0.08 * flick)
	# The character eases back to facing the camera between drags.
	character_pivot.rotation.y = lerpf(character_pivot.rotation.y, 0.35, minf(1.0, delta * 0.8))
	_swim(delta)
	_haunt(delta)


# ---------------------------------------------------------------- world

func _environment() -> void:
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.012, 0.018, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.09, 0.14);
uniform vec3 moon_dir = vec3(0.25, 0.22, -1.0);
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.45));
	vec3 cell = floor(EYEDIR * 140.0);
	float star = step(0.9975, hash(cell)) * smoothstep(0.02, 0.25, EYEDIR.y);
	col += vec3(0.8, 0.85, 1.0) * star * 0.8;
	float m = max(dot(normalize(EYEDIR), normalize(moon_dir)), 0.0);
	col += vec3(0.85, 0.88, 0.8) * smoothstep(0.9993, 0.9996, m) * 1.4;
	col += vec3(0.25, 0.32, 0.45) * pow(m, 60.0) * 0.5 + vec3(0.1, 0.13, 0.2) * pow(m, 8.0) * 0.35;
	COLOR = col;
}
"""
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky_mat.set_shader_parameter("moon_dir", MOON_DIR)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.13, 0.16, 0.26)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.14)
	env.fog_density = 0.028
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The moon, low over the far shore: a cold light from behind.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.55
	moon.transform = Transform3D.IDENTITY.looking_at(-MOON_DIR, Vector3.UP)
	add_child(moon)


static func _noise_tex(size: int, freq: float, seed_value: int, normal := false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	return t


func _ground() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 fire_at = vec3(0.15, 0.0, -0.1);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.05).r;
	float n2 = texture(noise_tex, wpos.xz * 0.23 + vec2(0.37, 0.11)).r;
	vec3 grass = mix(vec3(0.035, 0.055, 0.035), vec3(0.075, 0.095, 0.05), n);
	vec3 dirt = mix(vec3(0.11, 0.085, 0.06), vec3(0.19, 0.14, 0.09), n2);
	float d = length(wpos.xz - fire_at.xz);
	float trodden = smoothstep(3.4, 1.4, d + (n - 0.5) * 1.6);
	// A worn path to the dock.
	float path = smoothstep(0.75, 0.25, abs(wpos.x - 1.9 + sin(wpos.z * 0.7) * 0.25)) * step(wpos.z, 0.6) * step(-4.5, wpos.z);
	trodden = max(trodden, path * 0.8);
	ALBEDO = mix(grass, dirt, trodden) * (0.8 + n2 * 0.4);
	ROUGHNESS = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("noise_tex", _noise_tex(256, 0.02, 3))
	mat.set_shader_parameter("fire_at", FIRE_AT)
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)


func _lake() -> void:
	var sh := Shader.new()
	sh.code = """
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
	// The moon's path glittering on the ripples.
	vec3 wn = normalize(vec3((nm.x - 0.5) * 0.9, 1.0, (nm.y - 0.5) * 0.9));
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	vec3 r = reflect(-VIEW, vn);
	vec3 m = normalize((VIEW_MATRIX * vec4(normalize(moon_dir), 0.0)).xyz);
	float g = pow(max(dot(r, m), 0.0), 90.0);
	EMISSION = vec3(0.65, 0.72, 0.85) * g * 1.6;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	METALLIC = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("wave_tex", _noise_tex(256, 0.04, 17, true))
	mat.set_shader_parameter("moon_dir", MOON_DIR)
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_RADIUS
	disc.bottom_radius = LAKE_RADIUS
	disc.height = 0.02
	disc.radial_segments = 48
	disc.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = mat
	mi.position = LAKE_CENTER + Vector3(0, 0.02, 0)
	mi.scale = Vector3(1.9, 1.0, 1.0)
	add_child(mi)
	# A dark muddy shore round it.
	var shore := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = LAKE_RADIUS + 0.9
	ring.bottom_radius = LAKE_RADIUS + 0.9
	ring.height = 0.01
	ring.radial_segments = 48
	shore.mesh = ring
	shore.material_override = _mat(Color(0.05, 0.045, 0.035), 1.0)
	shore.position = LAKE_CENTER + Vector3(0, 0.006, 0)
	shore.scale = Vector3(1.9, 1.0, 1.0)
	add_child(shore)


## Where the lake is (its ellipse, a little way in from its shore).
func _in_lake(p: Vector3, margin := 0.0) -> bool:
	var d := Vector2((p.x - LAKE_CENTER.x) / 1.9, p.z - LAKE_CENTER.z)
	return d.length() < LAKE_RADIUS + margin


static func _mat(color: Color, rough := 0.9, emit := Color.BLACK, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
	return m


## A conifer: a trunk and three stacked cones (two surfaces: bark, needles).
static func _pine_mesh() -> ArrayMesh:
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.14
	trunk.height = 1.2
	trunk.radial_segments = 6
	bark.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
	var needles := SurfaceTool.new()
	needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := [[1.25, 1.7, 1.2], [1.0, 1.5, 2.1], [0.72, 1.3, 2.9], [0.42, 1.0, 3.6]]
	for l in layers:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = l[0]
		cone.height = l[1]
		cone.radial_segments = 7
		cone.rings = 1
		needles.append_from(cone, 0, Transform3D(Basis.IDENTITY, Vector3(0, l[2], 0)))
	var mesh := bark.commit()
	needles.commit(mesh)
	mesh.surface_set_material(0, _mat(Color(0.09, 0.065, 0.045)))
	mesh.surface_set_material(1, _mat(Color(0.03, 0.07, 0.05)))
	return mesh


## A dead tree: a bare trunk and a few crooked branches.
static func _dead_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.05
	trunk.bottom_radius = 0.16
	trunk.height = 3.2
	trunk.radial_segments = 6
	st.append_from(trunk, 0, Transform3D(Basis(Vector3.FORWARD, 0.08), Vector3(0, 1.6, 0)))
	var branches := [[2.2, 0.9, 1.0], [2.6, -1.1, 0.8], [1.6, 2.4, 0.9], [2.9, 0.4, 0.6]]
	for b in branches:
		var br := CylinderMesh.new()
		br.top_radius = 0.02
		br.bottom_radius = 0.06
		br.height = b[2]
		br.radial_segments = 5
		var basis := Basis(Vector3.UP, b[1]) * Basis(Vector3.RIGHT, 0.9)
		st.append_from(br, 0, Transform3D(basis, Vector3(0, b[0], 0) + basis.y * b[2] * 0.5))
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(Color(0.12, 0.1, 0.085)))
	return mesh


func _forest() -> void:
	var pines := []
	for i in 140:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(8.5, 26.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if _in_lake(p, 1.5):
			continue
		if p.z > 3.0 and absf(p.x) < 7.0:
			continue  # keep the view from the camera clear
		pines.append(p)
	# The far shore: a dark line of pines against the sky.
	for i in 70:
		var x := _rng.randf_range(-34.0, 34.0)
		var z := LAKE_CENTER.z - LAKE_RADIUS - _rng.randf_range(0.5, 7.0)
		pines.append(Vector3(x, 0, z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _pine_mesh()
	mm.instance_count = pines.size()
	for i in pines.size():
		var s := _rng.randf_range(0.9, 1.9)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.25), s))
		mm.set_instance_transform(i, Transform3D(basis, pines[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	# A few dead trees by the water, where the ghost walks.
	var dead := MultiMesh.new()
	dead.transform_format = MultiMesh.TRANSFORM_3D
	dead.mesh = _dead_mesh()
	var spots := [Vector3(-5.8, 0, -3.6), Vector3(-7.4, 0, -1.8), Vector3(6.4, 0, -3.2), Vector3(-9.5, 0, -5.0), Vector3(8.8, 0, -1.0)]
	dead.instance_count = spots.size()
	for i in spots.size():
		var s := _rng.randf_range(0.9, 1.3)
		dead.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), spots[i]))
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dead
	add_child(dmi)


## A faceted rock (its faces flat-shaded).
static func _rock_mesh(seed_value: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.8
	sphere.radial_segments = 7
	sphere.rings = 4
	var st := SurfaceTool.new()
	st.create_from(sphere, 0)
	st.deindex()
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bumps := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.01)
		if not bumps.has(key):
			bumps[key] = rng.randf_range(0.8, 1.15)
		verts[i] = verts[i] * bumps[key]
		verts[i].y = maxf(verts[i].y, -0.1)
	var out := SurfaceTool.new()
	out.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		out.add_vertex(v)
	out.generate_normals()
	var mesh := out.commit()
	mesh.surface_set_material(0, _mat(Color(0.16, 0.16, 0.17)))
	return mesh


func _rocks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _rock_mesh(5)
	var spots := []
	# Along the near shore, and scattered.
	for i in 26:
		var a := lerpf(0.15, PI - 0.15, float(i) / 25.0)
		var p := LAKE_CENTER + Vector3(-cos(a) * (LAKE_RADIUS + 0.3) * 1.9, 0, sin(a) * (LAKE_RADIUS + 0.3))
		if absf(p.x - 2.1) < 1.2:
			continue  # the dock
		spots.append(p + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.2, 0.5)))
	for i in 14:
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.5, 9.0)
		if not _in_lake(p, 1.0) and not (p.z > 2.0 and absf(p.x) < 4.0):
			spots.append(p)
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := _rng.randf_range(0.4, 1.3)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.5, 0.9), s))
		mm.set_instance_transform(i, Transform3D(basis, spots[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


# ---------------------------------------------------------------- camp

func _tent() -> void:
	var tent := Node3D.new()
	tent.position = Vector3(-3.1, 0, -2.3)
	tent.rotation.y = 0.45
	add_child(tent)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 1.3
	var h := 1.55
	var d := 1.4
	var a := Vector3(-w, 0, -d)
	var b := Vector3(w, 0, -d)
	var c := Vector3(0, h, -d)
	var a2 := Vector3(-w, 0, d)
	var b2 := Vector3(w, 0, d)
	var c2 := Vector3(0, h, d)
	for tri in [[a, c, c2], [a, c2, a2], [b, b2, c2], [b, c2, c], [a, b, c]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(Color(0.34, 0.29, 0.21)))
	var body := MeshInstance3D.new()
	body.mesh = mesh
	tent.add_child(body)
	# The open front: a dark doorway.
	var door := SurfaceTool.new()
	door.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.55, 0, d + 0.01), Vector3(0, h * 0.8, d + 0.01), Vector3(0.55, 0, d + 0.01)]:
		door.add_vertex(v)
	door.generate_normals()
	var dm := MeshInstance3D.new()
	dm.mesh = door.commit()
	dm.material_override = _mat(Color(0.015, 0.012, 0.01))
	tent.add_child(dm)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.025
	pm.height = 1.9
	pole.mesh = pm
	pole.material_override = _mat(Color(0.2, 0.14, 0.08))
	pole.position = Vector3(0, 0.95, d + 0.05)
	tent.add_child(pole)


func _fire() -> void:
	var fire := Node3D.new()
	fire.position = FIRE_AT
	add_child(fire)
	# Stones in a ring.
	var stone := _rock_mesh(9)
	for i in 10:
		var a := TAU * i / 10.0
		var s := MeshInstance3D.new()
		s.mesh = stone
		s.scale = Vector3(0.28, 0.2, 0.28) * _rng.randf_range(0.8, 1.2)
		s.position = Vector3(cos(a), 0, sin(a)) * 0.5
		s.rotation.y = _rng.randf() * TAU
		fire.add_child(s)
	# Logs, crossed.
	var wood := _mat(Color(0.16, 0.1, 0.06))
	for i in 4:
		var log := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.07
		cm.height = 0.75
		cm.radial_segments = 6
		log.mesh = cm
		log.material_override = wood
		log.rotation = Vector3(deg_to_rad(70), TAU * i / 4.0 + 0.3, 0)
		log.position = Vector3(0, 0.12, 0)
		fire.add_child(log)
	# Seats: two logs lying by the fire.
	for spot in [[Vector3(-1.5, 0.12, -0.6), 0.6], [Vector3(1.4, 0.12, 0.7), -0.4]]:
		var seat := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.14
		cm.bottom_radius = 0.15
		cm.height = 1.3
		cm.radial_segments = 8
		seat.mesh = cm
		seat.material_override = _mat(Color(0.2, 0.14, 0.09))
		seat.rotation = Vector3(0, spot[1], deg_to_rad(90))
		seat.position = spot[0] - FIRE_AT
		fire.add_child(seat)
	# The flames: additive billboards rising and fading.
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.albedo_texture = UiKit.glow()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	quad.material = flame_mat
	var flames := CPUParticles3D.new()
	flames.mesh = quad
	flames.amount = 20
	flames.lifetime = 0.9
	flames.preprocess = 1.0
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.18
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 1.2, 0)
	flames.initial_velocity_min = 0.3
	flames.initial_velocity_max = 0.7
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2
	var fcurve := Curve.new()
	fcurve.add_point(Vector2(0, 0.7))
	fcurve.add_point(Vector2(0.3, 1.0))
	fcurve.add_point(Vector2(1, 0.2))
	flames.scale_amount_curve = fcurve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	ramp.set_color(1, Color(0.8, 0.1, 0.02, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.45, 0.1, 0.75))
	flames.color_ramp = ramp
	flames.position = Vector3(0, 0.2, 0)
	fire.add_child(flames)
	# Embers drifting up.
	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(0.05, 0.05)
	ember_quad.material = flame_mat
	var embers := CPUParticles3D.new()
	embers.mesh = ember_quad
	embers.amount = 14
	embers.lifetime = 2.6
	embers.preprocess = 2.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.25
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0.15, 0.4, 0)
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 0.9
	var eramp := Gradient.new()
	eramp.set_color(0, Color(1.0, 0.7, 0.3, 1.0))
	eramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	embers.color_ramp = eramp
	embers.position = Vector3(0, 0.4, 0)
	fire.add_child(embers)
	# A soft glow round it, and the light it throws.
	_fire_glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(2.6, 2.6)
	var gmat := flame_mat.duplicate() as StandardMaterial3D
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gmat.vertex_color_use_as_albedo = false
	gmat.albedo_color = Color(1.0, 0.45, 0.12, 0.22)
	gq.material = gmat
	_fire_glow.mesh = gq
	_fire_glow.position = Vector3(0, 0.45, 0)
	fire.add_child(_fire_glow)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.56, 0.24)
	_fire_light.light_energy = 3.2
	_fire_light.omni_range = 8.0
	_fire_light.omni_attenuation = 1.4
	_fire_light.position = Vector3(0, 0.7, 0)
	fire.add_child(_fire_light)


## The merchant's stall (the shop): posts, a counter, a red awning, rods on
## a rack, a lantern; a hooded merchant behind it with two faint eyes.
func _stall() -> void:
	var stall := Node3D.new()
	stall.position = Vector3(2.9, 0, -1.9)
	stall.rotation.y = -0.55
	add_child(stall)
	var wood := _mat(Color(0.2, 0.13, 0.08))
	for x in [-1.0, 1.0]:
		for z in [-0.45, 0.45]:
			var post := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.09, 2.2 if z < 0 else 1.9, 0.09)
			post.mesh = bm
			post.material_override = wood
			post.position = Vector3(x, bm.size.y * 0.5, z)
			stall.add_child(post)
	var counter := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.1, 0.85, 0.6)
	counter.mesh = cm
	counter.material_override = _mat(Color(0.24, 0.16, 0.1))
	counter.position = Vector3(0, 0.43, 0.3)
	stall.add_child(counter)
	var awning := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(2.4, 0.05, 1.35)
	awning.mesh = am
	awning.material_override = _mat(Color(0.34, 0.05, 0.04))
	awning.position = Vector3(0, 2.05, 0.05)
	awning.rotation.x = -0.25
	stall.add_child(awning)
	for i in 4:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.18, 0.055, 1.36)
		stripe.mesh = sm
		stripe.material_override = _mat(Color(0.55, 0.45, 0.25))
		stripe.position = Vector3(-0.9 + i * 0.6, 2.06, 0.05)
		stripe.rotation.x = -0.25
		stall.add_child(stripe)
	# Rods leaning on the stall's side.
	for i in 3:
		var rod: Node3D = CharacterRig.RODS[i + 2].instantiate()
		rod.scale = Vector3.ONE * 0.19
		rod.rotation = Vector3(-0.28, 0.0, 0.1 - i * 0.08)
		rod.position = Vector3(1.2 + i * 0.12, 0.0, 0.62)
		stall.add_child(rod)
	# The lantern hanging at the front corner.
	var lamp: Node3D = CharacterRig.LAMP.instantiate()
	lamp.scale = Vector3.ONE * 1.3
	lamp.position = Vector3(-0.95, 1.45, 0.62)
	stall.add_child(lamp)
	var lamp_light := OmniLight3D.new()
	lamp_light.light_color = Color(1.0, 0.7, 0.35)
	lamp_light.light_energy = 1.4
	lamp_light.omni_range = 3.5
	lamp_light.position = Vector3(-0.95, 1.6, 0.8)
	stall.add_child(lamp_light)
	# The merchant: a dark hooded figure, two faint eyes.
	var robe := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.16
	rm.bottom_radius = 0.38
	rm.height = 1.35
	rm.radial_segments = 10
	robe.mesh = rm
	robe.material_override = _mat(Color(0.07, 0.06, 0.07))
	robe.position = Vector3(0.1, 0.68, -0.3)
	stall.add_child(robe)
	var hood := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.22
	hm.height = 0.5
	hood.mesh = hm
	hood.material_override = _mat(Color(0.08, 0.07, 0.08))
	hood.position = Vector3(0.1, 1.5, -0.3)
	stall.add_child(hood)
	var eye_mat := _mat(Color(0.9, 0.85, 0.5), 1.0, Color(1.0, 0.85, 0.4))
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x in [-0.055, 0.055]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.018
		em.height = 0.036
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(0.1 + x, 1.5, -0.1)
		stall.add_child(eye)


## The storage chest (the warehouse): wood with gold bands, crates by it.
func _chest() -> void:
	var chest := Node3D.new()
	chest.position = Vector3(-2.25, 0, 0.75)
	chest.rotation.y = 0.5
	add_child(chest)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.95, 0.5, 0.58)
	body.mesh = bm
	body.material_override = _mat(Color(0.26, 0.15, 0.08))
	body.position = Vector3(0, 0.25, 0)
	chest.add_child(body)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.29
	lm.bottom_radius = 0.29
	lm.height = 0.95
	lm.radial_segments = 12
	lid.mesh = lm
	lid.material_override = _mat(Color(0.3, 0.17, 0.09))
	lid.rotation.z = deg_to_rad(90)
	lid.scale = Vector3(1, 1, 0.55)
	lid.position = Vector3(0, 0.5, 0)
	chest.add_child(lid)
	var gold := _mat(Color(0.75, 0.55, 0.2), 0.35, Color.BLACK, 0.8)
	for x in [-0.36, 0.0, 0.36]:
		var band := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.06, 0.52, 0.6)
		band.mesh = gm
		band.material_override = gold
		band.position = Vector3(x, 0.26, 0)
		chest.add_child(band)
	var lock := MeshInstance3D.new()
	var lk := BoxMesh.new()
	lk.size = Vector3(0.12, 0.14, 0.04)
	lock.mesh = lk
	lock.material_override = gold
	lock.position = Vector3(0, 0.42, 0.3)
	chest.add_child(lock)
	var crate_mat := _mat(Color(0.22, 0.16, 0.1))
	for spot in [[Vector3(-0.95, 0.3, -0.35), 0.6], [Vector3(-1.05, 0.9, -0.3), 0.5], [Vector3(-0.35, 0.22, -0.75), 0.45]]:
		var crate := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3.ONE * spot[1]
		crate.mesh = cm
		crate.material_override = crate_mat
		crate.position = spot[0]
		crate.rotation.y = _rng.randf_range(-0.4, 0.4)
		chest.add_child(crate)


## The fish tank on its table (the fish tank page), the player's fish in it
## (their pictures, swimming to and fro behind the glass).
func _tank() -> void:
	var table := Node3D.new()
	table.position = Vector3(1.55, 0, -2.25)
	table.rotation.y = -0.35
	add_child(table)
	var wood := _mat(Color(0.19, 0.12, 0.07))
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.3, 0.06, 0.7)
	top.mesh = tm
	top.material_override = wood
	top.position = Vector3(0, 0.72, 0)
	table.add_child(top)
	for x in [-0.58, 0.58]:
		for z in [-0.28, 0.28]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.06, 0.72, 0.06)
			leg.mesh = lm
			leg.material_override = wood
			leg.position = Vector3(x, 0.36, z)
			table.add_child(leg)
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(1.06, 0.48, 0.46)
	water.mesh = wm
	var wmat := _mat(Color(0.1, 0.3, 0.36, 0.45), 0.1, Color(0.02, 0.07, 0.08))
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wmat
	water.position = Vector3(0, 1.0, 0)
	table.add_child(water)
	var sand := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.06, 0.06, 0.46)
	sand.mesh = sm
	sand.material_override = _mat(Color(0.4, 0.34, 0.24))
	sand.position = Vector3(0, 0.79, 0)
	table.add_child(sand)
	var frame := _mat(Color(0.1, 0.08, 0.06), 0.5)
	for y in [0.76, 1.26]:
		var rim := MeshInstance3D.new()
		var rmsh := BoxMesh.new()
		rmsh.size = Vector3(1.12, 0.04, 0.5)
		rim.mesh = rmsh
		rim.material_override = frame
		rim.position = Vector3(0, y, 0)
		table.add_child(rim)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.8, 0.9)
	glow.light_energy = 0.5
	glow.omni_range = 1.6
	glow.position = Vector3(0, 1.1, 0.4)
	table.add_child(glow)
	var holder := Node3D.new()
	holder.position = Vector3(0, 1.0, 0.0)
	table.add_child(holder)
	# The player's fish (the first six), as their 3D models (FishModel) -
	# or their pictures where a species has none.
	var shown := Profile.tank.slice(0, 6)
	for i in shown.size():
		var f: Dictionary = shown[i]
		var cm := float(f.get("length", 30.0))
		var long := lerpf(0.09, 0.26, clampf(log(maxf(cm, 1.0) / 5.0) / log(60.0), 0.0, 1.0))
		var body: Node3D = FishModel.make(f.get("id", ""))
		if body != null:
			body.scale = Vector3.ONE * long / 1.15
		else:
			var tex := FishData.icon(f.get("id", ""), f.get("name", ""))
			if tex == null:
				continue
			var sprite := Sprite3D.new()
			sprite.texture = tex
			sprite.pixel_size = long / maxf(tex.get_width(), 1.0)
			sprite.shaded = false
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			body = sprite
		var at := Vector3(_rng.randf_range(-0.33, 0.33), _rng.randf_range(-0.13, 0.12), _rng.randf_range(-0.1, 0.1))
		body.position = at
		holder.add_child(body)
		_fish.append([body, _rng.randf_range(0.08, 0.18), _rng.randf() * TAU, at])


## The tank's fish swim back and forth along it, turning at the ends.
func _swim(delta: float) -> void:
	for f in _fish:
		var body: Node3D = f[0]
		f[2] += delta * f[1] * 4.0
		var x := sin(f[2]) * 0.34
		var heading := cos(f[2])
		body.position = Vector3(x, f[3].y + sin(f[2] * 2.3) * 0.03, f[3].z)
		if body is Sprite3D:
			(body as Sprite3D).flip_h = heading < 0.0
		else:
			# Facing its way along the tank (+x or -x), turning through the
			# glass's depth at the ends.
			body.rotation.y = lerpf(0.0, PI, smoothstep(0.25, -0.25, heading))
			FishModel.swim(body as MeshInstance3D, delta, absf(heading) * 0.6 + 0.2)


## A dock into the lake, planks on posts.
func _dock() -> void:
	var dock := Node3D.new()
	dock.position = Vector3(2.1, 0, -3.3)
	add_child(dock)
	var wood := _mat(Color(0.17, 0.12, 0.08))
	for i in 16:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.25, 0.05, 0.28)
		plank.mesh = pm
		plank.material_override = wood
		plank.position = Vector3(_rng.randf_range(-0.03, 0.03), 0.2, -i * 0.32)
		plank.rotation.y = _rng.randf_range(-0.03, 0.03)
		dock.add_child(plank)
	for i in 4:
		for x in [-0.6, 0.6]:
			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.06
			cm.height = 0.8
			cm.radial_segments = 6
			post.mesh = cm
			post.material_override = wood
			post.position = Vector3(x, 0.05, -i * 1.6)
			dock.add_child(post)


func _character() -> void:
	character_pivot = Node3D.new()
	character_pivot.position = CHARACTER_AT
	character_pivot.rotation.y = 0.35
	add_child(character_pivot)
	character = CharacterRig.new()
	character_pivot.add_child(character)
	# A soft dark blob under the feet.
	var blob := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_texture = UiKit.glow()
	bm.albedo_color = Color(0, 0, 0, 0.6)
	blob.material_override = bm
	blob.position = CHARACTER_AT + Vector3(0, 0.01, 0)
	add_child(blob)


## Now and then the big ghost shows between the trees across the clearing,
## hangs there a moment, and is gone.
func _ghost_sprite() -> void:
	_ghost = Sprite3D.new()
	_ghost.texture = BIG_GHOST
	_ghost.region_enabled = true
	_ghost.region_rect = Rect2(0, 0, 240, 256)
	_ghost.pixel_size = 0.009
	_ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_ghost.shaded = false
	_ghost.modulate = Color(0.55, 0.62, 0.7, 0.0)
	_ghost.visible = false
	add_child(_ghost)


func _haunt(delta: float) -> void:
	if _ghost_life > 0.0:
		_ghost_life -= delta
		var t := 1.0 - _ghost_life / 6.0
		_ghost.modulate.a = sin(t * PI) * 0.45
		_ghost.position.x += delta * 0.25
		if _ghost_life <= 0.0:
			_ghost.visible = false
			_ghost_timer = _rng.randf_range(14.0, 26.0)
		return
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		_ghost.position = Vector3(side * _rng.randf_range(6.5, 9.5), 1.15, _rng.randf_range(-5.5, -2.5))
		_ghost.visible = true
		_ghost_life = 6.0
