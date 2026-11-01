shader_type spatial;
render_mode specular_schlick_ggx;
// A model under snow (RunView3D's snowy map): its own texture, whitened where the surface faces
// up - the boughs' tops, the rocks' backs - and a light dusting all over the boughs; and the
// distance fade the plain materials have (pixels dithered away close to the camera).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool scissor = false;
uniform float scissor_cut = 0.45;
uniform float fade_min = -1.0;
uniform float fade_max = -0.5;
// how much of the up-facing surface the snow covers, and the dusting everywhere
uniform float cover = 0.9;
uniform float dust = 0.0;
// an even whitening (a winter coat), whatever the surface faces
uniform float whiten = 0.0;
uniform vec3 snow_color : source_color = vec3(0.92, 0.95, 1.0);
uniform float rough = 0.9;

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	float s = clamp(max(up * cover + dust, whiten), 0.0, 1.0);
	ALBEDO = mix(t.rgb, snow_color, s);
	ROUGHNESS = mix(0.95, rough, s);
}
