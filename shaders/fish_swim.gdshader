shader_type spatial;
// A fish model swimming (FishModel): a wave runs from the head back to the
// tail, bending the body side to side, stronger toward the tail. The model
// is 1 long, head toward +x (tail tip near x = -0.72), back up (+y), its
// flanks facing +-z. `beat` is the tail beat's phase (advanced by the
// script, faster when it hurries); `sway` how far it bends.

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;
uniform float beat = 0.0;
uniform float sway = 0.06;
// 0..1: brightens the fish (picked in the tank).
uniform float glow = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.4);
// Dead (user request): the eyes (the mesh's vertex colour red) all white,
// the colours dulled and the sheen gone; rotten: the body going purple or
// green (`rot` 0..1, `rot_color`), in blotches.
uniform float dead = 0.0;
uniform float rot = 0.0;
uniform vec3 rot_color : source_color = vec3(0.45, 0.5, 0.2);

float blotch(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	float x = VERTEX.x;
	float k = sway * (0.12 + smoothstep(0.3, -0.75, x));
	VERTEX.z += sin(beat - x * 5.5) * k;
	// The flank turns with the bend (its slope along x), so the light
	// slides over it as it swims.
	float slope = -5.5 * cos(beat - x * 5.5) * k;
	NORMAL = normalize(vec3(NORMAL.x - slope * NORMAL.z, NORMAL.y, NORMAL.z));
}

void fragment() {
	vec3 c = texture(skin, UV).rgb;
	if (dead > 0.0) {
		float grey = dot(c, vec3(0.3, 0.5, 0.2));
		c = mix(c, vec3(grey) * vec3(0.92, 0.95, 1.0), 0.4 * dead);
		c *= 1.0 - 0.18 * dead;
	}
	if (rot > 0.0) {
		float n = 0.55 * blotch(UV * 26.0) + 0.45 * blotch(UV * 70.0);
		c = mix(c, rot_color * (0.7 + 0.5 * n), clamp(rot * (0.5 + 0.5 * n), 0.0, 0.92));
	}
	ALBEDO = c;
	ROUGHNESS = mix(0.42, 0.7, dead);
	SPECULAR = mix(0.6, 0.3, dead);
	// A wet sheen at grazing angles, and the picked glow.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rim * 0.25 * (1.0 - dead) + glow_color * glow * (0.25 + rim);
	if (dead > 0.5 && COLOR.r > 0.5) {
		// the eyes: plain white, nothing in them
		ALBEDO = vec3(0.93, 0.93, 0.9);
		ROUGHNESS = 0.25;
		SPECULAR = 0.5;
		EMISSION = vec3(0.12);
	}
}
