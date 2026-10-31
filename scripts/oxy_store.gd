class_name OxyStore
extends RefCounted

## The fish box's contents, whether in a run (GameState.oxy_fish, put in from what's carried)
## or at camp (Profile.oxy_stock, put in from the bag or the warehouse): one set of moves
## for FishFlyout - put at a cell, move, turn, take out. Each put or take is a use of the box.

var home := false


func _init(at_home := false) -> void:
	home = at_home


func list() -> Array:
	return Profile.oxy_stock if home else GameState.oxy_fish


func cols() -> int:
	return Profile.OXY_COLS


func rows() -> int:
	return Profile.OXY_ROWS


func title() -> String:
	return "打氧魚箱　耐久 %d / %d" % [Profile.durability("oxy_box"), Profile.max_durability("oxy_box")]


func hint() -> String:
	return "把魚拖進格子（按 R 或點魚可轉向）；把魚拖出格子就拿出來"


## Where each fish lies (Rect2i, same order), [] if they don't all fit.
func placed() -> Array:
	return GameState.oxy_placed(list())


## The cells fish `f` takes laid the way it is.
func size_of(f: Dictionary) -> Vector2i:
	return Inventory.rotated(Inventory.SIZES[Inventory.fish_size(f)], bool(f.get("rot", false)))


## Could `fish` go with its top left at `cell` (it being `index` of the box's own list if it's
## being moved there, else new)?
func fits(fish: Dictionary, cell: Vector2i, index := -1) -> bool:
	var l := list().duplicate()
	var probe := fish.duplicate()
	probe["cell"] = [cell.x, cell.y]
	if index >= 0:
		l[index] = probe
	else:
		l.append(probe)
	return GameState._oxy_holds(l, GameState.oxy_placed(l))


## Puts `from[index]` (the carried fish in a run; the bag's or the warehouse's at camp) in the
## box at `cell`. "" if done, else why not.
func put(from: Array, index: int, cell: Vector2i) -> String:
	if not home:
		if from != GameState.carried_fish:
			return "找不到這條魚"
		return GameState.oxy_put(index, cell)
	if not Profile.can_use_oxy_box():
		return "沒有打氧魚箱"
	if index < 0 or index >= from.size():
		return "找不到這條魚"
	var fish: Dictionary = from[index]
	var was = fish.get("cell")
	fish["cell"] = [cell.x, cell.y]
	var l := Profile.oxy_stock.duplicate()
	l.append(fish)
	if not GameState._oxy_holds(l, GameState.oxy_placed(l)):
		if was == null:
			fish.erase("cell")
		else:
			fish["cell"] = was
		return "放不進那個位置"
	from.remove_at(index)
	fish.erase("slot")
	fish.erase("hook")
	Profile.oxy_stock.append(fish)
	_wear()
	return ""


func move(index: int, cell: Vector2i) -> String:
	return GameState.oxy_move(index, cell, false, list())


func rotate(index: int) -> String:
	return GameState.oxy_rotate(index, list())


## The fish at `index` out: to what's carried (a run), the bag else the warehouse (camp).
func take(index: int) -> String:
	if not home:
		return GameState.oxy_take(index)
	if index < 0 or index >= Profile.oxy_stock.size():
		return "找不到這條魚"
	var fish: Dictionary = Profile.oxy_stock[index]
	fish.erase("cell")
	Profile.oxy_stock.remove_at(index)
	Profile.put_in_pack(fish)
	_wear()
	return ""


func _wear() -> void:
	if Profile.wear_out("oxy_box"):
		# (it broke: what was in it goes to the bag or the warehouse)
		for f in Profile.oxy_stock.duplicate():
			f.erase("cell")
			Profile.put_in_pack(f)
		Profile.oxy_stock.clear()
		GameState.push_message("打氧魚箱壞了，裡面的魚都拿出來了")
	Profile.profile_changed.emit()
