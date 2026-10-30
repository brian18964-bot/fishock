shader_type spatial;
// The fish on the line, seen through the water (RunView3D's under-water fish, for the
// fight's small picture): FishModel's swimming body, drawn over the water, tinted a
// watery blue and see-through - fainter the deeper it is (`see`).
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;
uniform float beat = 0.0;
uniform float sway = 0.06;
uniform float see = 0.7;
uniform vec3 tint : source_color = vec3(0.35, 0.7, 0.9);
uniform float tint_k = 0.4;

void vertex() {
	float x = VERTEX.x;
	float k = sway * (0.12 + smoothstep(0.3, -0.75, x));
	VERTEX.z += sin(beat - x * 5.5) * k;
}

void fragment() {
	vec3 c = texture(skin, UV).rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(c, tint, tint_k) * (0.85 + 0.35 * rim);
	ALPHA = see;
}
