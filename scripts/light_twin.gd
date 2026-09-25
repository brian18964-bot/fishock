class_name LightTwin
extends PointLight2D

## User bug report: lit from below (lantern pointed up the screen), a rock or
## tree stayed dark while its shadow showed. Every occluder sits at the
## object's base, and the sprite is drawn standing up above that base - so
## a light from the south threw the base's shadow straight back over the
## object's own picture.
##
## Fix: each shadow-casting light is split in two. The original keeps its
## shadows but only lights the flat ground layer (GROUND_LAYER: the ground,
## water, ripples, ground cover), where cast shadows belong. This twin, a
## shadowless copy that follows it every frame, lights everything else
## (PROP_LAYER, the default layer - trees, rocks, docks, animals, the
## player...), so an upright sprite is lit from whichever side the light
## is, and never sits in a shadow.

const PROP_LAYER := 1
const GROUND_LAYER := 2


## Splits `light` as above. Call once its texture/colour are set up.
## `silhouettes`: also lets it throw trees' and rocks' shaped shadows
## (SilhouetteShadow) - off for the faint daytime halo.
static func attach(light: PointLight2D, silhouettes := true) -> void:
	if silhouettes:
		light.add_to_group("shadow_lights")
	light.range_item_cull_mask = GROUND_LAYER
	# User bug report: with the light moved to the ground layer its shadows
	# vanished - the shadow mask also picks which lit items receive shadows,
	# and it was still layer 1 only. Occluders stay on layer 1.
	light.shadow_item_cull_mask = GROUND_LAYER | PROP_LAYER
	var twin := LightTwin.new()
	twin.name = "PropLight"
	light.add_child(twin)


func _ready() -> void:
	shadow_enabled = false
	range_item_cull_mask = PROP_LAYER
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var src := get_parent() as PointLight2D
	# Only what changed: each set goes to the renderer (phones).
	if texture != src.texture:
		texture = src.texture
	if texture_scale != src.texture_scale:
		texture_scale = src.texture_scale
	if offset != src.offset:
		offset = src.offset
	if color != src.color:
		color = src.color
	if energy != src.energy:
		energy = src.energy
	if height != src.height:
		height = src.height
	if blend_mode != src.blend_mode:
		blend_mode = src.blend_mode
	if enabled != src.enabled:
		enabled = src.enabled
