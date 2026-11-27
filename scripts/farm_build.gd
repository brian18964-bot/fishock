class_name FarmBuild
extends RefCounted

## User request (the human world's countryside - an ordinary place, not a ruin): its farms seen in
## 3D. The farmhouses and barns are Ruins of kind "model" (CityBuild.build shows them, seen through
## round the traveller as the city's are); here the rest: the ground's paint for the tracks and the
## fields (tracks_grid, fields_grid - RunView3D's ground), what stands about (props: the user's farm
## set, made ours by tools/make_farm_assets.py - lanterns, wells, logs, wagons, fruit trees - and
## round hay bales of our own), the fences (ours) and the crops in their rows (pumpkins, greens).

const PX := 27.108
## (a field's ground blends into the meadow over this much, m)
const FIELD_FADE := 0.6
## (a track's edge: how soft, m; the ground worn bare round a farm building - how far out, how soft)
const TRACK_FADE := 0.5
const YARD_WORN := 1.6
const YARD_FADE := 1.3
## The rows of the ploughed earth (tools/make_ground.py's FURROWS a 4 m tile - every 4/7 m in the
## world's z) - the crops grow on them.
const ROW := 4.0 / 7.0
## (pumpkins: every second row, so far apart along it, m; how big against the model - 0.4-0.57 m
## across; greens every row, so far apart)
const PUMPKIN_STEP := Vector2(1.4, 2.3)
const PUMPKIN_SIZE := Vector2(0.9, 1.3)
const GREENS_STEP := Vector2(0.85, 1.15)
const GREENS_SIZE := Vector2(0.8, 1.1)
## (the fences: a post this often, m; its height; the rails' heights; the wood's colour)
const FENCE_POST := 2.2
const FENCE_HIGH := 1.15
const FENCE_RAILS := [0.45, 0.88]
const FENCE_WOOD := Color(0.36, 0.29, 0.21)
## (the Japanese village's bamboo fences: a post this often, m; their height; the rails' heights; a
## cane this often; the dried bamboo's colour)
const BAMBOO_POST := 1.8
const BAMBOO_HIGH := 1.2
const BAMBOO_RAILS := [0.35, 0.68, 0.98]
const BAMBOO_CANE := 0.28
const BAMBOO := Color(0.6, 0.56, 0.34)
## (the English village's dry-stone walls: their height, courses, thickness at the foot, a stone's
## length (m), their grey; its hedges: their height, thickness, a lump's length, their green)
const WALL_HIGH := 0.78
const WALL_COURSES := 3
const WALL_THICK := 0.55
const WALL_STONE := Vector2(0.32, 0.7)
const WALL_GREY := Color(0.44, 0.42, 0.38)
const HEDGE_HIGH := 1.15
const HEDGE_THICK := 0.85
const HEDGE_LUMP := Vector2(0.7, 1.3)
const HEDGE_GREEN := Color(0.11, 0.2, 0.065)
## User request ("中國風第 11 章"): the Chinese village's wall - white plaster (TILE_WALL_WHITE) on a grey
## stone footing, under a ridge of dark tiles (TILE_WALL_TILE) that overhangs it each side; its
## height, thickness and footing (m); the plaster stained a shade each span (TILE_WALL_SPAN m).
const TILE_WALL_HIGH := 1.3
const TILE_WALL_THICK := 0.4
const TILE_WALL_FOOT := 0.25
const TILE_WALL_CAP := 0.24
const TILE_WALL_EAVE := 0.14
const TILE_WALL_SPAN := 2.4
const TILE_WALL_WHITE := Color(0.84, 0.82, 0.76)
const TILE_WALL_STONE := Color(0.42, 0.41, 0.39)
const TILE_WALL_TILE := Color(0.14, 0.145, 0.155)
## User request (the adobe village - "換成土屋主題"): its wall of mud brick - plastered, its top rounded
## off by the rain, a shade lighter where the sun's bleached it, each span (MUD_WALL_SPAN m) a little its
## own height and lean; its height and thickness (m).
const MUD_WALL_HIGH := 1.05
const MUD_WALL_THICK := 0.45
const MUD_WALL_SPAN := 1.6
const MUD_WALL := Color(0.55, 0.42, 0.29)
## (a round bale: its radius and length, m; its straw)
const BALE_R := 0.72
const BALE_LONG := 1.25
const BALE_STRAW := Color(0.66, 0.53, 0.28)
## (a lit lantern's light: sRGB, energy, reach m)
const LANTERN_LIGHT := Color(1.0, 0.78, 0.48)
const LANTERN_ENERGY := 2.2
const LANTERN_RANGE := 7.0
## The yard things' models (StreetProp kinds; several - one picked by its own dice).
const MODELS := {"lantern": ["farm_lantern"], "well": ["farm_well_1", "farm_well_2"], "logs": ["farm_logs_1"],
	"lumber": ["farm_logs_2"], "barrel": ["farm_barrel"], "wagon": ["farm_wagon"], "barrow": ["farm_barrow"],
	"trough": ["farm_trough"], "milk": ["farm_milk"], "fruit": ["farm_fruit_1", "farm_fruit_2", "farm_fruit_3"]}

## (what grows - each its own size a little)
const GROWN := ["fruit", "bamboo"]
## (the crops that bend in the wind - the pumpkins lie still)
const SWAYING_CROPS := ["farm_greens"]

static var _wood_mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D
static var _bale_mesh: ArrayMesh


## The tracks on the ground's grid (`lo` m, `n` cells of `cell` m): 1 on a track, 0 off it, soft at
## its edge - `tracks` px polylines `half_px` wide each side.
static func tracks_grid(tracks: Array, half_px: float, lo: Vector2, n: Vector2i, cell: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n.x * n.y)
	var half := half_px / PX
	for line in tracks:
		var pts := line as PackedVector2Array
		for s in pts.size() - 1:
			var a := pts[s] / PX
			var b := pts[s + 1] / PX
			var i0 := maxi(0, int((minf(a.x, b.x) - half - lo.x) / cell))
			var i1 := mini(n.x - 1, int((maxf(a.x, b.x) + half - lo.x) / cell) + 1)
			var j0 := maxi(0, int((minf(a.y, b.y) - half - lo.y) / cell))
			var j1 := mini(n.y - 1, int((maxf(a.y, b.y) + half - lo.y) / cell) + 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var p := Vector2(lo.x + i * cell, lo.y + j * cell)
					var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)
					var k := 1.0 - smoothstep(half - TRACK_FADE, half, d)
					if k > out[j * n.x + i]:
						out[j * n.x + i] = k
	return out


## The fields on the ground's grid: [the ploughed earth (the ploughed fields and those in rows),
## the stubble], each 1 inside a field, fading out over FIELD_FADE past its edge.
static func fields_grid(fields: Array, lo: Vector2, n: Vector2i, cell: float) -> Array:
	var plough := PackedFloat32Array()
	plough.resize(n.x * n.y)
	var stubble := PackedFloat32Array()
	stubble.resize(n.x * n.y)
	for f in fields:
		var field := f as FarmField
		var a := field.rect.position / PX
		var b := field.rect.end / PX
		if field.crop == "pasture":
			# (a pasture's grass the meadow's own)
			continue
		var into := stubble if field.crop == "stubble" else plough
		var i0 := maxi(0, int((a.x - FIELD_FADE - lo.x) / cell))
		var i1 := mini(n.x - 1, int((b.x + FIELD_FADE - lo.x) / cell) + 1)
		var j0 := maxi(0, int((a.y - FIELD_FADE - lo.y) / cell))
		var j1 := mini(n.y - 1, int((b.y + FIELD_FADE - lo.y) / cell) + 1)
		for j in range(j0, j1 + 1):
			var z := lo.y + j * cell
			var dz := maxf(maxf(a.y - z, 0.0), z - b.y)
			for i in range(i0, i1 + 1):
				var x := lo.x + i * cell
				var dx := maxf(maxf(a.x - x, 0.0), x - b.x)
				var k := 1.0 - smoothstep(0.0, FIELD_FADE, sqrt(dx * dx + dz * dz))
				if k > into[j * n.x + i]:
					into[j * n.x + i] = k
	return [plough, stubble]


## What stands about the farms (StreetProps of the farm's kinds), each at its ground.
static func props(holder: Node3D, list: Array, land_y: Callable) -> void:
	_materials()
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.3, 0.3, 0.3)
	for k in list.size():
		var sp := list[k] as StreetProp
		var rng := RandomNumberGenerator.new()
		rng.seed = sp.seed_value
		var node := Node3D.new()
		if sp.kind == "bale":
			node.add_child(_bale(rng))
		elif sp.model != "" or MODELS.has(sp.kind):
			# (its theme's model for it, or its kind's)
			var name := sp.model
			if name == "":
				var names: Array = MODELS[sp.kind]
				name = names[rng.randi() % names.size()]
			var model := _swaying(Ruin.path_of(name)) if sp.kind in GROWN else CityBuild._model(Ruin.path_of(name), "Model", shade, true)
			# (its long way along the prop's heading - the way its solid ground lies)
			var size: Array = Ruin.info(name).get("size", [1, 1, 1])
			if float(size[1]) > float(size[0]):
				model.rotation.y = PI * 0.5
			if sp.kind in GROWN:
				model.scale = Vector3.ONE * rng.randf_range(0.95, 1.2)
			node.add_child(model)
			if sp.lit:
				_light(node, name)
		else:
			continue
		node.name = "FarmProp%d" % k
		var at: Vector2 = sp.global_position
		node.position = Vector3(at.x / PX, float(land_y.call(at)), at.y / PX)
		node.rotation.y = -sp.yaw
		holder.add_child(node)


## User request ("風吹動態"): what grows in the yards - the bamboo clumps, the fruit trees - bends in
## the wind as the map's trees do (Foliage: its own pictures, its foot still, its top leaning, its
## leaves fluttering - cut out by their picture's alpha), not standing stiff as the buildings do.
static func _swaying(path: String) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.name = "Model"
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var src := m.mesh
		var dressed := Foliage.dress(src)
		for s in dressed.get_surface_count():
			var was := src.surface_get_material(s) as BaseMaterial3D
			var mat := dressed.surface_get_material(s) as ShaderMaterial
			if was != null and mat != null and was.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mat.set_shader_parameter("scissor", true)
				mat.set_shader_parameter("scissor_cut", 0.45)
		m.mesh = dressed
	return node


## A lit lantern: its lamp glowing, its light on the track round it.
static func _light(node: Node3D, name: String) -> void:
	var lamp: Array = Ruin.info(name).get("lamp", [0.0, 2.1, 0.5])
	var at := Vector3(float(lamp[0]), float(lamp[1]), float(lamp[2]))
	var glow := MeshInstance3D.new()
	glow.name = "LanternGlow"
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.26
	glow.mesh = ball
	glow.material_override = _glow_mat
	glow.position = at + Vector3(0.0, 0.12, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glow)
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.light_color = LANTERN_LIGHT
	light.light_energy = LANTERN_ENERGY
	light.omni_range = LANTERN_RANGE
	light.shadow_enabled = false
	light.position = at
	node.add_child(light)


## A round hay bale lying on its side (our own): its straw wound round - darker bands about it, the
## rolled spiral on its ends - settled a little flat where it lies.
static func _bale(rng: RandomNumberGenerator) -> MeshInstance3D:
	if _bale_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 18
		for s in seg:
			var a0 := TAU * s / seg
			var a1 := TAU * (s + 1) / seg
			for x0: float in [-0.5, -0.25, 0.0, 0.25]:
				var x1 := x0 + 0.25
				var quad := []
				for c in [[x0, a0], [x1, a0], [x1, a1], [x0, a1]]:
					var p := _bale_at(c[0] * BALE_LONG, c[1])
					quad.append(p)
				var n := Vector3(0.0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
				var band := 0.9 + 0.1 * sin(x0 * 40.0) - (0.06 if s % 3 == 0 else 0.0)
				var col := BALE_STRAW * band
				col.a = 1.0
				_tri(st, quad[0], quad[1], quad[2], n, col)
				_tri(st, quad[0], quad[2], quad[3], n, col)
			for side: float in [-1.0, 1.0]:
				var rim0 := _bale_at(side * BALE_LONG * 0.5, a0)
				var rim1 := _bale_at(side * BALE_LONG * 0.5, a1)
				var mid := Vector3(side * BALE_LONG * 0.5, BALE_R * 0.92, 0.0)
				var ring := [mid, mid.lerp(rim0, 0.35), mid.lerp(rim1, 0.35), mid.lerp(rim0, 0.7), mid.lerp(rim1, 0.7), rim0, rim1]
				var shades := [0.82, 0.95, 0.78, 0.9]
				var tris := [[0, 1, 2], [1, 3, 4], [1, 4, 2], [3, 5, 6], [3, 6, 4]]
				for k in tris.size():
					var col := BALE_STRAW * float(shades[mini(k, 3)])
					col.a = 1.0
					var tri: Array = tris[k]
					_tri(st, ring[tri[0]], ring[tri[1]], ring[tri[2]], Vector3(side, 0.0, 0.0), col)
		_bale_mesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _bale_mesh
	mi.material_override = _wood_mat
	# (each its own size a little)
	mi.scale = Vector3.ONE * rng.randf_range(0.92, 1.06)
	return mi


## A point on the bale's round side (`x` along it, `a` round it), settled flat underneath.
static func _bale_at(x: float, a: float) -> Vector3:
	var y := BALE_R * 0.92 + sin(a) * BALE_R * 0.92
	return Vector3(x, y, cos(a) * BALE_R)


## Every fence - one mesh, each of its kind (Fence.style): the countryside's posts and rails, its wood
## weathered piece by piece; the Japanese village's bamboo; the English dry-stone walls and hedges.
static func fences(holder: Node3D, list: Array, land_y: Callable) -> void:
	if list.is_empty():
		return
	_materials()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in list:
		var fence := f as Fence
		var rng := RandomNumberGenerator.new()
		rng.seed = fence.seed_value
		var ends := fence.ends()
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		match fence.style:
			"bamboo":
				_bamboo_fence(st, a, b, land_y, rng)
			"stone":
				_stone_wall(st, a, b, land_y, rng)
			"hedge":
				_hedge(st, a, b, land_y, rng)
			"tile_wall":
				_tile_wall(st, a, b, land_y, rng)
			"mud_wall":
				_mud_wall(st, a, b, land_y, rng)
			_:
				_wood_fence(st, a, b, land_y, rng)
	var mi := MeshInstance3D.new()
	mi.name = "Fences"
	mi.mesh = st.commit()
	mi.material_override = _wood_mat
	holder.add_child(mi)


## (a point along a fence from `a` to `b` (px), `t` of the way, at its ground - m)
static func _along(a: Vector2, b: Vector2, t: float, land_y: Callable) -> Vector3:
	var p2 := a.lerp(b, t)
	return Vector3(p2.x / PX, float(land_y.call(p2)), p2.y / PX)


static func _wood_fence(st: SurfaceTool, a: Vector2, b: Vector2, land_y: Callable, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b) / PX
	var posts := maxi(1, ceili(length / FENCE_POST))
	var tops := []
	for i in posts + 1:
		var at := _along(a, b, float(i) / float(posts), land_y)
		var high := FENCE_HIGH * rng.randf_range(0.93, 1.05)
		var wood := _shade(FENCE_WOOD, rng, 0.8, 1.12)
		var lean := Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
		_beam(st, at, at + Vector3(0.0, high, 0.0) + lean, 0.065, wood)
		tops.append(at + lean * 0.5)
	for i in posts:
		for h: float in FENCE_RAILS:
			var p0: Vector3 = tops[i] + Vector3(0.0, h + rng.randf_range(-0.03, 0.03), 0.0)
			var p1: Vector3 = tops[i + 1] + Vector3(0.0, h + rng.randf_range(-0.03, 0.03), 0.0)
			_beam(st, p0, p1, 0.04, _shade(FENCE_WOOD, rng, 0.85, 1.15))


## A bamboo fence (the Japanese village's four-eyed fence): thick bamboo posts, thin canes upright
## close along it, three rails across them, the bamboo dried pale and yellowing.
static func _bamboo_fence(st: SurfaceTool, a: Vector2, b: Vector2, land_y: Callable, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b) / PX
	var posts := maxi(1, ceili(length / BAMBOO_POST))
	for i in posts + 1:
		var at := _along(a, b, float(i) / float(posts), land_y)
		_beam(st, at, at + Vector3(0.0, BAMBOO_HIGH * rng.randf_range(0.97, 1.03), 0.0), 0.05, _shade(BAMBOO, rng, 0.85, 1.05))
	var canes := maxi(2, ceili(length / BAMBOO_CANE))
	var side := Vector3(-(b - a).normalized().y, 0.0, (b - a).normalized().x) * 0.03
	for i in canes + 1:
		var at := _along(a, b, float(i) / float(canes), land_y) + side * (1.0 if i % 2 == 0 else -1.0)
		_beam(st, at, at + Vector3(0.0, BAMBOO_HIGH * 0.88, 0.0), 0.02, _shade(BAMBOO, rng, 0.8, 1.1))
	for h: float in BAMBOO_RAILS:
		for i in posts:
			var p0 := _along(a, b, float(i) / float(posts), land_y) + Vector3(0.0, h, 0.0)
			var p1 := _along(a, b, float(i + 1) / float(posts), land_y) + Vector3(0.0, h, 0.0)
			_beam(st, p0, p1, 0.024, _shade(BAMBOO, rng, 0.75, 0.95))


## A dry-stone wall (the English village's): courses of rough stones of their own lengths and greys,
## a row of capstones on edge along its top.
static func _stone_wall(st: SurfaceTool, a: Vector2, b: Vector2, land_y: Callable, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b) / PX
	var dir2 := (b - a).normalized()
	var along := Vector3(dir2.x, 0.0, dir2.y)
	var course := WALL_HIGH / float(WALL_COURSES)
	for c in WALL_COURSES:
		var at := rng.randf_range(0.0, 0.25) if c % 2 == 1 else 0.0
		var thick := lerpf(WALL_THICK, WALL_THICK * 0.8, float(c) / float(WALL_COURSES))
		while at < length - 0.05:
			var stone := minf(rng.randf_range(WALL_STONE.x, WALL_STONE.y), length - at)
			var mid := _along(a, b, (at + stone * 0.5) / length, land_y)
			mid.y += course * (float(c) + 0.5) + rng.randf_range(-0.02, 0.02)
			_slab(st, mid, along, Vector3(stone - 0.03, course - 0.02, thick + rng.randf_range(-0.04, 0.04)), _shade(WALL_GREY, rng, 0.8, 1.18), rng)
			at += stone
	var at := 0.0
	while at < length - 0.05:
		var cap := minf(rng.randf_range(0.16, 0.28), length - at)
		var mid := _along(a, b, (at + cap * 0.5) / length, land_y)
		mid.y += WALL_HIGH + 0.08
		_slab(st, mid, along, Vector3(cap - 0.02, 0.18 + rng.randf_range(-0.03, 0.03), WALL_THICK * 0.75), _shade(WALL_GREY, rng, 0.75, 1.1), rng)
		at += cap


## The Chinese village's wall: span by span along it, a grey stone footing, the white plaster wall
## on it (each span its own faint stain), and over it a ridge of dark tiles sloping down each side past
## the wall, ridged along its top.
static func _tile_wall(st: SurfaceTool, a: Vector2, b: Vector2, land_y: Callable, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b) / PX
	var dir2 := (b - a).normalized()
	var along := Vector3(dir2.x, 0.0, dir2.y)
	var side := along.cross(Vector3.UP).normalized()
	var spans := maxi(1, ceili(length / TILE_WALL_SPAN))
	var span := length / float(spans)
	for i in spans:
		var mid := _along(a, b, (float(i) + 0.5) / float(spans), land_y)
		var foot := mid + Vector3(0.0, TILE_WALL_FOOT * 0.5, 0.0)
		_slab(st, foot, along, Vector3(span + 0.01, TILE_WALL_FOOT, TILE_WALL_THICK + 0.06), _shade(TILE_WALL_STONE, rng, 0.85, 1.12), rng)
		var body := mid + Vector3(0.0, TILE_WALL_FOOT + (TILE_WALL_HIGH - TILE_WALL_FOOT) * 0.5, 0.0)
		_slab(st, body, along, Vector3(span + 0.01, TILE_WALL_HIGH - TILE_WALL_FOOT, TILE_WALL_THICK), _shade(TILE_WALL_WHITE, rng, 0.9, 1.03), rng)
		# (the tiles: two slopes from the ridge out past each face, and the ridge along the top)
		var p0 := _along(a, b, float(i) / float(spans), land_y)
		var p1 := _along(a, b, float(i + 1) / float(spans), land_y)
		var top := TILE_WALL_HIGH + TILE_WALL_CAP
		var eave := TILE_WALL_THICK * 0.5 + TILE_WALL_EAVE
		var tile := _shade(TILE_WALL_TILE, rng, 0.85, 1.15)
		var under := tile * 0.7
		under.a = 1.0
		for s: float in [-1.0, 1.0]:
			var r0 := p0 + Vector3(0.0, top, 0.0)
			var r1 := p1 + Vector3(0.0, top, 0.0)
			var e0 := p0 + side * (eave * s) + Vector3(0.0, TILE_WALL_HIGH - 0.02, 0.0)
			var e1 := p1 + side * (eave * s) + Vector3(0.0, TILE_WALL_HIGH - 0.02, 0.0)
			var n := (side * s * TILE_WALL_CAP + Vector3.UP * eave).normalized()
			_tri(st, r0, r1, e1, n, tile)
			_tri(st, r0, e1, e0, n, tile)
			# (the slope's underside, seen from below the eave)
			_tri(st, r0, e1, r1, -n, under)
			_tri(st, r0, e0, e1, -n, under)
		var ridge := (p0 + p1) * 0.5 + Vector3(0.0, top + 0.04, 0.0)
		_slab(st, ridge, along, Vector3(span + 0.02, 0.09, 0.12), tile * 0.9, rng)


## The adobe village's mud-brick wall: span by span along it, a plastered block a little its own
## height, darker at its foot; its top a rounded cap of mud, paler.
static func _mud_wall(st: SurfaceTool, a: Vector2, b: Vector2, land_y: Callable, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b) / PX
	var dir2 := (b - a).normalized()
	var along := Vector3(dir2.x, 0.0, dir2.y)
	var spans := maxi(1, ceili(length / MUD_WALL_SPAN))
	var span := length / float(spans)
	for i in spans:
		var mid := _along(a, b, (float(i) + 0.5) / float(spans), land_y)
		var high := MUD_WALL_HIGH * rng.randf_range(0.9, 1.06)
		var mud := _shade(MUD_WALL, rng, 0.88, 1.08)
		var foot := mud * 0.78
		foot.a = 1.0
		_slab(st, mid + Vector3(0.0, 0.15, 0.0), along, Vector3(span + 0.02, 0.3, MUD_WALL_THICK + 0.04), foot, rng)
		_slab(st, mid + Vector3(0.0, 0.3 + (high - 0.3) * 0.5, 0.0), along, Vector3(span + 0.02, high - 0.3, MUD_WALL_THICK), mud, rng, 1.08)
		# (the cap: two narrowing courses, the top one paler)
		var cap := mud * 1.1
		cap.a = 1.0
		_slab(st, mid + Vector3(0.0, high + 0.05, 0.0), along, Vector3(span + 0.02, 0.1, MUD_WALL_THICK * 0.85), cap, rng, 1.1)
		_slab(st, mid + Vector3(0.0, high + 0.13, 0.0), along, Vector3(span, 0.07, MUD_WALL_THICK * 0.55), cap, rng, 1.15)


## A hedge (the English village's): lumps of clipped green along it, each its own size and shade,
## lighter on top.
static func _hedge(st: SurfaceTool, a: Vector2, b: Vector2, land_y: Callable, rng: RandomNumberGenerator) -> void:
	var length := a.distance_to(b) / PX
	var dir2 := (b - a).normalized()
	var along := Vector3(dir2.x, 0.0, dir2.y)
	var at := 0.0
	var across := along.cross(Vector3.UP).normalized()
	while at < length - 0.1:
		var lump := minf(rng.randf_range(HEDGE_LUMP.x, HEDGE_LUMP.y), length - at)
		var high := HEDGE_HIGH * rng.randf_range(0.85, 1.1)
		var mid := _along(a, b, (at + lump * 0.5) / length, land_y)
		mid.y += high * 0.5
		var turn := along.rotated(Vector3.UP, rng.randf_range(-0.12, 0.12))
		_slab(st, mid, turn, Vector3(lump + 0.15, high, HEDGE_THICK * rng.randf_range(0.85, 1.05)), _shade(HEDGE_GREEN, rng, 0.8, 1.1), rng, 1.2)
		# (smaller tufts over it and out its sides - not a clipped box)
		for _k in 3:
			var tuft := rng.randf_range(0.3, 0.55)
			var off := across * rng.randf_range(-HEDGE_THICK * 0.45, HEDGE_THICK * 0.45) + along * rng.randf_range(-lump * 0.4, lump * 0.4)
			var top := mid + off + Vector3(0.0, high * 0.5 - tuft * 0.25 + rng.randf_range(-0.05, 0.12), 0.0)
			_slab(st, top, along.rotated(Vector3.UP, rng.randf() * PI), Vector3(tuft, tuft * 0.7, tuft), _shade(HEDGE_GREEN, rng, 0.9, 1.25), rng, 1.15)
		at += lump


## A colour a shade of its own (`lo`..`hi` of it).
static func _shade(col: Color, rng: RandomNumberGenerator, lo: float, hi: float) -> Color:
	var c := col * rng.randf_range(lo, hi)
	c.a = 1.0
	return c


## A box (`size`: along, up, across) with its middle at `at`, its length along `along`; its top
## `top` times its colour.
static func _slab(st: SurfaceTool, at: Vector3, along: Vector3, size: Vector3, col: Color, rng: RandomNumberGenerator, top := 1.0) -> void:
	var u := along.normalized() * size.x * 0.5
	var v := Vector3.UP * size.y * 0.5
	var w := along.normalized().cross(Vector3.UP).normalized() * size.z * 0.5
	var lit := col * top
	lit.a = 1.0
	var faces := [[v, u, w, lit], [-v, u, -w, col * 0.8], [u, v, -w, col], [-u, v, w, col], [w, u, v, col], [-w, u, -v, col]]
	for f in faces:
		var n: Vector3 = f[0]
		var e1: Vector3 = f[1]
		var e2: Vector3 = f[2]
		var c: Color = f[3]
		c.a = 1.0
		var o := at + n
		_tri(st, o - e1 - e2, o + e1 - e2, o + e1 + e2, n.normalized(), c)
		_tri(st, o - e1 - e2, o + e1 + e2, o - e1 + e2, n.normalized(), c)


## A square beam from `a` to `b`, `r` m from its middle to its sides.
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var along := (b - a).normalized()
	var u := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized() * r
	var v := along.cross(u).normalized() * r
	var ring := [u + v, u - v, -u - v, -u + v]
	for k in 4:
		var c0: Vector3 = ring[k]
		var c1: Vector3 = ring[(k + 1) % 4]
		var quad := [a + c0, b + c0, b + c1, a + c1]
		# (the side facing out from the beam's middle - wound to face it whatever way the beam runs)
		var out := (c0 + c1).normalized()
		_tri(st, quad[0], quad[1], quad[2], out, col)
		_tri(st, quad[0], quad[2], quad[3], out, col)
	for end in [[a, -along], [b, along]]:
		var c: Vector3 = end[0]
		var quad := [c + ring[0], c + ring[1], c + ring[2], c + ring[3]]
		var dark := col * 0.9
		dark.a = 1.0
		_tri(st, quad[0], quad[1], quad[2], end[1], dark)
		_tri(st, quad[0], quad[2], quad[3], end[1], dark)


## A triangle facing `n` (wound the way Godot takes a front face, whichever order it's given in).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var pts := [a, c, b] if (b - a).cross(c - a).dot(n) > 0.0 else [a, b, c]
	for p in pts:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


## The crops of the fields in rows (pumpkins, greens): on the ploughed earth's rows (ROW), each its
## own size and turn - one multimesh a crop a field. `thin`: a phone's, every other one.
static func crops(holder: Node3D, list: Array, land_y: Callable, thin := false) -> int:
	var made := 0
	for f in list:
		var field := f as FarmField
		if field.crop != "pumpkin" and field.crop != "greens":
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = field.seed_value
		var a := field.rect.position / PX
		var b := field.rect.end / PX
		var plants := [["farm_pumpkin", PUMPKIN_STEP, PUMPKIN_SIZE, 2]] if field.crop == "pumpkin" else []
		plants.append(["farm_greens", GREENS_STEP, GREENS_SIZE, 1])
		for plant in plants:
			var spots := []
			var every: int = plant[3]
			var row0 := ceili((a.y + 0.4) / ROW - 0.5)
			var k := 0
			while (row0 + k + 0.5) * ROW < b.y - 0.4:
				var z := (row0 + k + 0.5) * ROW
				# (the pumpkins on every second row, the greens between them in a pumpkin field)
				var mine := (k % every == 0) if plant[0] == "farm_pumpkin" or field.crop == "greens" else (k % 2 == 1)
				if mine:
					var step: Vector2 = plant[1]
					var x := a.x + 0.4 + rng.randf() * step.x
					while x < b.x - 0.4:
						spots.append(Vector2(x + rng.randf_range(-0.12, 0.12), z + rng.randf_range(-0.06, 0.06)))
						x += rng.randf_range(step.x, step.y)
				k += 1
			if thin:
				spots = spots.filter(func(_p): return rng.randf() < 0.55)
			if spots.is_empty():
				continue
			var mesh := _crop_mesh(plant[0])
			if mesh == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = spots.size()
			var size: Vector2 = plant[2]
			for i in spots.size():
				var p: Vector2 = spots[i]
				var y := float(land_y.call(p * PX))
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(size.x, size.y))
				mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, y - 0.02, p.y)))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Crops%d" % made
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mmi)
			made += 1
	return made


## A crop's mesh (its model's), its own palette and colour.
static func _crop_mesh(name: String) -> Mesh:
	var scene := load(Ruin.path_of(name)) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate()
	var found := node.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = null
	if not found.is_empty():
		var src := (found[0] as MeshInstance3D).mesh
		mesh = src.duplicate() as Mesh
		var tall := mesh.get_aabb().end.y
		for s in mesh.get_surface_count():
			var from := mesh.surface_get_material(s) as BaseMaterial3D
			var mat := StandardMaterial3D.new()
			if from != null:
				mat.albedo_texture = from.albedo_texture
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.8
			if name in SWAYING_CROPS:
				# (user request "風吹動態": the leafy rows bend in the wind as the plants do)
				var sway := Foliage.material(mat, tall, Foliage.PLANT)
				sway.set_shader_parameter("use_vcol", true)
				mesh.surface_set_material(s, sway)
			else:
				mesh.surface_set_material(s, mat)
	node.free()
	return mesh


static func _materials() -> void:
	if _wood_mat == null:
		_wood_mat = StandardMaterial3D.new()
		_wood_mat.vertex_color_use_as_albedo = true
		_wood_mat.roughness = 0.88
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.albedo_color = LANTERN_LIGHT
		_glow_mat.emission_enabled = true
		_glow_mat.emission = LANTERN_LIGHT
		_glow_mat.emission_energy_multiplier = 3.0
