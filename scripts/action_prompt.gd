class_name ActionPrompt
extends CanvasLayer

## User request: every action other than fishing is done with a button that
## shows up at the thing itself - near the altar with fish on you it offers
## 獻祭, at the fuel station 加油, by a rock 翻開, and so on - rather than on
## the cast button. Names aren't printed over the map any more either: an
## object's name shows here, only while it can be used. The player decides
## what's on offer (Player.interaction()); the button holds E down while
## pressed, so held actions (offering, turning a rock) fill its bar.

const FONT_NAME := 13
const FONT_VERB := 18
const PAD := Vector2(20, 10)
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


## Dressed as an MMO's action button that lights up when it can be used
## (user request): red lacquer in a gold rim, a gold glow pulsing round it.
func _draw_prompt() -> void:
	if _offer.is_empty():
		return
	var at: Vector2 = get_viewport().get_canvas_transform() * (_offer.at as Vector2)
	at.y = maxf(at.y, TOP_MARGIN + 34.0)
	var verb: String = _offer.verb
	if not _touchscreen:
		verb = "E  " + verb
	var verb_size := UiKit.font(true).get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_VERB)
	var size := Vector2(maxf(verb_size.x + PAD.x * 2.0, 84.0), 44.0)
	_rect = Rect2(at - Vector2(size.x * 0.5, size.y), size)
	var down := _touch != -1 or _mouse or Input.is_key_pressed(KEY_E)
	var pulse := 0.45 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	_view.draw_texture_rect(UiKit.tex("action_glow"), _rect.grow(14.0), false, Color(1.0, 0.82, 0.3, pulse))
	UiKit.button_box("red", "pressed" if down else "normal").draw(_view.get_canvas_item(), _rect)
	# A held action's progress fills the button.
	var progress := _progress()
	if progress > 0.0:
		var inner := _rect.grow(-5.0)
		_view.draw_rect(Rect2(inner.position, Vector2(inner.size.x * progress, inner.size.y)), Color(1.0, 0.8, 0.35, 0.45))
	UiKit.draw_text(_view, Vector2(_rect.position.x, _rect.position.y + 29), verb, FONT_VERB, UiKit.GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER, _rect.size.x, true)
	var title: String = _offer.name
	if title != "":
		UiKit.draw_text(_view, Vector2(at.x - 150, _rect.position.y - GAP - 4), title, FONT_NAME, UiKit.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, 300)


func _progress() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return 0.0
	match _offer.get("verb", ""):
		"獻祭":
			return player.sacrifice_progress
	return 0.0
