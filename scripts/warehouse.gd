extends ItemBoard

## The warehouse page (from the main screen's 倉庫). User request: the
## warehouse and the character's bag side by side, to sort the bag and
## pick what's taken into the next run. Drag a thing from one to the other
## (or about the bag to rearrange it), or tap it for a card that moves as
## many as you choose. The warehouse has tabs - 裝備, 物品, 釣具, 其他;
## the bag doesn't.
## Dressed as an MMO bank (user request): two iron-and-gold windows, the
## warehouse's tabs along its top, sunken slots ringed by rarity.

## User request (the camp): the backpack leant on the crate opens the bag
## alone (scenes/bag.tscn) - rearranged by dragging, things thrown away
## from their card.
@export var bag_only := false

var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid
var _tabs := {}
var _purse: PanelContainer
var _used: Label


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	_purse = UiKit.page_chrome(self, _on_back)
	can_discard = bag_only
	if bag_only:
		_build_bag(Vector2((960 - 468) / 2.0, 56), "背包", ["拖曳物品可以在背包裡換位置",
			"點一下物品看說明，可以放回倉庫或丟棄", "背包裡的東西會帶進遊戲；釣到的魚、餌料會放進空格"])
		return

	# Left: the warehouse, by tab.
	var made := UiKit.window("倉庫")
	var left: PanelContainer = made[0]
	var lcol: VBoxContainer = made[1]
	left.name = "WarehouseWindow"
	left.position = Vector2(14, 56)
	left.custom_minimum_size = Vector2(454, 474)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for key in Items.TAB_ORDER:
		var b := UiKit.button(Items.TABS[key], 15)
		b.name = "Tab_" + key
		b.custom_minimum_size = Vector2(98, 38)
		b.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b)
		_tabs[key] = b
	lcol.add_child(tabs)
	_storage = ItemBoard.StorageGrid.new(6, 68.0)
	_storage.name = "Storage"
	_storage.custom_minimum_size = Vector2(408, 340)
	_storage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lcol.add_child(_storage)
	var note := UiKit.label("商城買的東西會放在這裡", 13, UiKit.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lcol.add_child(note)
	add_child(left)
	track(_storage)

	# Right: the bag.
	_build_bag(Vector2(478, 56), "背包・帶進下一輪", ["拖曳物品可以在倉庫和背包之間搬，或在背包裡換位置",
		"點一下物品看說明、選數量", "背包裡的東西會帶進遊戲；釣到的魚、餌料會放進空格"])
	_show_tab("gear")


func _build_bag(at: Vector2, title: String, lines: Array) -> void:
	var made2 := UiKit.window(title)
	var right: PanelContainer = made2[0]
	var rcol: VBoxContainer = made2[1]
	right.name = "BagWindow"
	right.position = at
	right.custom_minimum_size = Vector2(468, 474)
	_used = UiKit.label("", 14, UiKit.DIM)
	_used.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rcol.add_child(_used)
	_bag = ItemBoard.BagGrid.new(54.0)
	_bag.name = "Bag"
	_bag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rcol.add_child(_bag)
	rcol.add_child(UiKit.divider(360))
	for line in lines:
		var l := UiKit.label(line, 14, UiKit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 420
		rcol.add_child(l)
	add_child(right)
	track(_bag)


func _show_tab(key: String) -> void:
	if _storage == null:
		return
	_storage.tab = key
	for k in _tabs:
		UiKit.style_tab(_tabs[k], k == key)
	_storage.queue_redraw()


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	var cells := 0
	for e in Profile.bag:
		var sz := Items.size_of(e.id)
		cells += sz.x * sz.y
	_used.text = "%d / %d 格" % [cells, Inventory.COLS * Profile.bag_rows()]
	# Each tab's count on its button.
	for k in _tabs:
		var n := 0
		for id in Profile.storage_ids(k):
			n += Profile.stored(id)
		(_tabs[k] as Button).text = Items.TABS[k] + (" %d" % n if n > 0 else "")


func _on_back() -> void:
	UiKit.page_back(self)
