class_name FishPickPanel
extends Control

## A window over the backpack: pick one of the fish carried (for 魚氧樹 or
## 冷凍土 - Player.use_on_fish). Like the altar's (FishPicker): each fish a
## card with its picture, name, how it is (its bar), and - one the thing can't
## help greyed, with why.
## User request (the potions used on a fish): a fish tapped shows what it is first - its card
## (FishVitals: rarity, size and worth, its life and its time, its affixes) and whether the thing
## can help it - with 使用 to go ahead or 返回 to pick another; one it can't help shows too, 使用 off.

signal picked(index: int)

const CARD := Vector2(158, 142)
const COLS := 4

var _title := ""
var _item := ""
## The fish listed: the carried ones, or (the camp's bag page) any set given.
var _fish: Array = []
## (the camp: where each of them is - a line at the card's foot)
var _places: Array = []


func _init(title: String, item_id: String, fish = null, places: Array = []) -> void:
	_title = title
	_item = item_id
	_fish = fish if fish != null else GameState.carried_fish
	_places = places
	name = "FishPickPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	add_child(shade)
	var made := UiKit.window(_title)
	var panel: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	var rows := clampi(ceili(float(_fish.size()) / COLS), 1, 2)
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(CARD.x * COLS + 10.0 * (COLS - 1) + 12.0, CARD.y * rows + 10.0 * (rows - 1) + 8.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.name = "Fish"
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	col.add_child(scroll)
	if _fish.is_empty():
		grid.add_child(UiKit.label("背包和倉庫裡沒有魚。" if _item == "clasp" else "身上沒有魚。", 15, UiKit.DIM))
	elif _item == "salt" and _fish.all(func(g): return FishLife.can_salt(g) != ""):
		grid.add_child(UiKit.label("身上沒有可以醃的魚（要死掉、還沒腐敗）。", 15, UiKit.DIM))
	for i in _fish.size():
		var f: Dictionary = _fish[i]
		var why := "" if _item == "clasp" else FishLife.can_use(_item, f)
		if _item == "salt" and why != "":
			continue   # (only the dead that aren't rotten are shown)
		var card := Card.new()
		card.name = "Fish_%d" % i
		card.fish = f
		card.note = ("%s・" % _places[i] if i < _places.size() else "") + (why if why != "" else "可以用")
		card.note_color = Color(0.9, 0.55, 0.4) if why != "" else UiKit.USE
		card.custom_minimum_size = CARD
		card.blocked = why != ""
		var idx := i
		card.pressed.connect(func(): show_fish(idx))
		grid.add_child(card)
	var cancel := UiKit.button("取消", 16)
	cancel.name = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.pressed.connect(queue_free)
	col.add_child(cancel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)


var _detail: Control


## Fish `i`'s card over the list: what it is, whether the thing helps it, 使用 / 返回.
func show_fish(i: int) -> void:
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
	var f: Dictionary = _fish[i]
	var why := "" if _item == "clasp" else FishLife.can_use(_item, f)
	FishLife.ensure(f)
	var shade := ColorRect.new()
	shade.name = "FishDetail"
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			shade.queue_free())
	add_child(shade)
	_detail = shade
	var panel := UiKit.tooltip_panel()
	panel.custom_minimum_size = Vector2(400, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var pic := TextureRect.new()
	pic.texture = FishData.icon_of(f)
	pic.custom_minimum_size = Vector2(110, 60)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.add_child(FishVitals.name_row(f, 21))
	if i < _places.size():
		words.add_child(UiKit.label("在%s" % _places[i], 14, UiKit.DIM))
	head.add_child(words)
	col.add_child(head)
	var vitals := FishVitals.new()
	vitals.custom_minimum_size.x = 370
	col.add_child(vitals)
	# (at camp: its length, weight and times, as the bag's card; in a run, as the run's)
	vitals.show_fish(f, false, "camp" if not _places.is_empty() else "field")
	var can := UiKit.label("可以用在這條魚" if why == "" else why, 15, UiKit.USE if why == "" else Color(0.9, 0.55, 0.4), true)
	can.name = "Why"
	can.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	can.custom_minimum_size.x = 370
	col.add_child(can)
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_END
	acts.add_theme_constant_override("separation", 8)
	var go := UiKit.button("使用", 16, "red")
	go.name = "Use"
	go.custom_minimum_size = Vector2(110, 44)
	go.disabled = why != ""
	go.pressed.connect(func():
		picked.emit(i)
		queue_free())
	acts.add_child(go)
	var back := UiKit.button("返回", 16)
	back.name = "Back"
	back.custom_minimum_size = Vector2(90, 44)
	back.pressed.connect(shade.queue_free)
	acts.add_child(back)
	col.add_child(acts)
	panel.add_child(col)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	shade.add_child(center)


## One fish: its picture in a slot ringed by its rarity, its name, its life bar
## and a line (what a tap does, or why the thing can't help it). (A flat
## button: the card is the tap.) Also the oxygen box's (OxyPanel).
class Card extends Button:
	var fish := {}
	## A line at its foot, and its colour.
	var note := ""
	var note_color := UiKit.USE
	## (the thing can't help it: greyed - still tapped for its card)
	var blocked := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rarity := UiKit.fish_rarity(fish)
		UiKit.draw_slot(self, r, rarity, is_hovered() and not disabled)
		var dim := Color(1, 1, 1, 0.45) if disabled or blocked else Color.WHITE
		# (a short card leaves out its last line)
		var compact := size.y < 112.0
		var low := 24.0 if compact else 38.0
		var tex := FishData.icon_of(fish)
		var pic := Rect2(Vector2(14, 26), Vector2(size.x - 28.0, minf((size.x - 28.0) * 0.5, size.y - 26.0 - low - 14.0)))
		if tex != null:
			var k := minf(pic.size.x / tex.get_width(), pic.size.y / tex.get_height())
			var sz := Vector2(tex.get_size()) * k
			var tint := Color(0.55, 0.5, 0.35) if FishLife.state(fish) == "rotten" else Color.WHITE
			draw_texture_rect(tex, Rect2(pic.get_center() - sz / 2.0, sz), false, tint * dim)
		UiKit.draw_text(self, Vector2(8, 20), fish.get("name", "魚"), 15, UiKit.rarity_color(rarity) * dim,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, true)
		var bar := FishLife.bar(fish)
		UiKit.draw_text(self, Vector2(8, size.y - low), "%s %d%%" % [bar.label, roundi(float(bar.share) * 100.0)], 13,
			UiKit.TEXT * dim, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0)
		var track := Rect2(8, size.y - low + 6.0, size.x - 16.0, 6)
		draw_rect(track, Color(0.08, 0.07, 0.06, 0.9))
		var col := Color(0.35, 0.8, 0.5) if bar.kind == "vit" else (Color(0.4, 0.7, 0.95) if bar.kind == "fresh" else Color(0.5, 0.42, 0.25))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(bar.share), 0.0, 1.0), track.size.y)), col * dim)
		if not compact:
			UiKit.draw_text(self, Vector2(8, size.y - 10), note, 12, note_color * dim, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0)
