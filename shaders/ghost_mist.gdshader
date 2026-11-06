// User request (the floating ghost, plan B): an airy ghost - its lower body and tail thinning
// out into mist from the waist down (the tail's hard shape gone), a little see-through, lit from
// within and glowing at its edges so the night doesn't swallow it. RunView3D._mist_ghost.
//
// `base_y` (per instance, each frame): the world height of the ghost's holder - the fade is
// measured up from it (waist / gone, in m), the edge wavering with a drifting noise. `center`
// (per instance): the middle of its head in the world - its glowing edge taken mostly from a
// round body about it, so the model's flat facets don't show through as a patchwork.
//
// Its arms (user request: not stuck on stiffly): the parts of it out from its body, in front, at
// its arms' height (in its own space: `to_ghost` / `from_ghost`, its holder's), moved by `hand`
// (RunView3D's spring: trailing behind its going, swinging past and back) and pawing the air -
// the two out of step. Its claws, whole, go with them.
shader_type spatial;
render_mode cull_back, depth_draw_always, specular_disabled, world_vertex_coords;

uniform vec3 body_color : source_color = vec3(0.86, 0.88, 0.97);
uniform vec3 rim_color : source_color = vec3(0.62, 0.78, 1.0);
// How solid the middle of it is (the edges are more so: they glow).
uniform float core_alpha = 0.7;
uniform float rim_power = 2.0;
uniform float glow = 0.62;
// Faded from `waist` (whole) down to `gone` (nothing), m over its holder; 0/0 keeps it whole
// (its claws and eyes).
uniform float waist = 1.48;
uniform float gone = 1.14;
uniform float waver = 0.09;
instance uniform float base_y = 0.0;
instance uniform vec3 center = vec3(0.0);
uniform mat4 to_ghost = mat4(1.0);
uniform mat4 from_ghost = mat4(1.0);
uniform vec3 hand = vec3(0.0);
uniform float paw_t = 0.0;
// User request (its tail went one way only): the model's tail curls off to its right and back,
// whatever it does - straightened here (TAIL_BAKED at its tip, less up it), then hung where `tail`
// says (RunView3D's spring, in its holder's space at the tip: trailing behind its going, swinging
// past and back, draped back a little at rest), a slow wave going down it.
uniform vec3 tail = vec3(0.0, 0.0, -0.25);
// (its body's middle, from above, and its arms' height: m in its holder's space)
const vec2 AXIS = vec2(-0.15, 0.05);
const float ARMS = 1.42;
// (where its tail starts and ends, m up its holder; its tip's curl as made, from the axis)
const float HIP = 1.38;
const float TIP = 0.9;
const vec2 TAIL_BAKED = vec2(0.68, -0.46);
const float ARM_DROOP = 0.75;

varying vec3 world;
// (how much of it is arm: kept whole, never thinned away - its claws would hang there alone)
varying float arm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 local = (to_ghost * vec4(VERTEX, 1.0)).xyz;
	vec2 off = local.xz - AXIS;
	arm = smoothstep(0.24, 0.42, length(off)) * smoothstep(-0.02, 0.12, off.y)
		* (1.0 - smoothstep(0.1, 0.22, abs(local.y - ARMS)));
	// Its arms (user request: their moving unnatural - they rippled along their length): each one
	// swung whole from the shoulder - the farther out, the more it moves, as a limb turning would -
	// drifting up and down and to and fro as if held up in water, the two out of step, and
	// trailing on their spring.
	float reach = smoothstep(0.18, 0.6, length(off));
	float which = smoothstep(-0.12, 0.12, off.x);
	vec3 drift = vec3(0.0,
		0.075 * sin(paw_t * 1.25 + which * 1.9) + 0.025 * sin(paw_t * 2.3 + which * 0.7),
		0.05 * sin(paw_t * 0.85 + which * 2.4 + 1.0));
	vec3 move = (hand + drift) * arm * reach;
	// (the model holds an arm straight out to the side, stiff: let down from the shoulder - turned
	// ARM_DROOP rad down about it, the way an arm hangs when nothing holds it up)
	float out_from = max(length(off) - 0.25, 0.0) * arm;
	vec2 out_dir = normalize(off + vec2(0.0001));
	move.xz += out_dir * out_from * (cos(ARM_DROOP) - 1.0);
	move.y -= out_from * sin(ARM_DROOP);
	// Its tail: straightened, then hung back where it's trailing, a wave going down it.
	float d = clamp((HIP - local.y) / (HIP - TIP), 0.0, 1.0) * (1.0 - arm);
	vec2 straight = -TAIL_BAKED * pow(d, 0.7);
	vec2 hang = tail.xz * pow(d, 1.25);
	vec2 wave = vec2(sin(paw_t * 1.15 - d * 2.6), cos(paw_t * 0.8 - d * 2.1)) * 0.09 * pow(d, 1.4);
	move.xz += straight + hang + wave;
	VERTEX += (from_ghost * vec4(move, 0.0)).xyz;
	world = VERTEX;
}

void fragment() {
	vec3 round_n = normalize((VIEW_MATRIX * vec4(normalize(world - center), 0.0)).xyz);
	vec3 n = normalize(mix(NORMAL, round_n, 0.92));
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), rim_power);
	float fade = 1.0;
	if (waist > gone) {
		// (the edge drifting up through it, like smoke)
		float wisp = noise(world * 5.0 + vec3(0.0, -TIME * 0.9, TIME * 0.2)) * 0.65
			+ noise(world * 11.0 + vec3(TIME * 0.3, -TIME * 1.6, 0.0)) * 0.35;
		float h = world.y - base_y + (wisp - 0.5) * 2.0 * waver;
		fade = max(smoothstep(gone, waist, h), arm);
	}
	// (lit as the round body too: no facets)
	NORMAL = n;
	// (pale and lit from within: little of the lamp's warm light on it, so it doesn't go muddy)
	ALBEDO = body_color * 0.3;
	// (its thin arms all edge: their glow kept down, or the far one shines through its head)
	EMISSION = body_color * glow * 0.75 + rim_color * rim * glow * 1.4 * (1.0 - 0.7 * arm);
	ALPHA = clamp(mix(core_alpha, 0.95, rim), 0.0, 1.0) * fade;
	ROUGHNESS = 0.9;
}
