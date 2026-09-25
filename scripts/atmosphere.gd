class_name Atmosphere
extends Node2D

## User request: the scene felt lifeless - adds slow drifting fog over the
## world (shaders/fog.gdshader) and a breathing vignette of darkness at the
## screen edges (shaders/vignette.gdshader). Both thicken at night and in
## fog weather.

## User feedback: the picture looked hazy and old - day fog is now barely
## there, night and fog weather keep theirs lighter too, and a final grade
## pass (shaders/grade.gdshader) sharpens and saturates the world.
const FOG_DENSITY := {"day": 0.04, "fog": 0.26, "night": 0.1}
const VIGNETTE := {"day": 0.28, "fog": 0.45, "night": 0.6}
const GRADE_LAYER := 1
const FOG_Z := 30
const VIGNETTE_LAYER := 1

var _fog_mat: ShaderMaterial
var _vignette_mat: ShaderMaterial


func _ready() -> void:
	var fog := ColorRect.new()
	fog.name = "Fog"
	fog.size = Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.z_index = FOG_Z
	# Lit by the shadowed lights (see LightTwin): beams and shadow shafts.
	fog.light_mask = LightTwin.GROUND_LAYER
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = preload("res://shaders/fog.gdshader")
	_fog_mat.set_shader_parameter("noise_a", _noise(71, 0.012))
	_fog_mat.set_shader_parameter("noise_b", _noise(113, 0.02))
	_fog_mat.set_shader_parameter("density", FOG_DENSITY.day)
	fog.material = _fog_mat
	add_child(fog)

	# The grade reads the finished world, so it sits on its own layer under
	# the vignette (same layer number, added first) and the HUD.
	var grade_layer := CanvasLayer.new()
	grade_layer.layer = GRADE_LAYER
	var grade := ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_mat := ShaderMaterial.new()
	grade_mat.shader = preload("res://shaders/grade.gdshader")
	grade.material = grade_mat
	grade_layer.add_child(grade)
	add_child(grade_layer)

	var layer := CanvasLayer.new()
	layer.layer = VIGNETTE_LAYER
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = preload("res://shaders/vignette.gdshader")
	_vignette_mat.set_shader_parameter("noise", _noise(5, 0.03))
	_vignette_mat.set_shader_parameter("strength", VIGNETTE.day)
	vignette.material = _vignette_mat
	layer.add_child(vignette)
	add_child(layer)


func _process(delta: float) -> void:
	var mood := "day"
	if GameState.is_night:
		mood = "night"
	elif GameState.weather == GameState.Weather.FOG:
		mood = "fog"
	_ease("density", _fog_mat, FOG_DENSITY[mood], delta)
	_ease("strength", _vignette_mat, VIGNETTE[mood], delta)


func _ease(param: String, mat: ShaderMaterial, target: float, delta: float) -> void:
	var now: float = mat.get_shader_parameter(param)
	mat.set_shader_parameter(param, move_toward(now, target, delta * 0.1))


static func _noise(seed_value: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	return tex
