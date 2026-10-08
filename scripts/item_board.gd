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

## (not under DragScroll.SLOP: a list's scroll decides first)
const DRAG_START := 8.0
const TAB_COLORS := {
	"gear": Color(0.3, 0.26, 0.4), "item": Color(0.42, 0.36, 0.18), "tackle": Color(0.2, 0.4, 0.34),
	"other": Color(0.3, 0.3, 0.32),
}

## The bag page (user request): things in the bag can be thrown away.
var can_discard := false
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


## A DragScroll took the press for a scroll: it's neither a tap nor a drag.
func cancel_press() -> void:
	_press = {}
	if _dragging:
		_end_drag()


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
	# User request: dragged, a thing shows as its simple square icon, one
	# cell big - not its whole picture.
	_ghost = TextureRect.new()
	var square := Items.square_icon(_press.id)
	_ghost.texture = square if square != null else Items.icon(_press.id)
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.size = Vector2.ONE * 64.0
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
		["bag", "discard"]:
			return Profile.bag_discard(source.index, count) > 0
		["slot", "storage"]:
			return Profile.unequip(source.slot)
		["slot", "bag"]:
			if not Profile.unequip(source.slot):
				return false
			return Profile.to_bag(id, 1, target.get("cell", Vector2i(-1, -1))) > 0
	return false


## The card for a tapped thing (an MMO tooltip): its picture and name in
## its rarity's colour, what it is and does, how many (a stepper, for
## stacks) and what can be done with it here.
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
	var panel := UiKit.tooltip_panel()
	panel.custom_minimum_size = Vector2(400, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var rarity := UiKit.item_rarity(id)
	if Items.model_path(id) != "":
		var pv := ItemPreview.new()
		pv.name = "Preview"
		pv.custom_minimum_size = Vector2(370, 130)
		col.add_child(pv)
		pv.show_item(id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(ItemBoard.icon_box(id, 72.0))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.add_child(UiKit.label(def.name, 21, UiKit.rarity_color(rarity), true))
	words.add_child(UiKit.label("%s %s" % [UiKit.rarity_name(rarity), Items.TABS.get(def.tab, "")], 14, UiKit.rarity_color(rarity)))
	var where := {"storage": "在倉庫", "bag": "在背包", "slot": "穿戴中"}
	words.add_child(UiKit.label("%s ×%d" % [where[source.from], have], 14, UiKit.DIM))
	head.add_child(words)
	col.add_child(head)
	for line in ItemBoard.desc_lines(id):
		var l := UiKit.label(line[0], 15, line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 370
		col.add_child(l)

	# How many (stacks only).
	var amount := [have]
	if have > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.label("數量", 15, UiKit.DIM))
		var less := UiKit.button("－", 18)
		var more := UiKit.button("＋", 18)
		var slider := HSlider.new()
		slider.min_value = 1
		slider.max_value = have
		slider.step = 1
		slider.value = have
		slider.custom_minimum_size = Vector2(150, 30)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var shown := UiKit.label(str(have), 18, UiKit.GOLD_BRIGHT)
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
		var b := UiKit.button(act[0], 15, "red" if act.size() > 2 and act[2] else "gray")
		b.name = "Act_" + act[0]
		b.custom_minimum_size = Vector2(100, 42)
		var target: Dictionary = act[1]
		if target.to == "discard":
			# Thrown away for good: a second press to be sure.
			b.pressed.connect(func():
				if b.text != "確定丟棄？":
					b.text = "確定丟棄？"
					return
				move(source, target, amount[0])
				_close_card())
			acts.add_child(b)
			continue
		b.pressed.connect(func():
			move(source, target, amount[0])
			_close_card())
		acts.add_child(b)
	var cancel := UiKit.button("取消", 15)
	cancel.custom_minimum_size = Vector2(80, 42)
	cancel.pressed.connect(_close_card)
	acts.add_child(cancel)
	col.add_child(acts)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = (size - panel.size) / 2.0


## A thing's tooltip lines, [text, colour]: a rod's numbers one per line
## in white, what a bait or tool does in green (like an MMO's "use:").
static func desc_lines(id: String) -> Array:
	var def := Items.def(id)
	var out := []
	if id.begins_with("rod_"):
		for part in Items.rod_effects(Profile.ROD_TIERS[int(id.substr(4))]).split("、"):
			out.append([part, UiKit.TEXT])
		out.append(["裝備：換上後，下一輪釣魚就用這支", UiKit.USE])
	elif def.get("desc", "") != "":
		out.append(["使用：" + def.desc, UiKit.USE])
	if Profile.max_durability(id) > 0:
		out.append(["耐久度 %d / %d（每次使用少 1，用完就壞了，要再買新的）" % [Profile.durability(id), Profile.max_durability(id)],
			wear_color(id)])
	return out


## User request (durability): how worn a thing is - a thin bar along the
## bottom of its slot, green to red; nothing for things that don't wear.
static func draw_wear(ci: CanvasItem, r: Rect2, id: String) -> void:
	var most := Profile.max_durability(id)
	if most <= 0:
		return
	var share := clampf(float(Profile.durability(id)) / most, 0.0, 1.0)
	var bar := Rect2(r.position.x + 4.0, r.end.y - 7.0, r.size.x - 8.0, 3.0)
	ci.draw_rect(bar, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), wear_color(id))


static func wear_color(id: String) -> Color:
	var most := Profile.max_durability(id)
	var share := float(Profile.durability(id)) / most if most > 0 else 1.0
	if share > 0.5:
		return Color(0.5, 0.9, 0.45)
	if share > 0.2:
		return Color(0.95, 0.8, 0.3)
	return Color(1.0, 0.4, 0.3)


## A thing's picture in a slot (a Control): the square, its rarity ring,
## the picture.
static func icon_box(id: String, side := 64.0) -> Control:
	var box := ItemIcon.new()
	box.id = id
	box.custom_minimum_size = Vector2(side, side)
	return box


class ItemIcon extends Control:
	var id := ""
	var count := 0

	func _draw() -> void:
		ItemBoard.draw_item(self, Rect2(Vector2.ZERO, size), id, count, get_theme_default_font())


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
				if can_discard:
					out.append(["丟棄", {"to": "discard"}])
	if slot != "" and source.from != "slot":
		out.append(["裝備", {"to": "slot", "slot": slot}])
	return out


func _close_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


## Draws one thing in a slot: the sunken square with its rarity's ring, a
## soft glow of its kind's colour, its picture, its count (and its name,
## `named`, along the bottom).
static func draw_item(ci: CanvasItem, r: Rect2, id: String, count: int, _font: Font, lit := false, named := false) -> void:
	var def := Items.def(id)
	var rarity := UiKit.item_rarity(id)
	# A square slot shows the thing's square icon (the MMO look); a long
	# one (a rod's three cells) its picture, laid along it.
	var square := Items.square_icon(id) if absf(r.size.x - r.size.y) < r.size.y * 0.25 else null
	UiKit.draw_slot(ci, r, rarity, lit, square)
	var col: Color = TAB_COLORS.get(def.get("tab", "other"), Color.GRAY)
	var inner := r.grow(-4.0)
	var tex := Items.icon(id) if square == null else null
	if tex != null:
		ci.draw_texture_rect(UiKit.glow(), inner, false, Color(col.lightened(0.35), 0.45))
		var room := inner.grow(-3.0)
		if named:
			room.size.y -= 12.0
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
	if named:
		UiKit.draw_text(ci, Vector2(r.position.x, r.end.y - 6.0), def.get("name", ""), 11 if r.size.x < 80.0 else 13,
			UiKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if count > 1:
		UiKit.draw_text(ci, Vector2(r.position.x, r.end.y - (18.0 if named else 5.0)), str(count), 14, Color.WHITE,
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6.0)
	draw_wear(ci, r, id)


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
				UiKit.draw_slot(self, Rect2(Vector2(x, y) * cell, Vector2.ONE * cell).grow(-1.5))
		UiKit.draw_shut_rows(self, cell)
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


## The warehouse: one box per kind of thing on the chosen tab. User request:
## the boxes big enough to tap, the grid in a DragScroll - as tall as what's
## on the tab (at least `min_rows`), scrolled when that's more than shows.
class StorageGrid extends Control:
	var board: ItemBoard
	var tab := "gear":
		set(value):
			tab = value
			refit()
	var columns := 6
	var cell := 70.0
	var min_rows := 1
	var _lit := false

	func _init(cols := 6, cell_size := 70.0, rows := 1) -> void:
		columns = cols
		cell = cell_size
		min_rows = rows
		mouse_filter = Control.MOUSE_FILTER_STOP
		Profile.profile_changed.connect(func():
			refit()
			queue_redraw())
		refit()

	func ids() -> Array:
		return Profile.storage_ids(tab)

	func refit() -> void:
		var rows := maxi(min_rows, ceili(ids().size() / float(columns)))
		custom_minimum_size = Vector2(columns, rows) * cell
		queue_redraw()

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
			UiKit.draw_slot(self, r)
		for i in list.size():
			ItemBoard.draw_item(self, box(i), list[i], Profile.stored(list[i]), font, false, true)
		if list.is_empty():
			UiKit.draw_text(self, Vector2(0, cell * 0.6), "這裡還沒有東西", 15, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x)


## An equipment slot: what's worn there, or its name greyed.
class SlotBox extends Control:
	const LAMP_ICON := "res://assets/sprites/items/oil_lamp.png"
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

	## The slot as a square on the left (the thing worn, or the slot's
	## faint mark), its name and the thing's beside it - like a paper doll's
	## slot with its label.
	func _draw() -> void:
		var side := minf(size.y, size.x)
		var sq := Rect2(Vector2.ZERO, Vector2(side, side))
		var id := worn()
		var text_x := side + 10.0
		if locked:
			UiKit.draw_slot(self, sq)
			draw_rect(sq.grow(-4.0), Color(0, 0, 0, 0.45))
			_lock(sq.get_center())
		elif id == "":
			UiKit.draw_slot(self, sq, "", _lit)
			if slot == "light":
				# Nothing worn: the oil lamp every run starts with.
				var lamp: Texture2D = Items.texture(LAMP_ICON)
				var room := sq.grow(-9.0)
				var k := minf(room.size.x / lamp.get_width(), room.size.y / lamp.get_height())
				var sz := Vector2(lamp.get_size()) * k
				draw_texture_rect(lamp, Rect2(room.get_center() - sz / 2.0, sz), false, Color(1, 1, 1, 0.8))
		else:
			ItemBoard.draw_item(self, sq, id, 1, null, _lit)
		if size.x - side < 50.0:
			return
		UiKit.draw_text(self, Vector2(text_x, side * 0.5 - 4.0), title, 13, UiKit.DIM)
		var line := "即將推出" if locked else ("（空）" if id == "" else Items.name_of(id))
		if slot == "light" and id == "" and not locked:
			line = "隨身煤燈"
		var col := UiKit.DIM if locked or id == "" else UiKit.rarity_color(UiKit.item_rarity(id))
		UiKit.draw_text(self, Vector2(text_x, side * 0.5 + 16.0), line, 16 if size.x - text_x > 110.0 else 14, col,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x, true)

	func _lock(c: Vector2) -> void:
		var ink := Color(0.6, 0.56, 0.5, 0.8)
		draw_arc(c + Vector2(0, -4), 7.0, PI, TAU, 16, ink, 2.5)
		draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 14)), ink)
