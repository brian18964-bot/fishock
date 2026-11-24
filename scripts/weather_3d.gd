class_name Weather3D
extends Node3D

## User request (the weathers seen in the 3D run - fog, thick fog, drizzle, storm, the desert's
## sandstorm, the coasts' sea fog): rain falling round the traveller (a storm's heavy and slanting,
## a drizzle's light and slow), the desert's sand driven sideways in a sandstorm, the snow map's
## snowfall thickening in a blizzard; and how much thicker the air's haze is, and of what colour,
## eased in and out as the weather turns - RunView3D's light reads fog_mult, fog_tint, sea_fog.

## (drops in a storm's rain and a drizzle's; puffs of blown sand in a sandstorm)
const RAIN := 1400
const DRIZZLE := 380
const DUST := 240
## (how much thicker the haze is in each weather, x the map's own; how fast it turns, per s)
const FOG_MULT := {"CLEAR": 1.0, "FISH_RUN": 1.0, "DRIZZLE": 1.4, "STORM": 1.9, "FOG": 3.0, "DENSE_FOG": 6.5,
	"SANDSTORM": 5.0, "SEA_FOG": 2.0}
const EASE := 0.18
const DUST_TINT := Color(0.42, 0.31, 0.18)
const SEA_FOG_TINT := Color(0.32, 0.38, 0.44)
## (a fog's own pale grey - the night's mist seen, not only its dark)
const FOG_TINT := Color(0.22, 0.24, 0.28)

## (x the map's haze; the haze's colour pulled toward rgb by a; a fog lying low on the water 0..1)
var fog_mult := 1.0
var fog_tint := Color(0, 0, 0, 0)
var sea_fog := 0.0
## The snow map's snowfall (thicker in a blizzard), if any.
var snow: CPUParticles3D
var theme := ""
var _rain: CPUParticles3D
var _drizzle: CPUParticles3D
var _dust: CPUParticles3D


func setup(theme_name: String, low: bool) -> void:
	theme = theme_name
	var k := 0.5 if low else 1.0
	if not theme.begins_with("snow"):
		_rain = _drops(int(RAIN * k), 0.5, Vector2(14.0, 18.0), Vector3(0.008, 0.5, 0.008), 0.22)
		_drizzle = _drops(int(DRIZZLE * k), 1.4, Vector2(5.0, 6.5), Vector3(0.006, 0.26, 0.006), 0.24)
	if theme == "desert":
		_dust = CPUParticles3D.new()
		_dust.amount = int(DUST * k)
		_dust.lifetime = 3.0
		_dust.preprocess = 3.0
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_dust.emission_box_extents = Vector3(14.0, 1.4, 14.0)
		_dust.direction = Vector3(1.0, 0.05, 0.3)
		_dust.spread = 12.0
		_dust.gravity = Vector3.ZERO
		_dust.initial_velocity_min = 5.0
		_dust.initial_velocity_max = 9.0
		_dust.scale_amount_min = 0.6
		_dust.scale_amount_max = 1.6
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 1.6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_color = Color(DUST_TINT, 0.14)
		m.albedo_texture = _soft()
		quad.material = m
		_dust.mesh = quad
		_dust.emitting = false
		_dust.top_level = true
		_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_dust)


## The weather now round `at` (the traveller): what falls, how thick the air.
func update(delta: float, at: Vector3) -> void:
	var kind: String = GameState.Weather.keys()[GameState.weather]
	var want := float(FOG_MULT.get(kind, 1.0))
	fog_mult = move_toward(fog_mult, want, delta * EASE * maxf(absf(want - fog_mult), 0.5))
	var tint := Color(fog_tint, 0.0)
	match kind:
		"SANDSTORM": tint = Color(DUST_TINT, 0.75)
		"SEA_FOG": tint = Color(SEA_FOG_TINT, 0.45)
		"FOG": tint = Color(FOG_TINT, 0.4)
		"DENSE_FOG": tint = Color(FOG_TINT, 0.6)
	fog_tint = Color(tint.r, tint.g, tint.b, move_toward(fog_tint.a, tint.a, delta * EASE))
	sea_fog = move_toward(sea_fog, 1.0 if kind == "SEA_FOG" else 0.0, delta * EASE)
	if _rain != null:
		_rain.emitting = kind == "STORM"
		_rain.global_position = at + Vector3(-1.0, 7.5, 0.0)
		_drizzle.emitting = kind == "DRIZZLE"
		_drizzle.global_position = at + Vector3(-0.5, 7.0, 0.0)
	if _dust != null:
		_dust.emitting = kind == "SANDSTORM"
		_dust.global_position = at + Vector3(-8.0, 1.0, 0.0)
	if snow != null and is_instance_valid(snow):
		snow.speed_scale = move_toward(snow.speed_scale, 2.3 if kind == "STORM" else 1.0, delta * 0.5)


## Rain: thin streaks along their fall, falling at `speed` m/s for `life` s, faint.
func _drops(amount: int, life: float, speed: Vector2, size: Vector3, alpha: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 8)
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13.0, 0.4, 13.0)
	p.direction = Vector3(0.18, -1.0, 0.06)
	p.spread = 3.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.particle_flag_align_y = true
	var box := BoxMesh.new()
	box.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.68, 0.76, 0.88, alpha)
	box.material = m
	p.mesh = box
	p.emitting = false
	p.top_level = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


static func _soft() -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = 32
	g.height = 32
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	g.gradient = grad
	return g
