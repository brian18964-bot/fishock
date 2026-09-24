shader_type canvas_item;
render_mode blend_disabled, unshaded;

// One step of the water height simulation (see scripts/water_sim.gd):
// the damped 2D wave equation on a grid covering the whole map, one texel
// per SIM_CELL world px (rows foreshortened by sin 55deg, so waves spread
// in circles on the art's ground plane and show as ellipses on screen).
//
// State lives in an 8-bit RGBA target, so each height is packed into two
// channels as 16 bits: RG = height now, BA = height one step ago.
// Anything outside the water zones is held at 0, so waves reflect off the
// shore.

uniform sampler2D previous : filter_nearest;
uniform vec2 grid_size;
uniform vec2 cell_px;              // world px per texel (x, y)
uniform float wave_speed = 0.45;   // c^2 in cells/step, < 0.75 for stability
uniform float damping = 0.988;
uniform bool reset = false;
uniform vec4 zones[32];            // water lobes: world center xy, radius z
uniform int zone_count = 0;
uniform vec4 impulses[16];         // world xy, radius px z, strength w
uniform int impulse_count = 0;

vec2 pack(float h) {
	float u = clamp(h * 0.5 + 0.5, 0.0, 1.0) * 65535.0;
	float hi = floor(u / 256.0);
	return vec2(hi, u - hi * 256.0) / 255.0;
}

float unpack(vec2 v) {
	float u = round(v.x * 255.0) * 256.0 + round(v.y * 255.0);
	return u / 65535.0 * 2.0 - 1.0;
}

float height_at(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(grid_size) - 1);
	return unpack(texelFetch(previous, c, 0).rg);
}

void fragment() {
	ivec2 c = ivec2(FRAGCOORD.xy);
	vec2 world = (vec2(c) + 0.5) * cell_px;
	bool wet = false;
	for (int i = 0; i < zone_count; i++) {
		if (distance(world, zones[i].xy) < zones[i].z) {
			wet = true;
		}
	}
	vec4 here = texelFetch(previous, c, 0);
	float h = unpack(here.rg);
	float h_old = unpack(here.ba);
	// Isotropic 9-point Laplacian: a 4-neighbour one bends rings into
	// rounded squares as they spread.
	float edges = height_at(c + ivec2(1, 0)) + height_at(c - ivec2(1, 0))
			+ height_at(c + ivec2(0, 1)) + height_at(c - ivec2(0, 1));
	float corners = height_at(c + ivec2(1, 1)) + height_at(c + ivec2(-1, 1))
			+ height_at(c + ivec2(1, -1)) + height_at(c + ivec2(-1, -1));
	float lap = (4.0 * edges + corners - 20.0 * h) / 6.0;
	float h_new = (2.0 * h - h_old + wave_speed * lap) * damping;
	for (int i = 0; i < impulse_count; i++) {
		// Distance measured on the ground plane (rows unsquashed).
		vec2 d = (world - impulses[i].xy) * vec2(1.0, cell_px.x / cell_px.y);
		float r = impulses[i].z;
		h_new += impulses[i].w * exp(-dot(d, d) / (r * r));
	}
	if (!wet || reset) {
		h_new = 0.0;
		h = 0.0;
	}
	COLOR = vec4(pack(h_new), pack(h));
}
