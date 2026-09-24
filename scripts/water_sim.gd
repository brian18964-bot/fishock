class_name WaterSim
extends Node

## Water step 3: live wave simulation. A height field over the whole map is
## advanced every frame on the GPU (shaders/water_sim.gdshader, ping-ponging
## between two SubViewports); anything that touches the water pushes it via
## impulse(), and waves spread, interfere and bounce off the shore. The
## water surface shader reads the latest field for its normals, so the
## lantern shows them. Ripple.spawn() feeds this when it exists and falls
## back to its drawn rings when it doesn't.

const SIM_SHADER := preload("res://shaders/water_sim.gdshader")
const CELL := 4.0            # world px per texel across
const GROUND_SQUASH := 0.819  # sin 55deg: rows cover fewer world px
const MAX_IMPULSES := 16
const MAX_ZONES := 16

static var instance: WaterSim

var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
var _current := 0
var _impulses: Array[Vector4] = []
var _grid := Vector2i.ZERO
var _cell := Vector2.ZERO
var _frames := 0


## Pushes the water at `pos` (world px): radius in px, strength ~0..1.
static func impulse(pos: Vector2, radius: float, strength: float) -> bool:
	if instance == null or not is_instance_valid(instance):
		return false
	if instance._impulses.size() < MAX_IMPULSES:
		instance._impulses.append(Vector4(pos.x, pos.y, maxf(radius, CELL), strength))
	return true


func _ready() -> void:
	instance = self
	_cell = Vector2(CELL, CELL * GROUND_SQUASH)
	_grid = Vector2i(ceili(Player.WORLD_WIDTH / _cell.x), ceili(Player.WORLD_HEIGHT / _cell.y))
	for i in 2:
		var vp := SubViewport.new()
		vp.size = _grid
		vp.disable_3d = true
		vp.transparent_bg = true
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		var rect := ColorRect.new()
		rect.size = Vector2(_grid)
		var mat := ShaderMaterial.new()
		mat.shader = SIM_SHADER
		mat.set_shader_parameter("grid_size", Vector2(_grid))
		mat.set_shader_parameter("cell_px", _cell)
		rect.material = mat
		vp.add_child(rect)
		add_child(vp)
		_viewports.append(vp)
		_materials.append(mat)
	# Each target reads the other's last state.
	_materials[0].set_shader_parameter("previous", _viewports[1].get_texture())
	_materials[1].set_shader_parameter("previous", _viewports[0].get_texture())


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(_delta: float) -> void:
	var zones: Array[Vector4] = []
	for zone in get_tree().get_nodes_in_group("water_zones"):
		if zones.size() < MAX_ZONES:
			zones.append(Vector4(zone.global_position.x, zone.global_position.y, zone.radius, 0.0))
	var zone_count := zones.size()
	while zones.size() < MAX_ZONES:
		zones.append(Vector4.ZERO)
	var impulse_count := _impulses.size()
	var impulses := _impulses.duplicate()
	while impulses.size() < MAX_IMPULSES:
		impulses.append(Vector4.ZERO)
	_impulses.clear()

	var target := 1 - _current
	var mat := _materials[target]
	mat.set_shader_parameter("zones", zones)
	mat.set_shader_parameter("zone_count", zone_count)
	mat.set_shader_parameter("impulses", impulses)
	mat.set_shader_parameter("impulse_count", impulse_count)
	# The first couple of steps just clear both buffers to flat water.
	mat.set_shader_parameter("reset", _frames < 2)
	_viewports[target].render_target_update_mode = SubViewport.UPDATE_ONCE
	_current = target
	_frames += 1
	var tex := _viewports[_current].get_texture()
	for zone in get_tree().get_nodes_in_group("water_zones"):
		zone.set_sim_texture(tex, Vector2(_grid), _cell)
