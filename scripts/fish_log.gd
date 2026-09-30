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
const CELL := Vector2(96, 98)

var _rows: VBoxContainer
var _count: Label


func _ready() -> void:
	_build()
	_rebuild_rows()


func _build() -> void:
	UiKit.page_chrome(self, _on_back_pressed, "BackButton")
	var made := UiKit.window("魚類圖鑑")
	var book: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	book.position = Vector2(14, 56)
	book.custom_minimum_size = Vector2(932, 474)
	book.size = book.custom_minimum_size
	_count = UiKit.label("", 15, UiKit.DIM)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(890, 376)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.name = "RowsContainer"
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	col.add_child(scroll)
	add_child(book)


func _rebuild_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var caught := 0
	for id in FishData.FISH:
		if Profile.fish_log.has(FishData.FISH[id].name):
			caught += 1
	_count.text = "已收集 %d / %d" % [caught, FishData.FISH.size()]

	_section("淡水・各地都有", FishData.COMMON_FRESH)
	for key in FishData.STYLE_FISH:
		var own: Array = FishData.STYLE_FISH[key][0].duplicate()
		own.append(FishData.STYLE_FISH[key][1])
		_section("淡水・" + WATER_NAMES.get(key, key), own)
	_section("海水", FishData.SEA_COMMON)
	var rare: Array = FishData.SEA_RARE + FishData.SEA_LEGEND
	_section("海水・稀有", rare)


## One group: its title, then its fish in rows of nine, each ringed by its
## rarity (a water's rarest purple, the sea's legends orange).
func _section(title: String, ids: Array) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiKit.label(title, 17, UiKit.GOLD, true))
	var line := UiKit.divider(560)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(line)
	_rows.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for id in ids:
		grid.add_child(_cell(id))
	_rows.add_child(grid)


func _cell(id: String) -> Control:
	var def: Dictionary = FishData.FISH[id]
	var entry: Dictionary = Profile.fish_log.get(def.name, {})
	var have := not entry.is_empty()
	var b := LogCell.new()
	b.name = "Fish_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CELL
	b.fish_id = id
	b.have = have
	b.count = int(entry.get("count", 0))
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	if have:
		b.pressed.connect(func(): _card(id, entry))
	return b


## A species in the log: a slot with its picture (a dark shape if never
## caught) ringed by its rarity, its name under it.
class LogCell extends Button:
	var fish_id := ""
	var have := false
	var count := 0

	func _draw() -> void:
		var r := Rect2(Vector2(10, 2), Vector2(size.x - 20, size.x - 20))
		var rarity := UiKit.fish_rarity({"id": fish_id})
		UiKit.draw_slot(self, r, rarity if have else "")
		var tex := FishData.icon(fish_id)
		if tex != null:
			var room := r.grow(-5.0)
			var k := minf(room.size.x / tex.get_width(), room.size.y / tex.get_height())
			var sz := Vector2(tex.get_size()) * k
			draw_texture_rect(tex, Rect2(room.get_center() - sz / 2.0, sz), false,
				Color.WHITE if have else Color(0, 0, 0, 0.8))
		var name_text: String = FishData.FISH[fish_id].name if have else "？？？"
		var col := UiKit.rarity_color(rarity) if have else Color(1, 1, 1, 0.35)
		UiKit.draw_text(self, Vector2(0, size.y - 4), name_text, 13, col, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if have and count > 0:
			UiKit.draw_text(self, Vector2(0, r.end.y - 4), str(count), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.end.x - 4)


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
	var note := MenuStyle.notice(self, def.name, lines)
	# User request (3D out of the game): the fish itself, turning in 3D,
	# under the title.
	if FishModel.has_model(id):
		var col: VBoxContainer = note.get_child(0).get_child(0)
		var pic := ItemPreview.new()
		pic.name = "Preview"
		pic.custom_minimum_size = Vector2(400, 170)
		col.add_child(pic)
		col.move_child(pic, 1)
		pic.show_fish(id)


func _on_back_pressed() -> void:
	# Opened from the fish tank.
	UiKit.page_go(self, "fish_tank")
