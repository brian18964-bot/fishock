shader_type canvas_item;

// The player's sheet (scripts/player_visual.gd), its ears and tail swayed
// (sway.gdshaderinc).
#include "res://shaders/sway.gdshaderinc"

varying vec4 tint;

void vertex() {
	sway_at = VERTEX;
	tint = COLOR;
}

void fragment() {
	vec2 uv = sway_uv(UV, sway_at, TEXTURE_PIXEL_SIZE);
	COLOR = texture(TEXTURE, uv) * tint;
	NORMAL_MAP = texture(NORMAL_TEXTURE, uv).rgb;
}
