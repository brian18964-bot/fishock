class_name DepartChooser
extends Control

## User request: 出發 has a button of its own on the main screen; tapped, this window: two halves,
## 劇情模式 on the left (the tutorial and the story to come: the journey page's chapters) and
## 自由模式 on the right (alone or with others - others not yet - then the map, and off). Each with
## a picture made from the game itself (assets/ui/depart/). A tap outside the window closes it.
##
## `camp`: the camp screen (TitleScreen) that opens the story page (open_page("journey")) and walks
## the traveller out (depart_free); without one (a page on its own, a test), it starts the run
## itself.

const ART := "res://assets/ui/depart/"
const MAPS := [["", "湖畔森林", "map_forest", "森林中的湖泊與池塘，熟悉的夜晚。"],
	["snow_pine", "雪地森林", "map_snow", "覆雪的松林與結冰的池緣，冷冽的夜。"],
	["autumn", "秋林", "map_autumn", "枯樹與落葉，林間只剩零星的野獸。"],
	["desert", "沙漠綠洲", "map_desert", "沙丘間的綠洲與椰棗樹，遠古白骨半埋沙中。"],
	["coast", "沙灘海岸", "map_coast", "一側是大海，椰子樹下的沙灘與浪花。"],
	["coast_cliff", "海崖", "map_coast_cliff", "草原台地的盡頭是斷崖，崖下浪花拍打礁石。"]]
## The map cards' width: as wide as they fit side by side (at most this).
const MAP_CARD_MAX := 400.0
## (user request: a fourth map, the desert - the four side by side within the window's inside; a
## fifth, the seaside, beside them; then the seaside two of its own (the sandy beach, the sea
## cliff) - the six in rows of MAP_PER_ROW)
const MAP_ROW := 868.0
const MAP_PER_ROW := 3
## (in more than one row, the cards' pictures flatter - this share of their width - so the rows and
## the window's buttons fit its height)
const MAP_PIC_FLAT := 0.22
const MAP_PIC_FLAT_CURSES := 0.14
## A tap that soon after it opened is the opening tap's echo (a phone sends it twice): not a close.
const OPEN_GUARD_MS := 450

var camp: Object
var step := "mode"
var map_theme := ""
## The story's branch picked to fish in (a level's id), "" a map made at random.
var branch := ""
var picked_curses: Array = []
var _panel: PanelContainer
var _body: VBoxContainer
var _opened_at := 0


static func open(host: Node, camp_screen: Object = null) -> DepartChooser:
	var c := DepartChooser.new()
	c.name = "DepartChooser"
	c.camp = camp_screen
	host.add_child(c)
	return c


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed \
				and Time.get_ticks_msec() - _opened_at > OPEN_GUARD_MS:
			close())
	add_child(shade)
	var made := UiKit.window("出發")
	_panel = made[0]
	_body = made[1]
	_panel.name = "DepartWindow"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = Vector2(30, 22)
	_panel.custom_minimum_size = Vector2(900, 496)
	_panel.size = _panel.custom_minimum_size
	add_child(_panel)
	var x := UiKit.close_button()
	x.name = "CloseChooser"
	x.position = Vector2(_panel.position.x + _panel.size.x - 44, _panel.position.y + 8)
	x.pressed.connect(close)
	add_child(x)
	Sfx.play("ui_open", -6.0)
	show_step("mode")


func close() -> void:
	Sfx.play("ui_close", -8.0)
	queue_free()


func show_step(which: String) -> void:
	step = which
	# (the window's own title stays; what's under it is built afresh)
	var old := _body.get_children().slice(1)
	for c in old:
		_body.remove_child(c)
		c.queue_free()
	match which:
		"mode":
			_build_modes()
		"maps":
			_build_maps()


# ---------------------------------------------------------------- 劇情 / 自由

func _build_modes() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var story := _card("StoryMode", "劇情模式", "story",
		"新手教學與故事篇章：跟著章節認識營地、祭壇的守護者，以及夜裡森林中的東西。之後的劇情也會在這裡展開。")
	var go_story := UiKit.button("進入劇情", 18, "red")
	go_story.name = "GoStory"
	go_story.custom_minimum_size = Vector2(180, 46)
	go_story.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go_story.pressed.connect(_open_story)
	story.get_meta("actions").add_child(go_story)
	row.add_child(story)
	var free := _card("FreeMode", "自由模式", "free",
		"選一張地圖，在夜裡自由釣魚：隨機的地形與風景，所有威脅都在。額度 30，五分鐘。")
	var acts: HBoxContainer = free.get_meta("actions")
	var open := Campaign.free_open()
	var solo := UiKit.button("單人", 18, "red")
	solo.name = "GoSolo"
	solo.custom_minimum_size = Vector2(130, 46)
	solo.disabled = not open
	solo.pressed.connect(func(): show_step("maps"))
	acts.add_child(solo)
	var multi := UiKit.button("多人", 18)
	multi.name = "GoMulti"
	multi.custom_minimum_size = Vector2(130, 46)
	multi.disabled = not open
	multi.pressed.connect(func():
		MenuStyle.notice(self, "多人連線", ["正在開發中，敬請期待！",
			"規劃：和朋友組隊夜釣、一起湊獻祭額度、互相照亮躲避鬼魂。"]))
	acts.add_child(multi)
	if not open:
		var lock := UiKit.label("通過劇情第一章「%s」後開放" % Campaign.chapter(1).name, 14, UiKit.DANGER, true)
		lock.name = "FreeLocked"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		free.get_meta("words").add_child(lock)
	row.add_child(free)


## A half of the window: its picture, its name, what it is, a row for its buttons
## (meta "actions"; the words' box, meta "words").
func _card(node_name: String, title: String, picture: String, about: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.add_theme_stylebox_override("panel", UiKit.slot_box())
	card.custom_minimum_size = Vector2(428, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var pic := TextureRect.new()
	pic.name = "Picture"
	pic.texture = load(ART + picture + ".png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(412, 232)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	col.add_child(words)
	var name_l := UiKit.label(title, 22, UiKit.GOLD_BRIGHT, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(name_l)
	var about_l := UiKit.label(about, 14, UiKit.TEXT)
	about_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about_l.custom_minimum_size = Vector2(404, 0)
	words.add_child(about_l)
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 12)
	col.add_child(acts)
	card.set_meta("actions", acts)
	card.set_meta("words", words)
	return card


func _open_story() -> void:
	queue_free()
	if camp != null and is_instance_valid(camp) and camp.has_method("open_page"):
		camp.call("open_page", "journey")
	else:
		get_tree().change_scene_to_file("res://scenes/journey.tscn")


# ---------------------------------------------------------------- 自由模式：地圖

func _build_maps() -> void:
	var head := UiKit.label("自由模式・單人：選擇地圖", 18, UiKit.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(head)
	var per := mini(MAPS.size(), MAP_PER_ROW)
	var wide := minf(MAP_CARD_MAX, (MAP_ROW - 16.0 * (per - 1)) / per)
	var flat := 0.5 if MAPS.size() <= per else MAP_PIC_FLAT
	# (the curses under them too: flatter still, so the window's buttons stay in it)
	if Campaign.curses_open():
		flat = MAP_PIC_FLAT_CURSES
	var row: HBoxContainer = null
	for m in MAPS:
		if row == null or row.get_child_count() >= per:
			row = HBoxContainer.new()
			row.name = "MapRow%d" % _body.get_child_count()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 16)
			_body.add_child(row)
		var key: String = m[0]
		var card := Button.new()
		card.name = "Map_" + (key if key != "" else "forest")
		card.focus_mode = Control.FOCUS_NONE
		card.flat = true
		card.custom_minimum_size = Vector2(wide, wide * flat + (80.0 if flat >= 0.5 else 62.0))
		var on := map_theme == key
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiKit.slot_box())
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(col)
		var pic := TextureRect.new()
		pic.texture = load(ART + str(m[2]) + ".png")
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(wide - 16.0, (wide - 16.0) * flat)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not on:
			pic.modulate = Color(0.62, 0.62, 0.66)
		col.add_child(pic)
		var name_l := UiKit.label(("✓ " if on else "") + str(m[1]), 18 if flat >= 0.5 else 16, UiKit.GOLD_BRIGHT if on else UiKit.TEXT, true)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_l)
		var about := UiKit.label(str(m[3]).trim_suffix("。"), 13 if flat >= 0.5 else 12, UiKit.DIM)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# (wrapped within the card - two lines at most - so a longer line doesn't push it wider)
		about.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		about.custom_minimum_size = Vector2(wide - 12.0, 0)
		about.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(about)
		if on:
			var ring := ReferenceRect.new()
			ring.border_color = UiKit.GOLD_BRIGHT
			ring.border_width = 3.0
			ring.editor_only = false
			ring.set_anchors_preset(Control.PRESET_FULL_RECT)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(ring)
		card.pressed.connect(func():
			if map_theme != key:
				branch = ""
			map_theme = key
			show_step("maps"))
		row.add_child(card)
	_branch_row()
	# After the last chapter: curses, for more gold.
	if Campaign.curses_open():
		var grid := GridContainer.new()
		grid.name = "Curses"
		grid.columns = Campaign.CURSE_ORDER.size()
		grid.add_theme_constant_override("h_separation", 12)
		for key in Campaign.CURSE_ORDER:
			var c: Dictionary = Campaign.CURSES[key]
			var cb := CheckButton.new()
			cb.name = "Curse_" + key
			cb.text = "%s（+%d%%）" % [c.name, int(roundf(float(c.bonus) * 100.0))]
			cb.tooltip_text = str(c.desc)
			cb.focus_mode = Control.FOCUS_NONE
			cb.add_theme_font_size_override("font_size", 13)
			cb.button_pressed = key in picked_curses
			cb.toggled.connect(func(on):
				if on and not key in picked_curses:
					picked_curses.append(key)
				elif not on:
					picked_curses.erase(key))
			grid.add_child(cb)
		_body.add_child(grid)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 20)
	_body.add_child(foot)
	var back := UiKit.button("‹ 返回", 16)
	back.name = "BackToModes"
	back.custom_minimum_size = Vector2(120, 46)
	back.pressed.connect(func(): show_step("mode"))
	foot.add_child(back)
	var where := map_name(map_theme)
	if branch != "":
		where = str(Campaign.level(branch).get("name", where))
	var go := UiKit.button("出發：%s" % where, 20, "red")
	go.name = "GoFree"
	go.custom_minimum_size = Vector2(240, 50)
	go.pressed.connect(depart)
	foot.add_child(go)


## User request (free mode: each branch its own fish, there to be collected): under the maps, the picked
## map's ways to go - 隨機地圖 (made at random; now and then a night of its own, Campaign.FREE_EVENTS)
## or one of its branches in the story, open once cleared there (all, for the developer); and a line
## on what the one picked holds.
func _branch_row() -> void:
	var row := HBoxContainer.new()
	row.name = "Branches"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var options := [["", "隨機地圖"]]
	for l in Campaign.branches_of(map_theme):
		options.append([str(l.id), "%s %s" % [l.id, l.name]])
	for o in options:
		var id: String = o[0]
		var open := branch_open(id)
		var on := branch == id
		var b := UiKit.button(("✓ " if on else "") + str(o[1]), 13, "red" if on else "gray")
		b.name = "Branch_" + (id if id != "" else "random")
		b.custom_minimum_size = Vector2(0, 34)
		b.disabled = not open
		b.pressed.connect(func():
			branch = id
			show_step("maps"))
		row.add_child(b)
	_body.add_child(row)
	var words := "隨機生成這種風格的地圖，偶爾會遇上特別的夜晚：魚種風暴、暗潮之夜、巨物之夜"
	if branch != "":
		var r := Campaign.rules_for(branch)
		var own: Array = []
		for f in r.get("fish", []) + r.get("fish_epic", []):
			own.append(FishData.FISH[f].name)
		words = "%s的地圖與天氣・獨有魚：%s（不計星數）" % [Campaign.level(branch).name, "、".join(own)]
	elif options.size() > 1 and not branch_open(str(options[1][0])):
		words += "　・分支要先在劇情模式通過才能選"
	var about := UiKit.label(words, 12, UiKit.DIM)
	about.name = "BranchAbout"
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(about)


## Whether the branch `id` can be fished in freely ("" - a map made at random - always): cleared in the story.
static func branch_open(id: String) -> bool:
	return id == "" or Campaign.level_done(id) or Campaign.dev_all_open


## A map's name (MAPS; the lakeside forest's for "").
static func map_name(theme: String) -> String:
	for m in MAPS:
		if m[0] == theme:
			return m[1]
	return MAPS[0][1]


## Off on the free run picked.
func depart() -> void:
	queue_free()
	if camp != null and is_instance_valid(camp) and camp.has_method("depart_free"):
		camp.call("depart_free", picked_curses, map_theme, branch)
		return
	Campaign.begin_free(picked_curses, map_theme, branch)
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
