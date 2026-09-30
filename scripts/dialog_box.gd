class_name DialogBox
extends CanvasLayer

## A line of speech from a character (for now Willow, at the altar - see
## Player's 對話): a box with who's talking and what they say. Closes with
## its button or a tap anywhere outside it.
##
## Dressed as an MMO's quest-giver window (user request): parchment, the
## speaker's name in dark red, the words in brown ink.

const PANEL_SIZE := Vector2(460, 300)

var _backdrop: ColorRect
var _panel: PanelContainer
var _who: Label
var _text: Label


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
	_panel.size = PANEL_SIZE
	_panel.position = Vector2((960 - PANEL_SIZE.x) * 0.5, 540 - PANEL_SIZE.y - 24)
	_panel.visible = false
	add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_panel.add_child(list)
	_who = UiKit.label("", 22, Color(0.45, 0.08, 0.04), true, 0)
	list.add_child(_who)
	list.add_child(UiKit.divider(300))
	_text = UiKit.label("", 17, Color(0.23, 0.14, 0.06), false, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(_text)
	var ok := UiKit.button("再見", 16)
	ok.custom_minimum_size = Vector2(140, 42)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close)
	list.add_child(ok)


func say(who: String, text: String) -> void:
	_who.text = who
	_text.text = text
	_panel.visible = true
	_backdrop.visible = true
	Backpack.set_sticks_enabled(get_tree(), false)


func close() -> void:
	_panel.visible = false
	_backdrop.visible = false
	Backpack.set_sticks_enabled(get_tree(), true)


func is_open() -> bool:
	return _panel.visible
