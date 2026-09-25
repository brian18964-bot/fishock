shader_type canvas_item;

// Hides whatever of the sprite is below `cut_y` (in the sprite's own local
// px) - the water line, for the water ghost wading in or out (WaterGhost).
uniform float cut_y = 100000.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	if (local_y > cut_y) {
		discard;
	}
}
