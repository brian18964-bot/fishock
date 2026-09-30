extends ItemBoard

## The character's equipment page (from the main screen's 裝備). User
## request: the player sees their own character - it'll be dressed up
## later (a paper doll) - so the character stands on the left in 3D
## (CharacterViewer) wearing what's equipped; the slots are beside it:
## 釣竿 and 燈具 now, 帽子, 上衣, 背包 locked until the paper doll comes.
## And (user request) it's tied to the warehouse: its 裝備 tab and the bag
## are on the right - drag a rod or the flashlight onto a slot to put it
## on, off a slot to take it off, or tap one for its card.

const SLOT_LAYOUT := [
	["rod", "釣竿", Rect2(304, 64, 160, 100), false],
	["light", "燈具", Rect2(304, 172, 160, 84), false],
	["hat", "帽子", Rect2(304, 264, 160, 52), true],
	["top", "上衣", Rect2(304, 322, 160, 52), true],
	["pack", "背包", Rect2(304, 380, 160, 52), true],
]

var _viewer: CharacterViewer
var _gold: Label
var _stats: Label
var _storage: ItemBoard.StorageGrid
var _bag: ItemBoard.BagGrid


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
	var glow := TextureRect.new()
	glow.texture = LightTextureFactory.make_radial_texture(256, 0.6)
	glow.modulate = Color(1.0, 0.7, 0.35, 0.16)
	glow.position = Vector2(-60, 60)
	glow.size = Vector2(420, 420)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	_viewer = CharacterViewer.new()
	_viewer.position = Vector2(0, 56)
	_viewer.size = Vector2(300, 484)
	_viewer.zoom = 0.85
	add_child(_viewer)

	var back := MenuStyle.button("‹ 返回", 16)
	back.name = "Back"
	back.position = Vector2(16, 12)
	back.custom_minimum_size = Vector2(96, 40)
	back.pressed.connect(_on_back)
	add_child(back)
	var title := MenuStyle.label("角色裝備", 26, MenuStyle.GOLD)
	title.position = Vector2(130, 14)
	add_child(title)
	var shop := MenuStyle.button("商城", 15, true)
	shop.name = "ToShop"
	shop.position = Vector2(700, 12)
	shop.custom_minimum_size = Vector2(88, 40)
	shop.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/shop.tscn"))
	add_child(shop)
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 12)
	purse.custom_minimum_size = Vector2(140, 0)
	_gold = MenuStyle.label("", 18, MenuStyle.GOLD)
	purse.add_child(_gold)
	add_child(purse)

	# The slots, beside the character.
	for s in SLOT_LAYOUT:
		var box := ItemBoard.SlotBox.new(s[0], s[1], s[3])
		box.position = s[2].position
		box.size = s[2].size
		add_child(box)
		track(box)
	_stats = MenuStyle.label("", 12, MenuStyle.DIM)
	_stats.position = Vector2(304, 440)
	_stats.custom_minimum_size = Vector2(160, 0)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_stats)

	# Right: the warehouse's 裝備 tab, and the bag.
	var right := MenuStyle.panel()
	right.position = Vector2(476, 64)
	right.custom_minimum_size = Vector2(468, 460)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(MenuStyle.label("倉庫・裝備", 16, MenuStyle.GOLD))
	_storage = ItemBoard.StorageGrid.new(7, 63.0)
	_storage.name = "Storage"
	_storage.tab = "gear"
	_storage.custom_minimum_size = Vector2(441, 126)
	col.add_child(_storage)
	col.add_child(MenuStyle.label("背包", 16, MenuStyle.GOLD))
	_bag = ItemBoard.BagGrid.new(50.0)
	_bag.name = "Bag"
	col.add_child(_bag)
	var hint := MenuStyle.label("把釣竿、手電筒拖到左邊的欄位就能換上；點一下可以看詳情", 12, Color(1, 1, 1, 0.45))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 440
	col.add_child(hint)
	right.add_child(col)
	add_child(right)
	track(_storage)
	track(_bag)


func _refresh() -> void:
	_gold.text = "金幣  %d" % Profile.gold
	var lines := ["%s：%s" % [Profile.rod().name, Items.rod_effects(Profile.rod())]]
	lines.append("燈具：煤燈（隨身）" + ("＋手電筒" if Profile.has_flashlight else ""))
	_stats.text = "\n".join(lines)


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
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
