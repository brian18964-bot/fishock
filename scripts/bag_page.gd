extends ItemBoard

## The camp's bag page (user request: 背包, between 角色 and 魚缸 along every
## page's top, and a button at the home screen's bottom right). What is
## carried on the next run, 7 x 5: drag to rearrange, tap a thing for its card -
## and for what can be used at camp (salt, feed, the needle, the dropper: 使用,
## then the fish at camp to use it on). The potions and eyes are used out in
## the run.

const BAG_CELL := 74.0

var _purse: PanelContainer
var _bag: ItemBoard.BagGrid
var _used: Label
var _homes: Label


func _ready() -> void:
	_purse = UiKit.page_chrome(self, func(): UiKit.page_back(self), "Back", "backpack")
	can_discard = true
	can_use = true
	use_requested.connect(_on_use)

	var made := UiKit.window("背包・帶進下一輪")
	var win: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	win.name = "BagWindow"
	win.position = Vector2(14, 56)
	win.custom_minimum_size = Vector2(Inventory.COLS * BAG_CELL + 40.0, 474)
	_used = UiKit.label("", 14, UiKit.DIM)
	_used.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_used)
	_bag = ItemBoard.BagGrid.new(BAG_CELL)
	_bag.name = "Bag"
	_bag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_bag)
	add_child(win)
	track(_bag)

	var made2 := UiKit.window("使用道具")
	var side: PanelContainer = made2[0]
	var scol: VBoxContainer = made2[1]
	side.name = "UseWindow"
	side.position = Vector2(win.position.x + win.custom_minimum_size.x + 10.0, 56)
	side.custom_minimum_size = Vector2(946.0 - side.position.x, 474)
	for line in ["點背包裡的東西看說明；鹽巴、活力飼料、復活針、洗點滴瓶有「使用」鈕，選一條營地裡的魚用在牠身上",
			"藥水、各種眼睛、望遠鏡要在夜釣時使用", "拖曳可以換位置；放進倉庫的東西不佔包包"]:
		var l := UiKit.label(line, 14, UiKit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = side.custom_minimum_size.x - 40.0
		scol.add_child(l)
	scol.add_child(UiKit.divider(side.custom_minimum_size.x - 40.0))
	_homes = UiKit.label("", 15, UiKit.TEXT)
	_homes.name = "Homes"
	scol.add_child(_homes)
	add_child(side)

	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	var cells := 0
	for e in Profile.bag:
		var sz := Items.size_of(e.id)
		cells += sz.x * sz.y
	for f in Profile.pack_fish:
		var fs: Vector2i = Inventory.fish_item(f).size
		cells += fs.x * fs.y
	_used.text = "%d / %d 格" % [cells, Inventory.COLS * Profile.bag_rows()]
	var n := {"背包": 0, "魚缸": 0, "倉庫": 0, "魚桶": 0}
	for e in Profile.home_fish():
		n[e.where] += 1
	_homes.text = "營地裡的魚\n" + "　".join(n.keys().map(func(k): return "%s %d" % [k, n[k]]))


## 使用 on a fish item: which fish at camp?
func _on_use(id: String) -> void:
	var homes := Profile.home_fish()
	var panel := FishPickPanel.new(Items.name_of(id), id, homes.map(func(h): return h.fish), homes.map(func(h): return h.where))
	panel.z_index = 20
	add_child(panel)
	panel.picked.connect(func(i: int):
		var lines := []
		var why := Profile.use_on_home_fish(id, homes[i].fish, lines)
		var msg := (why if why != "" else "%s：%s%s" % [Items.name_of(id), homes[i].fish.get("name", "魚"), "　" + "、".join(lines) if not lines.is_empty() else ""])
		_say(msg))


## A line over the page that fades (what a use did).
func _say(text: String) -> void:
	var l := UiKit.label(text, 18, UiKit.GOLD_BRIGHT, true, 5)
	l.name = "Toast"
	l.position = Vector2(14, 52)
	l.custom_minimum_size = Vector2(900, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 30
	add_child(l)
	var t := l.create_tween()
	t.tween_interval(2.2)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)
