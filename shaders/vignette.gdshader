shader_type canvas_item;

// User request: "breathing" darkness - the screen edges close in and ease
// off on a slow cycle, with a smoky, creeping border.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform float strength = 0.5;
uniform float period = 7.0;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float r = length(c * vec2(1.0, 0.75)) * 1.6;
	float breathe = sin(TIME * 6.2831853 / period);
	float smoke = texture(noise, SCREEN_UV * 1.3 + vec2(TIME * 0.012, -TIME * 0.009)).r;
	float inner = 0.5 + 0.06 * breathe + (smoke - 0.5) * 0.18;
	float v = smoothstep(inner, inner + 0.42, r);
	COLOR = vec4(0.0, 0.0, 0.0, v * strength * (0.88 + 0.12 * breathe));
}
