extends ItemBoard

## The character's equipment page (from the main screen's 裝備). User
## request: the player sees their own character - it'll be dressed up
## later (a paper doll) - so the character stands on the left in 3D
## (CharacterViewer) wearing what's equipped; the slots are beside it:
## 釣竿 and 燈具 now, 帽子, 上衣, 背包 locked until the paper doll comes.
## And (user request) it's tied to the warehouse: its 裝備 tab and the bag
## are on the right - drag a rod or the flashlight onto a slot to put it
## on, off a slot to take it off, or tap one for its card.
## Dressed as an MMO character sheet (user request): the character in a
## framed window, the locked slots down its left side, the rod and the
## light along its foot with their names.

const SLOT_LAYOUT := [
	["hat", "帽子", Rect2(34, 116, 58, 58), true],
	["top", "上衣", Rect2(34, 186, 58, 58), true],
	["pack", "背包", Rect2(34, 256, 58, 58), true],
	["rod", "釣竿", Rect2(40, 452, 206, 58), false],
	["light", "燈具", Rect2(258, 452, 206, 58), false],
]

var _viewer: CharacterViewer
var _purse: PanelContainer
var _stats: Label
var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid


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
	var hint := UiKit.label("把釣竿、手電筒拖到左邊的欄位就能換上；點一下看說明", 13, UiKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(made3[1] as VBoxContainer).add_child(hint)
	add_child(bagwin)
	track(_storage)
	track(_bag)


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	_stats.text = Items.rod_effects(Profile.rod()).replace("、", "　・　")


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
