class_name WaterZone
extends StaticBody2D

## Design doc request: the map is no longer "water everywhere" - it's a
## handful of these, generated fresh each run by map_generator.gd. Common
## zones are easy: walk right up (no collision), cast at any range. Rare
## zones are solid ground can't cross (collision stays enabled), reachable
## only by landing a precise cast on them from outside - see
## Player._launch_cast()/_find_water_zone() for how casting reads these,
## and _update_fishing()'s lure branch for the "reel it past the rare
## zone's edge and the catch is done" shortcut.

enum ZoneType { COMMON, RARE }

## User request (water step 2): a real water surface instead of the flat
## debug circle - shaders/water.gdshader on a 2r x 2r rect: scrolling normal
## maps the lantern glints off, deeper middle, foam along the shore. Rare
## zones keep their purple read. The two wave normal maps are generated once
## (seamless noise baked to normals) and shared by every zone.
const WATER_SHADER := preload("res://shaders/water.gdshader")
const RARE_BASE := Color(0.36, 0.2, 0.5)
const RARE_DEEP := Color(0.16, 0.06, 0.26)
const RARE_FOAM := Color(0.86, 0.72, 0.95)

static var _wave_a: NoiseTexture2D
static var _wave_b: NoiseTexture2D

var zone_type: int = ZoneType.COMMON
var radius: float = 200.0

var _surface_material: ShaderMaterial


## Called by map_generator.gd right after instantiate(), before the zone is
## even added to the tree (add_child there is deferred) - so this resolves
## the collision shape directly via get_node() rather than an @onready var
## (which wouldn't be assigned yet at this point).
func setup(type: int, r: float, pos: Vector2) -> void:
	zone_type = type
	radius = r
	global_position = pos

	var shape := CircleShape2D.new()
	shape.radius = r
	var collision_shape: CollisionShape2D = get_node("CollisionShape2D")
	collision_shape.shape = shape
	collision_shape.disabled = (type == ZoneType.COMMON)

	add_to_group("water_zones")
	add_to_group("water_zones_rare" if is_rare() else "water_zones_common")

	_build_surface()


func is_rare() -> bool:
	return zone_type == ZoneType.RARE


func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


## 0 if `point` is already inside; otherwise how far outside the edge.
func distance_to_edge(point: Vector2) -> float:
	var d: float = global_position.distance_to(point) - radius
	return max(d, 0.0)


func _build_surface() -> void:
	if _wave_a == null:
		_wave_a = _wave_texture(11, 0.009)
		_wave_b = _wave_texture(29, 0.016)
	var surface := ColorRect.new()
	surface.name = "Surface"
	surface.size = Vector2(radius, radius) * 2.0
	surface.position = -surface.size / 2.0
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("radius", radius)
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
	# Zones are added in one deferred batch; look for overlapping neighbours
	# once they're all in the tree.
	_link_neighbors.call_deferred()


## Tells the shader about same-type zones overlapping this one, so the shore
## follows the merged outline of a lake built from several circles.
func _link_neighbors() -> void:
	if _surface_material == null:
		return
	var group := "water_zones_rare" if is_rare() else "water_zones_common"
	var found: Array[Vector3] = []
	for zone in get_tree().get_nodes_in_group(group):
		if zone == self or found.size() >= 8:
			continue
		if zone.global_position.distance_to(global_position) < zone.radius + radius:
			found.append(Vector3(zone.global_position.x, zone.global_position.y, zone.radius))
	var count := found.size()
	while found.size() < 8:
		found.append(Vector3.ZERO)
	_surface_material.set_shader_parameter("neighbors", found)
	_surface_material.set_shader_parameter("neighbor_count", count)


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
