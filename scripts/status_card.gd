class_name StatusCard
extends CanvasLayer

## User request: the character's status as a card in a corner - a portrait,
## their name, how fast they're moving and whatever's wrong with them (the
## water ghost's hold, a dizzy spell, carrying the oil drum, caught by the
## big ghost), plus the heart and the fish carried. Tapping it opens the
## backpack (it replaces the backpack button, clearing the controls).
## Top left, where most games keep the player's own status; the right side
## is left to the time, the lamp and the thumbs.
##
## Dressed as an MMO's player frame (user request): the portrait in a gold
## medallion, the name on a plate, what's wrong under it in red. Under the
## card, the gear in hand (GEAR_AT).

const NAME := "釣客"
const POS := Vector2(6, 4)
const SIZE := Vector2(226, 72)
const PORTRAIT := 64.0
const INK := Color(1.0, 0.96, 0.88)
const DIM := Color(1.0, 0.96, 0.88, 0.7)
const WARN := Color(1.0, 0.55, 0.45)
const GOOD := Color(0.72, 0.95, 0.55)

## User request: what's happening on the run (GameState.report) - the bait
## taken, a long wait for nothing, a ghost meddling, a wolf on you - a few
## words each under the card, the newest on top; each stays a few seconds
## and fades, and the same thing again just refreshes its line.
const FEED_AT := Vector2(10, 84)
const FEED_LINES := 3
const FEED_LIFE := 4.5
const FEED_FADE := 0.8
const FEED_SIZE := 13
const FEED_GAP := 21.0

## User request: under the card, what's in hand - the main hand (the rod),
## the off hand (a weapon or the net) and the bait on the hook with how many
## are left - each a slot with its icon (the one in hand now lit, the worn
## ones with their durability); a tap on any opens the bag. (User request,
## round 3: not drawn any more - the bait and its count are by the right
## pad now; SHOW_GEAR.)
const SHOW_GEAR := false
const GEAR_AT := Vector2(10, 80)
const GEAR_SLOT := 40.0
const GEAR_GAP := 6.0
const GEAR_LABELS := ["主手", "副手", "餌"]

## User request (the glow mushroom): what's been used and is still working
## - the glow, the potions - a slot each under the card, its icon, the time
## left sweeping round it and counted; the feed's lines under them then.
## First of them, the character's own ability (Abilities): its badge, lit
## while it's working (the cat at night, the owl in the dark; the ones
## that go off by chance always), glowing a moment when it goes off.
const EFFECT_AT := Vector2(10, 80)
const EFFECT_SLOT := 34.0
const EFFECT_GAP := 5.0

## How long the ability's slot glows when it goes off (s), and how long
## it's glowed so far.
const ABILITY_FLASH := 2.0
var _ability_flash := 0.0
var _hooked: Player

## The lines showing: [text, tone, age], newest first.
var feed: Array = []

var _view: Node2D
## The state slots drawn under the card this frame: [rect, key] (key: "ability", an item id for
## what's been used, "load" for 滿載而歸).
var _slots: Array = []
## The little card a tapped state's slot opens: what it is (TIP_LIFE s, or until a tap elsewhere).
var _tip: PanelContainer
var _tip_text: Label
var _tip_key := ""
var _tip_left := 0.0
const TIP_LIFE := 6.0
const TIP_WIDTH := 260.0
const TIP_LAYER := 8
var _portrait: Texture2D
var _font: Font
var _touchscreen := false


func _ready() -> void:
	layer = 4
	_touchscreen = DisplayServer.is_touchscreen_available()
	_font = ThemeDB.fallback_font
	var custom_path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if custom_path != "":
		_font = load(custom_path)
	# The portrait: a head-and-shoulders render of the 3D model.
	_portrait = CharacterArt.portrait_texture()
	_view = Node2D.new()
	_view.draw.connect(_draw_card)
	add_child(_view)
	_tip = UiKit.tooltip_panel()
	_tip.name = "StateTip"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.custom_minimum_size = Vector2(TIP_WIDTH, 0)
	_tip.visible = false
	_tip_text = UiKit.label("", 14, UiKit.TEXT)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.custom_minimum_size = Vector2(TIP_WIDTH - 20.0, 0)
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_text)
	# (over the fish cards down the left - FishAlerts - and the bag's buttons: a layer of its own)
	var over := CanvasLayer.new()
	over.name = "StateTipLayer"
	over.layer = TIP_LAYER
	add_child(over)
	over.add_child(_tip)
	GameState.event_reported.connect(_on_event)


func _on_event(text: String, tone: String) -> void:
	for line in feed:
		if line[0] == text:
			feed.erase(line)
			break
	feed.push_front([text, tone, 0.0])
	feed.resize(mini(feed.size(), FEED_LINES))


func contains(pos: Vector2) -> bool:
	return Rect2(POS, SIZE).has_point(pos) or (SHOW_GEAR and gear_rect().has_point(pos))


## The gear slots' strip.
func gear_rect() -> Rect2:
	return Rect2(GEAR_AT, Vector2(GEAR_SLOT * 3.0 + GEAR_GAP * 2.0, GEAR_SLOT))


## The slots' contents: [item id (for its icon), count (-1: none shown),
## lit (in hand), wears (shows durability)].
static func gear(p: Player) -> Array:
	var fishing := p.state != Player.State.IDLE
	var bait := ["bait", p.bait_count]
	if p.fishing_mode == Player.FishingMode.LURE and p.current_lure != "":
		bait = ["lure_" + p.current_lure, int(p.lure_stock.get(p.current_lure, 0))]
	elif p.live_bait != "":
		bait = ["live_" + p.live_bait, Profile.bag_count("live_" + p.live_bait)]
	return [
		[str(Profile.equipped.get("rod", "")), -1, fishing, true],
		[Profile.offhand(), -1, p.offhand_in_hand(), true],
		[bait[0], bait[1], false, false],
	]


func _process(delta: float) -> void:
	var p := _player()
	if p != null and p != _hooked:
		_hooked = p
		p.ability_triggered.connect(func(_k, _at, _n): _ability_flash = ABILITY_FLASH)
	_ability_flash = maxf(_ability_flash - delta, 0.0)
	_pulse_t += delta
	if _tip.visible:
		_tip_left -= delta
		if _tip_left <= 0.0:
			_tip.visible = false
		elif p != null:
			_tip_text.text = tip_text(_tip_key, p)
	for line in feed:
		line[2] += delta
	feed = feed.filter(func(line): return line[2] < FEED_LIFE + FEED_FADE)
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _touchscreen:
		pos = event.position
	if pos.x < 0.0:
		return
	# (user request: a tap on a state's icon says what it is; a tap anywhere else puts that away)
	for slot in _slots:
		if (slot[0] as Rect2).grow(4.0).has_point(pos):
			if _tip.visible and _tip_key == str(slot[1]):
				_tip.visible = false
			else:
				_show_tip(str(slot[1]), slot[0])
			get_viewport().set_input_as_handled()
			return
	if _tip.visible:
		_tip.visible = false
	if not contains(pos):
		return
	for c in get_parent().get_children():
		if c is DialogBox and c.is_open():
			return
		if c is Backpack:
			c.toggle()
			get_viewport().set_input_as_handled()
			return


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## How fast the player moves now, as a share of full speed (as Player moves it: the load, a
## muddle or a stagger, poison, the oil drum, low spirit, the vigor potion, the cat at night).
static func speed_share(p: Player) -> float:
	var share := Player.carry_speed_ratio(GameState.carried_fish.size())
	if p.water_ghost_timer > 0.0 or p.stagger_timer > 0.0:
		share *= Player.WATER_GHOST_SPEED_MULT
	if p.poison_timer > 0.0:
		share *= Player.POISON_SPEED_MULT
	if p.carrying_oil_drum:
		share *= Player.OIL_DRUM_SPEED_MULT
	if p.vigor_timer > 0.0:
		share *= Player.VIGOR_SPEED
	share *= Profile.SPIRIT_SPEED[Profile.spirit_penalty()]
	return share * p.night_ratio()


## User request: 滿載而歸 - the fish carried that slow the traveller (the bag's and the clasps':
## GameState.carried_fish), one each; past Player's floor they still count, the slowing doesn't.
static func load_count() -> int:
	return GameState.carried_fish.size()


## What a state's slot says when it's tapped.
static func tip_text(key: String, p: Player) -> String:
	match key:
		"load":
			var n := load_count()
			var share := Player.carry_speed_ratio(n)
			var lines := ["【滿載而歸】", "身上帶著 %d 條魚（背包＋活魚扣），每條讓腳步慢 %d%%。" % [n, roundi(Player.WEIGHT_SPEED_PENALTY * 100.0)],
				"負重速度：%d%%" % roundi(share * 100.0)]
			if share <= Player.MIN_SPEED_RATIO + 0.001:
				lines.append("已達上限：再多的魚也不會更慢（最低 %d%%）。" % roundi(Player.MIN_SPEED_RATIO * 100.0))
			lines.append("目前總速度：%d%%（含其他狀態）" % roundi(speed_share(p) * 100.0))
			return "\n".join(lines)
		"fear":
			return "【害怕】\n%s：嚇得動彈不得，暫時不能移動。\n剩餘 %d 秒" % [p.fear_text if p.fear_text != "" else "被嚇到了", ceili(p.fear_timer)] \
				if p.fear_timer > 0.0 else "【害怕】\n已經結束了"
		"muddle":
			return "【混亂】\n%s：方向亂掉，腳步變慢（速度 %d%%）。\n剩餘 %d 秒" % [p.affliction_text if p.affliction_text != "" else "頭昏眼花",
				roundi(Player.WATER_GHOST_SPEED_MULT * 100.0), ceili(p.water_ghost_timer)] \
				if p.water_ghost_timer > 0.0 else "【混亂】\n已經結束了"
		"ability":
			var kind := Abilities.active_kind()
			if kind == "":
				var t := Profile.talent_of()
				if Abilities.TALENTS.has(t):
					return "【天賦：%s】\n%s" % [Abilities.TALENTS[t].name, Abilities.talent_text(t)]
				return ""
			var info := Abilities.info(kind)
			return "【%s】\n%s\n%s" % [info.get("name", ""), info.get("desc", ""),
				"生效中" if Abilities.active(kind, p) else "目前未生效"]
	for e in effects(p):
		if e[0] == key:
			return "【%s】\n%s\n剩餘 %d 秒" % [Items.name_of(key), str(Items.def(key).get("desc", "")), ceili(float(e[1]))]
	return "【%s】\n已經結束了" % Items.name_of(key)


func _show_tip(key: String, at: Rect2) -> void:
	var p := _player()
	if p == null:
		return
	_tip_key = key
	_tip_text.text = tip_text(key, p)
	_tip_left = TIP_LIFE
	_tip.visible = true
	_tip.reset_size()
	_tip.position = Vector2(clampf(at.position.x, 8.0, 950.0 - TIP_WIDTH), at.end.y + 8.0)


## What's wrong (or of note), most pressing first.
static func conditions(p: Player) -> Array:
	var out := []
	if p.held:
		out.append(["被大鬼抓住了", WARN])
	if p.fear_timer > 0.0:
		out.append(["害怕中：%s（%d 秒）" % [p.fear_text, ceili(p.fear_timer)], WARN])
	if p.water_ghost_timer > 0.0:
		out.append(["混亂中：%s（%d 秒）" % [p.affliction_text, ceili(p.water_ghost_timer)], WARN])
	if p.poison_timer > 0.0:
		out.append(["中毒了，腳步沉重（%d 秒）" % ceili(p.poison_timer), WARN])
	if p.carrying_oil_drum:
		out.append(["提著油箱", DIM])
	# (what's been drunk or rubbed on: slots of their own - effects())
	if GameState.has_heart:
		out.append(["❤ 心臟", Color(1.0, 0.5, 0.5)])
	var worn := Profile.spirit_penalty()
	if worn > 0:
		out.append([SpiritBar.WORDS[worn], SpiritBar.COLORS[worn]])
	return out


## What's working now: [item id (its icon), seconds left, of how long].
static func effects(p: Player) -> Array:
	var out := []
	if p.glow_timer > 0.0:
		out.append(["glow_mushroom", minf(p.glow_timer, Player.GLOW_TIME), Player.GLOW_TIME])
	if p.ward_timer > 0.0:
		out.append(["potion_ward", p.ward_timer, Player.WARD_TIME])
	if p.vigor_timer > 0.0:
		out.append(["potion_vigor", p.vigor_timer, Player.VIGOR_TIME])
	return out


## The portrait in the medallion's round: its middle square (the head and
## shoulders - the picture's wider than high), filling the round (user
## report: the whole picture squeezed into a square, the character showed
## thin and small).
func _draw_face(c: Vector2, r: float) -> void:
	var size := _portrait.get_size()
	var side := minf(size.x, size.y)
	var u0 := Vector2((size.x - side) * 0.5 / size.x, (size.y - side) * 0.5 / size.y)
	var u_span := Vector2(side / size.x, side / size.y)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in 32:
		var dir := Vector2.RIGHT.rotated(TAU * k / 32.0)
		pts.append(c + dir * r)
		uvs.append(u0 + (dir * 0.5 + Vector2(0.5, 0.5)) * u_span)
	_view.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _portrait)


## The ability's badge in the first slot (false: the character has none).
func _draw_ability(p: Player) -> bool:
	var kind := Abilities.active_kind()
	var tex := Abilities.icon(kind) if kind != "" else null
	var r := Rect2(EFFECT_AT, Vector2.ONE * EFFECT_SLOT)
	if kind == "" and Profile.talent_of() != "":
		# (a talent taken in place of its own ability: its badge, always lit)
		var tt := Abilities.talent_icon(Profile.talent_of())
		if tt != null:
			# (user request: every state's slot square, the talent's too)
			UiKit.draw_slot(_view, r, "", false, null)
			_view.draw_texture_rect(tt, r.grow(-3.0), false)
			return true
	if tex == null:
		return false
	var on := Abilities.active(kind, p)
	if _ability_flash > 0.0:
		var k := _ability_flash / ABILITY_FLASH
		var color: Color = Abilities.info(kind).get("color", UiKit.GOLD)
		_view.draw_texture_rect(UiKit.glow(), r.grow(10.0 + 6.0 * sin(k * PI * 3.0)), false, Color(color, 0.8 * k))
	UiKit.draw_slot(_view, r, "", false, null)
	_view.draw_texture_rect(tex, r.grow(-3.0), false, Color.WHITE if on else Color(0.55, 0.55, 0.6, 0.75))
	return true


func _slot_rect(i: int) -> Rect2:
	return Rect2(EFFECT_AT + Vector2((EFFECT_SLOT + EFFECT_GAP) * i, 0), Vector2.ONE * EFFECT_SLOT)


## User request: 滿載而歸 - a fish in its slot, how many are carried in its corner (red once the
## slowing's at its floor).
func _draw_load(i: int) -> void:
	var r := _slot_rect(i)
	var n := load_count()
	var share := Player.carry_speed_ratio(n)
	var full := share <= Player.MIN_SPEED_RATIO + 0.001
	UiKit.draw_slot(_view, r, "", false, null)
	var fish := FishData.icon("carp")
	if fish != null:
		var sz := fish.get_size()
		var k := minf((r.size.x - 6.0) / sz.x, (r.size.y - 10.0) / sz.y)
		_view.draw_texture_rect(fish, Rect2(r.get_center() - sz * k * 0.5 - Vector2(0, 2), sz * k), false)
	UiKit.draw_text(_view, Vector2(r.position.x, r.end.y - 2.0), str(n), 13, WARN if full else Color.WHITE,
		HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2.0, true)
	_slots.append([r, "load"])


## User request: being scared (an animal's or a ghost's doing) and muddled are states too - a slot
## each, the time left swept round it and counted: [key, seconds left, of how long].
var _fear_total := 0.0
var _muddle_total := 0.0


func afflictions(p: Player) -> Array:
	var out := []
	_fear_total = maxf(_fear_total, p.fear_timer) if p.fear_timer > 0.0 else 0.0
	_muddle_total = maxf(_muddle_total, p.water_ghost_timer) if p.water_ghost_timer > 0.0 else 0.0
	if p.fear_timer > 0.0:
		out.append(["fear", p.fear_timer, _fear_total])
	if p.water_ghost_timer > 0.0:
		out.append(["muddle", p.water_ghost_timer, _muddle_total])
	return out


## The sweep of the time gone, dark from the top round, over `r`; the seconds left in its corner.
func _draw_time(r: Rect2, left: float, total: float) -> void:
	var gone := 1.0 - clampf(left / maxf(total, 0.001), 0.0, 1.0)
	if gone > 0.0:
		var c := r.get_center()
		var pts := PackedVector2Array([c])
		for k in 25:
			var a := -PI / 2.0 + TAU * gone * k / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * r.size.x)
		for poly in Geometry2D.intersect_polygons(pts, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])):
			_view.draw_colored_polygon(poly, Color(0, 0, 0, 0.5))
	UiKit.draw_text(_view, Vector2(r.position.x, r.end.y - 2.0), str(ceili(left)), 13,
		GOOD if left > 5.0 else WARN, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2.0, true)


func _draw_afflictions(list: Array, from: int) -> void:
	for i in list.size():
		var e: Array = list[i]
		var r := _slot_rect(i + from)
		_slots.append([r, str(e[0])])
		UiKit.draw_slot(_view, r, "", false, null)
		var c := r.get_center() + Vector2(0, -2)
		if e[0] == "fear":
			# (a fright: a red mark, trembling)
			var shake := Vector2(sin(_pulse_t * 40.0), 0.0) * 1.2
			_view.draw_rect(Rect2(c + shake + Vector2(-2.5, -11), Vector2(5, 13)), WARN)
			_view.draw_circle(c + shake + Vector2(0, 7), 2.8, WARN)
			for k in [-1, 1]:
				_view.draw_line(c + Vector2(9 * k, -8), c + Vector2(12 * k, -11), Color(WARN, 0.8), 1.5)
				_view.draw_line(c + Vector2(10 * k, -2), c + Vector2(14 * k, -2), Color(WARN, 0.8), 1.5)
		else:
			# (a muddle: a turning spiral)
			var pts := PackedVector2Array()
			for k in 40:
				var a := _pulse_t * 4.0 + k * 0.42
				pts.append(c + Vector2(cos(a), sin(a)) * (1.5 + k * 0.28))
			_view.draw_polyline(pts, Color(0.85, 0.7, 1.0), 2.0, true)
		_draw_time(r, float(e[1]), float(e[2]))


var _pulse_t := 0.0


func _draw_effects(list: Array, from := 0) -> void:
	for i in list.size():
		var e: Array = list[i]
		var r := _slot_rect(i + from)
		_slots.append([r, str(e[0])])
		UiKit.draw_slot(_view, r, "", false, Items.square_icon(e[0]))
		# (the time gone swept dark round from the top)
		var gone := 1.0 - clampf(float(e[1]) / float(e[2]), 0.0, 1.0)
		if gone > 0.0:
			var c := r.get_center()
			var pts := PackedVector2Array([c])
			for k in 25:
				var a := -PI / 2.0 + TAU * gone * k / 24.0
				pts.append(c + Vector2(cos(a), sin(a)) * r.size.x)
			for poly in Geometry2D.intersect_polygons(pts, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])):
				_view.draw_colored_polygon(poly, Color(0, 0, 0, 0.5))
		UiKit.draw_text(_view, Vector2(r.position.x, r.end.y - 2.0), str(ceili(float(e[1]))), 13,
			GOOD if float(e[1]) > 5.0 else WARN, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2.0, true)


func _draw_card() -> void:
	var p := _player()
	if p == null:
		return
	var ci := _view.get_canvas_item()
	# The name plate, from under the medallion to the right.
	var plate := Rect2(POS + Vector2(PORTRAIT * 0.55, 8), Vector2(SIZE.x - PORTRAIT * 0.55, 30))
	UiKit.plate_box().draw(ci, plate)
	var x := POS.x + PORTRAIT + 6.0
	UiKit.draw_text(_view, Vector2(x, plate.position.y + 21), NAME, 16, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var hint := "背包" if _touchscreen else "背包（I）"
	UiKit.draw_text(_view, Vector2(x, plate.position.y + 21), hint, 12, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT,
		plate.end.x - x - 12.0)
	# Portrait in the gold medallion.
	var c := POS + Vector2(PORTRAIT * 0.5, SIZE.y * 0.5)
	_view.draw_circle(c, PORTRAIT * 0.36, Color(0.06, 0.07, 0.09))
	if _portrait:
		_draw_face(c, PORTRAIT * 0.36)
	_view.draw_texture_rect(UiKit.tex("medallion"), Rect2(c - Vector2.ONE * PORTRAIT * 0.5, Vector2.ONE * PORTRAIT), false)
	# User request (Camp v2): the spirit, under the name.
	SpiritBar.paint(_view, Rect2(Vector2(x, plate.end.y + 4), Vector2(96, 8)))
	# User request (HUD cleanup): no speed or fish count - just what's
	# wrong, if anything.
	if SHOW_GEAR:
		_draw_gear(p)
	var working := effects(p)
	_slots.clear()
	var ability := _draw_ability(p)
	if ability:
		_slots.append([_slot_rect(0), "ability"])
	var at := 1 if ability else 0
	if load_count() > 0:
		_draw_load(at)
		at += 1
	var hurt := afflictions(p)
	_draw_afflictions(hurt, at)
	at += hurt.size()
	_draw_effects(working, at)
	_draw_feed(EFFECT_SLOT + 6.0 if at > 0 or not working.is_empty() else 0.0)
	var line := x
	for cond in conditions(p):
		# (scared and muddled have slots of their own now)
		if str(cond[0]).begins_with("害怕中") or str(cond[0]).begins_with("混亂中"):
			continue
		var w := UiKit.font().get_string_size(cond[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		if line + w > POS.x + SIZE.x - 4.0:
			break
		UiKit.draw_text(_view, Vector2(line, POS.y + 66), cond[0], 12, cond[1])
		line += w + 8.0


func _draw_gear(p: Player) -> void:
	var slots := gear(p)
	for i in slots.size():
		var r := Rect2(GEAR_AT + Vector2((GEAR_SLOT + GEAR_GAP) * i, 0), Vector2.ONE * GEAR_SLOT)
		var id: String = slots[i][0]
		if id == "":
			UiKit.draw_slot(_view, r)
		else:
			UiKit.draw_slot(_view, r, UiKit.item_rarity(id), slots[i][2], Items.square_icon(id))
			if slots[i][3]:
				ItemBoard.draw_wear(_view, r, id)
		UiKit.draw_text(_view, r.position + Vector2(3, 11), GEAR_LABELS[i], 10, UiKit.DIM)
		var n: int = slots[i][1]
		if n >= 0:
			UiKit.draw_text(_view, Vector2(r.position.x, r.end.y - 4.0), str(n), 13,
				Color.WHITE if n > 0 else WARN, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4.0)


func _draw_feed(down := 0.0) -> void:
	var font := UiKit.font()
	for i in feed.size():
		var line: Array = feed[i]
		var age: float = line[2]
		var alpha := clampf(minf(age / 0.15, (FEED_LIFE + FEED_FADE - age) / FEED_FADE), 0.0, 1.0)
		var color: Color = {"good": GOOD, "info": INK}.get(line[1], WARN)
		var w := font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_SIZE).x
		var at := FEED_AT + Vector2(0, i * FEED_GAP + down)
		_view.draw_rect(Rect2(at, Vector2(w + 14.0, FEED_GAP - 3.0)), Color(0, 0, 0, 0.45 * alpha))
		_view.draw_rect(Rect2(at, Vector2(2.0, FEED_GAP - 3.0)), Color(color, 0.9 * alpha))
		var text_at := at + Vector2(8, FEED_SIZE + 1.0)
		_view.draw_string_outline(font, text_at, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_SIZE, 4, Color(UiKit.OUTLINE, UiKit.OUTLINE.a * alpha))
		_view.draw_string(font, text_at, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_SIZE, Color(color, alpha))
