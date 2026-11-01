shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
// A print pressed in the snow (SnowTracks): a darker, bluer patch of the snow in the shape of the
// traveller's own foot (uniform kind), with a paler rim round it; it fades as the print is
// smoothed over again. The instance's custom data: x = how much of it is left (1..0), y = +1 or -1
// (the right or left foot), z = 1 for the tail's drag mark rather than a foot. On the square quad
// the toes point to -v (up in the picture), the heel to +v.
//
// kind: 0 a boot sole, 1 a cat's pad and four toes, 2 a dog's (with claws), 3 a bear's (a broad
// palm, five toes, claws), 4 a cloven hoof (slim: a stag's, 0: a sheep's round one), 5 a bird's
// three toes and a spur behind, 6 a webbed foot with five clawed toes.

uniform int kind = 0;
uniform float slim = 1.0;
uniform vec3 pressed : source_color = vec3(0.42, 0.5, 0.66);
uniform vec3 rim : source_color = vec3(0.92, 0.96, 1.0);
uniform float strength = 0.55;

varying float left;
varying float side;
varying float drag;

void vertex() {
	left = INSTANCE_CUSTOM.x;
	side = INSTANCE_CUSTOM.y;
	drag = INSTANCE_CUSTOM.z;
}

float ell(vec2 p, vec2 c, vec2 r) {
	return length((p - c) / r);
}

// distance to the segment a-b, over the line's half width w (< 1 inside)
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) / w;
}

// a hoof's half: pointed at the front (-y), blunt behind, `len` long and `wid` across
float drop(vec2 p, float len, float wid) {
	float t = (p.y + len * 0.5) / len;
	if (t < 0.0 || t > 1.0) {
		return 9.0;
	}
	float w = wid * pow(sin(t * 3.14159), 0.6) * (0.55 + 0.45 * t);
	return abs(p.x) / max(w, 0.0001);
}

float boot(vec2 p) {
	float t = clamp((p.y + 0.46) / 0.92, 0.0, 1.0);
	float width = 0.34 - 0.1 * smoothstep(0.3, 0.62, t) + 0.03 * smoothstep(0.62, 0.85, t);
	float cap = sqrt(max(1.0 - pow(abs(2.0 * t - 1.0), 4.0), 0.0));
	float across = abs(p.x - 0.02 * (1.0 - t)) / max(width * cap, 0.001);
	return abs(p.y) > 0.47 ? 9.0 : across;
}

float cat_paw(vec2 p) {
	float d = ell(p, vec2(0.0, 0.14), vec2(0.2, 0.15));
	d = min(d, ell(p, vec2(-0.21, -0.09), vec2(0.075, 0.1)));
	d = min(d, ell(p, vec2(-0.075, -0.22), vec2(0.075, 0.1)));
	d = min(d, ell(p, vec2(0.075, -0.22), vec2(0.075, 0.1)));
	d = min(d, ell(p, vec2(0.21, -0.09), vec2(0.075, 0.1)));
	return d;
}

float dog_paw(vec2 p) {
	float d = ell(p, vec2(0.0, 0.14), vec2(0.17, 0.16));
	d = min(d, ell(p, vec2(-0.19, -0.07), vec2(0.07, 0.1)));
	d = min(d, ell(p, vec2(-0.07, -0.2), vec2(0.07, 0.1)));
	d = min(d, ell(p, vec2(0.07, -0.2), vec2(0.07, 0.1)));
	d = min(d, ell(p, vec2(0.19, -0.07), vec2(0.07, 0.1)));
	// the claws, a dash beyond each toe
	d = min(d, ell(p, vec2(-0.2, -0.19), vec2(0.022, 0.04)));
	d = min(d, ell(p, vec2(-0.075, -0.32), vec2(0.022, 0.04)));
	d = min(d, ell(p, vec2(0.075, -0.32), vec2(0.022, 0.04)));
	d = min(d, ell(p, vec2(0.2, -0.19), vec2(0.022, 0.04)));
	return d;
}

float bear_paw(vec2 p) {
	float d = ell(p, vec2(0.0, 0.16), vec2(0.21, 0.21));
	for (int i = 0; i < 5; i++) {
		float x = -0.2 + 0.1 * float(i);
		float y = -0.15 - 0.1 * (1.0 - abs(x) / 0.2) * 0.9;
		d = min(d, ell(p, vec2(x, y), vec2(0.06, 0.075)));
		d = min(d, ell(p, vec2(x * 1.08, y - 0.115), vec2(0.02, 0.04)));
	}
	return d;
}

float hoof(vec2 p) {
	float len = mix(0.5, 0.68, slim);
	float wid = mix(0.125, 0.09, slim);
	float d = drop(vec2(p.x - 0.07, p.y + 0.02), len, wid);
	return min(d, drop(vec2(p.x + 0.07, p.y + 0.02), len, wid));
}

float bird(vec2 p) {
	vec2 o = vec2(0.0, 0.06);
	float d = ell(p, o, vec2(0.075, 0.075));
	d = min(d, seg(p, o, vec2(-0.27, -0.32), 0.055));
	d = min(d, seg(p, o, vec2(0.0, -0.42), 0.055));
	d = min(d, seg(p, o, vec2(0.27, -0.32), 0.055));
	d = min(d, seg(p, o, vec2(0.0, 0.4), 0.055));
	return d;
}

// returns the print's strength (1 a toe, less where the web is)
float croc(vec2 p, out float web) {
	vec2 o = vec2(0.0, 0.14);
	float d = ell(p, o + vec2(0.0, 0.04), vec2(0.11, 0.1));
	for (int i = 0; i < 5; i++) {
		float a = -1.1 + 0.55 * float(i);
		vec2 dir = vec2(sin(a), -cos(a));
		d = min(d, seg(p, o, o + dir * 0.36, 0.05));
		d = min(d, ell(p, o + dir * 0.4, vec2(0.025, 0.035)));
	}
	// the web between the toes, scalloped
	vec2 q = p - o;
	float r = length(q);
	float ang = atan(q.x, -q.y);
	float lim = 0.31 - 0.09 * (0.5 - 0.5 * cos(ang * 6.2832 / 0.55));
	web = (1.0 - smoothstep(lim - 0.03, lim, r)) * step(abs(ang), 1.2);
	return d;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float body;
	float ringv;
	if (drag > 0.5) {
		// the tail dragged: a shallow trough wandering a little, thinning out at both ends
		float w = abs(p.x - 0.1 * sin(p.y * 9.0));
		float ends = smoothstep(0.5, 0.3, abs(p.y));
		body = (1.0 - smoothstep(0.06, 0.15, w)) * ends * 0.55;
		ringv = 0.0;
	} else {
		p.x *= side;
		float d;
		float web = 0.0;
		if (kind == 1) {
			d = cat_paw(p);
		} else if (kind == 2) {
			d = dog_paw(p);
		} else if (kind == 3) {
			d = bear_paw(p);
		} else if (kind == 4) {
			d = hoof(p);
		} else if (kind == 5) {
			d = bird(p);
		} else if (kind == 6) {
			d = croc(p, web);
		} else {
			d = boot(p);
		}
		body = 1.0 - smoothstep(0.78, 1.0, d);
		body = max(body, web * 0.6);
		ringv = smoothstep(0.98, 1.1, d) * (1.0 - smoothstep(1.1, 1.4, d)) * 0.28;
	}
	ALBEDO = mix(rim, pressed, clamp(body * 1.6, 0.0, 1.0));
	ROUGHNESS = 1.0;
	ALPHA = (body * strength + ringv) * left;
	if (ALPHA < 0.01) {
		discard;
	}
}
