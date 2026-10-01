class_name Aquarium
extends Control

## The fish tank page's tank in 3D (user request, Camp v2: no glass tank in
## the wild - an oil drum lying on its side, its top half cut away, filled
## with water, and the fish seen from above). The camp's own drum
## (CampModel "drum_trough"), a bed of silt in its curved bottom with light
## rippling over it, a few stones, lotus leaves floating on the surface,
## the night round it lit by the fire - and the fish of
## Profile.tank as 3D models (FishModel) swimming by their trait, as the
## 2D tank (FishTank.TankView, still used when the 3D camp is off) has
## them: schooling ones keep together, fierce ones go for the others now
## and then, bottom dwellers keep low (flatfish lie on the silt), shy ones
## under the leaves, lazy ones barely move, jumpers leap out and splash,
## gluttons get to the food first. Tap a fish for its card (`picked`).
## Drawn at 1.5x in a SubViewport shown through a TextureRect.

signal picked(index: int)

const RENDER_SCALE := 1.5
## The drum: the camp's model made LENGTH long along x, lying on its side
## (its axis at AXIS_Y, inside RADIUS round it); the water's surface at
## SURFACE, a little under the cut rim.
const LENGTH := 2.0
const DRUM_SCALE := LENGTH / 0.92
const AXIS_Y := 0.287 * DRUM_SCALE
const RADIUS := 0.27 * DRUM_SCALE
const SURFACE := 0.71
const WIDTH := LENGTH
const DEPTH := 2.0 * RADIUS
## Where the fish may go (their middles).
const SWIM := AABB(Vector3(-0.8, 0.14, -0.4), Vector3(1.6, 0.5, 0.8))
const WATER_COLOR := Color(0.03, 0.11, 0.1)
## Stones the fish keep out of: [centre, radius, seed].
const ROCKS := [
	[Vector3(-0.68, 0.1, -0.14), 0.14, 3],
	[Vector3(-0.52, 0.1, 0.12), 0.09, 8],
	[Vector3(0.62, 0.1, 0.1), 0.12, 12],
]
## Lotus leaves on the surface (user request: the leaves only, no weed
## below): [x, z, radius].
const PADS := [[-0.55, 0.28, 0.19], [-0.3, 0.4, 0.12], [0.76, -0.3, 0.17]]
const SPEEDS := {"lazy": 0.05, "active": 0.19, "school": 0.16, "fierce": 0.175, "bottom": 0.09, "shy": 0.1,
	"jumper": 0.17, "glutton": 0.14}

var camera: Camera3D
var _viewport: SubViewport
var _world: Node3D
var _fish_root: Node3D
var _swimmers: Array = []
var _food: Array = []  # [MeshInstance3D, resting time]
var _splashes: Array = []  # [MeshInstance3D, age]
var _time := 0.0
var _glowing: Swimmer = null
var _floating: Array = []  # the lily pads


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_environment()
	_drum()
	_sand()
	_rocks()
	_surface()
	_pads()
	_fish_root = Node3D.new()
	_world.add_child(_fish_root)
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.near = 0.05
	camera.far = 20.0
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, 3.35, 1.05)).looking_at(Vector3(0, 0.4, 0.02), Vector3.UP)
	_world.add_child(camera)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	_viewport.size = Vector2i((size * RENDER_SCALE).max(Vector2(8, 8)))


# ---------------------------------------------------------------- the fish

## The fish in Profile.tank, as swimmers.
func stock() -> void:
	for s in _swimmers:
		s.queue_free()
	_swimmers.clear()
	_glowing = null
	for i in Profile.tank.size():
		var f: Dictionary = Profile.tank[i]
		var s := Swimmer.new()
		if not s.setup(f, i, self):
			s.free()
			continue
		_fish_root.add_child(s)
		_swimmers.append(s)


func fish() -> Array:
	return _swimmers


func water() -> AABB:
	return SWIM


## Whether a swimmer is in the water (the test's check).
func inside(s: Node3D) -> bool:
	return SWIM.grow(0.05).has_point(s.position)


func food() -> Array:
	return _food.map(func(p): return p[0].position)


## A pinch of food on the surface; it sinks to the sand.
func feed() -> void:
	for i in 6:
		var pellet := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.008
		m.height = 0.016
		m.radial_segments = 6
		m.rings = 3
		pellet.mesh = m
		pellet.material_override = _mat(Color(0.55, 0.32, 0.14))
		pellet.position = Vector3(randf_range(-0.6, 0.6), SURFACE - 0.01, randf_range(-0.25, 0.25))
		_world.add_child(pellet)
		_food.append([pellet, 0.0])


func eat(at: Vector3) -> void:
	for p in _food:
		if p[0].position == at:
			p[0].queue_free()
			_food.erase(p)
			return


## The bottom at (x, z): the drum's curved inside, with silt settled in
## the low middle in gentle ripples.
static func sand_y(x: float, z: float) -> float:
	var curve := AXIS_Y - sqrt(maxf(RADIUS * RADIUS - z * z, 0.0))
	var silt := 0.1 + 0.018 * sin(x * 3.1 + 1.3) * cos(z * 5.2) + 0.01 * sin(x * 7.3 + z * 2.1)
	return maxf(curve, silt)


## Where a shy fish hides: in the shade under a leaf.
func leaf_spot() -> Vector3:
	var p: Array = PADS[randi() % PADS.size()]
	return Vector3(p[0] + randf_range(-0.08, 0.08), 0.0, p[1] + randf_range(-0.06, 0.06))


func splash(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var m := PlaneMesh.new()
	m.size = Vector2(0.3, 0.3)
	ring.mesh = m
	ring.material_override = _ring_mat()
	ring.position = Vector3(at.x, SURFACE + 0.002, at.z)
	ring.scale = Vector3.ONE * 0.2
	_world.add_child(ring)
	_splashes.append([ring, 0.0])


## Lights the fish `index` up (its card is open); -1 for none.
func highlight(index: int) -> void:
	if _glowing != null and is_instance_valid(_glowing):
		FishModel.glow(_glowing.model, 0.0)
	_glowing = null
	for s in _swimmers:
		if s.index == index:
			_glowing = s
			FishModel.glow(s.model, 0.6)


func _process(delta: float) -> void:
	_time += delta
	for i in _floating.size():
		var pad: Node3D = _floating[i]
		pad.position.y = SURFACE - 0.004 + sin(_time * 0.9 + i * 2.0) * 0.003
		pad.rotation.y += sin(_time * 0.3 + i) * 0.02 * delta
	for p in _food:
		var pellet: MeshInstance3D = p[0]
		var floor_y := sand_y(pellet.position.x, pellet.position.z) + 0.008
		if pellet.position.y > floor_y:
			pellet.position += Vector3(sin(_time * 2.0 + pellet.position.x * 9.0) * 0.004, -0.07, 0.0) * delta
			pellet.position.y = maxf(pellet.position.y, floor_y)
		else:
			p[1] += delta
	# Food left on the sand long enough dissolves.
	for p in _food.filter(func(p): return p[1] > 25.0):
		p[0].queue_free()
		_food.erase(p)
	for s in _splashes:
		s[1] += delta
		var ring: MeshInstance3D = s[0]
		ring.scale = Vector3.ONE * (0.2 + s[1] * 1.6)
		(ring.material_override as ShaderMaterial).set_shader_parameter("fade", 1.0 - s[1] / 0.9)
	for s in _splashes.filter(func(s): return s[1] >= 0.9):
		s[0].queue_free()
		_splashes.erase(s)
	for s in _swimmers:
		s.swim(delta, self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := pick(event.position * RENDER_SCALE)
		if i >= 0:
			picked.emit(i)
			accept_event()


## The fish under `at` (viewport pixels), nearest the glass first; -1 if
## none.
func pick(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for s in _swimmers:
		var p: Vector3 = s.global_position
		if camera.is_position_behind(p):
			continue
		var c := camera.unproject_position(p)
		var reach := (camera.unproject_position(p + camera.global_transform.basis.x * s.length * 0.5) - c).length()
		var d := camera.global_position.distance_to(p)
		if c.distance_to(at) < maxf(reach, 18.0) and d < best_d:
			best = s.index
			best_d = d
	return best


# ---------------------------------------------------------------- the tank

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.44, 0.56)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Deeper is darker: things further from the eye fade into the water's
	# colour (and the night past the drum).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = WATER_COLOR
	env.fog_density = 0.7
	env.fog_depth_begin = 2.75
	env.fog_depth_end = 4.4
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	# The moon, high, and the campfire off to the front right.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = 0.75
	moon.rotation_degrees = Vector3(-62, -28, 0)
	_world.add_child(moon)
	var fire := OmniLight3D.new()
	fire.name = "Fire"
	fire.light_color = Color(1.0, 0.62, 0.3)
	fire.light_energy = 2.2
	fire.omni_range = 5.5
	fire.omni_attenuation = 1.3
	fire.position = Vector3(1.9, 1.5, 1.7)
	_world.add_child(fire)


static func _mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


## Light rippling through the surface onto what's below (a cheap caustic:
## a few rounds of warping sines).
const CAUSTIC := """
float caustic(vec2 uv, float t) {
	vec2 p = mod(uv * 6.2831, 6.2831) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}
"""


## The drum, and the trampled ground round it.
func _drum() -> void:
	var drum := CampModel.make("drum_trough")
	if drum != null:
		drum.scale = Vector3.ONE * DRUM_SCALE
		# Weathered by the water: darker, browner than the camp's dry one.
		var m: StandardMaterial3D = drum.material_override.duplicate()
		m.albedo_color = Color(0.5, 0.4, 0.32)
		drum.material_override = m
		_world.add_child(drum)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = noise(wpos.xz * 3.0) * 0.6 + noise(wpos.xz * 11.0) * 0.4;
	vec3 dirt = mix(vec3(0.09, 0.075, 0.06), vec3(0.17, 0.14, 0.1), n);
	// Tufts of dry grass away from the drum, pebbles.
	float grass = smoothstep(0.55, 0.75, noise(wpos.xz * 2.2 + 7.0)) * smoothstep(1.1, 1.8, length(wpos.xz * vec2(0.7, 1.2)));
	dirt = mix(dirt, vec3(0.13, 0.15, 0.07), grass * 0.8);
	vec2 cell = wpos.xz * 9.0;
	float peb = step(0.93, hash(floor(cell))) * smoothstep(0.3, 0.18, length(fract(cell) - 0.5));
	ALBEDO = mix(dirt, vec3(0.25, 0.24, 0.22), peb * 0.7);
	ROUGHNESS = 0.97;
}
"""
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9, 7)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = sh
	ground.material_override = gm
	ground.position.y = -0.002
	_world.add_child(ground)


func _sand() -> void:
	# A grid over the drum's bottom (sand_y): the silt, and the drum's
	# rusty inside rising round it under the water.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 36
	var nz := 18
	var hx := LENGTH / 2.0 - 0.03
	var hz := sqrt(RADIUS * RADIUS - pow(SURFACE + 0.02 - AXIS_Y, 2.0))
	for j in nz:
		for i in nx:
			var quad := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var x: float = -hx + 2.0 * hx * c[0] / nx
				var z: float = -hz + 2.0 * hz * c[1] / nz
				quad.append(Vector3(x, sand_y(x, z), z))
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(quad[k].x, quad[k].z))
				st.add_vertex(quad[k])
	st.generate_normals()
	var sand := MeshInstance3D.new()
	sand.mesh = st.commit()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 light_sand : source_color = vec3(0.5, 0.43, 0.3);
uniform vec3 dark_sand : source_color = vec3(0.27, 0.23, 0.16);
uniform vec3 rust : source_color = vec3(0.3, 0.15, 0.07);
uniform float surface = 0.71;
uniform float silt = 0.13;
varying vec3 wpos;
""" + CAUSTIC + """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Grains and pebbles in the silt; rust and slime up the walls.
	float grain = hash(floor(wpos.xz * 160.0));
	vec2 cell = wpos.xz * 20.0;
	vec2 id = floor(cell);
	float peb = step(0.82, hash(id)) * smoothstep(0.42, 0.3, length(fract(cell) - 0.5));
	vec3 col = mix(dark_sand, light_sand, 0.55 + 0.35 * grain);
	col = mix(col, mix(dark_sand, vec3(0.6, 0.57, 0.5), hash(id + 3.1)), peb * 0.8);
	float wall = smoothstep(silt - 0.01, silt + 0.05, wpos.y);
	vec3 walls = mix(rust, vec3(0.12, 0.16, 0.08), 0.5 + 0.5 * sin(wpos.x * 9.0 + hash(floor(wpos.xz * 30.0)) * 2.0));
	col = mix(col, walls, wall);
	// Darker the deeper.
	col *= mix(1.0, 0.55, clamp((surface - wpos.y) / 0.6, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	// The ripples of light, on the silt.
	float c = caustic(wpos.xz * 0.7, TIME * 0.35);
	EMISSION = vec3(0.5, 0.75, 0.7) * c * 0.22 * (1.0 - wall);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("surface", SURFACE)
	sand.material_override = mat
	_world.add_child(sand)


func _rocks() -> void:
	var stone := _mat(Color(0.33, 0.31, 0.28), 0.9)
	var mossy := _mat(Color(0.22, 0.28, 0.18), 0.95)
	for r in ROCKS:
		var rock := MeshInstance3D.new()
		rock.mesh = CampStage._rock_mesh(r[2])
		rock.material_override = stone if r[2] % 2 == 1 else mossy
		var c: Vector3 = r[0]
		rock.position = Vector3(c.x, sand_y(c.x, c.z) - 0.03, c.z)
		rock.scale = Vector3(r[1] * 2.2, r[1] * 1.8, r[1] * 1.9)
		rock.rotation.y = r[2] * 0.7
		_world.add_child(rock)


## The water's surface from above: dark and clear, tinted, rippling, the
## moon and the fire glinting on it.
func _surface() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.04, 0.11, 0.09);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	vec2 g = vec2(cos(p.x * 9.0 + t * 1.3) + 0.6 * cos(p.x * 4.0 - p.y * 7.0 + t * 0.9),
		sin(p.y * 11.0 - t * 1.1) + 0.6 * sin(p.x * 6.0 + p.y * 5.0 + t * 0.7)) * 0.06;
	NORMAL = normalize((VIEW_MATRIX * vec4(g.x, 1.0, g.y, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint;
	ALPHA = 0.42 + 0.4 * fres;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	// The night sky's sheen at the far side.
	EMISSION = vec3(0.05, 0.08, 0.12) * fres;
}
"""
	var water := MeshInstance3D.new()
	water.name = "Surface"
	var pm := PlaneMesh.new()
	var half_w := sqrt(RADIUS * RADIUS - pow(SURFACE - AXIS_Y, 2.0))
	pm.size = Vector2(LENGTH - 0.05, 2.0 * half_w)
	pm.subdivide_width = 8
	pm.subdivide_depth = 4
	water.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = sh
	water.material_override = mat
	water.position.y = SURFACE
	_world.add_child(water)


## Lotus leaves afloat (ASSET2's leaf), bobbing a little (a fish under one
## is half hidden).
func _pads() -> void:
	var leaf := CampModel.make("lotus_leaf")
	if leaf == null:
		return
	# Its own material (not the shared one): two-sided, darkened to the night.
	var mat := (leaf.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.5, 0.55, 0.5)
	mat.roughness = 0.55
	leaf.material_override = mat
	for pad in PADS:
		var mi := leaf.duplicate() as MeshInstance3D
		mi.name = "Pad"
		mi.scale = Vector3.ONE * pad[2] * 2.0
		mi.position = Vector3(pad[0], SURFACE - 0.004, pad[1])
		mi.rotation.y = pad[0] * 7.0
		_world.add_child(mi)
		_floating.append(mi)
	leaf.free()


static var _ring_shader: Shader


func _ring_mat() -> ShaderMaterial:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float fade = 1.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.08, 0.0, abs(r - 0.8));
	ALBEDO = vec3(0.8, 0.95, 1.0) * ring * fade * 0.8;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	return m


# ---------------------------------------------------------------- a swimmer

## One fish in the tank, swimming by its trait (as FishTank.Swimmer does in
## 2D): the node turns to its heading; its model (FishModel) beats its tail.
class Swimmer extends Node3D:
	var index := 0
	var trait_key := "active"
	var length := 0.3
	var speed := 0.15
	var vel := Vector3.ZERO
	var target := Vector3.ZERO
	var model: MeshInstance3D
	var flat := false
	var _yaw := 0.0
	var _pitch := 0.0
	var _t := 0.0
	var _rethink := 0.0
	var _dash := 0.0
	var _victim: Swimmer = null
	var _flee := Vector3.ZERO
	var _jump := -1.0
	var _jump_from := Vector3.ZERO
	var _jump_dir := Vector3.RIGHT
	var _next_jump := 0.0

	func setup(f: Dictionary, i: int, tank: Aquarium) -> bool:
		var id: String = f.get("id", "")
		model = FishModel.make(id)
		if model == null:
			return false
		index = i
		name = "Swimmer_%d" % i
		trait_key = f.get("tank_trait", "active")
		flat = FishData.FISH.get(id, {}).get("body", "") == "flat"
		var cm := float(f.get("length", 30.0))
		length = lerpf(0.16, 0.58, clampf(log(maxf(cm, 1.0) / 5.0) / log(60.0), 0.0, 1.0))
		model.scale = Vector3.ONE * length / 1.15
		if flat:
			# A flatfish lies on its side on the sand.
			model.rotation.x = -PI / 2.0
			trait_key = "bottom" if trait_key != "lazy" else "lazy"
		add_child(model)
		speed = float(Aquarium.SPEEDS.get(trait_key, 0.15)) * randf_range(0.85, 1.15)
		position = Vector3(randf_range(Aquarium.SWIM.position.x, Aquarium.SWIM.end.x), randf_range(Aquarium.SWIM.position.y, Aquarium.SWIM.end.y),
			randf_range(Aquarium.SWIM.position.z, Aquarium.SWIM.end.z))
		_yaw = randf() * TAU
		target = position
		_t = randf() * 10.0
		_next_jump = randf_range(8.0, 18.0)
		return true

	func startle(from: Vector3) -> void:
		_flee = (position - from).normalized() * 0.6

	func _floor(at: Vector3) -> float:
		return Aquarium.sand_y(at.x, at.z) + (0.03 if flat else maxf(0.06, length * 0.2))

	func _pick_target(tank: Aquarium) -> void:
		var p := Vector3(randf_range(Aquarium.SWIM.position.x, Aquarium.SWIM.end.x), randf_range(Aquarium.SWIM.position.y, Aquarium.SWIM.end.y),
			randf_range(Aquarium.SWIM.position.z, Aquarium.SWIM.end.z))
		match trait_key:
			"bottom":
				p.y = _floor(p) + randf_range(0.0, 0.1)
			"shy":
				var w := tank.leaf_spot()
				p = Vector3(w.x, randf_range(Aquarium.SWIM.position.y, Aquarium.SWIM.get_center().y), w.z)
			"lazy":
				p = position + Vector3(randf_range(-0.15, 0.15), randf_range(-0.05, 0.05), randf_range(-0.08, 0.08))
		target = p.clamp(Aquarium.SWIM.position, Aquarium.SWIM.end)
		target.y = maxf(target.y, _floor(target))
		_rethink = randf_range(2.5, 6.0) * (2.0 if trait_key == "lazy" else 1.0)

	func swim(delta: float, tank: Aquarium) -> void:
		_t += delta
		if _jump >= 0.0:
			_leap(delta, tank)
			return
		_rethink -= delta
		if _rethink <= 0.0 or position.distance_to(target) < 0.05:
			_pick_target(tank)
		var go := target
		var pace := speed
		var food: Array = tank.food()
		if not food.is_empty() and trait_key != "lazy":
			var near: Vector3 = food[0]
			for f in food:
				if position.distance_to(f) < position.distance_to(near):
					near = f
			go = near
			pace = speed * (2.0 if trait_key == "glutton" else 1.3)
			if position.distance_to(near) < maxf(length * 0.35, 0.04):
				tank.eat(near)
		elif trait_key == "school":
			var sum := Vector3.ZERO
			var n := 0
			for o in tank.fish():
				if o != self and (o.trait_key == "school" or n == 0):
					sum += o.position
					n += 1
			if n > 0:
				go = go.lerp(sum / n, 0.7)
		elif trait_key == "fierce":
			_dash -= delta
			if _dash < -randf_range(6.0, 10.0) and tank.fish().size() > 1:
				var others: Array = tank.fish().filter(func(o): return o != self)
				_victim = others[randi() % others.size()]
				_dash = 1.4
			if _dash > 0.0 and _victim != null and is_instance_valid(_victim):
				go = _victim.position
				pace = speed * 2.4
				if position.distance_to(_victim.position) < length * 0.5:
					_victim.startle(position)
					_dash = 0.0
		elif trait_key == "jumper":
			_next_jump -= delta
			if _next_jump <= 0.0 and position.y > Aquarium.SWIM.end.y - 0.12:
				_jump = 0.0
				_jump_from = position
				var h := Vector3(vel.x, 0, vel.z)
				_jump_dir = h.normalized() if h.length() > 0.01 else Vector3(cos(_yaw), 0, -sin(_yaw))
				tank.splash(position)
				return
			elif _next_jump <= 0.0:
				go = Vector3(position.x, Aquarium.SWIM.end.y, position.z)
				pace = speed * 1.6
		var want := (go - position).normalized() * pace if position.distance_to(go) > 0.01 else Vector3.ZERO
		vel = vel.lerp(want, minf(1.0, delta * 1.6))
		if _flee != Vector3.ZERO:
			vel += _flee * delta * 6.0
			_flee = _flee.move_toward(Vector3.ZERO, 0.9 * delta)
		position = (position + vel * delta).clamp(Aquarium.SWIM.position, Aquarium.SWIM.end)
		position.y = maxf(position.y, _floor(position))
		# Out of the rocks.
		for r in Aquarium.ROCKS:
			var c: Vector3 = r[0]
			var away := position - c
			var reach: float = r[1] + length * 0.3
			if away.length() < reach:
				position = c + away.normalized() * reach
		_pose(delta)

	## A leap out of the water and back.
	func _leap(delta: float, tank: Aquarium) -> void:
		_jump += delta
		var k := _jump / 1.0
		var top := Aquarium.SURFACE
		position = _jump_from + _jump_dir * 0.3 * k + Vector3.UP * ((top - _jump_from.y) * sin(minf(k * 1.6, 1.0) * PI / 2.0) + sin(k * PI) * 0.16)
		_pitch = lerpf(0.9, -0.9, k)
		basis = Basis.from_euler(Vector3(0, _yaw, _pitch))
		FishModel.swim(model, delta, 1.2)
		if k >= 1.0:
			_jump = -1.0
			_next_jump = randf_range(12.0, 25.0)
			tank.splash(position)
			position.y = minf(position.y, Aquarium.SWIM.end.y)
			vel = _jump_dir * speed

	func _pose(delta: float) -> void:
		var flat_v := Vector2(vel.x, vel.z)
		if flat_v.length() > 0.02:
			_yaw = lerp_angle(_yaw, atan2(-vel.z, vel.x), minf(1.0, delta * 3.0))
		var want_pitch := clampf(atan2(vel.y, maxf(flat_v.length(), 0.001)), -0.5, 0.5) * 0.8 if not flat else 0.0
		_pitch = lerpf(_pitch, want_pitch, minf(1.0, delta * 3.0))
		# A gentle bob when idling.
		var bob := sin(_t * 1.7) * 0.002
		position.y += bob
		basis = Basis.from_euler(Vector3(0, _yaw, _pitch))
		FishModel.swim(model, delta, vel.length() / maxf(speed, 0.01) * 0.6 + 0.15)
