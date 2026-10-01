extends Control

## The main screen. User request: like a mobile game's - the player's own
## character in 3D, the shop, the character's equipment, single player and
## multiplayer; the settings as a gear in the top-right corner; the fish
## log inside the fish tank.
## And (user request: an MMO look, everything out of the game in 3D as far
## as it goes) it's a camp at night, like an MMO's character select -
## CampStage. User request (the camp rebuilt): no list - the camp's things
## are the menu. Each has a faint gold rim; pressed (or hovered) it lights
## up with its name, and a tap opens its page over the camp while the
## camera glides to it:
##   the crate 倉庫 (warehouse), the backpack 背包 (the bag alone), the
##   tent 裝備 (equipment), the cut drum 魚缸 (fish tank), the merchant's
##   stall or his boat 商人 (shop)
##   the character: it lives there on its own (CampLife - by its
##                spirit); tap it and it waves (nods, talks...)
##   bottom:      出發夜釣 (a run), 多人連線 (not yet - says so)
##   top right:   gold, the settings (a gear)
## 出發夜釣 sets out (user request): the character takes the lamp from the
## drum and the rod from beside the tent and walks into the 渡石, then the
## run starts; back from one it comes out of the stone (escaped) or wakes
## by the fire (lost). A tap skips either.
## Between runs, so the day timer is stopped here (GameState.reset_run).
## With the 3D camp off (settings; for weak phones) it's the old stage - the
## character on its stone before a dark wall - and the camp's list on the
## right stands in for the things.

## The camp's picture is drawn at this many times the screen's own size.
const RENDER_SCALE := 1.5
const ENTRIES := [
	["warehouse", "倉庫", "res://assets/sprites/icons/battery.png"],
	["bag", "背包", ""],
	["equipment", "裝備", ""],
	["fish_tank", "魚缸", ""],
	["shop", "商城", "res://assets/sprites/icons/lamp.png"],
]

var _stage: CampStage
var _viewport: SubViewport
var _viewer: CharacterViewer
var _home: Control
var _page: Control
var _purse: PanelContainer
var _nameplate: VBoxContainer
var _entries := {}
var _drag := false
var _drag_moved := 0.0
## The camp's thing under the finger (or the mouse), lit, its name shown.
var _spot := ""
var _press_spot := ""
var _spot_label: Label
## A set piece playing (setting out, coming home): a tap skips it.
var _scene_piece := ""
var _skip_hint: Label
var _fade: ColorRect
var _setting_off := false


## A menu needn't draw at 60 frames a second: half that saves a phone's
## battery (and heat) while the camp's on screen.
const MENU_FPS := 30


func _ready() -> void:
	GameState.reset_run()
	Engine.max_fps = MENU_FPS
	# The camp's sound (user request, the MMO feel): the fire and the night,
	# and a lute.
	Sfx.ambience("amb_camp")
	Sfx.music("music_camp")
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()
	# The minutes rested here since last time (the game closed too).
	Profile.arrive_at_camp()
	var back := GameState.last_return
	GameState.last_return = ""
	if _stage != null and back != "":
		_come_home(back)
	if not Profile.tank_news.is_empty():
		_tank_news()


## User request (fish tank): back from a run with fish, the main screen
## says they went in the tank - and offers to go and look.
func _tank_news() -> void:
	var names: Array = Profile.tank_news.duplicate()
	Profile.clear_tank_news()
	var shown := names.slice(0, 8)
	var line := "將 %s 放進魚缸" % "、".join(shown)
	if names.size() > shown.size():
		line += "（還有 %d 條）" % (names.size() - shown.size())
	var note := MenuStyle.notice(self, "漁獲入缸", [line])
	note.name = "TankNews"
	var go := UiKit.button("去魚缸看看", 16, "red")
	go.custom_minimum_size = Vector2(160, 42)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func():
		note.queue_free()
		open_page("fish_tank"))
	note.get_child(0).get_child(0).add_child(go)


func camp_on() -> bool:
	return Profile.settings.get("camp_3d", true)


func _build() -> void:
	if camp_on():
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(Vector2(960, 540) * RENDER_SCALE)
		_viewport.own_world_3d = true
		_viewport.msaa_3d = Viewport.MSAA_2X
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
		_stage = CampStage.new()
		_stage.name = "Camp"
		_viewport.add_child(_stage)
		var view := TextureRect.new()
		view.name = "CampView"
		view.texture = _viewport.get_texture()
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_SCALE
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(view)
		add_child(UiKit.vignette(0.6))
	else:
		UiKit.backdrop(self)
		_viewer = CharacterViewer.new()
		_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_viewer.frame_x = -0.32
		add_child(_viewer)

	_home = Control.new()
	_home.name = "Home"
	_home.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_home)
	_home.gui_input.connect(_on_home_input)

	# Above the character: its name and how far the fish log's come.
	_nameplate = VBoxContainer.new()
	_nameplate.name = "Nameplate"
	_nameplate.add_theme_constant_override("separation", -2)
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := UiKit.label("釣客", 20, UiKit.GOLD_BRIGHT, true, 4)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nameplate.add_child(who)
	var logged := UiKit.label("", 13, UiKit.TEXT)
	logged.name = "Logged"
	logged.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nameplate.add_child(logged)
	# User request (Camp v2): the spirit, under the name.
	var spirit := SpiritBar.new()
	spirit.name = "Spirit"
	spirit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_nameplate.add_child(spirit)
	_nameplate.custom_minimum_size = Vector2(220, 0)
	_nameplate.position = Vector2(215, 92)
	_home.add_child(_nameplate)

	# Top right: gold, the settings.
	# User request: the settings as an icon, in the top right corner.
	_purse = UiKit.purse()
	_purse.position = Vector2(764, 12)
	_purse.custom_minimum_size = Vector2(126, 36)
	_home.add_child(_purse)
	var gear := GearButton.new()
	gear.name = "Settings"
	gear.position = Vector2(900, 10)
	gear.size = Vector2(44, 44)
	gear.pressed.connect(_on_settings)
	_home.add_child(gear)

	if _stage == null:
		# Right: the camp's list (only without the 3D camp - with it, the
		# camp's things are tapped).
		var made := UiKit.window("營地")
		var list: PanelContainer = made[0]
		var col: VBoxContainer = made[1]
		list.name = "CampList"
		list.position = Vector2(672, 64)
		list.custom_minimum_size = Vector2(274, 0)
		col.add_theme_constant_override("separation", 6)
		for e in ENTRIES:
			var b := _entry(e[0], e[1], e[2])
			col.add_child(b)
		_home.add_child(list)
	# The name of the camp's thing under the finger.
	_spot_label = UiKit.label("", 20, UiKit.GOLD_BRIGHT, true, 5)
	_spot_label.name = "SpotLabel"
	_spot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spot_label.custom_minimum_size = Vector2(160, 0)
	_spot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spot_label.visible = false
	_home.add_child(_spot_label)

	# Bottom: play, and multiplayer (not yet).
	var play := UiKit.button("出發夜釣", 24, "red")
	play.name = "Play"
	play.custom_minimum_size = Vector2(250, 58)
	play.position = Vector2(355, 466)
	play.pressed.connect(_on_solo)
	_home.add_child(play)
	var multi := UiKit.button("多人連線", 16)
	multi.name = "Multiplayer"
	multi.custom_minimum_size = Vector2(140, 42)
	multi.position = Vector2(14, 484)
	multi.pressed.connect(_on_multiplayer)
	_home.add_child(multi)
	var soon := UiKit.label("即將開放", 11, Color(0.6, 0.85, 1.0))
	soon.position = Vector2(88, -8)
	multi.add_child(soon)

	_skip_hint = UiKit.label("點一下畫面跳過", 15, UiKit.DIM)
	_skip_hint.name = "SkipHint"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.custom_minimum_size = Vector2(300, 0)
	_skip_hint.position = Vector2(330, 500)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.visible = false
	add_child(_skip_hint)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


## An entry in the camp's list, like a character in an MMO's list: a
## picture in a slot, a gold name, a line about it under.
func _entry(page: String, title: String, icon_path: String) -> Button:
	var b := Button.new()
	b.name = "Go_" + page
	b.text = ""
	b.tooltip_text = title
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(238, 66)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.35)
	box.border_color = Color(0.32, 0.29, 0.25, 0.9)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.5, 0.36, 0.08, 0.5)
	hover.border_color = UiKit.GOLD
	hover.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(open_page.bind(page))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var pic := EntryIcon.new()
	pic.page = page
	pic.icon_path = icon_path
	pic.custom_minimum_size = Vector2(48, 48)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(UiKit.label(title, 18, UiKit.GOLD, true))
	var sub := UiKit.label("", 13, UiKit.TEXT)
	sub.name = "Sub"
	words.add_child(sub)
	row.add_child(words)
	b.add_child(row)
	_entries[page] = b
	return b


func _refresh() -> void:
	UiKit.set_purse(_purse, Profile.gold)
	var kinds := 0
	for id in FishData.FISH:
		if Profile.fish_log.has(FishData.FISH[id].name):
			kinds += 1
	(_nameplate.get_node("Logged") as Label).text = "圖鑑 %d / %d" % [kinds, FishData.FISH.size()]
	var things := 0
	for id in Profile.storage:
		things += Profile.stored(id)
	_set_sub("warehouse", "倉庫裡 %d 件" % things)
	var light := "手電筒" if Profile.has_flashlight else "煤燈"
	_set_sub("equipment", "%s・%s" % [Profile.rod().name, light])
	_set_sub("fish_tank", "%d / %d 條魚" % [Profile.tank.size(), Profile.TANK_SIZE])
	_set_sub("shop", "釣具、魚餌、升級")


func _set_sub(page: String, text: String) -> void:
	var b: Button = _entries.get(page)
	if b != null:
		(b.find_child("Sub", true, false) as Label).text = text


## The character's head (world), standing or sat.
func _head_point() -> Vector3:
	var rig := _stage.character
	var bone := rig.skeleton.find_bone("Head") if rig.skeleton != null else -1
	if bone < 0:
		return _stage.character_pivot.global_position + Vector3(0, 1.55, 0)
	return (rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(bone)).origin


func _process(_delta: float) -> void:
	# The name floats over the character's head; the lit thing's over it.
	# Resting at the camp (3D or not).
	Profile.rest(_delta)
	if _stage != null and _home.visible:
		var head := _head_point() + Vector3(0, 0.5, 0)
		if not _stage.camera.is_position_behind(head):
			var at := _stage.camera.unproject_position(head) / RENDER_SCALE
			_nameplate.position = at - Vector2(_nameplate.size.x * 0.5, _nameplate.size.y)
		if _spot != "":
			var over := _stage.camera.unproject_position(_stage.label_point(_spot)) / RENDER_SCALE
			_spot_label.position = over - Vector2(_spot_label.size.x * 0.5, _spot_label.size.y)


## The camp's thing at `at` (screen), "" if none.
func spot_at(at: Vector2) -> String:
	return _stage.hotspot_at(at * RENDER_SCALE) if _stage != null else ""


func _light(page: String) -> void:
	_spot = page
	if _stage != null:
		_stage.highlight(page)
	_spot_label.visible = page != ""
	if page != "":
		_spot_label.text = _stage.hotspots[page].label


## A press on one of the camp's things lights it; let go on it, it opens.
## Elsewhere, drags turn the character and a tap on it waves.
func _on_home_input(event: InputEvent) -> void:
	if _scene_piece != "":
		# Setting out or coming home: a tap skips it.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_stage.life.finish()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = true
			_drag_moved = 0.0
			# The character itself before what's behind it.
			_press_spot = "" if _near_character(event.position) else spot_at(event.position)
			_light(_press_spot)
		else:
			_drag = false
			var under := spot_at(event.position)
			if _press_spot != "" and under == _press_spot and _drag_moved < 12.0:
				var page := _press_spot
				_press_spot = ""
				_light("")
				open_page(page)
				return
			_press_spot = ""
			_light(under)
			if _drag_moved < 6.0 and _near_character(event.position):
				_wave()
	elif event is InputEventMouseMotion:
		if _drag:
			_drag_moved += absf(event.relative.x) + absf(event.relative.y)
			if _press_spot == "" and _stage != null:
				_stage.turn_character(event.relative.x * 0.012)
		else:
			# Hovered (a mouse): lit, named.
			_light(spot_at(event.position))


## On the character: between its feet and its head, about its width.
func _near_character(at: Vector2) -> bool:
	if _stage == null:
		return false
	var feet := _stage.camera.unproject_position(_stage.character_pivot.global_position) / RENDER_SCALE
	var head := _stage.camera.unproject_position(_head_point() + Vector3(0, 0.15, 0)) / RENDER_SCALE
	var tall := maxf(feet.y - head.y, 40.0)
	var r := Rect2(Vector2((feet.x + head.x) * 0.5 - tall * 0.22, head.y), Vector2(tall * 0.44, tall))
	return r.has_point(at)


func _wave() -> void:
	if _stage != null:
		_stage.life.tap()
	elif _viewer != null:
		_viewer.wave()


## Opens a menu page over the camp: the list goes, the camera glides to the
## page's spot, the page fades in; the camp holds still under it (one
## frame drawn - cheaper on a phone) till it closes.
func open_page(page: String) -> void:
	if _page != null:
		_page.queue_free()
		_page = null
	_home.visible = false
	_light("")
	Sfx.play("ui_open", -6.0)
	var p: Control = load("res://scenes/%s.tscn" % page).instantiate()
	p.set_meta("over_camp", _stage != null)
	p.set_meta("camp", self)
	p.modulate.a = 0.0
	_page = p
	add_child(p)
	if _stage != null:
		_stage.life.hold(true)
		_live(true)
		_stage.go_to(page, true, func(): _live(false))
	var t := p.create_tween()
	t.tween_interval(0.35 if _stage != null else 0.0)
	t.tween_property(p, "modulate:a", 1.0, 0.25)


## Back from a page to the camp.
func close_page() -> void:
	if _page != null:
		_page.queue_free()
		_page = null
		Sfx.play("ui_close", -8.0)
	_home.visible = true
	_refresh()
	if _stage != null:
		_stage.life.hold(false)
		_live(true)
		_stage.go_to("home")


func _live(on: bool) -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_ONCE


func _exit_tree() -> void:
	Engine.max_fps = 0


func _on_solo() -> void:
	if _stage == null or _scene_piece != "":
		_start_run()
		return
	# User request: it sets out - the lamp from the drum, the rod from by
	# the tent, into the 渡石.
	_scene_piece = "depart"
	_light("")
	for n in ["Play", "Multiplayer", "Settings", "Nameplate"]:
		var c := _home.get_node_or_null(n)
		if c != null:
			c.visible = false
	_skip_hint.visible = true
	_stage.life.plan_done.connect(_on_piece_done)
	_stage.life.depart()


func _on_piece_done(tag: String) -> void:
	if tag == "depart":
		_start_run()
		return
	_scene_piece = ""
	_skip_hint.visible = false


## Into the run: the 渡石's light fills the screen, then the run starts.
func _start_run() -> void:
	if _setting_off:
		return
	_setting_off = true
	if _stage != null:
		_stage.stone_flare()
	_fade.color = Color(0.75, 0.92, 1.0, 0.0)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.45)
	t.tween_callback(func():
		Profile.leave_camp()
		GameState.start_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))


## Back from a run (GameState.last_return): out of the stone's light, or
## waking by the fire (out of the dark).
func _come_home(how: String) -> void:
	_scene_piece = how
	_skip_hint.visible = true
	_stage.life.plan_done.connect(_on_piece_done)
	_stage.life.come_home(how)
	_fade.color = Color(0, 0, 0, 1) if how == "lost" else Color(0.75, 0.92, 1.0, 0.9)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2 if how == "lost" else 0.6)


func _on_multiplayer() -> void:
	MenuStyle.notice(self, "多人連線", ["正在開發中，敬請期待！",
		"規劃：和朋友組隊夜釣、一起湊獻祭額度、互相照亮躲避鬼魂，也能比賽誰的漁獲最值錢。"])


func _on_shop() -> void:
	open_page("shop")


func _on_equipment() -> void:
	open_page("equipment")


## User request: game settings.
func _on_settings() -> void:
	var note := MenuStyle.notice(self, "設定", ["調整遊戲中的輔助功能與畫面。"])
	note.name = "SettingsPanel"
	var col: VBoxContainer = note.get_child(0).get_child(0)
	var auto := CheckButton.new()
	auto.name = "AutoLure"
	auto.text = "丟出誘餌後，自動選最便宜的魚當下一個誘餌"
	auto.button_pressed = Profile.settings.get("auto_lure", false)
	auto.add_theme_font_size_override("font_size", 15)
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(on): Profile.set_setting("auto_lure", on))
	col.add_child(auto)
	col.move_child(auto, col.get_child_count() - 2)
	var camp := CheckButton.new()
	camp.name = "Camp3D"
	camp.text = "主畫面的 3D 營地（關掉比較省電）"
	camp.button_pressed = camp_on()
	camp.add_theme_font_size_override("font_size", 15)
	camp.focus_mode = Control.FOCUS_NONE
	camp.toggled.connect(func(on):
		Profile.set_setting("camp_3d", on)
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	col.add_child(camp)
	col.move_child(camp, col.get_child_count() - 2)


func _go(page: String) -> void:
	open_page(page)


func _on_fish_log() -> void:
	open_page("fish_log")


## A round button with a gear drawn on it (the settings), in gold.
class GearButton extends Button:
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_circle(c, r, Color(0.07, 0.065, 0.06, 0.92))
		draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(0.62, 0.46, 0.17), 3.0)
		draw_arc(c, r - 0.5, 0.0, TAU, 40, Color(0, 0, 0), 1.0)
		var ink := UiKit.GOLD_BRIGHT if is_hovered() or button_pressed else UiKit.GOLD
		# Teeth, ring, hole.
		var teeth := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			var rr := r * (0.62 if i % 2 == 0 else 0.48)
			teeth.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(teeth, ink)
		draw_circle(c, r * 0.4, ink)
		draw_circle(c, r * 0.18, Color(0.07, 0.065, 0.06))


## An entry's picture: its page's thing in a slot (the rod worn for 裝備,
## a fish from the tank for 魚缸).
class EntryIcon extends Control:
	var page := ""
	var icon_path := ""
	## Held here: a texture loaded only inside _draw is freed before the
	## frame's drawn (and shows white).
	var _tex: Texture2D

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match page:
			"equipment":
				var id := "rod_%d" % Profile.rod_tier
				ItemBoard.draw_item(self, r, id, 1, null)
				return
			"fish_tank":
				var fish: Dictionary = Profile.tank[0] if not Profile.tank.is_empty() else {"id": "carp", "name": "鯉魚"}
				UiKit.draw_slot(self, r, UiKit.fish_rarity(fish))
				var ft := FishData.icon(fish.get("id", ""), fish.get("name", ""))
				_pic(r, ft)
				return
		if _tex == null and icon_path != "":
			_tex = load(icon_path)
		# A square icon fills the slot.
		var square := _tex != null and _tex.get_width() == _tex.get_height()
		UiKit.draw_slot(self, r, "", false, _tex if square else null)
		if not square:
			_pic(r, _tex)

	func _pic(r: Rect2, tex: Texture2D) -> void:
		if tex == null:
			return
		var room := r.grow(-6.0)
		var k := minf(room.size.x / tex.get_width(), room.size.y / tex.get_height())
		var sz := Vector2(tex.get_size()) * k
		draw_texture_rect(tex, Rect2(room.get_center() - sz / 2.0, sz), false)
