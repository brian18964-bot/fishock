extends Control

## The shop (from the main screen's 商城). User request: in sections -
## 釣具 (rods and lights), 魚餌 (live baits and lures), 道具, 升級 - each
## thing a card with its picture; tapping one shows what it is (and, for
## sale, how many and where it goes: equip, bag or warehouse).

const TABS := [["gear", "釣具"], ["bait", "魚餌"], ["item", "道具"], ["upgrade", "升級"]]
const UPGRADE_ICONS := {
	"fuel_capacity": "res://assets/sprites/items/oil_lamp.png",
	"bait_capacity": "res://assets/sprites/lure/worm_55deg_albedo.png",
	"flash_cooldown": "res://assets/sprites/items/flashlight.png",
	"fuel_station_charges": "res://assets/sprites/gas_can/gas_can_55deg_albedo.png",
	"rod_distance": "res://assets/sprites/items/rod_2.png",
	"reel_power": "res://assets/sprites/items/rod_4.png",
}
const UPGRADE_DESC := {
	"fuel_capacity": "提燈能裝更多燃料",
	"bait_capacity": "每輪開局多帶 5 份基礎餌料",
	"flash_cooldown": "閃光技能冷卻縮短 0.5 秒",
	"fuel_station_charges": "地圖上煤油站的總存量增加",
	"rod_distance": "拋竿拋得更遠",
	"reel_power": "收線時魚的體力掉得更快",
}
const CARD := Vector2(218, 112)

var _tab := "gear"
var _tabs := {}
var _grid: GridContainer
var _gold: Label


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_show_tab("gear")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := MenuStyle.button("‹ 返回", 16)
	back.name = "BackButton"
	back.position = Vector2(16, 12)
	back.custom_minimum_size = Vector2(96, 40)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	var title := MenuStyle.label("商城", 26, MenuStyle.GOLD)
	title.position = Vector2(130, 14)
	add_child(title)
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 12)
	purse.custom_minimum_size = Vector2(140, 0)
	_gold = MenuStyle.label("", 18, MenuStyle.GOLD)
	purse.add_child(_gold)
	add_child(purse)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(16, 62)
	tabs.add_theme_constant_override("separation", 8)
	for t in TABS:
		var b := MenuStyle.button(t[1], 16)
		b.name = "Tab_" + t[0]
		b.custom_minimum_size = Vector2(110, 40)
		var key: String = t[0]
		b.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b)
		_tabs[key] = b
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 112)
	scroll.size = Vector2(928, 418)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	add_child(scroll)


func _show_tab(key: String) -> void:
	_tab = key
	for k in _tabs:
		var on: bool = k == key
		(_tabs[k] as Button).add_theme_stylebox_override("normal", MenuStyle.box(Color(0.3, 0.2, 0.08, 0.95) if on
			else Color(0.1, 0.095, 0.09, 0.9), MenuStyle.GOLD if on else MenuStyle.EDGE, 12, 2 if on else 1))
	_refresh()


func _refresh() -> void:
	_gold.text = "金幣  %d" % Profile.gold
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	match _tab:
		"gear":
			for t in Profile.ROD_TIERS.size():
				var r: Dictionary = Profile.ROD_TIERS[t]
				var id: String = "rod_%d" % t
				if t <= Profile.rods_owned:
					_card(id, Items.icon(id), r.name, "擁有" + ("・使用中" if t == Profile.rod_tier else ""),
						func(): buy_dialog(id, 0, "已經擁有了（到裝備頁或倉庫換上）"))
				elif t == Profile.rods_owned + 1:
					_card(id, Items.icon(id), r.name, "%d 金幣" % r.cost, func(): buy_dialog(id, int(r.cost)), true)
				else:
					_card(id, Items.icon(id), r.name, "%d 金幣・先買前一支" % r.cost,
						func(): buy_dialog(id, int(r.cost), "要先買前一支釣竿（%s）" % Profile.ROD_TIERS[t - 1].name))
			_card("lamp", load("res://assets/sprites/items/oil_lamp.png"), "煤燈", "隨身・免費", func(): _lamp_card())
			if Profile.owned("flashlight") > 0:
				_card("flashlight", Items.icon("flashlight"), "手電筒", "擁有",
					func(): buy_dialog("flashlight", 0, "已經擁有了"))
			else:
				_card("flashlight", Items.icon("flashlight"), "手電筒", "%d 金幣" % Profile.FLASHLIGHT_COST,
					func(): buy_dialog("flashlight", Profile.FLASHLIGHT_COST), true)
		"bait":
			for key in Profile.LIVE_ORDER:
				var lb: Dictionary = Profile.LIVE_BAITS[key]
				var id: String = "live_" + key
				_card(id, Items.icon(id), lb.name, "%d 金幣・擁有 %d" % [lb.cost, Profile.owned(id)],
					func(): buy_dialog(id, int(lb.cost)), true)
			for key in Profile.LURE_ORDER:
				var l: Dictionary = Profile.LURES[key]
				var id: String = "lure_" + key
				_card(id, Items.icon(id), l.name, "%d 金幣・擁有 %d" % [l.cost, Profile.owned(id)],
					func(): buy_dialog(id, int(l.cost)), true)
		"item":
			_card("battery", Items.icon("battery"), "電池", "%d 金幣・擁有 %d" % [Profile.BATTERY_COST, Profile.owned("battery")],
				func(): buy_dialog("battery", Profile.BATTERY_COST), true)
		"upgrade":
			for key in Profile.UPGRADE_DEFS:
				var d: Dictionary = Profile.UPGRADE_DEFS[key]
				var lv: int = Profile.get_upgrade_level(key)
				var maxed: bool = lv >= int(d.max_level)
				_card("up_" + key, load(UPGRADE_ICONS[key]), d.label,
					"Lv.%d/%d・%s" % [lv, d.max_level, "已滿級" if maxed else "%d 金幣" % d.costs[lv]],
					func(): _upgrade_dialog(key), not maxed)


## A card: the picture, the name, the price or state.
func _card(id: String, tex: Texture2D, title: String, sub: String, open: Callable, for_sale := false) -> void:
	var b := Button.new()
	b.name = "Card_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD
	var edge := MenuStyle.GOLD if for_sale else MenuStyle.EDGE
	b.add_theme_stylebox_override("normal", MenuStyle.box(Color(0.1, 0.095, 0.09, 0.92), Color(edge, 0.7), 10, 1))
	b.add_theme_stylebox_override("hover", MenuStyle.box(Color(0.16, 0.13, 0.1, 0.95), edge, 10, 2))
	b.add_theme_stylebox_override("pressed", MenuStyle.box(Color(0.2, 0.15, 0.1, 0.95), edge, 10, 2))
	b.pressed.connect(open)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(84, 0)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := MenuStyle.label(title, 16)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name_label)
	var sub_label := MenuStyle.label(sub, 12, MenuStyle.GOLD if for_sale else MenuStyle.DIM)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(sub_label)
	row.add_child(words)
	b.add_child(row)
	_grid.add_child(b)


func _lamp_card() -> void:
	MenuStyle.notice(self, "煤燈", ["隨身的提燈，照亮身邊一圈。燃料在地圖上的煤油站補充，"
		+ "燃料剩 30% 以下亮度會自己慢慢變暗。升級「提燈燃油容量」能裝更多燃料。"])


func _upgrade_dialog(key: String) -> void:
	var d: Dictionary = Profile.UPGRADE_DEFS[key]
	var lv: int = Profile.get_upgrade_level(key)
	var note := ["%s（Lv.%d/%d）" % [UPGRADE_DESC[key], lv, d.max_level]]
	if lv >= int(d.max_level):
		note.append("已經升到滿級了")
		MenuStyle.notice(self, d.label, note)
		return
	var cost: int = d.costs[lv]
	note.append("升一級要 %d 金幣（持有 %d）" % [cost, Profile.gold])
	var box := MenuStyle.notice(self, d.label, note)
	var col: VBoxContainer = box.get_child(0).get_child(0)
	var up := MenuStyle.button("升級", 16, true)
	up.name = "Upgrade"
	up.disabled = Profile.gold < cost
	up.pressed.connect(func():
		Profile.buy_upgrade(key)
		box.queue_free())
	col.add_child(up)
	col.move_child(up, col.get_child_count() - 2)


## User request: buying asks where the thing goes - put it on (gear), in
## the bag, or in the warehouse - and, for what stacks, how many.
var _dialog: Control


## The card for a thing in the shop (user request: tapping one shows what
## it is): its picture and what it does; and, when it's for sale and
## affordable, how many and where to (`note` explains when it isn't).
func buy_dialog(id: String, cost: int, note := "") -> void:
	if _dialog != null:
		return
	var def := Items.def(id)
	var stackable := Items.stack_of(id) > 1
	var most := mini(20, Profile.gold / maxi(cost, 1)) if stackable else (1 if Profile.gold >= cost else 0)
	var can_buy := note == "" and most >= 1
	if note == "" and most < 1:
		note = "金幣不夠（要 %d，持有 %d）" % [cost, Profile.gold]
	var shade := ColorRect.new()
	shade.name = "BuyDialog"
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_dialog = shade
	var panel := MenuStyle.panel(Color(0.08, 0.075, 0.07, 0.97))
	panel.custom_minimum_size = Vector2(420, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var pic := TextureRect.new()
	pic.texture = Items.icon(id)
	pic.custom_minimum_size = Vector2(96, 56)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.add_child(MenuStyle.label(def.get("name", id), 20, MenuStyle.GOLD))
	var desc := MenuStyle.label(def.get("desc", ""), 13, MenuStyle.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 280
	words.add_child(desc)
	head.add_child(words)
	col.add_child(head)
	if not can_buy:
		col.add_child(MenuStyle.label(note, 14, Color(1.0, 0.7, 0.5)))
		var ok := MenuStyle.button("關閉", 15)
		ok.custom_minimum_size = Vector2(90, 40)
		ok.size_flags_horizontal = Control.SIZE_SHRINK_END
		ok.pressed.connect(_close_dialog)
		col.add_child(ok)
		panel.add_child(col)
		shade.add_child(panel)
		panel.reset_size()
		panel.position = (size - panel.size) / 2.0
		return
	var amount := [1]
	var total := MenuStyle.label("", 16, MenuStyle.GOLD)
	var show_total := func(): total.text = "共 %d 金幣（持有 %d）" % [cost * amount[0], Profile.gold]
	if stackable and most > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(MenuStyle.label("數量", 15, MenuStyle.DIM))
		var slider := HSlider.new()
		slider.name = "Amount"
		slider.min_value = 1
		slider.max_value = most
		slider.step = 1
		slider.value = 1
		slider.custom_minimum_size = Vector2(170, 30)
		var shown := MenuStyle.label("1", 18, MenuStyle.GOLD)
		shown.custom_minimum_size.x = 30
		slider.value_changed.connect(func(v):
			amount[0] = int(v)
			shown.text = str(int(v))
			show_total.call())
		var less := MenuStyle.button("－", 18)
		less.pressed.connect(func(): slider.value -= 1)
		var more := MenuStyle.button("＋", 18)
		more.pressed.connect(func(): slider.value += 1)
		for c in [less, slider, more, shown]:
			row.add_child(c)
		col.add_child(row)
	show_total.call()
	col.add_child(total)
	col.add_child(MenuStyle.label("買了要放到哪裡？", 14, MenuStyle.TEXT))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	var places := []
	if def.get("slot", "") != "":
		places.append(["裝備", "equip"])
	places.append(["放進背包", "bag"])
	places.append(["放進倉庫", "storage"])
	for p in places:
		var b := MenuStyle.button(p[0], 15, p[1] == places[0][1])
		b.name = "To_" + p[1]
		b.custom_minimum_size = Vector2(96, 42)
		var where: String = p[1]
		b.pressed.connect(func():
			_close_dialog()
			buy(id, amount[0], where))
		acts.add_child(b)
	var cancel := MenuStyle.button("取消", 15)
	cancel.custom_minimum_size = Vector2(70, 42)
	cancel.pressed.connect(_close_dialog)
	acts.add_child(cancel)
	col.add_child(acts)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = (size - panel.size) / 2.0


## Buys `n` of `id` and puts them `where` ("equip", "bag" or "storage").
func buy(id: String, n: int, where: String) -> int:
	var bought := 0
	for i in n:
		var ok := false
		if id.begins_with("lure_"):
			ok = Profile.buy_lure(id.substr(5))
		elif id.begins_with("live_"):
			ok = Profile.buy_live_bait(id.substr(5))
		elif id == "battery":
			ok = Profile.buy_battery()
		elif id == "flashlight":
			ok = Profile.buy_flashlight()
		elif id.begins_with("rod_"):
			ok = Profile.buy_rod()
		if not ok:
			break
		bought += 1
	if bought == 0:
		return 0
	var note := ""
	match where:
		"equip":
			Profile.equip(id)
			note = "已裝備 %s" % Items.name_of(id)
		"bag":
			var packed := Profile.to_bag(id, bought)
			note = "放進背包 %d 個" % packed
			if packed < bought:
				note += "，背包放不下的 %d 個放進倉庫" % (bought - packed)
		_:
			note = "放進倉庫"
	MenuStyle.notice(self, "買好了", ["%s ×%d：%s" % [Items.name_of(id), bought, note]])
	return bought


func _close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
