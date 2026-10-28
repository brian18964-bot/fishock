class_name OxyPanel
extends Control

## User request: the oxygenated fish box, opened (from the backpack's off
## hand slot): its six slots, and under them the fish carried. A tap on one
## in the box takes it out; a tap on one carried puts it in - each a use of
## the box's durability (GameState.oxy_put / oxy_take). What's in it doesn't
## run down (GameState._age_fish ticks only what's carried).

signal closed

const SLOT := Vector2(108, 118)
var _head: Label
var _grid: GridContainer
var _list: GridContainer
var _note: Label
var _t := 0.0


func _init() -> void:
	name = "OxyPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := UiKit.tooltip_panel()
	panel.custom_minimum_size = Vector2(700, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_head = UiKit.label("", 19, UiKit.GOLD_BRIGHT, true)
	col.add_child(_head)
	var sub := UiKit.label("放進魚箱的魚活性不會下降。點魚箱裡的魚拿出來，點下面的魚放進去（各用掉 1 點耐久）。", 13, UiKit.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 670
	col.add_child(sub)
	_grid = GridContainer.new()
	_grid.name = "Slots"
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	col.add_child(_grid)
	col.add_child(UiKit.divider(670))
	col.add_child(UiKit.label("身上帶著的魚", 15, UiKit.TEXT))
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(670, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = GridContainer.new()
	_list.name = "Carried"
	_list.columns = 6
	_list.add_theme_constant_override("h_separation", 6)
	_list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_list)
	col.add_child(scroll)
	_note = UiKit.label("", 14, Color(1.0, 0.7, 0.5))
	col.add_child(_note)
	var close := UiKit.button("關閉", 16)
	close.name = "Close"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	col.add_child(close)
	panel.add_child(col)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)


func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	# (the carried fish run down while it's open)
	_t += delta
	if _t >= 0.5:
		_t = 0.0
		_refresh_text()


func refresh() -> void:
	_head.text = "打氧魚箱　%d / %d　耐久 %d / %d" % [GameState.oxy_fish.size(), Profile.OXY_SLOTS,
		Profile.durability("oxy_box"), Profile.max_durability("oxy_box")]
	for c in _grid.get_children():
		c.queue_free()
	for i in Profile.OXY_SLOTS:
		if i < GameState.oxy_fish.size():
			# (its picture and how it is - a tap takes it out)
			var card := FishPickPanel.Card.new()
			card.name = "Slot_%d" % i
			card.fish = GameState.oxy_fish[i]
			card.note = "點一下拿出來"
			card.custom_minimum_size = SLOT
			var idx := i
			card.pressed.connect(func(): _say(GameState.oxy_take(idx)))
			_grid.add_child(card)
		else:
			var b := UiKit.button("（空）", 13)
			b.name = "Slot_%d" % i
			b.custom_minimum_size = SLOT
			b.disabled = true
			_grid.add_child(b)
	for c in _list.get_children():
		c.queue_free()
	if GameState.carried_fish.is_empty():
		var l := UiKit.label("身上沒有魚。", 14, UiKit.DIM)
		_list.add_child(l)
	for i in GameState.carried_fish.size():
		var card := FishPickPanel.Card.new()
		card.name = "Carried_%d" % i
		card.fish = GameState.carried_fish[i]
		card.note = "點一下放進魚箱"
		card.custom_minimum_size = SLOT
		var idx := i
		card.pressed.connect(func(): _say(GameState.oxy_put(idx)))
		_list.add_child(card)


func _refresh_text() -> void:
	# (the cards' bars run down: they draw what's in the fish)
	for c in _list.get_children() + _grid.get_children():
		c.queue_redraw()


func _say(why: String) -> void:
	_note.text = why
	refresh()
