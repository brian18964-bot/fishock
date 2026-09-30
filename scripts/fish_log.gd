extends Control

## The fish log (圖鑑, from the main screen): every species in the game,
## grouped the way they're found - the freshwater ones every style shares,
## each style's own four and its rarest, the sea's - each caught one in
## colour with how many and the best it fetched (Profile.fish_log, filled
## by Profile.record_catch() from Player._succeed_catch()), the rest dark
## shapes with ？？？. Tap a caught one for its card.

const WATER_NAMES := {
	"forest": "森林", "deadwood": "枯木林", "rocky": "岩地", "tropical": "熱帶雨林", "prehistoric": "史前",
	"swamp": "沼澤", "snow": "雪原", "autumn": "秋林", "ruins": "廢墟城市",
}
const TRAIT_NAMES := {"calm": "溫和", "normal": "普通", "wild": "兇猛"}
const HABIT_NAMES := {"cover": "會往障礙物鑽", "jumper": "愛跳出水面"}
const CELL := Vector2(96, 92)

var _rows: VBoxContainer
var _count: Label


func _ready() -> void:
	_build()
	_rebuild_rows()


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
	add_child(_at(MenuStyle.label("魚類圖鑑", 26, MenuStyle.GOLD), Vector2(130, 14)))
	_count = MenuStyle.label("", 16, MenuStyle.DIM)
	add_child(_at(_count, Vector2(760, 22)))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 64)
	scroll.size = Vector2(928, 468)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.name = "RowsContainer"
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	add_child(scroll)


func _at(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c


func _rebuild_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var caught := 0
	for id in FishData.FISH:
		if Profile.fish_log.has(FishData.FISH[id].name):
			caught += 1
	_count.text = "已收集 %d / %d" % [caught, FishData.FISH.size()]

	_section("淡水・各地都有", FishData.COMMON_FRESH, "")
	for key in FishData.STYLE_FISH:
		var own: Array = FishData.STYLE_FISH[key][0].duplicate()
		own.append(FishData.STYLE_FISH[key][1])
		_section("淡水・" + WATER_NAMES.get(key, key), own, FishData.STYLE_FISH[key][1])
	_section("海水", FishData.SEA_COMMON, "")
	var rare: Array = FishData.SEA_RARE + FishData.SEA_LEGEND
	_section("海水・稀有", rare, "")


## One group: its title, then its fish in rows of nine. `rarest` gets a
## gold edge (the sea's rare ones all do).
func _section(title: String, ids: Array, rarest: String) -> void:
	_rows.add_child(MenuStyle.label(title, 16, MenuStyle.GOLD))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for id in ids:
		grid.add_child(_cell(id, id == rarest or title.ends_with("稀有")))
	_rows.add_child(grid)


func _cell(id: String, rare: bool) -> Control:
	var def: Dictionary = FishData.FISH[id]
	var entry: Dictionary = Profile.fish_log.get(def.name, {})
	var have := not entry.is_empty()
	var b := Button.new()
	b.name = "Fish_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CELL
	var edge := MenuStyle.GOLD if rare else MenuStyle.EDGE
	var box := MenuStyle.box(Color(0.1, 0.095, 0.09, 0.9) if have else Color(0.06, 0.06, 0.07, 0.9), edge, 8, 2 if rare else 1)
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, box)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 4
	col.offset_right = -4
	col.offset_top = 8
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	var icon := TextureRect.new()
	icon.texture = FishData.icon(id)
	icon.custom_minimum_size = Vector2(0, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not have:
		icon.modulate = Color(0, 0, 0, 0.75)
	col.add_child(icon)
	var n := MenuStyle.label(def.name if have else "？？？", 13, MenuStyle.TEXT if have else Color(1, 1, 1, 0.35))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	if have:
		var c := MenuStyle.label("×%d" % int(entry.count), 11, MenuStyle.DIM)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(c)
		b.pressed.connect(func(): _card(id, entry))
	b.add_child(col)
	return b


func _card(id: String, entry: Dictionary) -> void:
	var def: Dictionary = FishData.FISH[id]
	var lines := ["釣過 %d 次，最高賣 %.0f 金幣" % [int(entry.count), float(entry.best_value)],
		"個性：%s" % TRAIT_NAMES.get(def.trait, def.trait)]
	if float(entry.get("longest", 0.0)) > 0.0:
		lines.insert(1, "最長 %.1f cm" % float(entry.longest))
	var usual := FishData.species_trait(id)
	lines.append("特性：%s（%s）" % [FishData.trait_name(usual), FishData.TANK_TRAITS[usual][1]])
	if HABIT_NAMES.has(def.habit):
		lines.append("習性：" + HABIT_NAMES[def.habit])
	MenuStyle.notice(self, def.name, lines)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
