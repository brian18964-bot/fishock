class_name OxyStore
extends RefCounted

## The fish box's contents as FishFlyout's store - a thin view over FishHoldings (the rules live
## there): in a run (GameState.oxy_fish, put in from what's carried) or at camp (Profile.oxy_stock,
## put in from the bag or the warehouse).

var home := false


func _init(at_home := false) -> void:
	home = at_home


func _h() -> FishHoldings:
	return FishHoldings.new(home)


func list() -> Array:
	return _h().list("oxy")


func cols() -> int:
	return Profile.OXY_COLS


func rows() -> int:
	return Profile.OXY_ROWS


func title() -> String:
	return "打氧魚箱　耐久 %d / %d" % [Profile.durability("oxy_box"), Profile.max_durability("oxy_box")]


func hint() -> String:
	return "把魚拖進格子；點魚看詳情（轉向、取出、上鎖）；把魚拖出格子就拿出來"


## Where each fish lies (Rect2i, same order), [] if they don't all fit.
func placed() -> Array:
	return FishHoldings.box_placed(list())


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
	return FishHoldings.box_holds(l, FishHoldings.box_placed(l))


## Puts `from[index]` (the carried fish in a run; the bag's or the warehouse's at camp) in the
## box at `cell`. "" if done, else why not.
func put(from: Array, index: int, cell: Vector2i) -> String:
	return _h().put_in_box(from, index, cell)


func move(index: int, cell: Vector2i) -> String:
	return FishHoldings.box_move(list(), index, cell)


func rotate(index: int) -> String:
	return FishHoldings.box_rotate(list(), index)


func take(index: int) -> String:
	return _h().take_from_box(index)
