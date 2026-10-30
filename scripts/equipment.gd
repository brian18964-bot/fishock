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
## User request: the slots and cells bigger (they were hard to tap) - the
## character's window narrower, and on the right one window with two tabs,
## the warehouse's gear (big boxes, scrolled) or the bag.

const CHAR_WIDTH := 450.0
## (the right window: the bag and the warehouse, their cells the page's)
const CELL := 58.0
const STAT_ORDER := ["react", "might", "resil", "endure", "luck"]

const SLOT_LAYOUT := [
	["hat", "帽子", Rect2(32, 106, 66, 66), true],
	["top", "上衣", Rect2(32, 182, 66, 66), true],
	["pack", "背包", Rect2(32, 258, 66, 66), true],
	["rod", "主手・釣竿", Rect2(28, 442, 164, 66), false],
	["light", "燈具", Rect2(272, 442, 164, 66), false],
	# User request: the off hand - a weapon (Profile.WEAPONS) or the
	# landing net, one of them.
	["offhand", "副手", Rect2(200, 442, 66, 66), false],
]

var _viewer: CharacterViewer
var _purse: PanelContainer
var _stats: Label
var _stat_rows: Array = []
var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid
var _tab := "bag"
var _tabs := {}
var _tent_grid: GridContainer
var _tent_scroll: DragScroll
var _hint: Label
var _used: Label
var _storage_scroll: DragScroll


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	_purse = UiKit.page_chrome(self, _on_back, "Back", "character")
	# Left: the character, framed, with a warm glow behind it.
	var made := UiKit.window("釣客")
	var sheet: PanelContainer = made[0]
	sheet.name = "CharacterWindow"
	sheet.position = Vector2(14, 56)
	sheet.custom_minimum_size = Vector2(CHAR_WIDTH, 474)
	add_child(sheet)
	var glow := TextureRect.new()
	glow.texture = UiKit.glow()
	glow.modulate = Color(1.0, 0.62, 0.3, 0.22)
	glow.position = Vector2(100, 100)
	glow.size = Vector2(260, 320)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	_viewer = CharacterViewer.new()
	_viewer.position = Vector2(100, 100)
	_viewer.size = Vector2(260, 320)
	_viewer.zoom = 0.95
	add_child(_viewer)
	for s in SLOT_LAYOUT:
		var box := ItemBoard.SlotBox.new(s[0], s[1], s[3])
		box.position = s[2].position
		box.size = s[2].size
		add_child(box)
		track(box)
	# User request: the character's five stats, each tapped for what it touches.
	var head := UiKit.label("素質", 12, UiKit.GOLD, true)
	head.position = Vector2(362, 110)
	head.custom_minimum_size = Vector2(88, 0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head)
	for i in STAT_ORDER.size():
		var row := StatRow.new()
		row.stat = STAT_ORDER[i]
		row.name = "Stat_" + STAT_ORDER[i]
		row.position = Vector2(362, 130 + 36 * i)
		row.size = Vector2(88, 32)
		row.pressed.connect(_show_stat)
		add_child(row)
		_stat_rows.append(row)
	_stats = UiKit.label("", 14, UiKit.TEXT)
	_stats.position = Vector2(32, 412)
	_stats.custom_minimum_size = Vector2(CHAR_WIDTH - 36.0, 0)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stats)

	# Right: one window - the bag, the warehouse or the camp's tents, by its tabs
	# (user request: to see what could be put on, and the camp's looks).
	var right_x := CHAR_WIDTH + 24.0
	var made2 := UiKit.window("")
	var gear: PanelContainer = made2[0]
	gear.name = "SourceWindow"
	gear.position = Vector2(right_x, 56)
	gear.custom_minimum_size = Vector2(946.0 - right_x, 474)
	var gcol: VBoxContainer = made2[1]
	(gcol.get_node("Title") as Control).visible = false
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 6)
	for t in [["bag", "背包"], ["storage", "倉庫"], ["camp", "營地"]]:
		var tb := UiKit.button(t[1], 16)
		tb.name = "Tab_" + t[0]
		tb.custom_minimum_size = Vector2(110, 38)
		var key: String = t[0]
		tb.pressed.connect(func(): _show_tab(key))
		tab_row.add_child(tb)
		_tabs[key] = tb
	gcol.add_child(tab_row)
	_used = UiKit.label("", 13, UiKit.DIM)
	_used.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gcol.add_child(_used)
	_bag = ItemBoard.BagGrid.new(CELL)
	_bag.name = "Bag"
	_bag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gcol.add_child(_bag)
	_storage_scroll = DragScroll.new()
	_storage_scroll.name = "StorageScroll"
	_storage_scroll.sideways_free = true
	_storage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_storage_scroll.custom_minimum_size = Vector2(CELL * Profile.STORAGE_COLS + 4.0, 0)
	_storage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_storage_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_storage = ItemBoard.StorageGrid.new(Profile.STORAGE_COLS, CELL, Profile.STORAGE_ROWS)
	_storage.name = "Storage"
	_storage_scroll.add_child(_storage)
	gcol.add_child(_storage_scroll)
	# The camp's tents.
	_tent_grid = GridContainer.new()
	_tent_grid.name = "Tents"
	_tent_grid.columns = 3
	_tent_grid.add_theme_constant_override("h_separation", 6)
	_tent_grid.add_theme_constant_override("v_separation", 6)
	_tent_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tent_scroll = DragScroll.new()
	_tent_scroll.name = "TentScroll"
	_tent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tent_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tent_scroll.custom_minimum_size = Vector2(TentCard.SIZE.x * 3.0 + 16.0, 0)
	_tent_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tent_scroll.add_child(_tent_grid)
	gcol.add_child(_tent_scroll)
	_hint = UiKit.label("", 13, UiKit.DIM)
	_hint.name = "TentNote"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(946.0 - right_x - 36.0, 0)
	gcol.add_child(_hint)
	add_child(gear)
	track(_storage)
	track(_bag)
	enable_use()
	_show_tab(str(get_meta("tab", "bag")))


## The right window's tab: the bag, the warehouse, or the camp's tent styles.
func _show_tab(key: String) -> void:
	_tab = key
	for k in _tabs:
		UiKit.style_tab(_tabs[k], k == key)
	_bag.visible = key == "bag"
	_used.visible = key != "camp"
	_storage_scroll.visible = key == "storage"
	_tent_scroll.visible = key == "camp"
	_hint.text = {"bag": "拖到左邊的欄位就能換上；點一下看說明，鹽巴等道具在這裡使用",
		"storage": "把釣竿（主手）、手電筒、武器或撈網（副手）拖到左邊的欄位；點一下看說明",
		"camp": "達成成就解鎖新帳篷（只改變營地外觀）；點一下已解鎖的就會搭起來"}[key]
	if key == "camp":
		_fill_tents()
	_refresh()


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
		_hint.text = "%s 已經搭在營地了" % t[1]
	elif Profile.pitch_tent(t[0]):
		Sfx.play("ui_open", -6.0)
		_hint.text = "搭起了 %s" % t[1]
	else:
		var p := Profile.tent_progress(i)
		_hint.text = "%s 還沒解鎖：%s（目前 %s）" % [t[1], t[2], TentCard.amount(t, p[0])]


## The fish packed in the bag at home that would count on a run (alive, not weak).
func _packed() -> Array:
	return Profile.pack_fish.filter(func(f): return FishLife.stats_count(f))


## A stat's card: its number and where it comes from, and what it touches.
func _show_stat(stat: String) -> void:
	var lines := []
	var parts := []
	for src in Stats.sources(stat, _packed()):
		parts.append("%s %d" % [src[0], src[1]])
	lines.append("總和 %d　＝　%s" % [Stats.total(stat, _packed()), "　＋　".join(parts) if not parts.is_empty() else "0"])
	lines.append(Stats.INFO[stat])
	if stat != Stats.LUCK:
		lines.append("起始素質是這個角色天生的（總和 10 點，依動物特質分配），其他來自釣竿、天賦、裝備，和出發時帶在包包裡的活魚詞綴（虛弱或死掉的不算）。")
	var note := MenuStyle.notice(self, Stats.NAMES[stat], lines)
	note.name = "StatNote"


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	for row in _stat_rows:
		row.value = Stats.total(row.stat, _packed())
		row.queue_redraw()
	_stats.text = Items.rod_effects(Profile.rod()).replace("、", "　・　")
	if _tab == "storage":
		var held := 0
		for st in Profile.storage_stacks():
			var sz := Items.size_of(st.id)
			held += sz.x * sz.y
		_used.text = "倉庫 %d / %d 格" % [held, Profile.STORAGE_COLS * Profile.STORAGE_ROWS]
	else:
		var cells := 0
		for e in Profile.bag:
			var sz := Items.size_of(e.id)
			cells += sz.x * sz.y
		for f in Profile.pack_fish:
			var fs: Vector2i = Inventory.fish_item(f).size
			cells += fs.x * fs.y
		_used.text = "背包 %d / %d 格" % [cells, Inventory.COLS * Profile.bag_rows()]
	if _tent_grid != null:
		for c in _tent_grid.get_children():
			c.queue_redraw()


func actions(source: Dictionary) -> Array:
	var slot: String = Items.def(source.id).get("slot", "")
	var out := []
	if can_use and Profile.USABLES.get(source.id, {}).get("target", "") == "fish":
		out.append(["使用", {"to": "use"}, true])
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


## One stat on the page: its name and number, tapped for its card.
class StatRow extends Control:
	signal pressed(stat: String)

	var stat := ""
	var value := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			pressed.emit(stat)
			accept_event()

	func _draw() -> void:
		var hot := get_global_rect().has_point(get_global_mouse_position())
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.2, 0.08, 0.7) if hot else Color(0, 0, 0, 0.4))
		UiKit.draw_text(self, Vector2(8, 22), Stats.NAMES[stat], 14, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 50.0)
		UiKit.draw_text(self, Vector2(50, 22), str(value), 15, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 58.0)
