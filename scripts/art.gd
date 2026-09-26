class_name Art

## User request: a sharper picture. The pre-rendered props (trees, rocks,
## bushes, ground cover, docks, boats), the player, the rod, lures and
## float, the ghost, the gas can and the splash sheets are rendered at
## DENSITY x the pipeline's original 2 texels per world px - 4 in all - so a
## phone's high-DPI screen no longer magnifies them into a blur. Only the
## albedo: their normal maps stay at the original size (a CanvasTexture
## samples both by UV, so they still line up; lighting doesn't need the
## detail, and it keeps the download small). Sprite offsets in the code are
## still written in original-density texture px; place() scales them.
## (Animals and critters stay at the original density.)
const DENSITY := 2.0


## Draws `sprite` at `scale` of an original-density sprite, with `offset` in
## original-density texture px.
static func place(sprite: Sprite2D, offset: Vector2, scale: float) -> void:
	sprite.offset = offset * DENSITY
	sprite.scale = Vector2.ONE * scale / DENSITY


## A variant table's texture: a path (loaded when first used, so a map only
## holds the textures it shows) or an already loaded texture.
static func tex(v: Variant) -> Texture2D:
	return v if v is Texture2D else load(v)
