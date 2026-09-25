class_name Backpack
extends CanvasLayer

## User request: the backpack button opens a Diablo-style bag - a grid
## where everything carried takes up cells (Inventory): fish by size, the
## heart, bait bundles, lures, batteries. Tap a thing to see it and what
## can be done with it: throw a fish (the big ghost goes for it), put a
## lure on, go back to the bobber. The light (oil lamp / flashlight) is
## picked in the row above the grid. The oil drum isn't in the bag - it's
## carried in the hands. I on a keyboard; Tab and K still step through as
## before.
##
## Plain for now: the whole UI is to be redesigned later.

const CELL := 46.0
const PANEL_SIZE := Vector2(420, 440)
const FONT := 15
const KIND_COLORS := {
	"fish": Color(0.32, 0.45, 0.55),
	"heart": Color(0.62, 0.16, 0.2),
	"bait": Color(0.45, 0.34, 0.2),
	"lure": Color(0.25, 0.5, 0.4),
	"battery": Color(0.6, 0.55, 0.2),
}
const ROTTEN_COLOR := Color(0.36, 0.3, 0.18)

var _panel: PanelContainer
var _backdrop: ColorRect
var _used: Label
var _light_row: HBoxContainer
var _mode: Label
var _grid: GridView
var _detail: Label
var _actions: HBoxContainer
var _key_held := false
var _refresh := 0.0
var _selected := {}  # {kind, index} of the tapped item


func _ready() -> void:
	layer = 6
	# User request: tapping anywhere outside the bag closes it.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.35)
	_backdrop.size = Vector2(960, 540)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	_backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			toggle())
	add_child(_backdrop)
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.05, 0.92)
	box.border_color = Color(1.0, 0.85, 0.55, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.size = PANEL_SIZE
	_panel.position = (Vector2(960, 540) - PANEL_SIZE) * 0.5
	_panel.visible = false
	add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_panel.add_child(list)

	var top := HBoxContainer.new()
	var title := _label("背包", 20, Color(1.0, 0.9, 0.7))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_used = _label("", 13, Color(1, 1, 1, 0.7))
	top.add_child(_used)
	var close := _button("✕")
	close.pressed.connect(toggle)
	top.add_child(close)
	list.add_child(top)

	_light_row = HBoxContainer.new()
	_light_row.add_theme_constant_override("separation", 6)
	list.add_child(_light_row)
	_mode = _label("", 13, Color(1.0, 0.85, 0.55, 0.9))
	list.add_child(_mode)

	_grid = GridView.new()
	_grid.owner_bag = self
	_grid.custom_minimum_size = Vector2(Inventory.COLS, Inventory.ROWS) * CELL
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(_grid)

	_detail = _label("點一下格子裡的東西", 14, Color(1, 1, 1, 0.85))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_detail)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	list.add_child(_actions)
	var bottom := _button("關閉背包")
	bottom.pressed.connect(toggle)
	list.add_child(bottom)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_backdrop.visible = _panel.visible
	_selected = {}
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


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _rebuild() -> void:
	_refresh = 0.4
	var player := _player()
	if player == null:
		return
	var items := Inventory.items(player)
	var placed := Inventory.pack(items)
	_grid.items = items
	_grid.placed = placed
	_grid.selected = _selected
	_grid.queue_redraw()
	_used.text = "%d / %d 格　" % [Inventory.used_cells(player), Inventory.COLS * Inventory.ROWS]

	# The light, picked straight from here.
	for c in _light_row.get_children():
		c.queue_free()
	var lantern: Lantern = player.get_node("Lantern")
	_light_row.add_child(_label("燈具", 13, Color(1.0, 0.85, 0.55, 0.9)))
	_light_row.add_child(_choice("煤燈 %d%%" % int(lantern.fuel / lantern.max_fuel * 100.0),
		lantern.tool == Lantern.Tool.LAMP, false, lantern.switch_tool.bind(Lantern.Tool.LAMP)))
	if Profile.has_flashlight:
		_light_row.add_child(_choice("手電筒 %d%%" % int(lantern.charge), lantern.tool == Lantern.Tool.FLASHLIGHT,
			false, lantern.switch_tool.bind(Lantern.Tool.FLASHLIGHT)))
	else:
		_light_row.add_child(_choice("手電筒（商店）", false, true, Callable()))

	var using: String = "浮標" if player.fishing_mode == Player.FishingMode.BOBBER else "路亞・" + Profile.LURES[player.current_lure].name
	_mode.text = "釣法：%s%s" % [using, "　（油箱提在手上，不佔背包）" if player.carrying_oil_drum else ""]
	_show_selected(player, items)


func _show_selected(player: Player, items: Array) -> void:
	for c in _actions.get_children():
		c.queue_free()
	var item := {}
	for it in items:
		if not _selected.is_empty() and it.kind == _selected.kind and it.index == _selected.index:
			item = it
	if item.is_empty():
		_selected = {}
		_detail.text = "點一下格子裡的東西"
		return
	var busy := player.state != Player.State.IDLE
	match item.kind:
		"fish":
			var fish: Dictionary = GameState.carried_fish[item.index]
			if fish.get("rotten", false):
				_detail.text = "腐敗的%s（%s型）：拿去獻祭會賭一把" % [item.label, item.grade]
			else:
				_detail.text = "%s（%s型，價值 %.0f）" % [item.label, item.grade, fish.get("value", 0.0)]
			_actions.add_child(_action("丟出（大鬼會去吃）", func():
				player.throw_fish(item.index)
				_selected = {}
				_rebuild()))
		"heart":
			_detail.text = "心臟：被大鬼關進籠子時會救你一命"
		"bait":
			_detail.text = "餌料 x%d（全部 %d）：浮標用" % [item.count, player.bait_count]
			if player.fishing_mode != Player.FishingMode.BOBBER:
				_actions.add_child(_action("改用浮標", func():
					player.choose_bobber()
					_rebuild(), busy))
		"lure":
			var def: Dictionary = Profile.LURES[item.index]
			_detail.text = "路亞・%s x%d：%s" % [def.name, item.count, def.desc]
			if player.fishing_mode != Player.FishingMode.LURE or player.current_lure != item.index:
				_actions.add_child(_action("裝上", func():
					player.choose_lure(item.index)
					_rebuild(), busy))
		"battery":
			_detail.text = "電池 x%d（全部 %d）：手電筒沒電時按住燈鈕換上" % [item.count, Profile.batteries]
	if busy and item.kind in ["bait", "lure"]:
		_detail.text += "（收線後才能換）"


func select(kind: String, index) -> void:
	_selected = {"kind": kind, "index": index}
	_rebuild()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FONT)
	return b


func _choice(text: String, current: bool, disabled: bool, pick: Callable) -> Button:
	var b := _button(("✓ " if current else "") + text)
	b.disabled = disabled or current
	if current:
		b.add_theme_color_override("font_disabled_color", Color(1.0, 0.9, 0.6))
	if pick.is_valid():
		b.pressed.connect(func():
			pick.call()
			_rebuild())
	return b


func _action(text: String, act: Callable, disabled := false) -> Button:
	var b := _button(text)
	b.disabled = disabled
	b.pressed.connect(act)
	return b


## The grid: cells, and each item as a tile over the cells it takes.
class GridView extends Control:
	var owner_bag: Backpack
	var items: Array = []
	var placed: Array = []
	var selected := {}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var cell := Vector2i(event.position / Backpack.CELL)
			for i in placed.size():
				var r: Rect2i = placed[i]
				if r.has_point(cell):
					owner_bag.select(items[i].kind, items[i].index)
					accept_event()
					return

	func _draw() -> void:
		var font := get_theme_default_font()
		for x in Inventory.COLS:
			for y in Inventory.ROWS:
				var r := Rect2(Vector2(x, y) * Backpack.CELL, Vector2.ONE * Backpack.CELL).grow(-1.5)
				draw_rect(r, Color(1, 1, 1, 0.05))
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
		for i in placed.size():
			var item: Dictionary = items[i]
			var cells: Rect2i = placed[i]
			var r := Rect2(Vector2(cells.position) * Backpack.CELL, Vector2(cells.size) * Backpack.CELL).grow(-3.0)
			var col: Color = Backpack.ROTTEN_COLOR if item.get("rotten", false) else Backpack.KIND_COLORS.get(item.kind, Color.GRAY)
			draw_rect(r, col)
			var is_sel: bool = not selected.is_empty() and selected.kind == item.kind and selected.index == item.index
			draw_rect(r, Color(1.0, 0.9, 0.6) if is_sel else Color(1, 1, 1, 0.3), false, 2.0 if is_sel else 1.0)
			var name: String = item.label
			var fs := 12 if cells.size.x > 1 else 11
			var text_w := r.size.x - 6.0
			draw_string(font, r.position + Vector2(3, 14), name, HORIZONTAL_ALIGNMENT_LEFT, text_w, fs, Color(1, 1, 1, 0.95))
			if item.kind == "fish":
				draw_string(font, r.position + Vector2(3, r.size.y - 5), item.grade, HORIZONTAL_ALIGNMENT_LEFT, text_w, 11, Color(1, 1, 1, 0.6))
			elif item.count > 0:
				draw_string(font, r.position + Vector2(0, r.size.y - 5), "x%d" % item.count, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3.0, 12, Color(1, 1, 1, 0.9))
