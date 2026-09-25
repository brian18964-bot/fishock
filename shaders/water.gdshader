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

	vec3 col = use_albedo ? texture(albedo, w).rgb : base_color.rgb;
	// Deeper away from the shore, lighter in the shallows (user feedback:
	// darker, deeper-looking water).
	col = mix(col, deep_color.rgb, smoothstep(16.0, 110.0, edge_px) * 0.88);
	col = mix(col, foam_color.rgb, smoothstep(14.0, 0.0, edge_px) * 0.1);
	// Broken foam line hugging the shore, nudged by the chop.
	float wobble = (na.x + nb.y) * 1.5;
	float foam = smoothstep(3.5, 1.0, abs(edge_px - 4.5 + wobble));
	foam *= smoothstep(-0.25, 0.25, na.y + nb.x * 0.5 + 0.1);
	col = mix(col, foam_color.rgb, foam * 0.32);

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
