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
## User request (damage numbers, FishFight's `hits`): the fish's stamina is a health
## bar with its number and every hit on it jumps up over the float as a number, as
## in an RPG - the reel's small and white (gold in the sweet spot), a flicked dash a
## crit, a quick one a perfect crit, the strike's perfect; what the fish does to the
## line shows beside the tension bar in red with its name (a leap, a run, a dash for
## cover), a move answered in time a green parry, and a ring and a "!" warn of the
## moves. (Settings: damage_numbers.)
##
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
## The numbers in the air: {text, label, pos, vel, age, life, size, color, kind}.
var _pops: Array = []
## The tension bar flashes red when a move hurts (s left).
var _hurt_flash := 0.0
## A flash round the screen's edge, and its colour: red for a hard hit taken, gold for
## a crit landed (user request: the numbers felt in the hand too - a buzz on a
## touchscreen).
var _edge := 0.0
var _edge_color := RAGE


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
	_take_hits(player, delta)
	if busy or _drawn or not _pops.is_empty() or _edge > 0.0:
		_view.queue_redraw()
	_drawn = busy


## The queued hits of the fight (taken whether or not they're shown), turned into
## numbers; the numbers in the air moving on.
func _take_hits(player: Player, delta: float) -> void:
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_edge = maxf(_edge - delta * 1.8, 0.0)
	if player != null and player.fight != null:
		var show: bool = Profile.settings.get("damage_numbers", true)
		for hit in player.fight.drain_hits():
			if show:
				_add_pop(hit)
	for pop in _pops:
		pop.age += delta
		pop.pos += pop.vel * delta
		pop.vel *= maxf(1.0 - 2.2 * delta, 0.0)
	_pops = _pops.filter(func(pop): return pop.age < pop.life)


## The panel's tension bar, for where the hurts show (right of it).
func _hurt_at() -> Vector2:
	return Vector2(CENTER_X + SIZE.x * 0.5 + 10.0, TOP + 74.0 - 8.0)


func _add_pop(hit: Dictionary) -> void:
	var at := _float_pos() + Vector2(randf_range(-22.0, 22.0), randf_range(-24.0, -8.0))
	var pop := {"text": "", "label": "", "pos": at, "vel": Vector2(randf_range(-16.0, 16.0), -70.0), "age": 0.0,
		"life": 1.0, "size": 18, "color": INK, "kind": "text", "pop": 0.0}
	match hit.type:
		"dmg":
			pop.text = "-" + _fmt(hit.n)
			match hit.style:
				"tick":
					pop.size = 17
				"sweet":
					pop.size = 22
					pop.color = PERFECT
					pop.life = 1.1
				"swipe":
					pop.size = 36
					pop.color = Color(1.0, 0.55, 0.2)
					pop.label = "暴擊！"
					pop.life = 1.4
					pop.pop = 0.7
					_add_ring(at, Color(1.0, 0.55, 0.2))
				"perfect":
					pop.size = 44
					pop.color = Color(1.0, 0.93, 0.55)
					pop.label = "完美暴擊！"
					pop.life = 1.6
					pop.pop = 0.9
					_add_ring(at, PERFECT)
				"strike":
					pop.size = 42
					pop.color = Color(1.0, 0.93, 0.55)
					pop.label = "完美揚竿！"
					pop.life = 1.6
					pop.pop = 0.9
					_add_ring(at, PERFECT)
				"wear":
					pop.size = 32
					pop.color = Color(0.82, 0.58, 1.0)
					pop.label = "展現力量！"
					pop.life = 1.4
					pop.pop = 0.6
		"miss":
			pop.text = "MISS"
			pop.size = 20
			pop.color = Color(0.7, 0.7, 0.72)
			pop.vel = Vector2(0, -30)
		"hurt":
			pop.text = "-" + _fmt(hit.n)
			pop.label = hit.src
			pop.pos = _hurt_at() + Vector2(randf_range(0.0, 14.0), randf_range(-6.0, 6.0) + _hurt_stack())
			pop.vel = Vector2(24.0, -34.0)
			pop.size = 20 + mini(int(hit.n) / 3, 16)
			pop.color = RAGE
			pop.life = 1.2
			pop.pop = 0.5
			_hurt_flash = 0.25
		"parry":
			pop.text = "卸力！"
			pop.pos = _hurt_at() + Vector2(0, -4 + _hurt_stack())
			pop.vel = Vector2(24.0, -30.0)
			pop.size = 22
			pop.color = SWEET
			pop.life = 1.2
		"warn":
			pop.text = "%s！" % hit.src
			pop.pos = _float_pos() + Vector2(0, -38)
			pop.vel = Vector2(0, -20)
			pop.size = 24
			pop.color = RAGE
			pop.life = 0.8
			pop.pop = 0.5
	_feel(hit)
	_pops.append(pop)
	if _pops.size() > 30:
		_pops.pop_front()


## Hurts shown close together go one under another, not on top.
func _hurt_stack() -> float:
	var n := 0
	for q in _pops:
		if q.kind == "text" and q.pos.x > CENTER_X + SIZE.x * 0.5 and q.age < 0.5:
			n += 1
	return 26.0 * n


## What a hit feels like: an edge flash and, on a touchscreen, a buzz - a crit landed
## (gold) or a hard one taken (red).
func _feel(hit: Dictionary) -> void:
	var buzz := 0
	if hit.type == "dmg" and hit.style in ["swipe", "perfect", "strike", "wear"]:
		_edge = 0.45 if hit.style != "swipe" else 0.3
		_edge_color = PERFECT
		buzz = 70 if hit.style == "swipe" else 110
	elif hit.type == "hurt" and int(hit.n) >= 20:
		_edge = clampf(float(hit.n) / 60.0, 0.25, 0.6)
		_edge_color = RAGE
		buzz = clampi(int(hit.n) * 2, 40, 130)
	if buzz > 0 and DisplayServer.is_touchscreen_available():
		Input.vibrate_handheld(buzz)


func _draw_edge() -> void:
	if _edge <= 0.0:
		return
	var vp := get_viewport().get_visible_rect().size
	var w := 26.0
	var c := Color(_edge_color, _edge)
	var clear := Color(_edge_color, 0.0)
	# (four bands fading inward)
	for i in 6:
		var a := _edge * (1.0 - i / 6.0) * 0.8
		var col := Color(_edge_color, a)
		var t := w / 6.0
		_view.draw_rect(Rect2(0, i * t, vp.x, t), col)
		_view.draw_rect(Rect2(0, vp.y - (i + 1) * t, vp.x, t), col)
		_view.draw_rect(Rect2(i * t, 0, t, vp.y), col)
		_view.draw_rect(Rect2(vp.x - (i + 1) * t, 0, t, vp.y), col)


func _add_ring(at: Vector2, color: Color) -> void:
	_pops.append({"text": "", "label": "", "pos": at, "vel": Vector2.ZERO, "age": 0.0, "life": 0.45, "size": 0,
		"color": color, "kind": "ring", "pop": 0.0})


## 12345 -> "12,345".
static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _draw_pops() -> void:
	_draw_edge()
	for pop in _pops:
		var t: float = pop.age / pop.life
		var fade := clampf((1.0 - t) / 0.4, 0.0, 1.0)
		if pop.kind == "ring":
			_view.draw_arc(pop.pos, lerpf(10.0, 64.0, t), 0.0, TAU, 40, Color(pop.color, (1.0 - t) * 0.8), 3.0)
			continue
		# (a hit lands big and settles)
		var grow := 1.0 + float(pop.pop) * maxf(1.0 - pop.age / 0.18, 0.0)
		var size := int(float(pop.size) * grow)
		var col: Color = pop.color
		col.a = fade
		UiKit.draw_text(_view, pop.pos + Vector2(-130, 0), pop.text, size, col, HORIZONTAL_ALIGNMENT_CENTER, 260, true)
		if pop.label != "":
			UiKit.draw_text(_view, pop.pos + Vector2(-130, -float(size) * 0.9), pop.label, maxi(int(size * 0.45), 13), Color(col, fade),
				HORIZONTAL_ALIGNMENT_CENTER, 260, true)


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
	return RunView3D.screen_point(get_viewport(), bobber.global_position)


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
	if player.state == Player.State.BITE and player.fishing_mode == Player.FishingMode.LURE:
		_draw_lure_strike(player)
	elif player.state == Player.State.BITE:
		_draw_strike_ring(player)
	elif player.light_lure > 0.0:
		_draw_lure_glow(player.light_lure)
	var fight := _fight()
	if fight == null:
		_draw_pops()
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
	var hp_at := Vector2(x, rect.position.y + 50)
	_row(hp_at, bar_x, "體力", fight.stamina(), STAMINA)
	# (its health as a number, the berserk's half marked)
	UiKit.draw_text(_view, Vector2(bar_x, hp_at.y - 2.0), "%s / %s" % [_fmt(roundi(fight.hp())), _fmt(roundi(fight.max_hp))], 11,
		INK, HORIZONTAL_ALIGNMENT_CENTER, BAR_W, true)
	if fight.diff.phases > 1:
		var half := bar_x + 3.0 + (BAR_W - 6.0) * (1.0 - FishFight.ENRAGE_AT)
		_view.draw_line(Vector2(half, hp_at.y - BAR_H), Vector2(half, hp_at.y + 2.0), Color(RAGE, 0.9), 1.5)
	var sweet := fight.in_sweet()
	var tension_color := RAGE if fight.tension > TENSION_HIGH else (SWEET if sweet else TENSION)
	var at := Vector2(x, rect.position.y + 74)
	_row(at, bar_x, "張力", fight.tension, tension_color, SWEET if sweet else DIM)
	var zone := fight.sweet_range()
	var band := Rect2(bar_x + 3.0 + (BAR_W - 6.0) * zone.x, at.y - BAR_H + 1.0, (BAR_W - 6.0) * (zone.y - zone.x), BAR_H)
	_view.draw_rect(band, Color(SWEET, 0.9 if sweet else 0.55), false, 1.5)
	if _hurt_flash > 0.0:
		_view.draw_rect(Rect2(bar_x, at.y - BAR_H + 1.0, BAR_W, BAR_H), Color(RAGE, _hurt_flash * 2.0))
	_draw_distance(fight, Vector2(x, rect.position.y + 98), bar_x)
	_draw_crank_hint(fight, player)

	if fight.swipe_left > 0.0:
		_draw_swipe_cue(fight)
	elif fight.perfect and fight.age < CALLOUT_TIME:
		var a := clampf((CALLOUT_TIME - fight.age) / 0.4, 0.0, 1.0)
		UiKit.draw_text(_view, Vector2(CENTER_X - 100, CUE_Y + 6), "完美揚竿！", 24, Color(PERFECT, a), HORIZONTAL_ALIGNMENT_CENTER, 200, true)
	_draw_pops()


## The line out (user request: 線長 - as long as the cast at the strike,
## longer as the fish goes out or deep; FishFight.line_out()) on a bar of
## all the line, its danger end marked - in red, pulsing, once it's out
## there - and how deep the fish is.
func _draw_distance(fight: FishFight, at: Vector2, bar_x: float) -> void:
	var share := fight.line_share()
	var danger := fight.danger() > 0.0
	var red := Color(RAGE, 0.7 + 0.3 * sin(_pulse * 12.0)) if danger else LINE
	UiKit.draw_text(_view, at, "線長", 13, RAGE if danger else DIM)
	var bar := Rect2(bar_x, at.y - BAR_H + 1.0, BAR_W, BAR_H)
	UiKit.draw_bar(_view, bar, share, red)
	var mark := bar.position.x + 3.0 + (BAR_W - 6.0) * FishFight.DANGER
	_view.draw_rect(Rect2(mark, bar.position.y, bar.end.x - 3.0 - mark, BAR_H), Color(RAGE, 0.18), true)
	_view.draw_line(Vector2(mark, bar.position.y - 1.0), Vector2(mark, bar.end.y + 1.0), Color(RAGE, 0.85), 1.5)
	UiKit.draw_text(_view, Vector2(bar.position.x, at.y), "%.1f / %.0f 公尺・深 %.1f" % [fight.line_out(), fight.line_max, fight.depth], 11,
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
	_draw_way_cue(-fight.run_side.normalized(), fight.swipe_left / FishFight.SWIPE_WINDOW, "往%s甩！")


## User request: a lure's bite - which way to strike (Player.strike_dir),
## as the fight's runs show which way to flick: the cue in the middle, an
## arrow out from the right stick, the float marked.
func _draw_lure_strike(player: Player) -> void:
	var total: float = float(player.tier_data.get("bite_window", 1.0)) * Player.LURE_STRIKE_TIME
	var dir := player.strike_dir.normalized()
	_draw_way_cue(dir, clampf(player.bite_timer / maxf(total, 0.01), 0.0, 1.0), "往%s揚竿！")
	_view.draw_arc(_float_pos(), RING_TO, 0.0, TAU, 32, Color(PERFECT, 0.9), 2.0)
	if DisplayServer.is_touchscreen_available():
		var c := TouchControls.AIM_CENTER
		var a := 0.6 + 0.3 * sin(_pulse * 10.0)
		var tip := c + dir * CRANK_HINT_RADIUS
		var side := dir.orthogonal() * 12.0
		_view.draw_line(c, tip - dir * 10.0, Color(PERFECT, a), 6.0)
		_view.draw_colored_polygon(PackedVector2Array([tip + dir * 6.0, tip - dir * 14.0 + side, tip - dir * 14.0 - side]), Color(PERFECT, a))


## A way to flick (dir), the time left (0..1), the words (with the way's
## name for %s).
func _draw_way_cue(dir: Vector2, left: float, words: String) -> void:
	var c := Vector2(CENTER_X, CUE_Y)
	_view.draw_circle(c, CUE_RADIUS, FILL)
	_view.draw_arc(c, CUE_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * left, 32, TENSION, 3.0)
	var tip := c + dir * 15.0
	var tail := c - dir * 13.0
	var side := dir.orthogonal() * 8.0
	_view.draw_line(tail, tip - dir * 6.0, INK, 4.0)
	_view.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 11.0 + side, tip - dir * 11.0 - side]), INK)
	_view.draw_string(_font, c + Vector2(-50, CUE_RADIUS + 16), words % FishFight.describe(dir), HORIZONTAL_ALIGNMENT_CENTER, 100, 13, INK)


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
