extends Control

## User request (the campaign): where a run is chosen - the camp's 出發夜釣
## opens it. Three tabs:
##   冒險      the five chapters; each chapter's five levels along a winding
##            path (stars won, locked ones dark, the next one pulsing), and
##            the chosen level's card: what it teaches, its map and danger,
##            its stars' conditions, the first-clear reward, Willow's hints
##            on or off, and 出發.
##   自由夜釣   the free run (a random map, everything in it); after the last
##            chapter, curses to make it harder for more gold.
##   成就      the achievements and how far along each is.
## Setting off goes back to the camp (TitleScreen.depart_level / depart_free)
## for the walk out to the stone.

const CH_NUM := ["一", "二", "三", "四", "五"]
const MAP_SIZE := Vector2(500, 318)
## The five stops along the path (in the map's box), left to right.
const STOPS := [Vector2(70, 230), Vector2(170, 110), Vector2(270, 220), Vector2(370, 100), Vector2(460, 210)]
const NODE_R := 30.0
const INK := Color(0.23, 0.14, 0.06)

var chapter := 1
var selected := ""
var _tab := "story"
var _tabs := {}
var _body: Control
var _map: Control
var _card: VBoxContainer
var _purse: PanelContainer
var _stars_label: Label
var _t := 0.0
var _picked_curses: Array = []


func _ready() -> void:
	# Ones earned at the camp (the shop, the fish log) count here too.
	Campaign.check_achievements()
	_purse = UiKit.page_chrome(self, func(): UiKit.page_back(self), "BackButton")
	UiKit.set_purse(_purse, Profile.gold)
	var made := UiKit.window("旅程")
	var book: PanelContainer = made[0]
	var col: VBoxContainer = made[1]
	book.position = Vector2(14, 56)
	book.custom_minimum_size = Vector2(932, 474)
	book.size = book.custom_minimum_size
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	for t in [["story", "冒險"], ["free", "自由夜釣"], ["achievements", "成就"]]:
		var b := UiKit.button(t[1], 16)
		b.name = "Tab_" + t[0]
		b.custom_minimum_size = Vector2(120, 38)
		b.pressed.connect(_show_tab.bind(t[0]))
		bar.add_child(b)
		_tabs[t[0]] = b
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_stars_label = UiKit.label("", 16, UiKit.GOLD_BRIGHT, true)
	bar.add_child(_stars_label)
	col.add_child(bar)
	_body = Control.new()
	_body.custom_minimum_size = Vector2(900, 380)
	col.add_child(_body)
	add_child(book)
	var next := Campaign.next_to_play()
	chapter = int(Campaign.level(next).chapter)
	selected = next
	_show_tab("story")


func _process(delta: float) -> void:
	_t += delta
	if _map != null and is_instance_valid(_map):
		_map.queue_redraw()


func _show_tab(key: String) -> void:
	_tab = key
	for k in _tabs:
		UiKit.style_tab(_tabs[k], k == key)
	_stars_label.text = "★ %d / %d" % [Campaign.stars_total(), Campaign.LEVELS.size() * 3]
	for c in _body.get_children():
		c.queue_free()
	_map = null
	match key:
		"story":
			_build_story()
		"free":
			_build_free()
		"achievements":
			_build_achievements()


# ---------------------------------------------------------------- 冒險

func _build_story() -> void:
	var chapters := HBoxContainer.new()
	chapters.add_theme_constant_override("separation", 6)
	for c in Campaign.CHAPTERS:
		var n: int = c.id
		var open := Campaign.chapter_open(n)
		var words := "第%s章 %s" % [CH_NUM[n - 1], c.name]
		words += "  ★%d/15" % Campaign.chapter_stars(n) if open else "  ★%d 解鎖" % int(c.stars)
		var b := UiKit.button(words, 14)
		b.name = "Chapter%d" % n
		b.custom_minimum_size = Vector2(172, 34)
		UiKit.style_tab(b, n == chapter)
		if not open:
			b.modulate = Color(0.6, 0.6, 0.6)
		b.pressed.connect(func():
			chapter = n
			var first: Array = Campaign.levels_of(n)
			selected = first[0].id
			for l in first:
				if Campaign.level_open(l.id) and not Campaign.level_done(l.id):
					selected = l.id
					break
			_show_tab("story"))
		chapters.add_child(b)
	_body.add_child(chapters)
	var blurb := UiKit.label(str(Campaign.chapter(chapter).blurb), 13, UiKit.DIM)
	blurb.position = Vector2(4, 40)
	blurb.custom_minimum_size = Vector2(880, 0)
	_body.add_child(blurb)
	_map = Control.new()
	_map.name = "LevelMap"
	_map.position = Vector2(0, 60)
	_map.custom_minimum_size = MAP_SIZE
	_map.size = MAP_SIZE
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	_body.add_child(_map)
	var card_box := PanelContainer.new()
	card_box.add_theme_stylebox_override("panel", UiKit.parchment_box())
	card_box.position = Vector2(508, 56)
	card_box.custom_minimum_size = Vector2(380, 322)
	card_box.size = card_box.custom_minimum_size
	_card = VBoxContainer.new()
	_card.name = "LevelCard"
	_card.add_theme_constant_override("separation", 1)
	card_box.add_child(_card)
	_body.add_child(card_box)
	_fill_card()


func _on_map_input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x < 0.0:
		return
	var levels := Campaign.levels_of(chapter)
	for i in levels.size():
		if pos.distance_to(STOPS[i]) <= NODE_R + 8.0:
			select(levels[i].id)
			return


func select(id: String) -> void:
	selected = id
	Sfx.play("ui_click", -8.0)
	_fill_card()


func _draw_map() -> void:
	var levels := Campaign.levels_of(chapter)
	# The path: dotted, through the stops.
	for i in levels.size() - 1:
		var a: Vector2 = STOPS[i]
		var b: Vector2 = STOPS[i + 1]
		var mid := (a + b) / 2.0 + Vector2(0, 30 if i % 2 == 0 else -30)
		var prev := a
		for k in range(1, 13):
			var t := k / 12.0
			var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
			if k % 2 == 1:
				_map.draw_line(prev, p, Color(0.93, 0.76, 0.36, 0.55 if Campaign.level_done(levels[i].id) else 0.2), 3.0)
			prev = p
	var next := Campaign.next_to_play()
	for i in levels.size():
		var l: Dictionary = levels[i]
		var c: Vector2 = STOPS[i]
		var open := Campaign.level_open(l.id)
		var stars: Array = Profile.level_stars(l.id)
		var is_sel: bool = l.id == selected
		if l.id == next and open:
			var pulse := 0.5 + 0.5 * sin(_t * 3.0)
			_map.draw_circle(c, NODE_R + 6.0 + pulse * 4.0, Color(1.0, 0.85, 0.42, 0.18 + 0.18 * pulse))
		_map.draw_circle(c, NODE_R + 3.0, Color(0, 0, 0, 0.8))
		var fill := Color(0.36, 0.1, 0.04) if bool(stars[0]) else Color(0.18, 0.16, 0.13)
		if not open:
			fill = Color(0.1, 0.1, 0.1)
		_map.draw_circle(c, NODE_R, fill)
		_map.draw_arc(c, NODE_R, 0.0, TAU, 40, UiKit.GOLD_BRIGHT if is_sel else Color(0.62, 0.46, 0.17), 3.0 if is_sel else 2.0)
		if open:
			UiKit.draw_text(_map, c + Vector2(-NODE_R, 7), str(l.id), 18, UiKit.GOLD_BRIGHT if is_sel else UiKit.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER, NODE_R * 2.0, true)
		else:
			UiKit.draw_lock(_map, c, UiKit.DIM, 1.2)
		UiKit.draw_text(_map, c + Vector2(-60, NODE_R + 20), str(l.name), 14, UiKit.TEXT if open else UiKit.DIM,
			HORIZONTAL_ALIGNMENT_CENTER, 120)
		for k in 3:
			var sc := c + Vector2((k - 1) * 15.0, -NODE_R - 10.0)
			_star(_map, sc, 6.5, UiKit.GOLD_BRIGHT if bool(stars[k]) else Color(0.3, 0.28, 0.25))


static func _star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.7))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.82)
	ci.draw_colored_polygon(inner, color)


func _line(text: String, size := 14, color := INK, bold := false) -> Label:
	var l := UiKit.label(text, size, color, bold, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 344
	_card.add_child(l)
	return l


func _fill_card() -> void:
	for c in _card.get_children():
		c.queue_free()
	var l := Campaign.level(selected)
	if l.is_empty():
		return
	var r := Campaign.rules_for(selected)
	var open := Campaign.level_open(selected)
	_line("%s　%s" % [l.id, l.name], 19, Color(0.36, 0.1, 0.04), true)
	_line("新東西：" + str(l.teach), 13, Color(0.2, 0.3, 0.1), true)
	_line(str(l.intro), 12, Color(0.4, 0.3, 0.2))
	var clock := "不限時" if float(r.day) <= 0.0 else "%d:%02d" % [int(r.day) / 60, int(r.day) % 60]
	var skulls := Campaign.danger(r)
	var danger := "☠".repeat(skulls) if skulls > 0 else "無"
	_line("地圖 %s　額度 %d　時間 %s　危險 %s" % [Campaign.MAP_NAMES[r.map], int(r.quota), clock, danger], 13,
		Color(0.5, 0.1, 0.05) if skulls >= 3 else INK)
	if r.safe:
		_line("安全模式：失敗也不會失去任何東西", 12, Color(0.2, 0.3, 0.1))
	var stars: Array = Profile.level_stars(selected)
	var conds: Array = [{"text": "從符文石成功離開"}]
	conds.append_array(l.stars)
	for i in conds.size():
		_line("%s %s　%s" % ["★".repeat(i + 1), conds[i].text, "✓" if bool(stars[i]) else ""], 12,
			Color(0.45, 0.3, 0.02) if bool(stars[i]) else INK)
	var entry := Profile.level_entry(selected)
	if bool(stars[0]):
		var best := float(entry.get("best", 0.0))
		_line("已通關 %d 次　最快 %d:%02d" % [int(entry.get("clears", 0)), int(best) / 60, int(best) % 60], 12,
			Color(0.4, 0.3, 0.2))
	else:
		var reward: Dictionary = l.reward
		var parts := ["金幣 %d" % int(reward.get("gold", 0))]
		var items: Dictionary = reward.get("items", {})
		for id in items:
			parts.append("%s ×%d" % [Items.name_of(id), int(items[id])])
		_line("首次通關：" + "、".join(parts), 12, Color(0.45, 0.3, 0.02))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if str(r.tutorial) != "":
		var hints := CheckButton.new()
		hints.name = "Hints"
		hints.text = "柳靈提示"
		hints.focus_mode = Control.FOCUS_NONE
		hints.button_pressed = Profile.settings.get("hints", true)
		hints.add_theme_font_size_override("font_size", 14)
		hints.add_theme_color_override("font_color", INK)
		hints.toggled.connect(func(on): Profile.set_setting("hints", on))
		row.add_child(hints)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	if open:
		var go := UiKit.button("出發", 18, "red")
		go.name = "Go"
		go.custom_minimum_size = Vector2(120, 40)
		go.pressed.connect(func(): _depart_level(selected))
		row.add_child(go)
	else:
		var why := "先通過上一關"
		if not Campaign.chapter_open(int(l.chapter)):
			why = "需要 %d 顆星，並通過上一章" % int(Campaign.chapter(int(l.chapter)).stars)
		row.add_child(UiKit.label(why, 14, Color(0.5, 0.1, 0.05), true, 0))
	_card.add_child(row)


func _depart_level(id: String) -> void:
	var camp: Object = get_meta("camp", null)
	if camp != null and is_instance_valid(camp) and camp.has_method("depart_level"):
		camp.call("depart_level", id)
		return
	Campaign.begin_level(id)
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---------------------------------------------------------------- 自由夜釣

func _build_free() -> void:
	var box := VBoxContainer.new()
	box.name = "FreeRun"
	box.add_theme_constant_override("separation", 8)
	box.position = Vector2(10, 6)
	box.custom_minimum_size = Vector2(880, 0)
	_body.add_child(box)
	box.add_child(UiKit.label("自由夜釣", 22, UiKit.GOLD_BRIGHT, true))
	var about := UiKit.label("隨機的大地圖、隨機的風景，所有威脅都在。額度 30，五分鐘。", 15, UiKit.TEXT)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 860
	box.add_child(about)
	box.add_child(UiKit.label("紀錄：成功逃脫 %d 次　入夜後逃脫 %d 次　釣到 %d 條魚" % [int(Profile.stats.get("escapes", 0)),
		int(Profile.record("escaped_night")), int(Profile.record("catch"))], 14, UiKit.DIM))
	if not Campaign.free_open():
		box.add_child(UiKit.label("通過第一章「初渡」後開放。", 16, UiKit.DANGER, true))
		return
	if Campaign.curses_open():
		box.add_child(UiKit.label("詛咒：自己加難度，成功離開時依獻祭總值多拿金幣。", 15, UiKit.GOLD))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		for key in Campaign.CURSE_ORDER:
			var c: Dictionary = Campaign.CURSES[key]
			var cb := CheckButton.new()
			cb.name = "Curse_" + key
			cb.text = "%s：%s（+%d%%）" % [c.name, c.desc, int(roundf(float(c.bonus) * 100.0))]
			cb.focus_mode = Control.FOCUS_NONE
			cb.add_theme_font_size_override("font_size", 14)
			cb.button_pressed = key in _picked_curses
			cb.toggled.connect(func(on):
				if on and not key in _picked_curses:
					_picked_curses.append(key)
				elif not on:
					_picked_curses.erase(key)
				_show_tab("free"))
			grid.add_child(cb)
		box.add_child(grid)
		var bonus := 0.0
		for k in _picked_curses:
			bonus += float(Campaign.CURSES[k].bonus)
		box.add_child(UiKit.label("金幣加成：+%d%%　　最多同時通過 %d 種詛咒" % [int(roundf(bonus * 100.0)),
			int(Profile.campaign.get("best_curses", 0))], 15, UiKit.GOLD_BRIGHT))
	else:
		box.add_child(UiKit.label("通過第五章後，可以加上「詛咒」挑戰更高難度。", 14, UiKit.DIM))
	var go := UiKit.button("出發", 20, "red")
	go.name = "GoFree"
	go.custom_minimum_size = Vector2(180, 52)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_depart_free)
	box.add_child(go)


func _depart_free() -> void:
	var camp: Object = get_meta("camp", null)
	if camp != null and is_instance_valid(camp) and camp.has_method("depart_free"):
		camp.call("depart_free", _picked_curses)
		return
	Campaign.begin_free(_picked_curses)
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---------------------------------------------------------------- 成就

func _build_achievements() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Achievements"
	scroll.custom_minimum_size = Vector2(890, 372)
	scroll.size = scroll.custom_minimum_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.custom_minimum_size.x = 870
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	_body.add_child(scroll)
	var done := 0
	for a in Campaign.ACHIEVEMENTS:
		if Profile.has_achievement(a[0]):
			done += 1
	rows.add_child(UiKit.label("已達成 %d / %d" % [done, Campaign.ACHIEVEMENTS.size()], 15, UiKit.DIM))
	for a in Campaign.ACHIEVEMENTS:
		var got := Profile.has_achievement(a[0])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.slot_box())
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var tag := UiKit.label(a[1], 13, UiKit.GOLD if got else UiKit.DIM)
		tag.custom_minimum_size.x = 40
		line.add_child(tag)
		var name_l := UiKit.label(a[2], 16, UiKit.GOLD_BRIGHT if got else UiKit.TEXT, true)
		name_l.custom_minimum_size.x = 130
		line.add_child(name_l)
		var desc := UiKit.label(a[3], 14, UiKit.TEXT if got else UiKit.DIM)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.custom_minimum_size.x = 440
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(desc)
		var prog := Campaign.achievement_progress(a)
		var status := "✓ 達成" if got else ("%d / %d" % [int(minf(prog[0], prog[1])), int(prog[1])] if float(prog[1]) > 0.0 else "")
		var st := UiKit.label(status, 14, UiKit.USE if got else UiKit.DIM, true)
		st.custom_minimum_size.x = 90
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(st)
		var gold := UiKit.label("%d 金" % int(a[4]), 13, UiKit.GOLD if got else UiKit.DIM)
		gold.custom_minimum_size.x = 56
		gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(gold)
		row.add_child(line)
		rows.add_child(row)
