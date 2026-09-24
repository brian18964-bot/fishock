class_name TouchControls
extends CanvasLayer

## On-screen buttons for phones (the web build, played on iPhone). Each one
## holds the matching keyboard key down while touched, so every existing
## key check in the game works untouched. TouchScreenButton does its own
## multi-touch next to the two virtual joysticks and hides itself where
## there's no touchscreen, so desktop play is unchanged.
##
## Laid out in the strip between the two joysticks (which own the bottom
## corners): the big cast/reel button right of centre, next to the aim
## stick's thumb; the rest in a small grid to its left.

const BUTTONS := [
	# [label, key, center (960x540 layout), radius]
	["拋竿\n收線", KEY_SPACE, Vector2(582, 452), 60.0],
	["切換", KEY_TAB, Vector2(370, 418), 30.0],
	["燈", KEY_L, Vector2(440, 418), 30.0],
	["閃光", KEY_F, Vector2(370, 490), 30.0],
	["丟魚", KEY_G, Vector2(440, 490), 30.0],
	["暗", KEY_BRACKETLEFT, Vector2(378, 356), 20.0],
	["亮", KEY_BRACKETRIGHT, Vector2(432, 356), 20.0],
]


func _ready() -> void:
	layer = 5
	for spec in BUTTONS:
		_add_button(spec[0], spec[1], spec[2], spec[3])


func _add_button(text: String, key: Key, center: Vector2, radius: float) -> void:
	var button := TouchScreenButton.new()
	button.texture_normal = _disc(radius, Color(1, 1, 1, 0.18))
	button.texture_pressed = _disc(radius, Color(1, 1, 1, 0.42))
	var shape := CircleShape2D.new()
	shape.radius = radius
	button.shape = shape
	button.shape_centered = true
	button.position = center - Vector2(radius, radius)
	button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	button.pressed.connect(_send.bind(key, true))
	button.released.connect(_send.bind(key, false))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(radius, radius) * 2.0
	label.add_theme_font_size_override("font_size", 18 if radius > 40.0 else 14)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	add_child(button)


func _send(key: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = down
	Input.parse_input_event(ev)


## A soft filled circle with a brighter rim.
static func _disc(radius: float, fill: Color) -> ImageTexture:
	var size := int(ceil(radius * 2.0))
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(radius, radius)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= radius:
				var rim := smoothstep(radius - 3.0, radius - 1.0, d)
				var col := fill.lerp(Color(1, 1, 1, 0.75), rim)
				col.a *= 1.0 - smoothstep(radius - 1.0, radius, d)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
