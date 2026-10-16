class_name BaitSlot
extends CanvasLayer

## User request (round 3): the right stick's corner dressed as a rod - a
## faint rod across it with the reel on the stick (its crank turning with
## the stick while it's worked), the line running off the rod's tip and
## back in to the bait on it at the top: a slot showing the bait on the
## hook (or the lure on the line) and how many are left, hung on the line
## by a swivel. A tap on it opens a little window over it of what's in the
## bag to fish with - the base bait, the live baits, the lures - and a tap
## on one puts it on (only between casts). The bait's shown here, not under
## the character card any more.

## The slot's centre and size (the 960x540 layout, over the quick slots -
## TouchControls).
const AT := TouchControls.AIM_CENTER + Vector2(33, -230)
const SIDE := 56.0
## The rod: along ROD_DIR from the stick, its butt ROD_BUTT behind it; the
## line back in from the screen's edge at LINE_FROM.
const ROD_DIR := Vector2(0.62, -0.785)
const ROD_BUTT := 150.0
const LINE_FROM := Vector2(962, AT.y - 34.0)
const INK := Color(0.92, 0.88, 0.8)
const PICK := 54.0

var _deco: RodDeco
var _slot: SlotView
var _picker: Control
var _touch := -1


func _ready() -> void:
	layer = 5
	_deco = RodDeco.new()
	_deco.name = "RodDeco"
	_deco.visible = DisplayServer.is_touchscreen_available()
	add_child(_deco)
	_slot = SlotView.new()
	_slot.name = "BaitButton"
	_slot.size = Vector2(SIDE, SIDE)
	_slot.position = AT - _slot.size * 0.5
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_to_group("hud_block")
	add_child(_slot)
	GameState.run_ended.connect(func(_won, _message):
		close_picker()
		visible = false)


func _process(_delta: float) -> void:
	_slot.queue_redraw()
	if _deco.visible:
		_deco.queue_redraw()


## What's on the hook now: [icon id, how many left, name].
static func current(p: Player) -> Array:
	if p.fishing_mode == Player.FishingMode.LURE and p.current_lure != "":
		return ["lure_" + p.current_lure, int(p.lure_stock.get(p.current_lure, 0)), Profile.LURES[p.current_lure].name]
	if p.live_bait != "":
		return ["live_" + p.live_bait, Profile.bag_count("live_" + p.live_bait), Profile.LIVE_BAITS[p.live_bait].name]
	return ["bait", p.bait_count, "餌料"]


## What there is to fish with: [icon id, how many, name, put it on].
static func choices(p: Player) -> Array:
	var out := []
	out.append(["bait", p.bait_count, "餌料", func():
		p.choose_live_bait("")
		p.choose_bobber()])
	for key in Profile.LIVE_BAITS:
		var n := Profile.bag_count("live_" + key)
		if n > 0:
			out.append(["live_" + key, n, Profile.LIVE_BAITS[key].name, func(): p.choose_live_bait(key)])
	for id in Profile.LURE_ORDER:
		var n := int(p.lure_stock.get(id, 0))
		if n > 0:
			out.append(["lure_" + id, n, Profile.LURES[id].name, func(): p.choose_lure(id)])
	return out


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _picker != null:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			# (the picker's buttons get it as a click)
			get_viewport().set_input_as_handled()
		return
	var pos := Vector2.INF
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		pos = event.position
		down = event.pressed and _touch == -1
		up = not event.pressed and event.index == _touch
		if down and _slot_rect().has_point(pos):
			_touch = event.index
			_slot.pressed = true
			get_viewport().set_input_as_handled()
		elif up:
			_touch = -1
			_slot.pressed = false
			if _slot_rect().has_point(pos):
				tap()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and not DisplayServer.is_touchscreen_available() and _slot_rect().has_point(event.position):
		tap()
		get_viewport().set_input_as_handled()


func _slot_rect() -> Rect2:
	return Rect2(_slot.position, _slot.size).grow(6.0)


## The slot tapped: the picker, between casts.
func tap() -> void:
	var p := _player()
	if p == null:
		return
	if p.state != Player.State.IDLE:
		GameState.report("收竿後才能換餌")
		_slot.shake()
		return
	open_picker()


func open_picker() -> void:
	close_picker()
	var p := _player()
	if p == null:
		return
	Backpack.set_sticks_enabled(get_tree(), false)
	var shade := ColorRect.new()
	shade.name = "BaitPicker"
	shade.color = Color(0, 0, 0, 0.25)
	shade.size = Vector2(960, 540)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_to_group("hud_block")
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_picker())
	add_child(shade)
	_picker = shade
	var panel := UiKit.tooltip_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiKit.label("換餌（背包裡的餌與路亞）", 14, UiKit.GOLD_BRIGHT, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var on: String = current(p)[0]
	for c in choices(p):
		var id: String = c[0]
		var b := Button.new()
		b.name = "Bait_" + id
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = Vector2(PICK, PICK + 18.0)
		var pic: ItemBoard.ItemIcon = ItemBoard.icon_box(id, PICK - 6.0)
		pic.count = int(c[1])
		pic.position = Vector2(3, 0)
		pic.size = Vector2(PICK - 6.0, PICK - 6.0)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		var name_label := UiKit.label(str(c[2]), 11, UiKit.GOLD_BRIGHT if id == on else UiKit.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(-6, PICK - 4.0)
		name_label.size = Vector2(PICK + 12.0, 16)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(name_label)
		if id == on:
			b.modulate = Color(1.25, 1.18, 0.9)
		var put_on: Callable = c[3]
		b.pressed.connect(func():
			put_on.call()
			Sfx.play("ui_click", -10.0)
			close_picker())
		row.add_child(b)
	col.add_child(row)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	# (over the slot, kept on the screen)
	panel.position = Vector2(clampf(AT.x + SIDE * 0.5 - panel.size.x, 8.0, 952.0 - panel.size.x),
		maxf(AT.y - SIDE * 0.5 - 14.0 - panel.size.y, 6.0))


func close_picker() -> void:
	if _picker != null:
		_picker.queue_free()
		_picker = null
		Backpack.set_sticks_enabled(get_tree(), true)


func picker_open() -> bool:
	return _picker != null


## The slot: the bait's picture, how many, 換餌; a swivel on its top edge
## where the line ties on.
class SlotView extends Control:
	var pressed := false
	var _shake := 0.0

	func shake() -> void:
		_shake = 1.0

	func _process(delta: float) -> void:
		_shake = maxf(_shake - delta * 3.0, 0.0)

	func _draw() -> void:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p == null:
			return
		var on := BaitSlot.current(p)
		var r := Rect2(Vector2.ZERO, size)
		r.position.x += sin(_shake * 40.0) * 4.0 * _shake
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.5 if pressed else 0.34)
		box.border_color = Color(1.0, 0.45, 0.35, 0.8) if _shake > 0.0 else QuickSlots.RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(9)
		draw_style_box(box, r)
		var tex := Items.square_icon(on[0])
		if tex != null:
			draw_texture_rect(tex, r.grow(-8.0), false, Color(1, 1, 1, 0.92) if int(on[1]) > 0 else Color(0.45, 0.45, 0.45, 0.6))
		var font := UiKit.font(true)
		var n := str(on[1])
		draw_string_outline(font, Vector2(r.position.x, r.position.y + 15.0), n, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5.0, 13, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(r.position.x, r.position.y + 15.0), n, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5.0, 13,
			Color(1, 0.4, 0.35) if int(on[1]) == 0 else Color.WHITE)
		UiKit.draw_text(self, Vector2(r.position.x, r.end.y - 4.0), "換餌", 11, UiKit.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, true)
		# the swivel: an eye on the top edge, a ring over it
		var top := Vector2(r.get_center().x, r.position.y)
		draw_arc(top + Vector2(0, -1), 4.5, PI, TAU, 12, BaitSlot.INK, 2.0, true)
		draw_line(top + Vector2(0, -6), top + Vector2(0, -10), BaitSlot.INK, 2.0, true)
		draw_arc(top + Vector2(0, -13.5), 3.5, 0.0, TAU, 14, BaitSlot.INK, 2.0, true)


## The faint rod, its reel on the right stick and the line to the bait.
class RodDeco extends Node2D:
	var _crank := 0.6

	func _draw() -> void:
		var c := TouchControls.AIM_CENTER
		var u := BaitSlot.ROD_DIR.normalized()
		var side := u.orthogonal()
		var ink := Color(BaitSlot.INK, 0.26)
		# the blank, tapering, from its butt out past the screen's edge
		var far := 700.0
		draw_colored_polygon(PackedVector2Array([c - u * BaitSlot.ROD_BUTT + side * 5.0, c + u * far + side * 1.5,
			c + u * far - side * 1.5, c - u * BaitSlot.ROD_BUTT - side * 5.0]), ink)
		# the cork grip
		draw_colored_polygon(PackedVector2Array([c - u * (BaitSlot.ROD_BUTT - 6.0) + side * 7.5, c - u * 56.0 + side * 6.5,
			c - u * 56.0 - side * 6.5, c - u * (BaitSlot.ROD_BUTT - 6.0) - side * 7.5]), Color(0.86, 0.74, 0.55, 0.26))
		# the guides
		for t in [82.0, 175.0, 262.0]:
			draw_arc(c + u * t, 5.0 - t / 90.0, 0.0, TAU, 12, Color(BaitSlot.INK, 0.35), 1.5, true)
		# the line, up the rod and off it, and back in to the bait's swivel
		draw_line(c + u * 6.0, c + u * far, Color(1, 1, 1, 0.22), 1.0, true)
		var to := BaitSlot.AT + Vector2(0, -BaitSlot.SIDE * 0.5 - 17.0)
		var pts := PackedVector2Array()
		for i in 25:
			var s := i / 24.0
			pts.append(BaitSlot.LINE_FROM.lerp(to, s) + Vector2(0, sin(s * PI) * 12.0))
		draw_polyline(pts, Color(1, 1, 1, 0.5), 1.2, true)
		# the reel on the stick: spool, spokes, crank and knob - the crank
		# turned the way the stick's pushed while it's worked
		var stick := get_tree().current_scene.get_node_or_null("HUD/Panel/AimJoystick")
		if stick != null and stick.get("is_pressed") and (stick.get("output") as Vector2).length() > 0.2:
			_crank = (stick.get("output") as Vector2).angle()
		draw_arc(c, 43.0, 0.0, TAU, 48, Color(BaitSlot.INK, 0.36), 2.5, true)
		draw_circle(c, 28.0, Color(BaitSlot.INK, 0.1))
		draw_arc(c, 28.0, 0.0, TAU, 40, Color(BaitSlot.INK, 0.28), 1.5, true)
		for k in 8:
			var d := Vector2.RIGHT.rotated(k * TAU / 8.0)
			draw_line(c + d * 10.0, c + d * 27.0, Color(BaitSlot.INK, 0.16), 1.5, true)
		draw_circle(c, 7.0, Color(BaitSlot.INK, 0.45))
		var knob := c + Vector2.RIGHT.rotated(_crank) * 38.0
		draw_line(c, knob, Color(BaitSlot.INK, 0.5), 3.5, true)
		draw_circle(knob, 8.5, Color(0.95, 0.9, 0.78, 0.6))
		for a0 in [PI * 1.1, PI * 0.1]:
			draw_arc(c, 54.0, a0, a0 + 1.2, 16, Color(1.0, 0.9, 0.66, 0.26), 2.0, true)
