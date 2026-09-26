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
## Plain for now: the whole UI is to be redesigned later.

const CENTER_X := 480.0
const TOP := 64.0
const SIZE := Vector2(280, 66)
const BAR_W := 180.0
const BAR_H := 9.0
const CUE_Y := 170.0
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
	_view.draw_rect(rect, FILL)
	var rim := RIM
	if fight.enraged:
		rim = RAGE
		rim.a = 0.55 + 0.4 * sin(_pulse * 10.0)
	_view.draw_rect(rect, rim, false, 2.0 if fight.enraged else 1.0)

	var x := rect.position.x + 12.0
	var mood := mood_text(fight)
	_view.draw_string(_font, Vector2(x, rect.position.y + 17), "魚・%s" % fight.label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_view.draw_string(_font, Vector2(rect.end.x - 12.0 - 150.0, rect.position.y + 19), mood[0], HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 16, mood[1])

	var bar_x := rect.end.x - 12.0 - BAR_W
	_row(Vector2(x, rect.position.y + 38), bar_x, "體力", fight.stamina(), STAMINA)
	var sweet := fight.in_sweet()
	var tension_color := RAGE if fight.tension > TENSION_HIGH else (SWEET if sweet else TENSION)
	var at := Vector2(x, rect.position.y + 56)
	var zone := fight.sweet_range()
	var band := Rect2(bar_x + BAR_W * zone.x, at.y - BAR_H - 1.0, BAR_W * (zone.y - zone.x), BAR_H + 4.0)
	_view.draw_rect(band, Color(SWEET, 0.22))
	_row(at, bar_x, "張力", fight.tension, tension_color, SWEET if sweet else DIM)
	_view.draw_rect(band, Color(SWEET, 0.9 if sweet else 0.5), false, 1.0)

	if fight.swipe_left > 0.0:
		_draw_swipe_cue(fight)
	elif fight.perfect and fight.age < CALLOUT_TIME:
		var a := clampf((CALLOUT_TIME - fight.age) / 0.4, 0.0, 1.0)
		_view.draw_string(_font, Vector2(CENTER_X - 100, CUE_Y + 6), "完美揚竿！", HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color(PERFECT, a))


func _row(at: Vector2, bar_x: float, text: String, value: float, color: Color, ink := DIM) -> void:
	_view.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	var bar := Rect2(bar_x, at.y - BAR_H + 1.0, BAR_W, BAR_H)
	_view.draw_rect(bar, Color(1, 1, 1, 0.12))
	_view.draw_rect(Rect2(bar.position, Vector2(BAR_W * clampf(value, 0.0, 1.0), BAR_H)), color)


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
