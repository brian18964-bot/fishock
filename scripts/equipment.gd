extends ItemBoard

## The character's equipment page (from the main screen's 裝備). User
## request: the player sees their own character - it'll be dressed up
## later (a paper doll) - so the character stands on the left in 3D
## (CharacterViewer) wearing what's equipped; the slots are beside it:
## 釣竿, 燈具 and 武器 now, 帽子, 上衣, 背包 locked until the paper doll comes.
## And (user request) it's tied to the warehouse: its 裝備 tab and the bag
## are on the right - drag a rod or the flashlight onto a slot to put it
## on, off a slot to take it off, or tap one for its card.
## Dressed as an MMO character sheet (user request): the character in a
## framed window, the locked slots down its left side, the rod and the
## light along its foot with their names.
## User request (Camp v2): a 營地 tab beside 裝備 - the camp's tents
## (Profile.TENTS), each earned by an achievement and only for looks: the
## ones earned are pitched with a tap, the others show how far along they
## are.

const SLOT_LAYOUT := [
	["hat", "帽子", Rect2(34, 116, 58, 58), true],
	["top", "上衣", Rect2(34, 186, 58, 58), true],
	["pack", "背包", Rect2(34, 256, 58, 58), true],
	["rod", "主手・釣竿", Rect2(40, 452, 206, 58), false],
	["light", "燈具", Rect2(258, 452, 206, 58), false],
	# User request: the off hand - a weapon (Profile.WEAPONS) or the
	# landing net, one of them.
	["offhand", "副手", Rect2(404, 116, 58, 58), false],
]

var _viewer: CharacterViewer
var _purse: PanelContainer
var _stats: Label
var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid
var _tab := "gear"
var _tabs := {}
var _gear_windows: Array = []
var _camp_window: PanelContainer
var _tent_grid: GridContainer
var _tent_note: Label


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	_purse = UiKit.page_chrome(self, _on_back)
	var shop := UiKit.button("商城", 15, "red")
	shop.name = "ToShop"
	shop.position = Vector2(708, 12)
	shop.custom_minimum_size = Vector2(100, 38)
	shop.pressed.connect(func(): UiKit.page_go(self, "shop"))
	add_child(shop)
	for t in [["gear", "裝備", 486], ["camp", "營地", 592]]:
		var tb := UiKit.button(t[1], 15)
		tb.name = "Tab_" + t[0]
		tb.position = Vector2(t[2], 12)
		tb.custom_minimum_size = Vector2(100, 38)
		var key: String = t[0]
		tb.pressed.connect(func(): _show_tab(key))
		add_child(tb)
		_tabs[key] = tb

	# Left: the character, framed, with a warm glow behind it.
	var made := UiKit.window("釣客")
	var sheet: PanelContainer = made[0]
	sheet.name = "CharacterWindow"
	sheet.position = Vector2(14, 56)
	sheet.custom_minimum_size = Vector2(462, 474)
	add_child(sheet)
	var glow := TextureRect.new()
	glow.texture = UiKit.glow()
	glow.modulate = Color(1.0, 0.62, 0.3, 0.22)
	glow.position = Vector2(90, 110)
	glow.size = Vector2(320, 320)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	_viewer = CharacterViewer.new()
	_viewer.position = Vector2(100, 96)
	_viewer.size = Vector2(300, 318)
	_viewer.zoom = 0.9
	add_child(_viewer)
	for s in SLOT_LAYOUT:
		var box := ItemBoard.SlotBox.new(s[0], s[1], s[3])
		box.position = s[2].position
		box.size = s[2].size
		add_child(box)
		track(box)
	_stats = UiKit.label("", 14, UiKit.TEXT)
	_stats.position = Vector2(40, 414)
	_stats.custom_minimum_size = Vector2(424, 0)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stats)

	# Right: the warehouse's 裝備 tab, and the bag.
	var made2 := UiKit.window("倉庫・裝備")
	var gear: PanelContainer = made2[0]
	gear.position = Vector2(486, 56)
	gear.custom_minimum_size = Vector2(460, 180)
	_storage = ItemBoard.StorageGrid.new(7, 60.0)
	_storage.name = "Storage"
	_storage.tab = "gear"
	_storage.custom_minimum_size = Vector2(420, 120)
	_storage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(made2[1] as VBoxContainer).add_child(_storage)
	add_child(gear)
	var made3 := UiKit.window("背包")
	var bagwin: PanelContainer = made3[0]
	bagwin.position = Vector2(486, 244)
	bagwin.custom_minimum_size = Vector2(460, 286)
	_bag = ItemBoard.BagGrid.new(50.0)
	_bag.name = "Bag"
	_bag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(made3[1] as VBoxContainer).add_child(_bag)
	var hint := UiKit.label("把釣竿（主手）、手電筒、武器或撈網（副手）拖到左邊的欄位就能換上；點一下看說明", 13, UiKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(made3[1] as VBoxContainer).add_child(hint)
	add_child(bagwin)
	track(_storage)
	track(_bag)
	_gear_windows = [gear, bagwin]

	# The 營地 tab: the tents.
	var made4 := UiKit.window("營地・帳篷")
	_camp_window = made4[0]
	_camp_window.name = "CampWindow"
	_camp_window.position = Vector2(486, 56)
	_camp_window.custom_minimum_size = Vector2(460, 474)
	var camp_col: VBoxContainer = made4[1]
	_tent_grid = GridContainer.new()
	_tent_grid.name = "Tents"
	_tent_grid.columns = 3
	_tent_grid.add_theme_constant_override("h_separation", 6)
	_tent_grid.add_theme_constant_override("v_separation", 6)
	_tent_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	camp_col.add_child(_tent_grid)
	_tent_note = UiKit.label("達成成就解鎖新帳篷（只改變營地外觀）；點一下已解鎖的就會搭起來", 13, UiKit.DIM)
	_tent_note.name = "TentNote"
	_tent_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tent_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tent_note.custom_minimum_size = Vector2(420, 0)
	camp_col.add_child(_tent_note)
	add_child(_camp_window)
	_show_tab("gear")


func _show_tab(key: String) -> void:
	_tab = key
	for k in _tabs:
		UiKit.style_tab(_tabs[k], k == key)
	for w in _gear_windows:
		w.visible = key == "gear"
	_camp_window.visible = key == "camp"
	if key == "camp":
		_fill_tents()


## The tents, in the order they're earned: the one pitched lit, the ones
## earned ready to pitch, the rest with how far along.
func _fill_tents() -> void:
	for c in _tent_grid.get_children():
		_tent_grid.remove_child(c)
		c.queue_free()
	for i in Profile.TENTS.size():
		var card := TentCard.new()
		card.index = i
		card.name = "Tent_%d" % Profile.TENTS[i][0]
		card.custom_minimum_size = TentCard.SIZE
		card.picked.connect(_on_tent)
		_tent_grid.add_child(card)


func _on_tent(i: int) -> void:
	var t: Array = Profile.TENTS[i]
	if Profile.camp_tent == t[0]:
		_tent_note.text = "%s 已經搭在營地了" % t[1]
	elif Profile.pitch_tent(t[0]):
		Sfx.play("ui_open", -6.0)
		_tent_note.text = "搭起了 %s" % t[1]
	else:
		var p := Profile.tent_progress(i)
		_tent_note.text = "%s 還沒解鎖：%s（目前 %s）" % [t[1], t[2], TentCard.amount(t, p[0])]


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	_stats.text = Items.rod_effects(Profile.rod()).replace("、", "　・　")
	if _tent_grid != null:
		for c in _tent_grid.get_children():
			c.queue_redraw()


func actions(source: Dictionary) -> Array:
	var slot: String = Items.def(source.id).get("slot", "")
	var out := []
	match source.from:
		"storage":
			if slot != "":
				out.append(["裝備", {"to": "slot", "slot": slot}, true])
			out.append(["放進背包", {"to": "bag"}])
		"bag":
			if slot != "":
				out.append(["裝備", {"to": "slot", "slot": slot}, true])
			if not Items.def(source.id).get("fixed", false):
				out.append(["放回倉庫", {"to": "storage"}])
		"slot":
			if source.slot != "rod":
				out.append(["卸下", {"to": "storage"}, true])
				out.append(["卸下放進背包", {"to": "bag"}])
	return out


func _on_back() -> void:
	UiKit.page_back(self)


## A tent on the 營地 tab: its picture in a slot (ringed gold when it's the
## one pitched, dimmed while it's locked), its name, and what earns it -
## a bar of how far along until it's earned.
class TentCard extends Control:
	signal picked(index: int)

	const SIZE := Vector2(140, 120)
	var index := 0

	static func amount(t: Array, now: float) -> String:
		match t[3]:
			"log":
				return "%d%%" % floori(now)
			"gold_spent":
				return "%d 金幣" % int(now)
			"legends":
				return "%d 條" % int(now)
		return "%d 次" % int(now)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			picked.emit(index)
			accept_event()

	func _draw() -> void:
		var t: Array = Profile.TENTS[index]
		var p := Profile.tent_progress(index)
		var open: bool = p[0] >= p[1]
		var pitched: bool = Profile.camp_tent == t[0]
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.22, 0.06, 0.5) if pitched else Color(0, 0, 0, 0.35))
		var slot := Rect2(Vector2((size.x - 58.0) / 2.0, 5), Vector2(58, 58))
		UiKit.draw_slot(self, slot, "legend" if pitched else "", pitched, Items.texture("res://assets/sprites/icons/tent_%d.png" % t[0]))
		if not open:
			# Locked: dimmed, a padlock over it.
			draw_rect(slot.grow(-3.0), Color(0, 0, 0, 0.6))
			UiKit.draw_lock(self, slot.get_center())
		UiKit.draw_text(self, Vector2(0, 81), t[1], 15, UiKit.GOLD_BRIGHT if open else UiKit.DIM,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
		var state: String = "使用中" if pitched else ("已解鎖" if open else t[2])
		UiKit.draw_text(self, Vector2(0, 98), state, 12, UiKit.GOLD if pitched else UiKit.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if not open:
			UiKit.draw_bar(self, Rect2(14, 104, size.x - 28, 11), p[0] / maxf(p[1], 1.0), Color(0.85, 0.62, 0.25))
