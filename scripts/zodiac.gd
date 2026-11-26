class_name Zodiac
extends RefCounted

## User request: the twelve zodiac coins - the altar's rarest reward, given now and then on top of the
## night's bone when the traveller gets away (GameState.escape). Their powers aren't written yet (user:
## "能力我先不寫進去"); for now each is a keepsake the merchant would pay well for. Models and pictures
## our own, made from a set the user gave (tools/make_zodiac_coins.py: not so round, 1.5 times as
## thick, the little stars painted out).
##
## Ids: zodiac_01 (Aries) .. zodiac_12 (Pisces).

const SIGNS := ["白羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座", "天秤座", "天蠍座", "射手座", "摩羯座", "水瓶座", "雙魚座"]
## (how often a night got away from gives one, besides its bone; what the merchant pays - mine for now,
## the user's to change)
const CHANCE := 0.01
const PRICE := 800
## (CHANCE, unless a test sets it)
static var chance := CHANCE
const ICONS := "res://assets/sprites/items/%s.png"
const SQUARE := "res://assets/sprites/icons/%s.png"
const MODELS := "res://assets/models/items/%s.glb"


static func is_coin(id: String) -> bool:
	return index_of(id) >= 0


## Its sign's number (0 Aries .. 11 Pisces), -1 not a coin.
static func index_of(id: String) -> int:
	if not id.begins_with("zodiac_") or id.length() != 9:
		return -1
	var n := int(id.substr(7))
	return n - 1 if n >= 1 and n <= 12 and id.substr(7).is_valid_int() else -1


static func id_of(i: int) -> String:
	return "zodiac_%02d" % (i + 1)


static func all() -> Array:
	var out := []
	for i in SIGNS.size():
		out.append(id_of(i))
	return out


static func name_of(id: String) -> String:
	var i := index_of(id)
	return "%s硬幣" % SIGNS[i] if i >= 0 else id


## The thing's def for Items.
static func def(id: String) -> Dictionary:
	if not is_coin(id):
		return {}
	return {"name": name_of(id), "tab": "other", "size": Vector2i(1, 1), "stack": 1, "slot": "",
		"icon": ICONS % id, "coin": true,
		"desc": "獻祭祭壇極少給出的古老硬幣，鑄著%s。邊緣不規則，沉甸甸的。據說十二枚湊齊會發生什麼事……（商人收購 %d 金幣）" % [SIGNS[index_of(id)], PRICE]}


static func square_icon_path(id: String) -> String:
	return SQUARE % id


static func model_path(id: String) -> String:
	return MODELS % id


## The altar's roll, as a night's got away from: one of the twelve (each as likely), or "".
static func roll() -> String:
	return id_of(randi() % SIGNS.size()) if randf() < chance else ""
