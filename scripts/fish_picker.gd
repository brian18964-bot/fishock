class_name FishPicker
extends Control

## User request: offering at the altar shows only the fish carried, not
## the whole bag - big cards in a big window: tap a fish to pick it (tap
## again to put it back), see what the picked ones add, offer them. The
## 誘惑 fish (pick_lure) is picked the same way, one fish. Opened by
## Backpack.open_mode(); Backpack.select("fish", i) picks too.

const WINDOW := Vector2(880, 486)
const CARD := Vector2(154, 132)
const COLS := 5
const PICKED := Color(0.4, 1.0, 0.5)
const ROTTEN := Color(0.85, 0.55, 0.35)

var owner_bag: Backpack
## "sacrifice" or "pick_lure".
var kind := "sacrifice"
## The fish picked: their uids (sacrifice), or the one's index (pick_lure).
var marked := {}
var chosen := -1

var _window: PanelContainer
var _title: Label
var _hint: Label
var _cards: GridContainer
var _summary: Label
var _buttons: HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.size = Vector2(960, 540)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var made := UiKit.window("獻祭")
	_window = made[0]
	var col: VBoxContainer = made[1]
	_title = col.get_node("Title/TitleText")
	_window.custom_minimum_size = WINDOW
	_window.size = WINDOW
	_window.position = (Vector2(960, 540) - WINDOW) * 0.5
	add_child(_window)
	_hint = UiKit.label("", 15, UiKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(WINDOW.x - 40.0, CARD.y * 2.0 + 30.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = COLS
	_cards.add_theme_constant_override("h_separation", 10)
	_cards.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_cards)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	_summary = UiKit.label("", 16, UiKit.GOLD_BRIGHT)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_summary)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	foot.add_child(_buttons)
	col.add_child(foot)


func open(pick_kind: String) -> void:
	kind = pick_kind
	marked.clear()
	chosen = -1
	_title.text = "獻祭" if kind == "sacrifice" else "誘惑"
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for i in GameState.carried_fish.size():
		var card := FishCard.new()
		card.name = "Fish_%d" % i
		card.picker = self
		card.index = i
		card.custom_minimum_size = CARD
		_cards.add_child(card)
	visible = true
	refresh()


func close() -> void:
	visible = false
	marked.clear()
	chosen = -1


func is_picked(index: int) -> bool:
	if kind == "pick_lure":
		return index == chosen
	return marked.has(_uid(index))


## A fish tapped: picked, or put back.
func toggle(index: int) -> void:
	if index < 0 or index >= GameState.carried_fish.size():
		return
	if kind == "pick_lure":
		chosen = -1 if chosen == index else index
	else:
		var uid := _uid(index)
		if marked.has(uid):
			marked.erase(uid)
		else:
			marked[uid] = true
	Sfx.play("ui_click", -10.0)
	refresh()


func picked_indices() -> Array:
	var out := []
	for i in GameState.carried_fish.size():
		if is_picked(i):
			out.append(i)
	return out


func refresh() -> void:
	for c in _cards.get_children():
		c.queue_redraw()
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()
	var picked := picked_indices()
	if GameState.carried_fish.is_empty():
		_hint.text = "背包裡沒有魚"
	elif kind == "sacrifice":
		_hint.text = "點魚選擇要獻上的（可以選好幾條，再點一次取消）"
	else:
		_hint.text = "點一條魚，選它當誘餌"
	if kind == "sacrifice":
		var total := 0.0
		var rotten := 0
		for i in picked:
			total += float(GameState.carried_fish[i].get("value", 0.0))
			if GameState.carried_fish[i].get("rotten", false):
				rotten += 1
		_summary.text = "已選 %d 條・額度 +%.0f（%d / %d）%s" % [picked.size(), total,
			int(GameState.quota_progress), int(GameState.quota_target), "・含腐敗的魚" if rotten > 0 else ""] \
			if not picked.is_empty() else "還沒選魚"
		var every := picked.size() == GameState.carried_fish.size() and not picked.is_empty()
		var all := _button("全不選" if every else "全選", "gray")
		all.disabled = GameState.carried_fish.is_empty()
		all.pressed.connect(func():
			marked.clear()
			if not every:
				for i in GameState.carried_fish.size():
					marked[_uid(i)] = true
			refresh())
		_buttons.add_child(all)
		var go := _button("獻祭 %d 條" % picked.size(), "red")
		go.name = "Offer"
		go.disabled = picked.is_empty()
		go.pressed.connect(_offer)
		_buttons.add_child(go)
	else:
		_summary.text = "誘餌：%s" % GameState.carried_fish[chosen].get("name", "魚") if chosen >= 0 else ""
		var ok := _button("確定", "red")
		ok.name = "ConfirmLure"
		ok.disabled = chosen < 0
		ok.pressed.connect(_confirm_lure)
		_buttons.add_child(ok)
	var cancel := _button("取消", "gray")
	cancel.pressed.connect(owner_bag.toggle)
	_buttons.add_child(cancel)


func _offer() -> void:
	var offered := GameState.sacrifice_many(picked_indices())
	if not offered.is_empty():
		GameState.push_message("獻祭了 %d 條魚" % offered.size())
	owner_bag.toggle()


func _confirm_lure() -> void:
	if chosen < 0 or chosen >= GameState.carried_fish.size():
		return
	var fish: Dictionary = GameState.carried_fish[chosen]
	GameState.set_lure(chosen)
	GameState.push_message("誘餌：%s（按住誘惑鈕蓄力丟出）" % fish.get("name", "魚"))
	owner_bag.toggle()


func _uid(index: int) -> int:
	return int(GameState.carried_fish[index].get("uid", -1))


func _button(text: String, style: String) -> Button:
	var b := UiKit.button(text, 16, style)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(108, 46)
	return b


## One fish: its picture, name (in its rarity's colour), size and worth;
## ringed and ticked when picked. Tapped (not dragged - the list scrolls
## under a finger), it's picked or put back.
class FishCard extends Control:
	var picker: FishPicker
	var index := -1
	var _down := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = event.position
			elif event.position.distance_to(_down) < 12.0:
				picker.toggle(index)

	func _draw() -> void:
		if index >= GameState.carried_fish.size():
			return
		var fish: Dictionary = GameState.carried_fish[index]
		var rarity := UiKit.fish_rarity(fish)
		var picked := picker.is_picked(index)
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_slot(self, r, rarity, picked)
		var rotten: bool = fish.get("rotten", false)
		var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
		var pic := Rect2(Vector2(14, 22), Vector2(size.x - 28.0, (size.x - 28.0) * 0.5))
		if tex != null:
			draw_texture_rect(tex, pic, false, Color(0.55, 0.5, 0.35) if rotten else Color.WHITE)
		UiKit.draw_text(self, Vector2(8, 20), fish.get("name", "魚"), 15, UiKit.rarity_color(rarity),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, true)
		var size_name: String = Inventory.SIZE_NAMES.get(Inventory.fish_size(fish), "")
		var line := "%s型・價值 %.0f" % [size_name, float(fish.get("value", 0.0))]
		UiKit.draw_text(self, Vector2(8, size.y - 26), line, 13, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0)
		if rotten:
			UiKit.draw_text(self, Vector2(8, size.y - 9), "腐敗・獻祭會賭一把", 12, FishPicker.ROTTEN, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0)
		elif GameState.lure_index() == index:
			UiKit.draw_text(self, Vector2(8, size.y - 9), "誘惑用的魚", 12, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0)
		if picked:
			draw_rect(r.grow(-2.0), Color(FishPicker.PICKED, 0.14))
			draw_rect(r.grow(-2.0), Color(FishPicker.PICKED, 0.95), false, 3.0)
			var at := Vector2(size.x - 18.0, 18.0)
			draw_circle(at, 12.0, Color(0.15, 0.5, 0.2))
			draw_arc(at, 12.0, 0.0, TAU, 24, FishPicker.PICKED, 2.0)
			UiKit.draw_text(self, at + Vector2(-12, 6), "✓", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 24, true)
