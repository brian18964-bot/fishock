// User request: the characters' ears (the owl's tufts) and tails move on
// their own. In the game the sprite's pixels round each one's line on the
// sheet (PlayerVisual: the frame's "sway" data, and how far each is turned
// now) are turned about its root - more toward the tip, none `reach` px
// off the line. Shared by the body (player_body.gdshader) and its layer in
// front of the rod (body_front.gdshader), so the two stay one picture.
const int SWAY_MAX = 5;
uniform int sway_count = 0;
// root x, y, tip x, y - in the sprite's own px (the feet at 0, 0)
uniform vec4 sway_line[SWAY_MAX];
// how far it's turned now (rad), and how far off its line it takes in (px)
uniform float sway_turn[SWAY_MAX];
uniform float sway_reach[SWAY_MAX];
// the frame's part of the sheet (UV: position, size): nothing read past it
uniform vec4 sway_frame = vec4(0.0, 0.0, 1.0, 1.0);

varying vec2 sway_at;

// Where the texel shown at `p` (the sprite's own px) is read from.
vec2 sway_from(vec2 p) {
	vec2 q = p;
	for (int i = 0; i < SWAY_MAX; i++) {
		if (i >= sway_count) {
			break;
		}
		vec2 r = sway_line[i].xy;
		vec2 d = sway_line[i].zw - r;
		float u = dot(p - r, d) / max(dot(d, d), 1.0);
		float off = length(p - (r + d * clamp(u, 0.0, 1.0)));
		float w = smoothstep(0.15, 0.7, u) * (1.0 - smoothstep(sway_reach[i] * 0.6, sway_reach[i], off));
		float a = -sway_turn[i] * w;
		vec2 o = p - r;
		q += r + vec2(o.x * cos(a) - o.y * sin(a), o.x * sin(a) + o.y * cos(a)) - p;
	}
	return q;
}

// The UV to read at, for the texel shown at UV `uv` (sprite px `p`).
vec2 sway_uv(vec2 uv, vec2 p, vec2 texel) {
	if (sway_count == 0) {
		return uv;
	}
	return clamp(uv + (sway_from(p) - p) * texel, sway_frame.xy, sway_frame.xy + sway_frame.zw);
}
