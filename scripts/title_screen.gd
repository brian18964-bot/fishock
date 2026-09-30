extends Control

## The main screen. User request: like a mobile game's - the player's own
## character in 3D, front on (it'll be dressed up later, a paper doll),
## the shop, the character's equipment, single player and multiplayer.
##   left:    the character (CharacterViewer) on its stone, drag to turn,
##            tap to wave
##   top:     the player's card (name, fish logged) and gold
##   right:   單機模式 (a run) and 多人連線 (not yet - says so)
##   bottom:  商城, 倉庫, 裝備, 魚缸, 圖鑑
## Between runs, so the day timer is stopped here (GameState.reset_run).

const BG_TOP := Color(0.035, 0.045, 0.08)
const BG_BOTTOM := Color(0.09, 0.07, 0.06)

var _gold: Label
var _viewer: CharacterViewer


func _ready() -> void:
	GameState.reset_run()
	_build()
	Profile.gold_updated.connect(func(_g): _refresh())
	Profile.profile_changed.connect(_refresh)
	_refresh()
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
	var go := MenuStyle.button("去魚缸看看", 16, true)
	go.pressed.connect(_go.bind("fish_tank"))
	note.get_child(0).get_child(0).add_child(go)


func _build() -> void:
	# The night sky behind everything: a gradient, a moon's glow, drifting motes.
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP)
	grad.set_color(1, BG_BOTTOM)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	var moon := TextureRect.new()
	moon.texture = LightTextureFactory.make_radial_texture(256, 0.6)
	moon.modulate = Color(0.55, 0.65, 0.9, 0.35)
	moon.position = Vector2(470, -120)
	moon.size = Vector2(420, 420)
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(moon)
	var motes := CPUParticles2D.new()
	motes.amount = 26
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(480, 270)
	motes.position = Vector2(480, 270)
	motes.gravity = Vector2(0, -4)
	motes.initial_velocity_min = 2.0
	motes.initial_velocity_max = 8.0
	motes.direction = Vector2.UP
	motes.spread = 60.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.5
	var mc := Gradient.new()
	mc.set_color(0, Color(0.8, 1.0, 0.5, 0.0))
	mc.set_color(1, Color(0.8, 1.0, 0.5, 0.0))
	mc.add_point(0.5, Color(0.85, 1.0, 0.55, 0.8))
	motes.color_ramp = mc
	add_child(motes)

	# The character, standing left of centre.
	_viewer = CharacterViewer.new()
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.frame_x = -0.32
	add_child(_viewer)

	# Title.
	var title := MenuStyle.label("黑暗釣魚", 40, MenuStyle.GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.position = Vector2(560, 34)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var sub := MenuStyle.label("在黑夜裡釣魚，別被牠們發現", 14, MenuStyle.DIM)
	sub.position = Vector2(566, 90)
	add_child(sub)

	# Top left: the player's card.
	var card := MenuStyle.panel()
	card.position = Vector2(16, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(46, 46)
	avatar.add_theme_stylebox_override("panel", MenuStyle.box(CharacterViewer.SKIN.darkened(0.3), MenuStyle.GOLD, 23, 2))
	row.add_child(avatar)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.add_child(MenuStyle.label("釣客", 18))
	var logged := MenuStyle.label("", 12, MenuStyle.DIM)
	logged.name = "Logged"
	who.add_child(logged)
	row.add_child(who)
	card.add_child(row)
	add_child(card)

	# Top right: gold.
	var purse := MenuStyle.panel()
	purse.position = Vector2(800, 14)
	purse.custom_minimum_size = Vector2(140, 0)
	_gold = MenuStyle.label("", 18, MenuStyle.GOLD)
	purse.add_child(_gold)
	add_child(purse)

	# Right: play.
	var play := VBoxContainer.new()
	play.position = Vector2(600, 190)
	play.add_theme_constant_override("separation", 14)
	var solo := MenuStyle.button("單機模式", 28, true)
	solo.custom_minimum_size = Vector2(300, 84)
	solo.pressed.connect(_on_solo)
	play.add_child(solo)
	var multi := MenuStyle.button("多人連線", 22)
	multi.custom_minimum_size = Vector2(300, 60)
	multi.pressed.connect(_on_multiplayer)
	play.add_child(multi)
	var soon := MenuStyle.label("即將開放", 12, Color(0.6, 0.85, 1.0))
	soon.position = Vector2(222, 6)
	multi.add_child(soon)
	add_child(play)

	# Bottom: shop, equipment, fish log.
	var bar := HBoxContainer.new()
	bar.position = Vector2(452, 438)
	bar.add_theme_constant_override("separation", 8)
	for entry in [["商城", _on_shop], ["倉庫", _go.bind("warehouse")], ["裝備", _on_equipment],
			["魚缸", _go.bind("fish_tank")], ["圖鑑", _on_fish_log]]:
		var b := MenuStyle.button(entry[0], 18)
		b.custom_minimum_size = Vector2(92, 72)
		b.pressed.connect(entry[1])
		bar.add_child(b)
	add_child(bar)

	var hint := MenuStyle.label("拖曳角色可以轉動，點一下會打招呼", 12, Color(1, 1, 1, 0.4))
	hint.position = Vector2(92, 506)
	add_child(hint)


func _refresh() -> void:
	_gold.text = "金幣  %d" % Profile.gold
	var logged: Label = find_child("Logged", true, false)
	if logged != null:
		var kinds := 0
		for id in FishData.FISH:
			if Profile.fish_log.has(FishData.FISH[id].name):
				kinds += 1
		logged.text = "圖鑑 %d/%d・%s" % [kinds, FishData.FISH.size(), Profile.rod().name]


func _on_solo() -> void:
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_multiplayer() -> void:
	MenuStyle.notice(self, "多人連線", ["正在開發中，敬請期待！",
		"規劃：和朋友組隊夜釣、一起湊獻祭額度、互相照亮躲避鬼魂，也能比賽誰的漁獲最值錢。"])


func _on_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_equipment() -> void:
	get_tree().change_scene_to_file("res://scenes/equipment.tscn")


func _go(page: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % page)


func _on_fish_log() -> void:
	get_tree().change_scene_to_file("res://scenes/fish_log.tscn")
