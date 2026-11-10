class_name Bones
extends RefCounted

## User request: the altar's rewards - something real to take home. Each offering the altar answers
## with (GameState._add_offering) is a fish bone: whole skeletons, spines, skulls and broken pieces in
## four sizes, sold for gold (the bigger and the more whole, the more), taking bag cells by their
## size; the dearer, the rarer to be drawn. And on its own, rarest of all, the glowing bone - its
## rarity drawn after (the fish's three), with stat affixes (one fewer than a fish of its rarity
## rolls) that count while it's in the bag (Stats.sources). An evil offering gives no bone - it's
## one of the ways a night ends in death (three of them). Models and pictures:
## tools/make_fish_bones.py, tools/render_square_icons.py.
##
## Ids: bone_<kind>_<size> (kind whole / spine / skull / broken, size s / m / l / xl); a glowing
## bone gbone_<n>, its own (Profile.glow_bones[id]: {rarity, life_traits, trait_tiers, trait_vals}).

const KINDS := ["whole", "spine", "skull", "broken"]
const SIZES := ["s", "m", "l", "xl"]
const SIZE_NAMES := {"s": "小", "m": "中", "l": "大", "xl": "超大"}
const KIND_NAMES := {"whole": "魚骨", "spine": "魚身骨", "skull": "魚頭骨", "broken": "不完整的魚骨"}
## What the merchant pays (user request: at least 30 gold), by size.
const PRICES := {"whole": [50, 80, 120, 180], "spine": [40, 60, 85, 120], "skull": [35, 50, 70, 100], "broken": [30, 40, 55, 75]}
## The bag cells each takes, by size (tools/make_fish_bones.py's CELLS the same).
const CELLS := {
	"whole": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)],
	"spine": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 1)],
	"skull": [Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
	"broken": [Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 1)],
}
## The draw: each bone's weight is (1 / its price) ^ DRAW_POWER - the dearest about a twentieth as
## likely as the cheapest; the extra offerings after the quota (bonus) draw flatter, the dear ones
## likelier (the gamble of staying on).
const DRAW_POWER := 1.6
const BONUS_POWER := 0.6
## The glowing bone: the share of offerings that are one - below even the dearest plain bone's
## (whole_xl: ~0.96 % of the usual draws, ~3.3 % of the extra ones), the rarest thing on the
## altar; then its rarity (the fish's: common / rare / epic, by weight).
const GLOW_CHANCE := 0.006
const GLOW_BONUS_CHANCE := 0.02
const GLOW_RARITY := {"common": 70.0, "rare": 25.0, "epic": 5.0}
const GLOW_PRICES := {"common": 150, "rare": 300, "epic": 600}
const GLOW_SIZE := Vector2i(2, 1)
const GLOW_NAME := "發光魚骨"
const ICONS := "res://assets/sprites/items/%s.png"
const SQUARE := "res://assets/sprites/icons/%s.png"
const MODELS := "res://assets/models/items/%s.glb"


static func is_bone(id: String) -> bool:
	return id.begins_with("bone_") or id.begins_with("gbone_")


static func is_glow(id: String) -> bool:
	return id.begins_with("gbone_")


## [kind, size index] of a plain bone's id ([] if it isn't one).
static func parts(id: String) -> Array:
	if not id.begins_with("bone_"):
		return []
	var bits := id.split("_")
	if bits.size() != 3 or not KINDS.has(bits[1]) or not SIZES.has(bits[2]):
		return []
	return [bits[1], SIZES.find(bits[2])]


static func all_plain() -> Array:
	var out := []
	for k in KINDS:
		for s in SIZES:
			out.append("bone_%s_%s" % [k, s])
	return out


## A glowing bone's own (its rarity and affixes; {} if it's gone).
static func glow_data(id: String) -> Dictionary:
	return Profile.glow_bones.get(id, {})


## The picture key (the files under sprites/items, sprites/icons, models/items).
static func art(id: String) -> String:
	if is_glow(id):
		return "glow_bone_" + str(glow_data(id).get("rarity", "common"))
	return id


static func name_of(id: String) -> String:
	if is_glow(id):
		return GLOW_NAME
	var p := parts(id)
	if p.is_empty():
		return id
	return SIZE_NAMES[SIZES[p[1]]] + KIND_NAMES[p[0]]


static func price(id: String) -> int:
	if is_glow(id):
		var d := glow_data(id)
		return int(GLOW_PRICES.get(str(d.get("rarity", "common")), 150)) if not d.is_empty() else 0
	var p := parts(id)
	return int(PRICES[p[0]][p[1]]) if not p.is_empty() else 0


static func size_of(id: String) -> Vector2i:
	if is_glow(id):
		return GLOW_SIZE
	var p := parts(id)
	return CELLS[p[0]][p[1]] if not p.is_empty() else Vector2i.ONE


## Its rarity's key, for the colours (a plain one's by its price; a glowing one its own).
static func rarity(id: String) -> String:
	if is_glow(id):
		return str(glow_data(id).get("rarity", "common"))
	var gold := price(id)
	return "epic" if gold >= 110 else ("rare" if gold >= 60 else "common")


static func desc(id: String) -> String:
	if is_glow(id):
		var d := glow_data(id)
		var lines := ["獻祭祭壇回應的發光魚骨（%s）。放在背包裡，它的詞綴就算進角色素質。" % UiKit.rarity_name(str(d.get("rarity", "common")))]
		for t in d.get("life_traits", []):
			lines.append("・%s %+d（%s）" % [Stats.NAMES.get(t, t), int(d.get("trait_vals", {}).get(t, 0)),
				FishLife.TIER_NAMES[clampi(int(d.get("trait_tiers", {}).get(t, 1)) - 1, 0, 4)]])
		lines.append("商人收購 %d 金幣" % price(id))
		return "\n".join(lines)
	return "獻祭祭壇回應的魚骨，可以賣給商人（%d 金幣）。越大、越完整越值錢。" % price(id)


## The thing's def for Items (its tab, cells, picture...).
static func def(id: String) -> Dictionary:
	if (is_glow(id) and glow_data(id).is_empty()) or (not is_glow(id) and parts(id).is_empty()):
		return {}
	return {"name": name_of(id), "tab": "other", "size": size_of(id), "stack": 1, "slot": "",
		"icon": ICONS % art(id), "desc": desc(id), "bone": true}


static func square_icon_path(id: String) -> String:
	return SQUARE % art(id)


static func model_path(id: String) -> String:
	return MODELS % art(id)


## Each plain bone's draw weight (bonus: flatter, the dear ones likelier).
static func weights(bonus := false) -> Dictionary:
	var out := {}
	var power := BONUS_POWER if bonus else DRAW_POWER
	for id in all_plain():
		out[id] = pow(1.0 / float(price(id)), power)
	return out


## An offering's bone, drawn: {"bone": a plain bone's id} or {"glow": its rarity}.
static func draw(bonus := false, rng: RandomNumberGenerator = null) -> Dictionary:
	var roll := rng.randf() if rng != null else randf()
	if roll < (GLOW_BONUS_CHANCE if bonus else GLOW_CHANCE):
		return {"glow": _weighted(GLOW_RARITY, rng)}
	return {"bone": _weighted(weights(bonus), rng)}


static func _weighted(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var at := (rng.randf() if rng != null else randf()) * total
	for k in table:
		at -= float(table[k])
		if at <= 0.0:
			return k
	return table.keys().back()


## A new glowing bone of `rarity`: its affixes rolled (stat affixes only; one fewer than a fish of
## that rarity rolls - at least one, at most MAX_AFFIXES - 1), kept in the profile. Its id.
static func make_glow(rarity: String) -> String:
	var n := FishLife._pick(FishLife._odds(FishLife.SLOT_ODDS, rarity)) - 1
	n = clampi(n, 1, FishLife.MAX_AFFIXES - 1)
	var pool: Array = FishLife.STAT_IDS.duplicate()
	pool.shuffle()
	var traits: Array = pool.slice(0, n)
	var tiers := {}
	var vals := {}
	var odds: Array = FishLife._odds(FishLife.TIER_ODDS, rarity)
	for t in traits:
		var tier := FishLife._pick(odds) + 1
		tiers[t] = tier
		var r: Array = FishLife.STAT_RANGES[tier - 1]
		vals[t] = randi_range(int(r[0]), int(r[1]))
	Profile.glow_serial += 1
	var id := "gbone_%d" % Profile.glow_serial
	Profile.glow_bones[id] = {"rarity": rarity, "life_traits": traits, "trait_tiers": tiers, "trait_vals": vals}
	return id


## The glowing bones in the bag now, as [[name, stat, number]] - what Stats adds (the bag's at camp
## and on the night alike: it's the same bag).
static func bag_stats(stat: String) -> Array:
	var out := []
	for e in Profile.bag:
		var id: String = e.id
		if not is_glow(id):
			continue
		var d := glow_data(id)
		if stat in d.get("life_traits", []):
			out.append(["%s（%s）" % [GLOW_NAME, UiKit.rarity_name(str(d.get("rarity", "common")))], int(d.get("trait_vals", {}).get(stat, 0))])
	return out
