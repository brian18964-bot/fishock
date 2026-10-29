class_name FishAlerts
extends CanvasLayer

## User request: at night there's no time to open the bag and look at the fish's
## vitality - so when a carried fish's vitality falls to ALERT_AT, a small card
## for it is pinned in the clear space down the left side (like the catch card, on
## the other side): its picture, name, and its vitality bar - dead, its freshness
## bar running down. Tap a card for the fish's full card (the backpack's, with
## that fish picked); close one with its ✕ or by flicking it off to the left; the
## eye hides them all (and shows them again).

const ALERT_AT := 0.30
const AT := Vector2(8, 126)
const CARD := Vector2(182, 48)
const GAP := 5.0
const MAX_SHOWN := 4
const REFRESH := 0.25

var _root: Control
var _eye: Eye
var _cards: Dictionary = {}     # uid -> AlertCard
var _dismissed: Dictionary = {}  # uid -> true: closed by the player, not shown again
var _hidden := false
var _t := 0.0


func _init() -> void:
	layer = 6


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_eye = Eye.new()
	_eye.position = AT
	_eye.size = Vector2(30, 26)
	_eye.visible = false
	_eye.pressed.connect(_toggle_hidden)
	_root.add_child(_eye)


func _process(delta: float) -> void:
	_t += delta
	if _t < REFRESH:
		return
	_t = 0.0
	_sync()


## Whether `fish` is one to show: alive and run down to ALERT_AT, or dead / rotten.
static func wants(fish: Dictionary) -> bool:
	if not FishLife.has_life(fish):
		return false
	match FishLife.state(fish):
		"alive":
			return not FishLife.has_trait(fish, "immortal") and float(fish.get("vit", 1.0)) <= ALERT_AT
	return true


func _sync() -> void:
	var live := {}
	for fish in GameState.carried_fish:
		var uid: int = int(fish.get("uid", -1))
		if uid < 0 or _dismissed.has(uid) or not wants(fish):
			continue
		live[uid] = fish
		if not _cards.has(uid):
			var card := AlertCard.new()
			card.fish = fish
			card.uid = uid
			card.size = CARD
			card.opened.connect(_open_fish)
			card.closed.connect(_dismiss)
			_root.add_child(card)
			_cards[uid] = card
	for uid in _cards.keys():
		if not live.has(uid):
			(_cards[uid] as Node).queue_free()
			_cards.erase(uid)
	_layout()


func _layout() -> void:
	_eye.visible = not _cards.is_empty()
	_eye.slashed = _hidden
	_eye.queue_redraw()
	var i := 0
	for uid in _cards:
		var card: AlertCard = _cards[uid]
		card.visible = not _hidden and i < MAX_SHOWN
		card.position = AT + Vector2(0, 31.0 + i * (CARD.y + GAP))
		i += 1


func _toggle_hidden() -> void:
	_hidden = not _hidden
	_layout()


func _dismiss(uid: int) -> void:
	_dismissed[uid] = true
	if _cards.has(uid):
		(_cards[uid] as Node).queue_free()
		_cards.erase(uid)
	_layout()


## The fish's full card: the backpack opened with it picked.
func _open_fish(uid: int) -> void:
	for c in get_parent().get_children():
		if c is Backpack:
			if not c.is_open():
				c.toggle()
			for i in GameState.carried_fish.size():
				if int(GameState.carried_fish[i].get("uid", -2)) == uid:
					c.select("fish", i)
			return


## The eye: tap to hide every card (slashed), tap again to show them.
class Eye extends Control:
	signal pressed
	var slashed := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
				or (event is InputEventScreenTouch and not event.pressed):
			pressed.emit()
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		var c := size / 2.0
		var col := Color(1.0, 0.92, 0.7, 0.95)
		var pts := PackedVector2Array()
		for k in 21:
			var x := lerpf(-12.0, 12.0, k / 20.0)
			pts.append(c + Vector2(x, -7.0 * sin(PI * k / 20.0)))
		for k in 21:
			var x := lerpf(12.0, -12.0, k / 20.0)
			pts.append(c + Vector2(x, 7.0 * sin(PI * k / 20.0)))
		draw_polyline(pts, col, 2.0, true)
		draw_circle(c, 4.0, col)
		if slashed:
			draw_line(c + Vector2(-13, 9), c + Vector2(13, -9), Color(1.0, 0.45, 0.4), 3.0, true)


## One fish's card.
class AlertCard extends Control:
	signal opened(uid: int)
	signal closed(uid: int)

	var fish := {}
	var uid := -1
	var _down := false
	var _from := Vector2.ZERO
	var _moved := 0.0
	var _shift := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(_delta: float) -> void:
		queue_redraw()

	func _close_rect() -> Rect2:
		return Rect2(size.x - 22.0, 3.0, 19.0, 19.0)

	func _gui_input(event: InputEvent) -> void:
		var pos := Vector2(-1, -1)
		var press := false
		var release := false
		var motion := false
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
			press = event.pressed
			release = not event.pressed
		elif event is InputEventMouseMotion and _down:
			pos = event.position
			motion = true
		elif event is InputEventScreenTouch:
			pos = event.position
			press = event.pressed
			release = not event.pressed
		elif event is InputEventScreenDrag:
			pos = event.position
			motion = true
		else:
			return
		if press:
			_down = true
			_from = pos
			_moved = 0.0
			_shift = 0.0
		elif motion and _down:
			_shift = minf(pos.x - _from.x, 0.0)
			_moved = maxf(_moved, pos.distance_to(_from))
			position.x = AlertCardPlace.x + _shift
		elif release and _down:
			_down = false
			position.x = AlertCardPlace.x
			if _shift < -50.0:
				closed.emit(uid)
			elif _moved < 10.0:
				if _close_rect().has_point(pos):
					closed.emit(uid)
				else:
					opened.emit(uid)
		accept_event()

	const AlertCardPlace := Vector2(8, 0)

	func _draw() -> void:
		draw_style_box(UiKit.frame_box(true), Rect2(Vector2.ZERO, size))
		var st := FishLife.state(fish)
		var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
		var slot := Rect2(Vector2(5, 7), Vector2(34, 34))
		UiKit.draw_slot(self, slot, UiKit.fish_rarity(fish), false, tex)
		var name_col := Color.WHITE if st == "alive" else Color(0.75, 0.75, 0.8)
		UiKit.draw_text(self, Vector2(46, 18), str(fish.get("name", "魚")), 13, name_col, HORIZONTAL_ALIGNMENT_LEFT, size.x - 72.0, true)
		var bar := FishLife.bar(fish)
		var label := "%s %d%%" % [bar.label, roundi(float(bar.share) * 100.0)]
		var col: Color = FishVitals.FRESH_COLOR if bar.kind == "fresh" else (FishVitals.ROT_COLOR if bar.kind == "rotten" \
			else FishVitals.VIT_COLOR.lerp(FishVitals.VIT_LOW, 1.0 - clampf(float(bar.share) * 3.0, 0.0, 1.0)))
		if st == "rotten":
			label = "腐敗了"
		UiKit.draw_text(self, Vector2(46, 42), label, 10, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 60.0)
		UiKit.draw_bar(self, Rect2(106, 31, size.x - 116.0, 10), float(bar.share), col)
		if fish.get("weak", false):
			UiKit.draw_text(self, Vector2(46, 30), "虛弱", 9, Color(1.0, 0.55, 0.45), HORIZONTAL_ALIGNMENT_LEFT, 40.0)
		var x := _close_rect()
		draw_rect(x, Color(0, 0, 0, 0.35))
		draw_line(x.position + Vector2(5, 5), x.end - Vector2(5, 5), Color(1, 0.9, 0.8, 0.9), 2.0, true)
		draw_line(Vector2(x.end.x - 5, x.position.y + 5), Vector2(x.position.x + 5, x.end.y - 5), Color(1, 0.9, 0.8, 0.9), 2.0, true)
