extends Control

## The character's equipment page (from the main screen's 裝備). User
## request: the player sees their own character - it'll be dressed up
## later (a paper doll) - so the character stands on the left in 3D
## (CharacterViewer) wearing what's equipped, and the slots sit on the
## right: 釣竿, 燈具, 路亞 now; 帽子, 上衣, 背包 locked until the paper
## doll comes. Tapping a slot shows it below the grid; tapping one of the
## rods there shows it in the character's hand (the one bought is the one
## fished with - Profile.rod_tier).

const SLOTS := [
	{"key": "rod", "name": "釣竿"},
	{"key": "light", "name": "燈具"},
	{"key": "lure", "name": "路亞"},
	{"key": "hat", "name": "帽子", "locked": true},
	{"key": "top", "name": "上衣", "locked": true},
	{"key": "pack", "name": "背包", "locked": true},
]
const LURE_ICON := "res://assets/sprites/lure/lure_%d_55deg_albedo.png"
const ROD_ICON := "res://assets/sprites/rod/rod_lvl%d_55deg_albedo.png"

var _viewer: CharacterViewer
var _gold: Label
var _detail: VBoxContainer
var _tiles := {}
var _selected := "rod"


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
	# The character's side: a warm glow behind it.
	var glow := TextureRect.new()
	glow.texture = LightTextureFactory.make_radial_texture(256, 0.6)
	glow.modulate = Color(1.0, 0.7, 0.35, 0.16)
	glow.position = Vector2(-20, 40)
	glow.size = Vector2(480, 480)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	_viewer = CharacterViewer.new()
	_viewer.position = Vector2(0, 50)
	_viewer.size = Vector2(450, 490)
	_viewer.zoom = 1.05
	add_child(_viewer)

	# Top bar: back, title, gold.
	var back := MenuStyle.button("‹ 返回", 16)
	back.name = "Back"
	back.position = Vector2(16, 12)
	back.custom_minimum_size = Vector2(96, 40)
	back.pressed.connect(_on_back)
	add_child(back)
	var title := MenuStyle.label("角色裝備", 26, MenuStyle.GOLD)
	title.position = Vector2(130, 14)
	add_child(title)
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 12)
	purse.custom_minimum_size = Vector2(140, 0)
	_gold = MenuStyle.label("", 18, MenuStyle.GOLD)
	purse.add_child(_gold)
	add_child(purse)

	# Right: the slots, then the one picked.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(470, 70)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for slot in SLOTS:
		var tile := _tile(slot)
		grid.add_child(tile)
		_tiles[slot.key] = tile
	add_child(grid)

	var panel := MenuStyle.panel()
	panel.position = Vector2(470, 296)
	panel.custom_minimum_size = Vector2(474, 228)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	panel.add_child(_detail)
	add_child(panel)

	var hint := MenuStyle.label("拖曳角色可以轉動", 12, Color(1, 1, 1, 0.4))
	hint.position = Vector2(170, 512)
	add_child(hint)


## A slot tile: its name and what's in it (filled in by _refresh).
func _tile(slot: Dictionary) -> Button:
	var b := MenuStyle.button("", 15)
	b.name = "Slot_" + slot.key
	b.custom_minimum_size = Vector2(151, 100)
	b.pressed.connect(func(): _select(slot.key))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	var head := MenuStyle.label(slot.name, 13, MenuStyle.DIM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(0, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var what := MenuStyle.label("", 14)
	what.name = "What"
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(what)
	b.add_child(col)
	if slot.get("locked", false):
		b.modulate = Color(1, 1, 1, 0.55)
	return b


func _select(key: String) -> void:
	_selected = key
	_refresh()


func _refresh() -> void:
	_gold.text = "金幣  %d" % Profile.gold
	for slot in SLOTS:
		var tile: Button = _tiles[slot.key]
		var what: Label = tile.find_child("What", true, false)
		var icon: TextureRect = tile.find_child("Icon", true, false)
		match slot.key:
			"rod":
				what.text = Profile.rod().name
				icon.texture = _rod_icon()
			"light":
				what.text = "煤燈＋手電筒" if Profile.has_flashlight else "煤燈"
				icon.texture = LightTextureFactory.make_radial_texture(64, 0.5)
				icon.modulate = Color(1.0, 0.8, 0.45)
			"lure":
				var n := Profile.loadout_lure_total()
				what.text = "%d 個" % n if n > 0 else "沒帶"
				icon.texture = load(LURE_ICON % 1)
			_:
				what.text = "即將推出"
		var on: bool = slot.key == _selected
		var edge := MenuStyle.GOLD if on else MenuStyle.EDGE
		tile.add_theme_stylebox_override("normal", MenuStyle.box(Color(0.14, 0.12, 0.09, 0.95) if on
			else Color(0.1, 0.095, 0.09, 0.9), edge, 12, 2 if on else 1))
	_show_detail()


func _rod_icon() -> Texture2D:
	return load(ROD_ICON % (Profile.rod_tier + 1))


func _show_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	match _selected:
		"rod":
			_rod_detail()
		"light":
			_light_detail()
		"lure":
			_lure_detail()
		_:
			var slot: Dictionary = SLOTS.filter(func(s): return s.key == _selected)[0]
			_detail.add_child(MenuStyle.label(slot.name, 20, MenuStyle.GOLD))
			var l := MenuStyle.label("紙娃娃系統即將推出：帽子、上衣、背包等外觀會直接穿在左邊的角色身上，"
				+ "可以在商城購買或用釣魚成就解鎖。", 14, MenuStyle.DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 440
			_detail.add_child(l)


func _rod_detail() -> void:
	var rod := Profile.rod()
	_detail.add_child(MenuStyle.label("%s（Lv.%d/%d）" % [rod.name, Profile.rod_tier + 1, Profile.ROD_TIERS.size()],
		20, MenuStyle.GOLD))
	_detail.add_child(MenuStyle.label(_rod_effects(rod), 14, MenuStyle.DIM))
	# The whole rod line: the ones owned can be looked at in hand.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i in Profile.ROD_TIERS.size():
		var tier: Dictionary = Profile.ROD_TIERS[i]
		var owned := i <= Profile.rod_tier
		var b := MenuStyle.button(tier.name if owned else "%s\n%d 金" % [tier.name, tier.cost], 13, i == Profile.rod_tier)
		b.custom_minimum_size = Vector2(84, 52)
		if owned:
			b.pressed.connect(func(): _viewer.equip_rod(i))
		else:
			b.modulate = Color(1, 1, 1, 0.6)
			b.pressed.connect(_on_shop)
		row.add_child(b)
	_detail.add_child(row)
	var next := Profile.next_rod()
	var foot := MenuStyle.label("點已擁有的竿可以拿在手上看看" if next.is_empty()
		else "下一支：%s｜%s" % [next.name, _rod_effects(next)], 12, Color(1, 1, 1, 0.5))
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size.x = 440
	_detail.add_child(foot)
	_detail.add_child(_shop_button("到商城升級"))


func _rod_effects(rod: Dictionary) -> String:
	var parts := ["張力上限 x%.2f" % rod.strength]
	if rod.window > 1.0:
		parts.append("揚竿時間 +%d%%" % roundi((rod.window - 1.0) * 100.0))
	if rod.jump < 1.0:
		parts.append("魚跳衝擊 -%d%%" % roundi((1.0 - rod.jump) * 100.0))
	return "、".join(parts)


func _light_detail() -> void:
	_detail.add_child(MenuStyle.label("燈具", 20, MenuStyle.GOLD))
	_detail.add_child(_line("煤燈", "隨身提燈，照亮身邊一圈；燃油在加油站補充", true))
	_detail.add_child(_line("手電筒", "遠距離窄光束，用電池（庫存 %d 顆）" % Profile.batteries if Profile.has_flashlight
		else "未擁有｜%d 金幣，遠距離窄光束" % Profile.FLASHLIGHT_COST, Profile.has_flashlight))
	_detail.add_child(_shop_button("到商城購買"))


func _lure_detail() -> void:
	_detail.add_child(MenuStyle.label("路亞假餌（下一輪全部帶去）", 20, MenuStyle.GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for id in Profile.LURE_ORDER:
		var def: Dictionary = Profile.LURES[id]
		var n := int(Profile.lure_stock.get(id, 0))
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(146, 34)
		var icon := TextureRect.new()
		icon.texture = load(LURE_ICON % (int(def.sprite) + 1))
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)
		cell.add_child(MenuStyle.label("%s ×%d" % [def.name, n], 14, MenuStyle.TEXT if n > 0 else Color(1, 1, 1, 0.4)))
		grid.add_child(cell)
	_detail.add_child(grid)
	_detail.add_child(_shop_button("到商城補貨"))


func _line(title: String, desc: String, owned: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(MenuStyle.label(title + ("" if owned else "（未擁有）"), 16, MenuStyle.TEXT if owned else Color(1, 1, 1, 0.5)))
	col.add_child(MenuStyle.label(desc, 13, MenuStyle.DIM))
	return col


func _shop_button(text: String) -> Button:
	var b := MenuStyle.button(text, 15, true)
	b.name = "ToShop"
	b.custom_minimum_size = Vector2(160, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(_on_shop)
	return b


func _on_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
