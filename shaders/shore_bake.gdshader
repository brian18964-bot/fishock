shader_type canvas_item;
render_mode unshaded;

// Bakes a water zone's shoreline into a texture, once (WaterZone renders it
// into a SubViewport when the map is made), so the water surface itself
// just samples it instead of working the shore out for every pixel every
// frame (performance on phones). Same function WaterZone.depth() evaluates
// for gameplay: the lobes blended with a smooth union, pushed in and out
// by two octaves of the shared noise.
//   R: distance to the shore of the merged water (world px) near the shore,
//      over near_range - fine steps, for the foam line and the soft rim
//   G: the same for this zone's own lobes (where it draws), over own_range
//   B: the distance again over the whole of field_range (the deep water)

uniform vec3 lobes[16];
uniform int lobe_count = 0;
uniform int own_lobe_count = 0;
uniform sampler2D shore_noise : repeat_enable, filter_linear;
uniform float shore_blend = 30.0;
uniform float warp_scale_a = 600.0;
uniform float warp_amp_a = 18.0;
uniform float warp_scale_b = 150.0;
uniform float warp_amp_b = 5.0;
uniform vec2 origin;       // world position of the surface's top-left
uniform vec2 world_size;   // world size of the surface
uniform vec2 near_range = vec2(-8.0, 24.0);
uniform vec2 field_range = vec2(-8.0, 120.0);
uniform vec2 own_range = vec2(-8.0, 8.0);

float smax(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
	return mix(b, a, h) + k * h * (1.0 - h);
}

float shore_warp(vec2 p) {
	float a = texture(shore_noise, p / warp_scale_a).r;
	float b = texture(shore_noise, p / warp_scale_b + vec2(0.37, 0.61)).r;
	return (a - 0.5) * 2.0 * warp_amp_a + (b - 0.5) * 2.0 * warp_amp_b;
}

void fragment() {
	vec2 world_pos = origin + UV * world_size;
	float own = -1e6;
	float edge_px = -1e6;
	for (int i = 0; i < lobe_count; i++) {
		float d = lobes[i].z - distance(world_pos, lobes[i].xy);
		edge_px = smax(edge_px, d, shore_blend);
		if (i < own_lobe_count) {
			own = smax(own, d, shore_blend);
		}
	}
	float warp = shore_warp(world_pos);
	edge_px += warp;
	own += warp;
	COLOR = vec4(
		clamp((edge_px - near_range.x) / (near_range.y - near_range.x), 0.0, 1.0),
		clamp((own - own_range.x) / (own_range.y - own_range.x), 0.0, 1.0),
		clamp((edge_px - field_range.x) / (field_range.y - field_range.x), 0.0, 1.0),
		1.0);
}
