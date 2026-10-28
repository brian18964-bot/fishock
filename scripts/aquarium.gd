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
## A fish in the bucket tapped: its place in Profile.fish_box.
signal bucket_picked(index: int)
## The bucket itself tapped (in the tank's view: go to it).
signal bucket_clicked

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
## [x, z, radius (the leaf model is 1 m across: scale 2r)] - user report: far too
## big (0.5 m), 60% smaller (0.2 m), and two of them.
const PADS := [[-0.5, 0.26, 0.2], [0.55, -0.22, 0.17]]
## The bucket (魚桶, the user's bucket model - tools/make_bucket.py) stands
## left of the drum, half in the frame; its fish are bodies the physics pile
## up in it. The inside: its wall's radius at a height h (model metres) is
## BUCKET_R0 + BUCKET_LEAN * h, its floor BUCKET_FLOOR up (model metres).
const BUCKET_FILE := "res://assets/models/items/fish_bucket.glb"
const BUCKET_AT := Vector3(-1.62, 0.0, 0.05)
const BUCKET_SCALE := 2.4
const BUCKET_R0 := 0.082
const BUCKET_LEAN := 0.12
const BUCKET_FLOOR := 0.02
const BUCKET_WALLS := 18
## The two views: the tank with the bucket half in at the left, and the bucket.
## [camera position, what it looks at, fov]
const VIEWS := {
	"tank": [Vector3(-0.25, 3.5, 1.1), Vector3(-0.25, 0.4, 0.02), 38.0],
	"bucket": [Vector3(-1.62, 2.0, 0.75), Vector3(-1.62, 0.22, 0.05), 34.0],
}
## The leaves' water: how fast they slow (per s), the most they go (m/s).
const LEAF_DRAG := 1.5
const LEAF_MAX := 1.6
## Ripples going at once (the surface's shader holds this many).
const DROPS := 24
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
## The lily pads: {node, pos (x, z), vel, yaw, spin, r, wake (s till its next ripple)}.
var _leaves: Array = []
## Where the player left them (this session's): [[x, z, yaw] ..].
static var _saved_leaves: Array = []
## The leaf held: {leaf, grab (its local point), to (where the finger is), moved, at}.
var _held := {}
## Ripples: [x, z, age, strength].
var _drops: Array = []
var _water_mat: ShaderMaterial
var _bucket_fish: Array = []
var _spawn_queue: Array = []
var _spawn_wait := 0.0
var _view := "tank"
var _view_tween: Tween


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
	_bucket()
	_fish_root = Node3D.new()
	_world.add_child(_fish_root)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 20.0
	_world.add_child(camera)
	_set_view_now("tank")
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
	stock_bucket()


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
	var l: Dictionary = _leaves[randi() % _leaves.size()] if not _leaves.is_empty() else {"pos": Vector2.ZERO}
	return Vector3(l.pos.x + randf_range(-0.08, 0.08), 0.0, l.pos.y + randf_range(-0.06, 0.06))


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
	ripple(Vector2(at.x, at.z), 1.0)


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
	_float_leaves(delta)
	_age_drops(delta)
	_spawn_wait -= delta
	if not _spawn_queue.is_empty() and _spawn_wait <= 0.0:
		_spawn_wait = 0.07
		_drop_in(_spawn_queue.pop_front())
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# A leaf under the finger is taken (and let go of, it drifts on); a
			# tap that doesn't move it goes on to the fish under it.
			var at := _surface_point(event.position)
			var leaf := _leaf_at(at)
			if not leaf.is_empty() and _view == "tank":
				var local := Vector2(at - leaf.pos).rotated(leaf.yaw)
				_held = {"leaf": leaf, "grab": local, "to": at, "moved": 0.0, "at": event.position}
				accept_event()
				return
			_tap(event.position)
		elif not _held.is_empty():
			var tap: bool = float(_held.moved) < 8.0
			var where: Vector2 = _held.at
			_held = {}
			if tap:
				_tap(where)
			accept_event()
	elif event is InputEventMouseMotion and not _held.is_empty():
		_held.to = _surface_point(event.position)
		_held.moved += event.relative.length()
		accept_event()


func _tap(at: Vector2) -> void:
	if _view == "bucket":
		var b := bucket_pick(at * RENDER_SCALE)
		if b >= 0:
			bucket_picked.emit(b)
		return
	var i := pick(at * RENDER_SCALE)
	if i >= 0:
		picked.emit(i)
		return
	# The bucket at the left (half in the frame): a tap on it goes to it.
	var mid := BUCKET_AT + Vector3(0, 0.28 * BUCKET_SCALE * 0.5, 0)
	if not camera.is_position_behind(mid):
		var c := camera.unproject_position(mid)
		var reach := (camera.unproject_position(mid + Vector3(0.135 * BUCKET_SCALE, 0, 0)) - c).length() * 1.1
		if c.distance_to(at * RENDER_SCALE) < reach:
			bucket_clicked.emit()


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
// Ripples (x, z, age, strength): a ring of crests going out at c m/s, each
// a little behind the last, fading as it widens and as it ages.
uniform vec4 drops[24];
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	vec2 g = vec2(cos(p.x * 9.0 + t * 1.3) + 0.6 * cos(p.x * 4.0 - p.y * 7.0 + t * 0.9),
		sin(p.y * 11.0 - t * 1.1) + 0.6 * sin(p.x * 6.0 + p.y * 5.0 + t * 0.7)) * 0.06;
	float lit = 0.0;
	for (int i = 0; i < 24; i++) {
		vec4 d = drops[i];
		if (d.w <= 0.0) { continue; }
		vec2 v = p - d.xy;
		float dist = length(v) + 0.0001;
		float front = d.z * 0.33;
		float x = dist - front;
		float width = 0.055 + d.z * 0.05;
		float env = exp(-x * x / (2.0 * width * width));
		float life = d.w * exp(-d.z * 1.5) / (1.0 + dist * 4.0);
		float wave = cos(x * 58.0) * env * life;
		g += v / dist * wave * 0.32;
		lit += abs(wave);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(g.x, 1.0, g.y, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint;
	ALPHA = clamp(0.42 + 0.4 * fres + lit * 0.45, 0.0, 0.95);
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	// The night sky's sheen at the far side, the crests catching it.
	EMISSION = vec3(0.05, 0.08, 0.12) * fres + vec3(0.45, 0.62, 0.7) * lit * 1.1;
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
	_water_mat = mat
	var none := PackedVector4Array()
	none.resize(DROPS)
	mat.set_shader_parameter("drops", none)
	water.material_override = mat
	water.position.y = SURFACE
	_world.add_child(water)


## Lotus leaves afloat (ASSET2's leaf): they float on the water as a leaf
## does - pushed about by a finger (a drag takes one by the spot touched, so a
## pull off its middle turns it too), going on a while after it's let go,
## slowing in the water, bumping the others and the drum's wall, every move
## and knock sending ripples out over the surface. A fish under one is half
## hidden. Where they were left is kept for the next time the page opens.
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
	for k in PADS.size():
		var pad: Array = PADS[k]
		var mi := leaf.duplicate() as MeshInstance3D
		mi.name = "Pad"
		mi.scale = Vector3.ONE * pad[2] * 2.0
		var at := Vector2(pad[0], pad[1])
		var yaw: float = pad[0] * 7.0
		if k < _saved_leaves.size():
			at = Vector2(_saved_leaves[k][0], _saved_leaves[k][1])
			yaw = _saved_leaves[k][2]
		mi.position = Vector3(at.x, SURFACE - 0.004, at.y)
		mi.rotation.y = yaw
		_world.add_child(mi)
		_leaves.append({"node": mi, "pos": at, "vel": Vector2.ZERO, "yaw": yaw, "spin": 0.0, "r": pad[2], "wake": 0.0, "bob": k * 2.0})
	leaf.free()


func _exit_tree() -> void:
	_saved_leaves = _leaves.map(func(l): return [l.pos.x, l.pos.y, l.yaw])


## Half the water's width and depth the leaves keep in (m): the surface's
## own size.
static func _water_half() -> Vector2:
	return Vector2((LENGTH - 0.05) * 0.5, sqrt(RADIUS * RADIUS - pow(SURFACE - AXIS_Y, 2.0)))


## The point on the water's plane under a click (viewport pixels `p`, the
## control's), as (x, z).
func _surface_point(p: Vector2) -> Vector2:
	var vp := p * RENDER_SCALE
	var o := camera.project_ray_origin(vp)
	var d := camera.project_ray_normal(vp)
	if absf(d.y) < 0.0001:
		return Vector2.ZERO
	var hit := o + d * ((SURFACE - o.y) / d.y)
	return Vector2(hit.x, hit.z)


## The leaf at water point `at` (the topmost one), or {}.
func _leaf_at(at: Vector2) -> Dictionary:
	for k in range(_leaves.size() - 1, -1, -1):
		if _leaves[k].pos.distance_to(at) < _leaves[k].r * 0.95:
			return _leaves[k]
	return {}


## One step of the leaves' floating.
func _float_leaves(delta: float) -> void:
	var half := _water_half()
	for l in _leaves:
		var force := Vector2.ZERO
		var torque := 0.0
		var held: bool = not _held.is_empty() and _held.leaf == l
		if held:
			# (a spring to the finger, by the spot it took: the pull turns it)
			var grab: Vector2 = Vector2(_held.grab).rotated(-l.yaw)
			var at: Vector2 = l.pos + grab
			var to: Vector2 = _held.to
			force = (to - at) * 70.0 - l.vel * 15.0
			torque = grab.y * force.x - grab.x * force.y
		else:
			# (a faint current: they never lie quite still)
			force = Vector2(sin(_time * 0.37 + l.bob), cos(_time * 0.29 + l.bob * 1.7)) * 0.012
		l.vel += force * delta
		l.vel *= exp(-(0.35 if held else LEAF_DRAG) * delta)
		if l.vel.length() > LEAF_MAX:
			l.vel = l.vel.normalized() * LEAF_MAX
		l.spin += torque / (l.r * l.r * 9.0) * delta
		l.spin *= exp(-2.4 * delta)
		l.pos += l.vel * delta
		l.yaw += l.spin * delta
		# The drum's wall.
		var reach: float = l.r * 0.85
		var hit := 0.0
		if absf(l.pos.x) > half.x - reach:
			l.pos.x = signf(l.pos.x) * (half.x - reach)
			hit = absf(l.vel.x)
			l.vel.x *= -0.45
		var zr: float = half.y - reach * 0.6
		if absf(l.pos.y) > zr:
			l.pos.y = signf(l.pos.y) * zr
			hit = maxf(hit, absf(l.vel.y))
			l.vel.y *= -0.45
		if hit > 0.05:
			ripple(l.pos, clampf(hit * 1.2, 0.2, 1.0))
	# Leaf against leaf.
	for a in _leaves.size():
		for b in range(a + 1, _leaves.size()):
			_bump(_leaves[a], _leaves[b])
	for l in _leaves:
		var speed: float = l.vel.length()
		# A wake behind a moving one.
		l.wake -= delta
		if speed > 0.04 and l.wake <= 0.0:
			l.wake = clampf(0.34 - speed * 0.2, 0.14, 0.34)
			ripple(l.pos - l.vel.normalized() * l.r * 0.4, clampf(speed * 1.1, 0.15, 0.9))
		var node: Node3D = l.node
		node.position = Vector3(l.pos.x, SURFACE - 0.004 + sin(_time * 0.9 + l.bob) * 0.003, l.pos.y)
		# (it heels a little the way it goes)
		# (its size kept: the leaf model is 1 m across)
		node.basis = Basis.from_euler(Vector3(l.vel.y * 0.1, l.yaw, -l.vel.x * 0.1)).scaled(Vector3.ONE * float(l.r) * 2.0)


func _bump(a: Dictionary, b: Dictionary) -> void:
	var gap: Vector2 = a.pos - b.pos
	var min_gap: float = (a.r + b.r) * 0.85
	var dist := gap.length()
	if dist >= min_gap or dist < 0.0001:
		return
	var n := gap / dist
	var ma: float = a.r * a.r
	var mb: float = b.r * b.r
	var push := min_gap - dist
	a.pos += n * push * mb / (ma + mb)
	b.pos -= n * push * ma / (ma + mb)
	var rel: float = (a.vel - b.vel).dot(n)
	if rel < 0.0:
		var j := -(1.0 + 0.5) * rel / (1.0 / ma + 1.0 / mb)
		a.vel += n * j / ma
		b.vel -= n * j / mb
		a.spin += rel * 0.8
		b.spin -= rel * 0.8
		ripple((a.pos + b.pos) * 0.5, clampf(-rel * 1.4, 0.2, 1.0))


## A ripple starting at water point `at` (x, z), `strength` 0..1.
func ripple(at: Vector2, strength: float) -> void:
	_drops.append([at.x, at.y, 0.0, strength])
	if _drops.size() > DROPS:
		_drops.pop_front()


func _age_drops(delta: float) -> void:
	for d in _drops:
		d[2] += delta
	_drops = _drops.filter(func(d): return d[2] < 1.8)
	if _water_mat == null:
		return
	var out := PackedVector4Array()
	out.resize(DROPS)
	for i in _drops.size():
		var d: Array = _drops[i]
		out[i] = Vector4(d[0], d[1], d[2], d[3])
	_water_mat.set_shader_parameter("drops", out)


# ---------------------------------------------------------------- the bucket

## The bucket (a metal pail with its bail) stood left of the drum, with a
## floor and a ring of leaning walls for the fish to pile in.
func _bucket() -> void:
	var body := StaticBody3D.new()
	body.name = "Bucket"
	body.position = BUCKET_AT
	var scene: PackedScene = load(BUCKET_FILE) if ResourceLoader.exists(BUCKET_FILE) else null
	if scene != null:
		var model := scene.instantiate() as Node3D
		model.scale = Vector3.ONE * BUCKET_SCALE
		model.rotation.y = 0.5
		body.add_child(model)
	var k := BUCKET_SCALE
	var floor_shape := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(1.6, 0.4, 1.6)
	floor_shape.shape = fb
	floor_shape.position = Vector3(0, BUCKET_FLOOR * k - 0.2, 0)
	body.add_child(floor_shape)
	var tilt := atan(BUCKET_LEAN)
	var h_mid := 0.13
	var r_mid := (BUCKET_R0 + BUCKET_LEAN * h_mid) * k
	var thick := 0.12
	for i in BUCKET_WALLS:
		var a := TAU * i / BUCKET_WALLS
		var wall := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(thick, 0.34 * k, TAU * r_mid / BUCKET_WALLS * 1.25)
		wall.shape = wb
		var out := r_mid + thick * 0.5
		wall.transform = Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -tilt),
			Vector3(cos(a) * out, h_mid * k, sin(a) * out))
		body.add_child(wall)
	_world.add_child(body)


## Which view the camera has ("tank": the drum with the bucket half in at the
## left; "bucket": the bucket close). Eased over a moment.
func set_view(view: String) -> void:
	if view == _view or not VIEWS.has(view):
		return
	_view = view
	_held = {}
	if _view_tween != null:
		_view_tween.kill()
	var from_pos := camera.position
	var from_q := camera.basis.get_rotation_quaternion()
	var from_fov := camera.fov
	var to: Array = VIEWS[view]
	var to_t := Transform3D(Basis.IDENTITY, to[0]).looking_at(to[1], Vector3.UP)
	_view_tween = create_tween()
	_view_tween.tween_method(func(k: float):
		camera.position = from_pos.lerp(to[0], k)
		camera.basis = Basis(from_q.slerp(to_t.basis.get_rotation_quaternion(), k))
		camera.fov = lerpf(from_fov, to[2], k), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func view() -> String:
	return _view


func _set_view_now(view: String) -> void:
	_view = view
	var to: Array = VIEWS[view]
	camera.transform = Transform3D(Basis.IDENTITY, to[0]).looking_at(to[1], Vector3.UP)
	camera.fov = to[2]


func bucket_fish() -> Array:
	return _bucket_fish


## The fish in Profile.fish_box as bodies in the bucket: ones gone are taken
## out, new ones tumble in from above.
func stock_bucket() -> void:
	for b in _bucket_fish.duplicate():
		if _index_of(Profile.fish_box, b.fish) < 0:
			b.queue_free()
			_bucket_fish.erase(b)
	for f in Profile.fish_box:
		var there := false
		for b in _bucket_fish:
			there = there or is_same(b.fish, f)
		for q in _spawn_queue:
			there = there or is_same(q, f)
		if not there:
			_spawn_queue.append(f)


static func _index_of(list: Array, f: Dictionary) -> int:
	for i in list.size():
		if is_same(list[i], f):
			return i
	return -1


## A fish let fall into the bucket, from above, turning as it comes.
func _drop_in(f: Dictionary) -> void:
	var b := BucketFish.new()
	if not b.setup(f):
		b.free()
		return
	var k := BUCKET_SCALE
	b.position = BUCKET_AT + Vector3(randf_range(-0.1, 0.1), 0.95 * k * 0.5 + _bucket_fish.size() * 0.015, randf_range(-0.1, 0.1))
	b.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	b.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	_world.add_child(b)
	_bucket_fish.append(b)


## The bucket's fish under `at` (viewport pixels): its place in
## Profile.fish_box, or -1.
func bucket_pick(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for b in _bucket_fish:
		var p: Vector3 = b.global_position
		if camera.is_position_behind(p):
			continue
		var c := camera.unproject_position(p)
		var reach := (camera.unproject_position(p + camera.global_transform.basis.x * b.length * 0.5) - c).length()
		var d := camera.global_position.distance_to(p)
		if c.distance_to(at) < maxf(reach, 16.0) and d < best_d:
			best = _index_of(Profile.fish_box, b.fish)
			best_d = d
	return best


## Lights the bucket's fish `index` (its place in Profile.fish_box); -1 for none.
func highlight_bucket(index: int) -> void:
	for b in _bucket_fish:
		FishModel.glow(b.model, 0.6 if index >= 0 and is_same(b.fish, Profile.fish_box[index]) else 0.0)


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


## One fish in the bucket: a body the physics lets fall and pile - lying where
## it lands once it's dead (white-eyed, gone green or purple as it rots), a
## living one flopping now and then (weaker the less it has left).
class BucketFish extends RigidBody3D:
	var fish := {}
	var model: MeshInstance3D
	var length := 0.3
	var _flop := 0.0
	var _look := 0.0
	var _state := ""

	func setup(f: Dictionary) -> bool:
		var id: String = f.get("id", "")
		model = FishModel.make(id)
		if model == null:
			return false
		fish = f
		name = "BucketFish"
		var cm := float(f.get("length", 30.0))
		# (no longer than a pail's width)
		length = minf(lerpf(0.16, 0.58, clampf(log(maxf(cm, 1.0) / 5.0) / log(60.0), 0.0, 1.0)), 0.36)
		var unit := length / 1.15
		model.scale = Vector3.ONE * unit
		model.position.x = 0.06 * unit
		var shape := CollisionShape3D.new()
		var flat: bool = FishData.FISH.get(id, {}).get("body", "") == "flat"
		if flat:
			model.rotation.x = -PI / 2.0
			var box := BoxShape3D.new()
			box.size = Vector3(length * 0.95, length * 0.07, length * 0.45)
			shape.shape = box
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = maxf(length * 0.11, 0.012)
			cap.height = length * 0.9
			shape.shape = cap
			shape.rotation.z = PI / 2.0
		add_child(shape)
		add_child(model)
		mass = 0.3 + length * 2.0
		var mat := PhysicsMaterial.new()
		mat.friction = 0.9
		mat.bounce = 0.05
		physics_material_override = mat
		linear_damp = 0.25
		angular_damp = 1.4
		continuous_cd = true
		_flop = randf_range(0.2, 0.9)
		_dress()
		return true

	func _dress() -> void:
		_state = FishLife.state(fish)
		FishModel.dress(model, fish)

	func _physics_process(delta: float) -> void:
		_look -= delta
		if _look <= 0.0:
			_look = 0.4
			if FishLife.state(fish) != _state:
				_dress()
		if _state != "alive":
			return
		_flop -= delta
		if _flop > 0.0:
			return
		# A flop: up and over, weaker as its life runs out.
		var vit := clampf(float(FishLife.bar(fish).share), 0.15, 1.0)
		_flop = randf_range(0.5, 1.4) / vit
		apply_central_impulse(Vector3(randf_range(-0.4, 0.4), randf_range(0.9, 1.5), randf_range(-0.4, 0.4)) * mass * 0.5 * vit)
		apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass * 0.02 * vit)
		FishModel.swim(model, 0.3, 1.5)

