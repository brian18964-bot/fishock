shader_type canvas_item;

// One expanding ripple on the water surface (see scripts/ripple.gd). Draws a
// short train of wave crests behind a front that grows from the center to
// the rect's edge, and writes the wave's surface normal to NORMAL_MAP in the
// same encoding as the pre-rendered sprites' normal maps (n * 0.5 + 0.5,
// X right, Y up), so 2D lights (the lantern) shade the crests. Clipped to
// the water zone it was spawned in.

uniform float progress = 0.0;      // 0..1 over the ripple's life
uniform float strength = 1.0;      // wave height / visibility
uniform vec2 zone_center;          // world px
uniform float zone_radius = 1e6;   // world px

const float WAVELENGTH = 0.16;     // in rect-radius units
const float TRAIN = 0.22;          // how far behind the front crests persist

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float front = 1.0 - (1.0 - progress) * (1.0 - progress);  // eases out
	float fade = (1.0 - progress) * (1.0 - progress);
	float d = front - r;  // distance behind the front
	float env = exp(-pow(d / TRAIN, 2.0)) * smoothstep(-0.06, 0.0, d);
	float phase = d / WAVELENGTH * 6.2831853;
	float h = sin(phase) * env;
	// dh/dr = dh/dd * dd/dr, dd/dr = -1 (envelope slope ignored).
	float dh = -cos(phase) * 6.2831853 / WAVELENGTH * env;
	vec2 dir = r > 1e-4 ? p / r : vec2(0.0);
	float s = strength * fade * 0.06;
	// UV y runs down the screen; the encoded normal's Y points up.
	vec3 n = normalize(vec3(-dh * dir.x * s, dh * dir.y * s, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;

	// Crests catch light, troughs read a touch darker than the water.
	float crest = max(h, 0.0);
	float trough = max(-h, 0.0);
	float mask = step(r, 1.0) * step(distance(world_pos, zone_center), zone_radius);
	float k = fade * strength * mask;
	vec4 lit = vec4(0.85, 0.95, 1.0, crest * 0.85 * k);
	vec4 dark = vec4(0.0, 0.05, 0.09, trough * 0.35 * k);
	COLOR = crest > 0.0 ? lit : dark;
}

// The lantern sits at height 0, so a flat, upward-facing surface would
// catch almost none of its light. Treat the light as held a little above
// the water, and add a specular glint off the chop.
const float LIGHT_LIFT = 0.9;

void light() {
	vec3 l = normalize(LIGHT_DIRECTION + vec3(0.0, 0.0, LIGHT_LIFT));
	float ndl = max(dot(NORMAL, l), 0.0);
	vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(NORMAL, hv), 0.0), 30.0) * 0.35;
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb * ndl + vec3(spec)), LIGHT_COLOR.a);
}
