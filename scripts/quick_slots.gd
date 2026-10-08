class_name QuickSlots
extends CanvasLayer

## User request: three quick slots on the screen, over the right stick, set
## by the player to the things they want at hand (Profile.quick_slots, one
## of Profile.USABLES each - kept between runs) and used the moment
## they're tapped (Player.use_item()): drunk, opened, looked through. Each
## shows its thing's picture and how many are in the bag (greyed when none
## are), the binoculars' wait, a potion's time left round its rim.
## An empty slot tapped, or any slot held, opens a picker of what's in the
## bag to set it to (or clear it). Z / X / C on a keyboard.
## Touches are taken in _input (any finger - walking with the left stick
## while tapping one), and the slots are "hud_block" so a long press on
## them isn't the lamp's brightness (TouchControls).

## The slots' centres (the 960x540 layout: a row over the right stick,
## TouchControls.AIM_CENTER), their size; a hold this long opens the picker.
const CENTERS := [Vector2(736, 200), Vector2(802, 200), Vector2(868, 200)]
const SIDE := 56.0
const HOLD := 0.45
const KEYS := [KEY_Z, KEY_X, KEY_C]
const RIM := Color(0.95, 0.82, 0.5, 0.55)

var slots: Array[SlotView] = []
## The touch on a slot: its finger, which slot, how long it's been held.
var _touch := -1
var _touch_slot := -1
var _held := 0.0
var _picker: Control
var _picker_slot := -1


func _ready() -> void:
	layer = 5
	for i in CENTERS.size():
		var s := SlotView.new()
		s.name = "QuickSlot%d" % (i + 1)
		s.index = i
		s.size = Vector2(SIDE, SIDE)
		s.position = CENTERS[i] - s.size * 0.5
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_to_group("hud_block")
		add_child(s)
		slots.append(s)
	GameState.run_ended.connect(func(_won, _message):
		close_picker()
		visible = false)


func _process(delta: float) -> void:
	if _touch_slot >= 0:
		_held += delta
		slots[_touch_slot].hold = clampf(_held / HOLD, 0.0, 1.0)
		if _held >= HOLD:
			# Held: the picker, not a use.
			var i := _touch_slot
			_release_touch()
			open_picker(i)
	for s in slots:
		s.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and KEYS.has(event.keycode):
		if _picker == null and not _bag_open():
			tap(KEYS.find(event.keycode))
		return
	if _picker != null:
		# (the picker's buttons get the touch as a click; nothing else does)
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			get_viewport().set_input_as_handled()
		return
	if _bag_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			var i := slot_at(event.position)
			if i >= 0:
				_touch = event.index
				_touch_slot = i
				_held = 0.0
				slots[i].pressed = true
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			var i := _touch_slot
			_release_touch()
			if i >= 0:
				tap(i)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch:
		get_viewport().set_input_as_handled()


func _release_touch() -> void:
	if _touch_slot >= 0:
		slots[_touch_slot].pressed = false
		slots[_touch_slot].hold = 0.0
	_touch = -1
	_touch_slot = -1
	_held = 0.0


## The slot under `pos` (the screen's), or -1.
func slot_at(pos: Vector2) -> int:
	for i in slots.size():
		if Rect2(slots[i].position, slots[i].size).grow(4.0).has_point(pos):
			return i
	return -1


## A slot tapped: its thing used - or, empty, the picker.
func tap(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	var id: String = Profile.quick_slots[i]
	if id == "":
		open_picker(i)
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if Profile.bag_count(id) < 1:
		GameState.report("背包裡沒有%s了" % Items.name_of(id), "warn")
		slots[i].shake()
		return
	if player.use_item(id):
		slots[i].pop()
	else:
		slots[i].shake()


func _bag_open() -> bool:
	for c in get_tree().current_scene.get_children():
		if (c is Backpack or c is DialogBox) and c.is_open():
			return true
	return false


## The picker for slot `i`: what's in the bag to use, to set it to; or clear.
func open_picker(i: int) -> void:
	close_picker()
	_picker_slot = i
	Backpack.set_sticks_enabled(get_tree(), false)
	var shade := ColorRect.new()
	shade.name = "QuickPicker"
	shade.color = Color(0, 0, 0, 0.35)
	shade.size = Vector2(960, 540)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_to_group("hud_block")
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_picker())
	add_child(shade)
	_picker = shade
	var panel := UiKit.tooltip_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := UiKit.label("快捷欄 %d：選一樣道具" % (i + 1), 17, UiKit.GOLD_BRIGHT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UiKit.close_button()
	close.pressed.connect(close_picker)
	head.add_child(close)
	col.add_child(head)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.custom_minimum_size.x = 6 * 72.0 + 5 * 8.0
	var any := false
	for id in Profile.USABLE_ORDER:
		if Profile.bag_count(id) < 1 and Profile.quick_slots[i] != id:
			continue
		any = true
		var b := Button.new()
		b.name = "Pick_" + id
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(72, 88)
		b.flat = true
		var pic: ItemBoard.ItemIcon = ItemBoard.icon_box(id, 64.0)
		pic.count = Profile.bag_count(id)
		pic.position = Vector2(4, 2)
		pic.size = Vector2(64, 64)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		var name_label := UiKit.label(Items.name_of(id), 12, UiKit.rarity_color(UiKit.item_rarity(id)))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, 68)
		name_label.size = Vector2(72, 18)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_label)
		if Profile.quick_slots[i] == id:
			b.modulate = Color(1.2, 1.15, 0.9)
		b.pressed.connect(func(): pick(id))
		row.add_child(b)
	if not any:
		row.add_child(UiKit.label("背包裡沒有能用的道具（藥水、眼睛、望遠鏡）", 14, UiKit.DIM))
	col.add_child(row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	var clear := UiKit.button("清空這格", 14, "gray")
	clear.name = "ClearSlot"
	clear.custom_minimum_size = Vector2(110, 40)
	clear.disabled = Profile.quick_slots[i] == ""
	clear.pressed.connect(func(): pick(""))
	foot.add_child(clear)
	col.add_child(foot)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = Vector2(clampf(CENTERS[i].x - panel.size.x * 0.5, 10.0, 950.0 - panel.size.x),
		maxf(CENTERS[i].y - SIDE * 0.5 - 12.0 - panel.size.y, 10.0))


func pick(id: String) -> void:
	if _picker_slot >= 0:
		Profile.set_quick_slot(_picker_slot, id)
		Sfx.play("ui_click", -10.0)
	close_picker()


func close_picker() -> void:
	if _picker != null:
		_picker.queue_free()
		_picker = null
		Backpack.set_sticks_enabled(get_tree(), true)
	_picker_slot = -1


func picker_open() -> bool:
	return _picker != null


## One slot: its thing's picture and count, or a faint +.
class SlotView extends Control:
	var index := 0
	var pressed := false
	var hold := 0.0
	var _pop := 0.0
	var _shake := 0.0

	func pop() -> void:
		_pop = 1.0

	func shake() -> void:
		_shake = 1.0

	func _process(delta: float) -> void:
		_pop = maxf(_pop - delta * 3.0, 0.0)
		_shake = maxf(_shake - delta * 3.0, 0.0)

	func _draw() -> void:
		var id: String = Profile.quick_slots[index] if index < Profile.quick_slots.size() else ""
		var grow := 3.0 * sin(_pop * PI)
		var jiggle := Vector2(sin(_shake * 40.0) * 4.0 * _shake, 0.0)
		var r := Rect2(Vector2.ZERO, size).grow(grow)
		r.position += jiggle
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.5 if pressed else 0.34)
		box.border_color = Color(1.0, 0.45, 0.35, 0.8) if _shake > 0.0 else RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(9)
		draw_style_box(box, r)
		var font := UiKit.font(true)
		draw_string_outline(font, r.position + Vector2(5, 13), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(font, r.position + Vector2(5, 13), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.95, 0.85, 0.7))
		if id == "":
			var c := r.get_center()
			var ink := Color(1, 0.95, 0.85, 0.45)
			draw_line(c - Vector2(9, 0), c + Vector2(9, 0), ink, 2.5)
			draw_line(c - Vector2(0, 9), c + Vector2(0, 9), ink, 2.5)
		else:
			var count := Profile.bag_count(id)
			var tex := Items.square_icon(id)
			if tex == null:
				tex = Items.icon(id)
			if tex != null:
				var inner := r.grow(-7.0)
				draw_texture_rect(tex, inner, false, Color(1, 1, 1, 0.92) if count > 0 else Color(0.45, 0.45, 0.45, 0.6))
			if count > 1 or (count == 0):
				var t := str(count)
				draw_string_outline(font, Vector2(r.position.x, r.end.y - 5.0), t, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6.0, 13, 3,
					Color(0, 0, 0, 0.85))
				draw_string(font, Vector2(r.position.x, r.end.y - 5.0), t, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6.0, 13,
					Color(1, 0.4, 0.35) if count == 0 else Color.WHITE)
			_draw_timer(id, r)
		if hold > 0.05:
			draw_arc(r.get_center(), size.x * 0.62, -PI / 2.0, -PI / 2.0 + TAU * hold, 40, Color(1, 0.95, 0.8, 0.85), 3.0, true)

	## The binoculars' wait (the slot darkened, clearing round), a potion's
	## time left (an arc round the rim).
	func _draw_timer(id: String, r: Rect2) -> void:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
		var c := r.get_center()
		match id:
			"binoculars":
				var share := player.binoculars_cooldown / (Player.GUIDE_TIME + Player.BINOCULARS_COOLDOWN)
				if share > 0.0:
					var pts := PackedVector2Array([c])
					var steps := 24
					for k in steps + 1:
						var a := -PI / 2.0 + TAU * share * k / steps
						pts.append(c + Vector2(cos(a), sin(a)) * size.x)
					var clipped := Geometry2D.intersect_polygons(pts, PackedVector2Array([r.position,
						Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
					for poly in clipped:
						draw_colored_polygon(poly, Color(0, 0, 0, 0.55))
			"potion_vigor", "potion_ward":
				var left := player.vigor_timer / Player.VIGOR_TIME if id == "potion_vigor" else player.ward_timer / Player.WARD_TIME
				if left > 0.0:
					draw_arc(c, size.x * 0.56, -PI / 2.0, -PI / 2.0 + TAU * left, 40, Color(0.6, 1.0, 0.65, 0.8), 2.5, true)
