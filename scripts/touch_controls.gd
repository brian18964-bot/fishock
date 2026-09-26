class_name TouchControls
extends CanvasLayer

## On-screen controls for phones (the web build, played on iPhone), laid out
## with Brawl Stars as the model (user request: as few buttons round the two
## sticks as possible):
##   left stick     walk
##   right stick    fish - press to cast (pull further for a longer cast,
##                  tap for a middling one), strike, hold to reel, drag to
##                  answer a fish's sideways run (Player: the right stick)
##   light button   next to the right stick, showing the oil lamp or the
##                  flashlight: drag it to aim the light, hold it to charge
##                  the light up, let go to flash a ghost in it; a tap
##                  flashes the nearest ghost close by for a short stun
##                  (Player's light skill). Its rim fills as it charges and
##                  shows the flash's cooldown.
##   丟魚            throw a fish ahead (the big ghost goes for it)
## The lamp's brightness: long-press any empty spot on the screen, then
## slide up or down - like iPhone's brightness in Control Center; all the
## way down puts the lamp out, and with the lamp out the long press relights
## it (its ring fills), then slides as before. The backpack is opened from
## the character card, top left (StatusCard).
## Everything is see-through so the field stays visible. TouchScreenButton
## holds a key down while touched, so the key checks in the game work as on
## a keyboard; the controls hide where there's no touchscreen.

## Right stick centre in the 960x540 layout (AimJoystick in main.tscn: a
## 300x300 control at the bottom-right corner, 8 px in).
const AIM_CENTER := Vector2(802, 382)

## The light button, where the cast button used to be.
const SKILL_ANGLE := 165.0
const SKILL_DISTANCE := 150.0
const SKILL_RADIUS := 42.0
## Drag this far off the button's center before it steers the light; the
## knob shows the direction, clamped to the rim.
const DRAG_DEADZONE := 10.0

const BUTTONS := [
	# [label, key, angle around the right stick (deg, clockwise from right), distance, radius]
	["丟魚", KEY_G, 222.0, 150.0, 25.0],
]
## A press on an empty spot held this long (and still) opens the slider.
const LONG_PRESS := 0.4
const PRESS_SLOP := 14.0
const SLIDER_SIZE := Vector2(34, 140)
## The slider's bottom stretch is "off".
const OFF_ZONE := 0.06
const FILL := Color(1, 1, 1, 0.1)
const FILL_PRESSED := Color(1, 1, 1, 0.38)
const RIM_ALPHA := 0.45

var _skill_center := Vector2.ZERO
var _skill_touch := -1
var _skill_view: SkillButtonView
var _slider: BrightnessSlider
var _ring: PressRing
var _press_touch := -1
var _press_start := Vector2.ZERO
var _press_time := 0.0
var _press_active := false
var _press_key_down := false
var _press_y := 0.0
var _level := 0.0
var _start_brightness := 0.75
## User request: with the lamp out, holding the light skill button relights
## it (L held, like the long press on an empty spot) instead of flashing.
var _skill_relight := false


func _ready() -> void:
	layer = 5
	visible = DisplayServer.is_touchscreen_available()
	for spec in BUTTONS:
		var center: Vector2 = AIM_CENTER + Vector2.RIGHT.rotated(deg_to_rad(spec[2])) * spec[3]
		_add_button(spec[0], spec[1], center, spec[4])
	_skill_center = AIM_CENTER + Vector2.RIGHT.rotated(deg_to_rad(SKILL_ANGLE)) * SKILL_DISTANCE
	_skill_view = SkillButtonView.new()
	_skill_view.position = _skill_center
	_skill_view.radius = SKILL_RADIUS
	add_child(_skill_view)
	_slider = BrightnessSlider.new()
	_slider.size = SLIDER_SIZE
	_slider.visible = false
	add_child(_slider)
	_ring = PressRing.new()
	_ring.visible = false
	add_child(_ring)


func _process(delta: float) -> void:
	var lantern := _lantern()
	if lantern == null:
		return
	_skill_view.set_state(_skill_touch != -1, lantern.tool == Lantern.Tool.FLASHLIGHT, lantern.boost,
		lantern.flash_cooldown / maxf(lantern.flash_cooldown_max, 0.01), lantern.lit)
	if _press_touch != -1:
		_press_time += delta
		if not _press_active and _press_time >= LONG_PRESS:
			_press_active = true
			_start_brightness = lantern.brightness
			if not lantern.lit:
				# Out: the long press relights it first (L held).
				_press_key_down = true
				_send(KEY_L, true)
		_ring.progress = clampf(_press_time / LONG_PRESS, 0.0, 1.0) if not _press_active else lantern.relight_progress
		_ring.visible = _press_time > 0.1 and not _slider.visible
		_ring.queue_redraw()
		if _press_active and lantern.lit and not _slider.visible:
			_level = OFF_ZONE + (1.0 - OFF_ZONE) * inverse_lerp(Lantern.MIN_BRIGHTNESS, Lantern.MAX_BRIGHTNESS, lantern.brightness)
			_slider.visible = true
			_slider.set_active(true)
		_slider.set_value(_level if lantern.lit else 0.0)
	elif _skill_relight:
		_ring.position = _skill_center
		_ring.progress = lantern.relight_progress
		_ring.visible = not lantern.lit
		_ring.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or _bag_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _skill_touch == -1 and event.position.distance_to(_skill_center) <= SKILL_RADIUS:
			_skill_touch = event.index
			var lantern := _lantern()
			if lantern != null and not lantern.lit:
				_skill_relight = true
				_send(KEY_L, true)
			else:
				_set_skill(true, Vector2.ZERO, false)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _skill_touch:
			_skill_touch = -1
			_skill_view.set_knob(Vector2.ZERO)
			if _skill_relight:
				_skill_relight = false
				_send(KEY_L, false)
				_ring.visible = false
			else:
				_set_skill(false, Vector2.ZERO, false)
			get_viewport().set_input_as_handled()
		elif event.pressed and _press_touch == -1 and _is_empty_spot(event.position):
			_press_touch = event.index
			_press_start = event.position
			_press_y = event.position.y
			_press_time = 0.0
			_press_active = false
			_ring.position = event.position
			_place_slider(event.position)
		elif not event.pressed and event.index == _press_touch:
			_end_press()
	elif event is InputEventScreenDrag and event.index == _skill_touch:
		if _skill_relight:
			get_viewport().set_input_as_handled()
			return
		var drag: Vector2 = event.position - _skill_center
		var steering := drag.length() > DRAG_DEADZONE
		_skill_view.set_knob(drag.limit_length(SKILL_RADIUS) if steering else Vector2.ZERO)
		if steering:
			_set_skill(true, drag.normalized(), true)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _press_touch:
		if not _press_active:
			if event.position.distance_to(_press_start) > PRESS_SLOP:
				_end_press()  # a swipe, not a long press
			return
		var lantern := _lantern()
		if _slider.visible and lantern != null and lantern.lit:
			_level = clampf(_level + (_press_y - event.position.y) / SLIDER_SIZE.y, 0.0, 1.0)
			if _level <= 0.0:
				lantern.put_out()
				# Relit later, it comes back as bright as before this drag.
				lantern.brightness = maxf(_start_brightness, 0.6)
			else:
				lantern.brightness = lerpf(Lantern.MIN_BRIGHTNESS, Lantern.MAX_BRIGHTNESS,
					clampf((_level - OFF_ZONE) / (1.0 - OFF_ZONE), 0.0, 1.0))
		_press_y = event.position.y
		get_viewport().set_input_as_handled()


func _end_press() -> void:
	if _press_key_down:
		_send(KEY_L, false)
	_press_key_down = false
	_press_touch = -1
	_press_active = false
	_slider.visible = false
	_slider.set_active(false)
	_ring.visible = false


## Nothing there to take the touch: not a stick, a button, the character
## card or an object's button.
func _is_empty_spot(pos: Vector2) -> bool:
	if pos.distance_to(_skill_center) <= SKILL_RADIUS + 8.0:
		return false
	for spec in BUTTONS:
		var center: Vector2 = AIM_CENTER + Vector2.RIGHT.rotated(deg_to_rad(spec[2])) * spec[3]
		if pos.distance_to(center) <= spec[4] + 8.0:
			return false
	var scene := get_tree().current_scene
	for path in ["HUD/Panel/MoveJoystick", "HUD/Panel/AimJoystick"]:
		var stick := scene.get_node_or_null(path) as Control
		if stick != null and stick.get_global_rect().has_point(pos):
			return false
	for c in scene.get_children():
		if c is StatusCard and c.contains(pos):
			return false
		if c is ActionPrompt and not c._offer.is_empty() and c._rect.grow(8.0).has_point(pos):
			return false
	return true


## The slider beside the finger, clear of the screen's edges.
func _place_slider(pos: Vector2) -> void:
	var x := pos.x + 36.0 if pos.x < 960.0 - 90.0 else pos.x - 36.0 - SLIDER_SIZE.x
	var y := clampf(pos.y - SLIDER_SIZE.y * 0.5, 8.0, 540.0 - SLIDER_SIZE.y - 8.0)
	_slider.position = Vector2(x, y)


func _set_skill(held: bool, aim: Vector2, dragged: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.skill_held = held
	if held:
		if aim != Vector2.ZERO:
			player.skill_aim = aim
		player.skill_dragged = player.skill_dragged or dragged


func _bag_open() -> bool:
	for bag in get_tree().current_scene.get_children():
		if (bag is Backpack or bag is DialogBox) and bag.is_open():
			return true
	return false


func _lantern() -> Lantern:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_node_or_null("Lantern") as Lantern if player != null else null


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


## The light button: the oil lamp or the flashlight drawn on it, a knob
## and pointer while it's dragged, its rim filling as the light charges and
## a dark sweep while the flash cools down.
class SkillButtonView extends Node2D:
	var radius := 42.0
	var _pressed := false
	var _flashlight := false
	var _charge := 0.0
	var _cooldown := 0.0
	var _lit := true
	var _knob := Vector2.ZERO
	var _normal: ImageTexture
	var _down: ImageTexture

	func _ready() -> void:
		_normal = TouchControls._disc(radius, TouchControls.FILL)
		_down = TouchControls._disc(radius, TouchControls.FILL_PRESSED)

	func set_state(pressed: bool, flashlight: bool, charge: float, cooldown: float, lit: bool) -> void:
		if pressed == _pressed and flashlight == _flashlight and absf(charge - _charge) < 0.01 \
				and absf(cooldown - _cooldown) < 0.01 and lit == _lit:
			return
		_pressed = pressed
		_flashlight = flashlight
		_charge = charge
		_cooldown = cooldown
		_lit = lit
		queue_redraw()

	func set_knob(knob: Vector2) -> void:
		_knob = knob
		queue_redraw()

	func _draw() -> void:
		draw_texture(_down if _pressed else _normal, -Vector2(radius, radius))
		var ink := Color(1.0, 0.92, 0.7, 0.9 if _lit else 0.4)
		if _flashlight:
			_draw_flashlight(ink)
		else:
			_draw_lamp(ink)
		if _cooldown > 0.0:
			# The flash recharging: a dark sweep going round.
			draw_arc(Vector2.ZERO, radius - 5.0, -PI / 2.0, -PI / 2.0 + TAU * _cooldown, 40, Color(0, 0, 0, 0.45), 8.0)
		if _charge > 0.0:
			draw_arc(Vector2.ZERO, radius - 2.0, -PI / 2.0, -PI / 2.0 + TAU * _charge, 48, Color(1.0, 0.85, 0.4, 0.95), 4.0)
		if _pressed and _knob != Vector2.ZERO:
			var dir := _knob.normalized()
			draw_line(Vector2.ZERO, dir * (radius + 26.0), Color(1, 0.9, 0.5, 0.75), 3.0)
			draw_circle(_knob, 13.0, Color(1, 1, 1, 0.45))
			var tip := dir * (radius + 32.0)
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12.0 + dir.orthogonal() * 7.0,
				tip - dir * 12.0 - dir.orthogonal() * 7.0]), Color(1, 0.9, 0.5, 0.85))

	## An oil lamp: handle, cap, glass with a flame, base.
	func _draw_lamp(ink: Color) -> void:
		draw_arc(Vector2(0, -12), 8.0, PI, TAU, 16, ink, 2.0)
		draw_rect(Rect2(-8, -12, 16, 4), ink)
		draw_rect(Rect2(-7, -8, 14, 16), ink, false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(4, 2), Vector2(0, 5), Vector2(-4, 2)]),
			Color(1.0, 0.75, 0.3, ink.a))
		draw_rect(Rect2(-10, 8, 20, 5), ink)

	## A flashlight: body, head and beam.
	func _draw_flashlight(ink: Color) -> void:
		var r := Transform2D(-0.6, Vector2.ZERO)
		draw_set_transform_matrix(r)
		draw_rect(Rect2(-16, -4, 18, 8), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(2, -4), Vector2(9, -7), Vector2(9, 7), Vector2(2, 4)]), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(10, -6), Vector2(22, -12), Vector2(22, 12), Vector2(10, 6)]),
			Color(1.0, 0.95, 0.7, ink.a * 0.45))
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Under a long press on an empty spot: a ring filling towards the slider
## (or the relight, with the lamp out).
class PressRing extends Node2D:
	var progress := 0.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(1, 1, 1, 0.2), 3.0)
		draw_arc(Vector2.ZERO, 26.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, Color(1.0, 0.9, 0.6, 0.85), 3.0)


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
