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

	right.add_child(_header("路亞假餌（買了下一輪全部帶去）"))
	for id in Profile.LURE_ORDER:
		var def: Dictionary = Profile.LURES[id]
		right.add_child(_row("%s（庫存 %d）｜%d 金幣" % [def.name, int(Profile.lure_stock.get(id, 0)), def.cost],
			def.desc, "購買", Profile.gold < int(def.cost), func(): Profile.buy_lure(id)))
	right.add_child(_header("燈具"))
	right.add_child(_row("手電筒｜%s" % ("已擁有" if Profile.has_flashlight else "%d 金幣" % Profile.FLASHLIGHT_COST),
		"遠距離窄光束，用電池", "購買", Profile.has_flashlight or Profile.gold < Profile.FLASHLIGHT_COST, Profile.buy_flashlight))
	right.add_child(_row("電池（庫存 %d）｜%d 金幣" % [Profile.batteries, Profile.BATTERY_COST],
		"手電筒沒電時隨地換上", "購買", Profile.gold < Profile.BATTERY_COST, Profile.buy_battery))


func _rod_row() -> Control:
	var rod := Profile.rod()
	var next := Profile.next_rod()
	var title := "%s（Lv.%d/%d）｜%s" % [rod.name, Profile.rod_tier + 1, Profile.ROD_TIERS.size(),
		"已是最好的竿" if next.is_empty() else "換%s %d 金幣" % [next.name, next.cost]]
	var desc := "現在：" + _rod_effects(rod)
	if not next.is_empty():
		desc += "\n下一支：" + _rod_effects(next)
	return _row(title, desc, "升級", next.is_empty() or Profile.gold < int(next.get("cost", 0)), Profile.buy_rod)


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


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
