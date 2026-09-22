extends PointLight2D

## Ambient, non-directional visibility around the player during the day -
## a soft, feathered halo (not the lantern's tight cone) so nearby terrain
## reads through the daytime haze without needing to aim the lantern at it.
## Disappears entirely at night, leaving only the lantern. User feedback:
## a fog weather event shrinks this halo further.

const RADIUS_SCALE := 1.1
const FOG_RADIUS_SCALE := 0.65

func _ready() -> void:
	texture = LightTextureFactory.make_radial_texture(256, 0.45)
	texture_scale = RADIUS_SCALE
	color = Color(0.75, 0.8, 0.9)
	energy = 0.55
	shadow_enabled = true

func _process(_delta: float) -> void:
	visible = not GameState.is_night
	texture_scale = FOG_RADIUS_SCALE if GameState.weather == GameState.Weather.FOG else RADIUS_SCALE
