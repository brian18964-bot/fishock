class_name DialogBox
extends CanvasLayer

## A line of speech from a character (for now Willow, at the altar - see
## Player's 對話): a box with who's talking and what they say. Closes with
## its button or a tap anywhere outside it.
##
## Plain for now: the whole UI is to be redesigned later.

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
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.05, 0.94)
	box.border_color = Color(0.75, 0.95, 0.6, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.size = PANEL_SIZE
	_panel.position = Vector2((960 - PANEL_SIZE.x) * 0.5, 540 - PANEL_SIZE.y - 24)
	_panel.visible = false
	add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_panel.add_child(list)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 18)
	_who.add_theme_color_override("font_color", Color(0.75, 0.95, 0.6))
	list.add_child(_who)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(_text)
	var ok := Button.new()
	ok.text = "關閉"
	ok.add_theme_font_size_override("font_size", 15)
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
