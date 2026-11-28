class_name CityBuild
extends RefCounted

## User request (the ruined human world - the city): the 3D city's own - the buildings (Ruin) and
## the pavement round them. For now the buildings are shells of our own making (till the user's
## models come, docs/RUINED_WORLD.md): walls the building's own colour - concrete, plaster, brick -
## grimy low down and streaked, a slab line at each storey, windows in bays (most broken and dark
## inside, some with their glass, a few boarded), a shop's ground floor its shopfront (shutters
## down and rusting, or open and dark) under a faded sign; a flat roof, or a broken top (bites
## out of its walls, the top storey gone, its walls' thickness and inside showing); a heap of
## rubble where one came down, a stub of wall standing in it.
##
## The traveller is never lost behind one: what's between the camera and them, round the line to
## them, is seen through (screen-door), and what's very near the camera too, as the trees fade
## (RunView3D.FADE_NEAR..FAR) - SHADER's `hero`, set each frame (update).
##
## User request (the user's models, made ours - tools/make_city_assets.py): a whole block's building
## may be one of the low buildings (Ruin.model); tall towers stand outside the map's top and sides,
## the skyline (skyline); the cars are the remade jeeps, with oil drums, crates and benches about
## (props) - all of them seen through the same way (TEX_SHADER).

## (the pavement round a building: this wide, m; fading out over the last FADE)
const WALK := 2.0
const WALK_FADE := 0.4
## (a broken top: how likely; how many bites out of its walls; the parapet over a roof, m)
const BROKEN := {"shop": 0.45, "flat": 0.6, "tower": 0.5}
const BITES := Vector2i(2, 4)
const PARAPET := 0.5
## (how finely the walls' tops are drawn, m; a wall's thickness)
const STEP := 0.6
const THICK := 0.25
## The buildings' colours (sRGB-ish albedo): concrete, plaster, brick, faded teal, pale pink.
const COLOURS := [Color(0.42, 0.41, 0.39), Color(0.52, 0.47, 0.39), Color(0.44, 0.26, 0.19),
	Color(0.31, 0.39, 0.38), Color(0.52, 0.42, 0.39), Color(0.36, 0.35, 0.34)]
const PX := 27.108

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 hero = vec3(0.0, -100.0, 0.0);
uniform float cut = 2.8;
uniform float fade_min = 5.5;
uniform float fade_max = 8.6;
varying vec3 wp;
varying vec4 tint;
varying vec2 face;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR;
	face = UV2;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}
void fragment() {
	// (seen through: round the line from the camera to the traveller, in front of them; and very
	// near the camera)
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 to_hero = hero - cam;
	float len = length(to_hero);
	vec3 dir = to_hero / max(len, 0.001);
	vec3 rel = wp - cam;
	float t = dot(rel, dir);
	float off = length(rel - dir * t);
	float hide = t < len - 0.4 ? 1.0 - smoothstep(cut * 0.55, cut, off) : 0.0;
	hide = max(hide, 1.0 - smoothstep(fade_min, fade_max, length(rel)));
	if (hide > 0.0 && hide >= bayer4(FRAGCOORD.xy)) {
		discard;
	}
	vec2 uv = UV;
	float seed = tint.a * 97.0;
	vec3 base = tint.rgb;
	float n1 = noise(uv * 1.3 + seed);
	float n2 = noise(uv * 6.0 + seed * 3.0);
	vec3 col = base * (0.85 + 0.25 * n1) * (0.92 + 0.12 * n2);
	float rough = 0.92;
	if (face.x < 0.5) {
		// The outside of a wall: storeys, bays, windows; a shop's front.
		float storey = floor(uv.y / 3.0);
		float in_s = uv.y - storey * 3.0;
		col *= 1.0 - 0.2 * (1.0 - smoothstep(0.0, 0.14, in_s)) * step(0.5, storey);
		col *= mix(0.55, 1.0, smoothstep(0.0, 1.3, uv.y));
		float streak = noise(vec2(uv.x * 3.0, uv.y * 0.15) + seed);
		col *= 1.0 - 0.28 * smoothstep(0.55, 0.85, streak);
		float bay_w = 2.6;
		float bay = floor(uv.x / bay_w);
		float bx = uv.x - bay * bay_w;
		float r = hash(vec2(bay, storey) + seed);
		if (storey < 0.5 && face.y < 0.5) {
			float open = step(0.25, bx) * step(bx, bay_w - 0.25) * step(0.05, in_s) * step(in_s, 2.4);
			if (open > 0.5) {
				if (r < 0.55) {
					float rib = 0.5 + 0.5 * sin(in_s * 40.0);
					vec3 sh = vec3(0.3, 0.29, 0.28) * (0.8 + 0.2 * rib) * (0.8 + 0.4 * noise(uv * 4.0 + seed));
					sh = mix(sh, vec3(0.33, 0.17, 0.08), smoothstep(0.5, 0.9, noise(uv * 2.0 + seed + 5.0)) * 0.6);
					col = sh;
					rough = 0.6;
				} else {
					col = vec3(0.014);
					rough = 1.0;
				}
			}
			float band = step(2.55, in_s) * step(in_s, 2.95);
			if (band > 0.5) {
				vec3 sc = 0.5 + 0.5 * cos(6.2831 * (hash(vec2(floor(uv.x / 7.8), seed)) + vec3(0.0, 0.33, 0.67)));
				col = mix(col, sc * 0.42 * (0.7 + 0.5 * n2), 0.8);
			}
		} else {
			float win = step(0.7, bx) * step(bx, 1.9) * step(0.9, in_s) * step(in_s, 2.3);
			float frame = step(0.6, bx) * step(bx, 2.0) * step(0.8, in_s) * step(in_s, 2.4) - win;
			col = mix(col, col * 1.18, frame);
			if (win > 0.5) {
				if (r < 0.15) {
					col = vec3(0.3, 0.22, 0.14) * (0.75 + 0.35 * noise(vec2(uv.x * 9.0, in_s * 1.5)));
				} else if (r < 0.35) {
					col = vec3(0.05, 0.06, 0.07);
					rough = 0.25;
				} else {
					col = vec3(0.012);
					rough = 1.0;
				}
			}
		}
	} else if (face.x < 1.5) {
		// Inside, where the walls are broken open.
		col = base * 0.3 * (0.8 + 0.3 * n1);
	} else if (face.x < 2.5) {
		// A roof, a broken wall's top: stained, mossy.
		col = base * 0.72 * (0.9 + 0.14 * n1) * (0.92 + 0.1 * n2);
		col *= 1.0 - 0.15 * smoothstep(0.65, 0.9, noise(uv * 0.5 + seed));
		col = mix(col, vec3(0.13, 0.16, 0.08), smoothstep(0.72, 0.9, noise(uv * 0.6 + seed + 3.0)) * 0.3);
	} else {
		// Rubble: broken concrete, bits of brick.
		col = base * (0.62 + 0.5 * n2);
		col = mix(col, vec3(0.42, 0.24, 0.16), smoothstep(0.6, 0.8, noise(uv * 2.5 + seed)) * 0.7);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
"""

static var _shader: Shader
static var _tex_shader: Shader
## Every see-through material made this map (update keeps their `hero`).
static var _seen: Array = []

## The see-through for the models: their own pictures (and normal maps), their vertex colour
## (the cars' dirt and rust) if asked - the same hiding as SHADER's.
const TEX_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform bool use_colour = false;
uniform float roughness = 0.88;
uniform vec3 hero = vec3(0.0, -100.0, 0.0);
uniform float cut = 2.8;
uniform float fade_min = 5.5;
uniform float fade_max = 8.6;
varying vec3 wp;
varying vec4 vcol;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}
float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}
void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 to_hero = hero - cam;
	float len = length(to_hero);
	vec3 dir = to_hero / max(len, 0.001);
	vec3 rel = wp - cam;
	float t = dot(rel, dir);
	float off = length(rel - dir * t);
	float hide = t < len - 0.4 ? 1.0 - smoothstep(cut * 0.55, cut, off) : 0.0;
	hide = max(hide, 1.0 - smoothstep(fade_min, fade_max, length(rel)));
	if (hide > 0.0 && hide >= bayer4(FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = texture(albedo_tex, UV).rgb;
	if (use_colour) {
		c *= vcol.rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
"""
## (the skyline: how far out from the map's edge the towers stand (m), how far apart (m), how big
## against their own size; how much of the map's sides, from the top, they line)
const SKY_OUT := Vector2(6.0, 12.0)
const SKY_GAP := Vector2(16.0, 30.0)
const SKY_SCALE := Vector2(0.4, 0.58)
const SKY_SIDES := 0.75


## The pavement round the buildings, over the ground's grid (`lo` its corner, m; `n` its size;
## `cell` m apart): 0..1 each point, as the ground's path paint.
static func walks(ruins: Array, lo: Vector2, n: Vector2i, cell: float, walk := WALK, fade := WALK_FADE) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n.x * n.y)
	for r in ruins:
		var ruin := r as Ruin
		if ruin.kind == "rubble":
			continue
		var rect := ruin.rect()
		var a := Vector2(rect.position.x / PX, rect.position.y / PX)
		var b := Vector2(rect.end.x / PX, rect.end.y / PX)
		var i0 := maxi(0, int((a.x - walk - lo.x) / cell))
		var i1 := mini(n.x - 1, int((b.x + walk - lo.x) / cell) + 1)
		var j0 := maxi(0, int((a.y - walk - lo.y) / cell))
		var j1 := mini(n.y - 1, int((b.y + walk - lo.y) / cell) + 1)
		for j in range(j0, j1 + 1):
			var z := lo.y + j * cell
			var dz := maxf(maxf(a.y - z, 0.0), z - b.y)
			for i in range(i0, i1 + 1):
				var x := lo.x + i * cell
				var dx := maxf(maxf(a.x - x, 0.0), x - b.x)
				var d := sqrt(dx * dx + dz * dz)
				var k := 1.0 - smoothstep(walk - fade, walk, d)
				if k > out[j * n.x + i]:
					out[j * n.x + i] = k
	return out


## Every building as a model: added to `holder` at its ground (`land_y`: a 2D point's ground
## height). Returns their shared material (its `hero` to be kept up to date: update).
static func build(holder: Node3D, ruins: Array, land_y: Callable) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	_seen = [mat]
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.3, 0.3, 0.3)
	for k in ruins.size():
		var ruin := ruins[k] as Ruin
		var rng := RandomNumberGenerator.new()
		rng.seed = ruin.seed_value
		var at: Vector2 = ruin.global_position
		if ruin.model != "":
			# (its vertex colour on too: the farm set's dirt low down, the Japanese set's colours - white
			# where a model has none)
			var built := _model(ruin.model_path(), "RuinModel%d" % k, shade, true)
			built.rotation.y = ruin.model_yaw
			built.scale = Vector3.ONE * ruin.model_scale
			# (user report "所有物件不可以有穿圖": a model whose own middle isn't over its origin - the
			# scanned grey-brick house, 0.8 m off - stood with its middle on its place, where its
			# footprint and its solid ground are; what stood by its walls stood in them)
			var mid := _middle(built)
			built.position = Vector3(at.x / PX, float(land_y.call(at)), at.y / PX) - built.basis * Vector3(mid.x, 0.0, mid.z)
			holder.add_child(built)
			continue
		var mesh := _rubble(ruin, rng) if ruin.kind == "rubble" else _shell(ruin, rng)
		var mi := MeshInstance3D.new()
		mi.name = "RuinModel%d" % k
		mi.mesh = mesh
		mi.material_override = mat
		# (its shadow cast by a plain twin: the see-through holes are the camera's, not the moon's)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(at.x / PX, float(land_y.call(at)), at.y / PX)
		holder.add_child(mi)
		var caster := MeshInstance3D.new()
		caster.name = "RuinShadow%d" % k
		caster.mesh = mesh
		caster.material_override = shade
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.position = mi.position
		holder.add_child(caster)
	return mat


## The middle of a model's meshes (in its own frame, before it's turned or scaled).
static func _middle(node: Node3D) -> Vector3:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != node:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var bb := m.get_aabb()
		for i in 8:
			var p: Vector3 = t * bb.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
	return (lo + hi) * 0.5 if lo.is_finite() else Vector3.ZERO


## The see-through round the traveller (at `hero`, world).
static func update(mat: ShaderMaterial, hero: Vector3) -> void:
	if mat != null:
		mat.set_shader_parameter("hero", hero)
	for m in _seen:
		if m != mat:
			(m as ShaderMaterial).set_shader_parameter("hero", hero)


## One of the user's models, made ours (`path`, a .glb): its own pictures, seen through as the rest
## (TEX_SHADER); its shadow cast by a plain twin of each part (`shade`). Named `name`.
static var _tex_cut_shader: Shader
## `see`: seen through round the traveller and near the camera (a building, a tower); false for a low
## thing about the street that's never between the camera and them (a car, a drum, a bench).
static func _model(path: String, name: String, shade: Material, colour := false, see := true) -> Node3D:
	if _tex_shader == null:
		_tex_shader = Shader.new()
		_tex_shader.code = TEX_SHADER
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.name = name
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			var own := ShaderMaterial.new()
			# (a cut-out surface - the bamboo's leafy sprigs: its picture's clear parts cut away, seen
			# from both sides - TEX_CUT_SHADER)
			var cut := src != null and src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			if cut and _tex_cut_shader == null:
				_tex_cut_shader = Shader.new()
				_tex_cut_shader.code = TEX_SHADER.replace("render_mode cull_back;", "render_mode cull_disabled;") \
					.replace("ALBEDO = c;", "ALBEDO = c;\n\tALPHA = texture(albedo_tex, UV).a;\n\tALPHA_SCISSOR_THRESHOLD = 0.45;")
			own.shader = _tex_cut_shader if cut else _tex_shader
			if src != null:
				own.set_shader_parameter("albedo_tex", src.albedo_texture)
				own.set_shader_parameter("roughness", src.roughness)
				if src.normal_enabled and src.normal_texture != null:
					own.set_shader_parameter("normal_tex", src.normal_texture)
					own.set_shader_parameter("has_normal", true)
			own.set_shader_parameter("use_colour", colour)
			m.set_surface_override_material(i, own)
			if see:
				_seen.append(own)
			else:
				# (no see-through holes: neither round the traveller nor near the camera)
				own.set_shader_parameter("cut", 0.0)
				own.set_shader_parameter("fade_min", -2.0)
				own.set_shader_parameter("fade_max", -1.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var caster := MeshInstance3D.new()
		caster.mesh = m.mesh
		caster.material_override = shade
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.transform = m.transform
		m.get_parent().add_child(caster)
	return node


## The skyline: the towers (`names`, the remade high-rises) outside the map (`rect`, px) along its
## top and the upper part of its sides - not its foot, where they'd stand between the camera and
## the traveller - SKY_GAP apart, SKY_OUT out from the edge, each its own size and turn.
static func skyline(holder: Node3D, names: Array, rect: Rect2, land_y: Callable, rng: RandomNumberGenerator) -> int:
	if names.is_empty():
		return 0
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.3, 0.3, 0.3)
	var spots := []
	var w := rect.size.x / PX
	var h := rect.size.y / PX
	var x0 := rect.position.x / PX
	var z0 := rect.position.y / PX
	var at := rng.randf_range(0.0, SKY_GAP.x)
	while at < w:
		spots.append(Vector2(x0 + at, z0 - rng.randf_range(SKY_OUT.x, SKY_OUT.y)))
		at += rng.randf_range(SKY_GAP.x, SKY_GAP.y)
	for side in [-1.0, 1.0]:
		at = rng.randf_range(SKY_GAP.x * 0.5, SKY_GAP.y)
		while at < h * SKY_SIDES:
			var x := x0 - rng.randf_range(SKY_OUT.x, SKY_OUT.y) if side < 0.0 else x0 + w + rng.randf_range(SKY_OUT.x, SKY_OUT.y)
			spots.append(Vector2(x, z0 + at))
			at += rng.randf_range(SKY_GAP.x, SKY_GAP.y)
	var made := 0
	for p in spots:
		var name: String = names[rng.randi() % names.size()]
		var tower := _model(Ruin.MODELS_DIR + name + ".glb", "SkylineTower%d" % made, shade)
		# (its foot where the map's edge is - the ground rises out there; sunk a little)
		var edge := Vector2(clampf(p.x, x0, x0 + w), clampf(p.y, z0, z0 + h)) * PX
		tower.position = Vector3(p.x, float(land_y.call(edge)) - 0.5, p.y)
		tower.rotation.y = float(rng.randi() % 4) * PI * 0.5
		tower.scale = Vector3.ONE * rng.randf_range(SKY_SCALE.x, SKY_SCALE.y)
		holder.add_child(tower)
		made += 1
	return made


## A building's shell: four walls round its footprint, its storeys high, a parapet over a flat
## roof - or a broken top: bites out of the walls, the top storey gone, the walls' thickness and
## their inside showing.
static func _shell(ruin: Ruin, rng: RandomNumberGenerator) -> ArrayMesh:
	var w := ruin.size.x / PX
	var d := ruin.size.y / PX
	var h := ruin.height()
	var kind := 0.0 if ruin.kind == "shop" else (1.0 if ruin.kind == "flat" else 2.0)
	var colour: Color = COLOURS[rng.randi() % COLOURS.size()]
	var tint := Color(colour.r, colour.g, colour.b, rng.randf())
	var broken := rng.randf() < float(BROKEN.get(ruin.kind, 0.5)) and ruin.storeys > 1
	var roof := h - (Ruin.STOREY if broken else 0.0)
	# The way round (corners, counter-clockwise seen from above: the outside on the left).
	var corners := [Vector2(-w, -d) * 0.5, Vector2(w, -d) * 0.5, Vector2(w, d) * 0.5, Vector2(-w, d) * 0.5]
	var round_len := 2.0 * (w + d)
	var bites := []
	if broken:
		for _i in rng.randi_range(BITES.x, BITES.y):
			bites.append(Vector3(rng.randf() * round_len, rng.randf_range(1.5, 5.0), rng.randf_range(0.8, Ruin.STOREY + 0.6)))
	var top := func(s: float) -> float:
		if not broken:
			return h + PARAPET
		var dip := 0.0
		for b in bites:
			var along := absf(fposmod(s - b.x + round_len * 0.5, round_len) - round_len * 0.5)
			dip = maxf(dip, b.z * maxf(0.0, 1.0 - along / b.y))
		# (ragged all along)
		dip += 0.35 * absf(sin(s * 2.7 + tint.a * 30.0)) + 0.2 * absf(sin(s * 7.3))
		return maxf(roof + 0.3, h - dip)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s0 := 0.0
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var edge := b - a
		var length := edge.length()
		var out := Vector2(edge.y, -edge.x).normalized()
		var steps := maxi(1, ceili(length / STEP))
		for k in steps:
			var t0 := float(k) / steps
			var t1 := float(k + 1) / steps
			var p0 := a + edge * t0
			var p1 := a + edge * t1
			var h0: float = top.call(s0 + length * t0)
			var h1: float = top.call(s0 + length * t1)
			var u0 := s0 + length * t0
			var u1 := s0 + length * t1
			# (outside)
			_quad(st, Vector3(p0.x, -0.4, p0.y), Vector3(p1.x, -0.4, p1.y), Vector3(p1.x, h1, p1.y), Vector3(p0.x, h0, p0.y),
				Vector3(out.x, 0.0, out.y), Vector2(u0, -0.4), Vector2(u1, -0.4), Vector2(u1, h1), Vector2(u0, h0), tint, Vector2(0.0, kind))
			if broken:
				# (inside, set in by the wall's thickness, and the wall's top between)
				var q0 := p0 - out * THICK
				var q1 := p1 - out * THICK
				_quad(st, Vector3(q1.x, roof, q1.y), Vector3(q0.x, roof, q0.y), Vector3(q0.x, h0, q0.y), Vector3(q1.x, h1, q1.y),
					Vector3(-out.x, 0.0, -out.y), Vector2(u1, roof), Vector2(u0, roof), Vector2(u0, h0), Vector2(u1, h1), tint, Vector2(1.0, kind))
				_quad(st, Vector3(p0.x, h0, p0.y), Vector3(p1.x, h1, p1.y), Vector3(q1.x, h1, q1.y), Vector3(q0.x, h0, q0.y),
					Vector3.UP, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, THICK), Vector2(u0, THICK), tint, Vector2(2.0, kind))
		s0 += length
	# The roof (or the floor the broken top's left).
	var in_by := THICK if broken else 0.0
	var r0 := Vector2(-w * 0.5 + in_by, -d * 0.5 + in_by)
	var r1 := Vector2(w * 0.5 - in_by, d * 0.5 - in_by)
	_quad(st, Vector3(r0.x, roof, r1.y), Vector3(r1.x, roof, r1.y), Vector3(r1.x, roof, r0.y), Vector3(r0.x, roof, r0.y),
		Vector3.UP, Vector2(r0.x, r1.y), Vector2(r1.x, r1.y), Vector2(r1.x, r0.y), Vector2(r0.x, r0.y), tint, Vector2(2.0, kind))
	if not broken:
		# (the parapet's inside, down to the roof)
		for e in 4:
			var a: Vector2 = corners[e]
			var b: Vector2 = corners[(e + 1) % 4]
			var edge := b - a
			var out := Vector2(edge.y, -edge.x).normalized()
			_quad(st, Vector3(b.x, h, b.y), Vector3(a.x, h, a.y), Vector3(a.x, h + PARAPET, a.y), Vector3(b.x, h + PARAPET, b.y),
				Vector3(-out.x, 0.0, -out.y), Vector2(0, h), Vector2(edge.length(), h), Vector2(edge.length(), h + PARAPET), Vector2(0, h + PARAPET), tint, Vector2(1.0, kind))
	st.generate_tangents()
	return st.commit()


## A heap where one came down: a mound of broken concrete over its footprint, ragged, and a stub
## of a wall standing up out of it.
static func _rubble(ruin: Ruin, rng: RandomNumberGenerator) -> ArrayMesh:
	var w := ruin.size.x / PX
	var d := ruin.size.y / PX
	var colour: Color = COLOURS[rng.randi() % COLOURS.size()]
	var tint := Color(colour.r, colour.g, colour.b, rng.randf())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var u := float(i) / n * 2.0 - 1.0
			var v := float(j) / n * 2.0 - 1.0
			var dome := maxf(0.0, (1.0 - u * u) * (1.0 - v * v))
			hs[j * (n + 1) + i] = Ruin.RUBBLE_HIGH * pow(dome, 0.6) * (0.65 + 0.5 * noise.get_noise_2d(i, j)) - 0.15
	for j in n:
		for i in n:
			var p := []
			for c in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var x := (float(c.x) / n - 0.5) * w * 1.06
				var z := (float(c.y) / n - 0.5) * d * 1.06
				p.append(Vector3(x, hs[c.y * (n + 1) + c.x], z))
			var nrm: Vector3 = ((p[2] - p[0]) as Vector3).cross(p[1] - p[0]).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			_quad(st, p[3], p[2], p[1], p[0], nrm, Vector2(p[3].x, p[3].z), Vector2(p[2].x, p[2].z),
				Vector2(p[1].x, p[1].z), Vector2(p[0].x, p[0].z), tint, Vector2(3.0, 0.0))
	# (a stub of wall still standing, along one side)
	var side := rng.randi() % 4
	var along := w if side % 2 == 0 else d
	var len := along * rng.randf_range(0.3, 0.6)
	var high := rng.randf_range(1.6, 3.8)
	var start := rng.randf_range(-along * 0.5, along * 0.5 - len)
	var steps := maxi(2, ceili(len / STEP))
	for k in steps:
		var t0 := start + len * float(k) / steps
		var t1 := start + len * float(k + 1) / steps
		var h0 := high * (0.55 + 0.45 * absf(sin(t0 * 2.1 + tint.a * 9.0)))
		var h1 := high * (0.55 + 0.45 * absf(sin(t1 * 2.1 + tint.a * 9.0)))
		var off := (d if side % 2 == 0 else w) * 0.45 * (1.0 if side < 2 else -1.0)
		var p0 := Vector3(t0, -0.2, off) if side % 2 == 0 else Vector3(off, -0.2, t0)
		var p1 := Vector3(t1, -0.2, off) if side % 2 == 0 else Vector3(off, -0.2, t1)
		var nrm := Vector3(0, 0, 1) if side % 2 == 0 else Vector3(1, 0, 0)
		for face: float in [1.0, -1.0]:
			var o := nrm * THICK * 0.5 * face
			var a0 := p0 + o
			var a1 := p1 + o
			var top0 := a0 + Vector3(0, h0 + 0.2, 0)
			var top1 := a1 + Vector3(0, h1 + 0.2, 0)
			if face > 0.0:
				_quad(st, a0, a1, top1, top0, nrm, Vector2(t0, 0), Vector2(t1, 0), Vector2(t1, h1), Vector2(t0, h0), tint, Vector2(0.0, 1.0))
			else:
				_quad(st, a1, a0, top0, top1, -nrm, Vector2(t1, 0), Vector2(t0, 0), Vector2(t0, h0), Vector2(t1, h1), tint, Vector2(0.0, 1.0))
	st.generate_tangents()
	return st.commit()


## One quad (corners a, b, c, d in order round it), `nrm` its normal (the side it's seen from),
## `uv` per corner (m), the building's tint (its seed in alpha), `face` (kind of face, kind of
## building). (Wound clockwise as seen from `nrm`'s side - Godot's front - whichever way round the
## corners were given.)
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, tint: Color, face: Vector2) -> void:
	var order := [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]
	if (b - a).cross(c - a).dot(nrm) > 0.0:
		order = [[a, ua], [d, ud], [c, uc], [a, ua], [c, uc], [b, ub]]
	for pair in order:
		st.set_normal(nrm)
		st.set_color(tint)
		st.set_uv(pair[1])
		st.set_uv2(face)
		st.add_vertex(pair[0])


## The cars' paint (faded: rust red, dirty white, a dull blue, a taxi's yellow, olive) and the
## lamps' iron; a lit lamp's light (sRGB, energy, reach m).
const CAR_PAINTS := [Color(0.45, 0.16, 0.12), Color(0.62, 0.6, 0.55), Color(0.2, 0.3, 0.42), Color(0.7, 0.55, 0.15),
	Color(0.27, 0.29, 0.24)]
const IRON := Color(0.2, 0.22, 0.21)
const LAMP_LIGHT := Color(1.0, 0.82, 0.55)
const LAMP_ENERGY := 1.6
const LAMP_RANGE := 8.0
static var _prop_mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D


## The streets' cars and lamps (StreetProp), each a shape of our own, at its ground.
static func props(holder: Node3D, list: Array, land_y: Callable) -> void:
	if _prop_mat == null:
		_prop_mat = StandardMaterial3D.new()
		_prop_mat.vertex_color_use_as_albedo = true
		_prop_mat.roughness = 0.75
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.albedo_color = LAMP_LIGHT
		_glow_mat.emission_enabled = true
		_glow_mat.emission = LAMP_LIGHT
		_glow_mat.emission_energy_multiplier = 2.5
	for k in list.size():
		var sp := list[k] as StreetProp
		var rng := RandomNumberGenerator.new()
		rng.seed = sp.seed_value
		var node: Node3D
		match sp.kind:
			"lamp":
				node = _lamp(sp, rng)
			_:
				node = _prop_model(sp, rng)
		node.name = "StreetPropModel%d" % k
		var at: Vector2 = sp.global_position
		node.position = Vector3(at.x / PX, float(land_y.call(at)), at.y / PX)
		node.rotation.y = -sp.yaw
		holder.add_child(node)


## A car (one of the remade jeeps, at random), an oil drum, a crate, a bench - the user's models,
## made ours - their dirt and rust in their vertex colour; a car leant a little on a flat tyre.
## User report ("車子被燈光照射的呈現沒有做好"): drawn whole by the lamp's light - the buildings' see-through
## dots (round the traveller, near the camera) cut holes in a car beside them; these are low things,
## never between the camera and the traveller, so they're not seen through.
static func _prop_model(sp: StreetProp, rng: RandomNumberGenerator) -> Node3D:
	var name := "city_" + sp.kind
	if sp.kind == "car":
		name = "city_car_%d" % (rng.randi() % 4 + 1)
	elif sp.kind == "bench":
		name = "city_bench_%d" % (rng.randi() % 2 + 1)
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.3, 0.3, 0.3)
	var holder := Node3D.new()
	var model := _model(Ruin.MODELS_DIR + name + ".glb", "Model", shade, true, false)
	holder.add_child(model)
	if sp.kind == "car":
		model.rotation = Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.03, 0.03))
	elif sp.kind == "drum" and rng.randf() < 0.3:
		# (one knocked over)
		model.rotation.z = PI * 0.5
		model.position.y = 0.28
	return holder


## (the old box car - kept for a map without the models)
## A car left where it stopped: body, cabin, dark windows, wheels (one flat, so it leans), its
## paint faded and dirtied.
static func _car(rng: RandomNumberGenerator) -> Node3D:
	var paint: Color = CAR_PAINTS[rng.randi() % CAR_PAINTS.size()]
	paint = paint.darkened(rng.randf_range(0.0, 0.25))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := Color(0.04, 0.045, 0.05)
	var tyre := Color(0.06, 0.06, 0.06)
	_box(st, Vector3(0.0, 0.62, 0.0), Vector3(4.1, 0.62, 1.74), paint, rng)
	_box(st, Vector3(-0.25, 1.17, 0.0), Vector3(2.05, 0.5, 1.56), glass, rng)
	_box(st, Vector3(-0.25, 1.46, 0.0), Vector3(1.95, 0.08, 1.5), paint, rng)
	for x in [-1.3, 1.3]:
		for z in [-0.8, 0.8]:
			_box(st, Vector3(x, 0.3, z), Vector3(0.64, 0.6, 0.24), tyre, rng)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _prop_mat
	var holder := Node3D.new()
	holder.add_child(mi)
	# (a flat tyre: leant a little to one side or one end)
	mi.rotation = Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.04, 0.04))
	return holder


## A street lamp: its post, its arm, its head - some leaning; a lit one's head glowing, its light
## shining down on the pavement.
static func _lamp(sp: StreetProp, rng: RandomNumberGenerator) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.0, 2.3, 0.0), Vector3(0.13, 4.6, 0.13), IRON, rng)
	_box(st, Vector3(0.62, 4.56, 0.0), Vector3(1.3, 0.08, 0.08), IRON, rng)
	if not sp.lit:
		_box(st, Vector3(1.2, 4.48, 0.0), Vector3(0.5, 0.14, 0.26), IRON.lightened(0.15), rng)
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _prop_mat
	holder.add_child(mi)
	if sp.lit:
		var head := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.14, 0.26)
		head.mesh = box
		head.material_override = _glow_mat
		head.position = Vector3(1.2, 4.48, 0.0)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(head)
		var light := OmniLight3D.new()
		light.name = "LampLight"
		light.light_color = LAMP_LIGHT
		light.light_energy = LAMP_ENERGY
		light.omni_range = LAMP_RANGE
		light.shadow_enabled = false
		light.position = Vector3(1.2, 4.1, 0.0)
		holder.add_child(light)
	else:
		# (a dead one leans, now and then)
		if rng.randf() < 0.35:
			holder.rotation.z = rng.randf_range(-0.14, 0.14)
	return holder


## A box (`size`, its middle at `at`) of one colour, a little dirtier low down.
static func _box(st: SurfaceTool, at: Vector3, size: Vector3, col: Color, rng: RandomNumberGenerator) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.DOWN, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
		[Vector3.RIGHT, [Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3.LEFT, [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.BACK, [Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3.FORWARD, [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
	]
	var grime := rng.randf_range(0.82, 1.0)
	for f in faces:
		var c: Array = f[1]
		var shade := col * grime
		shade.a = 1.0
		_quad(st, at + c[0], at + c[1], at + c[2], at + c[3], f[0], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, shade, Vector2.ZERO)
