extends Control

## Title-screen shop. User request (shop linkage): besides the upgrades it
## sells the rod line (Profile.ROD_TIERS - each a higher tension cap) and
## six lures, each with its own effect (Profile.LURES). Two scrolling
## columns: upgrades and rods on the left, lures and lights on the right.

const TITLE_SIZE := 15
const DESC_SIZE := 12
const DESC_COLOR := Color(0.72, 0.74, 0.8)
const HEADER_COLOR := Color(1.0, 0.8, 0.45)
const LABEL_WIDTH := 300.0

@onready var gold_label: Label = $GoldLabel
@onready var left: VBoxContainer = $Scroll/Columns/Left
@onready var right: VBoxContainer = $Scroll/Columns/Right
@onready var back_button: Button = $BackButton


func _ready() -> void:
	_restyle()
	back_button.pressed.connect(_on_back_pressed)
	Profile.gold_updated.connect(_on_profile_changed)
	Profile.profile_changed.connect(_on_profile_changed)
	_refresh_gold()
	_rebuild_rows()


func _on_profile_changed(_arg = null) -> void:
	_refresh_gold()
	_rebuild_rows()


## The main screen's look (MenuStyle): back at the top left, the title
## beside it, gold in a purse at the right, the rows on dark panels.
func _restyle() -> void:
	$Background.color = Color(0.04, 0.045, 0.07)
	var title: Label = $TitleLabel
	title.text = "商城"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector2(130, 14)
	title.size = Vector2(200, 36)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", MenuStyle.GOLD)
	var styled := MenuStyle.button("‹ 返回", 16)
	for s in ["normal", "hover", "pressed"]:
		back_button.add_theme_stylebox_override(s, styled.get_theme_stylebox(s))
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.text = "‹ 返回"
	back_button.position = Vector2(16, 12)
	back_button.size = Vector2(96, 40)
	styled.free()
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 12)
	purse.custom_minimum_size = Vector2(140, 0)
	add_child(purse)
	gold_label.reparent(purse)
	gold_label.modulate = Color.WHITE
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", MenuStyle.GOLD)
	var scroll: ScrollContainer = $Scroll
	scroll.position = Vector2(16, 64)
	scroll.size = Vector2(928, 468)


func _refresh_gold() -> void:
	gold_label.text = "金幣  %d" % Profile.gold


func _rebuild_rows() -> void:
	for column in [left, right]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()

	left.add_child(_header("釣竿"))
	left.add_child(_rod_row())
	left.add_child(_header("升級"))
	for key in Profile.UPGRADE_DEFS.keys():
		left.add_child(_upgrade_row(key))

	right.add_child(_header("路亞假餌（買了放進倉庫，裝進背包才帶得進去）"))
	for id in Profile.LURE_ORDER:
		var def: Dictionary = Profile.LURES[id]
		right.add_child(_row("%s（擁有 %d）｜%d 金幣" % [def.name, Profile.owned("lure_" + id), def.cost],
			def.desc, "購買", Profile.gold < int(def.cost), func(): buy_dialog("lure_" + id, int(def.cost))))
	right.add_child(_header("燈具"))
	var has_light := Profile.owned("flashlight") > 0
	right.add_child(_row("手電筒｜%s" % ("已擁有" if has_light else "%d 金幣" % Profile.FLASHLIGHT_COST),
		"遠距離窄光束，用電池", "購買", has_light or Profile.gold < Profile.FLASHLIGHT_COST,
		func(): buy_dialog("flashlight", Profile.FLASHLIGHT_COST)))
	right.add_child(_row("電池（擁有 %d）｜%d 金幣" % [Profile.owned("battery"), Profile.BATTERY_COST],
		"手電筒沒電時隨地換上", "購買", Profile.gold < Profile.BATTERY_COST, func(): buy_dialog("battery", Profile.BATTERY_COST)))


func _rod_row() -> Control:
	var rod := Profile.rod()
	var next := Profile.next_rod()
	var title := "%s（Lv.%d/%d）｜%s" % [Profile.ROD_TIERS[Profile.rods_owned].name, Profile.rods_owned + 1, Profile.ROD_TIERS.size(),
		"已是最好的竿" if next.is_empty() else "買%s %d 金幣" % [next.name, next.cost]]
	var desc := "現在：" + _rod_effects(rod)
	if not next.is_empty():
		desc += "\n下一支：" + _rod_effects(next)
	return _row(title, desc, "購買", next.is_empty() or Profile.gold < int(next.get("cost", 0)),
		func(): buy_dialog("rod_%d" % (Profile.rods_owned + 1), int(next.cost)))


func _rod_effects(rod: Dictionary) -> String:
	var parts := ["張力上限 x%.2f" % rod.strength]
	if rod.window > 1.0:
		parts.append("揚竿時間 +%d%%" % roundi((rod.window - 1.0) * 100.0))
	if rod.jump < 1.0:
		parts.append("魚跳時硬拉的衝擊 -%d%%" % roundi((1.0 - rod.jump) * 100.0))
	return "、".join(parts)


func _upgrade_row(key: String) -> Control:
	var def: Dictionary = Profile.UPGRADE_DEFS[key]
	var level: int = Profile.get_upgrade_level(key)
	var max_level: int = def.max_level
	var maxed: bool = level >= max_level
	var next_cost: int = 0 if maxed else def.costs[level]
	var title := "%s：Lv.%d/%d｜%s" % [def.label, level, max_level, "已滿級" if maxed else "%d 金幣" % next_cost]
	return _row(title, "", "升級", maxed or Profile.gold < next_cost, func(): Profile.buy_upgrade(key))


func _header(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	label.add_theme_color_override("font_color", HEADER_COLOR)
	return label


func _row(title: String, desc: String, button_text: String, disabled: bool, action: Callable) -> Control:
	var card := MenuStyle.panel(Color(0.09, 0.085, 0.08, 0.9))
	var row := HBoxContainer.new()
	card.add_child(row)
	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	text.add_child(label)
	if desc != "":
		var sub := Label.new()
		sub.text = desc
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
		sub.add_theme_font_size_override("font_size", DESC_SIZE)
		sub.add_theme_color_override("font_color", DESC_COLOR)
		text.add_child(sub)
	row.add_child(text)
	var button := MenuStyle.button(button_text, 15, not disabled)
	button.custom_minimum_size = Vector2(72, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = disabled
	button.pressed.connect(func(): action.call())
	row.add_child(button)
	return card


## User request: buying asks where the thing goes - put it on (gear), in
## the bag, or in the warehouse - and, for what stacks, how many.
var _dialog: Control


func buy_dialog(id: String, cost: int) -> void:
	if _dialog != null:
		return
	var def := Items.def(id)
	var stackable := Items.stack_of(id) > 1
	var most := mini(20, Profile.gold / maxi(cost, 1)) if stackable else 1
	if most < 1:
		return
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
	words.add_child(MenuStyle.label("購買 " + def.get("name", id), 20, MenuStyle.GOLD))
	var desc := MenuStyle.label(def.get("desc", ""), 13, MenuStyle.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 280
	words.add_child(desc)
	head.add_child(words)
	col.add_child(head)
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
