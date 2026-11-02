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
	["snow_pine", "雪地森林", "map_snow", "覆雪的松林與結冰的池緣，冷冽的夜。"]]
## A tap that soon after it opened is the opening tap's echo (a phone sends it twice): not a close.
const OPEN_GUARD_MS := 450

var camp: Object
var step := "mode"
var map_theme := ""
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
		var lock := UiKit.label("通過劇情第一章「初渡」後開放", 14, UiKit.DANGER, true)
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	for m in MAPS:
		var key: String = m[0]
		var card := Button.new()
		card.name = "Map_" + (key if key != "" else "forest")
		card.focus_mode = Control.FOCUS_NONE
		card.flat = true
		card.custom_minimum_size = Vector2(400, 262)
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
		pic.custom_minimum_size = Vector2(384, 192)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not on:
			pic.modulate = Color(0.62, 0.62, 0.66)
		col.add_child(pic)
		var name_l := UiKit.label(("✓ " if on else "") + str(m[1]), 18, UiKit.GOLD_BRIGHT if on else UiKit.TEXT, true)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_l)
		var about := UiKit.label(str(m[3]), 13, UiKit.DIM)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
			map_theme = key
			show_step("maps"))
		row.add_child(card)
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
	var go := UiKit.button("出發：%s" % ("雪地森林" if map_theme == "snow_pine" else "湖畔森林"), 20, "red")
	go.name = "GoFree"
	go.custom_minimum_size = Vector2(240, 50)
	go.pressed.connect(depart)
	foot.add_child(go)


## Off on the free run picked.
func depart() -> void:
	queue_free()
	if camp != null and is_instance_valid(camp) and camp.has_method("depart_free"):
		camp.call("depart_free", picked_curses, map_theme)
		return
	Campaign.begin_free(picked_curses, map_theme)
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
