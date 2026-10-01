extends Control

## The shop (from the main screen's 商城). User request: in sections -
## 釣具 (rods and lights), 魚餌 (live baits and lures), 道具, 升級 - each
## thing a card with its picture; tapping one shows what it is (and, for
## sale, how many and where it goes: equip, bag or warehouse).
## Dressed as an MMO vendor (user request): the vendor's window on the left
## - its sections as tabs, the wares two to a row, each name in its
## rarity's colour with its price - and the chosen thing's tooltip on the
## right with the buying (how many, where to) under it.

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
	"fuel_station_charges": "營地油桶能存更多燃油（營火燒得更久）",
	"rod_distance": "拋竿拋得更遠",
	"reel_power": "收線時魚的體力掉得更快",
}
const LAMP_ICON := "res://assets/sprites/items/oil_lamp.png"
const CARD := Vector2(262, 62)

var _tab := "gear"
var _tabs := {}
var _grid: GridContainer
var _purse: PanelContainer
## The right-hand pane: the chosen thing's tooltip and the buying.
var _pane: VBoxContainer
var _selected := ""
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_show_tab("gear")


func _build() -> void:
	_purse = UiKit.page_chrome(self, _on_back_pressed, "BackButton")
	var made := UiKit.window("漁具商人")
	var vendor: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	vendor.name = "VendorWindow"
	vendor.position = Vector2(14, 56)
	vendor.custom_minimum_size = Vector2(566, 474)
	vendor.size = vendor.custom_minimum_size
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in TABS:
		var b := UiKit.button(t[1], 16)
		b.name = "Tab_" + t[0]
		b.custom_minimum_size = Vector2(118, 40)
		var key: String = t[0]
		b.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b)
		_tabs[key] = b
	col.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(530, 364)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	col.add_child(scroll)
	add_child(vendor)

	var detail := UiKit.tooltip_panel()
	detail.name = "Detail"
	detail.position = Vector2(590, 56)
	detail.custom_minimum_size = Vector2(356, 474)
	detail.size = detail.custom_minimum_size
	_pane = VBoxContainer.new()
	_pane.add_theme_constant_override("separation", 6)
	detail.add_child(_pane)
	add_child(detail)

	_toast = UiKit.label("", 17, UiKit.GOLD_BRIGHT, true, 5)
	_toast.position = Vector2(180, 16)
	_toast.custom_minimum_size = Vector2(520, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _show_tab(key: String) -> void:
	_tab = key
	for k in _tabs:
		UiKit.style_tab(_tabs[k], k == key)
	_selected = ""
	_refresh()
	# The first thing on the tab, shown.
	var first := _grid.get_child(0) if _grid.get_child_count() > 0 else null
	if first != null:
		(first as Button).pressed.emit()


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	match _tab:
		"gear":
			for t in Profile.ROD_TIERS.size():
				var r: Dictionary = Profile.ROD_TIERS[t]
				var id: String = "rod_%d" % t
				if t <= Profile.rods_owned:
					_card(id, Items.icon(id), r.name, "使用中" if t == Profile.rod_tier else "已擁有", 0,
						func(): buy_dialog(id, 0, "已經擁有了（到裝備頁或倉庫換上）"))
				elif t == Profile.rods_owned + 1:
					_card(id, Items.icon(id), r.name, "", int(r.cost), func(): buy_dialog(id, int(r.cost)))
				else:
					_card(id, Items.icon(id), r.name, "先買前一支", int(r.cost),
						func(): buy_dialog(id, int(r.cost), "要先買前一支釣竿（%s）" % Profile.ROD_TIERS[t - 1].name))
			_card("lamp", load(LAMP_ICON), "煤燈", "隨身・免費", 0, func(): _lamp_card())
			if Profile.owned("flashlight") > 0:
				_card("flashlight", Items.icon("flashlight"), "手電筒", "已擁有", 0,
					func(): buy_dialog("flashlight", 0, "已經擁有了"))
			else:
				_card("flashlight", Items.icon("flashlight"), "手電筒", "", Profile.FLASHLIGHT_COST,
					func(): buy_dialog("flashlight", Profile.FLASHLIGHT_COST))
		"bait":
			for key in Profile.LIVE_ORDER:
				var lb: Dictionary = Profile.LIVE_BAITS[key]
				var id: String = "live_" + key
				_card(id, Items.icon(id), lb.name, "擁有 %d" % Profile.owned(id), int(lb.cost),
					func(): buy_dialog(id, int(lb.cost)))
			for key in Profile.LURE_ORDER:
				var l: Dictionary = Profile.LURES[key]
				var id: String = "lure_" + key
				_card(id, Items.icon(id), l.name, "擁有 %d" % Profile.owned(id), int(l.cost),
					func(): buy_dialog(id, int(l.cost)))
		"item":
			_card("battery", Items.icon("battery"), "電池", "擁有 %d" % Profile.owned("battery"), Profile.BATTERY_COST,
				func(): buy_dialog("battery", Profile.BATTERY_COST))
			for key in Profile.SNACK_ORDER:
				var sn: Dictionary = Profile.SNACKS[key]
				_card(key, Items.icon(key), sn.name, "精神 +%d" % int(sn.spirit), int(sn.cost), func(): _snack_card(key))
		"upgrade":
			for key in Profile.UPGRADE_DEFS:
				var d: Dictionary = Profile.UPGRADE_DEFS[key]
				var lv: int = Profile.get_upgrade_level(key)
				var maxed: bool = lv >= int(d.max_level)
				_card("up_" + key, load(UPGRADE_ICONS[key]), d.label, "Lv.%d/%d%s" % [lv, d.max_level, "・已滿級" if maxed else ""],
					0 if maxed else int(d.costs[lv]), func(): _upgrade_dialog(key))


## A ware: its picture in a slot, its name in its rarity's colour, and its
## price (or state) under it. Picking it shows it on the right.
func _card(id: String, tex: Texture2D, title: String, sub: String, price: int, open: Callable) -> void:
	var b := Button.new()
	b.name = "Card_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var chosen := id == _selected
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.3, 0.22, 0.06, 0.55) if chosen else Color(0, 0, 0, 0.35)
	box.border_color = UiKit.GOLD if chosen else Color(0.3, 0.28, 0.25, 0.8)
	box.set_border_width_all(2 if chosen else 1)
	box.set_corner_radius_all(4)
	var hover := box.duplicate()
	hover.bg_color = Color(0.22, 0.17, 0.08, 0.6)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func():
		_selected = id
		_mark_selected()
		open.call())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var pic := WareIcon.new()
	pic.id = id
	pic.texture = tex
	pic.custom_minimum_size = Vector2(52, 52)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.add_child(UiKit.label(title, 17, UiKit.rarity_color(_rarity(id)), true))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if price > 0:
		var g := UiKit.gold_label(price, 15)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.add_child(g)
	if sub != "":
		bottom.add_child(UiKit.label(sub, 13, UiKit.DIM))
	words.add_child(bottom)
	row.add_child(words)
	b.add_child(row)
	_grid.add_child(b)


func _rarity(id: String) -> String:
	if id.begins_with("up_") or id == "lamp":
		return "common"
	return UiKit.item_rarity(id)


func _mark_selected() -> void:
	for c in _grid.get_children():
		var on: bool = c.name == "Card_" + _selected
		var box: StyleBoxFlat = (c as Button).get_theme_stylebox("normal")
		box.bg_color = Color(0.3, 0.22, 0.06, 0.55) if on else Color(0, 0, 0, 0.35)
		box.border_color = UiKit.GOLD if on else Color(0.3, 0.28, 0.25, 0.8)
		box.set_border_width_all(2 if on else 1)
		(c as Button).queue_redraw()


## Empties the right-hand pane (at once - its old buttons mustn't linger).
func _clear_pane() -> void:
	for c in _pane.get_children():
		_pane.remove_child(c)
		c.queue_free()


## The top of the pane: the thing's picture, name (rarity colour), what
## kind of thing, then its lines.
func _head(tex: Texture2D, title: String, rarity: String, kind: String, lines: Array) -> void:
	# User request (3D out of the game): the thing itself, turning, when
	# there's a model of it.
	if Items.model_path(_selected) != "":
		var stage := Control.new()
		stage.name = "Stage"
		stage.custom_minimum_size = Vector2(330, 150)
		var pv := ItemPreview.new()
		pv.name = "Preview"
		pv.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.add_child(pv)
		# User request (show the gear on the character): what's held can be
		# tried on - the character holding it, in 3D.
		if _selected.begins_with("rod_") or _selected in ["flashlight", "lamp"]:
			var tb := UiKit.button("試穿", 13)
			tb.name = "TryOn"
			tb.toggle_mode = true
			tb.custom_minimum_size = Vector2(58, 30)
			tb.position = Vector2(330 - 62, 2)
			var id := _selected
			tb.toggled.connect(func(on): _try_on(stage, pv, id, on))
			stage.add_child(tb)
		_pane.add_child(stage)
		pv.show_item(_selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var pic := WareIcon.new()
	pic.id = _selected
	pic.texture = tex
	pic.custom_minimum_size = Vector2(76, 76)
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	var name_label := UiKit.label(title, 22, UiKit.rarity_color(rarity), true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 230
	words.add_child(name_label)
	words.add_child(UiKit.label(kind, 14, UiKit.rarity_color(rarity)))
	head.add_child(words)
	_pane.add_child(head)
	_pane.add_child(UiKit.divider(300))
	for line in lines:
		var l := UiKit.label(line[0], 15, line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 320
		_pane.add_child(l)


## The character holding `id` (a rod, the flashlight, the lamp) in place of
## the thing turning on its own; off puts the thing back.
func _try_on(stage: Control, preview: ItemPreview, id: String, on: bool) -> void:
	var old := stage.get_node_or_null("TryOnView")
	if old != null:
		old.queue_free()
	preview.visible = not on
	if not on:
		return
	var view := CharacterViewer.new()
	view.name = "TryOnView"
	view.zoom = 2.1
	view.look_height = 1.15
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(view)
	stage.move_child(view, 1)
	view.rig.follow_profile = false
	if id.begins_with("rod_"):
		view.rig.equip_rod(int(id.substr(4)))
	elif id == "flashlight":
		view.rig.equip_flashlight()


func _lamp_card() -> void:
	_clear_pane()
	_head(load(LAMP_ICON), "煤燈", "common", "普通 燈具", [
		["隨身的提燈，照亮身邊一圈。", UiKit.TEXT],
		["使用：燃料回營地的油桶補充，剩 30% 以下亮度會慢慢變暗。", UiKit.USE],
		["升級「提燈燃油容量」能裝更多燃料。", UiKit.DIM]])


## User request (Camp v2): the merchant's tea and rations - had there and
## then, for spirit.
func _snack_card(key: String) -> void:
	_clear_pane()
	var sn: Dictionary = Profile.SNACKS[key]
	_head(Items.icon(key), sn.name, "common", "普通 補給", [
		[sn.desc, UiKit.TEXT],
		["使用：買了當場享用，精神 +%d" % int(sn.spirit), UiKit.USE],
		["目前精神 %d / %d" % [roundi(Profile.spirit), int(Profile.SPIRIT_MAX)], UiKit.DIM]])
	var price := HBoxContainer.new()
	price.add_child(UiKit.label("價格：", 15, UiKit.TEXT))
	price.add_child(UiKit.gold_label(int(sn.cost), 15))
	_pane.add_child(price)
	_spacer()
	if Profile.spirit >= Profile.SPIRIT_MAX:
		_pane.add_child(UiKit.label("精神飽滿，現在不需要", 15, UiKit.DIM))
		return
	if Profile.gold < int(sn.cost):
		_pane.add_child(UiKit.label("金幣不夠（要 %d，持有 %d）" % [sn.cost, Profile.gold], 15, Color(1.0, 0.7, 0.5)))
		return
	var b := UiKit.button("買下享用", 17, "red")
	b.name = "Have"
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func():
		if Profile.buy_snack(key):
			Sfx.play("coins", -4.0)
			_show_toast("%s：精神 %d / %d" % [sn.name, roundi(Profile.spirit), int(Profile.SPIRIT_MAX)])
		_reselect(key))
	_pane.add_child(b)


func _upgrade_dialog(key: String) -> void:
	_clear_pane()
	var d: Dictionary = Profile.UPGRADE_DEFS[key]
	var lv: int = Profile.get_upgrade_level(key)
	var lines := [["使用：" + UPGRADE_DESC[key], UiKit.USE], ["目前等級 Lv.%d / %d" % [lv, d.max_level], UiKit.TEXT]]
	_head(load(UPGRADE_ICONS[key]), d.label, "common", "升級", lines)
	if lv >= int(d.max_level):
		_pane.add_child(UiKit.label("已經升到滿級了", 16, UiKit.GOLD))
		return
	var cost: int = d.costs[lv]
	var price := HBoxContainer.new()
	price.add_child(UiKit.label("升一級：", 16, UiKit.TEXT))
	price.add_child(UiKit.gold_label(cost, 16))
	_pane.add_child(price)
	_spacer()
	var up := UiKit.button("升級", 18, "red")
	up.name = "Upgrade"
	up.custom_minimum_size = Vector2(0, 48)
	up.disabled = Profile.gold < cost
	up.pressed.connect(func():
		Profile.buy_upgrade(key)
		Sfx.play("coins", -4.0)
		_show_toast("%s 升到 Lv.%d" % [d.label, Profile.get_upgrade_level(key)])
		_upgrade_dialog(key))
	_pane.add_child(up)


func _spacer() -> void:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane.add_child(s)


## User request: buying asks where the thing goes - put it on (gear), in
## the bag, or in the warehouse - and, for what stacks, how many.
var _dialog: Control


## Shows a thing on the right (user request: tapping one shows what it
## is): its tooltip; and, when it's for sale and affordable, how many and
## where to (`note` explains when it isn't).
func buy_dialog(id: String, cost: int, note := "") -> void:
	_clear_pane()
	_selected = id
	_dialog = _pane
	var def := Items.def(id)
	var rarity := UiKit.item_rarity(id)
	var stackable := Items.stack_of(id) > 1
	var most := mini(20, Profile.gold / maxi(cost, 1)) if stackable else (1 if Profile.gold >= cost else 0)
	var can_buy := note == "" and most >= 1
	if note == "" and most < 1:
		note = "金幣不夠（要 %d，持有 %d）" % [cost, Profile.gold]
	var kind := "%s %s" % [UiKit.rarity_name(rarity), Items.TABS.get(def.get("tab", ""), "")]
	_head(Items.icon(id), def.get("name", id), rarity, kind, ItemBoard.desc_lines(id))
	if cost > 0:
		var price := HBoxContainer.new()
		price.add_child(UiKit.label("價格：", 15, UiKit.TEXT))
		price.add_child(UiKit.gold_label(cost, 15))
		if stackable:
			price.add_child(UiKit.label("（擁有 %d）" % Profile.owned(id), 14, UiKit.DIM))
		_pane.add_child(price)
	_spacer()
	if not can_buy:
		_pane.add_child(UiKit.label(note, 15, Color(1.0, 0.7, 0.5)))
		return
	var amount := [1]
	var total := UiKit.label("", 16, UiKit.GOLD_BRIGHT)
	var show_total := func(): total.text = "共 %d 金幣（持有 %d）" % [cost * amount[0], Profile.gold]
	if stackable and most > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UiKit.label("數量", 15, UiKit.DIM))
		var slider := HSlider.new()
		slider.name = "Amount"
		slider.min_value = 1
		slider.max_value = most
		slider.step = 1
		slider.value = 1
		slider.custom_minimum_size = Vector2(150, 30)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var shown := UiKit.label("1", 18, UiKit.GOLD_BRIGHT)
		shown.custom_minimum_size.x = 28
		slider.value_changed.connect(func(v):
			amount[0] = int(v)
			shown.text = str(int(v))
			show_total.call())
		var less := UiKit.button("－", 18)
		less.custom_minimum_size = Vector2(40, 38)
		less.pressed.connect(func(): slider.value -= 1)
		var more := UiKit.button("＋", 18)
		more.custom_minimum_size = Vector2(40, 38)
		more.pressed.connect(func(): slider.value += 1)
		for c in [less, slider, more, shown]:
			row.add_child(c)
		_pane.add_child(row)
	show_total.call()
	_pane.add_child(total)
	_pane.add_child(UiKit.label("買了要放到哪裡？", 15, UiKit.TEXT))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	var places := []
	if def.get("slot", "") != "":
		places.append(["直接裝備", "equip"])
	places.append(["放進背包", "bag"])
	places.append(["放進倉庫", "storage"])
	for p in places:
		var b := UiKit.button(p[0], 15, "red")
		b.name = "To_" + p[1]
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var where: String = p[1]
		b.pressed.connect(func():
			buy(id, amount[0], where)
			_reselect(id))
		acts.add_child(b)
	_pane.add_child(acts)


## After buying: the wares again (prices, counts, what's owned) and the
## same thing shown.
func _reselect(id: String) -> void:
	_refresh()
	var card: Button = _grid.get_node_or_null("Card_" + id)
	if card != null:
		card.pressed.emit()


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
	Sfx.play("coins", -4.0)
	var note := ""
	match where:
		"equip":
			Profile.equip(id)
			note = "已裝備"
		"bag":
			var packed := Profile.to_bag(id, bought)
			note = "放進背包 %d 個" % packed
			if packed < bought:
				note += "，放不下的 %d 個放進倉庫" % (bought - packed)
		_:
			note = "放進倉庫"
	_show_toast("購得 %s ×%d：%s" % [Items.name_of(id), bought, note])
	return bought


## A line along the top that fades (an MMO's "you receive" message).
func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _close_dialog() -> void:
	_clear_pane()
	_dialog = null


func _on_back_pressed() -> void:
	UiKit.page_back(self)


## A ware's picture in a slot, ringed by its rarity.
class WareIcon extends Control:
	var id := ""
	var texture: Texture2D

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rarity := "common" if id.begins_with("up_") or id == "lamp" or id == "" else UiKit.item_rarity(id)
		# Its square icon (the MMO look) where it has one.
		var square := Items.square_icon(id)
		UiKit.draw_slot(self, r, rarity, false, square)
		if texture == null or square != null:
			return
		var room := r.grow(-7.0)
		var long := float(texture.get_width()) / texture.get_height()
		if long > 2.2:
			var diag := room.size.length() * 0.95
			var sz := Vector2(diag, diag / long)
			draw_set_transform(room.get_center(), -atan2(room.size.y, room.size.x))
			draw_texture_rect(texture, Rect2(-sz / 2.0, sz), false)
			draw_set_transform(Vector2.ZERO)
		else:
			var k := minf(room.size.x / texture.get_width(), room.size.y / texture.get_height())
			var sz := Vector2(texture.get_size()) * k
			draw_texture_rect(texture, Rect2(room.get_center() - sz / 2.0, sz), false)
