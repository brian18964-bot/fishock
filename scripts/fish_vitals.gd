class_name FishVitals
extends VBoxContainer

## User request: a fish's vitality bar (活性) while it lives; dead, its
## freshness bar (新鮮度); rotten, an empty one - with its traits under
## (FishLife). Shown on the backpack's card, the tank's, the merchant's.
## Follows the fish dict it's given while it's shown (the bar runs down).

const BAR_SIZE := Vector2(0, 14)
const VIT_COLOR := Color(0.35, 0.8, 0.5)
const VIT_LOW := Color(0.9, 0.35, 0.3)
const FRESH_COLOR := Color(0.4, 0.7, 0.95)
const ROT_COLOR := Color(0.5, 0.42, 0.25)
## How often it looks again (s).
const REFRESH := 0.25
## At home (tank, bag, warehouse) it's kept as it is (nothing runs down - but
## in the bucket).
var kept := false

var _fish := {}
var _head: Label
var _bar: Control
var _traits: VBoxContainer
var _t := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_head = UiKit.label("", 14, UiKit.TEXT)
	add_child(_head)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, BAR_SIZE.y)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_traits = VBoxContainer.new()
	_traits.add_theme_constant_override("separation", 2)
	add_child(_traits)
	visible = false


## Shows `fish` (the dict itself: a later tick shows). Nothing for a fish
## that has no life.
func show_fish(fish: Dictionary, in_tank := false) -> void:
	_fish = fish
	kept = in_tank
	visible = FishLife.has_life(fish)
	for c in _traits.get_children():
		c.queue_free()
	if not visible:
		return
	for t in fish.get("life_traits", []):
		# (the colour is its tier's; a bad one is marked)
		var l := UiKit.label("%s%s・%s：%s" % ["▼ " if FishLife.is_bad(t) else "", FishLife.TRAITS[t].name,
			FishLife.TIER_NAMES[FishLife.tier_of(fish, t) - 1], FishLife.trait_desc(fish, t)], 13, FishLife.trait_color(fish, t))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# (a wrapped label sized from nothing is tall till it's laid out)
		l.custom_minimum_size.x = maxf(custom_minimum_size.x, 200.0)
		_traits.add_child(l)
	_refresh()


func _process(delta: float) -> void:
	if not visible or _fish.is_empty():
		return
	_t += delta
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	var bar := FishLife.bar(_fish)
	var text := "%s %d%%" % [bar.label, roundi(float(bar.share) * 100.0)]
	match FishLife.state(_fish):
		"alive":
			var left := FishLife.lifespan_left(_fish, GameState.is_night)
			if _fish.get("weak", false):
				text += "・虛弱！在魚缸裡不會再倒數，餵活力飼料才恢復" if kept else "・虛弱！約 %s 後死亡（快放進魚缸）" % _time(left)
			elif FishLife.has_trait(_fish, "immortal"):
				text += "・不會死亡"
			elif kept:
				text += "・放在家裡活性不會下降"
			else:
				text += "・約 %s 後死亡" % _time(left)
		"dead":
			var keeps := FishLife.freshness_left(_fish)
			text = "已死亡・" + text
			if kept:
				text += "・放在家裡不會腐敗"
			elif keeps == INF:
				text += "・不會腐敗"
			else:
				text += "・約 %s 後腐敗" % _time(keeps)
		_:
			text = "腐敗了・沒有價值"
	# (the map's finds at work on it)
	if float(_fish.get("vit_slow", 0.0)) > 0.0 and FishLife.state(_fish) == "alive":
		text += "\n魚氧樹作用中（剩 %d 秒）" % ceili(float(_fish.vit_slow))
	elif float(_fish.get("fresh_slow", 0.0)) > 0.0 and FishLife.state(_fish) != "rotten":
		text += "\n冷凍土作用中（剩 %d 秒）" % ceili(float(_fish.fresh_slow))
	_head.text = text
	_bar.queue_redraw()


## "2 分 10 秒" / "45 秒".
static func _time(s: float) -> String:
	var n := maxi(int(ceil(s)), 0)
	return "%d 分 %02d 秒" % [n / 60, n % 60] if n >= 60 else "%d 秒" % n


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, Color(0.08, 0.07, 0.06, 0.9))
	var bar := FishLife.bar(_fish)
	var col := VIT_COLOR.lerp(VIT_LOW, 1.0 - clampf(float(bar.share) * 2.0, 0.0, 1.0)) if bar.kind == "vit" \
		else (FRESH_COLOR if bar.kind == "fresh" else ROT_COLOR)
	if bar.kind == "fresh":
		col = FRESH_COLOR.lerp(ROT_COLOR, 1.0 - float(bar.share))
	var w := r.size.x * clampf(float(bar.share), 0.0, 1.0)
	if w > 0.0:
		_bar.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	_bar.draw_rect(r, Color(0.75, 0.68, 0.5, 0.8), false, 1.0)
