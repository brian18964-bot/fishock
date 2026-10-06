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
## Dressed as an MMO bag (user request): an iron-and-gold window with its
## title plate and round close button, sunken slots ringed by rarity.

const CELL := 46.0
const PANEL_SIZE := Vector2(420, 440)
const FONT := 15
const KIND_COLORS := {
	"use": Color(0.55, 0.3, 0.6),
	"fish": Color(0.32, 0.45, 0.55),
	"heart": Color(0.62, 0.16, 0.2),
	"bait": Color(0.45, 0.34, 0.2),
	"lure": Color(0.25, 0.5, 0.4),
	"battery": Color(0.6, 0.55, 0.2),
	"gear": Color(0.35, 0.3, 0.45),
	"live": Color(0.45, 0.3, 0.3),
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
## User request: the bag also opens to pick fish - "sacrifice" (at the
## altar: mark the fish to offer, then offer them) and "pick_lure" (the
## fish the 誘惑 button throws); "normal" otherwise.
var _mode_kind := "normal"
var _marked := {}  # uid -> true, the fish marked to offer
var _title: Label


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
	_panel.add_theme_stylebox_override("panel", UiKit.frame_box())
	_panel.size = PANEL_SIZE
	_panel.position = (Vector2(960, 540) - PANEL_SIZE) * 0.5
	_panel.visible = false
	add_child(_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_panel.add_child(list)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.plate_box())
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiKit.label("背包", 18, UiKit.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	top.add_child(plate)
	_title = title
	_used = _label("", 13, UiKit.DIM)
	top.add_child(_used)
	var close := UiKit.close_button()
	close.pressed.connect(toggle)
	top.add_child(close)
	list.add_child(top)

	_light_row = HBoxContainer.new()
	_light_row.add_theme_constant_override("separation", 6)
	list.add_child(_light_row)
	_mode = _label("", 14, UiKit.GOLD)
	list.add_child(_mode)

	_grid = GridView.new()
	_grid.owner_bag = self
	_grid.custom_minimum_size = Vector2(Inventory.COLS, Inventory.ROWS) * CELL
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(_grid)

	_detail = _label("點一下格子裡的東西", 15, UiKit.TEXT)
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
	set_sticks_enabled(get_tree(), not _panel.visible)
	_selected = {}
	if not _panel.visible:
		_mode_kind = "normal"
		_marked.clear()
	if _panel.visible:
		_rebuild()


## Opens the bag to pick fish: "sacrifice" or "pick_lure" (see _mode_kind).
func open_mode(kind: String) -> void:
	_mode_kind = kind
	_marked.clear()
	_selected = {}
	if not _panel.visible:
		toggle()
		_mode_kind = kind
	_rebuild()


func mode() -> String:
	return _mode_kind


func marked() -> Dictionary:
	return _marked


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
	_used.text = "%d / %d 格　" % [Inventory.used_cells(player), Inventory.COLS * Profile.bag_rows()]

	# The light, picked straight from here.
	for c in _light_row.get_children():
		c.queue_free()
	var lantern: Lantern = player.get_node("Lantern")
	_light_row.add_child(_label("燈具", 14, UiKit.GOLD))
	_light_row.add_child(_choice("煤燈 %d%%" % int(lantern.fuel / lantern.max_fuel * 100.0),
		lantern.tool == Lantern.Tool.LAMP, false, lantern.switch_tool.bind(Lantern.Tool.LAMP)))
	if Profile.has_flashlight:
		_light_row.add_child(_choice("手電筒 %d%%" % int(lantern.charge), lantern.tool == Lantern.Tool.FLASHLIGHT,
			false, lantern.switch_tool.bind(Lantern.Tool.FLASHLIGHT)))
	else:
		_light_row.add_child(_choice("手電筒（未裝備）", false, true, Callable()))

	var using: String = "浮標" if player.fishing_mode == Player.FishingMode.BOBBER else "路亞・" + Profile.LURES[player.current_lure].name
	_mode.text = "釣法：%s%s" % [using, "　（油箱提在手上，不佔背包）" if player.carrying_oil_drum else ""]
	_show_selected(player, items)


func _show_selected(player: Player, items: Array) -> void:
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	_title.text = {"sacrifice": "獻祭：選擇要獻上的魚", "pick_lure": "誘惑：選擇要當誘餌的魚"}.get(_mode_kind, "背包")
	if _mode_kind == "sacrifice":
		_show_offering()
		return
	if _mode_kind == "pick_lure":
		_show_lure_pick(items)
		return
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
			if GameState.lure_index() == item.index:
				_detail.text += "　・已設為誘惑用的魚"
				_actions.add_child(_action("取消誘餌", func():
					GameState.lure_uid = -1
					_rebuild()))
			else:
				_actions.add_child(_action("設為誘餌", func():
					GameState.set_lure(item.index)
					_rebuild()))
			_actions.add_child(_action("放在地上", func():
				player.put_fish_down(item.index)
				_selected = {}
				_rebuild()))
		"heart":
			_detail.text = "心臟：被大鬼抓住時，按「用心臟掙脫」（或 H）震開牠的手"
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
		"gear":
			_detail.text = "%s：備用的，要在主畫面的裝備頁換上" % item.label
		"use":
			# User request (round 7): the potions, the eyeball, the
			# binoculars - used from here (Player.use_item()).
			var uid: String = item.item
			var u: Dictionary = Profile.USABLES[uid]
			var counted := " x%d" % item.count if item.count > 0 else ""
			_detail.text = "%s%s：%s" % [u.name, counted, u.desc]
			var note := ""
			if uid == "potion_vigor" and player.vigor_timer > 0.0:
				note = "（藥效還有 %d 秒）" % ceili(player.vigor_timer)
			elif uid == "potion_ward" and player.ward_timer > 0.0:
				note = "（藥效還有 %d 秒）" % ceili(player.ward_timer)
			elif uid == "binoculars" and player.binoculars_cooldown > 0.0:
				note = "（%d 秒後才能再用）" % ceili(player.binoculars_cooldown)
			_detail.text += note
			_actions.add_child(_action("使用", func():
				player.use_item(uid)
				_rebuild(), uid == "binoculars" and player.binoculars_cooldown > 0.0))
		"live":
			var live: Dictionary = Profile.LIVE_BAITS[item.index]
			var on: bool = player.live_bait == item.index and player.fishing_mode == Player.FishingMode.BOBBER
			_detail.text = "%s x%d：%s%s" % [live.name, item.count, live.desc, "（使用中）" if on else ""]
			if on:
				_actions.add_child(_action("改用基礎餌料", func():
					player.choose_live_bait("")
					_rebuild(), busy))
			else:
				_actions.add_child(_action("裝上", func():
					player.choose_live_bait(item.index)
					_rebuild(), busy))
	# User request (multiplayer to come): put things down for a teammate.
	if item.has("bag"):
		_actions.add_child(_action("放在地上", func():
			player.put_item_down(item.bag)
			_selected = {}
			_rebuild(), busy))
	if busy and item.kind in ["bait", "lure", "live"]:
		_detail.text += "（收線後才能換）"


## User request: things can be dragged out of the bag onto the ground;
## rare fish, gear and special things ask first.
var _ghost: TextureRect
var _confirm: Control


func can_drop(item: Dictionary) -> bool:
	return _mode_kind == "normal" and (item.kind == "fish" or item.has("bag"))


func drag_start(item: Dictionary) -> void:
	_ghost = TextureRect.new()
	_ghost.texture = FishData.icon(item.get("id", ""), item.label) if item.kind == "fish" else Items.icon(item.get("item", ""))
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.size = Vector2(item.size) * CELL
	_ghost.modulate = Color(1, 1, 1, 0.8)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)


func drag_move(at: Vector2) -> void:
	if _ghost != null:
		_ghost.position = at - _ghost.size / 2.0
		# Out of the bag: reddish, "put down here".
		_ghost.modulate = Color(1, 0.75, 0.6, 0.9) if not _panel.get_global_rect().has_point(at) else Color(1, 1, 1, 0.8)


func drag_end(item: Dictionary, at: Vector2) -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _panel.get_global_rect().has_point(at):
		return
	if precious(item):
		_ask_drop(item)
	else:
		_drop(item)


## Worth a second thought before leaving on the ground: rare fish (a rare
## or legendary catch, a style's rarest, the sea's rare ones), gear, the
## heart and anything special.
static func precious(item: Dictionary) -> bool:
	match item.kind:
		"fish":
			var fish: Dictionary = GameState.carried_fish[item.index] if item.index < GameState.carried_fish.size() else {}
			if fish.get("rarity", "common") != "common" or fish.get("size", "") == "huge":
				return true
			var id: String = fish.get("id", "")
			if id in FishData.SEA_RARE or id in FishData.SEA_LEGEND:
				return true
			for style in FishData.STYLE_FISH:
				if FishData.STYLE_FISH[style][1] == id:
					return true
			return false
		"lure", "battery", "bait", "live":
			return false
	return true


func _drop(item: Dictionary) -> void:
	var player := _player()
	if player == null:
		return
	if item.kind == "fish":
		player.put_fish_down(item.index)
	elif item.has("bag"):
		player.put_item_down(item.bag)
	_selected = {}
	_rebuild()


func _ask_drop(item: Dictionary) -> void:
	if _confirm != null:
		return
	var shade := ColorRect.new()
	shade.name = "DropConfirm"
	shade.color = Color(0, 0, 0, 0.45)
	shade.size = Vector2(960, 540)
	add_child(shade)
	_confirm = shade
	var made := UiKit.window("丟在地上")
	var box: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	col.add_theme_constant_override("separation", 10)
	col.add_child(_label("確定把 %s 丟在地上？" % item.label, 18, UiKit.GOLD_BRIGHT))
	col.add_child(_label("這是稀有或重要的東西，丟了可能會被鬼吃掉或被別人撿走。", 14, UiKit.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := _button("丟掉")
	UiKit.style_button(yes, "red", FONT)
	yes.name = "ConfirmDrop"
	yes.pressed.connect(func():
		_close_confirm()
		_drop(item))
	var no := _button("取消")
	no.pressed.connect(_close_confirm)
	row.add_child(yes)
	row.add_child(no)
	col.add_child(row)
	box.add_child(col)
	shade.add_child(box)
	box.reset_size()
	box.position = (Vector2(960, 540) - box.size) / 2.0


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null


func select(kind: String, index) -> void:
	if _mode_kind == "sacrifice":
		if kind == "fish":
			var uid: int = int(GameState.carried_fish[index].get("uid", -1))
			if _marked.has(uid):
				_marked.erase(uid)
			else:
				_marked[uid] = true
		_rebuild()
		return
	if _mode_kind == "pick_lure" and kind != "fish":
		return
	_selected = {"kind": kind, "index": index}
	_rebuild()


## Offering at the altar: the marked fish, what they'd add, offer them.
func _show_offering() -> void:
	var picked := _marked_indices()
	var total := 0.0
	for i in picked:
		total += float(GameState.carried_fish[i].get("value", 0.0))
	_detail.text = "點魚選擇要獻祭的（可多選）。已選 %d 條，額度 +%.0f" % [picked.size(), total] \
		if not picked.is_empty() else "點魚選擇要獻祭的（可多選）"
	_actions.add_child(_action("全選", func():
		for f in GameState.carried_fish:
			_marked[int(f.get("uid", -1))] = true
		_rebuild()))
	var go := _action("獻祭 %d 條" % picked.size(), func():
		var offered := GameState.sacrifice_many(_marked_indices())
		if not offered.is_empty():
			GameState.push_message("獻祭了 %d 條魚" % offered.size())
		toggle(), picked.is_empty())
	go.name = "Offer"
	_actions.add_child(go)
	_actions.add_child(_action("取消", toggle))


func _marked_indices() -> Array:
	var out := []
	for i in GameState.carried_fish.size():
		if _marked.has(int(GameState.carried_fish[i].get("uid", -1))):
			out.append(i)
	return out


## Picking the 誘惑 fish: tap one, then confirm.
func _show_lure_pick(_items: Array) -> void:
	if _selected.is_empty() or _selected.kind != "fish" or _selected.index >= GameState.carried_fish.size():
		_selected = {}
		_detail.text = "點一條魚，選它當誘餌"
		_actions.add_child(_action("取消", toggle))
		return
	var fish: Dictionary = GameState.carried_fish[_selected.index]
	_detail.text = "選定 %s 為誘餌？" % fish.get("name", "魚")
	var ok := _action("確定", func():
		GameState.set_lure(_selected.index)
		GameState.push_message("誘餌：%s（按住誘惑鈕蓄力丟出）" % fish.get("name", "魚"))
		toggle())
	ok.name = "ConfirmLure"
	_actions.add_child(ok)
	_actions.add_child(_action("取消", toggle))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", FONT)
	return b


func _choice(text: String, current: bool, disabled: bool, pick: Callable) -> Button:
	var b := _button(text)
	b.disabled = disabled or current
	if current:
		UiKit.style_button(b, "red", FONT)
		b.add_theme_stylebox_override("disabled", UiKit.button_box("red", "normal"))
		b.add_theme_color_override("font_disabled_color", UiKit.GOLD_BRIGHT)
	if pick.is_valid():
		b.pressed.connect(func():
			pick.call()
			_rebuild())
	return b


## A button for what can be done with the chosen thing; the main ones red.
func _action(text: String, act: Callable, disabled := false) -> Button:
	var b := _button(text)
	b.disabled = disabled
	b.pressed.connect(act)
	if text in ["設為誘餌", "確定", "裝上", "改用浮標"] or text.begins_with("獻祭"):
		UiKit.style_button(b, "red", FONT)
	return b


## The grid: cells, and each item as a tile over the cells it takes.
class GridView extends Control:
	var owner_bag: Backpack
	var items: Array = []
	var placed: Array = []
	var selected := {}

	var _press := -1
	var _press_at := Vector2.ZERO
	var _dragging := false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press = -1
				_dragging = false
				var cell := Vector2i(event.position / Backpack.CELL)
				for i in placed.size():
					var r: Rect2i = placed[i]
					if r.has_point(cell):
						_press = i
						_press_at = event.position
				accept_event()
			else:
				if _press >= 0 and _press < items.size():
					if _dragging:
						owner_bag.drag_end(items[_press], get_global_transform() * event.position)
					else:
						owner_bag.select(items[_press].kind, items[_press].index)
				_press = -1
				_dragging = false
				accept_event()
		elif event is InputEventMouseMotion and _press >= 0 and _press < items.size():
			# User request: drag a thing out of the bag to put it down.
			if not _dragging and event.position.distance_to(_press_at) > 10.0 and owner_bag.can_drop(items[_press]):
				_dragging = true
				owner_bag.drag_start(items[_press])
			if _dragging:
				owner_bag.drag_move(get_global_transform() * event.position)
			accept_event()

	func _draw() -> void:
		for x in Inventory.COLS:
			for y in Inventory.ROWS:
				UiKit.draw_slot(self, Rect2(Vector2(x, y) * Backpack.CELL, Vector2.ONE * Backpack.CELL).grow(-1.5))
		UiKit.draw_shut_rows(self, Backpack.CELL)
		for i in placed.size():
			var item: Dictionary = items[i]
			var cells: Rect2i = placed[i]
			var r := Rect2(Vector2(cells.position) * Backpack.CELL, Vector2(cells.size) * Backpack.CELL).grow(-2.0)
			var is_sel: bool = not selected.is_empty() and selected.kind == item.kind and selected.index == item.index
			var rarity := _rarity(item)
			# A packed thing in one cell shows its square icon (the MMO look).
			var square: Texture2D = Items.square_icon(item.item) if item.has("item") and cells.size.x == cells.size.y else null
			UiKit.draw_slot(self, r, rarity, is_sel, square)
			var inner := r.grow(-4.0)
			var col: Color = Backpack.ROTTEN_COLOR if item.get("rotten", false) else Backpack.KIND_COLORS.get(item.kind, Color.GRAY)
			if square == null:
				draw_texture_rect(UiKit.glow(), inner, false, Color(col.lightened(0.3), 0.4))
			if item.kind == "fish":
				# Its picture, fitted in (2:1).
				var tex := FishData.icon(item.get("id", ""), item.label)
				if tex != null:
					var fit := minf(inner.size.x / 2.0, inner.size.y) * 0.95
					var pic := Rect2(inner.get_center() - Vector2(fit, fit / 2.0), Vector2(fit * 2.0, fit))
					draw_texture_rect(tex, pic, false, Color(0.55, 0.5, 0.35) if item.get("rotten", false) else Color.WHITE)
			elif item.has("item") and square == null:
				# Packed before the run: its picture (Items.icon), fitted in.
				var tex := Items.icon(item.item)
				if tex != null:
					var k := minf(inner.size.x / tex.get_width(), inner.size.y / tex.get_height())
					var sz := Vector2(tex.get_size()) * k
					draw_texture_rect(tex, Rect2(inner.get_center() - sz / 2.0, sz), false)
			if item.kind == "fish":
				var uid: int = int(GameState.carried_fish[item.index].get("uid", -1))
				if owner_bag.marked().has(uid):
					draw_rect(r, Color(0.4, 1.0, 0.5, 0.25))
					draw_rect(r, Color(0.4, 1.0, 0.5, 0.9), false, 2.5)
					UiKit.draw_text(self, Vector2(r.position.x, r.end.y - 4), "✓", 16, Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4.0)
				if GameState.lure_index() == item.index:
					# The 誘惑 fish: a badge at the top right.
					var at := Vector2(r.end.x - 10.0, r.position.y + 10.0)
					draw_circle(at, 9.0, Color(0.7, 0.18, 0.1))
					draw_arc(at, 9.0, 0.0, TAU, 20, UiKit.GOLD, 1.5)
					UiKit.draw_text(self, at + Vector2(-9, 5), "誘", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 18)
			var name: String = item.label
			var fs := 12 if cells.size.x > 1 else 11
			var text_w := r.size.x - 8.0
			UiKit.draw_text(self, r.position + Vector2(4, 15), name, fs, UiKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_LEFT, text_w)
			if item.kind == "fish":
				UiKit.draw_text(self, r.position + Vector2(4, r.size.y - 5), item.grade, 11, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, text_w)
			elif item.count > 0:
				UiKit.draw_text(self, r.position + Vector2(0, r.size.y - 5), str(item.count), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5.0)

	## A thing's rarity: a fish's own, a packed thing's by its id.
	func _rarity(item: Dictionary) -> String:
		if item.kind == "fish" and item.index < GameState.carried_fish.size():
			return UiKit.fish_rarity(GameState.carried_fish[item.index])
		if item.has("item"):
			return UiKit.item_rarity(item.item)
		if item.kind == "heart":
			return "legend"
		return "common"


## While a window's up, the sticks leave its touches alone (they'd walk the
## player, or swing and flash the light).
static func set_sticks_enabled(tree: SceneTree, enabled: bool) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	for path in ["HUD/Panel/MoveJoystick", "HUD/Panel/AimJoystick"]:
		var stick := scene.get_node_or_null(path)
		if stick != null:
			if not enabled:
				stick._reset()  # let go of any touch it holds, or it'd stay pushed
			stick.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
