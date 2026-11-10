shader_type spatial;
render_mode specular_schlick_ggx, world_vertex_coords;
// Trees and plants in the wind (user request: every map's trees and plants swaying naturally, and a
// chopped tree shaking): shaders/snow_cover.gdshader's look - its own picture, cut out by its
// alpha, snow on the tops on the snowy map, dithered away close to the camera - with the model bent
// by the wind. Its foot stays put, its top leans the most (the square of the height), with the
// map's gusts (slow, each tree in its own phase), a small sway back and forth, the parts out from
// the trunk bobbing a little more and the leaves fluttering. A chopped tree's own copy has `shake`
// (RunView3D._shake_tree): the whole tree swings and settles.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool scissor = false;
uniform float scissor_cut = 0.45;
uniform float fade_min = -1.0;
uniform float fade_max = -0.5;
uniform float cover = 0.0;
uniform float dust = 0.0;
uniform vec3 snow_color : source_color = vec3(0.92, 0.95, 1.0);
uniform float rough = 0.9;

// the model's own height (m, before its scale) and how far its top leans, a share of that height,
// in an ordinary wind; the parts out from the trunk bob this much a metre out; the leaves' flutter (m)
uniform float height = 10.0;
uniform float sway = 0.012;
uniform float branch = 0.0;
uniform float flutter = 0.0;
// the wind (Foliage.set_wind - project-wide): its strength (1 an ordinary night, more in a storm)
// and the way it blows (x, z)
global uniform float foliage_wind;
global uniform vec2 foliage_wind_dir;
// a chop: the top's swing now (m, signed - set each frame while it settles) and its way
uniform float shake = 0.0;
uniform vec2 shake_dir = vec2(1.0, 0.0);

varying vec3 wn;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float tall = max(height * length(MODEL_MATRIX[1].xyz), 0.01);
	float h = clamp((VERTEX.y - o.y) / tall, 0.0, 1.3);
	float bend = h * h;
	float ph = dot(o.xz, vec2(0.37, 0.61));
	// (the gusts: slow and broad, a tree's neighbours in nearly the same breath)
	float gust = 0.55 + 0.45 * sin(TIME * 0.5 + o.x * 0.05) * sin(TIME * 0.31 + o.z * 0.07 + 1.3);
	float wob = sin(TIME * 1.6 + ph) * 0.35 + sin(TIME * 2.7 + ph * 1.7) * 0.15;
	float wind = foliage_wind;
	float top = sway * tall * bend * wind;
	vec2 d = normalize(foliage_wind_dir);
	VERTEX.xz += d * top * (gust + wob) + shake_dir * shake * bend;
	float r = length(VERTEX.xz - o.xz);
	VERTEX.y += branch * r * h * wind * sin(TIME * 2.3 + ph + VERTEX.y * 0.8);
	if (flutter > 0.0) {
		VERTEX += vec3(sin(TIME * 7.0 + VERTEX.x * 3.1 + VERTEX.z * 1.7),
			sin(TIME * 8.3 + VERTEX.y * 2.9) * 0.6,
			cos(TIME * 6.1 + VERTEX.z * 2.3 + VERTEX.x)) * flutter * min(wind, 2.0) * h;
	}
	wn = NORMAL;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV) * tint;
	if (scissor && t.a < scissor_cut) {
		discard;
	}
	float f = smoothstep(fade_min, fade_max, -VERTEX.z);
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (noise > f) {
		discard;
	}
	vec3 n = FRONT_FACING ? wn : -wn;
	float up = smoothstep(0.15, 0.7, n.y);
	float s = clamp(up * cover + dust, 0.0, 1.0);
	ALBEDO = mix(t.rgb, snow_color, s);
	ROUGHNESS = mix(0.95, rough, s);
}
