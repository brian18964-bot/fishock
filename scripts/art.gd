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


## Sheet row/column of the 8 facings (tools/render_characters.py DIRS:
## down, down_left, left, up_left, up, up_right, right, down_right) by 45deg
## sector clockwise from +X.
const SECTOR_TO_DIR := [6, 7, 0, 1, 2, 3, 4, 5]
## How far past a sector's edge a heading has to swing before the facing
## changes - so a heading near a diagonal doesn't flick between two frames.
const FACING_SLACK := 0.14


## The 8-way facing for heading `v`, sticking with `current` until the
## heading has clearly left its sector.
static func facing8(v: Vector2, current: int) -> int:
	var angle := v.angle()
	var sector := SECTOR_TO_DIR.find(current)
	if sector >= 0 and absf(angle_difference(sector * PI / 4.0, angle)) < PI / 8.0 + FACING_SLACK:
		return current
	return SECTOR_TO_DIR[posmod(roundi(angle / (PI / 4.0)), 8)]
