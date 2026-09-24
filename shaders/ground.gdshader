shader_type canvas_item;

// User request: each map style has its own ground. Two tiling textures from
// tools/make_ground.py (albedo + normal), A everywhere and B in large
// patches picked by a low-frequency noise, with a gentle brightness drift
// so the tile repeat doesn't show. The normals make the lantern pick out
// grass blades, pebbles and leaves.

uniform sampler2D albedo_a : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D albedo_b : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D macro : repeat_enable, filter_linear;
uniform float tile_px = 256.0;     // world px per texture tile
uniform float macro_px = 1300.0;   // world px per macro-noise tile
uniform float blend_b = 0.3;       // share of the ground covered by B
uniform float brightness = 0.65;
uniform vec3 tint = vec3(1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float m = texture(macro, world / macro_px).r;
	float m2 = texture(macro, world / (macro_px * 0.31) + vec2(0.5, 0.25)).r;
	float cover = m * 0.7 + m2 * 0.3;
	float t = smoothstep(1.0 - blend_b - 0.06, 1.0 - blend_b + 0.06, cover);
	vec2 uv = world / tile_px;
	// B on its own offset so the two tile grids never line up.
	vec2 uvb = world / (tile_px * 1.07) + vec2(0.37, 0.61);
	vec3 col = mix(texture(albedo_a, uv).rgb, texture(albedo_b, uvb).rgb, t);
	col *= (0.86 + 0.28 * m2) * brightness * tint;
	COLOR = vec4(col, 1.0);
	NORMAL_MAP = mix(texture(normal_a, uv).rgb, texture(normal_b, uvb).rgb, t);
}
