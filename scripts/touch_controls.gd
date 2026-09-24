class_name TouchControls
extends CanvasLayer

## On-screen buttons for phones (the web build, played on iPhone). Each one
## holds the matching keyboard key down while touched, so every existing
## key check in the game works untouched. TouchScreenButton does its own
## multi-touch next to the two virtual joysticks and hides itself where
## there's no touchscreen, so desktop play is unchanged.
##
## User request: laid out the way mobile games usually do it - the action
## buttons fan round the right-hand control (the aim stick) so the right
## thumb reaches them all: the big cast/reel button just left of the stick,
## the others in an arc over it, brightness +/- smallest at the far end.
## Everything is see-through so the field stays visible.

## Aim stick center in the 960x540 layout (AimJoystick in main.tscn: a
## 300x300 control at the bottom-right corner, 8 px in).
const AIM_CENTER := Vector2(802, 382)

const BUTTONS := [
	# [label, key, angle around the aim stick (deg, clockwise from right), distance, radius]
	["拋竿\n收線", KEY_SPACE, 165.0, 150.0, 42.0],
	["切換", KEY_TAB, 205.0, 150.0, 26.0],
	["燈", KEY_L, 232.0, 150.0, 26.0],
	["閃光", KEY_F, 259.0, 150.0, 26.0],
	["丟魚", KEY_G, 286.0, 150.0, 26.0],
	["暗", KEY_BRACKETLEFT, 314.0, 140.0, 19.0],
	["亮", KEY_BRACKETRIGHT, 338.0, 140.0, 19.0],
]
const FILL := Color(1, 1, 1, 0.1)
const FILL_PRESSED := Color(1, 1, 1, 0.38)
const RIM_ALPHA := 0.45


func _ready() -> void:
	layer = 5
	for spec in BUTTONS:
		var center: Vector2 = AIM_CENTER + Vector2.RIGHT.rotated(deg_to_rad(spec[2])) * spec[3]
		_add_button(spec[0], spec[1], center, spec[4])


func _add_button(text: String, key: Key, center: Vector2, radius: float) -> void:
	var button := TouchScreenButton.new()
	button.texture_normal = _disc(radius, FILL)
	button.texture_pressed = _disc(radius, FILL_PRESSED)
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
	label.add_theme_font_size_override("font_size", 18 if radius > 40.0 else (14 if radius > 20.0 else 13))
	label.modulate.a = 0.85
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
				var col := fill.lerp(Color(1, 1, 1, RIM_ALPHA), rim)
				col.a *= 1.0 - smoothstep(radius - 1.0, radius, d)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
