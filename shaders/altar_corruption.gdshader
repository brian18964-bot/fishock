shader_type canvas_item;

// User feedback: the altar's corrosion looked slapdash (dark blots dropped
// on it). Now it's in the stone itself: rot creeps across it in veined
// patches from the edges in, black-violet, with cracks that glow a sickly
// violet and pulse - spreading and deepening with each evil offering
// (corruption 0..1, altar.gd). Only where the stone is (the sprite's alpha).

uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 rot_color : source_color = vec4(0.1, 0.04, 0.12, 1.0);
uniform vec4 crack_color : source_color = vec4(0.72, 0.3, 1.0, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (corruption > 0.001) {
		float n = texture(noise, UV * 1.3).r * 0.65 + texture(noise, UV * 3.7 + vec2(0.4, 0.2)).r * 0.35;
		// Creeping in from the rim: the edge of the dais goes first.
		float rim = length((UV - vec2(0.5, 0.55)) * vec2(1.0, 1.6));
		float reach = corruption * 0.85;
		float rot = smoothstep(reach, reach - 0.15, n * 0.8 + (0.6 - rim) * 0.7);
		// The stone darkened and stained - still stone, not paint.
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		vec3 rotted = mix(vec3(lum), rot_color.rgb * 3.0, 0.45) * (0.45 + 0.35 * n);
		c.rgb = mix(c.rgb, rotted, rot * 0.9);
		// Cracks: veins along bands of the noise, only inside the rot,
		// glowing and pulsing.
		float band = 1.0 - smoothstep(0.03, 0.075, abs(fract(n * 4.0 + 0.13) - 0.5));
		float pulse = 0.55 + 0.45 * sin(TIME * 2.2 + n * 9.0);
		c.rgb = mix(c.rgb, crack_color.rgb, band * smoothstep(0.3, 0.8, rot) * pulse * (0.5 + 0.5 * corruption));
	}
	COLOR = c * COLOR;
}
