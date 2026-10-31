class_name OxyPanel
extends Control

## User request: the oxygenated fish box, opened with 使用 (worn or in the bag): its grid, two
## across and three down, and beside it the fish carried. A fish takes the cells its size does
## (a medium one two, lying or standing), as in the bag. Drag a carried fish to any free place
## in the box, or tap it to have it laid in; drag one inside the box to move it; tap one in
## the box (or drag it out to the right) to take it out - each in or out a use of the box's
## durability (GameState.oxy_put / oxy_take). What's in it doesn't run down.

signal closed

const CELL := 84.0
const TILE := Vector2(112, 62)
const PER_PAGE := 12

var _head: Label
var _box: Tiles
var _carried: Tiles
var _note: Label
var _page := 0
var _ghost: Control
var _t := 0.0


func _init() -> void:
	name = "OxyPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := UiKit.tooltip_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_head = UiKit.label("", 19, UiKit.GOLD_BRIGHT, true)
	col.add_child(_head)
	var sub := UiKit.label("放進魚箱的魚活性不會下降。魚依大小佔格：把右邊的魚拖進箱子的空位，或點一下讓系統排好；點箱子裡的魚拿出來（各用掉 1 點耐久）。", 13, UiKit.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 640
	col.add_child(sub)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	_box = Tiles.new()
	_box.name = "Slots"
	_box.panel = self
	_box.source = "box"
	_box.cols = Profile.OXY_COLS
	_box.rows = Profile.OXY_ROWS
	_box.cell = CELL
	_box.custom_minimum_size = Vector2(Profile.OXY_COLS, Profile.OXY_ROWS) * CELL
	body.add_child(_box)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.add_child(UiKit.label("身上帶著的魚", 15, UiKit.TEXT))
	_carried = Tiles.new()
	_carried.name = "Carried"
	_carried.panel = self
	_carried.source = "carried"
	_carried.cols = 3
	_carried.rows = 4
	_carried.custom_minimum_size = Vector2(3 * TILE.x + 12.0, 4 * TILE.y + 18.0)
	right.add_child(_carried)
	var pager := HBoxContainer.new()
	var prev := UiKit.button("◀", 14)
	prev.name = "Prev"
	prev.pressed.connect(func(): _turn(-1))
	var next := UiKit.button("▶", 14)
	next.name = "Next"
	next.pressed.connect(func(): _turn(1))
	pager.add_child(prev)
	pager.add_child(next)
	right.add_child(pager)
	body.add_child(right)
	col.add_child(body)
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
		_box.queue_redraw()
		_carried.queue_redraw()


func _turn(by: int) -> void:
	var pages := maxi(ceili(GameState.carried_fish.size() / float(PER_PAGE)), 1)
	_page = clampi(_page + by, 0, pages - 1)
	refresh()


func refresh() -> void:
	var cells := 0
	for it in GameState.oxy_items():
		cells += it.size.x * it.size.y
	_head.text = "打氧魚箱　%d / %d 格　耐久 %d / %d" % [cells, Profile.OXY_COLS * Profile.OXY_ROWS,
		Profile.durability("oxy_box"), Profile.max_durability("oxy_box")]
	_box.fish = GameState.oxy_fish
	var placed := GameState.oxy_placed()
	_box.rects.clear()
	for i in GameState.oxy_fish.size():
		var r: Rect2i = placed[i] if not placed.is_empty() else Rect2i()
		_box.rects.append(Rect2(Vector2(r.position) * CELL, Vector2(r.size) * CELL))
	_box.placed = placed
	var pages := maxi(ceili(GameState.carried_fish.size() / float(PER_PAGE)), 1)
	_page = clampi(_page, 0, pages - 1)
	_carried.fish = []
	_carried.indices = []
	_carried.rects.clear()
	for k in PER_PAGE:
		var i := _page * PER_PAGE + k
		if i >= GameState.carried_fish.size():
			break
		_carried.fish.append(GameState.carried_fish[i])
		_carried.indices.append(i)
		_carried.rects.append(Rect2(Vector2(k % 3, k / 3) * (TILE + Vector2(3, 3)), TILE))
	_box.queue_redraw()
	_carried.queue_redraw()


func _say(why: String) -> void:
	_note.text = why
	if why != "":
		GameState.push_message(why)
	refresh()


## A tap: a carried fish laid in by the system, one in the box taken out.
func tap(source: String, i: int) -> void:
	if source == "carried":
		_say(GameState.oxy_put(_carried.indices[i]))
	else:
		_say(GameState.oxy_take(i))


func drag_start(fish: Dictionary) -> void:
	_ghost = Control.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.size = Vector2.ONE * 56.0
	var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
	_ghost.draw.connect(func():
		if tex != null:
			UiKit.draw_fish_fit(_ghost, Rect2(Vector2.ZERO, _ghost.size), tex, Color(1, 1, 1, 0.85)))
	add_child(_ghost)


func drag_move(at: Vector2) -> void:
	if _ghost != null:
		_ghost.position = at - _ghost.size * 0.5


## Let go at `at` (global): a carried fish over the box goes where it's put; one in the box
## over the box moves there, over the carried list is taken out.
func drag_end(source: String, i: int, at: Vector2, grab: Vector2i) -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_box.preview = Rect2i()
	var over_box := _box.get_global_rect().has_point(at)
	if source == "carried":
		if over_box:
			_say(GameState.oxy_put(_carried.indices[i], _box.cell_at(at) - grab))
	else:
		if over_box:
			_say(GameState.oxy_move(i, _box.cell_at(at) - grab))
		elif _carried.get_global_rect().has_point(at):
			_say(GameState.oxy_take(i))
	refresh()


## Where a fish dragged would land (cells; shown green or red).
func drag_preview(source: String, i: int, at: Vector2, grab: Vector2i) -> void:
	if not _box.get_global_rect().has_point(at):
		_box.preview = Rect2i()
		_box.queue_redraw()
		return
	var fish: Dictionary = _carried.fish[i] if source == "carried" else GameState.oxy_fish[i]
	var size: Vector2i = Inventory.rotated(Inventory.SIZES[Inventory.fish_size(fish)], bool(fish.get("rot", false)))
	var cell := _box.cell_at(at) - grab
	_box.preview = Rect2i(cell, size)
	var list := GameState.oxy_fish.duplicate()
	var probe := fish.duplicate()
	probe["cell"] = [cell.x, cell.y]
	if source == "box":
		list[i] = probe
	else:
		list.append(probe)
	var laid := GameState.oxy_placed(list)
	_box.preview_ok = GameState._oxy_holds(list, laid)
	_box.queue_redraw()


## Fish as tiles: the box's on its grid, the carried ones in a list.
class Tiles extends Control:
	var panel: OxyPanel
	var source := "box"
	var fish: Array = []
	var indices: Array = []
	var rects: Array = []
	var placed: Array = []
	var cols := 2
	var rows := 3
	var cell := 0.0
	var preview := Rect2i()
	var preview_ok := false
	var _press := -1
	var _press_at := Vector2.ZERO
	var _grab := Vector2i.ZERO
	var _dragging := false

	func cell_at(at: Vector2) -> Vector2i:
		var local: Vector2 = get_global_transform().affine_inverse() * at
		return Vector2i(floori(local.x / cell), floori(local.y / cell))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press = -1
				_dragging = false
				for i in rects.size():
					if (rects[i] as Rect2).has_point(event.position):
						_press = i
						_press_at = event.position
						_grab = Vector2i(((_press_at - (rects[i] as Rect2).position) / cell).floor()) if cell > 0.0 else Vector2i.ZERO
				accept_event()
			else:
				if _press >= 0 and _press < fish.size():
					if _dragging:
						panel.drag_end(source, _press, get_global_transform() * event.position, _grab)
					else:
						panel.tap(source, _press)
				_press = -1
				_dragging = false
				accept_event()
		elif event is InputEventMouseMotion and _press >= 0 and _press < fish.size():
			if not _dragging and event.position.distance_to(_press_at) > 10.0:
				_dragging = true
				panel.drag_start(fish[_press])
			if _dragging:
				var at: Vector2 = get_global_transform() * event.position
				panel.drag_move(at)
				panel.drag_preview(source, _press, at, _grab)
			accept_event()

	func _draw() -> void:
		if cell > 0.0:
			for x in cols:
				for y in rows:
					UiKit.draw_slot(self, Rect2(Vector2(x, y) * cell, Vector2.ONE * cell).grow(-1.5))
		for i in fish.size():
			var f: Dictionary = fish[i]
			var r: Rect2 = (rects[i] as Rect2).grow(-2.0)
			UiKit.draw_slot(self, r, UiKit.fish_rarity(f), false, null)
			var tex := FishData.icon(f.get("id", ""), f.get("name", ""))
			var inner := r.grow(-4.0)
			if tex != null:
				UiKit.draw_fish_fit(self, inner.grow(-2.0), tex, Color(0.75, 0.78, 0.8) if f.get("dead", false) else Color.WHITE)
			UiKit.draw_text(self, r.position + Vector2(4, 14), str(f.get("name", "魚")), 12, UiKit.rarity_color(UiKit.fish_rarity(f)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0)
			if FishLife.has_life(f):
				var bar := FishLife.bar(f)
				var strip := Rect2(Vector2(inner.position.x + 3.0, inner.end.y - 6.0), Vector2(inner.size.x - 6.0, 4.0))
				draw_rect(strip, Color(0, 0, 0, 0.6))
				var colr: Color = FishVitals.FRESH_COLOR if bar.kind == "fresh" else (FishVitals.ROT_COLOR if bar.kind == "rotten" \
					else FishVitals.VIT_COLOR.lerp(FishVitals.VIT_LOW, 1.0 - clampf(float(bar.share) * 2.0, 0.0, 1.0)))
				draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(float(bar.share), 0.0, 1.0), strip.size.y)), colr)
		if preview.size != Vector2i.ZERO and cell > 0.0:
			var pr := Rect2(Vector2(preview.position) * cell, Vector2(preview.size) * cell).grow(-1.0)
			var shown := pr.intersection(Rect2(Vector2.ZERO, Vector2(cols, rows) * cell))
			draw_rect(shown, Color(0.4, 0.9, 0.5, 0.28) if preview_ok else Color(0.95, 0.3, 0.25, 0.28))
			draw_rect(shown, Color(0.5, 1.0, 0.6, 0.8) if preview_ok else Color(1.0, 0.4, 0.35, 0.8), false, 2.0)
