shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
// A boot print pressed in the snow (SnowTracks): a darker, bluer patch of the snow in the shape of
// a sole and a heel, with a paler rim round it; it fades as the print is smoothed over again.
// The instance's custom data: x = how much of it is left (1..0), y = +1 or -1 (the right or left foot).
// The quad's -v end is the toe.

uniform vec3 pressed : source_color = vec3(0.42, 0.5, 0.66);
uniform vec3 rim : source_color = vec3(0.92, 0.96, 1.0);
uniform float strength = 0.55;

varying float left;
varying float side;

void vertex() {
	left = INSTANCE_CUSTOM.x;
	side = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= side;
	// one boot sole: broad at the ball of the foot, narrower through the arch, a heel a little
	// wider again (p.y: -0.5 the toe .. +0.5 the heel), the ends rounded
	float t = clamp((p.y + 0.46) / 0.92, 0.0, 1.0);
	float width = 0.34 - 0.1 * smoothstep(0.3, 0.62, t) + 0.03 * smoothstep(0.62, 0.85, t);
	float cap = sqrt(max(1.0 - pow(abs(2.0 * t - 1.0), 4.0), 0.0));
	float across = abs(p.x - 0.02 * (1.0 - t)) / max(width * cap, 0.001);
	float inside = step(abs(p.y), 0.47);
	float body = (1.0 - smoothstep(0.78, 1.0, across)) * inside;
	float ring = smoothstep(0.98, 1.1, across) * (1.0 - smoothstep(1.1, 1.4, across)) * inside;
	ALBEDO = mix(rim, pressed, body);
	ROUGHNESS = 1.0;
	ALPHA = (body * strength + ring * 0.28) * left;
	if (ALPHA < 0.01) {
		discard;
	}
}
