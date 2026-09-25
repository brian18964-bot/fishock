class_name Inventory
extends RefCounted

## User request: a Diablo-style backpack - a grid, and everything carried
## takes up cells: fish by size (small 1x1, medium 1x2, large 2x2, a
## legendary one a size up), the heart, bait (a bundle per cell), lures (a
## cell per kind), batteries (a few per cell), and whatever items come
## later. When it's full, nothing more fits: a fish caught then is left on
## the ground, bait found is left where it was. The oil drum isn't in it -
## that's carried in the hands.
##
## The layout isn't stored: it's packed afresh from what's carried (biggest
## first, top-left first, down each column in turn), so whether something
## fits is just whether the packing still succeeds with it added.

const COLS := 8
const ROWS := 4
const BAIT_PER_CELL := 10
const BATTERIES_PER_CELL := 3
const SIZES := {"small": Vector2i(1, 1), "medium": Vector2i(1, 2), "large": Vector2i(2, 2), "huge": Vector2i(2, 3)}
const SIZE_NAMES := {"small": "小", "medium": "中", "large": "大", "huge": "巨"}
const SIZE_BY_TIER := {"near": "small", "mid": "medium", "far": "large"}
const BIGGER := {"small": "medium", "medium": "large", "large": "huge", "huge": "huge"}


## A caught fish's size: by how far out it was hooked, a size up if it's a
## legendary one.
static func size_for_catch(tier: String, epic: bool) -> String:
	var size: String = SIZE_BY_TIER.get(tier, "small")
	return BIGGER[size] if epic else size


static func fish_size(fish: Dictionary) -> String:
	return fish.get("size", SIZE_BY_TIER.get(fish.get("tier", ""), "small"))


## Everything carried, as grid items: {kind, label, count, size (cells),
## index (for fish: into GameState.carried_fish; for lures: the lure id)}.
static func items(player: Node) -> Array:
	var out := []
	for i in GameState.carried_fish.size():
		var fish: Dictionary = GameState.carried_fish[i]
		var size := fish_size(fish)
		out.append({"kind": "fish", "label": fish.get("name", "魚"), "count": 0,
			"size": SIZES[size], "index": i, "rotten": fish.get("rotten", false), "grade": SIZE_NAMES[size]})
	if GameState.has_heart:
		out.append({"kind": "heart", "label": "心臟", "count": 0, "size": Vector2i(1, 1), "index": -1})
	if player != null:
		var bait: int = player.bait_count
		while bait > 0:
			out.append({"kind": "bait", "label": "餌", "count": mini(bait, BAIT_PER_CELL), "size": Vector2i(1, 1), "index": -1})
			bait -= BAIT_PER_CELL
		for id in Profile.LURE_ORDER:
			var n := int(player.lure_stock.get(id, 0))
			if n > 0:
				out.append({"kind": "lure", "label": Profile.LURES[id].name, "count": n, "size": Vector2i(1, 1), "index": id})
	var batteries: int = Profile.batteries
	while batteries > 0:
		out.append({"kind": "battery", "label": "電池", "count": mini(batteries, BATTERIES_PER_CELL), "size": Vector2i(1, 1), "index": -1})
		batteries -= BATTERIES_PER_CELL
	return out


## Where each item goes (same order as `list`), or [] if they don't all fit.
static func pack(list: Array) -> Array:
	var order := range(list.size())
	order.sort_custom(func(a, b):
		var sa: Vector2i = list[a].size
		var sb: Vector2i = list[b].size
		return sa.x * sa.y > sb.x * sb.y if sa.x * sa.y != sb.x * sb.y else a < b)
	var used := {}
	var placed := []
	placed.resize(list.size())
	for i in order:
		var size: Vector2i = list[i].size
		var spot := _first_fit(used, size)
		if spot.x < 0:
			return []
		for dx in size.x:
			for dy in size.y:
				used[Vector2i(spot.x + dx, spot.y + dy)] = true
		placed[i] = Rect2i(spot, size)
	return placed


static func _first_fit(used: Dictionary, size: Vector2i) -> Vector2i:
	for x in COLS - size.x + 1:
		for y in ROWS - size.y + 1:
			var free := true
			for dx in size.x:
				for dy in size.y:
					if used.has(Vector2i(x + dx, y + dy)):
						free = false
			if free:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Would it all still fit with `extra` (grid items) added?
static func fits_with(player: Node, extra: Array) -> bool:
	return not pack(items(player) + extra).is_empty()


static func fish_item(fish: Dictionary) -> Dictionary:
	return {"kind": "fish", "size": SIZES[fish_size(fish)]}


## Room for `amount` more bait?
static func fits_bait(player: Node, amount: int) -> bool:
	var before := ceili(player.bait_count / float(BAIT_PER_CELL))
	var after := ceili((player.bait_count + amount) / float(BAIT_PER_CELL))
	var extra := []
	for _i in after - before:
		extra.append({"kind": "bait", "size": Vector2i(1, 1)})
	return fits_with(player, extra)


static func used_cells(player: Node) -> int:
	var n := 0
	for item in items(player):
		n += item.size.x * item.size.y
	return n
