// User request (the floating ghost, plan B): an airy ghost - its lower body and tail thinning
// out into mist from the waist down (the tail's hard shape gone), a little see-through, lit from
// within and glowing at its edges so the night doesn't swallow it. RunView3D._mist_ghost.
//
// `base_y` (per instance, each frame): the world height of the ghost's holder - the fade is
// measured up from it (waist / gone, in m), the edge wavering with a drifting noise. `center`
// (per instance): the middle of its head in the world - its glowing edge taken mostly from a
// round body about it, so the model's flat facets don't show through as a patchwork.
shader_type spatial;
render_mode cull_back, depth_draw_always, specular_disabled;

uniform vec3 body_color : source_color = vec3(0.86, 0.88, 0.97);
uniform vec3 rim_color : source_color = vec3(0.62, 0.78, 1.0);
// How solid the middle of it is (the edges are more so: they glow).
uniform float core_alpha = 0.55;
uniform float rim_power = 2.0;
uniform float glow = 0.62;
// Faded from `waist` (whole) down to `gone` (nothing), m over its holder; 0/0 keeps it whole
// (its claws and eyes).
uniform float waist = 1.48;
uniform float gone = 1.14;
uniform float waver = 0.09;
instance uniform float base_y = 0.0;
instance uniform vec3 center = vec3(0.0);

varying vec3 world;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 round_n = normalize((VIEW_MATRIX * vec4(normalize(world - center), 0.0)).xyz);
	vec3 n = normalize(mix(NORMAL, round_n, 0.92));
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), rim_power);
	float fade = 1.0;
	if (waist > gone) {
		// (the edge drifting up through it, like smoke)
		float wisp = noise(world * 5.0 + vec3(0.0, -TIME * 0.9, TIME * 0.2)) * 0.65
			+ noise(world * 11.0 + vec3(TIME * 0.3, -TIME * 1.6, 0.0)) * 0.35;
		float h = world.y - base_y + (wisp - 0.5) * 2.0 * waver;
		fade = smoothstep(gone, waist, h);
	}
	// (lit as the round body too: no facets)
	NORMAL = n;
	// (pale and lit from within: little of the lamp's warm light on it, so it doesn't go muddy)
	ALBEDO = body_color * 0.3;
	EMISSION = body_color * glow * 0.75 + rim_color * rim * glow * 1.4;
	ALPHA = clamp(mix(core_alpha, 0.95, rim), 0.0, 1.0) * fade;
	ROUGHNESS = 0.9;
}
