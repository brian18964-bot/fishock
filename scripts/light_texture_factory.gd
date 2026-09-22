class_name LightTextureFactory
extends RefCounted

## Procedurally builds soft light textures at runtime so the prototype needs
## no external art assets yet. Cone points toward +X; rotate the node using
## it to aim.

static func make_cone_texture(size: int = 256, half_angle_deg: float = 32.0, feather_deg: float = 10.0) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_radius := size / 2.0
	var half_angle := deg_to_rad(half_angle_deg)
	var feather := deg_to_rad(feather_deg)
	for y in range(size):
		for x in range(size):
			var offset := Vector2(x, y) - center
			var dist := offset.length()
			var alpha := 0.0
			if dist <= max_radius:
				var angle: float = abs(offset.angle())
				var angle_falloff := 1.0
				if angle > half_angle:
					angle_falloff = 0.0
				elif angle > half_angle - feather:
					angle_falloff = 1.0 - (angle - (half_angle - feather)) / feather
				var dist_falloff: float = 1.0 - pow(dist / max_radius, 1.4)
				alpha = clamp(angle_falloff * dist_falloff, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


static func make_radial_texture(size: int = 256, feather: float = 0.15) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := (Vector2(x, y) - center).length() / max_radius
			var alpha: float = clamp(1.0 - dist, 0.0, 1.0)
			if dist > 1.0 - feather:
				alpha *= (1.0 - dist) / feather
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
