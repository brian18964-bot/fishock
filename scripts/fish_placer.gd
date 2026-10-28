class_name FishPlacer
extends Control

## User request: a fish put in the bag or the warehouse from the tank page
## comes up the bag's grid (or the warehouse's slots) and the player puts it
## where they want it: the fish shows where it'd go - in green where it
## fits, red where it doesn't - and is dragged (or the cell tapped) to move
## it; the fish already in the bag can be moved about too. 放入 sets it down
## (Profile.move_fish), 取消 leaves it.

signal done(placed: bool)

const CELL := 48.0
const SLOT := Vector2(68, 60)
const STASH_COLS := 5
const FIT := Color(0.4, 1.0, 0.5)
const NO_FIT := Color(1.0, 0.4, 0.35)

## "pack" (the bag's grid) or "stash" (the warehouse's slots).
var where := "pack"
## The fish being put in (not in either list yet), where it is now: `src` list, `index`.
var fish := {}
var src := "tank"
var index := 0
## Its corner in the bag's cells; in the warehouse (slot, 0).
var at := Vector2i.ZERO

var _grid: Control
var _go: Button
var _note: Label
## The drag: {fish (which one), grab (cells off its corner), at (its corner now), new (bool)}.
var _drag := {}


func _init(place: String, from: String, i: int) -> void:
	where = place
	src = from
	index = i
	fish = Profile.fish_list(from)[i]
	name = "FishPlacer"
	var panel := UiKit.tooltip_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiKit.label("放進包包" if where == "pack" else "放進倉庫", 19, UiKit.GOLD_BRIGHT, true))
	var hint := UiKit.label("拖著%s，或點空格，放到想放的位置。" % fish.get("name", "魚"), 13, UiKit.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = _grid_size().x
	col.add_child(hint)
	_grid = Grid.new()
	_grid.name = "Grid"
	_grid.custom_minimum_size = _grid_size()
	_grid.set("placer", self)
	col.add_child(_grid)
	_note = UiKit.label("", 14, Color(1.0, 0.7, 0.5))
	col.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	_go = UiKit.button("放入", 16, "red")
	_go.name = "PlaceGo"
	_go.custom_minimum_size = Vector2(110, 42)
	_go.pressed.connect(_place)
	buttons.add_child(_go)
	var cancel := UiKit.button("取消", 16)
	cancel.name = "PlaceCancel"
	cancel.custom_minimum_size = Vector2(90, 42)
	cancel.pressed.connect(func(): done.emit(false))
	buttons.add_child(cancel)
	col.add_child(buttons)
	panel.add_child(col)
	add_child(panel)
	if where == "pack":
		at = Profile.pack_first_fit(fish)
		if at.x < 0:
			at = Vector2i.ZERO
	else:
		at = Vector2i(maxi(Profile.stash_first_free(), 0), 0)
	_check()


func _grid_size() -> Vector2:
	if where == "pack":
		return Vector2(Inventory.COLS, Inventory.ROWS) * CELL
	return Vector2(STASH_COLS, ceili(float(Profile.STASH_SIZE) / STASH_COLS)) * SLOT


## The fish's size in cells (the warehouse's: one slot).
func fish_size() -> Vector2i:
	return Inventory.fish_item(fish).size if where == "pack" else Vector2i.ONE


func fits(f: Dictionary, corner: Vector2i) -> bool:
	if where == "pack":
		return Profile.pack_fits(f, corner)
	return Profile.stash_free(corner.x, f)


## The fish already there: [{fish, rect (cells)}] (the bag's, or the warehouse's).
func others() -> Array:
	var out := []
	if where == "pack":
		var places := Profile.pack_places()
		for k in places.size():
			out.append({"fish": Profile.pack_fish[k], "rect": places[k]})
	else:
		for f in Profile.stash_fish:
			out.append({"fish": f, "rect": Rect2i(Vector2i(Profile.stash_slot(f), 0), Vector2i.ONE)})
	return out


func _check() -> void:
	var ok := fits(fish, at)
	_go.disabled = not ok
	_note.text = "" if ok else ("放不下這裡" if where == "pack" else "這格有魚了")
	_grid.queue_redraw()


func _place() -> void:
	var why := Profile.move_fish(src, index, where, at)
	if why != "":
		_note.text = why
		return
	done.emit(true)


## Moves the fish being put in to the cell `corner` (clamped to the grid).
func put_at(corner: Vector2i) -> void:
	at = _clamp(corner)
	_check()


func _clamp(c: Vector2i) -> Vector2i:
	var size := fish_size()
	if where == "pack":
		return Vector2i(clampi(c.x, 0, Inventory.COLS - size.x), clampi(c.y, 0, Inventory.ROWS - size.y))
	return Vector2i(clampi(c.x, 0, Profile.STASH_SIZE - 1), 0)


## The grid: slots, what's in them, the fish being put in.
class Grid extends Control:
	var placer: FishPlacer
	var _hover := Vector2i(-1, -1)

	func _cell_px() -> Vector2:
		return Vector2(FishPlacer.CELL, FishPlacer.CELL) if placer.where == "pack" else FishPlacer.SLOT

	## The grid cell (the warehouse's: the slot number as x) under a local point.
	func cell_at(p: Vector2) -> Vector2i:
		var px := _cell_px()
		var c := Vector2i(floori(p.x / px.x), floori(p.y / px.y))
		if placer.where == "stash":
			return Vector2i(c.y * FishPlacer.STASH_COLS + c.x, 0)
		return c

	func rect_of(corner: Vector2i, size: Vector2i) -> Rect2:
		var px := _cell_px()
		if placer.where == "stash":
			return Rect2(Vector2(corner.x % FishPlacer.STASH_COLS, corner.x / FishPlacer.STASH_COLS) * px, px)
		return Rect2(Vector2(corner) * px, Vector2(size) * px)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var c := cell_at(event.position)
				if placer.where == "pack" and (c.x < 0 or c.y < 0 or c.x >= Inventory.COLS or c.y >= Inventory.ROWS):
					return
				# The fish being put in, or one in there already, taken by the cell.
				if _covers(placer.at, placer.fish_size(), c):
					_drag = {"fish": placer.fish, "grab": c - placer.at, "at": placer.at, "new": true}
				else:
					for o in placer.others():
						var r: Rect2i = o.rect
						if _covers(r.position, r.size, c):
							_drag = {"fish": o.fish, "grab": c - r.position, "at": r.position, "new": false}
				if _drag.is_empty():
					# (an empty cell tapped: the fish goes there)
					var size := placer.fish_size()
					placer.put_at(c - Vector2i(size.x / 2, size.y / 2) if placer.where == "pack" else c)
			elif not _drag.is_empty():
				var d := _drag
				_drag = {}
				if not d.new and placer.fits(d.fish, d.at) and d.at != _from(d.fish):
					_move_existing(d.fish, d.at)
				elif d.new:
					placer.put_at(d.at)
				queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion:
			_hover = cell_at(event.position)
			if not _drag.is_empty():
				var corner: Vector2i = _hover - Vector2i(_drag.grab)
				_drag.at = placer._clamp(corner)
			queue_redraw()

	var _drag := {}

	func _covers(corner: Vector2i, size: Vector2i, c: Vector2i) -> bool:
		if placer.where == "stash":
			return corner.x == c.x
		return c.x >= corner.x and c.y >= corner.y and c.x < corner.x + size.x and c.y < corner.y + size.y

	func _from(f: Dictionary) -> Vector2i:
		for o in placer.others():
			if is_same(o.fish, f):
				return (o.rect as Rect2i).position
		return Vector2i(-1, -1)

	## A fish already in set down at `corner`.
	func _move_existing(f: Dictionary, corner: Vector2i) -> void:
		if placer.where == "pack":
			f["cell"] = [corner.x, corner.y]
		else:
			f["slot"] = corner.x
		Profile.profile_changed.emit()

	func _draw() -> void:
		var px := _cell_px()
		var cols := Inventory.COLS if placer.where == "pack" else FishPlacer.STASH_COLS
		var rows := Inventory.ROWS if placer.where == "pack" else ceili(float(Profile.STASH_SIZE) / FishPlacer.STASH_COLS)
		var open_rows := Profile.bag_rows() if placer.where == "pack" else rows
		for y in rows:
			for x in cols:
				var r := Rect2(Vector2(x, y) * px, px).grow(-1.5)
				UiKit.draw_slot(self, r)
				if y >= open_rows or (placer.where == "stash" and y * cols + x >= Profile.STASH_SIZE):
					draw_rect(r, Color(0, 0, 0, 0.55))
		# What's in the bag already (the bag's things, then the fish).
		if placer.where == "pack":
			var items := Inventory.items(null)
			var placed := Inventory.pack(items)
			for k in placed.size():
				if items[k].kind == "fish":
					continue
				var r := rect_of((placed[k] as Rect2i).position, (placed[k] as Rect2i).size).grow(-2.5)
				draw_rect(r, Color(0.16, 0.14, 0.1, 0.92))
				draw_rect(r, Color(0.5, 0.45, 0.3, 0.8), false, 1.0)
				var tex: Texture2D = Items.square_icon(items[k].item) if items[k].has("item") else null
				if tex != null:
					draw_texture_rect(tex, r.grow(-3.0), false)
				else:
					UiKit.draw_text(self, r.position + Vector2(4, r.size.y * 0.5 + 5), str(items[k].label), 12, UiKit.TEXT,
						HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8.0)
		for o in placer.others():
			if not _drag.is_empty() and is_same(_drag.fish, o.fish):
				continue
			var rc: Rect2i = o.rect
			_draw_fish(o.fish, rect_of(rc.position, rc.size).grow(-2.5), false)
		# The one being put in (or a held one, where it'd land).
		var shown := placer.fish
		var corner := placer.at
		if not _drag.is_empty():
			shown = _drag.fish
			corner = _drag.at
		var ok := placer.fits(shown, corner) if not _drag.is_empty() else placer.fits(placer.fish, placer.at)
		var rect := rect_of(corner, Inventory.fish_item(shown).size if placer.where == "pack" else Vector2i.ONE).grow(-2.5)
		_draw_fish(shown, rect, true)
		var tint := FishPlacer.FIT if ok else FishPlacer.NO_FIT
		draw_rect(rect, Color(tint, 0.18))
		draw_rect(rect, Color(tint, 0.95), false, 3.0)

	func _draw_fish(f: Dictionary, r: Rect2, fresh: bool) -> void:
		UiKit.draw_slot(self, r, UiKit.fish_rarity(f), fresh)
		var tex := FishData.icon(f.get("id", ""), f.get("name", ""))
		if tex != null:
			var room := r.grow(-4.0)
			var k := minf(room.size.x / tex.get_width(), room.size.y / tex.get_height())
			var sz := Vector2(tex.get_size()) * k
			var tint := Color(0.55, 0.5, 0.35) if FishLife.state(f) == "rotten" else (Color(0.75, 0.75, 0.8) if FishLife.state(f) == "dead" else Color.WHITE)
			draw_texture_rect(tex, Rect2(room.get_center() - sz / 2.0, sz), false, tint)
