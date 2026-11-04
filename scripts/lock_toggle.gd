class_name LockToggle
extends Control

## User request: the lock on a thing's card is a padlock in its top right corner, not a word - shut
## (gold) when it's locked, open (dim) when not; a tap turns it. `changed` says which it is now.

signal changed(locked: bool)

const SIDE := 34.0

var locked := false


func _init(on := false) -> void:
	locked = on
	name = "LockToggle"
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "已上鎖：點一下解鎖" if on else "點一下上鎖"


## (user report: tapped, nothing happened - on a phone's browser one tap comes twice, the touch's
## mouse click and the browser's own a moment later; turned twice it stayed as it was. The echo
## within ECHO_MS is the same tap. Shared by every padlock: the card's rebuilt under the finger.)
const ECHO_MS := 400
static var _last_ms := -100000


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		var now := Time.get_ticks_msec()
		if now - _last_ms < ECHO_MS:
			return
		_last_ms = now
		locked = not locked
		tooltip_text = "已上鎖：點一下解鎖" if locked else "點一下上鎖"
		queue_redraw()
		Sfx.play("tap", -8.0)
		changed.emit(locked)
		accept_event()


func _draw() -> void:
	Locks.draw_icon(self, Rect2(Vector2.ZERO, size), locked)


## A corner for the padlock over the top right of a card laid out in a VBoxContainer (put it in
## first): it takes no room, the padlock hangs at the card's top right.
static func corner(on: bool, on_change: Callable, inset := Vector2(2, 2)) -> Control:
	var c := Control.new()
	c.name = "LockCorner"
	c.custom_minimum_size = Vector2.ZERO
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := LockToggle.new(on)
	t.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	t.offset_left = -SIDE - inset.x
	t.offset_right = -inset.x
	t.offset_top = inset.y
	t.offset_bottom = inset.y + SIDE
	t.changed.connect(on_change)
	c.add_child(t)
	return c
