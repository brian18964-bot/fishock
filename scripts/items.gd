class_name Items
extends RefCounted

## User request (warehouse): the things a player owns, kept between runs -
## in the warehouse (Profile.storage, sorted into tabs) or packed in the
## bag they take into the next run (Profile.bag, the in-game backpack's
## grid), or worn (Profile.equipped). Each kind of thing, by id:
##   rod_0..rod_4   the rods (Profile.ROD_TIERS), three cells long
##   flashlight     two cells, worn in the light slot
##   battery        three to a cell
##   lure_<id>      the lures (Profile.LURES), ten to a cell
##   live_<id>      live baits (Profile.LIVE_BAITS), ten to a cell
##   bait           the base bait (user request: given each run, but it
##                  takes bag cells) - kept in the bag, only moved about
## A thing's {name, tab, size (cells), stack (per cell), slot (the
## equipment slot it's worn in, if any), icon, desc}.

const TABS := {"gear": "裝備", "item": "物品", "tackle": "釣具", "other": "其他"}
const TAB_ORDER := ["gear", "item", "tackle", "other"]
const ICONS := "res://assets/sprites/items/%s.png"
const LURE_ICON := "res://assets/sprites/lure/lure_%d_55deg_albedo.png"
const LIVE_ICONS := {
	"worm": "res://assets/sprites/lure/worm_55deg_albedo.png",
	"cricket": "res://assets/sprites/items/cricket.png",
	"shrimp": "res://assets/sprites/items/shrimp.png",
	"minnow": "res://assets/sprites/fish/minnow.png",
}

static var _icons := {}


static func def(id: String) -> Dictionary:
	if id.begins_with("rod_"):
		var tier := int(id.substr(4))
		if tier < 0 or tier >= Profile.ROD_TIERS.size():
			return {}
		var r: Dictionary = Profile.ROD_TIERS[tier]
		return {"name": r.name, "tab": "gear", "size": Vector2i(3, 1), "stack": 1, "slot": "rod",
			"icon": ICONS % id, "desc": rod_effects(r), "tier": tier}
	if id == "flashlight":
		return {"name": "手電筒", "tab": "gear", "size": Vector2i(2, 1), "stack": 1, "slot": "light",
			"icon": ICONS % id, "desc": "遠距離窄光束，用電池；裝備後才能在遊戲裡切換使用"}
	if id == "bait":
		return {"name": "餌料", "tab": "item", "size": Vector2i(1, 1), "stack": 10, "slot": "", "fixed": true,
			"icon": "res://assets/sprites/lure/worm_55deg_albedo.png",
			"desc": "基礎餌料：每輪開局自動補滿，會佔背包空間（可以移動位置，不能拿出背包）"}
	if id == "battery":
		return {"name": "電池", "tab": "item", "size": Vector2i(1, 1), "stack": 3, "slot": "",
			"icon": ICONS % id, "desc": "手電筒沒電時換上，要放在背包裡才帶得進去"}
	if id.begins_with("live_"):
		var lk := id.substr(5)
		if not Profile.LIVE_BAITS.has(lk):
			return {}
		var lb: Dictionary = Profile.LIVE_BAITS[lk]
		return {"name": lb.name, "tab": "tackle", "size": Vector2i(1, 1), "stack": 10, "slot": "",
			"icon": LIVE_ICONS[lk], "desc": lb.desc, "live": lk}
	if id.begins_with("lure_"):
		var key := id.substr(5)
		if not Profile.LURES.has(key):
			return {}
		var l: Dictionary = Profile.LURES[key]
		return {"name": l.name, "tab": "tackle", "size": Vector2i(1, 1), "stack": 10, "slot": "",
			"icon": LURE_ICON % (int(l.sprite) + 1), "desc": l.desc, "lure": key}
	return {}


static func name_of(id: String) -> String:
	return def(id).get("name", id)


static func size_of(id: String) -> Vector2i:
	return def(id).get("size", Vector2i(1, 1))


static func stack_of(id: String) -> int:
	return int(def(id).get("stack", 1))


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path: String = def(id).get("icon", "")
		_icons[id] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _icons[id]


const MODELS := "res://assets/models/items/%s.glb"
const LIVE_MODELS := {"worm": "worm", "cricket": "cricket", "shrimp": "shrimp"}


## A thing's 3D model, for the menus' previews (ItemPreview) - "" when it
## has none. "lamp" is the oil lamp every run starts with.
static func model_path(id: String) -> String:
	if id.begins_with("rod_"):
		return "res://assets/models/fishing_rod_lvl%d.glb" % (int(id.substr(4)) + 1)
	match id:
		"flashlight", "battery":
			return MODELS % id
		"bait":
			return MODELS % "worm"
		"lamp":
			return "res://assets/models/oil_lamp.glb"
	if id.begins_with("lure_") and Profile.LURES.has(id.substr(5)):
		return MODELS % ("lure_%d" % (int(Profile.LURES[id.substr(5)].sprite) + 1))
	if id.begins_with("live_") and LIVE_MODELS.has(id.substr(5)):
		return MODELS % LIVE_MODELS[id.substr(5)]
	return ""


## A picture by its path, kept loaded (safe to use while drawing).
static func texture(path: String) -> Texture2D:
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]


static func rod_effects(rod: Dictionary) -> String:
	var parts := ["張力上限 x%.2f" % rod.strength]
	if rod.window > 1.0:
		parts.append("揚竿時間 +%d%%" % roundi((rod.window - 1.0) * 100.0))
	if rod.jump < 1.0:
		parts.append("魚跳衝擊 -%d%%" % roundi((1.0 - rod.jump) * 100.0))
	return "、".join(parts)


## Warehouse ids in display order: rods by tier, then the rest by tab.
static func sort_ids(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a, b): return _rank(a) < _rank(b))
	return out


static func _rank(id: String) -> int:
	if id.begins_with("rod_"):
		return int(id.substr(4))
	if id == "flashlight":
		return 10
	if id == "bait":
		return 15
	if id == "battery":
		return 20
	if id.begins_with("live_"):
		return 25 + Profile.LIVE_ORDER.find(id.substr(5))
	if id.begins_with("lure_"):
		return 30 + Profile.LURE_ORDER.find(id.substr(5))
	return 100
