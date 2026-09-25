shader_type canvas_item;

// User feedback: the picture read hazy and washed-out ("濛濛舊舊"). A light
// final pass over the world: a little unsharp masking (the close camera
// stretches every sprite texel over a few screen pixels), more saturation,
// and contrast pivoted low so the dark night stays dark.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float sharpen = 0.45;
uniform float radius_px = 2.0;
uniform float saturation = 1.22;
uniform float contrast = 1.12;
uniform float pivot = 0.25;

void fragment() {
	vec2 o = SCREEN_PIXEL_SIZE * radius_px;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 blur = (texture(screen_tex, SCREEN_UV + vec2(o.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV - vec2(o.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(0.0, o.y)).rgb
			+ texture(screen_tex, SCREEN_UV - vec2(0.0, o.y)).rgb) * 0.25;
	c += (c - blur) * sharpen;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - pivot) * contrast + pivot;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
