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
const EFFECT_AT := Vector2(10, 80)
const EFFECT_SLOT := 34.0
const EFFECT_GAP := 5.0

## The lines showing: [text, tone, age], newest first.
var feed: Array = []

var _view: Node2D
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
	if pos.x < 0.0 or not contains(pos):
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


## How fast the player moves now, as a share of full speed.
static func speed_share(p: Player) -> float:
	var share := Player.carry_speed_ratio(GameState.carried_fish.size())
	if p.water_ghost_timer > 0.0:
		share *= Player.WATER_GHOST_SPEED_MULT
	if p.poison_timer > 0.0:
		share *= Player.POISON_SPEED_MULT
	if p.carrying_oil_drum:
		share *= Player.OIL_DRUM_SPEED_MULT
	if p.vigor_timer > 0.0:
		share *= Player.VIGOR_SPEED
	return share


## What's wrong (or of note), most pressing first.
static func conditions(p: Player) -> Array:
	var out := []
	if p.held:
		out.append(["被大鬼抓住了", WARN])
	if p.water_ghost_timer > 0.0:
		out.append([p.affliction_text, WARN])
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


func _draw_effects(list: Array) -> void:
	for i in list.size():
		var e: Array = list[i]
		var r := Rect2(EFFECT_AT + Vector2((EFFECT_SLOT + EFFECT_GAP) * i, 0), Vector2.ONE * EFFECT_SLOT)
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
	var face := PORTRAIT * 0.62
	if _portrait:
		_view.draw_texture_rect(_portrait, Rect2(c - Vector2.ONE * face * 0.5, Vector2.ONE * face), false)
	_view.draw_texture_rect(UiKit.tex("medallion"), Rect2(c - Vector2.ONE * PORTRAIT * 0.5, Vector2.ONE * PORTRAIT), false)
	# User request (Camp v2): the spirit, under the name.
	SpiritBar.paint(_view, Rect2(Vector2(x, plate.end.y + 4), Vector2(96, 8)))
	# User request (HUD cleanup): no speed or fish count - just what's
	# wrong, if anything.
	if SHOW_GEAR:
		_draw_gear(p)
	var working := effects(p)
	_draw_effects(working)
	_draw_feed(EFFECT_SLOT + 6.0 if not working.is_empty() else 0.0)
	var line := x
	for cond in conditions(p):
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
