class_name ItemBoard
extends Control

## The warehouse and equipment pages' shared workings (user request): the
## warehouse (Profile.storage, by tab), the bag packed for the next run
## (Profile.bag on the backpack's grid) and, on the equipment page, the
## slots worn (Profile.equipped). Things are dragged between them - or
## within the bag to rearrange it - or tapped for a card that moves a
## chosen number of them.
##
## A page extends this, builds its views (StorageGrid, BagGrid, SlotBox)
## and hands them to track(). A press on a view starts a drag; let go on a
## view to drop it there; let go without moving and it's a tap (card()).
## Mouse events only: touches arrive as mouse events too
## (input_devices/pointing/emulate_mouse_from_touch).

const DRAG_START := 8.0
const TAB_COLORS := {
	"gear": Color(0.3, 0.26, 0.4), "item": Color(0.42, 0.36, 0.18), "tackle": Color(0.2, 0.4, 0.34),
	"other": Color(0.3, 0.3, 0.32),
}

var _views: Array = []
## The press: {from: "storage"/"bag"/"slot", id, index (bag), slot, at}.
var _press := {}
var _dragging := false
var _ghost: TextureRect
var _card: Control


func track(view: Control) -> void:
	_views.append(view)
	view.set("board", self)


## A view was pressed on a thing (`source`, see _press) at `at` (global).
func pressed(source: Dictionary, at: Vector2) -> void:
	if _card != null:
		return
	_press = source.duplicate()
	_press["at"] = at
	_dragging = false


func _input(event: InputEvent) -> void:
	if _press.is_empty():
		return
	if event is InputEventMouseMotion:
		var at: Vector2 = event.position
		if not _dragging and at.distance_to(_press.at) > DRAG_START:
			_start_drag()
		if _dragging:
			_ghost.position = at - _ghost.size / 2.0
			for v in _views:
				if v.has_method("hover"):
					v.hover(_press, at)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var source := _press
		_press = {}
		if _dragging:
			_end_drag()
			drop(source, event.position)
		else:
			card(source)


func _start_drag() -> void:
	_dragging = true
	_ghost = TextureRect.new()
	_ghost.texture = Items.icon(_press.id)
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.size = Vector2(Items.size_of(_press.id)) * 52.0
	_ghost.modulate = Color(1, 1, 1, 0.8)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 50
	add_child(_ghost)


func _end_drag() -> void:
	_dragging = false
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	for v in _views:
		if v.has_method("hover"):
			v.hover({}, Vector2.ZERO)


## Let go at `at`: onto whichever view is there.
func drop(source: Dictionary, at: Vector2) -> bool:
	for v in _views:
		if v.is_visible_in_tree() and v.get_global_rect().has_point(at):
			var target: Dictionary = v.target_at(at)
			return move(source, target)
	return false


## Moves what `source` names to `target` ({to: "storage"} / {to: "bag",
## cell} / {to: "slot", slot}); `count` of it where that's a choice.
func move(source: Dictionary, target: Dictionary, count := -1) -> bool:
	if target.is_empty():
		return false
	var id: String = source.id
	match [source.from, target.to]:
		["storage", "bag"]:
			var n := Profile.stored(id) if count < 0 else count
			if count < 0:
				n = mini(n, Items.stack_of(id))
			return Profile.to_bag(id, n, target.get("cell", Vector2i(-1, -1))) > 0
		["storage", "slot"], ["bag", "slot"]:
			if Items.def(id).get("slot", "") != target.slot:
				return false
			return Profile.equip(id, source.get("index", -1) if source.from == "bag" else -1)
		["bag", "bag"]:
			if count > 0 and count < int(Profile.bag[source.index].count):
				return Profile.bag_split(source.index, count, target.cell)
			return Profile.bag_move(source.index, target.cell)
		["bag", "storage"]:
			return Profile.to_storage(source.index, count) > 0
		["slot", "storage"]:
			return Profile.unequip(source.slot)
		["slot", "bag"]:
			if not Profile.unequip(source.slot):
				return false
			return Profile.to_bag(id, 1, target.get("cell", Vector2i(-1, -1))) > 0
	return false


## The card for a tapped thing: its picture, name and what it does, how
## many (a stepper, for stacks) and what can be done with it here.
func card(source: Dictionary) -> void:
	var id: String = source.id
	var def := Items.def(id)
	if def.is_empty():
		return
	var have: int = 1
	match source.from:
		"storage":
			have = Profile.stored(id)
		"bag":
			have = int(Profile.bag[source.index].count)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_card())
	add_child(shade)
	_card = shade
	var panel := MenuStyle.panel(Color(0.08, 0.075, 0.07, 0.97))
	panel.custom_minimum_size = Vector2(380, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var pic := TextureRect.new()
	pic.texture = Items.icon(id)
	pic.custom_minimum_size = Vector2(96, 64)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.add_child(MenuStyle.label(def.name, 20, MenuStyle.GOLD))
	var where := {"storage": "在倉庫", "bag": "在背包", "slot": "穿戴中"}
	words.add_child(MenuStyle.label("%s・%s ×%d" % [Items.TABS.get(def.tab, ""), where[source.from], have], 13, MenuStyle.DIM))
	head.add_child(words)
	col.add_child(head)
	var desc := MenuStyle.label(def.get("desc", ""), 14, MenuStyle.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 350
	col.add_child(desc)

	# How many (stacks only).
	var amount := [have]
	if have > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(MenuStyle.label("數量", 15, MenuStyle.DIM))
		var less := MenuStyle.button("－", 18)
		var more := MenuStyle.button("＋", 18)
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = have
		slider.step = 1
		slider.value = have
		slider.custom_minimum_size = Vector2(150, 30)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var shown := MenuStyle.label(str(have), 18, MenuStyle.GOLD)
		shown.name = "Amount"
		shown.custom_minimum_size.x = 36
		slider.value_changed.connect(func(v):
			amount[0] = int(v)
			shown.text = str(int(v)))
		less.pressed.connect(func(): slider.value -= 1)
		more.pressed.connect(func(): slider.value += 1)
		for c in [less, slider, more, shown]:
			row.add_child(c)
		col.add_child(row)

	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	acts.alignment = BoxContainer.ALIGNMENT_END
	for act in actions(source):
		var b := MenuStyle.button(act[0], 15, act.size() > 2 and act[2])
		b.name = "Act_" + act[0]
		b.custom_minimum_size = Vector2(96, 40)
		var target: Dictionary = act[1]
		b.pressed.connect(func():
			move(source, target, amount[0])
			_close_card())
		acts.add_child(b)
	var cancel := MenuStyle.button("取消", 15)
	cancel.custom_minimum_size = Vector2(80, 40)
	cancel.pressed.connect(_close_card)
	acts.add_child(cancel)
	col.add_child(acts)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = (size - panel.size) / 2.0


## What a tapped thing can do on this page: [label, target, main?]. The
## warehouse page moves between warehouse and bag; the equipment page adds
## putting on and taking off.
func actions(source: Dictionary) -> Array:
	var out := []
	var slot: String = Items.def(source.id).get("slot", "")
	match source.from:
		"storage":
			out.append(["放進背包", {"to": "bag"}, true])
		"bag":
			if not Items.def(source.id).get("fixed", false):
				out.append(["放回倉庫", {"to": "storage"}, true])
	if slot != "" and source.from != "slot":
		out.append(["裝備", {"to": "slot", "slot": slot}])
	return out


func _close_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


## Draws one thing in a box: its tab's colour, its picture, its count.
static func draw_item(ci: CanvasItem, r: Rect2, id: String, count: int, font: Font, lit := false, named := false) -> void:
	var def := Items.def(id)
	var col: Color = TAB_COLORS.get(def.get("tab", "other"), Color.GRAY)
	ci.draw_rect(r, col.darkened(0.25) if not lit else col.lightened(0.15))
	var tex := Items.icon(id)
	if tex != null:
		var room := r.grow(-4.0)
		var long := float(tex.get_width()) / tex.get_height()
		if long > 2.2 and room.size.x / room.size.y < 1.6:
			# A long thing in a square box: laid corner to corner.
			var diag := room.size.length() * 0.95
			var sz := Vector2(diag, diag / long)
			ci.draw_set_transform(room.get_center(), -atan2(room.size.y, room.size.x))
			ci.draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			var k := minf(room.size.x / tex.get_width(), room.size.y / tex.get_height())
			var sz := Vector2(tex.get_size()) * k
			ci.draw_texture_rect(tex, Rect2(room.get_center() - sz / 2.0, sz), false)
	ci.draw_rect(r, Color(1.0, 0.9, 0.6) if lit else Color(1, 1, 1, 0.25), false, 2.0 if lit else 1.0)
	if named:
		ci.draw_string(font, r.position + Vector2(4, 13), def.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 6.0, 11, Color(1, 1, 1, 0.85))
	if count > 1:
		ci.draw_string(font, r.position + Vector2(0, r.size.y - 4), "×%d" % count, HORIZONTAL_ALIGNMENT_RIGHT,
			r.size.x - 4.0, 13, Color.WHITE)


## The bag: Inventory's grid with what's packed where it's packed.
class BagGrid extends Control:
	var board: ItemBoard
	var cell := 54.0
	var _hover := {}
	var _hover_cell := Vector2i.ZERO
	var _inside := false

	func _init(cell_size := 54.0) -> void:
		cell = cell_size
		custom_minimum_size = Vector2(Inventory.COLS, Inventory.ROWS) * cell
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		Profile.profile_changed.connect(queue_redraw)

	func cell_at(global: Vector2) -> Vector2i:
		var p := (global - global_position) / cell
		return Vector2i(floori(p.x), floori(p.y))

	func target_at(global: Vector2) -> Dictionary:
		var c := cell_at(global)
		if not _hover.is_empty():
			# Dragged by its middle: its top-left cell.
			var sz := Items.size_of(_hover.id)
			c = cell_at(global - Vector2(sz - Vector2i.ONE) * cell / 2.0)
		return {"to": "bag", "cell": c}

	func hover(source: Dictionary, at: Vector2) -> void:
		_hover = source
		_inside = not source.is_empty() and get_global_rect().has_point(at)
		if _inside:
			_hover_cell = target_at(at).cell
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var i := Profile.bag_at(cell_at(event.global_position))
			if i >= 0:
				board.pressed({"from": "bag", "id": Profile.bag[i].id, "index": i}, event.global_position)
				accept_event()

	func _draw() -> void:
		var font := get_theme_default_font()
		for x in Inventory.COLS:
			for y in Inventory.ROWS:
				var r := Rect2(Vector2(x, y) * cell, Vector2.ONE * cell).grow(-1.5)
				draw_rect(r, Color(1, 1, 1, 0.05))
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
		for i in Profile.bag.size():
			var e: Dictionary = Profile.bag[i]
			var r := Rect2(Vector2(e.cell) * cell, Vector2(Items.size_of(e.id)) * cell).grow(-3.0)
			var dragged: bool = _hover.get("from", "") == "bag" and _hover.get("index", -1) == i
			ItemBoard.draw_item(self, r, e.id, int(e.count), font)
			if dragged:
				draw_rect(r, Color(0, 0, 0, 0.5))
		# Where a dragged thing would land: green if it fits, red if not.
		if _inside:
			var sz := Items.size_of(_hover.id)
			var ok := Profile.bag_fits(_hover.id, _hover_cell, _hover.get("index", -1) if _hover.from == "bag" else -1)
			var at := Profile.bag_at(_hover_cell)
			if not ok and at >= 0 and Profile.bag[at].id == _hover.id:
				ok = true
			var r := Rect2(Vector2(_hover_cell) * cell, Vector2(sz) * cell).grow(-2.0)
			draw_rect(r, Color(0.4, 1.0, 0.5, 0.25) if ok else Color(1.0, 0.35, 0.3, 0.25))
			draw_rect(r, Color(0.4, 1.0, 0.5, 0.8) if ok else Color(1.0, 0.35, 0.3, 0.8), false, 2.0)


## The warehouse: one box per kind of thing on the chosen tab.
class StorageGrid extends Control:
	var board: ItemBoard
	var tab := "gear"
	var columns := 6
	var cell := 70.0
	var _lit := false

	func _init(cols := 6, cell_size := 70.0) -> void:
		columns = cols
		cell = cell_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		Profile.profile_changed.connect(queue_redraw)

	func ids() -> Array:
		return Profile.storage_ids(tab)

	func box(i: int) -> Rect2:
		return Rect2(Vector2(i % columns, i / columns) * cell, Vector2.ONE * cell).grow(-3.0)

	func target_at(_global: Vector2) -> Dictionary:
		return {"to": "storage"}

	func hover(source: Dictionary, at: Vector2) -> void:
		var lit: bool = not source.is_empty() and source.from != "storage" and get_global_rect().has_point(at)
		if lit != _lit:
			_lit = lit
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var list := ids()
			for i in list.size():
				if box(i).has_point(event.position):
					board.pressed({"from": "storage", "id": list[i]}, event.global_position)
					accept_event()
					return

	func _draw() -> void:
		var font := get_theme_default_font()
		if _lit:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 1.0, 0.5, 0.08))
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 1.0, 0.5, 0.6), false, 2.0)
		var list := ids()
		var rows := maxi(ceili(size.y / cell), ceili(list.size() / float(columns)))
		for i in columns * rows:
			var r := box(i)
			if r.end.y > size.y + 1.0:
				break
			draw_rect(r, Color(1, 1, 1, 0.04))
			draw_rect(r, Color(1, 1, 1, 0.1), false, 1.0)
		for i in list.size():
			ItemBoard.draw_item(self, box(i), list[i], Profile.stored(list[i]), font, false, true)
		if list.is_empty():
			draw_string(font, Vector2(0, cell * 0.6), "這裡還沒有東西", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
				Color(1, 1, 1, 0.35))


## An equipment slot: what's worn there, or its name greyed.
class SlotBox extends Control:
	var board: ItemBoard
	var slot := "rod"
	var title := ""
	var locked := false
	var _lit := false

	func _init(slot_key: String, slot_title: String, is_locked := false) -> void:
		slot = slot_key
		title = slot_title
		locked = is_locked
		name = "Slot_" + slot_key
		mouse_filter = Control.MOUSE_FILTER_STOP
		Profile.profile_changed.connect(queue_redraw)

	func worn() -> String:
		return Profile.equipped.get(slot, "")

	func target_at(_global: Vector2) -> Dictionary:
		return {} if locked else {"to": "slot", "slot": slot}

	func hover(source: Dictionary, at: Vector2) -> void:
		var lit: bool = not locked and not source.is_empty() and Items.def(source.id).get("slot", "") == slot \
			and get_global_rect().has_point(at)
		if lit != _lit:
			_lit = lit
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and worn() != "":
			board.pressed({"from": "slot", "id": worn(), "slot": slot}, event.global_position)
			accept_event()

	func _draw() -> void:
		var font := get_theme_default_font()
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.1, 0.095, 0.09, 0.9 if not locked else 0.5))
		draw_rect(r, MenuStyle.GOLD if _lit else MenuStyle.EDGE, false, 2.0 if _lit else 1.0)
		draw_string(font, Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MenuStyle.DIM)
		if locked:
			draw_string(font, Vector2(0, size.y / 2.0 + 8), "即將推出", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
				Color(1, 1, 1, 0.35))
			return
		var id := worn()
		if id == "":
			draw_string(font, Vector2(0, size.y / 2.0 + 8), "（空）", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
				Color(1, 1, 1, 0.35))
			return
		ItemBoard.draw_item(self, Rect2(6, 22, size.x - 12, size.y - 44), id, 1, font)
		draw_string(font, Vector2(0, size.y - 7), Items.name_of(id), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, MenuStyle.TEXT)
