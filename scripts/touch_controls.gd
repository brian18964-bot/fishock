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
##
## User request: casting has a direction, and it's the same thumb that
## aims the light - so the cast button doubles as a stick. Press and hold
## to charge, drag to aim the cast (the light turns with it), let go to
## cast. A short tap still works as before.
##
## User request: the lamp's brightness is a slider like iPhone's screen
## brightness in Control Center - drag up on it to brighten, down to dim.
## It moves with the finger (it doesn't jump to where you touch), and its
## fill shows the current brightness.
##
## User request: the lamp button sits right above the aim stick, and the
## slider belongs to it. Unlit, holding the button relights the lamp (its
## ring fills); keep holding once it's lit and the slider pops up over the
## button - slide the same finger up or down. Lit, a long press brings the
## slider up the same way, and a short tap puts the lamp out. Pulled right
## to the bottom, the lamp goes out.

## Aim stick center in the 960x540 layout (AimJoystick in main.tscn: a
## 300x300 control at the bottom-right corner, 8 px in).
const AIM_CENTER := Vector2(802, 382)

const CAST_ANGLE := 165.0
const CAST_DISTANCE := 150.0
const CAST_RADIUS := 42.0
## Drag this far off the button's center before it steers the aim; the knob
## shows the direction, clamped to the rim.
const DRAG_DEADZONE := 10.0
## Keep steering this long after letting go, so the cast launched on
## release still goes the way the thumb pointed.
const AIM_HOLD_AFTER_RELEASE := 0.15

const BUTTONS := [
	# [label, key, angle around the aim stick (deg, clockwise from right), distance, radius]
	["切換", KEY_TAB, 190.0, 150.0, 25.0],
	["丟魚", KEY_G, 216.0, 150.0, 25.0],
	["換燈", KEY_K, 242.0, 150.0, 22.0],
	["閃光", KEY_F, 305.0, 150.0, 25.0],
]
## The lamp button: straight above the aim stick.
const LAMP_CENTER := Vector2(802, 232)
const LAMP_RADIUS := 28.0
## Held this long on a lit lamp, the slider comes up (shorter is a tap).
const LONG_PRESS := 0.35
## The slider pops up over the lamp button.
const SLIDER_SIZE := Vector2(34, 140)
const SLIDER_GAP := 8.0
## The slider's bottom stretch is "off".
const OFF_ZONE := 0.06
const FILL := Color(1, 1, 1, 0.1)
const FILL_PRESSED := Color(1, 1, 1, 0.38)
const RIM_ALPHA := 0.45

var _cast_center := Vector2.ZERO
var _cast_touch := -1
var _cast_drag := Vector2.ZERO
var _aim_release_timer := 0.0
var _cast_view: CastButtonView
var _slider: BrightnessSlider
var _lamp_view: LampButtonView
var _lamp_touch := -1
var _lamp_time := 0.0
var _lamp_was_lit := false
var _lamp_key_down := false
var _lamp_y := 0.0
var _level := 0.0
var _start_brightness := 0.75


func _ready() -> void:
	layer = 5
	visible = DisplayServer.is_touchscreen_available()
	for spec in BUTTONS:
		var center: Vector2 = AIM_CENTER + Vector2.RIGHT.rotated(deg_to_rad(spec[2])) * spec[3]
		_add_button(spec[0], spec[1], center, spec[4])
	_cast_center = AIM_CENTER + Vector2.RIGHT.rotated(deg_to_rad(CAST_ANGLE)) * CAST_DISTANCE
	_cast_view = CastButtonView.new()
	_cast_view.position = _cast_center
	_cast_view.radius = CAST_RADIUS
	add_child(_cast_view)
	_lamp_view = LampButtonView.new()
	_lamp_view.position = LAMP_CENTER
	_lamp_view.radius = LAMP_RADIUS
	add_child(_lamp_view)
	_slider = BrightnessSlider.new()
	_slider.size = SLIDER_SIZE
	_slider.position = LAMP_CENTER - Vector2(SLIDER_SIZE.x * 0.5, LAMP_RADIUS + SLIDER_GAP + SLIDER_SIZE.y)
	_slider.visible = false
	add_child(_slider)


func _process(delta: float) -> void:
	var lantern := _lantern()
	if lantern != null:
		_lamp_view.set_state(_lamp_touch != -1, lantern.lit, lantern.relight_progress)
		if _lamp_touch != -1:
			_lamp_time += delta
			# Lit by this hold, or held long on a lit lamp: up comes the slider.
			if not _slider.visible and lantern.lit and (not _lamp_was_lit or _lamp_time >= LONG_PRESS):
				_level = OFF_ZONE + (1.0 - OFF_ZONE) * inverse_lerp(Lantern.MIN_BRIGHTNESS, Lantern.MAX_BRIGHTNESS, lantern.brightness)
				_slider.visible = true
				_slider.set_active(true)
		_slider.set_value(_level if lantern.lit else 0.0)
	if _cast_touch == -1 and _aim_release_timer > 0.0:
		_aim_release_timer -= delta
		if _aim_release_timer <= 0.0:
			_set_player_aim(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _lamp_touch == -1 and event.position.distance_to(LAMP_CENTER) <= LAMP_RADIUS + 4.0:
			_lamp_press(event.index, event.position.y)
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and event.index == _lamp_touch:
			_lamp_release()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and _cast_touch == -1 and event.position.distance_to(_cast_center) <= CAST_RADIUS:
			_cast_touch = event.index
			_cast_drag = Vector2.ZERO
			_cast_view.set_state(true, Vector2.ZERO)
			_send(KEY_SPACE, true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _cast_touch:
			_cast_touch = -1
			_cast_view.set_state(false, Vector2.ZERO)
			_send(KEY_SPACE, false)
			_aim_release_timer = AIM_HOLD_AFTER_RELEASE
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _lamp_touch:
		var lantern := _lantern()
		if _slider.visible and lantern != null and lantern.lit:
			_level = clampf(_level + (_lamp_y - event.position.y) / SLIDER_SIZE.y, 0.0, 1.0)
			if _level <= 0.0:
				lantern.put_out()
				# Relit later, it comes back as bright as before this drag.
				lantern.brightness = maxf(_start_brightness, 0.6)
			else:
				lantern.brightness = lerpf(Lantern.MIN_BRIGHTNESS, Lantern.MAX_BRIGHTNESS,
					clampf((_level - OFF_ZONE) / (1.0 - OFF_ZONE), 0.0, 1.0))
		_lamp_y = event.position.y
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _cast_touch:
		_cast_drag = event.position - _cast_center
		var steering := _cast_drag.length() > DRAG_DEADZONE
		_cast_view.set_state(true, _cast_drag.limit_length(CAST_RADIUS) if steering else Vector2.ZERO)
		if steering:
			_set_player_aim(_cast_drag.normalized())
		get_viewport().set_input_as_handled()


func _lamp_press(index: int, y: float) -> void:
	var lantern := _lantern()
	_lamp_touch = index
	_lamp_time = 0.0
	_lamp_y = y
	_lamp_was_lit = lantern != null and lantern.lit
	if lantern != null:
		_start_brightness = lantern.brightness
	if not _lamp_was_lit:
		# Unlit: holding L runs the relight (or battery swap).
		_lamp_key_down = true
		_send(KEY_L, true)


func _lamp_release() -> void:
	var lantern := _lantern()
	if _lamp_key_down:
		_send(KEY_L, false)
	elif lantern != null and lantern.lit and not _slider.visible and _lamp_time < LONG_PRESS:
		lantern.put_out()  # a tap on a lit lamp
	_lamp_touch = -1
	_lamp_key_down = false
	_slider.visible = false
	_slider.set_active(false)


func _lantern() -> Lantern:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_node_or_null("Lantern") as Lantern if player != null else null


func _set_player_aim(dir: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.touch_aim = dir


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
	button.add_child(_label(text, radius))
	add_child(button)


static func _label(text: String, radius: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(radius, radius) * 2.0
	label.add_theme_font_size_override("font_size", 18 if radius > 40.0 else (14 if radius > 20.0 else 13))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.85
	return label


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


## The cast/reel button: the disc and label, plus - while it's dragged - a
## knob and a pointer toward where the cast will go.
class CastButtonView extends Node2D:
	var radius := 42.0
	var _pressed := false
	var _knob := Vector2.ZERO
	var _normal: ImageTexture
	var _down: ImageTexture

	func _ready() -> void:
		_normal = TouchControls._disc(radius, TouchControls.FILL)
		_down = TouchControls._disc(radius, TouchControls.FILL_PRESSED)
		var label := TouchControls._label("拋竿\n收線", radius)
		label.position = -Vector2(radius, radius)
		add_child(label)

	func set_state(pressed: bool, knob: Vector2) -> void:
		_pressed = pressed
		_knob = knob
		queue_redraw()

	func _draw() -> void:
		var tex := _down if _pressed else _normal
		draw_texture(tex, -Vector2(radius, radius))
		if _pressed and _knob != Vector2.ZERO:
			var dir := _knob.normalized()
			draw_line(Vector2.ZERO, dir * (radius + 26.0), Color(1, 0.9, 0.5, 0.75), 3.0)
			draw_circle(_knob, 13.0, Color(1, 1, 1, 0.45))
			var tip := dir * (radius + 32.0)
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12.0 + dir.orthogonal() * 7.0,
				tip - dir * 12.0 - dir.orthogonal() * 7.0]), Color(1, 0.9, 0.5, 0.85))


## The lamp button: warm when the lamp is lit, a ring filling while it's
## being relit.
class LampButtonView extends Node2D:
	var radius := 28.0
	var _pressed := false
	var _lit := false
	var _progress := 0.0
	var _normal: ImageTexture
	var _down: ImageTexture

	func _ready() -> void:
		_normal = TouchControls._disc(radius, TouchControls.FILL)
		_down = TouchControls._disc(radius, TouchControls.FILL_PRESSED)
		var label := TouchControls._label("燈", radius)
		label.position = -Vector2(radius, radius)
		add_child(label)

	func set_state(pressed: bool, lit: bool, progress: float) -> void:
		if pressed == _pressed and lit == _lit and absf(progress - _progress) < 0.001:
			return
		_pressed = pressed
		_lit = lit
		_progress = progress
		queue_redraw()

	func _draw() -> void:
		draw_texture(_down if _pressed else _normal, -Vector2(radius, radius))
		if _lit:
			draw_circle(Vector2.ZERO, radius - 3.0, Color(1.0, 0.8, 0.45, 0.22))
		if _progress > 0.0:
			draw_arc(Vector2.ZERO, radius - 2.0, -PI / 2.0, -PI / 2.0 + TAU * _progress, 40, Color(1.0, 0.85, 0.5, 0.9), 4.0)


## The brightness slider: a rounded bar filled from the bottom up to the
## lamp's brightness, with a sun at its foot.
class BrightnessSlider extends Node2D:
	var size := Vector2(34, 160)
	var _value := 0.5
	var _active := false

	func set_value(v: float) -> void:
		if absf(v - _value) > 0.001:
			_value = v
			queue_redraw()

	func set_active(active: bool) -> void:
		_active = active
		queue_redraw()

	func _draw() -> void:
		var radius := size.x * 0.5
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0, 0, 0, 0.35 if _active else 0.25)
		back.border_color = Color(1, 1, 1, 0.45)
		back.set_border_width_all(1)
		back.set_corner_radius_all(int(radius))
		draw_style_box(back, Rect2(Vector2.ZERO, size))
		var fill_h := maxf(size.y * clampf(_value, 0.0, 1.0), 2.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1, 0.93, 0.75, 0.75 if _active else 0.55)
		fill.set_corner_radius_all(int(minf(radius, fill_h * 0.5)))
		draw_style_box(fill, Rect2(0, size.y - fill_h, size.x, fill_h))
		# The sun.
		var c := Vector2(radius, size.y - radius)
		var ink := Color(0.15, 0.12, 0.08, 0.85) if _value > 0.12 else Color(1, 1, 1, 0.8)
		draw_circle(c, 4.5, ink)
		for i in 8:
			var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
			draw_line(c + d * 7.0, c + d * 10.0, ink, 1.5)
