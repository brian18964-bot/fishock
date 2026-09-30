class_name Aquarium
extends Control

## The fish tank page's tank in 3D (user request: out of the game, show
## everything in 3D that can be): a planted tank seen through its front
## glass - sand in dunes rising to the back with light rippling over it,
## rocks and a piece of driftwood, weed swaying, light falling through the
## surface in shafts, bubbles from an air stone - and the fish of
## Profile.tank as 3D models (FishModel) swimming by their trait, as the
## 2D tank (FishTank.TankView, still used when the 3D camp is off) has
## them: schooling ones keep together, fierce ones go for the others now
## and then, bottom dwellers keep low (flatfish lie on the sand), shy ones
## by the weed, lazy ones barely move, jumpers leap out and splash,
## gluttons get to the food first. Tap a fish for its card (`picked`).
## Drawn at 1.5x in a SubViewport shown through a TextureRect.

signal picked(index: int)

const RENDER_SCALE := 1.5
## The water inside the glass: x across, y up (the surface at SURFACE), z
## toward the viewer.
const WIDTH := 2.0
const DEPTH := 1.0
const SURFACE := 1.2
## Where the fish may go (their middles).
const SWIM := AABB(Vector3(-0.84, 0.2, -0.3), Vector3(1.68, 0.9, 0.6))
const WATER_COLOR := Color(0.05, 0.19, 0.22)
## Rocks the fish keep out of: [centre, radius].
const ROCKS := [
	[Vector3(-0.62, 0.12, -0.3), 0.26, 3],
	[Vector3(-0.3, 0.1, -0.36), 0.17, 8],
	[Vector3(0.56, 0.1, -0.24), 0.2, 12],
	[Vector3(0.82, 0.08, 0.08), 0.12, 21],
]
## Weed clumps: [x, z, leaves, tallest, colour].
const WEED := [
	[-0.84, -0.36, 12, 1.05, Color(0.16, 0.42, 0.18)],
	[-0.45, -0.18, 8, 0.7, Color(0.26, 0.46, 0.16)],
	[0.2, -0.4, 14, 1.1, Color(0.14, 0.38, 0.2)],
	[0.78, -0.38, 9, 0.8, Color(0.62, 0.28, 0.18)],
	[0.4, 0.05, 6, 0.42, Color(0.3, 0.5, 0.18)],
	[-0.88, 0.2, 5, 0.35, Color(0.2, 0.45, 0.2)],
]
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
	_sand()
	_back()
	_rocks()
	_driftwood()
	_weed()
	_light()
	_bubbles()
	_frame()
	_fish_root = Node3D.new()
	_world.add_child(_fish_root)
	camera = Camera3D.new()
	camera.fov = 29.0
	camera.near = 0.05
	camera.far = 20.0
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 3.55)).looking_at(Vector3(0, 0.58, 0), Vector3.UP)
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
		pellet.position = Vector3(randf_range(-0.7, 0.7), SURFACE - 0.01, randf_range(-0.25, 0.25))
		_world.add_child(pellet)
		_food.append([pellet, 0.0])


func eat(at: Vector3) -> void:
	for p in _food:
		if p[0].position == at:
			p[0].queue_free()
			_food.erase(p)
			return


## The height of the sand at (x, z): low at the front, banked up at the
## back, in gentle dunes.
static func sand_y(x: float, z: float) -> float:
	var bank := lerpf(0.2, 0.04, clampf(z / DEPTH + 0.5, 0.0, 1.0))
	return bank + 0.025 * sin(x * 3.1 + 1.3) * cos(z * 4.2) + 0.012 * sin(x * 7.3 + z * 2.1)


## Where a shy fish hides: by a clump of weed.
func weed_spot() -> Vector3:
	var w: Array = WEED[randi() % WEED.size()]
	return Vector3(w[0] + randf_range(-0.15, 0.15), 0.0, w[1] + randf_range(0.0, 0.2))


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
	env.background_color = Color(0.012, 0.016, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.46, 0.5)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# The water: things further back fade into it.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = WATER_COLOR
	env.fog_density = 0.85
	env.fog_depth_begin = 2.9
	env.fog_depth_end = 5.2
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	# The tank's lamp, over it.
	var lamp := DirectionalLight3D.new()
	lamp.light_color = Color(0.85, 0.97, 1.0)
	lamp.light_energy = 1.15
	lamp.rotation_degrees = Vector3(-68, 12, 0)
	_world.add_child(lamp)


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


func _sand() -> void:
	# A grid in dunes (sand_y), and its cut face behind the front glass.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 40
	var nz := 20
	for j in nz:
		for i in nx:
			var quad := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var x: float = -WIDTH / 2.0 + WIDTH * c[0] / nx
				var z: float = -DEPTH / 2.0 + DEPTH * c[1] / nz
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
uniform vec3 light_sand : source_color = vec3(0.62, 0.53, 0.38);
uniform vec3 dark_sand : source_color = vec3(0.36, 0.31, 0.23);
uniform float front_cut = 0.0;
varying vec3 wpos;
""" + CAUSTIC + """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Grains and pebbles.
	vec2 g = floor(wpos.xz * 180.0 + wpos.y * 90.0 * front_cut);
	float grain = hash(g);
	vec2 cell = wpos.xz * 22.0 + vec2(wpos.y * 30.0 * front_cut, 0.0);
	vec2 id = floor(cell);
	float peb = step(0.8, hash(id)) * smoothstep(0.42, 0.3, length(fract(cell) - 0.5));
	vec3 col = mix(dark_sand, light_sand, 0.55 + 0.35 * grain);
	col = mix(col, mix(dark_sand, vec3(0.7, 0.66, 0.6), hash(id + 3.1)), peb * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	// The ripples of light, fainter at the back and on the cut face.
	float c = caustic(wpos.xz * 0.55, TIME * 0.35);
	EMISSION = vec3(0.55, 0.8, 0.85) * c * 0.35 * (1.0 - front_cut) * smoothstep(-0.6, 0.4, wpos.z);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	sand.material_override = mat
	_world.add_child(sand)
	# The cut face: the sand bed seen through the glass, down to the frame.
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := DEPTH / 2.0
	for i in nx:
		var x0 := -WIDTH / 2.0 + WIDTH * i / nx
		var x1 := x0 + WIDTH / nx
		var q := [Vector3(x0, -0.14, z), Vector3(x1, -0.14, z), Vector3(x1, sand_y(x1, z), z), Vector3(x0, sand_y(x0, z), z)]
		for k in [0, 2, 1, 0, 3, 2]:
			face.set_normal(Vector3.BACK)
			face.add_vertex(q[k])
	var cut := MeshInstance3D.new()
	cut.mesh = face.commit()
	var cm: ShaderMaterial = mat.duplicate()
	cm.set_shader_parameter("front_cut", 1.0)
	cm.set_shader_parameter("light_sand", Color(0.5, 0.42, 0.3))
	cm.set_shader_parameter("dark_sand", Color(0.26, 0.21, 0.15))
	cut.material_override = cm
	_world.add_child(cut)


## The back and side panes: deep water fading up to the light.
func _back() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform vec3 deep : source_color = vec3(0.015, 0.06, 0.075);
uniform vec3 high : source_color = vec3(0.09, 0.27, 0.3);
uniform float dim = 1.0;
void fragment() {
	float h = 1.0 - UV.y;
	vec3 col = mix(deep, high, pow(h, 1.6));
	// Soft columns of light from the lamp, drifting.
	col += vec3(0.05, 0.1, 0.1) * pow(0.5 + 0.5 * sin(UV.x * 17.0 + TIME * 0.2 + sin(UV.x * 5.0)), 6.0) * h;
	ALBEDO = col * dim;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, SURFACE + 0.1)
	back.mesh = q
	back.material_override = mat
	back.position = Vector3(0, (SURFACE + 0.1) / 2.0 - 0.02, -DEPTH / 2.0)
	_world.add_child(back)
	for side in [-1.0, 1.0]:
		var pane := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(DEPTH, SURFACE + 0.1)
		pane.mesh = sq
		var sm: ShaderMaterial = mat.duplicate()
		sm.set_shader_parameter("dim", 0.7)
		pane.material_override = sm
		pane.position = Vector3(side * WIDTH / 2.0, (SURFACE + 0.1) / 2.0 - 0.02, 0)
		pane.rotation.y = -side * PI / 2.0
		_world.add_child(pane)
	# The surface from below: a silvery ceiling, rippling.
	var surf_sh := Shader.new()
	surf_sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
varying vec3 wpos;
""" + CAUSTIC + """
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float c = caustic(wpos.xz * 0.8 + 3.0, TIME * 0.4);
	ALBEDO = mix(vec3(0.12, 0.3, 0.33), vec3(0.75, 0.95, 1.0), c * 0.8);
	ALPHA = 0.55 + c * 0.35;
}
"""
	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(WIDTH, DEPTH)
	surf.mesh = pm
	var smat := ShaderMaterial.new()
	smat.shader = surf_sh
	surf.material_override = smat
	surf.position = Vector3(0, SURFACE, 0)
	_world.add_child(surf)


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


## A branch of driftwood lying across the back, reaching up.
func _driftwood() -> void:
	var wood := _mat(Color(0.2, 0.14, 0.09), 0.95)
	var pts := [Vector3(-0.15, 0.14, -0.3), Vector3(0.12, 0.3, -0.26), Vector3(0.3, 0.62, -0.34), Vector3(0.38, 0.8, -0.3)]
	var radius := [0.045, 0.034, 0.022]
	for k in 3:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius[k] * 0.8
		cm.bottom_radius = radius[k]
		cm.height = a.distance_to(b) + 0.02
		cm.radial_segments = 7
		cm.rings = 1
		seg.mesh = cm
		seg.material_override = wood
		seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		seg.position = (a + b) / 2.0
		_world.add_child(seg)
	var twig := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.008
	tm.bottom_radius = 0.018
	tm.height = 0.3
	tm.radial_segments = 5
	twig.mesh = tm
	twig.material_override = wood
	twig.basis = Basis(Quaternion(Vector3.UP, Vector3(-0.6, 1.0, 0.1).normalized()))
	twig.position = Vector3(0.05, 0.4, -0.27)
	_world.add_child(twig)


## Clumps of ribbon weed, swaying.
func _weed() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color : source_color = vec3(0.16, 0.42, 0.18);
void vertex() {
	float h = UV.y;
	float phase = MODEL_MATRIX[3].x * 3.1 + MODEL_MATRIX[3].z * 1.7 + VERTEX.x * 11.0 + VERTEX.z * 7.0;
	VERTEX.x += sin(TIME * 0.8 + phase + h * 2.2) * 0.07 * h * h;
	VERTEX.z += cos(TIME * 0.6 + phase * 1.3 + h * 1.8) * 0.035 * h * h;
}
void fragment() {
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	vec3 base = color * 0.45;
	vec3 tip = color * 1.25 + vec3(0.04, 0.06, 0.0);
	float vein = smoothstep(0.08, 0.0, abs(UV.x - 0.5)) * 0.12;
	ALBEDO = mix(base, tip, UV.y) + vein;
	ROUGHNESS = 0.6;
	// Light through the leaf.
	EMISSION = color * 0.12 * UV.y;
}
"""
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for w in WEED:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in int(w[2]):
			var base := Vector3(rng.randf_range(-0.07, 0.07), 0.0, rng.randf_range(-0.05, 0.05))
			var tall: float = w[3] * rng.randf_range(0.55, 1.0)
			var wide := rng.randf_range(0.024, 0.042)
			var lean := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.12, 0.12)).normalized()
			var face := rng.randf() * TAU
			var across := Vector3(cos(face), 0, sin(face)) * wide / 2.0
			var segs := 7
			var prev_l := Vector3.ZERO
			var prev_r := Vector3.ZERO
			for k in segs + 1:
				var t := float(k) / segs
				var c := base + lean * tall * t + Vector3(lean.x, 0, lean.z) * tall * t * t * 0.4
				var taper := 1.0 - t * 0.6
				var l := c - across * taper
				var r := c + across * taper
				if k > 0:
					var n0 := across.cross(lean).normalized()
					for v in [[prev_l, 0.0, t - 1.0 / segs], [prev_r, 1.0, t - 1.0 / segs], [r, 1.0, t],
							[prev_l, 0.0, t - 1.0 / segs], [r, 1.0, t], [l, 0.0, t]]:
						st.set_normal(n0)
						st.set_uv(Vector2(v[1], v[2]))
						st.add_vertex(v[0])
				prev_l = l
				prev_r = r
		var clump := MeshInstance3D.new()
		clump.mesh = st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color", w[4])
		clump.material_override = mat
		clump.position = Vector3(w[0], sand_y(w[0], w[1]) - 0.01, w[1])
		_world.add_child(clump)


## Shafts of the lamp's light slanting down through the water.
func _light() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform float strength = 0.08;
uniform float seed = 0.0;
void fragment() {
	float across = sin(UV.x * 3.14159);
	float down = smoothstep(1.0, 0.1, UV.y) * smoothstep(0.0, 0.08, UV.y);
	float breathe = 0.6 + 0.4 * sin(TIME * 0.45 + seed * 5.0);
	ALBEDO = vec3(0.6, 0.9, 1.0) * across * across * down * breathe * strength;
}
"""
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 5:
		var shaft := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(0.14, 0.3), SURFACE * 1.05)
		shaft.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("seed", float(i))
		mat.set_shader_parameter("strength", rng.randf_range(0.06, 0.11))
		shaft.material_override = mat
		var x := -0.75 + i * 0.37 + rng.randf_range(-0.08, 0.08)
		shaft.position = Vector3(x, SURFACE * 0.5, rng.randf_range(-0.3, 0.1))
		shaft.rotation = Vector3(0, rng.randf_range(-0.4, 0.4), deg_to_rad(-14))
		_world.add_child(shaft)


## An air stone in the back corner, and its bubbles.
func _bubbles() -> void:
	var stone := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.035
	sm.bottom_radius = 0.04
	sm.height = 0.05
	sm.radial_segments = 8
	stone.mesh = sm
	stone.material_override = _mat(Color(0.3, 0.3, 0.32))
	var at := Vector3(0.68, 0.0, -0.1)
	at.y = sand_y(at.x, at.z) + 0.01
	stone.position = at
	_world.add_child(stone)
	var bubbles := CPUParticles3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.009
	bm.height = 0.018
	bm.radial_segments = 8
	bm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.97, 1.0, 0.55)
	bm.material = mat
	bubbles.mesh = bm
	bubbles.position = at + Vector3(0, 0.03, 0)
	bubbles.amount = 26
	bubbles.lifetime = 2.6
	bubbles.preprocess = 3.0
	bubbles.direction = Vector3.UP
	bubbles.spread = 7.0
	bubbles.gravity = Vector3(0, 0.12, 0)
	bubbles.initial_velocity_min = 0.25
	bubbles.initial_velocity_max = 0.4
	bubbles.scale_amount_min = 0.6
	bubbles.scale_amount_max = 1.6
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.02
	_world.add_child(bubbles)


## The iron frame round the glass, and a glint on the front pane.
func _frame() -> void:
	var iron := _mat(Color(0.06, 0.06, 0.065), 0.45, 0.6)
	var hw := WIDTH / 2.0 + 0.02
	var hd := DEPTH / 2.0 + 0.02
	var top := SURFACE + 0.12
	var bars := [
		# [centre, size]
		[Vector3(0, -0.12, hd), Vector3(WIDTH + 0.1, 0.07, 0.05)],
		[Vector3(0, top, hd), Vector3(WIDTH + 0.1, 0.045, 0.05)],
		[Vector3(0, top, -hd), Vector3(WIDTH + 0.1, 0.045, 0.05)],
		[Vector3(-hw, (top - 0.14) / 2.0, hd), Vector3(0.05, top + 0.16, 0.05)],
		[Vector3(hw, (top - 0.14) / 2.0, hd), Vector3(0.05, top + 0.16, 0.05)],
		[Vector3(-hw, (top - 0.14) / 2.0, -hd), Vector3(0.05, top + 0.16, 0.05)],
		[Vector3(hw, (top - 0.14) / 2.0, -hd), Vector3(0.05, top + 0.16, 0.05)],
		[Vector3(-hw, top, 0), Vector3(0.05, 0.045, DEPTH + 0.06)],
		[Vector3(hw, top, 0), Vector3(0.05, 0.045, DEPTH + 0.06)],
	]
	for b in bars:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		bar.mesh = bm
		bar.material_override = iron
		bar.position = b[0]
		_world.add_child(bar)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled;
void fragment() {
	float d = UV.x * 0.8 + UV.y * 0.45;
	float streak = smoothstep(0.1, 0.0, abs(d - 0.3)) * 0.6 + smoothstep(0.03, 0.0, abs(d - 0.42)) * 0.5;
	ALBEDO = vec3(0.7, 0.85, 0.9) * streak * 0.05;
}
"""
	var glint := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, top + 0.12)
	glint.mesh = q
	var gm := ShaderMaterial.new()
	gm.shader = sh
	glint.material_override = gm
	glint.position = Vector3(0, (top - 0.12) / 2.0, DEPTH / 2.0 + 0.012)
	_world.add_child(glint)


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
				var w := tank.weed_spot()
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
