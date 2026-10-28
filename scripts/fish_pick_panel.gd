class_name FishPickPanel
extends Control

## A small window over the backpack: pick one of the fish carried (for 魚氧樹
## or 冷凍土 - Player.use_on_fish). Each fish shows how it is; one the thing
## can't help is greyed, with why.

signal picked(index: int)

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
	var panel := UiKit.tooltip_panel()
	panel.custom_minimum_size = Vector2(420, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiKit.label(_title, 19, UiKit.GOLD_BRIGHT, true))
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(390, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.name = "Fish"
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	col.add_child(scroll)
	if GameState.carried_fish.is_empty():
		list.add_child(UiKit.label("身上沒有魚。", 15, UiKit.DIM))
	for i in GameState.carried_fish.size():
		var f: Dictionary = GameState.carried_fish[i]
		var probe := f.duplicate()
		var why := FishLife.use_oxy_tree(probe) if _item == "oxy_tree" else FishLife.use_frozen(probe)
		var bar := FishLife.bar(f)
		var b := UiKit.button("%s　%s %d%%%s" % [f.get("name", "魚"), bar.label, roundi(float(bar.share) * 100.0),
			"　（%s）" % why if why != "" else ""], 14)
		b.name = "Fish_%d" % i
		b.custom_minimum_size = Vector2(380, 38)
		b.disabled = why != ""
		var idx := i
		b.pressed.connect(func():
			picked.emit(idx)
			queue_free())
		list.add_child(b)
	var cancel := UiKit.button("取消", 16)
	cancel.name = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.pressed.connect(queue_free)
	col.add_child(cancel)
	panel.add_child(col)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
