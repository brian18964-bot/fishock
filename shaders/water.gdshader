shader_type canvas_item;

// Water zone surface (see scripts/water_zone.gd). Two tileable normal maps
// scroll against each other for a gentle chop, written to NORMAL_MAP in the
// sprites' encoding so the lantern glints off the surface; a darker middle,
// a soft lighter shallows band and a broken foam line trace the shore.
// `albedo` takes a painted water texture later; left unset, the flat
// base/deep colors are used.

uniform vec4 base_color : source_color = vec4(0.16, 0.42, 0.55, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.2, 0.32, 1.0);
uniform vec4 foam_color : source_color = vec4(0.82, 0.93, 0.97, 1.0);
uniform sampler2D albedo : source_color, repeat_enable, filter_linear;
uniform bool use_albedo = false;
uniform sampler2D wave_a : repeat_enable, filter_linear;
uniform sampler2D wave_b : repeat_enable, filter_linear;
uniform float wave_scale = 260.0;   // world px per normal-map tile
uniform float wave_strength = 0.45;
uniform vec2 drift_a = vec2(0.012, 0.006);
uniform vec2 drift_b = vec2(-0.008, 0.010);
uniform float opacity = 1.0;
// Live wave field from scripts/water_sim.gd (packed 16-bit heights).
uniform sampler2D sim_height : filter_nearest;
uniform bool sim_active = false;
uniform vec2 sim_grid;
uniform vec2 sim_cell;             // world px per texel
uniform float sim_strength = 14.0;
// The water body as circles (world center xy, radius z): this zone's own
// lobes first (own_lobe_count), then overlapping same-type zones' lobes.
// The zone draws only inside its own lobes; the shore line follows the
// outline of all of them merged.
uniform vec3 lobes[16];
uniform int lobe_count = 0;
uniform int own_lobe_count = 0;

const float SQUASH = 0.819;  // sin 55deg: ripples lie on the art's ground plane

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 decode(vec4 t) {
	return t.rgb * 2.0 - 1.0;
}

float sim_texel(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(sim_grid) - 1);
	vec2 v = texelFetch(sim_height, c, 0).rg;
	float u = round(v.x * 255.0) * 256.0 + round(v.y * 255.0);
	return u / 65535.0 * 2.0 - 1.0;
}

// Bilinear height at a world position (the packed texels can't be
// hardware-filtered).
float sim_at(vec2 world) {
	vec2 g = world / sim_cell - 0.5;
	ivec2 c = ivec2(floor(g));
	vec2 f = fract(g);
	return mix(mix(sim_texel(c), sim_texel(c + ivec2(1, 0)), f.x),
			mix(sim_texel(c + ivec2(0, 1)), sim_texel(c + ivec2(1, 1)), f.x), f.y);
}

void fragment() {
	float own = -1e6;
	float edge_px = -1e6;  // distance to the shore of the merged water, px
	for (int i = 0; i < lobe_count; i++) {
		float d = lobes[i].z - distance(world_pos, lobes[i].xy);
		edge_px = max(edge_px, d);
		if (i < own_lobe_count) {
			own = max(own, d);
		}
	}
	if (own < 0.0) {
		discard;
	}

	// World-anchored, foreshortened wave coordinates.
	vec2 w = vec2(world_pos.x, world_pos.y / SQUASH) / wave_scale;
	vec3 na = decode(texture(wave_a, w + drift_a * TIME));
	vec3 nb = decode(texture(wave_b, w * 1.7 + drift_b * TIME));
	vec2 slope = (na.xy + nb.xy) * wave_strength;
	float sim_h = 0.0;
	if (sim_active) {
		// Surface slope from the live waves; encoded Y points up the screen.
		float hx = sim_at(world_pos + vec2(sim_cell.x, 0.0)) - sim_at(world_pos - vec2(sim_cell.x, 0.0));
		float hy = sim_at(world_pos + vec2(0.0, sim_cell.y)) - sim_at(world_pos - vec2(0.0, sim_cell.y));
		slope += vec2(-hx, hy) * sim_strength;
		sim_h = sim_at(world_pos);
	}
	vec3 n = normalize(vec3(slope, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;

	vec3 col = use_albedo ? texture(albedo, w).rgb : base_color.rgb;
	// Deeper away from the shore, lighter in the shallows.
	col = mix(col, deep_color.rgb, smoothstep(20.0, 140.0, edge_px) * 0.7);
	col = mix(col, foam_color.rgb, smoothstep(22.0, 0.0, edge_px) * 0.18);
	// Broken foam line hugging the shore, nudged by the chop.
	float wobble = (na.x + nb.y) * 1.5;
	float foam = smoothstep(3.5, 1.0, abs(edge_px - 4.5 + wobble));
	foam *= smoothstep(-0.25, 0.25, na.y + nb.x * 0.5 + 0.1);
	col = mix(col, foam_color.rgb, foam * 0.6);
	// Live wave crests pick up a little foam colour.
	col = mix(col, foam_color.rgb, clamp(sim_h * 2.5, 0.0, 0.35));

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
