class_name FishPickPanel
extends Control

## A window over the backpack: pick one of the fish carried (for 魚氧樹 or
## 冷凍土 - Player.use_on_fish). Like the altar's (FishPicker): each fish a
## card with its picture, name, how it is (its bar), and - one the thing can't
## help greyed, with why.

signal picked(index: int)

const CARD := Vector2(158, 142)
const COLS := 4

var _title := ""
var _item := ""


func _init(title: String, item_id: String) -> void:
	_title = title
	_item = item_id
	name = "FishPickPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var made := UiKit.window(_title)
	var panel: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	var rows := clampi(ceili(float(GameState.carried_fish.size()) / COLS), 1, 2)
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
	if GameState.carried_fish.is_empty():
		grid.add_child(UiKit.label("身上沒有魚。", 15, UiKit.DIM))
	for i in GameState.carried_fish.size():
		var f: Dictionary = GameState.carried_fish[i]
		var why := FishLife.use_oxy_tree(f.duplicate()) if _item == "oxy_tree" else FishLife.use_frozen(f.duplicate())
		var card := Card.new()
		card.name = "Fish_%d" % i
		card.fish = f
		card.note = why if why != "" else "可以用"
		card.note_color = Color(0.9, 0.55, 0.4) if why != "" else UiKit.USE
		card.custom_minimum_size = CARD
		card.disabled = why != ""
		var idx := i
		card.pressed.connect(func():
			picked.emit(idx)
			queue_free())
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


## One fish: its picture in a slot ringed by its rarity, its name, its life bar
## and a line (what a tap does, or why the thing can't help it). (A flat
## button: the card is the tap.) Also the oxygen box's (OxyPanel).
class Card extends Button:
	var fish := {}
	## A line at its foot, and its colour.
	var note := ""
	var note_color := UiKit.USE

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rarity := UiKit.fish_rarity(fish)
		UiKit.draw_slot(self, r, rarity, is_hovered() and not disabled)
		var dim := Color(1, 1, 1, 0.45) if disabled else Color.WHITE
		# (a short card leaves out its last line)
		var compact := size.y < 112.0
		var low := 24.0 if compact else 38.0
		var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
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
