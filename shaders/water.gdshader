shader_type canvas_item;

// Water zone surface (see scripts/water_zone.gd). Two tileable normal maps
// scroll against each other for a gentle chop, written to NORMAL_MAP in the
// sprites' encoding so the lantern glints off the surface; a darker middle,
// a soft lighter shallows band and a broken foam line trace the shore.
// `albedo` takes a painted water texture later; left unset, the flat
// base/deep colors are used.

uniform vec4 base_color : source_color = vec4(0.09, 0.27, 0.37, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.15, 1.0);
uniform vec4 foam_color : source_color = vec4(0.82, 0.93, 0.97, 1.0);
uniform sampler2D albedo : source_color, repeat_enable, filter_linear;
uniform bool use_albedo = false;
uniform sampler2D wave_a : repeat_enable, filter_linear;
uniform sampler2D wave_b : repeat_enable, filter_linear;
uniform float wave_scale = 260.0;   // world px per normal-map tile
uniform float wave_strength = 0.12;  // user feedback: a calm surface
uniform vec2 drift_a = vec2(0.012, 0.006);
uniform vec2 drift_b = vec2(-0.008, 0.010);
uniform float opacity = 1.0;
// The shoreline, baked once per zone (shaders/shore_bake.gdshader,
// WaterZone): R the distance to the shore of the merged water near the
// shore (fine), B the same over the whole range, G the same for this zone's
// own outline (it draws only inside that) - world px over these ranges.
// Worked out per pixel every frame before - too much for a phone.
uniform sampler2D shore_field : filter_linear;
uniform vec2 near_range = vec2(-8.0, 24.0);
uniform vec2 field_range = vec2(-8.0, 120.0);
uniform vec2 own_range = vec2(-8.0, 8.0);

// User request (the sea styles), after the user's ocean-water pack but in
// our own painted style: clear shallows showing the sand, turquoise going
// to deep blue out to sea, dark weed-covered rocks under the water, a surf
// of lacy foam washing in and out along the beach, a wave line coming in
// behind it, glints in the shallows. Only for a sea (WaterZone.sea).
uniform bool sea = false;
uniform sampler2D foam_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D blot_tex : repeat_enable, filter_linear;  // soft noise (WaterZone's shore noise)
uniform vec4 shallow_color : source_color = vec4(0.36, 0.72, 0.66, 1.0);
uniform vec4 seabed_color : source_color = vec4(0.72, 0.68, 0.5, 1.0);
uniform vec4 reef_color : source_color = vec4(0.07, 0.19, 0.13, 1.0);
uniform float reef_amount = 0.4;
uniform float shallow_px = 70.0;
uniform float deep_px = 380.0;

const float SQUASH = 0.819;  // sin 55deg: ripples lie on the art's ground plane

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 decode(vec4 t) {
	return t.rgb * 2.0 - 1.0;
}

void fragment() {
	vec3 field = texture(shore_field, UV).rgb;
	float own = mix(own_range.x, own_range.y, field.g);
	if (own < 0.0) {
		discard;
	}
	float edge_px = field.r < 0.99 ? mix(near_range.x, near_range.y, field.r)
			: mix(field_range.x, field_range.y, field.b);

	// World-anchored, foreshortened wave coordinates.
	vec2 w = vec2(world_pos.x, world_pos.y / SQUASH) / wave_scale;
	vec3 na = decode(texture(wave_a, w + drift_a * TIME));
	vec3 nb = decode(texture(wave_b, w * 1.7 + drift_b * TIME));
	vec2 slope = (na.xy + nb.xy) * wave_strength;
	vec3 n = normalize(vec3(slope, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;

	vec3 col;
	if (sea) {
		// The sand seen through the shallows, turquoise, then deep blue.
		col = mix(seabed_color.rgb, shallow_color.rgb, smoothstep(0.0, shallow_px * 0.45, edge_px));
		col = mix(col, base_color.rgb, smoothstep(shallow_px * 0.5, shallow_px * 1.7, edge_px));
		col = mix(col, deep_color.rgb, smoothstep(shallow_px * 1.2, deep_px, edge_px));
		// Weed-covered rocks under the water: big soft blotches (the foam
		// mask far down its mips), in the shallows and the middle depths.
		vec2 fw = vec2(world_pos.x, world_pos.y / SQUASH);
		float blot = texture(blot_tex, fw / 800.0 + vec2(0.3, 0.7)).r * 0.8
				+ texture(blot_tex, fw / 260.0 + vec2(0.81, 0.13)).r * 0.2;
		float reef = smoothstep(0.62, 0.76, blot) * smoothstep(18.0, 50.0, edge_px)
				* (1.0 - smoothstep(120.0, 220.0, edge_px));
		col = mix(col, reef_color.rgb, reef * reef_amount);
		// Glints where the chop focuses the light, in the shallows.
		float glint = smoothstep(0.6, 0.95, 1.0 - abs(na.x + nb.x) * 1.4);
		col += glint * 0.07 * (1.0 - smoothstep(8.0, 100.0, edge_px));
		// The surf: a band of lace washing in and out, a wave line behind.
		float along = textureLod(foam_tex, fw / 500.0, 6.0).r;
		float surge = 14.0 + 8.0 * sin(TIME * 0.8 + along * 14.0);
		float lace = texture(foam_tex, fw / 150.0 + vec2(TIME * 0.004, TIME * 0.009)).r;
		float band = 1.0 - smoothstep(surge * 0.3, surge, edge_px);
		float foam = band * smoothstep(0.28, 0.52, lace) + smoothstep(3.0, 0.5, edge_px) * 0.8;
		float crest_at = 34.0 - fract(TIME * 0.05 + along * 3.0) * 28.0;
		float crest = smoothstep(5.0, 0.0, abs(edge_px - crest_at)) * smoothstep(0.3, 0.65, lace)
				* smoothstep(0.0, 0.3, fract(TIME * 0.05 + along * 3.0));
		col = mix(col, foam_color.rgb, clamp(foam * 0.95 + crest * 0.55, 0.0, 1.0));
	} else {
		col = use_albedo ? texture(albedo, w).rgb : base_color.rgb;
		// Deeper away from the shore, lighter in the shallows (user feedback:
		// darker, deeper-looking water).
		col = mix(col, deep_color.rgb, smoothstep(16.0, 110.0, edge_px) * 0.88);
		col = mix(col, foam_color.rgb, smoothstep(14.0, 0.0, edge_px) * 0.1);
		// Broken foam line hugging the shore, nudged by the chop.
		float wobble = (na.x + nb.y) * 1.5;
		float foam = smoothstep(3.5, 1.0, abs(edge_px - 4.5 + wobble));
		foam *= smoothstep(-0.25, 0.25, na.y + nb.x * 0.5 + 0.1);
		col = mix(col, foam_color.rgb, foam * 0.32);
	}

	// Soft outer rim instead of a hard cut.
	float alpha = opacity * smoothstep(0.0, 2.0, edge_px);
	COLOR = vec4(col, alpha);
}

// The lantern sits at height 0, so a flat, upward-facing surface would
// catch almost none of its light. Treat the light as held a little above
// the water, and add a specular glint off the chop.
const float LIGHT_LIFT = 0.9;

void light() {
	vec3 l = normalize(LIGHT_DIRECTION + vec3(0.0, 0.0, LIGHT_LIFT));
	float ndl = max(dot(NORMAL, l), 0.0);
	vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(NORMAL, hv), 0.0), 60.0) * 0.5;
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb * ndl + vec3(spec)), LIGHT_COLOR.a);
}
