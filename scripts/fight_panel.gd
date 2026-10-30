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
## User request (the move area): under the panel, when the fish makes a move - a dash,
## a sideways dash, a leap, a dash for the rocks, berserk, a rally, into the weed - its
## animation plays (a clip, assets/fight_moves/<key>.ogv, else drawn here), and nothing
## shows when it makes none. It's also the left hand's: when a way is asked - flick
## against a sideways dash, pull against it, the strike of a lure's bite - drag in it
## that way (`pad_vec`), as the right stick (kept for turning the reel) used to be
## turned. A keyboard and a mouse work as before, and the mouse can drag here too.
##
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
const CUE_Y := 372.0
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

## The drag in the move area: its way and strength (0..1), and whether the area is up
## (Player takes the way from here, not the right stick, while it is).
static var pad_vec := Vector2.ZERO
static var pad_active := false

const MOVE_SIZE := Vector2(288, 162)
const MOVE_DIR := "res://assets/fight_moves/%s.ogv"
## Move -> its name in the area.
const MOVE_NAMES := {"dash": "衝刺", "side_dash": "橫衝", "leap": "躍出水面", "rock_dive": "鑽石縫", "rage": "狂暴",
	"rally": "反撲", "weed": "鑽水草", "bite": "咬鉤"}
const DRAG_FULL := 46.0

var _area: Control
var _cue: Control
var _videos := {}
var _move := ""
var _move_t := 0.0
var _drag_id := -2
var _drag_from := Vector2.ZERO
var _drag_at := Vector2.ZERO
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
	_build_area()
	_view = Node2D.new()
	_view.draw.connect(_draw_panel)
	add_child(_view)


func _process(delta: float) -> void:
	_pulse += delta
	var player := _player()
	var busy := player != null and (player.state == Player.State.REELING \
		or player.state == Player.State.BITE or player.light_lure > 0.0)
	_take_hits(player, delta)
	_update_area(player, delta)
	if busy or _drawn or not _pops.is_empty() or _edge > 0.0:
		_view.queue_redraw()
	_drawn = busy


func _exit_tree() -> void:
	pad_vec = Vector2.ZERO
	pad_active = false


## Which move the fish is making ("" none), for the area.
func move_key(fight: FishFight) -> String:
	match fight.mood():
		"run":
			return "rage" if fight.enraged else "dash"
		"side_run":
			return "side_dash"
		"jump":
			return "leap"
		"dive":
			return "rock_dive"
		"snag":
			return "weed"
		"rally":
			return "rally"
	return ""


func _build_area() -> void:
	_area = Control.new()
	_area.name = "MoveArea"
	_area.position = Vector2(CENTER_X - MOVE_SIZE.x * 0.5, TOP + SIZE.y + 10.0)
	_area.size = MOVE_SIZE
	_area.visible = false
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.draw.connect(_draw_area)
	_area.gui_input.connect(_area_input)
	add_child(_area)
	for key in MOVE_NAMES:
		var path: String = MOVE_DIR % key
		if not ResourceLoader.exists(path):
			continue
		var v := VideoStreamPlayer.new()
		v.name = "Clip_" + key
		v.stream = load(path)
		v.expand = true
		v.size = MOVE_SIZE
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.visible = false
		# (looped while the move goes on)
		v.finished.connect(func(): if v.visible: v.play())
		_area.add_child(v)
		_videos[key] = v
	_cue = Control.new()
	_cue.name = "Cue"
	_cue.size = MOVE_SIZE
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue.draw.connect(_draw_cue)
	_area.add_child(_cue)


## What the area shows now: a move of the fish's, or a lure's bite (the way to strike).
func _update_area(player: Player, delta: float) -> void:
	var key := ""
	var fight := _fight()
	if fight != null:
		key = move_key(fight)
	elif player != null and player.state == Player.State.BITE and player.fishing_mode == Player.FishingMode.LURE:
		key = "bite"
	if key != _move:
		_move = key
		_move_t = 0.0
		for k in _videos:
			var v: VideoStreamPlayer = _videos[k]
			v.visible = k == key
			if k == key:
				v.play()
			else:
				v.stop()
	_move_t += delta
	var show := _move != ""
	_area.visible = show
	pad_active = show
	if not show:
		pad_vec = Vector2.ZERO
		_drag_id = -2
		return
	# (a sideways dash to the left plays mirrored: the clips run left to right)
	if _move == "side_dash" and fight != null and _videos.has(_move):
		var v: VideoStreamPlayer = _videos[_move]
		var flip := fight.run_side.x < 0.0
		v.pivot_offset = MOVE_SIZE * 0.5
		v.scale = Vector2(-1.0 if flip else 1.0, 1.0)
	_area.queue_redraw()
	_cue.queue_redraw()


## A drag in the area is the way (see pad_vec): a mouse button or a finger.
func _area_input(event: InputEvent) -> void:
	var id := -2
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var move := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		id = -1
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion:
		id = -1
		pos = event.position
		move = true
	elif event is InputEventScreenTouch:
		id = event.index
		pos = event.position - _area.global_position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag:
		id = event.index
		pos = event.position - _area.global_position
		move = true
	else:
		return
	if down and _drag_id == -2:
		_drag_id = id
		_drag_from = pos
		_drag_at = pos
		pad_vec = Vector2.ZERO
	elif id != _drag_id:
		return
	elif move and _drag_id != -2:
		_drag_at = pos
		pad_vec = ((pos - _drag_from) / DRAG_FULL).limit_length(1.0)
	elif up:
		_drag_id = -2
		pad_vec = Vector2.ZERO
	_area.accept_event()
	_cue.queue_redraw()


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
			# (the tension taken climbs - a +; the line's own life, frayed, falls - a -)
			pop.text = ("-" if hit.src == "割線" else "+") + _fmt(hit.n)
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
		"snag":
			return ["鑽進水草！往回拉", RAGE]
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
		_view.draw_rect(Rect2(bar_x, at.y - BAR_H + 1.0, BAR_W, BAR_H), Color(RAGE, _hurt_flash * 0.45))
	_draw_distance(fight, Vector2(x, rect.position.y + 98), bar_x)
	_draw_crank_hint(fight, player)

	if fight.perfect and fight.age < CALLOUT_TIME:
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


## The move's picture when it has no clip: the water cut away, drawn.
func _draw_area() -> void:
	var r := Rect2(Vector2.ZERO, MOVE_SIZE)
	_area.draw_rect(r, Color(0.03, 0.06, 0.09, 0.9))
	var surface := 38.0
	var floor_y := 132.0
	_area.draw_rect(Rect2(0, surface, r.size.x, floor_y - surface), Color(0.07, 0.15, 0.22, 0.9))
	_area.draw_rect(Rect2(0, floor_y, r.size.x, r.size.y - floor_y), Color(0.16, 0.12, 0.08, 0.95))
	var wave: Array = []
	for i in 29:
		wave.append(Vector2(i * 10.0, surface + sin(_move_t * 3.0 + i * 0.7) * 1.6))
	_area.draw_polyline(PackedVector2Array(wave), Color(0.6, 0.8, 0.95, 0.6), 1.5)
	if not _videos.has(_move):
		_draw_move_art(_move, _move_t, surface, floor_y)
	_area.draw_rect(r, Color(RIM, 0.45), false, 1.5)


func _fish_shape(at: Vector2, k: float, col: Color, face := 1.0) -> void:
	var f := face
	_area.draw_colored_polygon(PackedVector2Array([at + Vector2(14, 0) * k * f, at + Vector2(4, -6) * k * f, at + Vector2(-8, -5) * k * f,
		at + Vector2(-16, -10) * k * f, at + Vector2(-14, 0) * k * f, at + Vector2(-16, 10) * k * f, at + Vector2(-8, 5) * k * f, at + Vector2(4, 6) * k * f]), col)
	_area.draw_circle(at + Vector2(8, -1.5) * k * f, 1.4 * k, Color(0, 0, 0, 0.8))


## A stand-in for each move's clip (the real ones: assets/fight_moves/<key>.ogv).
func _draw_move_art(key: String, t: float, surface: float, floor_y: float) -> void:
	var w := MOVE_SIZE.x
	var ph := fposmod(t * 0.9, 1.0)
	var fish_col := Color(0.85, 0.88, 0.9)
	match key:
		"dash", "side_dash":
			var y := 92.0 if key == "dash" else 108.0
			var x := lerpf(-20.0, w + 20.0, ph)
			for i in 5:
				_area.draw_line(Vector2(x - 24.0 - i * 14.0, y - 8 + i * 4), Vector2(x - 40.0 - i * 14.0, y - 8 + i * 4), Color(0.7, 0.85, 1.0, 0.5 - i * 0.08), 2.0)
			_fish_shape(Vector2(x, y), 1.5, fish_col)
		"leap":
			var x2 := lerpf(60.0, w - 60.0, ph)
			var y2 := surface + 8.0 - sin(PI * ph) * 70.0
			_fish_shape(Vector2(x2, y2), 1.5, fish_col)
			for ring in 2:
				var rr := fposmod(t * 1.2 + ring * 0.5, 1.0)
				_area.draw_arc(Vector2(60.0 if ph < 0.5 else w - 60.0, surface), 6.0 + rr * 26.0, PI, TAU, 20, Color(0.8, 0.92, 1.0, 1.0 - rr), 1.5)
		"rock_dive":
			for i in 5:
				var rx := 120.0 + i * 36.0
				_area.draw_colored_polygon(PackedVector2Array([Vector2(rx - 16, floor_y), Vector2(rx, floor_y - 22 - (i % 2) * 8), Vector2(rx + 16, floor_y)]), Color(0.32, 0.3, 0.3))
			var fx := lerpf(40.0, 150.0, ph)
			_fish_shape(Vector2(fx, lerpf(60.0, 118.0, ph)), 1.4, fish_col)
		"rage":
			var shake := Vector2(sin(t * 40.0), cos(t * 33.0)) * 2.5
			var c := Vector2(w * 0.5, 88.0) + shake
			for i in 12:
				var a := TAU * i / 12.0 + t * 2.0
				var len := 34.0 + sin(t * 14.0 + i) * 8.0
				_area.draw_line(c + Vector2.from_angle(a) * 30.0, c + Vector2.from_angle(a) * len, Color(RAGE, 0.8), 2.5)
			_fish_shape(c, 1.9 + sin(t * 12.0) * 0.1, Color(1.0, 0.45, 0.4))
		"rally":
			var c2 := Vector2(w * 0.5, 90.0)
			for i in 3:
				var rr2 := fposmod(t * 0.8 + i / 3.0, 1.0)
				_area.draw_arc(c2, 14.0 + rr2 * 60.0, 0.0, TAU, 32, Color(PERFECT, (1.0 - rr2) * 0.8), 2.0)
			for i in 8:
				var sx := c2.x - 50.0 + i * 14.0
				var sy := c2.y + 30.0 - fposmod(t * 40.0 + i * 17.0, 70.0)
				_area.draw_circle(Vector2(sx, sy), 1.8, Color(PERFECT, 0.8))
			_fish_shape(c2, 1.7 + sin(t * 8.0) * 0.08, Color(1.0, 0.92, 0.6))
		"weed":
			for i in 9:
				var wx := 90.0 + i * 14.0
				var pts: Array = []
				for k in 7:
					pts.append(Vector2(wx + sin(t * 2.0 + k * 0.6 + i) * (3.0 + k * 1.6), floor_y - k * 11.0))
				_area.draw_polyline(PackedVector2Array(pts), Color(0.3, 0.65, 0.3, 0.9), 2.5)
			_fish_shape(Vector2(w * 0.5 + sin(t * 3.0) * 14.0, 100.0), 1.4, Color(1.0, 0.6, 0.5))
		"bite":
			for ring in 3:
				var rr3 := fposmod(t * 0.9 + ring / 3.0, 1.0)
				_area.draw_arc(Vector2(w * 0.5, surface), 6.0 + rr3 * 40.0, PI, TAU, 24, Color(0.8, 0.92, 1.0, 1.0 - rr3), 1.5)


## The way asked of the left hand - drawn over the move: an arrow and, while there's a
## time to do it in, a ring running out; the finger's drag.
func _draw_cue() -> void:
	var fight := _fight()
	var dir := Vector2.ZERO
	var left := -1.0
	var words := ""
	if fight != null and fight.run_side != Vector2.ZERO and fight.mood() == "side_run":
		dir = -fight.run_side.normalized()
		if fight.swipe_left > 0.0:
			left = fight.swipe_left / maxf(fight.swipe_window(), 0.01)
			words = "往%s甩！" % FishFight.describe(dir)
		else:
			words = "往%s拉住" % FishFight.describe(dir)
	elif fight == null:
		var player := _player()
		if player != null and player.state == Player.State.BITE and player.fishing_mode == Player.FishingMode.LURE:
			dir = player.strike_dir.normalized()
			var total: float = float(player.tier_data.get("bite_window", 1.0)) * Player.LURE_STRIKE_TIME
			left = clampf(player.bite_timer / maxf(total, 0.01), 0.0, 1.0)
			words = "往%s揚竿！" % FishFight.describe(dir)
	if dir != Vector2.ZERO:
		var c := MOVE_SIZE * 0.5
		_cue.draw_circle(c, 30.0, Color(FILL, 0.55))
		if left >= 0.0:
			_cue.draw_arc(c, 30.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, TENSION, 3.5)
		var tip := c + dir * 24.0
		var tail := c - dir * 20.0
		var side := dir.orthogonal() * 10.0
		_cue.draw_line(tail, tip - dir * 8.0, INK, 5.0)
		_cue.draw_colored_polygon(PackedVector2Array([tip + dir * 4.0, tip - dir * 14.0 + side, tip - dir * 14.0 - side]), INK)
		UiKit.draw_text(_cue, Vector2(0, MOVE_SIZE.y - 10.0), words, 16, TENSION, HORIZONTAL_ALIGNMENT_CENTER, MOVE_SIZE.x, true)
	else:
		UiKit.draw_text(_cue, Vector2(8, 18), MOVE_NAMES.get(_move, ""), 14, Color(INK, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	# The finger: where it went from and to.
	if _drag_id != -2 and pad_vec != Vector2.ZERO:
		_cue.draw_line(_drag_from, _drag_at, Color(SWEET, 0.7), 3.0)
		_cue.draw_circle(_drag_from, 6.0, Color(SWEET, 0.4))
		_cue.draw_circle(_drag_at, 9.0, Color(SWEET, 0.8))


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


## User request: a lure's bite - which way to strike (Player.strike_dir),
## as the fight's runs show which way to flick: the cue in the middle, an
## arrow out from the right stick, the float marked.
func _draw_lure_strike(player: Player) -> void:
	# (the way to strike is shown in the move area; here the float marked)
	_view.draw_arc(_float_pos(), RING_TO, 0.0, TAU, 32, Color(PERFECT, 0.9), 2.0)


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
