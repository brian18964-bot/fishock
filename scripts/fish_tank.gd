extends Control

## The fish tank (from the main screen's 魚缸). User request: the fish
## brought home from a run (Profile.tank - put there when the run is
## escaped, see GameState._bring_fish_home) swim in a tank; beside it, the
## list of them, to sell or (once multiplayer comes) trade. Each swims by
## its trait (FishData.TANK_TRAITS): schooling ones keep together, fierce
## ones go for the others now and then, bottom dwellers keep low, shy ones
## by the weed, lazy ones barely move, jumpers leap, gluttons get to the
## food first. Tap a fish, in the tank or the list, for its card.

const TANK := Rect2(16, 64, 590, 460)
## The water inside the glass (tank-local).
const WATER := Rect2(10, 26, 570, 380)
const SAND_H := 44.0
const WATER_TOP := Color(0.1, 0.3, 0.38)
const WATER_BOTTOM := Color(0.03, 0.1, 0.16)

var _tank: TankView
var _list: VBoxContainer
var _count: Label
var _gold: Label
var _card: Control


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): _refresh_gold())
	_refresh_gold()
	_rebuild()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := MenuStyle.button("‹ 返回", 16)
	back.name = "Back"
	back.position = Vector2(16, 12)
	back.custom_minimum_size = Vector2(96, 40)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	add_child(back)
	var title := MenuStyle.label("魚缸", 26, MenuStyle.GOLD)
	title.position = Vector2(130, 14)
	add_child(title)
	var feed := MenuStyle.button("餵食", 15, true)
	feed.name = "Feed"
	feed.position = Vector2(700, 12)
	feed.custom_minimum_size = Vector2(88, 40)
	feed.pressed.connect(func(): _tank.feed())
	add_child(feed)
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 12)
	purse.custom_minimum_size = Vector2(140, 0)
	_gold = MenuStyle.label("", 18, MenuStyle.GOLD)
	purse.add_child(_gold)
	add_child(purse)

	_tank = TankView.new()
	_tank.name = "Tank"
	_tank.position = TANK.position
	_tank.size = TANK.size
	_tank.picked.connect(_card_for)
	add_child(_tank)

	var right := MenuStyle.panel()
	right.position = Vector2(618, 64)
	right.custom_minimum_size = Vector2(326, 460)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_count = MenuStyle.label("", 16, MenuStyle.GOLD)
	col.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(302, 408)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	col.add_child(scroll)
	right.add_child(col)
	add_child(right)


func _refresh_gold() -> void:
	_gold.text = "金幣  %d" % Profile.gold


func _rebuild() -> void:
	_count.text = "魚缸裡的魚  %d / %d" % [Profile.tank.size(), Profile.TANK_SIZE]
	for c in _list.get_children():
		c.queue_free()
	if Profile.tank.is_empty():
		var l := MenuStyle.label("還沒有魚。從遊戲裡帶著漁獲成功逃出來，魚就會放進這裡。", 14, MenuStyle.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 290
		_list.add_child(l)
	for i in Profile.tank.size():
		_list.add_child(_row(i))
	_tank.stock()


func _row(i: int) -> Control:
	var f: Dictionary = Profile.tank[i]
	var b := Button.new()
	b.name = "Fish_%d" % i
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(296, 52)
	var box := MenuStyle.box(Color(0.1, 0.095, 0.09, 0.9), MenuStyle.EDGE, 8)
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, box)
	b.pressed.connect(_card_for.bind(i))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var pic := TextureRect.new()
	pic.texture = FishData.icon(f.get("id", ""), f.get("name", ""))
	pic.custom_minimum_size = Vector2(76, 38)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := MenuStyle.label("%s　%s" % [f.get("name", "魚"), FishData.trait_name(f.get("tank_trait", ""))], 15)
	words.add_child(top)
	words.add_child(MenuStyle.label(FishData.size_text(f), 12, MenuStyle.DIM))
	row.add_child(words)
	b.add_child(row)
	return b


## A fish's card: its picture, measurements, trait, price; sell or trade.
func _card_for(i: int) -> void:
	if _card != null or i < 0 or i >= Profile.tank.size():
		return
	var f: Dictionary = Profile.tank[i]
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(shade)
	_card = shade
	var panel := MenuStyle.panel(Color(0.08, 0.075, 0.07, 0.97))
	panel.custom_minimum_size = Vector2(400, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var pic := TextureRect.new()
	pic.texture = FishData.icon(f.get("id", ""), f.get("name", ""))
	pic.custom_minimum_size = Vector2(0, 110)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(pic)
	col.add_child(MenuStyle.label(f.get("name", "魚"), 22, MenuStyle.GOLD))
	col.add_child(MenuStyle.label("長度・重量：" + FishData.size_text(f), 15))
	var t: String = f.get("tank_trait", "")
	var tl := MenuStyle.label("特性：%s－%s" % [FishData.trait_name(t), FishData.TANK_TRAITS.get(t, ["", ""])[1]], 15)
	col.add_child(tl)
	var price := maxi(1, roundi(float(f.get("value", 0.0))))
	col.add_child(MenuStyle.label("售價：%d 金幣" % price, 15, MenuStyle.DIM))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	acts.alignment = BoxContainer.ALIGNMENT_END
	var sell := MenuStyle.button("販售 +%d" % price, 15, true)
	sell.name = "Sell"
	sell.custom_minimum_size = Vector2(110, 40)
	sell.pressed.connect(func():
		Profile.sell_from_tank(i)
		_close()
		_rebuild())
	acts.add_child(sell)
	var trade := MenuStyle.button("交換（多人連線開放後）", 13)
	trade.disabled = true
	trade.custom_minimum_size = Vector2(150, 40)
	acts.add_child(trade)
	var close := MenuStyle.button("關閉", 15)
	close.custom_minimum_size = Vector2(70, 40)
	close.pressed.connect(_close)
	acts.add_child(close)
	col.add_child(acts)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = (size - panel.size) / 2.0


func _close() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


## The tank: glass, water, sand, weed and bubbles, and the fish in it.
class TankView extends Control:
	signal picked(index: int)

	var _time := 0.0
	var _weed: Array = []  # [x, height, phase, colour]
	var _food: Array = []  # Vector2 pellets, sinking
	var _splashes: Array = []  # [pos, age]
	var _fish: Array = []

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 9:
			var x := rng.randf_range(20, WATER.size.x - 20) + WATER.position.x
			_weed.append([x, rng.randf_range(60, 160), rng.randf() * TAU,
				Color(0.15, 0.4, 0.22).lerp(Color(0.3, 0.5, 0.2), rng.randf())])
		var bubbles := CPUParticles2D.new()
		bubbles.position = Vector2(WATER.position.x + WATER.size.x * 0.82, WATER.end.y - SAND_H * 0.5)
		bubbles.amount = 14
		bubbles.lifetime = 4.0
		bubbles.preprocess = 4.0
		bubbles.direction = Vector2.UP
		bubbles.spread = 8.0
		bubbles.gravity = Vector2(0, -20)
		bubbles.initial_velocity_min = 20.0
		bubbles.initial_velocity_max = 40.0
		bubbles.scale_amount_min = 1.5
		bubbles.scale_amount_max = 3.5
		bubbles.color = Color(0.8, 0.95, 1.0, 0.5)
		bubbles.z_index = 2
		add_child(bubbles)

	## The fish in Profile.tank, as swimmers.
	func stock() -> void:
		for s in _fish:
			s.queue_free()
		_fish.clear()
		for i in Profile.tank.size():
			var f: Dictionary = Profile.tank[i]
			var s := Swimmer.new()
			s.setup(f, i, self)
			add_child(s)
			_fish.append(s)

	func water() -> Rect2:
		return Rect2(WATER.position + Vector2(8, 16), WATER.size - Vector2(16, SAND_H + 20))

	func weed_x() -> Array:
		return _weed.map(func(w): return w[0])

	func fish() -> Array:
		return _fish

	func food() -> Array:
		return _food

	func feed() -> void:
		var w := water()
		for i in 6:
			_food.append(Vector2(randf_range(w.position.x + 40, w.end.x - 40), WATER.position.y + 4))

	func eat(pellet: Vector2) -> void:
		_food.erase(pellet)

	func splash(at: Vector2) -> void:
		_splashes.append([at, 0.0])

	func _process(delta: float) -> void:
		_time += delta
		var floor_y := WATER.end.y - SAND_H * 0.6
		for i in _food.size():
			_food[i] = Vector2(_food[i].x + sin(_time * 2.0 + i) * 0.2, minf(_food[i].y + 22.0 * delta, floor_y))
		for s in _splashes:
			s[1] += delta
		_splashes = _splashes.filter(func(s): return s[1] < 0.8)
		for s in _fish:
			s.swim(delta, self)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var best: Swimmer = null
			for s in _fish:
				if s.hit(event.position) and (best == null or s.z_index > best.z_index):
					best = s
			if best != null:
				picked.emit(best.index)
				accept_event()

	func _draw() -> void:
		# Stand and glass.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.045))
		var w := WATER
		# Water: dark below, lighter at the top, a line of light at the surface.
		var cols := PackedColorArray([WATER_TOP, WATER_TOP, WATER_BOTTOM, WATER_BOTTOM])
		draw_polygon(PackedVector2Array([w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)]), cols)
		# Light shafts from above.
		for i in 4:
			var x := w.position.x + w.size.x * (0.15 + i * 0.22) + sin(_time * 0.3 + i) * 14.0
			var ray := PackedVector2Array([Vector2(x, w.position.y), Vector2(x + 40, w.position.y),
				Vector2(x + 110, w.end.y - SAND_H), Vector2(x + 40, w.end.y - SAND_H)])
			draw_colored_polygon(ray, Color(0.7, 0.95, 1.0, 0.035))
		# The surface, gently moving.
		var surf := PackedVector2Array()
		for i in 41:
			var x := w.position.x + w.size.x * i / 40.0
			surf.append(Vector2(x, w.position.y + sin(_time * 1.6 + i * 0.5) * 1.5))
		draw_polyline(surf, Color(0.8, 0.95, 1.0, 0.45), 2.0)
		# Weed, swaying.
		for wd in _weed:
			var base := Vector2(wd[0], w.end.y - SAND_H * 0.55)
			var pts := PackedVector2Array()
			var segs := 8
			for j in segs + 1:
				var k := float(j) / segs
				var sway: float = sin(_time * 1.2 + wd[2] + k * 2.0) * 10.0 * k
				pts.append(base + Vector2(sway, -wd[1] * k))
			draw_polyline(pts, wd[3], 6.0)
			draw_polyline(pts, wd[3].lightened(0.2), 2.0)
		# Sand and pebbles.
		var sand := Rect2(w.position.x, w.end.y - SAND_H, w.size.x, SAND_H)
		draw_rect(sand, Color(0.55, 0.47, 0.34))
		draw_rect(Rect2(sand.position, Vector2(sand.size.x, 6)), Color(0.62, 0.54, 0.4))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 40:
			var p := Vector2(rng.randf_range(sand.position.x, sand.end.x), rng.randf_range(sand.position.y + 8, sand.end.y - 4))
			draw_circle(p, rng.randf_range(2, 5), Color(0.4, 0.36, 0.3).lerp(Color(0.7, 0.66, 0.58), rng.randf()))
		# Food.
		for f in _food:
			draw_circle(f, 2.5, Color(0.8, 0.55, 0.3))
		# Splashes from jumpers.
		for s in _splashes:
			var a: float = 1.0 - s[1] / 0.8
			draw_arc(s[0], 6.0 + s[1] * 30.0, PI, TAU, 16, Color(0.85, 0.95, 1.0, a * 0.8), 2.0)
		# Glass: edge, glare.
		draw_rect(w, Color(0.75, 0.9, 1.0, 0.35), false, 3.0)
		draw_line(w.position + Vector2(18, 20), w.position + Vector2(60, w.size.y - 60), Color(1, 1, 1, 0.06), 10.0)
		draw_rect(Rect2(w.position.x - 8, w.position.y - 10, w.size.x + 16, 12), Color(0.16, 0.14, 0.12))
		draw_rect(Rect2(w.position.x - 8, w.end.y, w.size.x + 16, 16), Color(0.16, 0.14, 0.12))
		if Profile.tank.is_empty():
			draw_string(get_theme_default_font(), Vector2(0, w.get_center().y), "空空的魚缸", HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 20, Color(1, 1, 1, 0.3))


## One fish in the tank, swimming by its trait.
class Swimmer extends Sprite2D:
	var index := 0
	var trait_key := "active"
	var width := 60.0
	var vel := Vector2.ZERO
	var target := Vector2.ZERO
	var speed := 40.0
	var _t := 0.0
	var _rethink := 0.0
	var _dash := 0.0
	var _victim: Swimmer = null
	var _flee := Vector2.ZERO
	var _jump := -1.0
	var _jump_from := Vector2.ZERO
	var _next_jump := 0.0

	func setup(f: Dictionary, i: int, tank) -> void:
		index = i
		trait_key = f.get("tank_trait", "active")
		texture = FishData.icon(f.get("id", ""), f.get("name", ""))
		var length := float(f.get("length", 30.0))
		width = lerpf(30.0, 130.0, clampf(log(length / 5.0) / log(60.0), 0.0, 1.0))
		if texture != null:
			scale = Vector2.ONE * width / texture.get_width()
		speed = {"lazy": 14.0, "active": 55.0, "school": 45.0, "fierce": 50.0, "bottom": 25.0, "shy": 28.0,
			"jumper": 48.0, "glutton": 40.0}.get(trait_key, 40.0) * randf_range(0.85, 1.15)
		var w: Rect2 = tank.water()
		position = Vector2(randf_range(w.position.x, w.end.x), randf_range(w.position.y, w.end.y))
		target = position
		_t = randf() * 10.0
		_next_jump = randf_range(8.0, 18.0)
		z_index = int(width)

	func hit(p: Vector2) -> bool:
		return absf(p.x - position.x) < width * 0.5 and absf(p.y - position.y) < width * 0.25 + 6.0

	func startle(from: Vector2) -> void:
		_flee = (position - from).normalized() * 140.0

	func _pick_target(tank) -> void:
		var w: Rect2 = tank.water()
		var p := Vector2(randf_range(w.position.x, w.end.x), randf_range(w.position.y, w.end.y))
		match trait_key:
			"bottom":
				p.y = randf_range(w.end.y - w.size.y * 0.2, w.end.y)
			"shy":
				var xs: Array = tank.weed_x()
				p.x = clampf(xs[randi() % xs.size()] + randf_range(-25, 25), w.position.x, w.end.x)
				p.y = randf_range(w.position.y + w.size.y * 0.4, w.end.y)
			"lazy":
				p = position + Vector2(randf_range(-40, 40), randf_range(-15, 15))
		target = p.clamp(w.position, w.end)
		_rethink = randf_range(2.5, 6.0) * (2.0 if trait_key == "lazy" else 1.0)

	func swim(delta: float, tank) -> void:
		_t += delta
		var w: Rect2 = tank.water()
		if _jump >= 0.0:
			_leap(delta, tank)
			return
		_rethink -= delta
		if _rethink <= 0.0 or position.distance_to(target) < 12.0:
			_pick_target(tank)
		var go := target
		var pace := speed
		# Food: everyone goes for it, gluttons fastest.
		var food: Array = tank.food()
		if not food.is_empty() and trait_key != "lazy":
			var near: Vector2 = food[0]
			for f in food:
				if position.distance_to(f) < position.distance_to(near):
					near = f
			go = near
			pace = speed * (2.0 if trait_key == "glutton" else 1.3)
			if position.distance_to(near) < width * 0.3:
				tank.eat(near)
		elif trait_key == "school":
			# Keep with the others: toward the middle of the school.
			var sum := Vector2.ZERO
			var n := 0
			for o in tank.fish():
				if o != self and (o.trait_key == "school" or n == 0):
					sum += o.position
					n += 1
			if n > 0:
				go = go.lerp(sum / n, 0.7)
		elif trait_key == "fierce":
			_dash -= delta
			if _dash < -randf_range(6.0, 10.0) and tank.fish().size() > 1:
				var others: Array = tank.fish().filter(func(o): return o != self)
				_victim = others[randi() % others.size()]
				_dash = 1.4
			if _dash > 0.0 and _victim != null and is_instance_valid(_victim):
				go = _victim.position
				pace = speed * 2.4
				if position.distance_to(_victim.position) < width * 0.5:
					_victim.startle(position)
					_dash = 0.0
		elif trait_key == "jumper":
			_next_jump -= delta
			if _next_jump <= 0.0 and position.y < w.position.y + w.size.y * 0.35:
				_jump = 0.0
				_jump_from = position
				tank.splash(Vector2(position.x, WATER.position.y))
				return
			elif _next_jump <= 0.0:
				go = Vector2(position.x, w.position.y)
				pace = speed * 1.6
		var want := (go - position).normalized() * pace if position.distance_to(go) > 2.0 else Vector2.ZERO
		vel = vel.lerp(want, minf(1.0, delta * 1.8))
		if _flee != Vector2.ZERO:
			vel += _flee * delta * 6.0
			_flee = _flee.move_toward(Vector2.ZERO, 200.0 * delta)
		position = (position + vel * delta).clamp(w.position, w.end)
		_pose(delta)

	## A leap out of the water and back.
	func _leap(delta: float, tank) -> void:
		_jump += delta
		var k := _jump / 1.1
		var top := WATER.position.y
		position = Vector2(_jump_from.x + vel.x * 0.6 * _jump + signf(vel.x + 0.01) * 50.0 * k,
			top + (_jump_from.y - top) * (1.0 - sin(k * PI)) - sin(k * PI) * 70.0)
		rotation = lerpf(-0.8, 0.8, k) * (1.0 if not flip_h else -1.0)
		if k >= 1.0:
			_jump = -1.0
			_next_jump = randf_range(12.0, 25.0)
			tank.splash(Vector2(position.x, top))
			position.y = top + 20.0

	func _pose(_delta: float) -> void:
		if absf(vel.x) > 3.0:
			flip_h = vel.x < 0.0
		var tilt := clampf(vel.y / maxf(speed, 1.0), -1.0, 1.0) * 0.35
		rotation = (-tilt if flip_h else tilt) + sin(_t * (6.0 + vel.length() * 0.05)) * 0.03
		# A little tail beat: the body flexes along its length.
		var base := width / texture.get_width() if texture != null else 1.0
		scale = Vector2(base * (1.0 + sin(_t * 7.0) * 0.025), base)
