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
## User request (the move area): under the panel, when the fish makes a move that pulls
## (a dash, a sideways dash, a dash for the rocks or into the weed, berserk, a rally) a
## small live 3D picture of what the angler sees - a camera behind the shoulder looking
## out along the line, level over the water (RunView3D.fight_cam_pose, a SubViewport on
## the game's own world), the rod bowed, the fish pulling - and a leap, the fish's own
## silhouette jumping; nothing when it makes none. Over it one clear arrow: drag that
## way (the other way from the pull; FishFight.answering). Also the lure's strike: drag the
## way shown. The drag is on the line's frame (up: along the line; `pad_vec`;
## `pad_world()` is the same in the world, for Player). A keyboard and a mouse work as
## before, and the mouse can drag here too.
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

## The drag in the move area (on the clock face: up is 12, straight out over the water),
## its strength (0..1), whether the area is up (Player takes the way from here, not the
## right stick, while it is), and the line's way in the world the face is turned to.
static var pad_vec := Vector2.ZERO
static var pad_active := false
static var pad_frame := Vector2.UP

const MOVE_SIZE := Vector2(240, 132)
## How far a slide goes (px in the area) to be the whole way: the arrow's length.
const DRAG_FULL := 80.0
const ARROW_LEN := 78.0
const ROD_LEN := 78.0

## The drag's push, and the left stick's (Player.rod_vec); pad_vec is the larger.
var _drag_vec := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _area: Control
var _tex: TextureRect
var _over: Control
var _sv: SubViewport
var _cam: Camera3D
## Frames still to draw to warm the 3D picture up (shaders, buffers) as the fight starts,
## so the first move doesn't stall the game; a stab just made (s left).
var _warm_frames := 0
var _warmed := false
## The run's world is built and the picture's been drawn once already, unseen (see _prewarm).
var _prewarmed := false
var _sv_tick := 0
## How long the picture stays up after the way asked is done (s), and what's left.
const LINGER := 2.0
var _linger := 0.0
var _stab_t := 0.0
var _move := ""
var _move_t := 0.0
var _drag_id := -2
var _drag_from := Vector2.ZERO
var _drag_at := Vector2.ZERO
## A world way on the clock face, and back.
static func to_frame(world: Vector2) -> Vector2:
	return world.rotated(-Vector2.UP.angle_to(pad_frame))


static func pad_world() -> Vector2:
	return pad_vec.rotated(Vector2.UP.angle_to(pad_frame))


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
	_drag_vec = Vector2.ZERO
	_stick_vec = Vector2.ZERO
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
	_area.clip_contents = true
	_area.visible = false
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.draw.connect(func(): _area.draw_rect(Rect2(Vector2.ZERO, MOVE_SIZE), Color(0.03, 0.06, 0.09, 0.9)))
	_area.gui_input.connect(_area_input)
	add_child(_area)
	_tex = TextureRect.new()
	_tex.name = "View"
	_tex.size = MOVE_SIZE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_tex)
	_over = Control.new()
	_over.name = "Over"
	_over.size = MOVE_SIZE
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	_area.add_child(_over)


## The 3D picture: a SubViewport on the game's own world (not in a headless run), made
## cheap - small, no shadow atlas, no AA, a plain environment (no glow, no occlusion), a
## short far plane.
func _ensure_view() -> void:
	if _sv != null or DisplayServer.get_name() == "headless":
		return
	_sv = SubViewport.new()
	_sv.size = Vector2i(MOVE_SIZE * 1.25)
	_sv.world_3d = get_viewport().world_3d
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sv.positional_shadow_atlas_size = 256
	_sv.msaa_3d = Viewport.MSAA_DISABLED
	_sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_sv.use_taa = false
	_sv.gui_disable_input = true
	_sv.audio_listener_enable_3d = false
	add_child(_sv)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.near = 0.05
	_cam.far = 30.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.56, 0.68)
	env.ambient_light_energy = 1.7
	_cam.environment = env
	_sv.add_child(_cam)
	_tex.texture = _sv.get_texture()


## The first time the run's world stands: the picture's made and drawn a few times, with the
## under-water fish and the line in it (RunView3D.warm_fight), so no shader or buffer is built
## in the middle of a fight - that was the hitch.
func _prewarm() -> void:
	if _prewarmed or DisplayServer.get_name() == "headless":
		return
	var rv := RunView3D.active
	if rv == null or not is_instance_valid(rv) or not rv.built:
		return
	_prewarmed = true
	_ensure_view()
	_warm_frames = 8
	rv.warm_fight(8)


## What the area shows now: a move of the fish's, or a lure's bite (the way to strike).
func _update_area(player: Player, delta: float) -> void:
	var key := ""
	var fight := _fight()
	_prewarm()
	if fight != null:
		key = move_key(fight)
		# (the picture is up while a way's asked - and a leap, the hauling after a dive - not through
		# the rest of a move: it's drawn only when it's needed)
		if key != "" and key != "leap" and not fight.prompt_active() and fight.haul_left <= 0.0:
			key = ""
		pad_frame = fight.line_way()
		if not _warmed:
			# (the fight's just begun: build the picture and draw it a few times now)
			_warmed = true
			_ensure_view()
			_warm_frames = 4
	else:
		_warmed = false
		if player != null and player.state == Player.State.BITE and player.fishing_mode == Player.FishingMode.LURE:
			key = "bite"
			var line := (player.cast_target - player.global_position).normalized()
			pad_frame = line if line != Vector2.ZERO else Vector2.UP
			if _sv == null:
				_ensure_view()
				_warm_frames = 3
	# (a moment more once it's over, to see the stab)
	if key != "":
		_linger = LINGER
	elif _linger > 0.0 and _move != "":
		_linger -= delta
		key = _move
	if key != _move:
		_move = key
		_move_t = 0.0
	_move_t += delta
	_stab_t = maxf(_stab_t - delta, 0.0)
	var show := _move != ""
	_area.visible = show
	pad_active = show
	var drawing := show or _warm_frames > 0
	if _sv != null:
		# (the 3D picture's a second render of the world: every other frame is plenty)
		_sv_tick += 1
		var now := drawing and (_warm_frames > 0 or _sv_tick % 2 == 0)
		_sv.render_target_update_mode = SubViewport.UPDATE_ONCE if now else SubViewport.UPDATE_DISABLED
		if _warm_frames > 0:
			_warm_frames -= 1
	if not show:
		pad_vec = Vector2.ZERO
		_drag_vec = Vector2.ZERO
		_drag_id = -2
	var stick: Vector2 = player.rod_vec if (show and player != null) else Vector2.ZERO
	if stick != _stick_vec or stick != Vector2.ZERO:
		_stick_vec = stick
		_merge_pad()
	var rv := RunView3D.active
	if _cam != null and drawing and rv != null and is_instance_valid(rv) and rv.built:
		# (the picture trembles with the pull that's not answered)
		var shake := 0.0
		if fight != null and fight.pull_dir != Vector2.ZERO and not fight.answering:
			shake = (0.4 + fight.tension) * fight.ramp
		_cam.global_transform = rv.fight_cam_pose(shake)
	if show:
		_over.queue_redraw()


func _merge_pad() -> void:
	pad_vec = _drag_vec if _drag_vec.length() >= _stick_vec.length() else _stick_vec


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
		_drag_vec = Vector2.ZERO
	elif id != _drag_id:
		return
	elif move and _drag_id != -2:
		_drag_at = pos
		_drag_vec = ((pos - _drag_from) / DRAG_FULL).limit_length(1.0)
	elif up:
		_drag_id = -2
		_drag_vec = Vector2.ZERO
	_merge_pad()
	_area.accept_event()
	_over.queue_redraw()


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
	if hit.type == "dmg" and hit.style in ["swipe", "perfect"]:
		_stab_t = 0.6
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
			return ["鑽進水草！反向拉住", RAGE]
		"jump":
			return ["跳出水面！放手", RAGE]
		"dive":
			return ["鑽往水下！反向拉住", RAGE]
		"side_run":
			return ["往%s衝" % FishFight.describe(fight.run_side), TENSION]
		"run":
			return ["狂暴亂竄！反向拉住" if fight.enraged else "往外衝！反向拉住", RAGE if fight.enraged else TENSION]
		"enraged":
			return ["狂暴", RAGE]
		"spent":
			return ["沒力了！收線上岸", STAMINA]
		"slack":
			return ["線鬆了！按住", RAGE]
		"rally":
			return ["反撲！反向拉住", RAGE]
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


## Over the picture: one clear arrow - drag that way - and the words; a leap, the fish's
## own silhouette; the finger.
func _draw_over() -> void:
	var fight := _fight()
	var answer := Vector2.ZERO
	var words := ""
	var left := -1.0
	match _move:
		"leap":
			if _sv == null:
				# (no 3D picture to show it jumping: its silhouette, drawn)
				_draw_leap()
			words = "放手！"
		"bite":
			var player := _player()
			if player != null:
				answer = to_frame(player.strike_dir.normalized())
				var total: float = float(player.tier_data.get("bite_window", 1.0)) * Player.LURE_STRIKE_TIME
				left = clampf(player.bite_timer / maxf(total, 0.01), 0.0, 1.0)
				words = "往%s揚竿！" % FishFight.describe(answer)
		_:
			if fight != null and fight.prompt_active():
				answer = to_frame(fight.prompt_dir())
				left = fight.prompt_left()
				words = "往%s甩！" % FishFight.describe(answer) if _move == "side_dash" else "往%s拉竿！" % FishFight.describe(answer)
			elif fight != null and fight.haul_left > 0.0:
				words = "拉回來了！狠狠捲線"
	var r := Rect2(Vector2.ZERO, MOVE_SIZE)
	# (a darker foot for the words)
	_over.draw_rect(Rect2(0, MOVE_SIZE.y - 28.0, MOVE_SIZE.x, 28.0), Color(0, 0, 0, 0.5))
	if answer != Vector2.ZERO:
		# (left of the middle: the float and the fish are looked at a little right of it)
		var c := Vector2(MOVE_SIZE.x * 0.3, MOVE_SIZE.y * 0.44)
		if left >= 0.0:
			_over.draw_arc(c, ARROW_LEN * 0.56, -PI * 0.5, -PI * 0.5 + TAU * left, 36, TENSION, 3.5)
		# The arrow: faint where it's still to be slid, solid as far as it has been.
		var fill := 0.0
		if pad_vec.length() > 0.02 and pad_vec.normalized().dot(answer) > FishFight.ANSWER_DOT:
			fill = clampf(pad_vec.length(), 0.0, 1.0)
		if _stab_t > 0.0:
			fill = 1.0
		_draw_arrow(c, answer, 0.28, 1.0, Color(SWEET, 1.0))
		if fill > 0.0:
			_draw_arrow(c, answer, 0.95, fill, Color(SWEET, 1.0))
	if _stab_t > 0.0:
		UiKit.draw_text(_over, Vector2(0, 30.0), "刺！", 26, Color(1.0, 0.93, 0.55, clampf(_stab_t / 0.3, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, MOVE_SIZE.x, true)
	if words != "":
		UiKit.draw_text(_over, Vector2(0, MOVE_SIZE.y - 8.0), words, 16, TENSION, HORIZONTAL_ALIGNMENT_CENTER, MOVE_SIZE.x, true)
	_over.draw_rect(r, Color(RIM, 0.5), false, 1.5)


## An arrow of ARROW_LEN centred on `c` along `dir`, drawn up to `share` of its length from
## the tail, at `alpha`.
func _draw_arrow(c: Vector2, dir: Vector2, alpha: float, share: float, col: Color) -> void:
	var tail := c - dir * ARROW_LEN * 0.5
	var side := dir.orthogonal()
	var shaft := ARROW_LEN * 0.62
	var head := ARROW_LEN - shaft
	var upto := ARROW_LEN * share
	var colr := Color(col, alpha)
	var s_end := minf(upto, shaft)
	if s_end > 0.0:
		var a := tail + side * 6.0
		var b := tail - side * 6.0
		_over.draw_colored_polygon(PackedVector2Array([a, a + dir * s_end, b + dir * s_end, b]), colr)
	if upto > shaft:
		var t := (upto - shaft) / head
		var half := lerpf(16.0, 0.0, t)
		var base := tail + dir * shaft
		_over.draw_colored_polygon(PackedVector2Array([base + side * 16.0, base + dir * (upto - shaft) + side * half, base + dir * (upto - shaft) - side * half, base - side * 16.0]), colr)


## A leap: the fish's own silhouette up out of the water, in a splash.
func _draw_leap() -> void:
	var ph := fposmod(_move_t * 0.9, 1.0)
	var at := Vector2(lerpf(50.0, MOVE_SIZE.x * 0.62, ph), 84.0 - sin(PI * ph) * 56.0)
	var player := _player()
	var tex: Texture2D = null
	if player != null and player.fish_id != "":
		tex = FishData.icon(player.fish_id, "")
	if tex != null:
		var k := 54.0 / maxf(tex.get_width(), 1.0)
		var sz := Vector2(tex.get_size()) * k
		_over.draw_set_transform(at, -0.5 + ph * 1.2, Vector2.ONE)
		_over.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(0.82, 0.9, 0.97, 0.95))
		_over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_over.draw_circle(at, 9.0, Color(0.82, 0.9, 0.97))
	for ring in 2:
		var rr := fposmod(_move_t * 1.2 + ring * 0.5, 1.0)
		_over.draw_arc(Vector2(50.0 if ph < 0.5 else MOVE_SIZE.x * 0.62, 84.0), 6.0 + rr * 26.0, PI, TAU, 20, Color(0.8, 0.92, 1.0, 1.0 - rr), 1.5)


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
