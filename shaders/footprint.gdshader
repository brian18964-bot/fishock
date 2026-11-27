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
// The desert's (SnowTracks.sand): a dip in dry sand - shallow, its edges loose and soft (the sole
// read blurred, blurring more as the wind fills it in), the sand pushed up round it in a loose,
// pale rim, more at the toe; in the damp sand by the water (w < 0) crisp and dark, little rim.
uniform bool sand = false;
uniform vec3 sand_pressed : source_color = vec3(0.3, 0.22, 0.13);
uniform vec3 sand_rim : source_color = vec3(0.86, 0.72, 0.52);
uniform vec3 wet_pressed : source_color = vec3(0.17, 0.13, 0.09);
uniform vec3 wet_rim : source_color = vec3(0.36, 0.28, 0.19);
// User request (wet feet: SnowTracks.stain_only - grass, earth, a deck): no dip, the ground just
// darkened with the water in the sole's shape - soft at its edge where the water spread, darkest
// at the heel and the ball (the sole's lowest), as wet as the foot was (w) and drying away (x).
uniform bool stain = false;
uniform vec3 stain_dark : source_color = vec3(0.03, 0.026, 0.022);

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

// (the sole, nothing outside its box - the sand's print has room round it for its rim)
float sole_in(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return sole_at(uv);
}

// (a soft read of the sole - eight taps `b` apart: dry sand doesn't keep a print's edge)
float sole_soft(vec2 uv, float b) {
	float t = sole_in(uv) * 2.0;
	t += sole_in(uv + vec2(b, 0.0)) + sole_in(uv - vec2(b, 0.0));
	t += sole_in(uv + vec2(0.0, b)) + sole_in(uv - vec2(0.0, b));
	t += sole_in(uv + vec2(b, b) * 0.7) + sole_in(uv - vec2(b, b) * 0.7);
	return t / 8.0;
}

void fragment() {
	if (stain) {
		// (the quad's 1.4 x 1.3 the sole's box - SnowTracks: the water spreads out round the sole; a
		// faint wet halo round the print, as much as the foot was wet)
		vec2 wuv = (UV - 0.5) * vec2(1.4, 1.3) + 0.5;
		float wd = clamp(deep, 0.0, 1.0);
		float ws = sole_soft(wuv, 0.04);
		float wbody = smoothstep(0.05, 0.4, ws) * (0.8 + 0.2 * ws);
		float halo = clamp(smoothstep(0.02, 0.2, sole_soft(wuv, 0.13)) - wbody, 0.0, 1.0);
		ALBEDO = stain_dark;
		ROUGHNESS = 0.35;
		ALPHA = (wbody * (0.5 + 0.45 * wd) + halo * 0.3 * wd) * left;
		if (ALPHA < 0.01) {
			discard;
		}
	} else if (sand) {
		bool damp = deep < 0.0;
		float dd = abs(deep);
		// (dry: soft from the first, blurring further as it fills; damp: nearly crisp)
		float bl = damp ? 0.025 + (1.0 - left) * 0.05 : 0.06 + (1.0 - left) * 0.1;
		// (the quad's 1.3 x 1.15 the sole's box - SnowTracks: the sole in its middle)
		vec2 uv = (UV - 0.5) * vec2(1.3, 1.15) + 0.5;
		float ss = sole_soft(uv, bl);
		float around = sole_soft(uv + vec2(0.0, -0.03), bl * 2.4);
		float body_s = smoothstep(0.08, 0.5, ss);
		float ring_s = clamp(smoothstep(0.04, 0.22, around) - body_s * 1.2, 0.0, 1.0);
		// (more sand thrown up at the toe - the push off)
		ring_s *= mix(1.3, 0.6, clamp(uv.y, 0.0, 1.0));
		float press_s = body_s * (0.6 + 0.4 * ss);
		ALBEDO = damp ? mix(wet_rim, wet_pressed, clamp(press_s * 1.5, 0.0, 1.0))
			: mix(sand_rim, sand_pressed, clamp(press_s * 1.4, 0.0, 1.0));
		ROUGHNESS = damp ? 0.7 : 1.0;
		ALPHA = (press_s * (damp ? mix(0.65, 0.95, dd) : mix(0.55, 0.9, dd)) + ring_s * (damp ? 0.12 : 0.4)) * left;
		if (ALPHA < 0.01) {
			discard;
		}
	} else {
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
}
