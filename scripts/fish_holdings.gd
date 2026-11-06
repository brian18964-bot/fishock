class_name FishHoldings
extends RefCounted

## The one door fish go through between the places they're kept, in a run or at camp, and the one
## place the rules of the fish box's cells live (user request: the box, the bag and the
## warehouse as one source - no copy of the rules in GameState, in OxyStore, in the screens).
##
## Places: "pack" (what's carried in a run; the bag's fish at camp), "oxy" (the fish box's cells:
## GameState.oxy_fish in a run, Profile.oxy_stock at camp), "stash" (the warehouse), "tank",
## "box" (the bucket), "clasp". The lists themselves still live where they were saved (GameState /
## Profile); everything that wants one asks `list(place)` (or `place_of(list)` for which one it
## is), and everything that moves a fish into or out of the fish box goes through `put_in_box` /
## `take_from_box` / `box_move` / `box_rotate` here - Backpack, ItemBoard, FishPlacer, OxyStore,
## ClaspStore. (Moves between the other places are Profile.move_fish.)

var home := false


func _init(at_home := false) -> void:
	home = at_home


static func in_run() -> FishHoldings:
	return FishHoldings.new(false)


static func at_camp() -> FishHoldings:
	return FishHoldings.new(true)


## The fish in `place` (the list itself: a change to it is the change). The names are the ones
## Profile.move_fish uses - "pack", "stash", "tank", "box" (the bucket), "clasp" - and "oxy" (the
## fish box's cells). "pack" is what's carried in a run (GameState.carried_fish).
func list(place: String) -> Array:
	match place:
		"pack":
			return Profile.pack_fish if home else GameState.carried_fish
		"oxy":
			return Profile.oxy_stock if home else GameState.oxy_fish
	return Profile.fish_list(place)


## The place whose list is exactly `fish_list` (the same array, not one that looks like it), or "".
func place_of(fish_list: Array) -> String:
	for place in ["pack", "stash", "tank", "box", "clasp", "oxy"]:
		if is_same(list(place), fish_list):
			return place
	return ""


# ---------------------------------------------------------------- the box's cells

## `list`'s fish as grid items (Inventory.pack_in), the way they lie now.
static func box_items(fish_list: Array) -> Array:
	var out := []
	for f in fish_list:
		var item := {"size": Inventory.rotated(Inventory.SIZES[Inventory.fish_size(f)], bool(f.get("rot", false)))}
		var c = f.get("cell")
		if c is Array and c.size() == 2:
			item["cell"] = Vector2i(int(c[0]), int(c[1]))
		out.append(item)
	return out


## Where each fish of `fish_list` lies in the box (same order), [] if they don't all fit.
static func box_placed(fish_list: Array) -> Array:
	return Inventory.pack_in(box_items(fish_list), Profile.OXY_COLS, Profile.OXY_ROWS)


## Did every fish in `fish_list` that was set at a cell land on it (`placed`: box_placed)?
static func box_holds(fish_list: Array, placed: Array) -> bool:
	if placed.is_empty() and not fish_list.is_empty():
		return false
	for i in fish_list.size():
		var c = fish_list[i].get("cell")
		if c is Array and (placed[i] as Rect2i).position != Vector2i(int(c[0]), int(c[1])):
			return false
	return true


## Lays `fish_list` out in the box as well as it can: as they lie, else with the ones not placed
## by hand re-laid, else turned the other way about too. The fish are set (cell, rot) to it;
## false (and nothing touched) if no way fits.
static func box_arrange(fish_list: Array) -> bool:
	var turnable: Array = []
	for i in fish_list.size():
		var size: Vector2i = Inventory.SIZES[Inventory.fish_size(fish_list[i])]
		if size.x != size.y:
			turnable.append(i)
	# [re-lay all, turn mask]: first as they lie, then every way of turning them
	var variants := [[false, -1]]
	for mask in 1 << turnable.size():
		variants.append([true, mask])
	for v in variants:
		var tries := []
		for f in fish_list:
			tries.append(f.duplicate())
		if v[1] >= 0:
			for k in turnable.size():
				tries[turnable[k]]["rot"] = (int(v[1]) >> k) & 1 == 1
		if v[0]:
			for t in tries:
				t.erase("cell")
		var placed := box_placed(tries)
		if placed.is_empty() and not fish_list.is_empty():
			continue
		for i in fish_list.size():
			var r := placed[i] as Rect2i
			fish_list[i]["cell"] = [r.position.x, r.position.y]
			fish_list[i]["rot"] = bool(tries[i].get("rot", false))
		return true
	return false


## A fish of `fish_list` set down elsewhere in the box (turned too, if `turn`): "" if done.
static func box_move(fish_list: Array, index: int, cell: Vector2i, turn := false) -> String:
	if index < 0 or index >= fish_list.size():
		return "找不到這條魚"
	var fish: Dictionary = fish_list[index]
	var was = fish.get("cell")
	var was_rot = fish.get("rot")
	# (the others lie where they do now)
	var placed := box_placed(fish_list)
	for j in fish_list.size():
		if not fish_list[j].has("cell") and not placed.is_empty():
			var r := placed[j] as Rect2i
			fish_list[j]["cell"] = [r.position.x, r.position.y]
	if turn:
		fish["rot"] = not bool(fish.get("rot", false))
	fish["cell"] = [cell.x, cell.y]
	if not box_holds(fish_list, box_placed(fish_list)):
		if was == null:
			fish.erase("cell")
		else:
			fish["cell"] = was
		if was_rot == null:
			fish.erase("rot")
		else:
			fish["rot"] = was_rot
		return "放不進那個位置"
	return ""


## A fish of `fish_list` turned (lying <-> standing) where it is, else at the first place it
## fits.
static func box_rotate(fish_list: Array, index: int) -> String:
	if index < 0 or index >= fish_list.size():
		return "找不到這條魚"
	var at := box_placed(fish_list)
	if at.is_empty():
		return "轉不過來"
	var r := at[index] as Rect2i
	if box_move(fish_list, index, r.position, true) == "":
		return ""
	for x in Profile.OXY_COLS:
		for y in Profile.OXY_ROWS:
			if box_move(fish_list, index, Vector2i(x, y), true) == "":
				return ""
	return "轉過來放不下"


# ---------------------------------------------------------------- moving fish

## Is there a box to put fish in (worn, in the bag, or - at camp - in the warehouse; in a run only
## what's been brought: worn or in the bag)?
func box_usable() -> bool:
	return Profile.can_use_oxy_box() if home else Profile.box_goes()


## Fish `index` of `from` (a place's list: `list(...)`; in a run only what's carried) into the box
## at `cell` (-1: laid in by the system). "" if done. A use of the box is counted when a fish
## comes out (see take_from_box).
func put_in_box(from: Array, index: int, cell := Vector2i(-1, -1)) -> String:
	if not home and not is_same(from, GameState.carried_fish):
		return "找不到這條魚"
	if not box_usable():
		return "沒有打氧魚箱"
	if index < 0 or index >= from.size():
		return "找不到這條魚"
	var fish: Dictionary = from[index]
	var was = fish.get("cell")
	fish.erase("cell")
	var box := list("oxy")
	var trial := box.duplicate()
	if cell.x >= 0:
		fish["cell"] = [cell.x, cell.y]
		trial.append(fish)
		if not box_holds(trial, box_placed(trial)):
			fish.erase("cell")
			if was != null:
				fish["cell"] = was
			return "放不進那個位置"
	else:
		trial.append(fish)
		if not box_arrange(trial):
			if was != null:
				fish["cell"] = was
			return "魚箱放不下"
	if not home and GameState.lure_uid == int(fish.get("uid", -2)):
		GameState.lure_uid = -1
	from.remove_at(index)
	fish.erase("slot")
	fish.erase("hook")
	box.append(fish)
	if home:
		# (user report: a box left in the warehouse, its fish gave nothing - with fish in it, it's
		# taken into the bag, where they count and go along; no room, it stays and says so - hint)
		Profile.carry_oxy_box()
		Profile.profile_changed.emit()
	else:
		GameState.inventory_updated.emit(GameState.carried_fish)
	return ""


## The box's fish `index` out: into the bag - else, at camp, the warehouse. "" if done. Each
## fish in and out is one use of the box.
func take_from_box(index: int) -> String:
	var box := list("oxy")
	if index < 0 or index >= box.size():
		return "找不到這條魚"
	var fish: Dictionary = box[index]
	if not home:
		var back := fish.duplicate()
		back.erase("cell")
		var player := GameState.get_tree().get_first_node_in_group("player")
		if not Inventory.fits_with(player, [Inventory.fish_item(back)]):
			return "背包放不下"
	fish.erase("cell")
	box.remove_at(index)
	if home:
		Profile.put_in_pack(fish)
	else:
		GameState.carried_fish.append(fish)
		GameState.inventory_updated.emit(GameState.carried_fish)
	_wear_box()
	return ""


func _wear_box() -> void:
	if Profile.wear_out("oxy_box"):
		# (it broke: what was in it is back out - among what's carried, or in the bag or warehouse)
		var box := list("oxy")
		for f in box.duplicate():
			f.erase("cell")
			if home:
				Profile.put_in_pack(f)
			else:
				GameState.carried_fish.append(f)
		box.clear()
		if not home:
			GameState.inventory_updated.emit(GameState.carried_fish)
		GameState.push_message("打氧魚箱壞了，裡面的魚都拿出來了")
	if home:
		Profile.profile_changed.emit()
