extends ItemBoard

## The warehouse page (from the main screen's 倉庫). User request: the
## warehouse and the character's bag side by side, to sort the bag and
## pick what's taken into the next run. Drag a thing from one to the other
## (or about the bag to rearrange it), or tap it for a card that moves as
## many as you choose. The warehouse is one list, without tabs.
## Dressed as an MMO bank (user request): two iron-and-gold windows, the
## warehouse's tabs along its top, sunken slots ringed by rarity.

## User request (the camp): the crate and the backpack leant on it both
## open it; a thing in the bag can be thrown away from its card.
## User request: the boxes and the bag's cells bigger (they were hard to
## tap) - the warehouse three big boxes across, scrolled up and down
## (DragScroll; a thing dragged sideways goes to the bag), the bag wider.

## User request: the warehouse has cells like the bag - 2.4 times its - and
## everything takes the room it does in the bag (a rod 3 x 1): its window
## wide as the bag's beside it, scrolled when what's in it runs past.
const CELL := 58.0
const WINDOW_WIDTH := 446.0

var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid
var _purse: PanelContainer
var _used: Label
var _stored: Label


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	_purse = UiKit.page_chrome(self, _on_back, "Back", "warehouse")
	can_discard = true

	# Left: the warehouse.
	var made := UiKit.window("倉庫")
	var left: PanelContainer = made[0]
	var lcol: VBoxContainer = made[1]
	left.name = "WarehouseWindow"
	left.position = Vector2(14, 56)
	left.custom_minimum_size = Vector2(WINDOW_WIDTH, 474)
	_stored = UiKit.label("", 14, UiKit.DIM)
	_stored.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lcol.add_child(_stored)
	var scroll := DragScroll.new()
	scroll.name = "StorageScroll"
	scroll.sideways_free = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(CELL * Profile.STORAGE_COLS + 4.0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_storage = ItemBoard.StorageGrid.new(Profile.STORAGE_COLS, CELL, Profile.STORAGE_ROWS)
	_storage.name = "Storage"
	scroll.add_child(_storage)
	lcol.add_child(scroll)
	add_child(left)
	track(_storage)

	# Right: the bag.
	var made2 := UiKit.window("背包")
	var right: PanelContainer = made2[0]
	var rcol: VBoxContainer = made2[1]
	right.name = "BagWindow"
	right.position = Vector2(14.0 + WINDOW_WIDTH + 8.0, 56)
	right.custom_minimum_size = Vector2(WINDOW_WIDTH, 474)
	_used = UiKit.label("", 14, UiKit.DIM)
	_used.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rcol.add_child(_used)
	_bag = ItemBoard.BagGrid.new(CELL)
	_bag.name = "Bag"
	_bag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rcol.add_child(_bag)
	rcol.add_child(UiKit.divider(380))
	var l := UiKit.label("拖曳物品在倉庫和背包之間搬、或在背包裡換位置；點一下看說明、選數量。上下滑動看倉庫更多", 14, UiKit.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WINDOW_WIDTH - 40.0
	rcol.add_child(l)
	add_child(right)
	track(_bag)


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
	var held := 0
	for st in Profile.storage_stacks():
		var sz := Items.size_of(st.id)
		held += sz.x * sz.y
	_stored.text = "%d / %d 格" % [held, Profile.STORAGE_COLS * Profile.STORAGE_ROWS]


func _on_back() -> void:
	UiKit.page_back(self)
