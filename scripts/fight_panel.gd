class_name FightPanel
extends CanvasLayer

## User request: while a fish is on, how it's doing sits in the middle of
## the screen, simply - its stamina, the line's tension and what it's up to
## (running, leaping, berserk, tiring). When it dashes sideways, an arrow
## under the panel shows which way to flick the right stick, with the time
## left to do it running out around it. Replaces the bars that used to sit
## along the top. The tension bar shows its sweet spot (reel faster while
## the tension is in it).
##
## Also drawn over the float: when a fish bites, a ring closing in on it
## for the perfect strike's moment; while a charged light lures fish to it,
## a glow spreading on the water.
##
## Dressed as an MMO's target frame (user request): a dark iron frame,
## the fish's name and mood, framed bars for its stamina and the tension.
## User request: and how far off the fish is (the line out, m, of all on
## the reel) - red past FishFight.DANGER, where the line may snap - and,
## with the fish getting away and the reel still, a turning arrow round the
## right stick: turn it to reel.
## User request: it doesn't say how rare or hard the fish is - that's read
## from the line once struck (FishFight.open: hold the stick and watch the
## tension; a ring round the stick says to hold while the line's slack).

const CENTER_X := 480.0
const TOP := 60.0
const SIZE := Vector2(320, 116)
const BAR_W := 200.0
const BAR_H := 14.0
const CUE_Y := 194.0
const CUE_RADIUS := 24.0
const INK := Color(1.0, 0.96, 0.88)
const DIM := Color(1.0, 0.96, 0.88, 0.6)
const FILL := Color(0.08, 0.07, 0.05, 0.62)
const RIM := Color(1.0, 0.85, 0.55, 0.5)
const RAGE := Color(1.0, 0.3, 0.25)
const STAMINA := Color(0.45, 0.85, 0.55)
const TENSION := Color(1.0, 0.8, 0.4)
const TENSION_HIGH := 0.8
const SWEET := Color(0.55, 0.95, 0.6)
const PERFECT := Color(1.0, 0.88, 0.35)
const RING_FROM := 34.0
const RING_TO := 11.0
const CALLOUT_TIME := 1.4
const LINE := Color(0.55, 0.8, 1.0)
## The right stick's middle on screen (TouchControls.AIM_CENTER) and the
## turning arrow's size round it.
const CRANK_HINT_RADIUS := 64.0

var _view: Node2D
var _font: Font
var _pulse := 0.0
## Something was drawn last frame (so it gets cleared once it's gone).
var _drawn := false


func _ready() -> void:
	layer = 4
	_font = ThemeDB.fallback_font
	var custom_path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if custom_path != "":
		_font = load(custom_path)
	_view = Node2D.new()
	_view.draw.connect(_draw_panel)
	add_child(_view)


func _process(delta: float) -> void:
	_pulse += delta
	var player := _player()
	var busy := player != null and (player.state == Player.State.REELING \
		or player.state == Player.State.BITE or player.light_lure > 0.0)
	if busy or _drawn:
		_view.queue_redraw()
	_drawn = busy


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _fight() -> FishFight:
	var player := _player()
	if player == null or player.state != Player.State.REELING:
		return null
	return player.fight


## The float, on screen.
func _float_pos() -> Vector2:
	var bobber := get_tree().current_scene.get_node_or_null("Bobber") as Node2D
	if bobber == null:
		return Vector2(-100, -100)
	return get_viewport().get_canvas_transform() * bobber.global_position


## What the fish is doing, in words, and in what color.
static func mood_text(fight: FishFight) -> Array:
	match fight.mood():
		"jump":
			return ["跳出水面！放手", RAGE]
		"dive":
			return ["鑽往石縫！收線", RAGE]
		"side_run":
			return ["往%s衝" % FishFight.describe(fight.run_side), TENSION]
		"run":
			return ["狂暴衝刺！" if fight.enraged else "往外衝！放線", RAGE if fight.enraged else TENSION]
		"enraged":
			return ["狂暴", RAGE]
		"spent":
			return ["沒力了！收線上岸", STAMINA]
		"slack":
			return ["線鬆了！按住", RAGE]
		"rally":
			return ["又有力氣了！", RAGE]
		"swim_out":
			return ["往外游", TENSION]
		"swim_in":
			return ["往岸邊游", DIM]
		"swim_side":
			return ["往%s游" % FishFight.describe(fight.swim_side_dir()), TENSION]
		"surge":
			return ["猛拉！頂住", RAGE]
		"opening":
			return ["咬住了，按住頂住", INK]
		"tired":
			return ["疲憊", STAMINA]
	return ["角力中", DIM]


func _draw_panel() -> void:
	var player := _player()
	if player == null:
		return
	if player.state == Player.State.BITE:
		_draw_strike_ring(player)
	elif player.light_lure > 0.0:
		_draw_lure_glow(player.light_lure)
	var fight := _fight()
	if fight == null:
		return
	var rect := Rect2(Vector2(CENTER_X - SIZE.x * 0.5, TOP), SIZE)
	UiKit.frame_box(true).draw(_view.get_canvas_item(), rect)
	if fight.enraged:
		var rim := RAGE
		rim.a = 0.45 + 0.4 * sin(_pulse * 10.0)
		_view.draw_rect(rect.grow(-3.0), rim, false, 3.0)

	var x := rect.position.x + 18.0
	var mood := mood_text(fight)
	UiKit.draw_text(_view, Vector2(x, rect.position.y + 25), "上鉤的魚", 15, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	UiKit.draw_text(_view, Vector2(rect.end.x - 18.0 - 170.0, rect.position.y + 25), mood[0], 16, mood[1],
		HORIZONTAL_ALIGNMENT_RIGHT, 170.0, true)

	var bar_x := rect.end.x - 18.0 - BAR_W
	_row(Vector2(x, rect.position.y + 50), bar_x, "體力", fight.stamina(), STAMINA)
	var sweet := fight.in_sweet()
	var tension_color := RAGE if fight.tension > TENSION_HIGH else (SWEET if sweet else TENSION)
	var at := Vector2(x, rect.position.y + 74)
	_row(at, bar_x, "張力", fight.tension, tension_color, SWEET if sweet else DIM)
	var zone := fight.sweet_range()
	var band := Rect2(bar_x + 3.0 + (BAR_W - 6.0) * zone.x, at.y - BAR_H + 1.0, (BAR_W - 6.0) * (zone.y - zone.x), BAR_H)
	_view.draw_rect(band, Color(SWEET, 0.9 if sweet else 0.55), false, 1.5)
	_draw_distance(fight, Vector2(x, rect.position.y + 98), bar_x)
	_draw_crank_hint(fight, player)

	if fight.swipe_left > 0.0:
		_draw_swipe_cue(fight)
	elif fight.perfect and fight.age < CALLOUT_TIME:
		var a := clampf((CALLOUT_TIME - fight.age) / 0.4, 0.0, 1.0)
		UiKit.draw_text(_view, Vector2(CENTER_X - 100, CUE_Y + 6), "完美揚竿！", 24, Color(PERFECT, a), HORIZONTAL_ALIGNMENT_CENTER, 200, true)


## The line out: how far off the fish is (m) on a bar of all the line,
## its danger end marked - in red, pulsing, once it's out there.
func _draw_distance(fight: FishFight, at: Vector2, bar_x: float) -> void:
	var share := fight.line_share()
	var danger := fight.danger() > 0.0
	var red := Color(RAGE, 0.7 + 0.3 * sin(_pulse * 12.0)) if danger else LINE
	UiKit.draw_text(_view, at, "距離", 13, RAGE if danger else DIM)
	var bar := Rect2(bar_x, at.y - BAR_H + 1.0, BAR_W, BAR_H)
	UiKit.draw_bar(_view, bar, share, red)
	var mark := bar.position.x + 3.0 + (BAR_W - 6.0) * FishFight.DANGER
	_view.draw_rect(Rect2(mark, bar.position.y, bar.end.x - 3.0 - mark, BAR_H), Color(RAGE, 0.18), true)
	_view.draw_line(Vector2(mark, bar.position.y - 1.0), Vector2(mark, bar.end.y + 1.0), Color(RAGE, 0.85), 1.5)
	UiKit.draw_text(_view, Vector2(bar.position.x, at.y), "%.0f / %.0f 公尺" % [fight.distance, fight.line_max], 11,
		INK if not danger else Color(1, 0.9, 0.85), HORIZONTAL_ALIGNMENT_CENTER, BAR_W, true)


## The fish taking line while the reel's still: a turning arrow round the
## right stick (touch screens; Space on a keyboard - said in words).
func _draw_crank_hint(fight: FishFight, player: Player) -> void:
	if fight.opening_left > 0.0:
		_draw_hold_hint(fight)
		return
	if fight.crank >= FishFight.HELD_AT or fight.jump_left > 0.0 or fight.run_left > 0.0 or fight.line_share() < 0.3:
		return
	var a := 0.45 + 0.35 * sin(_pulse * 6.0)
	if DisplayServer.is_touchscreen_available():
		var c := TouchControls.AIM_CENTER
		var start := _pulse * 3.0
		_view.draw_arc(c, CRANK_HINT_RADIUS, start, start + PI * 1.4, 40, Color(LINE, a), 4.0)
		var end := start + PI * 1.4
		var tip := c + Vector2.RIGHT.rotated(end) * CRANK_HINT_RADIUS
		var along := Vector2.RIGHT.rotated(end + PI * 0.5)
		var out := Vector2.RIGHT.rotated(end)
		_view.draw_colored_polygon(PackedVector2Array([tip + along * 12.0, tip + out * 9.0, tip - out * 9.0]), Color(LINE, a))
		UiKit.draw_text(_view, c + Vector2(-60, -CRANK_HINT_RADIUS - 12.0), "轉動收線", 15, Color(LINE, a + 0.2), HORIZONTAL_ALIGNMENT_CENTER, 120, true)
	else:
		UiKit.draw_text(_view, Vector2(CENTER_X - 120, CUE_Y + 6), "魚越跑越遠！按住空白鍵收線", 16, Color(LINE, a + 0.2), HORIZONTAL_ALIGNMENT_CENTER, 240, true)


## Struck, the line slack: a ring round the right stick - hold it.
func _draw_hold_hint(fight: FishFight) -> void:
	if fight.hold or fight.crank >= FishFight.HELD_AT:
		return
	var a := 0.55 + 0.35 * sin(_pulse * 10.0)
	if DisplayServer.is_touchscreen_available():
		var c := TouchControls.AIM_CENTER
		_view.draw_arc(c, CRANK_HINT_RADIUS, 0.0, TAU, 48, Color(RAGE, a), 4.0)
		UiKit.draw_text(_view, c + Vector2(-60, -CRANK_HINT_RADIUS - 12.0), "按住頂住", 15, Color(RAGE, a + 0.2), HORIZONTAL_ALIGNMENT_CENTER, 120, true)
	else:
		UiKit.draw_text(_view, Vector2(CENTER_X - 120, CUE_Y + 6), "線鬆了！按住空白鍵頂住", 16, Color(RAGE, a + 0.2), HORIZONTAL_ALIGNMENT_CENTER, 240, true)


func _row(at: Vector2, bar_x: float, text: String, value: float, color: Color, ink := DIM) -> void:
	UiKit.draw_text(_view, at, text, 13, ink)
	UiKit.draw_bar(_view, Rect2(bar_x, at.y - BAR_H + 1.0, BAR_W, BAR_H), value, color)


## Which way to flick, and how long is left to do it.
func _draw_swipe_cue(fight: FishFight) -> void:
	var c := Vector2(CENTER_X, CUE_Y)
	var dir := -fight.run_side.normalized()
	var left := fight.swipe_left / FishFight.SWIPE_WINDOW
	_view.draw_circle(c, CUE_RADIUS, FILL)
	_view.draw_arc(c, CUE_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * left, 32, TENSION, 3.0)
	var tip := c + dir * 15.0
	var tail := c - dir * 13.0
	var side := dir.orthogonal() * 8.0
	_view.draw_line(tail, tip - dir * 6.0, INK, 4.0)
	_view.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 11.0 + side, tip - dir * 11.0 - side]), INK)
	_view.draw_string(_font, c + Vector2(-40, CUE_RADIUS + 16), "往%s甩！" % FishFight.describe(dir), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, INK)


## The bite: a ring closes in on the float - strike as it meets the float
## for a perfect strike; after that, just the float marked.
func _draw_strike_ring(player: Player) -> void:
	var c := _float_pos()
	var window := player.perfect_hook_window()
	var left := player.perfect_hook_left()
	_view.draw_arc(c, RING_TO, 0.0, TAU, 32, Color(PERFECT, 0.9), 2.0)
	if left > 0.0:
		var t := 1.0 - left / maxf(window, 0.01)
		_view.draw_arc(c, lerpf(RING_FROM, RING_TO, t), 0.0, TAU, 40, Color(PERFECT, 0.5 + 0.5 * t), 3.0)


## A charged light on the float: rings of light spreading on the water.
func _draw_lure_glow(strength: float) -> void:
	var c := _float_pos()
	for i in 3:
		var t := fposmod(_pulse * 0.6 + i / 3.0, 1.0)
		_view.draw_arc(c, lerpf(10.0, 44.0, t), 0.0, TAU, 40, Color(PERFECT, (1.0 - t) * 0.55 * strength), 1.5)
	_view.draw_string(_font, c + Vector2(-40, -26), "誘魚中", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(PERFECT, 0.5 + 0.4 * strength))
