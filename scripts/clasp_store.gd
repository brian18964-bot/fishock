class_name ClaspStore
extends RefCounted

## The live-fish clasp worn in `slot`, as FishFlyout's store (the same moves as OxyStore): a cell
## for each hook, a fish hung on it taking one cell however big it is; hung from the bag or the
## warehouse at camp, taken off to the bag, else the warehouse. A fish can't be turned.

var slot := ""
var can_turn := false


func _init(slot_key: String) -> void:
	slot = slot_key


func _hooks() -> Array:
	return Profile.clasp_hooks().filter(func(h): return h.slot == slot)


func list() -> Array:
	var out := []
	for h in _hooks():
		var i := Profile.hooked_at(h.id)
		if i >= 0:
			out.append(Profile.clasp_fish[i])
	return out


func cols() -> int:
	return maxi(_hooks().size(), 1)


func rows() -> int:
	return 1


func title() -> String:
	return "活魚扣"


func hint() -> String:
	return "把魚拖到掛鉤上（不佔背包格子）；把魚拖出來就取下"


func placed() -> Array:
	var out := []
	for f in list():
		out.append(Rect2i(Vector2i(_hook_of(f), 0), Vector2i.ONE))
	return out


func _hook_of(f: Dictionary) -> int:
	return int(str(f.get("hook", "%s:0" % slot)).get_slice(":", 1))


func size_of(_f: Dictionary) -> Vector2i:
	return Vector2i.ONE


func fits(fish: Dictionary, cell: Vector2i, index := -1) -> bool:
	if cell.y != 0 or cell.x < 0 or cell.x >= cols():
		return false
	var at := Profile.hooked_at("%s:%d" % [slot, cell.x])
	if at < 0:
		return true
	return index >= 0 and Profile.clasp_fish[at] == list()[index]


func put(from: Array, index: int, cell: Vector2i) -> String:
	var src := "pack" if from == Profile.pack_fish else ("stash" if from == Profile.stash_fish else "")
	if src == "" or cell.y != 0 or cell.x < 0 or cell.x >= cols():
		return "放不進那個位置"
	return Profile.hang_fish(src, index, "%s:%d" % [slot, cell.x])


func move(index: int, cell: Vector2i) -> String:
	var l := list()
	if index < 0 or index >= l.size() or not fits(l[index], cell, index):
		return "這個掛鉤有魚了"
	l[index]["hook"] = "%s:%d" % [slot, cell.x]
	Profile.profile_changed.emit()
	return ""


func rotate(_index: int) -> String:
	return ""


func take(index: int) -> String:
	var l := list()
	if index < 0 or index >= l.size():
		return "找不到這條魚"
	var i := Profile.clasp_fish.find(l[index])
	var why := Profile.move_fish("clasp", i, "pack")
	if why != "":
		why = Profile.move_fish("clasp", i, "stash")
	return why


## A button under the cells: the clasp taken off (only with its hooks empty).
func extra_label() -> String:
	return "卸下活魚扣"


func extra_do() -> String:
	if Profile.unequip(slot):
		return "!close"
	return "先把魚取下來，才能卸下活魚扣"
