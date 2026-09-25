shader_type canvas_item;
render_mode unshaded;

// A soft black copy of an object's silhouette, lying on the ground as its
// shadow (see SilhouetteShadow). Blurred a little at the edge, and lighter
// toward its far end (the object's top).

uniform float strength = 0.5;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 2.5;
	float a = texture(TEXTURE, UV).a * 2.0;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	a /= 6.0;
	float fade = mix(0.45, 1.0, UV.y);
	COLOR = vec4(0.0, 0.0, 0.0, a * strength * fade);
}
