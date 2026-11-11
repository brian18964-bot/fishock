class_name DialogBox
extends CanvasLayer

## A line of speech from a character (for now Willow, at the altar - see
## Player's 對話): a box with who's talking and what they say. Closes with
## its button or a tap anywhere outside it.
##
## Dressed as an MMO's quest-giver window (user request): parchment, the
## speaker's name in dark red, the words in brown ink.

const PANEL_SIZE := Vector2(460, 300)
## User report (the altar's list of bones cut off at the screen's foot): the box stands on the
## screen's foot (MARGIN up) and grows upward with what it says, as wide as PANEL_WIDTH; past
## TEXT_MAX high the words scroll.
const PANEL_WIDTH := 540.0
const MARGIN := 16.0
const TEXT_MAX := 340.0

var _backdrop: ColorRect
var _panel: PanelContainer
var _who: Label
var _text: Label
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 7
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.35)
	_backdrop.size = Vector2(960, 540)
	_backdrop.visible = false
	_backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_backdrop)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.parchment_box())
	# (its foot on the screen's foot, centred; it grows upward)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -PANEL_WIDTH * 0.5
	_panel.offset_right = PANEL_WIDTH * 0.5
	_panel.offset_bottom = -MARGIN
	_panel.offset_top = -MARGIN
	_panel.visible = false
	add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_panel.add_child(list)
	_who = UiKit.label("", 22, Color(0.45, 0.08, 0.04), true, 0)
	list.add_child(_who)
	list.add_child(UiKit.divider(300))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(_scroll)
	_text = UiKit.label("", 17, Color(0.23, 0.14, 0.06), false, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size.x = PANEL_WIDTH - 60.0
	_scroll.add_child(_text)
	var ok := UiKit.button("再見", 16)
	ok.custom_minimum_size = Vector2(140, 42)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close)
	list.add_child(ok)


func say(who: String, text: String) -> void:
	_who.text = who
	_text.text = text
	# (the words' own height at the box's width - up to TEXT_MAX, then they scroll)
	var font: Font = _text.get_theme_font("font")
	var size := _text.get_theme_font_size("font_size")
	var high := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _text.custom_minimum_size.x, size).y + 8.0
	_scroll.custom_minimum_size.y = minf(high, TEXT_MAX)
	_scroll.scroll_vertical = 0
	# (shrunk to its least, then it grows upward to fit)
	_panel.offset_top = _panel.offset_bottom
	_panel.visible = true
	_refit.call_deferred()
	_backdrop.visible = true
	Backpack.set_sticks_enabled(get_tree(), false)


## A frame on, the words laid out: the room they really take (the font's measure can fall a little
## short of the label's own lines).
func _refit() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not _panel.visible:
		return
	var high := minf(_text.get_combined_minimum_size().y + 4.0, TEXT_MAX)
	if high > _scroll.custom_minimum_size.y:
		_scroll.custom_minimum_size.y = high
		_panel.offset_top = _panel.offset_bottom


func close() -> void:
	_panel.visible = false
	_backdrop.visible = false
	Backpack.set_sticks_enabled(get_tree(), true)


func is_open() -> bool:
	return _panel.visible


## The box on the screen now (for the tests).
func panel_rect() -> Rect2:
	return _panel.get_global_rect()
