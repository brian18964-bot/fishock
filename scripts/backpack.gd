class_name Backpack
extends CanvasLayer

## User request: a backpack button in place of the old switch-fishing-mode
## and switch-light buttons - open it and tap what to use: the bobber or
## one of the lures in stock, the oil lamp or the flashlight. The oil drum
## isn't in it (it's carried in the hands, and fishing waits till it's
## delivered). I on a keyboard; Tab and K still step through as before.
##
## Plain for now: the whole UI is to be redesigned later.

const PANEL_SIZE := Vector2(380, 330)
const FONT := 15

var _panel: PanelContainer
var _list: VBoxContainer
var _key_held := false
var _refresh := 0.0


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.05, 0.9)
	box.border_color = Color(1.0, 0.85, 0.55, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.size = PANEL_SIZE
	_panel.position = (Vector2(960, 540) - PANEL_SIZE) * 0.5
	_panel.visible = false
	add_child(_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_panel.add_child(_list)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_rebuild()


func _process(delta: float) -> void:
	var held := Input.is_key_pressed(KEY_I)
	if held and not _key_held:
		toggle()
	_key_held = held
	if _panel.visible:
		_refresh -= delta
		if _refresh <= 0.0:
			_rebuild()


func _rebuild() -> void:
	_refresh = 0.5
	for c in _list.get_children():
		c.queue_free()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var lantern: Lantern = player.get_node("Lantern")
	var busy := player.state != Player.State.IDLE

	_title("背包")
	_heading("釣法" + ("（收線後才能換）" if busy else ""))
	var bobber := player.fishing_mode == Player.FishingMode.BOBBER
	_item("浮標　餌 x%d" % player.bait_count, bobber, busy, player.choose_bobber)
	for id in Profile.LURE_ORDER:
		var count := int(player.lure_stock.get(id, 0))
		if count <= 0:
			continue
		var on: bool = not bobber and player.current_lure == id
		_item("路亞・%s x%d" % [Profile.LURES[id].name, count], on, busy, player.choose_lure.bind(id))

	_heading("燈具")
	var lamp_on := lantern.tool == Lantern.Tool.LAMP
	_item("煤燈　燃油 %d%%" % int(lantern.fuel / lantern.max_fuel * 100.0), lamp_on, false,
		lantern.switch_tool.bind(Lantern.Tool.LAMP))
	if Profile.has_flashlight:
		_item("手電筒　電量 %d%%・備用電池 %d" % [int(lantern.charge), Profile.batteries], not lamp_on, false,
			lantern.switch_tool.bind(Lantern.Tool.FLASHLIGHT))
	else:
		_item("手電筒（商店購買）", false, true, Callable())

	_heading("身上")
	var notes := "漁獲 %d 條" % GameState.carried_fish.size()
	if player.carrying_oil_drum:
		notes += "　・手上提著油箱（不佔背包）"
	_label(notes, 14, Color(1, 1, 1, 0.8))

	var close := Button.new()
	close.text = "關閉"
	close.add_theme_font_size_override("font_size", FONT)
	close.pressed.connect(toggle)
	_list.add_child(close)


func _title(text: String) -> void:
	_label(text, 20, Color(1.0, 0.9, 0.7))


func _heading(text: String) -> void:
	_label(text, 13, Color(1.0, 0.85, 0.55, 0.85))


func _label(text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_list.add_child(l)


## One choice: ✓ when it's the one in use; greyed out when it can't be
## picked right now.
func _item(text: String, current: bool, disabled: bool, pick: Callable) -> void:
	var b := Button.new()
	b.text = ("✓ " if current else "　 ") + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", FONT)
	b.disabled = disabled or current
	if current:
		b.add_theme_color_override("font_disabled_color", Color(1.0, 0.9, 0.6))
	if pick.is_valid():
		b.pressed.connect(func():
			pick.call()
			_rebuild())
	_list.add_child(b)
