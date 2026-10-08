class_name DragScroll
extends ScrollContainer

## User request: a window that runs on past what's shown (the warehouse, the
## shop's wares, the fish tank's list...) scrolls under a finger - dragged
## anywhere on it, over a card or a button too. The engine's own drag only
## scrolls on a screen it knows is a touchscreen, and not where something
## under the finger takes the press (every card here is a button), so it
## often wouldn't move. Here a press that moves past SLOP up or down is a
## scroll: what was pressed isn't tapped (a button lets go unpressed, an
## ancestor's cancel_press() is called - ItemBoard's), and let go it glides
## on a little.
## `sideways_free`: a sideways drag is left alone (the warehouse's things are
## dragged out of it sideways, to the bag).

const SLOP := 10.0
## The glide: its speed's loss per second, the least worth gliding and the
## most (px/s).
const GLIDE_DRAG := 5.0
const GLIDE_MIN := 30.0
const GLIDE_MAX := 4000.0

var sideways_free := false
var _tracking := false
var _scrolling := false
var _from := Vector2.ZERO
var _from_scroll := 0.0
var _speed := 0.0
var _last_y := 0.0
var _last_t := 0.0
var _glide := 0.0
var _glide_at := 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	set_process(false)


func is_scrolling() -> bool:
	return _scrolling


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_glide = 0.0
			set_process(false)
			_tracking = _over(event.position)
			_scrolling = false
			_from = event.position
			_from_scroll = scroll_vertical
			_last_y = event.position.y
			_last_t = _now()
			_speed = 0.0
		else:
			if _scrolling and absf(_speed) > GLIDE_MIN and _now() - _last_t < 0.1:
				_glide = clampf(_speed, -GLIDE_MAX, GLIDE_MAX)
				_glide_at = scroll_vertical
				set_process(true)
			_tracking = false
			_scrolling = false
	elif event is InputEventMouseMotion and _tracking:
		var d: Vector2 = event.position - _from
		if not _scrolling:
			if d.length() < SLOP:
				return
			if (sideways_free and absf(d.x) > absf(d.y)) or get_v_scroll_bar().max_value <= size.y + 0.5:
				_tracking = false
				return
			_begin()
		scroll_vertical = int(roundf(_from_scroll - (d.y - signf(d.y) * SLOP)))
		var t := _now()
		if t > _last_t:
			var v: float = -(event.position.y - _last_y) / (t - _last_t)
			_speed = lerpf(_speed, v, 0.5)
		_last_y = event.position.y
		_last_t = t
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_glide *= exp(-GLIDE_DRAG * delta)
	_glide_at += _glide * delta
	var before := scroll_vertical
	scroll_vertical = int(roundf(_glide_at))
	if absf(_glide) < GLIDE_MIN or (scroll_vertical == before and absf(_glide) * delta >= 1.0):
		set_process(false)


## The engine's own touch drag off (it would scroll too); the wheel kept.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		accept_event()


## The scroll starts: nothing pressed counts as tapped.
func _begin() -> void:
	_scrolling = true
	for b in find_children("*", "BaseButton", true, false):
		var button := b as BaseButton
		if button.disabled or button.toggle_mode:
			continue
		if button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]:
			# (disabling forgets the press, so letting go doesn't press it)
			button.disabled = true
			button.disabled = false
	var up := get_parent()
	while up != null:
		if up.has_method("cancel_press"):
			up.cancel_press()
		up = up.get_parent()


## Whether a press at `at` (the viewport's) is on this, and not under
## something drawn over it (a card opened over the list).
func _over(at: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var local := get_global_transform_with_canvas().affine_inverse() * at
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return false
	var node: Node = self
	while node.get_parent() != null and not node is CanvasLayer:
		var parent := node.get_parent()
		for i in range(node.get_index() + 1, parent.get_child_count()):
			if _blocks(parent.get_child(i), at):
				return false
		node = parent
	return true


static func _blocks(n: Node, at: Vector2) -> bool:
	if n is CanvasLayer or (n is CanvasItem and not (n as CanvasItem).visible):
		return false
	if n is Control:
		var c := n as Control
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and Rect2(Vector2.ZERO, c.size).has_point(c.get_global_transform_with_canvas().affine_inverse() * at):
			return true
	for child in n.get_children():
		if _blocks(child, at):
			return true
	return false


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0
