shader_type canvas_item;

// User request: the scene felt dead - slow drifting fog over the world.
// Lit like the ground (see LightTwin), so the lantern beam shows in it and
// trunks throw shafts of shadow through it; the whole bank swells and
// thins slowly.

uniform sampler2D noise_a : repeat_enable, filter_linear;
uniform sampler2D noise_b : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.62, 0.66, 0.72, 1.0);
uniform float density = 0.18;
uniform vec2 drift_a = vec2(7.0, 2.5);   // world px per second
uniform vec2 drift_b = vec2(-4.5, 3.5);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float a = texture(noise_a, (world + drift_a * TIME) / 720.0).r;
	float b = texture(noise_b, (world + drift_b * TIME) / 330.0).r;
	float swell = 0.85 + 0.15 * sin(TIME * 0.45);
	float d = smoothstep(0.32, 0.85, a * 0.65 + b * 0.35) * density * swell;
	COLOR = vec4(fog_color.rgb, d);
}
