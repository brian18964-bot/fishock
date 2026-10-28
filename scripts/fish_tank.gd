extends Control

## The fish tank (from the main screen's 魚缸). User request: the fish
## brought home from a run (Profile.tank - put there when the run is
## escaped, see GameState._bring_fish_home) swim in a tank; beside it, the
## list of them, to sell or (once multiplayer comes) trade. Each swims by
## its trait (FishData.TANK_TRAITS): schooling ones keep together, fierce
## ones go for the others now and then, bottom dwellers keep low, shy ones
## by the weed, lazy ones barely move, jumpers leap, gluttons get to the
## food first. Tap a fish, in the tank or the list, for its card.
## User request (3D out of the game): the tank is 3D (Aquarium) - the 2D
## one (TankView) stays for when the 3D camp is turned off. User request
## (Camp v2): the 3D one is the camp's half-cut drum of water, seen from
## above.
## User request: two tabs - 總覽 (the tank's fish, the bag's and the
## warehouse's all in one list, the bucket half in the frame at the tank's
## left) and 魚桶 (the bucket: the fish in it, dead ones lying piled, a live
## one put in dying in its time, then rotting). A fish's card is at the left,
## and putting it in the bag or the warehouse brings up their grid beside it
## (FishPlacer) to set it where it goes.

const TANK := Rect2(24, 66, 580, 454)
## The water inside the glass (tank-local).
const WATER := Rect2(10, 26, 570, 380)
const SAND_H := 44.0
const WATER_TOP := Color(0.1, 0.3, 0.38)
const WATER_BOTTOM := Color(0.03, 0.1, 0.16)
## Where the card and the grid beside it go (the page is 960 wide).
const CARD_AT := Vector2(14, 0)
const CARD_WIDTH := 420.0
const PLACER_X := 448.0

var _tank  # Aquarium, or TankView when the 3D camp is off
var _list: VBoxContainer
var _count: Label
var _purse: PanelContainer
var _card: Control
var _placer: FishPlacer
## Which the right-hand window shows: "overview" (the tank's, the bag's and
## the warehouse's fish) or "bucket".
var _tab := "overview"
var _tabs := {}
const TAB_NAMES := [["overview", "總覽"], ["bucket", "魚桶"]]
## The lists the overview shows: [list, heading, capacity (0: none)].
const SECTIONS := [["tank", "魚缸", Profile.TANK_SIZE], ["pack", "包包（下次出發帶上）", 0], ["stash", "倉庫", Profile.STASH_SIZE]]
var _toast: Label


func _ready() -> void:
	_build()
	# User request: what the fortune fish sent while away.
	var sent := Profile.settle_fortune()
	Profile.gold_updated.connect(func(_g): _refresh_gold())
	_refresh_gold()
	_rebuild()
	if sent > 0:
		_say("財神魚送來了 %d 金幣" % sent)


func _build() -> void:
	_purse = UiKit.page_chrome(self, func(): UiKit.page_back(self))
	# User request: the fish log is here now (not on the main screen).
	var book := UiKit.button("圖鑑", 15)
	book.name = "FishLog"
	book.position = Vector2(592, 12)
	book.custom_minimum_size = Vector2(100, 38)
	book.pressed.connect(func(): UiKit.page_go(self, "fish_log"))
	add_child(book)
	var feed := UiKit.button("餵食", 15, "red")
	feed.name = "Feed"
	feed.position = Vector2(700, 12)
	feed.custom_minimum_size = Vector2(100, 38)
	feed.pressed.connect(func(): _tank.feed())
	add_child(feed)

	# The tank in its own frame.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.frame_box(true))
	frame.position = TANK.position - Vector2(10, 10)
	frame.size = TANK.size + Vector2(20, 20)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_tank = Aquarium.new() if Profile.settings.get("camp_3d", true) else TankView.new()
	_tank.name = "Tank"
	_tank.position = TANK.position
	_tank.size = TANK.size
	_tank.picked.connect(func(i): _card_for(i, "tank"))
	if _tank.has_signal("bucket_picked"):
		_tank.bucket_picked.connect(func(i): _card_for(i, "box"))
	add_child(_tank)

	var made := UiKit.window("魚缸")
	var right: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	right.position = Vector2(622, 56)
	right.custom_minimum_size = Vector2(324, 474)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in TAB_NAMES:
		var b := UiKit.button(t[1], 15)
		b.name = "Tab_" + t[0]
		b.custom_minimum_size = Vector2(110, 36)
		var key: String = t[0]
		b.pressed.connect(func():
			_tab = key
			_rebuild())
		tabs.add_child(b)
		_tabs[key] = b
	col.add_child(tabs)
	_count = UiKit.label("", 15, UiKit.DIM)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count.custom_minimum_size.x = 288
	col.add_child(_count)
	var scroll := DragScroll.new()
	scroll.custom_minimum_size = Vector2(288, 336)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	col.add_child(scroll)
	add_child(right)
	_toast = UiKit.label("", 17, UiKit.GOLD_BRIGHT, true, 5)
	_toast.position = Vector2(120, 16)
	_toast.custom_minimum_size = Vector2(460, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _say(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _refresh_gold() -> void:
	UiKit.set_purse(_purse, Profile.gold)


func _rebuild() -> void:
	for k in _tabs:
		UiKit.style_tab(_tabs[k], k == _tab)
	for c in _list.get_children():
		c.queue_free()
	if _tab == "bucket":
		_count.text = "魚桶  %d / %d　活魚放進去會慢慢死去，死了又會慢慢腐敗" % [Profile.fish_box.size(), Profile.FISH_BOX_SIZE]
		if Profile.fish_box.is_empty():
			var l := UiKit.label("魚桶是空的。點魚缸裡的魚，可以把牠放進魚桶；帶回來的死魚也在這裡。", 15, UiKit.DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 280
			_list.add_child(l)
		for i in Profile.fish_box.size():
			_list.add_child(_row(i, "box"))
	else:
		_count.text = "魚缸 %d / %d　包包 %d　倉庫 %d / %d" % [Profile.tank.size(), Profile.TANK_SIZE, Profile.pack_fish.size(),
			Profile.stash_fish.size(), Profile.STASH_SIZE]
		for sec in SECTIONS:
			var fish := Profile.fish_list(sec[0])
			_list.add_child(UiKit.label("%s　%d%s" % [sec[1], fish.size(), " / %d" % sec[2] if sec[2] > 0 else ""], 15, UiKit.GOLD_BRIGHT, true))
			if fish.is_empty():
				var empty := {"tank": "還沒有魚。從遊戲裡帶著漁獲成功逃出來，魚就會放進這裡。",
					"pack": "包包裡沒有魚。點魚，可以放進包包帶出去。", "stash": "倉庫裡沒有魚。"}
				var l := UiKit.label(empty[sec[0]], 13, UiKit.DIM)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size.x = 280
				_list.add_child(l)
			for i in fish.size():
				_list.add_child(_row(i, sec[0]))
	if _tank.has_method("set_view"):
		_tank.set_view("bucket" if _tab == "bucket" else "tank")
	_tank.stock()


## A fish in the list: its picture in a slot ringed by its rarity, its
## name in that colour, its trait and size.
func _row(i: int, src := "tank") -> Control:
	var f: Dictionary = Profile.fish_list(src)[i]
	var rarity := UiKit.fish_rarity(f)
	var b := Button.new()
	b.name = "Fish_%s_%d" % [src, i]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(284, 58)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.35)
	box.border_color = Color(0.3, 0.28, 0.25, 0.8)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	var hover := box.duplicate()
	hover.bg_color = Color(0.22, 0.17, 0.08, 0.6)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(_card_for.bind(i, src))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var pic := FishIcon.new()
	pic.fish = f
	pic.custom_minimum_size = Vector2(50, 50)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UiKit.label(f.get("name", "魚"), 16, UiKit.rarity_color(rarity), true))
	top.add_child(UiKit.label(FishData.trait_name(f.get("tank_trait", "")), 13, UiKit.USE))
	words.add_child(top)
	var state := FishLife.state(f)
	var life := FishLife.traits_text(f)
	words.add_child(UiKit.label("%s%s%s" % [FishData.size_text(f), "" if state == "alive" else "・" + FishLife.state_text(f),
		"・" + life if life != "" else ""], 12, UiKit.DIM))
	row.add_child(words)
	b.add_child(row)
	return b


## A fish's card (its tooltip): picture, name, measurements, trait, price;
## sell or trade. At the left of the page, the grid it's put in beside it.
func _card_for(i: int, src := "tank") -> void:
	var list := Profile.fish_list(src)
	if _card != null or i < 0 or i >= list.size():
		return
	var f: Dictionary = list[i]
	var rarity := UiKit.fish_rarity(f)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(shade)
	_card = shade
	var panel := UiKit.tooltip_panel()
	panel.name = "Card"
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	# The fish in 3D, turning (user request), or its picture.
	if FishModel.has_model(f.get("id", "")):
		var turn := ItemPreview.new()
		turn.name = "Preview"
		turn.custom_minimum_size = Vector2(0, 150)
		col.add_child(turn)
		turn.show_fish(f.get("id", ""), f)
	else:
		var pic := TextureRect.new()
		pic.texture = FishData.icon(f.get("id", ""), f.get("name", ""))
		pic.custom_minimum_size = Vector2(0, 110)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(pic)
	col.add_child(UiKit.label(f.get("name", "魚"), 22, UiKit.rarity_color(rarity), true))
	col.add_child(UiKit.label(UiKit.rarity_name(rarity) + " 魚　" + {"tank": "在魚缸", "pack": "在包包", "stash": "在倉庫", "box": "在魚桶"}[src], 14, UiKit.rarity_color(rarity)))
	col.add_child(UiKit.divider(CARD_WIDTH - 40.0))
	col.add_child(UiKit.label("長度・重量：" + FishData.size_text(f), 15))
	var t: String = f.get("tank_trait", "")
	var tl := UiKit.label("特性：%s－%s" % [FishData.trait_name(t), FishData.TANK_TRAITS.get(t, ["", ""])[1]], 15, UiKit.USE)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size.x = CARD_WIDTH - 30.0
	col.add_child(tl)
	# (its life, kept as it was brought: it doesn't run down at home - but in the bucket)
	var vitals := FishVitals.new()
	vitals.custom_minimum_size.x = CARD_WIDTH - 30.0
	col.add_child(vitals)
	vitals.show_fish(f, src != "box")
	var price := maxi(1, roundi(float(f.get("value", 0.0))))
	var pr := HBoxContainer.new()
	pr.add_child(UiKit.label("售價：", 15))
	pr.add_child(UiKit.gold_label(price, 15))
	col.add_child(pr)
	# What can be done with it: put elsewhere (bag, warehouse, tank, bucket),
	# fed (the smith), sold (from the tank).
	var moves := HFlowContainer.new()
	moves.add_theme_constant_override("h_separation", 8)
	moves.add_theme_constant_override("v_separation", 6)
	moves.custom_minimum_size.x = CARD_WIDTH - 30.0
	var where := {"tank": "放回魚缸", "box": "放進魚桶", "pack": "放進包包", "stash": "放進倉庫"}
	for to in Profile.fish_places(f, src):
		var mb := UiKit.button(where[to], 14)
		mb.name = "Move_" + to
		mb.custom_minimum_size = Vector2(100, 38)
		var dest: String = to
		mb.pressed.connect(func():
			if dest == "pack" or dest == "stash":
				# (the grid beside the card: set it where it goes)
				_open_placer(dest, src, i)
				return
			var why := Profile.move_fish(src, i, dest)
			_close()
			if why != "":
				_say(why)
			else:
				_say("%s %s" % [f.get("name", "魚"), where[dest]])
			_rebuild())
		moves.add_child(mb)
	if FishLife.has_trait(f, "smith") and src == "tank":
		var fb := UiKit.button("餵食", 14, "red")
		fb.name = "FeedFish"
		fb.custom_minimum_size = Vector2(100, 38)
		fb.pressed.connect(func():
			_close()
			_feed_dialog(f))
		moves.add_child(fb)
	col.add_child(moves)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	acts.alignment = BoxContainer.ALIGNMENT_END
	if src == "tank":
		var sell := UiKit.button("販售 +%d" % price, 15, "red")
		sell.name = "Sell"
		sell.custom_minimum_size = Vector2(110, 42)
		sell.pressed.connect(func():
			Profile.sell_from_tank(i)
			Sfx.play("coins", -4.0)
			_close()
			_rebuild())
		acts.add_child(sell)
		var trade := UiKit.button("交換（多人連線後）", 13)
		trade.disabled = true
		trade.custom_minimum_size = Vector2(150, 42)
		acts.add_child(trade)
	var close := UiKit.button("關閉", 15)
	close.custom_minimum_size = Vector2(70, 42)
	close.pressed.connect(_close)
	acts.add_child(close)
	col.add_child(acts)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = Vector2(CARD_AT.x, maxf((size.y - panel.size.y) / 2.0, 8.0))
	if _tank.has_method("highlight"):
		if src == "box" and _tank.has_method("highlight_bucket"):
			_tank.highlight_bucket(i)
		elif src == "tank":
			_tank.highlight(i)


## The bag's grid (or the warehouse's slots) beside the card, to put the fish
## where it goes: set down, the page is refreshed.
func _open_placer(to: String, src: String, i: int) -> void:
	if _placer != null:
		_placer.queue_free()
		_placer = null
	var f: Dictionary = Profile.fish_list(src)[i]
	var why := Profile.fish_refusal(f, to)
	if why != "":
		_close()
		_say(why)
		return
	_placer = FishPlacer.new(to, src, i)
	_card.add_child(_placer)
	_placer.position = Vector2(PLACER_X, 70)
	_placer.done.connect(func(placed: bool):
		var name: String = f.get("name", "魚")
		_close()
		if placed:
			_say("%s 放進%s了" % [name, "包包" if to == "pack" else "倉庫"])
		_rebuild())


## User request: feeding one fish. The smith eats a rotten fish (from the
## bucket) and mends a piece of gear (5 durability, FishLife.SMITH_REPAIR):
## first the rotten one is picked, then the gear.
func _feed_dialog(smith: Dictionary) -> void:
	if _card != null:
		return
	var rotten := []
	for i in Profile.fish_box.size():
		if FishLife.state(Profile.fish_box[i]) == "rotten":
			rotten.append(i)
	var gear := Profile.repairable()
	var title := "餵食 %s" % smith.get("name", "魚")
	if rotten.is_empty():
		_modal(title, ["魚桶裡沒有腐敗的魚可以餵。"], [])
		return
	if gear.is_empty():
		_modal(title, ["身上沒有需要修理的裝備。"], [])
		return
	var picks := []
	for i in rotten:
		var f: Dictionary = Profile.fish_box[i]
		var idx: int = i
		picks.append(["腐敗的%s" % f.get("name", "魚"), func(): _feed_gear(idx)])
	_modal(title + "：選一條腐敗的魚", ["鐵匠吃下去後，可以選一件裝備回復 %d 點耐久。" % FishLife.SMITH_REPAIR], picks)


func _feed_gear(box_index: int) -> void:
	var picks := []
	for id in Profile.repairable():
		var gid: String = id
		picks.append(["%s（耐久 %d / %d）" % [Items.name_of(gid), Profile.durability(gid), Profile.max_durability(gid)],
			func():
				Profile.discard_from_box(box_index)
				var got := Profile.repair(gid, FishLife.SMITH_REPAIR)
				_say("鐵匠修好了%s，耐久 +%d" % [Items.name_of(gid), got])
				_close()
				_rebuild()])
	_modal("修理哪一件裝備？", ["耐久回復 %d 點。" % FishLife.SMITH_REPAIR], picks)


## A small window over the page: its title, some lines, and a button each
## for `picks` ([label, callable]); closed by 取消.
func _modal(title: String, lines: Array, picks: Array) -> void:
	_close()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_card = shade
	var panel := UiKit.tooltip_panel()
	panel.name = "Modal"
	panel.custom_minimum_size = Vector2(380, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiKit.label(title, 19, UiKit.GOLD_BRIGHT, true))
	for l in lines:
		var lb := UiKit.label(l, 15)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size.x = 350
		col.add_child(lb)
	for p in picks:
		var b := UiKit.button(p[0], 15)
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(p[1])
		col.add_child(b)
	var cancel := UiKit.button("取消" if not picks.is_empty() else "關閉", 15)
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.pressed.connect(_close)
	col.add_child(cancel)
	panel.add_child(col)
	shade.add_child(panel)
	panel.reset_size()
	panel.position = (size - panel.size) / 2.0


func _close() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
	_placer = null
	if _tank.has_method("highlight"):
		_tank.highlight(-1)
	if _tank.has_method("highlight_bucket"):
		_tank.highlight_bucket(-1)


## A fish's picture in a slot ringed by its rarity.
class FishIcon extends Control:
	var fish := {}

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_slot(self, r, UiKit.fish_rarity(fish))
		var tex := FishData.icon(fish.get("id", ""), fish.get("name", ""))
		if tex == null:
			return
		var room := r.grow(-5.0)
		var k := minf(room.size.x / tex.get_width(), room.size.y / tex.get_height())
		var sz := Vector2(tex.get_size()) * k
		draw_texture_rect(tex, Rect2(room.get_center() - sz / 2.0, sz), false)


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

	func inside(s: Swimmer) -> bool:
		return water().grow(2).has_point(s.position)

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
