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
##
## User request: the character's gear beside the grid - the main hand (the
## rod), the off hand (a weapon or the net) and the light - and things
## dragged between them (between casts): gear from the bag onto its slot
## puts it on (what was there goes into the bag in its place), off a slot
## onto the grid takes it off. Dragged, a thing shows as its simple square
## icon.
##
## User request: bigger (the cells were hard to tap), and a tapped thing
## opens its own little card beside it - what it is and what can be done
## with it. Picking fish (the altar's offering, the 誘惑 fish) opens a
## window of just the fish (FishPicker), not the bag.

## (User request, again: bigger still - 60 was hard to hit on a phone.)
const CELL := 72.0
const PANEL_SIZE := Vector2(820, 470)
## The gear slots (EquipSlot): [Profile.equipped slot, its name].
const GEAR_SLOTS := [["rod", "主手・釣竿"], ["offhand", "副手"], ["light", "燈具"]]
const GEAR_SIDE := 76.0
const FONT := 16
## The tapped thing's card: its width, and its gap from the thing.
const CARD_WIDTH := 300.0
const CARD_GAP := 10.0
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
var _clasp_label: Label
var _gear_col: VBoxContainer
var _gear_slots: Array = []
var _mode: Label
var _grid: GridView
var _hint: Label
## The tapped thing's card (see above): its picture, name, what it is, what
## can be done with it.
var _card: PanelContainer
var _card_pic: TextureRect
var _card_name: Label
var _card_sub: Label
var _detail: Label
var _vitals: FishVitals
var _card_trait: Label
var _actions: HFlowContainer
## The thing whose card is up.
var _shown := {}
var _picker: FishPicker
var _key_held := false
var _refresh := 0.0
var _selected := {}  # {kind, index} of the tapped item
## User request: picking fish - "sacrifice" (at the altar: pick the fish
## to offer, then offer them) and "pick_lure" (the fish the 誘惑 button
## throws), in FishPicker; "normal" otherwise.
var _mode_kind := "normal"
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
	# User request (活魚扣): the fish on the clasps - they take no room in the grid.
	_clasp_label = _label("", 13, UiKit.GOLD)
	_clasp_label.name = "ClaspFish"
	list.add_child(_clasp_label)
	_mode = _label("", 14, UiKit.GOLD)
	list.add_child(_mode)

	# The gear worn, beside the grid.
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 14)
	_gear_col = VBoxContainer.new()
	_gear_col.add_theme_constant_override("separation", 10)
	for g in GEAR_SLOTS:
		var box := EquipSlot.new()
		box.name = "Gear_" + g[0]
		box.slot = g[0]
		box.title = g[1]
		box.owner_bag = self
		box.custom_minimum_size = Vector2(GEAR_SIDE + 96.0, GEAR_SIDE)
		_gear_col.add_child(box)
		_gear_slots.append(box)
	middle.add_child(_gear_col)
	_grid = GridView.new()
	_grid.owner_bag = self
	_grid.custom_minimum_size = Vector2(Inventory.COLS, Inventory.ROWS) * CELL
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	middle.add_child(_grid)
	list.add_child(middle)

	_hint = _label("點一下東西看詳情・拖到左邊的裝備欄換裝・拖出背包就放在地上", 14, UiKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(_hint)
	_build_card()
	_picker = FishPicker.new()
	_picker.name = "FishPicker"
	_picker.owner_bag = self
	add_child(_picker)


## The tapped thing's card (hidden until something's tapped).
func _build_card() -> void:
	_card = UiKit.tooltip_panel()
	_card.name = "ItemCard"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_card_pic = TextureRect.new()
	_card_pic.custom_minimum_size = Vector2(64, 64)
	_card_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_card_pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	_card_name = UiKit.label("", 19, UiKit.GOLD_BRIGHT, true)
	# (user request: a fish's 個性 just beside its name)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(_card_name)
	_card_trait = UiKit.label("", 13, UiKit.USE)
	_card_trait.name = "Personality"
	_card_trait.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(_card_trait)
	words.add_child(name_row)
	_card_sub = UiKit.label("", 13, UiKit.DIM)
	words.add_child(_card_sub)
	head.add_child(words)
	var close := UiKit.close_button()
	close.pressed.connect(deselect)
	head.add_child(close)
	col.add_child(head)
	_detail = _label("", 15, UiKit.TEXT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = CARD_WIDTH - 24.0
	col.add_child(_detail)
	# (a fish's vitality or freshness, and its traits)
	_vitals = FishVitals.new()
	_vitals.custom_minimum_size.x = CARD_WIDTH - 24.0
	col.add_child(_vitals)
	_actions = HFlowContainer.new()
	# (laid out at the card's width from the start - else the card is sized
	# for its buttons one under another)
	_actions.custom_minimum_size.x = CARD_WIDTH - 24.0
	_actions.add_theme_constant_override("h_separation", 8)
	_actions.add_theme_constant_override("v_separation", 8)
	col.add_child(_actions)
	_card.add_child(col)
	add_child(_card)


func is_open() -> bool:
	return _panel.visible or _picker.visible


func toggle() -> void:
	if _picker.visible:
		_picker.close()
		_mode_kind = "normal"
		set_sticks_enabled(get_tree(), true)
		return
	_panel.visible = not _panel.visible
	_close_flyout()
	_backdrop.visible = _panel.visible
	set_sticks_enabled(get_tree(), not _panel.visible)
	_selected = {}
	_mode_kind = "normal"
	_card.visible = false
	if _panel.visible:
		_rebuild()
		_panel.reset_size()
		_panel.position = ((Vector2(960, 540) - _panel.size) * 0.5).floor()


## Opens the fish picker (FishPicker): "sacrifice" or "pick_lure".
func open_mode(kind: String) -> void:
	if _panel.visible:
		toggle()
	_mode_kind = kind
	_selected = {}
	set_sticks_enabled(get_tree(), false)
	_picker.open(kind)


func mode() -> String:
	return _mode_kind


## Nothing tapped: the card goes.
func deselect() -> void:
	_selected = {}
	_rebuild()


func _process(delta: float) -> void:
	var held := Input.is_key_pressed(KEY_I)
	if held and not _key_held:
		toggle()
	_key_held = held
	if _panel.visible:
		_refresh -= delta
		if _refresh <= 0.0:
			_rebuild(true)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## (`periodic`: the regular refresh - the open card is left as it is, so a
## button half pressed isn't swapped for a new one under the finger)
func _rebuild(periodic := false) -> void:
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

	var hung := GameState.carried_fish.filter(func(f): return f.get("clasped", false))
	_clasp_label.visible = not hung.is_empty()
	_clasp_label.text = "活魚扣：" + "、".join(hung.map(func(f): return "%s %d%%" % [f.get("name", "魚"), roundi(float(FishLife.bar(f).share) * 100.0)]))

	for box in _gear_slots:
		box.selected = not _selected.is_empty() and _selected.kind == "slot" and _selected.index == box.slot
		box.queue_redraw()

	var using: String = "浮標" if player.fishing_mode == Player.FishingMode.BOBBER else "路亞・" + Profile.LURES[player.current_lure].name
	_mode.text = "釣法：%s%s" % [using, "　（油箱提在手上，不佔背包）" if player.carrying_oil_drum else ""]
	if periodic and _card.visible and _shown == _selected:
		return
	_shown = _selected.duplicate()
	_show_selected(player, items, placed)


## The tapped thing's card: filled in, and put beside it.
func _show_selected(player: Player, items: Array, placed: Array) -> void:
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	_vitals.visible = false
	if not _selected.is_empty() and _selected.kind == "slot":
		_show_slot(player, _selected.index)
		for box in _gear_slots:
			if box.slot == _selected.index:
				_place_card(box.get_global_rect())
				_place_later(box.get_global_rect())
		return
	var item := {}
	var at := Rect2()
	for i in items.size():
		var it: Dictionary = items[i]
		if not _selected.is_empty() and it.kind == _selected.kind and it.index == _selected.index:
			item = it
			if i < placed.size():
				var cells: Rect2i = placed[i]
				at = _grid.get_global_transform() * Rect2(Vector2(cells.position) * CELL, Vector2(cells.size) * CELL)
	if item.is_empty():
		_selected = {}
		_card.visible = false
		return
	_card_head(item)
	var busy := player.state != Player.State.IDLE
	match item.kind:
		"fish":
			var fish: Dictionary = GameState.carried_fish[item.index]
			# (the card's body is FishVitals: 稀有度, 大小＋價值, 活性, the bar, the affixes)
			_detail.text = ""
			if FishLife.state(fish) == "rotten":
				_detail.text = "腐敗了：拿去獻祭會賭一把"
			elif FishLife.state(fish) == "dead":
				_detail.text = "已死亡，只能賣給商人"
			_vitals.show_fish(fish, false, "field")
			if GameState.lure_index() == item.index:
				_detail.text += "　・已設為誘惑用的魚"
				_actions.add_child(_action("取消誘餌", func():
					GameState.lure_uid = -1
					_rebuild()))
			else:
				_actions.add_child(_action("設為誘餌", func():
					GameState.set_lure(item.index)
					_rebuild()))
			if item.size.x != item.size.y:
				_actions.add_child(_action("旋轉", func(): _rotate(item)))
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
			var gid: String = item.get("item", "")
			_detail.text = "備用的，拖到左邊的裝備欄就能換上（收竿時才能換）%s" % _wear_text(gid)
			if Items.def(gid).get("slot", "") != "":
				_actions.add_child(_action("裝備", func():
					equip_from_bag(item.bag)
					_rebuild(), busy))
			if gid == "oxy_box":
				_actions.add_child(_action("使用", func(): _open_oxy(at)))
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
			elif uid == "glow_mushroom" and player.glow_timer > 0.0:
				note = "（藍光還有 %d 秒；再用會重新計時）" % ceili(minf(player.glow_timer, Player.GLOW_TIME))
			elif uid == "eye_ghost" and player.nearest_ghost() == null:
				note = "（附近沒有鬼）"
			elif uid == "binoculars" and player.binoculars_cooldown > 0.0:
				note = "（%d 秒後才能再用）" % ceili(player.binoculars_cooldown)
			_detail.text += note
			if u.get("target", "") == "fish":
				# (魚氧樹, 冷凍土: used on one of the fish carried - pick which)
				_actions.add_child(_action("用在魚身上", func():
					var panel := FishPickPanel.new("%s用在哪條魚身上？" % u.name, uid)
					panel.picked.connect(func(index):
						player.use_on_fish(uid, index)
						_rebuild())
					add_child(panel), GameState.carried_fish.is_empty()))
			else:
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
	# User request: what takes more than a cell can be turned.
	if item.has("bag") and item.size.x != item.size.y:
		_actions.add_child(_action("旋轉", func(): _rotate(item)))
	# User request (multiplayer to come): put things down for a teammate.
	if item.has("bag"):
		_actions.add_child(_action("放在地上", func():
			player.put_item_down(item.bag)
			_selected = {}
			_rebuild(), busy))
	if busy and item.kind in ["bait", "lure", "live"]:
		_detail.text += "（收線後才能換）"
	_detail.visible = _detail.text != ""
	# (user report: a thing low in the bag had its card run off the bottom,
	# its buttons out of reach - placed once it's filled, and again once
	# it's laid out)
	_place_card(at)
	_place_later(at)


## The card's head: the thing's picture and name (in its rarity's colour),
## and what kind of thing it is.
func _card_head(item: Dictionary) -> void:
	var id: String = item.get("item", "")
	var tex: Texture2D = null
	if item.kind == "fish":
		tex = FishData.icon(item.get("id", ""), item.label)
	elif id != "":
		tex = Items.square_icon(id)
		if tex == null:
			tex = Items.icon(id)
	_card_pic.texture = tex
	_card_pic.visible = tex != null
	_card_pic.custom_minimum_size = Vector2(96, 48) if item.kind == "fish" else Vector2(64, 64)
	var rarity := GridView.rarity_of(item)
	_card_name.text = item.label
	_card_name.add_theme_color_override("font_color", UiKit.rarity_color(rarity))
	var kinds := {"fish": "魚", "heart": "心臟", "bait": "餌料", "lure": "路亞", "battery": "電池", "gear": "裝備",
		"use": "道具", "live": "活餌"}
	_card_sub.text = "%s　%s" % [UiKit.rarity_name(rarity), kinds.get(item.kind, "")]
	_card_trait.text = ""
	if item.kind == "fish":
		# (the fish's rarity is the body's line; its 個性 is by its name)
		_card_sub.text = ""
		_card_trait.text = FishData.trait_name(str(GameState.carried_fish[item.index].get("tank_trait", "")))
	_card_sub.visible = _card_sub.text != ""


## The card beside `at` (a thing's rect on screen): to its right if it
## fits, else its left; kept on the screen.
## (once its words have been laid out at their width)
func _place_later(at: Rect2) -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_place_card(at)


func _place_card(at: Rect2) -> void:
	if _selected.is_empty():
		return
	_card.visible = true
	_card.reset_size()
	var sz := _card.size
	var x := at.end.x + CARD_GAP
	if x + sz.x > 950.0:
		x = at.position.x - CARD_GAP - sz.x
	var y := clampf(at.position.y - 10.0, 10.0, 530.0 - sz.y)
	_card.position = Vector2(clampf(x, 10.0, 950.0 - sz.x), y)


## User request: things can be dragged out of the bag onto the ground;
## rare fish, gear and special things ask first.
var _ghost: TextureRect
var _confirm: Control


func can_drop(item: Dictionary) -> bool:
	return _mode_kind == "normal" and (item.kind == "fish" or item.has("bag") or item.kind == "slot")


## User request (arranging the bag): a thing dragged to another place in the grid goes there,
## if it - the whole of it - fits; where it's let go is the cell its grabbed part's over.
## `_grab` is which of its cells was grabbed (from its top left).
var _drag_item := {}
var _grab := Vector2i.ZERO


func drag_start(item: Dictionary, grab := Vector2i.ZERO) -> void:
	_drag_item = item
	_grab = grab
	# User request: dragged, a thing shows as its simple square icon.
	_ghost = TextureRect.new()
	var id: String = item.get("item", "")
	var square := Items.square_icon(id) if id != "" else null
	if item.kind == "fish":
		_ghost.texture = FishData.icon(item.get("id", ""), item.label)
	else:
		_ghost.texture = square if square != null else Items.icon(id)
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.size = Vector2.ONE * CELL
	_ghost.modulate = Color(1, 1, 1, 0.8)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)


func drag_move(at: Vector2) -> void:
	if _ghost != null:
		_ghost.position = at - _ghost.size / 2.0
		# Out of the bag: reddish, "put down here".
		_ghost.modulate = Color(1, 0.75, 0.6, 0.9) if not _panel.get_global_rect().has_point(at) else Color(1, 1, 1, 0.8)
	# A fish over the fish box's icon: its cells open; over them it shows where it'd go.
	if not _drag_item.is_empty() and _drag_item.kind == "fish" and _drag_item.index < GameState.carried_fish.size():
		var held: Dictionary = GameState.carried_fish[_drag_item.index]
		if not _flyout_open() and _oxy_icon_at(at).size != Vector2.ZERO and Profile.can_use_oxy_box():
			_open_oxy(_oxy_icon_at(at))
		if _flyout_open():
			_flyout.hover_fish(held, at, _grab)
			if _flyout.contains(at):
				return
	# Over the grid: where it would go, green if it fits, red if not.
	if _grid != null and not _drag_item.is_empty() and _drag_item.kind != "slot" and _grid.get_global_rect().has_point(at):
		var i := _grid_index(_drag_item)
		if i >= 0:
			var rect := Rect2i(_grid.cell_at(at) - _grab, (_grid.placed[i] as Rect2i).size)
			_grid.preview = rect
			_grid.preview_ok = can_place(_drag_item, rect.position)
			_grid.queue_redraw()
			return
	if _grid != null and _grid.preview.size != Vector2i.ZERO:
		_grid.preview = Rect2i()
		_grid.queue_redraw()


## Where in the grid's `items` this thing is (-1: not there).
func _grid_index(item: Dictionary) -> int:
	for i in _grid.items.size():
		var it: Dictionary = _grid.items[i]
		if it.kind == item.kind and it.index == item.index and it.get("bag", -1) == item.get("bag", -1):
			return i
	return -1


## Would `item` fit with its top left at `cell`, everything else as it is? Whatever isn't
## placed by hand packs around it, so that has to keep working too.
func can_place(item: Dictionary, cell: Vector2i) -> bool:
	var i := _grid_index(item)
	var player := _player()
	if i < 0 or player == null:
		return false
	var rect := Rect2i(cell, (_grid.placed[i] as Rect2i).size)
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > Inventory.COLS or rect.end.y > Profile.bag_rows():
		return false
	for j in _grid.placed.size():
		if j != i and (_grid.placed[j] as Rect2i).intersects(rect):
			return false
	var list := Inventory.items(player)
	if i >= list.size():
		return false
	list[i]["cell"] = cell
	return not Inventory.pack(list).is_empty()


## Puts `item` down with its top left at `cell` (can_place); everything else keeps its place -
## a fish carried loose is pinned where it sits now, so nothing else shuffles. False if it
## doesn't fit.
func move_in_grid(item: Dictionary, cell: Vector2i) -> bool:
	if not can_place(item, cell):
		return false
	var i := _grid_index(item)
	for j in _grid.items.size():
		var other: Dictionary = _grid.items[j]
		if j != i and other.kind == "fish" and other.index < GameState.carried_fish.size() \
				and not GameState.carried_fish[other.index].has("cell"):
			var at: Vector2i = (_grid.placed[j] as Rect2i).position
			GameState.carried_fish[other.index]["cell"] = [at.x, at.y]
	if item.kind == "fish":
		GameState.carried_fish[item.index]["cell"] = [cell.x, cell.y]
	elif item.has("bag"):
		if not Profile.bag_move(item.bag, cell):
			return false
	else:
		return false
	_rebuild()
	return true


## A packed stack dropped on another of the same thing: it joins it (as much as it takes).
func _stack_onto(item: Dictionary, at: Vector2i) -> bool:
	for j in _grid.items.size():
		var other: Dictionary = _grid.items[j]
		if other.has("bag") and other.bag != item.bag and other.item == item.item and (_grid.placed[j] as Rect2i).has_point(at):
			if Profile.bag_move(item.bag, Profile.bag[other.bag].cell):
				_selected = {}
				_rebuild()
				return true
	return false


## The fish box's cells (FishFlyout) beside its icon `anchor` - from 使用, or a fish dragged
## onto the icon. One at a time.
var _flyout: FishFlyout


func _open_oxy(anchor: Rect2) -> void:
	if _flyout != null and is_instance_valid(_flyout):
		_flyout.queue_free()
	_flyout = FishFlyout.new(OxyStore.new(false), anchor)
	_flyout.closed.connect(_rebuild)
	add_child(_flyout)


func _close_flyout() -> void:
	if _flyout != null and is_instance_valid(_flyout):
		_flyout.queue_free()
	_flyout = null


## The fish box's icon under `at` - worn in its slot, or lying in the grid: its rect (global),
## or an empty one.
func _oxy_icon_at(at: Vector2) -> Rect2:
	for box in _gear_slots:
		if box.slot == "offhand" and Profile.has_oxy_box() and box.get_global_rect().has_point(at):
			return box.get_global_rect()
	if _grid.get_global_rect().has_point(at):
		var cell := _grid.cell_at(at)
		for j in _grid.items.size():
			var it: Dictionary = _grid.items[j]
			if it.get("item", "") == "oxy_box" and (_grid.placed[j] as Rect2i).has_point(cell):
				var r: Rect2i = _grid.placed[j]
				return _grid.get_global_transform() * Rect2(Vector2(r.position) * CELL, Vector2(r.size) * CELL)
	return Rect2()


func _unhandled_key_input(event: InputEvent) -> void:
	# R while a fish is held: turns it (lying <-> standing)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R \
			and not _drag_item.is_empty() and _drag_item.kind == "fish":
		_rotate(_drag_item)
		_rebuild()


func _flyout_open() -> bool:
	return _flyout != null and is_instance_valid(_flyout)


func drag_end(item: Dictionary, at: Vector2) -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_drag_item = {}
	if _grid != null:
		_grid.preview = Rect2i()
		_grid.queue_redraw()
	# A fish let go over the fish box's open cells: put in the cell it's over.
	if item.kind == "fish" and _flyout_open() and _flyout.contains(at):
		_flyout.drop_fish(GameState.carried_fish, item.index, at, _grab)
		_selected = {}
		_rebuild()
		return
	if _flyout_open():
		_flyout.clear_hover()
	# Onto a gear slot: put it on; a slot's thing onto the grid: off.
	for box in _gear_slots:
		if box.get_global_rect().has_point(at):
			if item.has("bag") and Items.def(item.get("item", "")).get("slot", "") == box.slot:
				equip_from_bag(item.bag)
			_rebuild()
			return
	if item.kind == "slot":
		if _grid.get_global_rect().has_point(at):
			unequip_to_bag(item.index, _grid.cell_at(at))
		_rebuild()
		return
	if _grid.get_global_rect().has_point(at):
		# (arranged: set down in the grid, if it fits there - or stacked onto the same thing)
		if not (item.has("bag") and _stack_onto(item, _grid.cell_at(at))):
			move_in_grid(item, _grid.cell_at(at) - _grab)
		return
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
	shade.add_child(box)
	box.reset_size()
	box.position = (Vector2(960, 540) - box.size) / 2.0


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null


## Puts on the bag's thing at Profile.bag[`index`] (Profile.equip_from_bag)
## - between casts, and only if the bag still holds everything after.
func equip_from_bag(index: int) -> bool:
	var player := _player()
	if player == null or player.state != Player.State.IDLE:
		GameState.push_message("收竿後才能換裝備")
		return false
	var before := [Profile.bag.duplicate(true), Profile.equipped.duplicate()]
	var id: String = Profile.bag[index].id if index >= 0 and index < Profile.bag.size() else ""
	if not Profile.equip_from_bag(index) or Inventory.pack(Inventory.items(_player())).is_empty():
		_undo(before)
		GameState.push_message("背包放不下換下來的裝備")
		return false
	_after_gear_change(player)
	GameState.push_message("換上了%s" % Items.name_of(id))
	return true


## Takes off what's in `slot` into the bag (at `cell` if it fits there).
func unequip_to_bag(slot: String, cell := Vector2i(-1, -1)) -> bool:
	var player := _player()
	if player == null or player.state != Player.State.IDLE:
		GameState.push_message("收竿後才能換裝備")
		return false
	if slot == "rod":
		GameState.push_message("釣竿一定要有一支，把另一支拖上來就能換")
		return false
	var before := [Profile.bag.duplicate(true), Profile.equipped.duplicate()]
	var id: String = Profile.equipped.get(slot, "")
	if not Profile.unequip_to_bag(slot, cell) or Inventory.pack(Inventory.items(_player())).is_empty():
		_undo(before)
		GameState.push_message("背包滿了，放不下")
		return false
	_after_gear_change(player)
	GameState.push_message("卸下了%s" % Items.name_of(id))
	return true


func _undo(before: Array) -> void:
	Profile.bag = before[0]
	Profile.equipped = before[1]
	Profile._sync_rod()
	Profile.profile_changed.emit()


## The light taken off while on: back to the lamp.
func _after_gear_change(player: Player) -> void:
	var lantern: Lantern = player.get_node("Lantern")
	if lantern.tool == Lantern.Tool.FLASHLIGHT and not Profile.has_flashlight:
		lantern.switch_tool(Lantern.Tool.LAMP)
	_selected = {}


## A worn thing's durability, said.
static func _wear_text(id: String) -> String:
	if Profile.max_durability(id) <= 0:
		return ""
	return "（耐久度 %d/%d）" % [Profile.durability(id), Profile.max_durability(id)]


## A gear slot tapped: what's in it, and taking it off.
func _show_slot(player: Player, slot: String) -> void:
	var id: String = Profile.equipped.get(slot, "")
	var title := ""
	for g in GEAR_SLOTS:
		if g[0] == slot:
			title = g[1]
	_card_head({"kind": "gear", "item": id if id != "" else ("lamp" if slot == "light" else ""),
		"label": Items.name_of(id) if id != "" else ("煤燈" if slot == "light" else title)})
	_card_sub.text = "穿戴中・" + title
	if id == "":
		_detail.text = "%s：空的。把背包裡的%s拖過來就能換上" % [title, {"offhand": "武器或撈網", "light": "手電筒", "rod": "釣竿"}.get(slot, "裝備")]
		if slot == "light":
			_detail.text = "燈具：煤燈（隨身）。把手電筒拖過來就能換上"
		return
	var desc: String = Items.def(id).get("desc", "")
	if id.begins_with("rod_"):
		desc = Items.rod_effects(Profile.ROD_TIERS[int(id.substr(4))])
	var lines := [desc] if desc != "" else []
	if Profile.max_durability(id) > 0:
		lines.append("耐久度 %d / %d" % [Profile.durability(id), Profile.max_durability(id)])
	_detail.text = "\n".join(lines)
	if id == "oxy_box":
		_actions.add_child(_action("使用", func():
			for box in _gear_slots:
				if box.slot == slot:
					_open_oxy(box.get_global_rect())))
	if slot != "rod":
		_actions.add_child(_action("卸下放進背包", func():
			unequip_to_bag(slot)
			_rebuild(), player.state != Player.State.IDLE))


## User request: a thing over more than a cell turned (lying <-> standing) in
## the bag - if the bag still packs.
func _rotate(item: Dictionary) -> void:
	if item.kind == "fish":
		var f: Dictionary = GameState.carried_fish[item.index]
		f["rot"] = not bool(f.get("rot", false))
		if Inventory.pack(Inventory.items(_player())).is_empty():
			f["rot"] = not bool(f["rot"])
			GameState.push_message("轉過來放不下")
	elif item.has("bag"):
		if not Profile.bag_rotate(int(item.bag)) or Inventory.pack(Inventory.items(_player())).is_empty():
			Profile.bag_rotate(int(item.bag))
			GameState.push_message("轉過來放不下")
	_rebuild()


func select(kind: String, index) -> void:
	if _mode_kind != "normal":
		if kind == "fish":
			_picker.toggle(index)
		return
	# Tapped again: the card goes.
	if not _selected.is_empty() and _selected.kind == kind and _selected.index == index:
		deselect()
		return
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
	if text in ["設為誘餌", "裝上", "改用浮標", "裝備", "使用"]:
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
	## Where the thing being dragged would go (cells), and whether it fits there.
	var preview := Rect2i()
	var preview_ok := false

	## The grid cell under `at` (global).
	func cell_at(at: Vector2) -> Vector2i:
		var local: Vector2 = get_global_transform().affine_inverse() * at
		return Vector2i(floori(local.x / Backpack.CELL), floori(local.y / Backpack.CELL))

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
				else:
					owner_bag.deselect()
				_press = -1
				_dragging = false
				accept_event()
		elif event is InputEventMouseMotion and _press >= 0 and _press < items.size():
			# User request: drag a thing out of the bag to put it down.
			if not _dragging and event.position.distance_to(_press_at) > 10.0 and owner_bag.can_drop(items[_press]):
				_dragging = true
				var grab := Vector2i(_press_at / Backpack.CELL) - (placed[_press] as Rect2i).position
				owner_bag.drag_start(items[_press], grab)
			if _dragging:
				owner_bag.drag_move(get_global_transform() * event.position)
			accept_event()

	func _draw() -> void:
		for x in Inventory.COLS:
			for y in Inventory.ROWS:
				UiKit.draw_slot(self, Rect2(Vector2(x, y) * Backpack.CELL, Vector2.ONE * Backpack.CELL).grow(-1.5))
		UiKit.draw_shut_rows(self, Backpack.CELL)
		if preview.size != Vector2i.ZERO:
			var pr := Rect2(Vector2(preview.position) * Backpack.CELL, Vector2(preview.size) * Backpack.CELL).grow(-1.0)
			var shown := pr.intersection(Rect2(Vector2.ZERO, Vector2(Inventory.COLS, Inventory.ROWS) * Backpack.CELL))
			draw_rect(shown, Color(0.4, 0.9, 0.5, 0.28) if preview_ok else Color(0.95, 0.3, 0.25, 0.28))
			draw_rect(shown, Color(0.5, 1.0, 0.6, 0.8) if preview_ok else Color(1.0, 0.4, 0.35, 0.8), false, 2.0)
		for i in placed.size():
			var item: Dictionary = items[i]
			var cells: Rect2i = placed[i]
			var r := Rect2(Vector2(cells.position) * Backpack.CELL, Vector2(cells.size) * Backpack.CELL).grow(-2.0)
			var is_sel: bool = not selected.is_empty() and selected.kind == item.kind and selected.index == item.index
			var rarity := rarity_of(item)
			# A packed thing in one cell shows its square icon (the MMO look).
			var square: Texture2D = Items.square_icon(item.item) if item.has("item") and cells.size.x == cells.size.y else null
			UiKit.draw_slot(self, r, rarity, is_sel, square)
			var inner := r.grow(-4.0)
			var col: Color = Backpack.ROTTEN_COLOR if item.get("rotten", false) else Backpack.KIND_COLORS.get(item.kind, Color.GRAY)
			if square == null:
				draw_texture_rect(UiKit.glow(), inner, false, Color(col.lightened(0.3), 0.4))
			if item.kind == "fish":
				# Its picture, filling the cells it takes (turned up in a standing one).
				var tex := FishData.icon(item.get("id", ""), item.label)
				if tex != null:
					UiKit.draw_fish_fit(self, inner.grow(-2.0), tex, Color(0.55, 0.5, 0.35) if item.get("rotten", false) \
						else (Color(0.75, 0.78, 0.8) if item.get("dead", false) else Color.WHITE))
				# (how much life or freshness it has left: a thin bar under it)
				if item.index < GameState.carried_fish.size() and FishLife.has_life(GameState.carried_fish[item.index]):
					var bar := FishLife.bar(GameState.carried_fish[item.index])
					var strip := Rect2(Vector2(inner.position.x + 3.0, inner.end.y - 6.0), Vector2(inner.size.x - 6.0, 4.0))
					draw_rect(strip, Color(0, 0, 0, 0.6))
					var colr: Color = FishVitals.FRESH_COLOR if bar.kind == "fresh" else (FishVitals.ROT_COLOR if bar.kind == "rotten" \
						else FishVitals.VIT_COLOR.lerp(FishVitals.VIT_LOW, 1.0 - clampf(float(bar.share) * 2.0, 0.0, 1.0)))
					draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(float(bar.share), 0.0, 1.0), strip.size.y)), colr)
			elif item.has("item") and square == null:
				# Packed before the run: its picture (Items.icon), fitted in.
				var tex := Items.icon(item.item)
				if tex != null:
					UiKit.draw_long_pic(self, inner, tex)
			if item.kind == "fish":
				if GameState.lure_index() == item.index:
					# The 誘惑 fish: a badge at the top right.
					var at := Vector2(r.end.x - 10.0, r.position.y + 10.0)
					draw_circle(at, 9.0, Color(0.7, 0.18, 0.1))
					draw_arc(at, 9.0, 0.0, TAU, 20, UiKit.GOLD, 1.5)
					UiKit.draw_text(self, at + Vector2(-9, 5), "誘", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 18)
			var name: String = item.label
			var fs := 13 if cells.size.x > 1 else 12
			var text_w := r.size.x - 8.0
			UiKit.draw_text(self, r.position + Vector2(4, 15), name, fs, UiKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_LEFT, text_w)
			if item.kind == "fish":
				UiKit.draw_text(self, r.position + Vector2(4, r.size.y - 5), item.grade, 12, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, text_w)
			elif item.count > 0:
				UiKit.draw_text(self, r.position + Vector2(0, r.size.y - 5), str(item.count), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5.0)
			if item.has("item"):
				ItemBoard.draw_wear(self, r, item.item)

	## A thing's rarity: a fish's own, a packed thing's by its id.
	static func rarity_of(item: Dictionary) -> String:
		if item.kind == "fish" and item.index < GameState.carried_fish.size():
			return UiKit.fish_rarity(GameState.carried_fish[item.index])
		if item.has("item"):
			return UiKit.item_rarity(item.item)
		if item.kind == "heart":
			return "legend"
		return "common"


## A gear slot beside the grid (GEAR_SLOTS): the thing worn in its square,
## the slot's name beside it; tapped, it's chosen; dragged, it comes off.
class EquipSlot extends Control:
	var owner_bag: Backpack
	var slot := ""
	var title := ""
	var selected := false
	var _press_at := Vector2.ZERO
	var _pressed := false
	var _dragging := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var id: String = Profile.equipped.get(slot, "")
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_at = event.position
			elif _pressed:
				_pressed = false
				if _dragging:
					owner_bag.drag_end({"kind": "slot", "index": slot, "item": id}, get_global_transform() * event.position)
				else:
					owner_bag.select("slot", slot)
				_dragging = false
			accept_event()
		elif event is InputEventMouseMotion and _pressed and id != "" and slot != "rod":
			if not _dragging and event.position.distance_to(_press_at) > 10.0:
				_dragging = true
				owner_bag.drag_start({"kind": "slot", "index": slot, "item": id, "size": Vector2i.ONE, "label": Items.name_of(id)})
			if _dragging:
				owner_bag.drag_move(get_global_transform() * event.position)
			accept_event()

	func _draw() -> void:
		var id: String = Profile.equipped.get(slot, "")
		var sq := Rect2(Vector2.ZERO, Vector2.ONE * minf(size.x, size.y))
		if id == "":
			UiKit.draw_slot(self, sq, "", selected)
			if slot == "light":
				var lamp: Texture2D = Items.square_icon("lamp")
				if lamp != null:
					draw_texture_rect(lamp, sq.grow(-6.0), false, Color(1, 1, 1, 0.75))
		else:
			UiKit.draw_slot(self, sq, UiKit.item_rarity(id), selected, Items.square_icon(id))
			ItemBoard.draw_wear(self, sq, id)
		var text_x := sq.end.x + 4.0
		UiKit.draw_text(self, Vector2(text_x, 24.0), title.split("・")[0], 15, UiKit.GOLD)
		var line := Items.name_of(id) if id != "" else ("煤燈" if slot == "light" else "（空）")
		UiKit.draw_text(self, Vector2(text_x, 46.0), line, 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x)


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

