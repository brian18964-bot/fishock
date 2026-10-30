class_name ClaspPanel
extends Control

## User request (活魚扣): the clasp worn in a slot, opened - a cell for each of its
## hooks, a fish hung on it shown (tap it: taken off, to the bag, else the warehouse),
## a free hook a "＋" (tap it: pick one of the fish in the bag or the warehouse to hang).
## A hung fish takes no bag room, however big it is; its vitality and freshness still
## run down. The clasp can only be taken off with its hooks empty.

const CARD := Vector2(158, 142)

var slot := ""
var _row: HBoxContainer
var _note: Label


func _init(slot_key: String) -> void:
	slot = slot_key
	name = "ClaspPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var made := UiKit.window("活魚扣")
	var panel: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	var words := UiKit.label("點「＋」把背包或倉庫的魚掛上來；掛著的魚不佔背包格子，活性和新鮮度照樣倒數。點掛著的魚把牠取下。", 14, UiKit.DIM)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 420
	col.add_child(words)
	_row = HBoxContainer.new()
	_row.name = "Hooks"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 10)
	col.add_child(_row)
	_note = UiKit.label("", 15, UiKit.GOLD_BRIGHT)
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 10)
	var off := UiKit.button("卸下活魚扣", 15)
	off.name = "TakeOff"
	off.custom_minimum_size = Vector2(130, 42)
	off.pressed.connect(func():
		if Profile.unequip(slot):
			queue_free()
		else:
			_note.text = "先把魚取下來，才能卸下活魚扣")
	acts.add_child(off)
	var close := UiKit.button("關閉", 15)
	close.name = "Close"
	close.custom_minimum_size = Vector2(100, 42)
	close.pressed.connect(queue_free)
	acts.add_child(close)
	col.add_child(acts)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
	Profile.profile_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if _row == null:
		return
	for c in _row.get_children():
		c.queue_free()
	for h in Profile.clasp_hooks():
		if h.slot != slot:
			continue
		var hook: String = h.id
		var i := Profile.hooked_at(hook)
		if i >= 0:
			var card := FishPickPanel.Card.new()
			card.name = "Hung_" + hook.replace(":", "_")
			card.fish = Profile.clasp_fish[i]
			card.note = "點一下取下"
			card.custom_minimum_size = CARD
			card.pressed.connect(func(): _take_off(hook))
			_row.add_child(card)
		else:
			var plus := Plus.new()
			plus.name = "Free_" + hook.replace(":", "_")
			plus.custom_minimum_size = CARD
			plus.pressed.connect(func(): _pick(hook))
			_row.add_child(plus)


## The fish at `hook` off it - to the bag, if it fits, else the warehouse.
func _take_off(hook: String) -> void:
	var i := Profile.hooked_at(hook)
	if i < 0:
		return
	var f: Dictionary = Profile.clasp_fish[i]
	var why := Profile.move_fish("clasp", i, "pack")
	if why != "":
		why = Profile.move_fish("clasp", i, "stash")
	_note.text = "%s 取下來了" % f.get("name", "魚") if why == "" else why


## Which fish to hang: the bag's and the warehouse's.
func _pick(hook: String) -> void:
	var fish := []
	var places := []
	var from := []
	for pair in [["pack", "背包"], ["stash", "倉庫"]]:
		var list := Profile.fish_list(pair[0])
		for k in list.size():
			fish.append(list[k])
			places.append(pair[1])
			from.append([pair[0], k])
	var picker := FishPickPanel.new("掛哪一條魚？", "clasp", fish, places)
	picker.z_index = 5
	add_child(picker)
	picker.picked.connect(func(n: int):
		var why := Profile.hang_fish(from[n][0], from[n][1], hook)
		_note.text = "掛上去了" if why == "" else why)


## An empty hook: a "＋" in a slot.
class Plus extends Button:
	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_slot(self, r, "", is_hovered())
		var c := r.get_center()
		var ink := UiKit.GOLD_BRIGHT if is_hovered() else UiKit.GOLD
		draw_line(c + Vector2(-18, 0), c + Vector2(18, 0), ink, 5.0)
		draw_line(c + Vector2(0, -18), c + Vector2(0, 18), ink, 5.0)
		UiKit.draw_text(self, Vector2(0, size.y - 12), "掛上一條魚", 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x)
