shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
// A print pressed in the snow (SnowTracks): the character's own sole as baked from its model
// (tools/bake_footprints.gd: a cell of `soles` per character and foot, white where the sole meets
// the ground, brighter where it's lower) - a darker, bluer patch of the snow, deeper toward the
// sole's lowest parts, with a paler rim round it; it fades as the print smooths over.
// The instance's custom data: x = how much of it is left (1..0), y = the cell's column (0 the
// left foot, 1 the right), z = its row (the character), w = how deep (the weight, the pace).
// The quad's UV is the cell's: u across the foot (its left to its right), v from the toe (0).

uniform sampler2D soles : filter_linear_mipmap, repeat_disable;
uniform float rows = 12.0;
uniform vec3 pressed : source_color = vec3(0.3, 0.37, 0.52);
uniform vec3 rim : source_color = vec3(0.93, 0.96, 1.0);

varying float left;
varying vec2 cell;
varying float deep;

void vertex() {
	left = INSTANCE_CUSTOM.x;
	cell = INSTANCE_CUSTOM.yz;
	deep = INSTANCE_CUSTOM.w;
}

float sole_at(vec2 uv) {
	uv = clamp(uv, vec2(0.01), vec2(0.99));
	return texture(soles, vec2((cell.x + uv.x) / 2.0, (cell.y + uv.y) / rows)).r;
}

void fragment() {
	float s = sole_at(UV);
	// (the rim: a little snow pushed up just outside the sole)
	float o = 0.035;
	float around = max(max(sole_at(UV + vec2(o, 0.0)), sole_at(UV - vec2(o, 0.0))),
		max(sole_at(UV + vec2(0.0, o)), sole_at(UV - vec2(0.0, o))));
	float body = smoothstep(0.12, 0.5, s);
	float ring = clamp(smoothstep(0.12, 0.5, around) - body, 0.0, 1.0);
	float press = body * (0.55 + 0.45 * s);
	ALBEDO = mix(rim, pressed, clamp(press * 1.6, 0.0, 1.0));
	ROUGHNESS = 1.0;
	ALPHA = (press * mix(0.55, 0.95, deep) + ring * 0.3) * left;
	if (ALPHA < 0.01) {
		discard;
	}
}
