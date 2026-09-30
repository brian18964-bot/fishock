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
	ALBEDO = c;
	ROUGHNESS = 0.42;
	SPECULAR = 0.6;
	// A wet sheen at grazing angles, and the picked glow.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rim * 0.25 + glow_color * glow * (0.25 + rim);
}
