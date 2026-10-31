class_name FishFlyout
extends Control

## User request (the fish box and the live-fish clasp, the same everywhere - in a run's bag, at
## camp's equipment, bag and warehouse): 使用 on one, or a fish dragged onto it, opens a small
## window of cells beside its icon. The fish are dragged into the cells by hand (a fish takes
## the cells its size does; turned with R, or a tap on it), moved about in them, and dragged
## out to take them out. The window's `store` (OxyStore / ClaspStore) does the moving.

signal closed
signal said(text: String)

const CELL := 64.0
const PAD := 10.0
const HEAD := 30.0

var store
var anchor := Rect2()
var _grid: Tiles
var _title: Label
var _hint: Label
var _ghost: Control


func _init(the_store, near: Rect2) -> void:
	store = the_store
	anchor = near
	name = "FishFlyout"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var cols: int = store.cols()
	var rows: int = store.rows()
	var inner := Vector2(cols, rows) * CELL
	var w := maxf(inner.x, 150.0) + PAD * 2.0
	var extra: float = 34.0 if store.has_method("extra_label") else 0.0
	size = Vector2(w, inner.y + PAD * 2.0 + HEAD + 34.0 + extra)
	_place()
	_title = UiKit.label("", 14, UiKit.GOLD_BRIGHT, true)
	_title.position = Vector2(PAD, 4)
	_title.size = Vector2(w - 40.0, HEAD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var x := UiKit.button("✕", 14)
	x.name = "Close"
	x.position = Vector2(w - 34.0, 2)
	x.size = Vector2(28, 26)
	x.pressed.connect(close)
	add_child(x)
	_grid = Tiles.new()
	_grid.name = "Cells"
	_grid.flyout = self
	_grid.position = Vector2(PAD + (w - PAD * 2.0 - inner.x) * 0.5, HEAD + PAD * 0.5)
	_grid.size = inner
	add_child(_grid)
	_hint = UiKit.label(str(store.hint()), 11, UiKit.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(PAD, HEAD + inner.y + PAD)
	_hint.size = Vector2(w - PAD * 2.0, 32)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	if extra > 0.0:
		var b := UiKit.button(str(store.extra_label()), 13)
		b.name = "Extra"
		b.position = Vector2(PAD, size.y - 36.0)
		b.size = Vector2(w - PAD * 2.0, 28)
		b.pressed.connect(func():
			var why: String = store.extra_do()
			if why == "!close":
				close()
			else:
				_say(why))
		add_child(b)
	refresh()


func _draw() -> void:
	draw_style_box(UiKit.frame_box(true), Rect2(Vector2.ZERO, size))


func _process(_delta: float) -> void:
	if _grid != null:
		_grid.queue_redraw()


## Beside the icon: its right, else its left, else under or over it - kept on the screen.
func _place() -> void:
	var screen := Vector2(960, 540)
	var at := Vector2(anchor.end.x + 8.0, anchor.position.y)
	if at.x + size.x > screen.x - 4.0:
		at.x = anchor.position.x - 8.0 - size.x
	if at.x < 4.0:
		at = Vector2(anchor.position.x, anchor.end.y + 8.0)
		if at.y + size.y > screen.y - 4.0:
			at.y = anchor.position.y - 8.0 - size.y
	global_position = Vector2(clampf(at.x, 4.0, screen.x - size.x - 4.0), clampf(at.y, 4.0, screen.y - size.y - 4.0))


func close() -> void:
	closed.emit()
	queue_free()


func refresh() -> void:
	if _grid == null:
		return
	_title.text = store.title()
	_grid.fish = store.list()
	var placed: Array = store.placed()
	_grid.rects.clear()
	for i in _grid.fish.size():
		var r: Rect2i = placed[i] if not placed.is_empty() else Rect2i()
		_grid.rects.append(Rect2(Vector2(r.position) * CELL, Vector2(r.size) * CELL))
	_grid.queue_redraw()


func _say(why: String) -> void:
	if why != "":
		said.emit(why)
		GameState.push_message(why)
	refresh()


## Is the global point over the window?
func contains(at: Vector2) -> bool:
	return get_global_rect().has_point(at)


func cell_at(at: Vector2) -> Vector2i:
	var local: Vector2 = _grid.get_global_transform().affine_inverse() * at
	return Vector2i(floori(local.x / CELL), floori(local.y / CELL))


## A fish dragged in from elsewhere (`fish`; `grab` its grabbed cell) is over `at`: shows
## where it would go, green or red.
func hover_fish(fish: Dictionary, at: Vector2, grab := Vector2i.ZERO) -> void:
	if not contains(at):
		_grid.preview = Rect2i()
		_grid.queue_redraw()
		return
	var cell := cell_at(at) - grab
	_grid.preview = Rect2i(cell, store.size_of(fish))
	_grid.preview_ok = store.fits(fish, cell)
	_grid.queue_redraw()


## Which cell of a fish being held is the one to hold it by (its middle).
func centered_grab(fish: Dictionary) -> Vector2i:
	var sz: Vector2i = store.size_of(fish)
	return Vector2i((sz.x - 1) / 2, (sz.y - 1) / 2)


func clear_hover() -> void:
	_grid.preview = Rect2i()
	_grid.queue_redraw()


## A fish let go over `at` (from `from`'s list, index `index`): put in where it's over. False
## if it wasn't over the window.
func drop_fish(from: Array, index: int, at: Vector2, grab := Vector2i.ZERO) -> bool:
	clear_hover()
	if not contains(at):
		return false
	_say(store.put(from, index, cell_at(at) - grab))
	return true


## A fish dragged inside the window.
func drag_start(fish: Dictionary) -> void:
	_ghost = Control.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.size = Vector2.ONE * 52.0
	_ghost.z_index = 70
	var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
	_ghost.draw.connect(func():
		if tex != null:
			UiKit.draw_fish_fit(_ghost, Rect2(Vector2.ZERO, _ghost.size), tex, Color(1, 1, 1, 0.85)))
	get_tree().current_scene.add_child(_ghost) if get_tree().current_scene != null else add_child(_ghost)


func drag_move(fish: Dictionary, index: int, at: Vector2, grab: Vector2i) -> void:
	if _ghost != null:
		_ghost.global_position = at - _ghost.size * 0.5
	if contains(at):
		var cell := cell_at(at) - grab
		_grid.preview = Rect2i(cell, store.size_of(fish))
		_grid.preview_ok = store.fits(fish, cell, index)
	else:
		_grid.preview = Rect2i()
	_grid.queue_redraw()


func drag_end(index: int, at: Vector2, grab: Vector2i) -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	clear_hover()
	if contains(at):
		_say(store.move(index, cell_at(at) - grab))
	else:
		_say(store.take(index))


func tap(index: int) -> void:
	_say(store.rotate(index))


func _unhandled_key_input(event: InputEvent) -> void:
	# R while a fish is held in the window turns it
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and _grid != null and _grid._dragging:
		_say(store.rotate(_grid._press))


## The fish in their cells.
class Tiles extends Control:
	var flyout: FishFlyout
	var fish: Array = []
	var rects: Array = []
	var preview := Rect2i()
	var preview_ok := false
	var _press := -1
	var _press_at := Vector2.ZERO
	var _grab := Vector2i.ZERO
	var _dragging := false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press = -1
				_dragging = false
				for i in rects.size():
					if (rects[i] as Rect2).has_point(event.position):
						_press = i
						_press_at = event.position
						_grab = Vector2i(((_press_at - (rects[i] as Rect2).position) / FishFlyout.CELL).floor())
				accept_event()
			else:
				if _press >= 0 and _press < fish.size():
					if _dragging:
						flyout.drag_end(_press, get_global_transform() * event.position, _grab)
					else:
						flyout.tap(_press)
				_press = -1
				_dragging = false
				accept_event()
		elif event is InputEventMouseMotion and _press >= 0 and _press < fish.size():
			if not _dragging and event.position.distance_to(_press_at) > 10.0:
				_dragging = true
				flyout.drag_start(fish[_press])
			if _dragging:
				flyout.drag_move(fish[_press], _press, get_global_transform() * event.position, _grab)
			accept_event()

	func _draw() -> void:
		for x in int(size.x / FishFlyout.CELL):
			for y in int(size.y / FishFlyout.CELL):
				UiKit.draw_slot(self, Rect2(Vector2(x, y) * FishFlyout.CELL, Vector2.ONE * FishFlyout.CELL).grow(-1.5))
		for i in fish.size():
			var f: Dictionary = fish[i]
			var r: Rect2 = (rects[i] as Rect2).grow(-2.0)
			UiKit.draw_slot(self, r, UiKit.fish_rarity(f), false, null)
			var tex := FishData.icon(f.get("id", ""), f.get("name", ""))
			var inner := r.grow(-4.0)
			if tex != null:
				UiKit.draw_fish_fit(self, inner.grow(-2.0), tex, Color(0.75, 0.78, 0.8) if f.get("dead", false) else Color.WHITE)
			UiKit.draw_text(self, r.position + Vector2(4, 14), str(f.get("name", "魚")), 11, UiKit.rarity_color(UiKit.fish_rarity(f)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0)
			if FishLife.has_life(f):
				var bar := FishLife.bar(f)
				var strip := Rect2(Vector2(inner.position.x + 3.0, inner.end.y - 6.0), Vector2(inner.size.x - 6.0, 4.0))
				draw_rect(strip, Color(0, 0, 0, 0.6))
				var colr: Color = FishVitals.FRESH_COLOR if bar.kind == "fresh" else (FishVitals.ROT_COLOR if bar.kind == "rotten" \
					else FishVitals.VIT_COLOR.lerp(FishVitals.VIT_LOW, 1.0 - clampf(float(bar.share) * 2.0, 0.0, 1.0)))
				draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(float(bar.share), 0.0, 1.0), strip.size.y)), colr)
		if preview.size != Vector2i.ZERO:
			var pr := Rect2(Vector2(preview.position) * FishFlyout.CELL, Vector2(preview.size) * FishFlyout.CELL).grow(-1.0)
			var shown := pr.intersection(Rect2(Vector2.ZERO, size))
			draw_rect(shown, Color(0.4, 0.9, 0.5, 0.28) if preview_ok else Color(0.95, 0.3, 0.25, 0.28))
			draw_rect(shown, Color(0.5, 1.0, 0.6, 0.8) if preview_ok else Color(1.0, 0.4, 0.35, 0.8), false, 2.0)
