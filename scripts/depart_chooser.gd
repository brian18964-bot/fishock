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
	["autumn", "秋林", "map_autumn", "枯樹與落葉，林間只剩零星的野獸。"],
	["snow_pine", "雪地森林", "map_snow", "覆雪的松林與結冰的池緣，冷冽的夜。"],
	["desert", "沙漠綠洲", "map_desert", "沙丘間的綠洲與椰棗樹，遠古白骨半埋沙中。"],
	["coast", "沙灘海岸", "map_coast", "一側是大海，椰子樹下的沙灘與浪花。"],
	["coast_cliff", "海崖", "map_coast_cliff", "草原台地的盡頭是斷崖，崖下浪花拍打礁石。"]]
## User report ("今天做的地圖我目前都無法測試"): the ruined human world's maps (chapters 7-12) as well (their
## cards the game's own night there: tools/map_cards.gd).
const RUIN_MAPS := [["city", "荒廢都市", "map_city", "龜裂的街道與空蕩大樓，積水裡游著人類的魚。"],
	["countryside", "鄉村", "map_countryside", "收割過的田與穀倉，灌溉水塘裡游著田間的魚。"],
	["japan", "日式山村", "map_japan", "竹林、鳥居和石燈籠，神社池子裡游著日本魚。"],
	["england", "英式村莊", "map_england", "木構屋和石牆，牧場邊的池塘裡游著英國的魚。"],
	["china", "中式古鎮", "map_china", "灰瓦石屋和紅柱涼亭，柳樹垂在水邊。"],
	["adobe", "土屋聚落", "map_adobe", "泥磚土屋和椰棗樹，綠洲池塘裡游著尼羅河魚。"]]
## User request ("地圖目前12風格，在選擇視窗的左側呈現出來 ... 點擊後會出現各自的分支"; "用捲動清單，12 張
## 一眼就看得到"): the twelve maps listed down the window's left, by chapter - each a row with its little
## picture - scrolled if a screen's too short for them all; the one picked on the right, its picture,
## its words and its branches. The list's width and height (px), a row's height and the gap between
## rows; the picture's height on the right (flatter with the curses under it).
const LIST_W := 230.0
const LIST_H := 322.0
const ROW_H := 25.0
const ROW_GAP := 2
const BIG_H := 150.0
const BIG_H_CURSES := 110.0
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
	_bag_warning()


## User request (塞滿要提醒): a bag too full for a big fish (2 x 2) said so before setting off -
## the bones brought home fill it a little each night - with a way straight to it to make room.
func _bag_warning() -> void:
	if Profile.bag_room_for(Inventory.SIZES.large):
		return
	var strip := HBoxContainer.new()
	strip.name = "BagWarning"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 12)
	var free := Profile.bag_free_cells()
	var words := "背包快滿了（剩 %d 格），大魚會放不下，釣到的魚只能放在地上。出發前先賣掉或收進倉庫吧。" % free
	if free == 0:
		words = "背包滿了！釣到的魚會放不下，只能放在地上。出發前先賣掉或收進倉庫吧。"
	var note := UiKit.label(words, 14, UiKit.DANGER, true)
	strip.add_child(note)
	if camp != null and is_instance_valid(camp) and camp.has_method("open_page"):
		var go := UiKit.button("整理背包", 14)
		go.name = "SortBag"
		go.custom_minimum_size = Vector2(96, 30)
		go.pressed.connect(func():
			queue_free()
			camp.call("open_page", "equipment", "bag"))
		strip.add_child(go)
	_body.add_child(strip)


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
	var pane := HBoxContainer.new()
	pane.name = "MapsPane"
	pane.add_theme_constant_override("separation", 14)
	_body.add_child(pane)
	# (left: the twelve, one under another by chapter)
	var scroll := ScrollContainer.new()
	scroll.name = "MapList"
	scroll.custom_minimum_size = Vector2(LIST_W, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "MapRows"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(col)
	var maps := all_maps()
	for i in maps.size():
		var m: Array = maps[i]
		var key: String = m[0]
		var on := map_theme == key
		var row := Button.new()
		row.name = "Map_" + (key if key != "" else "forest")
		row.focus_mode = Control.FOCUS_NONE
		row.flat = true
		row.custom_minimum_size = Vector2(LIST_W - 14.0, ROW_H)
		var frame := PanelContainer.new()
		# (the slot frame, its top and bottom margins thinned so a row stays ROW_H tall and the twelve
		# fit the list without scrolling)
		var box := UiKit.slot_box()
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0
		frame.add_theme_stylebox_override("panel", box)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(frame)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 8)
		frame.add_child(line)
		var pic := TextureRect.new()
		pic.texture = load(ART + str(m[2]) + ".png")
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2((ROW_H - 6.0) * 16.0 / 9.0, ROW_H - 6.0)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not on:
			pic.modulate = Color(0.62, 0.62, 0.66)
		line.add_child(pic)
		var name_l := UiKit.label("%d　%s" % [i + 1, m[1]], 14, UiKit.GOLD_BRIGHT if on else UiKit.TEXT, on)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(name_l)
		if on:
			var ring := ReferenceRect.new()
			ring.border_color = UiKit.GOLD_BRIGHT
			ring.border_width = 2.0
			ring.editor_only = false
			ring.set_anchors_preset(Control.PRESET_FULL_RECT)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(ring)
		row.pressed.connect(func():
			if map_theme != key:
				branch = ""
			map_theme = key
			show_step("maps"))
		col.add_child(row)
	# (all twelve in sight: the list as tall as its rows come to, should a font make them taller)
	scroll.custom_minimum_size.y = maxf(LIST_H, col.get_combined_minimum_size().y)
	# (right: the one picked - its picture, its name and words, its branches)
	var detail := VBoxContainer.new()
	detail.name = "MapDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	pane.add_child(detail)
	var picked := _map_of(map_theme)
	var big := TextureRect.new()
	big.name = "MapPicture"
	big.texture = load(ART + str(picked[2]) + ".png")
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	big.custom_minimum_size = Vector2(0, BIG_H_CURSES if Campaign.curses_open() else BIG_H)
	detail.add_child(big)
	var title := UiKit.label(str(picked[1]), 20, UiKit.GOLD_BRIGHT, true)
	title.name = "MapName"
	detail.add_child(title)
	var words := UiKit.label(str(picked[3]), 13, UiKit.DIM)
	words.name = "MapWords"
	detail.add_child(words)
	_branch_row(detail)
	# After the last chapter: curses, for more gold.
	if Campaign.curses_open():
		var grid := GridContainer.new()
		grid.name = "Curses"
		grid.columns = 3
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
		detail.add_child(grid)
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
func _branch_row(into: Control) -> void:
	var row := HFlowContainer.new()
	row.name = "Branches"
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
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
	into.add_child(row)
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
	about.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	into.add_child(about)


## Whether the branch `id` can be fished in freely ("" - a map made at random - always): cleared in the story.
static func branch_open(id: String) -> bool:
	return id == "" or Campaign.level_done(id) or Campaign.dev_all_open


## The twelve maps by chapter: [key, name, picture, words] each.
static func all_maps() -> Array:
	return MAPS + RUIN_MAPS


## A map's [key, name, picture, words] (the lakeside forest's for "" or one not listed).
static func _map_of(theme: String) -> Array:
	for m in all_maps():
		if m[0] == theme:
			return m
	return MAPS[0]


## A map's name.
static func map_name(theme: String) -> String:
	return str(_map_of(theme)[1])


## Off on the free run picked.
func depart() -> void:
	queue_free()
	if camp != null and is_instance_valid(camp) and camp.has_method("depart_free"):
		camp.call("depart_free", picked_curses, map_theme, branch)
		return
	Campaign.begin_free(picked_curses, map_theme, branch)
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
