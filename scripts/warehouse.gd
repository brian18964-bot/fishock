extends ItemBoard

## The warehouse page (from the main screen's 倉庫). User request: the
## warehouse and the character's bag side by side, to sort the bag and
## pick what's taken into the next run. Drag a thing from one to the other
## (or about the bag to rearrange it), or tap it for a card that moves as
## many as you choose. The warehouse has tabs - 裝備, 物品, 釣具, 其他;
## the bag doesn't.

var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid
var _tabs := {}
var _gold: Label
var _used: Label


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := MenuStyle.button("‹ 返回", 16)
	back.name = "Back"
	back.position = Vector2(16, 12)
	back.custom_minimum_size = Vector2(96, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	add_child(back)
	var title := MenuStyle.label("倉庫", 26, MenuStyle.GOLD)
	title.position = Vector2(130, 14)
	add_child(title)
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 12)
	purse.custom_minimum_size = Vector2(140, 0)
	_gold = MenuStyle.label("", 18, MenuStyle.GOLD)
	purse.add_child(_gold)
	add_child(purse)

	# Left: the warehouse, by tab.
	var left := MenuStyle.panel()
	left.position = Vector2(16, 64)
	left.custom_minimum_size = Vector2(452, 460)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for key in Items.TAB_ORDER:
		var b := MenuStyle.button(Items.TABS[key], 15)
		b.name = "Tab_" + key
		b.custom_minimum_size = Vector2(100, 38)
		b.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b)
		_tabs[key] = b
	lcol.add_child(tabs)
	_storage = ItemBoard.StorageGrid.new(6, 71.0)
	_storage.name = "Storage"
	_storage.custom_minimum_size = Vector2(426, 355)
	lcol.add_child(_storage)
	lcol.add_child(MenuStyle.label("商城買的東西會放在這裡", 12, Color(1, 1, 1, 0.4)))
	left.add_child(lcol)
	add_child(left)
	track(_storage)

	# Right: the bag.
	var right := MenuStyle.panel()
	right.position = Vector2(480, 64)
	right.custom_minimum_size = Vector2(464, 460)
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_child(MenuStyle.label("背包（帶進下一輪）", 18, MenuStyle.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_used = MenuStyle.label("", 14, MenuStyle.DIM)
	head.add_child(_used)
	rcol.add_child(head)
	_bag = ItemBoard.BagGrid.new(54.0)
	_bag.name = "Bag"
	rcol.add_child(_bag)
	for line in ["拖曳可以在倉庫和背包之間搬，或在背包裡換位置", "點一下物品可以選數量",
			"背包裡的東西會帶進遊戲；釣到的魚、餌料在遊戲中會放進空格"]:
		var l := MenuStyle.label("・" + line, 13, MenuStyle.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 430
		rcol.add_child(l)
	right.add_child(rcol)
	add_child(right)
	track(_bag)
	_show_tab("gear")


func _show_tab(key: String) -> void:
	_storage.tab = key
	for k in _tabs:
		var on: bool = k == key
		var b: Button = _tabs[k]
		b.add_theme_stylebox_override("normal", MenuStyle.box(Color(0.3, 0.2, 0.08, 0.95) if on
			else Color(0.1, 0.095, 0.09, 0.9), MenuStyle.GOLD if on else MenuStyle.EDGE, 12, 2 if on else 1))
	_storage.queue_redraw()


func _refresh() -> void:
	_gold.text = "金幣  %d" % Profile.gold
	var cells := 0
	for e in Profile.bag:
		var sz := Items.size_of(e.id)
		cells += sz.x * sz.y
	_used.text = "%d / %d 格" % [cells, Inventory.COLS * Inventory.ROWS]
	# Each tab's count on its button.
	for k in _tabs:
		var n := 0
		for id in Profile.storage_ids(k):
			n += Profile.stored(id)
		(_tabs[k] as Button).text = Items.TABS[k] + (" %d" % n if n > 0 else "")
