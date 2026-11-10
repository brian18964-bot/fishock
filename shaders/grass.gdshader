shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled;
// Grass (user request, stage three of the wind): clumps of blades about the traveller (GrassField),
// bending in the wind - the same wind the trees bend to (Foliage's shader globals) - and pushed
// aside by whoever walks through: up to 12 pushers (RunView3D: the traveller, its last few steps
// fading - so the grass springs back slowly behind it - and the animals and ghosts near), each
// [x, y, z, reach]; a blade within a pusher's reach leans away from it and down. UV.y is how far up
// the blade (0 at its root). Dithered away past fade_near..fade_far from the camera.

uniform vec3 base_color : source_color = vec3(0.12, 0.2, 0.07);
uniform vec3 tip_color : source_color = vec3(0.32, 0.45, 0.16);
uniform float fade_near = 11.0;
uniform float fade_far = 15.0;
// how far a pushed blade's tip goes aside (a share of its height), and the wind's lean
uniform float bend = 0.55;
uniform float sway = 0.14;
uniform vec4 movers[12];
global uniform float foliage_wind;
global uniform vec2 foliage_wind_dir;

varying float up;

void vertex() {
	up = UV.y;
	vec3 o = MODEL_MATRIX[3].xyz;
	float tall = length(MODEL_MATRIX[1].xyz);
	float k = UV.y * UV.y;
	float gust = 0.55 + 0.45 * sin(TIME * 0.5 + o.x * 0.05) * sin(TIME * 0.31 + o.z * 0.07 + 1.3);
	float wob = sin(TIME * 2.4 + dot(o.xz, vec2(1.3, 1.7))) * 0.35 + sin(TIME * 4.1 + o.x * 2.1) * 0.12;
	vec2 off = normalize(foliage_wind_dir) * (gust + wob) * foliage_wind * sway * tall * k;
	vec2 push = vec2(0.0);
	float press = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 m = movers[i];
		if (m.w <= 0.0) {
			continue;
		}
		vec2 dd = o.xz - m.xz;
		float dist = length(dd);
		float f = clamp(1.0 - dist / m.w, 0.0, 1.0);
		if (f > 0.0) {
			push += (dist > 0.001 ? dd / dist : vec2(1.0, 0.0)) * f;
			press = max(press, f);
		}
	}
	if (press > 0.0) {
		off += normalize(push) * min(length(push), 1.0) * bend * tall * k;
		VERTEX.y -= press * bend * 0.7 * tall * k;
	}
	VERTEX.xz += off;
}

void fragment() {
	float f = 1.0 - smoothstep(fade_near, fade_far, -VERTEX.z);
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (noise > f) {
		discard;
	}
	ALBEDO = mix(base_color, tip_color, up) * COLOR.rgb;
	ROUGHNESS = 1.0;
}
