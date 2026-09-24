class_name WaterZone
extends StaticBody2D

## Design doc request: the map is no longer "water everywhere" - it's a
## handful of these, generated fresh each run by map_generator.gd. Common
## zones: walk into the shallows (Player keeps you out of the deep middle),
## cast at any range. Rare zones are solid ground can't cross (collision
## stays enabled), reachable only by landing a precise cast on them from
## outside - see Player._launch_cast()/_find_water_zone() for how casting
## reads these, and _update_fishing()'s lure branch for the "reel it past
## the rare zone's edge and the catch is done" shortcut.
##
## User request: ponds are irregular - each zone is the union of a few
## overlapping circles ("lobes", zone-local offset xy + radius z), so the
## shoreline wobbles instead of being one perfect circle.

enum ZoneType { COMMON, RARE }

## User request (water step 2): a real water surface instead of the flat
## debug circle - shaders/water.gdshader on the zone's bounding rect:
## scrolling normal maps the lantern glints off, deeper middle, foam along
## the shore. Rare zones keep their purple read. The two wave normal maps
## are generated once (seamless noise baked to normals) and shared.
const WATER_SHADER := preload("res://shaders/water.gdshader")
const RARE_BASE := Color(0.27, 0.13, 0.4)
const RARE_DEEP := Color(0.08, 0.02, 0.16)
const RARE_FOAM := Color(0.86, 0.72, 0.95)
## Lobes the surface shader can take (own + overlapping zones').
const MAX_SHADER_LOBES := 16

static var _wave_a: NoiseTexture2D
static var _wave_b: NoiseTexture2D

var zone_type: int = ZoneType.COMMON
## Bounding radius around the zone's origin (covers every lobe).
var radius: float = 200.0
var lobes: Array[Vector3] = []

var _surface_material: ShaderMaterial


## Called by map_generator.gd right after instantiate(), before the zone is
## even added to the tree (add_child there is deferred) - so collision
## shapes are made directly here rather than via @onready vars. `extra`
## are more lobes (local offset xy, radius z) on top of the main circle.
func setup(type: int, r: float, pos: Vector2, extra: Array[Vector3] = []) -> void:
	zone_type = type
	global_position = pos
	lobes = [Vector3(0.0, 0.0, r)]
	lobes.append_array(extra)
	radius = 0.0
	for lobe in lobes:
		radius = maxf(radius, Vector2(lobe.x, lobe.y).length() + lobe.z)

	var template: CollisionShape2D = get_node("CollisionShape2D")
	for i in lobes.size():
		var cs: CollisionShape2D = template if i == 0 else CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = lobes[i].z
		cs.shape = shape
		cs.position = Vector2(lobes[i].x, lobes[i].y)
		cs.disabled = (type == ZoneType.COMMON)
		if i > 0:
			add_child(cs)

	add_to_group("water_zones")
	add_to_group("water_zones_rare" if is_rare() else "water_zones_common")

	_build_surface()


func is_rare() -> bool:
	return zone_type == ZoneType.RARE


## Lobes in world coordinates (center xy, radius z).
func world_lobes() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for lobe in lobes:
		out.append(Vector3(global_position.x + lobe.x, global_position.y + lobe.y, lobe.z))
	return out


## How far inside the shore `point` is (px); negative outside.
func depth(point: Vector2) -> float:
	var best := -INF
	for lobe in lobes:
		var c := global_position + Vector2(lobe.x, lobe.y)
		best = maxf(best, lobe.z - c.distance_to(point))
	return best


func contains(point: Vector2) -> bool:
	return depth(point) >= 0.0


## At least `margin` px in from the shore.
func is_deep(point: Vector2, margin: float) -> bool:
	return depth(point) >= margin


## 0 if `point` is already inside; otherwise how far outside the edge.
func distance_to_edge(point: Vector2) -> float:
	return maxf(-depth(point), 0.0)


## A random point at least `margin` px in from the shore.
func random_point(margin: float) -> Vector2:
	for _try in 40:
		var p := global_position + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		if is_deep(p, margin):
			return p
	return global_position


## Where a ray from the zone's origin along `dir` leaves the water.
func shore_point(dir: Vector2) -> Vector2:
	var p := global_position
	var step := 4.0
	var d := 0.0
	while d < radius + step:
		if not contains(global_position + dir * (d + step)):
			return global_position + dir * d
		d += step
	return global_position + dir * radius


## Points spread along the shoreline with their outward normals:
## [[point, normal], ...], roughly every `spacing` px.
func shore_samples(spacing: float) -> Array:
	var out := []
	for lobe in lobes:
		var c := global_position + Vector2(lobe.x, lobe.y)
		var n := maxi(8, int(TAU * lobe.z / spacing))
		for i in n:
			var a := (i + randf() * 0.5) / n * TAU
			var dir := Vector2.RIGHT.rotated(a)
			var p := c + dir * lobe.z
			# Only the parts of this lobe's circle that are real shoreline.
			if depth(p + dir * 2.0) < 0.0 and depth(p - dir * 2.0) >= 0.0:
				out.append([p, dir])
	return out


func _build_surface() -> void:
	if _wave_a == null:
		_wave_a = _wave_texture(11, 0.009)
		_wave_b = _wave_texture(29, 0.016)
	var surface := ColorRect.new()
	surface.name = "Surface"
	surface.size = Vector2(radius, radius) * 2.0
	surface.position = -surface.size / 2.0
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.light_mask = LightTwin.GROUND_LAYER
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("wave_a", _wave_a)
	mat.set_shader_parameter("wave_b", _wave_b)
	if is_rare():
		mat.set_shader_parameter("base_color", RARE_BASE)
		mat.set_shader_parameter("deep_color", RARE_DEEP)
		mat.set_shader_parameter("foam_color", RARE_FOAM)
		mat.set_shader_parameter("wave_strength", 0.75)
	surface.material = mat
	add_child(surface)
	_surface_material = mat


func _ready() -> void:
	# Zones are added in one deferred batch; gather overlapping neighbours'
	# lobes once they're all in the tree.
	_link_lobes.call_deferred()


## Gives the shader this zone's lobes plus any same-type zone's lobes that
## overlap it, so the shore follows the merged outline and the surface is
## drawn only inside it.
func _link_lobes() -> void:
	if _surface_material == null:
		return
	var own := world_lobes()
	var all: Array[Vector3] = own.duplicate()
	var group := "water_zones_rare" if is_rare() else "water_zones_common"
	for zone in get_tree().get_nodes_in_group(group):
		if zone == self or zone.global_position.distance_to(global_position) >= zone.radius + radius:
			continue
		all.append_array(zone.world_lobes())
	var count := mini(all.size(), MAX_SHADER_LOBES)
	all.resize(MAX_SHADER_LOBES)
	_surface_material.set_shader_parameter("lobes", all)
	_surface_material.set_shader_parameter("lobe_count", count)
	_surface_material.set_shader_parameter("own_lobe_count", mini(own.size(), MAX_SHADER_LOBES))


## Called every frame by WaterSim with the latest wave field.
func set_sim_texture(tex: Texture2D, grid: Vector2, cell: Vector2) -> void:
	if _surface_material == null:
		return
	_surface_material.set_shader_parameter("sim_height", tex)
	_surface_material.set_shader_parameter("sim_grid", grid)
	_surface_material.set_shader_parameter("sim_cell", cell)
	_surface_material.set_shader_parameter("sim_active", true)


## Seamless noise baked straight to a normal map by Godot.
static func _wave_texture(seed_value: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 3.0
	tex.noise = noise
	return tex
