class_name ActionPrompt
extends CanvasLayer

## User request: every action other than fishing is done with a button that
## shows up at the thing itself - near the altar with fish on you it offers
## 獻祭, at the fuel station 加油, by a rock 翻開, and so on - rather than on
## the cast button. Names aren't printed over the map any more either: an
## object's name shows here, only while it can be used. The player decides
## what's on offer (Player.interaction()); the button holds E down while
## pressed, so held actions (offering, turning a rock) fill its bar.

const FONT_NAME := 12
const FONT_VERB := 16
const PAD := Vector2(14, 7)
const GAP := 3.0
const INK := Color(1.0, 0.96, 0.88)
const FILL := Color(0.08, 0.07, 0.05, 0.62)
const FILL_DOWN := Color(0.3, 0.24, 0.14, 0.75)
const RIM := Color(1.0, 0.85, 0.55, 0.8)
const BAR := Color(1.0, 0.8, 0.4, 0.55)
## Kept below the HUD's lines along the top of the screen.
const TOP_MARGIN := 116.0

var _offer: Dictionary = {}
var _rect := Rect2()
var _touch := -1
var _mouse := false
var _view: Node2D
var _font: Font
var _touchscreen := false


func _ready() -> void:
	layer = 4
	_touchscreen = DisplayServer.is_touchscreen_available()
	_font = ThemeDB.fallback_font
	var custom: Font = load(ProjectSettings.get_setting("gui/theme/custom_font", "")) if ProjectSettings.get_setting("gui/theme/custom_font", "") != "" else null
	if custom != null:
		_font = custom
	_view = Node2D.new()
	_view.draw.connect(_draw_prompt)
	add_child(_view)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	_offer = player.interaction() if player != null and player.has_method("interaction") else {}
	# Not while a window (the backpack, a dialog) is up.
	for c in get_parent().get_children():
		if (c is Backpack or c is DialogBox) and c.is_open():
			_offer = {}
	if _offer.is_empty() and (_touch != -1 or _mouse):
		_release()
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if _offer.is_empty():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and _rect.grow(6.0).has_point(event.position):
			_touch = event.index
			_send(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not _touchscreen and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _rect.has_point(event.position):
			_mouse = true
			_send(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse:
			_release()
			get_viewport().set_input_as_handled()


func _release() -> void:
	_touch = -1
	_mouse = false
	_send(false)


func _send(down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = down
	Input.parse_input_event(ev)


func _draw_prompt() -> void:
	if _offer.is_empty():
		return
	var at: Vector2 = get_viewport().get_canvas_transform() * (_offer.at as Vector2)
	at.y = maxf(at.y, TOP_MARGIN + 34.0)
	var verb: String = _offer.verb
	if not _touchscreen:
		verb = "E  " + verb
	var verb_size := _font.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_VERB)
	var size := verb_size + PAD * 2.0
	_rect = Rect2(at - Vector2(size.x * 0.5, size.y), size)
	var down := _touch != -1 or _mouse or Input.is_key_pressed(KEY_E)
	var box := StyleBoxFlat.new()
	box.bg_color = FILL_DOWN if down else FILL
	box.border_color = RIM
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(size.y * 0.5))
	_view.draw_style_box(box, _rect)
	# A held action's progress fills the button.
	var progress := _progress()
	if progress > 0.0:
		var bar := StyleBoxFlat.new()
		bar.bg_color = BAR
		bar.set_corner_radius_all(int(size.y * 0.5))
		_view.draw_style_box(bar, Rect2(_rect.position, Vector2(maxf(size.x * progress, size.y), size.y)))
	var base := _rect.position + Vector2(PAD.x, PAD.y + _font.get_ascent(FONT_VERB))
	_view.draw_string_outline(_font, base, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_VERB, 3, Color(0, 0, 0, 0.6))
	_view.draw_string(_font, base, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_VERB, INK)
	var title: String = _offer.name
	if title != "":
		var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NAME).x
		var tpos := Vector2(at.x - tw * 0.5, _rect.position.y - GAP - _font.get_descent(FONT_NAME))
		_view.draw_string_outline(_font, tpos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NAME, 3, Color(0, 0, 0, 0.7))
		_view.draw_string(_font, tpos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NAME, Color(INK, 0.85))


func _progress() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return 0.0
	match _offer.get("verb", ""):
		"獻祭":
			return player.sacrifice_progress
		"翻開":
			return player.rummage_progress
	return 0.0
