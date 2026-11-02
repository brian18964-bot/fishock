class_name Locks
extends RefCounted

## User request: any fish or thing can be locked (a little padlock on it) so it isn't lost by a
## slip - a prized fish with its affixes offered at the altar, sold at camp. Locked, it can't be
## offered, sold, thrown away, put down or thrown as a lure; it can still be moved about, put in
## the fish box or on a clasp, worn, used. A dead fish can be locked too.
##
## Where the lock lives: a fish carries it (fish.locked); a bag stack too (Profile.bag[i].locked);
## the warehouse keeps one per kind of thing (Profile.storage_locks[id]) - its stacks are a count
## per kind. A stack moved between the bag and the warehouse takes its lock with it.

const SAID := "已上鎖，先解鎖才能這樣做"


static func fish(f: Dictionary) -> bool:
	return bool(f.get("locked", false))


static func set_fish(f: Dictionary, on: bool) -> void:
	if on:
		f["locked"] = true
	else:
		f.erase("locked")
	Profile.profile_changed.emit()


## Bag stack `index` (Profile.bag).
static func bag(index: int) -> bool:
	return index >= 0 and index < Profile.bag.size() and bool(Profile.bag[index].get("locked", false))


static func set_bag(index: int, on: bool) -> void:
	if index < 0 or index >= Profile.bag.size():
		return
	if on:
		Profile.bag[index]["locked"] = true
	else:
		Profile.bag[index].erase("locked")
	Profile.profile_changed.emit()


## The warehouse's `id`.
static func stored(id: String) -> bool:
	return bool(Profile.storage_locks.get(id, false))


static func set_stored(id: String, on: bool) -> void:
	if on:
		Profile.storage_locks[id] = true
	else:
		Profile.storage_locks.erase(id)
	Profile.profile_changed.emit()


## The padlock drawn in the top right corner of `r` on `ci` (a CanvasItem's draw).
static func draw(ci: CanvasItem, r: Rect2) -> void:
	var s := clampf(minf(r.size.x, r.size.y) * 0.22, 9.0, 14.0)
	var at := Vector2(r.end.x - s - 3.0, r.position.y + 3.0)
	var body := Rect2(at + Vector2(0, s * 0.45), Vector2(s, s * 0.6))
	ci.draw_rect(body.grow(1.5), Color(0, 0, 0, 0.7))
	ci.draw_arc(Vector2(body.get_center().x, body.position.y), s * 0.32, PI, TAU, 10, Color(0, 0, 0, 0.7), 4.0, true)
	ci.draw_arc(Vector2(body.get_center().x, body.position.y), s * 0.32, PI, TAU, 10, UiKit.GOLD_BRIGHT, 2.0, true)
	ci.draw_rect(body, UiKit.GOLD_BRIGHT)
	ci.draw_circle(body.get_center(), s * 0.09, Color(0.15, 0.1, 0.05))


## The padlock as a button (LockToggle): a dark round, the lock in it - shut and gold, or its
## shackle up and open, dim.
static func draw_icon(ci: CanvasItem, r: Rect2, locked: bool) -> void:
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.5
	ci.draw_circle(c, rad, Color(0.05, 0.05, 0.07, 0.85))
	ci.draw_arc(c, rad - 1.0, 0.0, TAU, 28, UiKit.GOLD if locked else Color(0.5, 0.5, 0.55), 1.5, true)
	var w := rad * 0.9
	var body := Rect2(c + Vector2(-w * 0.5, -rad * 0.05), Vector2(w, rad * 0.62))
	var col := UiKit.GOLD_BRIGHT if locked else Color(0.75, 0.76, 0.8)
	var arc_c := Vector2(body.get_center().x, body.position.y)
	var arc_r := w * 0.33
	if locked:
		ci.draw_arc(arc_c, arc_r, PI, TAU, 12, col, 2.6, true)
		ci.draw_line(arc_c + Vector2(-arc_r, 0), arc_c + Vector2(-arc_r, 2), col, 2.6)
		ci.draw_line(arc_c + Vector2(arc_r, 0), arc_c + Vector2(arc_r, 2), col, 2.6)
	else:
		# (the shackle lifted and swung open on its right leg)
		var up := arc_c + Vector2(arc_r * 0.9, -rad * 0.28)
		ci.draw_arc(up, arc_r, PI, TAU, 12, col, 2.6, true)
		ci.draw_line(up + Vector2(arc_r, 0), arc_c + Vector2(arc_r * 0.9 + arc_r, 2), col, 2.6)
	ci.draw_rect(body, col)
	ci.draw_circle(body.get_center() + Vector2(0, -1), rad * 0.09, Color(0.12, 0.09, 0.05))
	ci.draw_line(body.get_center() + Vector2(0, -1), body.get_center() + Vector2(0, rad * 0.14), Color(0.12, 0.09, 0.05), 1.5)
