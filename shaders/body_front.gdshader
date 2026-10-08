shader_type canvas_item;

// The player's sheet drawn again over the rod where the character is in
// front of it (scripts/body_front.gd): this sprite shows the body's own
// texture - its cell's part round the rod - and the mask (the front
// atlas's alpha, tools/render_player.py --grip) says which of it.
uniform sampler2D mask : filter_linear;
// (its ears and tail swayed as the body's are: sway.gdshaderinc)
#include "res://shaders/sway.gdshaderinc"
// this sprite's region in the body texture (UV: position, size)
uniform vec4 region_uv;
// the cell's piece of the mask atlas (UV: position, size), and half a
// texel of it, so no neighbouring piece is read
uniform vec4 mask_uv;
uniform vec2 mask_half;

varying vec4 tint;

void vertex() {
	sway_at = VERTEX;
	tint = COLOR;
}

void fragment() {
	vec2 from = sway_uv(UV, sway_at, TEXTURE_PIXEL_SIZE);
	COLOR = texture(TEXTURE, from) * tint;
	NORMAL_MAP = texture(NORMAL_TEXTURE, from).rgb;
	vec2 at = (UV - region_uv.xy) / region_uv.zw;
	vec2 m = clamp(mask_uv.xy + at * mask_uv.zw, mask_uv.xy + mask_half, mask_uv.xy + mask_uv.zw - mask_half);
	COLOR.a *= texture(mask, m).a;
}
