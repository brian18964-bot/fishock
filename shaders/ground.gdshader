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
uniform float detail = 0.55;       // normal-map detail (1 = full); the albedo's is baked in (tools/soften_ground.py)

// User request (a ruined town): streets laid over the ground. `streets` is
// a map of the whole world (TownBuilder): red = road, green = pavement,
// blue = road paint (lane dashes, crossings). Weeds take the edges and
// patches of both (the macro noise), and the paint is worn.
uniform bool streets_on = false;
uniform sampler2D streets : filter_linear;
uniform vec2 world_size = vec2(2400.0, 1350.0);
uniform sampler2D albedo_road : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_road : repeat_enable, filter_linear_mipmap;
uniform sampler2D albedo_walk : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_walk : repeat_enable, filter_linear_mipmap;
uniform vec3 paint_color : source_color = vec3(0.62, 0.58, 0.46);

// User request (the sea styles): a beach along the coast. The same slots
// as the streets (phones have few texture units): `streets` holds the
// distance from the sea (0..coast_range px, MapGenerator), "road" is the
// sand, "walk" the pebbles at the water's edge. The bands'
// edges wander with the macro noise; `sand_patches` 1 leaves the sand only
// in patches (a rocky coast).
uniform bool coast_on = false;
uniform float coast_range = 400.0;
uniform float sand_width = 200.0;
uniform float stones_width = 30.0;
uniform float sand_patches = 0.0;
uniform float stones_tile = 0.42;  // the stones' tile, in ground tiles

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
	// Close up (the Diablo-style camera) the full-detail tiles read as busy,
	// so some of a blurrier mip is folded back in - baked into the albedo
	// images by tools/soften_ground.py (one sample each instead of two, for
	// phones).
	vec3 ca = texture(albedo_a, uv).rgb;
	vec3 cb = texture(albedo_b, uvb).rgb;
	vec3 col = mix(ca, cb, t);
	vec3 n = mix(texture(normal_a, uv).rgb, texture(normal_b, uvb).rgb, t);
	if (streets_on) {
		vec4 s = texture(streets, world / world_size);
		float weeds = smoothstep(0.72, 0.86, cover);
		float road = smoothstep(0.35, 0.65, s.r) * (1.0 - weeds);
		float walk = smoothstep(0.35, 0.65, s.g) * (1.0 - weeds * 0.7);
		vec2 uvs = world / tile_px * 1.3;
		col = mix(col, texture(albedo_walk, uvs).rgb, walk);
		n = mix(n, texture(normal_walk, uvs).rgb, walk);
		col = mix(col, texture(albedo_road, uv).rgb, road);
		n = mix(n, texture(normal_road, uv).rgb, road);
		float worn = smoothstep(0.25, 0.6, texture(macro, world / 90.0).r);
		col = mix(col, paint_color, smoothstep(0.4, 0.7, s.b) * road * worn * 0.8);
	}
	if (coast_on) {
		float d = texture(streets, world / world_size).r * coast_range;
		d += (m2 - 0.5) * 90.0 + (texture(macro, world / 210.0).r - 0.5) * 50.0;
		float beach = 1.0 - smoothstep(sand_width - 18.0, sand_width + 18.0, d);
		beach *= mix(1.0, smoothstep(0.44, 0.56, cover), sand_patches);
		float stones = 1.0 - smoothstep(stones_width - 9.0, stones_width + 9.0, d);
		vec2 uvc = world / (tile_px * 1.1) + vec2(0.13, 0.71);
		col = mix(col, texture(albedo_road, uvc).rgb, beach);
		n = mix(n, texture(normal_road, uvc).rgb, beach);
		vec2 uvs = world / (tile_px * stones_tile) + vec2(0.52, 0.08);
		col = mix(col, texture(albedo_walk, uvs).rgb, stones);
		n = mix(n, texture(normal_walk, uvs).rgb, stones);
		// Wet and darker where the surf reaches.
		col *= 1.0 - 0.15 * (1.0 - smoothstep(4.0, 22.0, texture(streets, world / world_size).r * coast_range));
	}
	col *= (0.86 + 0.28 * m2) * brightness * tint;
	COLOR = vec4(col, 1.0);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, detail);
}
