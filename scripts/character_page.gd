class_name CharacterPage
extends Control

## User request: the camp's fire tapped, the camera closes in on it as it
## does on the other things there, and the characters come up to choose
## from - down the left each one's portrait (CharacterArt.portrait_texture,
## in Profile.CHARACTERS' order), on the right the one picked standing
## whole in 3D (CharacterViewer: drag to turn it, tap it and it waves), its
## name over it and 選擇 under it to travel as it - it takes over at the
## fire there and then (TitleScreen.choose_character). On the web one not
## fetched yet (CharacterPacks) is fetched when it's picked, how far along
## shown where it'll stand; chosen only once it's in.

## A portrait's cell in the list (3 across), the portrait in it.
const CELL := Vector2(104, 124)
const FACE := 84.0
const LIST_WIDTH := 362.0

var _purse: PanelContainer
var _viewer: CharacterViewer
## {id: its cell (a Button)}
var _cells := {}
var _picked := ""
var _title: Label
var _choose: Button
var _cover: Control
var _cover_text: Label
## The picked one's ability (its badge, name, what it does) and story.
const INFO_WIDTH := 272.0
var _ability_icon: TextureRect
var _ability_name: Label
var _ability_desc: Label
var _story: Label


func _ready() -> void:
	_build()
	Profile.gold_updated.connect(func(_g): UiKit.set_purse(_purse, Profile.gold))
	UiKit.set_purse(_purse, Profile.gold)
	pick(Profile.character)


func _build() -> void:
	_purse = UiKit.page_chrome(self, _on_back)

	# Left: everyone's portrait, scrolled up and down.
	var made := UiKit.window("選擇角色")
	var left: PanelContainer = made[0]
	var lcol: VBoxContainer = made[1]
	left.name = "ListWindow"
	left.position = Vector2(14, 56)
	left.custom_minimum_size = Vector2(LIST_WIDTH, 474)
	var scroll := DragScroll.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.name = "Faces"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in Profile.CHARACTERS:
		var cell := _cell(c[0], c[1])
		grid.add_child(cell)
		_cells[c[0]] = cell
	scroll.add_child(grid)
	lcol.add_child(scroll)
	add_child(left)

	# Right: the one picked, whole.
	var right_x := LIST_WIDTH + 24.0
	var made2 := UiKit.window("")
	var right: PanelContainer = made2[0]
	var rcol: VBoxContainer = made2[1]
	right.name = "ViewWindow"
	right.position = Vector2(right_x, 56)
	right.custom_minimum_size = Vector2(946.0 - right_x, 474)
	_title = right.find_child("TitleText", true, false)
	var stage := Control.new()
	stage.name = "Stage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	var glow := TextureRect.new()
	glow.texture = UiKit.glow()
	glow.modulate = Color(1.0, 0.62, 0.3, 0.22)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	_viewer = CharacterViewer.new()
	_viewer.name = "Viewer"
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.zoom = 1.3
	_viewer.look_height = 0.9
	_viewer.hold_gear = false
	stage.add_child(_viewer)
	# (one not fetched yet: how far along, where it'll stand)
	_cover = CenterContainer.new()
	_cover.name = "Fetching"
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.visible = false
	_cover_text = UiKit.label("", 18, UiKit.GOLD_BRIGHT, true, 4)
	_cover_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover.add_child(_cover_text)
	stage.add_child(_cover)
	# (user request: each one's ability and story told here - by it, on
	# the right)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	body.add_child(_info_panel())
	rcol.add_child(body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	var hint := UiKit.label("拖曳轉動・點一下打招呼", 14, UiKit.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(hint)
	_choose = UiKit.button("選擇", 18, "red")
	_choose.name = "Choose"
	_choose.custom_minimum_size = Vector2(150, 46)
	_choose.pressed.connect(choose)
	foot.add_child(_choose)
	rcol.add_child(foot)
	add_child(right)
	CharacterPacks.progressed.connect(_on_progress)


func _info_panel() -> Control:
	var col := VBoxContainer.new()
	col.name = "Info"
	col.custom_minimum_size = Vector2(INFO_WIDTH, 0)
	col.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_ability_icon = TextureRect.new()
	_ability_icon.name = "AbilityIcon"
	_ability_icon.custom_minimum_size = Vector2(56, 56)
	_ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_ability_icon)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_child(UiKit.label("角色能力", 12, UiKit.DIM))
	_ability_name = UiKit.label("", 19, UiKit.GOLD_BRIGHT, true)
	_ability_name.name = "AbilityName"
	names.add_child(_ability_name)
	head.add_child(names)
	col.add_child(head)
	_ability_desc = UiKit.label("", 14, UiKit.TEXT)
	_ability_desc.name = "AbilityDesc"
	_ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability_desc.custom_minimum_size = Vector2(INFO_WIDTH, 0)
	col.add_child(_ability_desc)
	var rule := ColorRect.new()
	rule.color = Color(UiKit.GOLD, 0.35)
	rule.custom_minimum_size = Vector2(INFO_WIDTH, 1)
	col.add_child(rule)
	col.add_child(UiKit.label("故事", 14, UiKit.GOLD, true))
	var scroll := DragScroll.new()
	scroll.name = "StoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_story = UiKit.label("", 14, UiKit.DIM)
	_story.name = "Story"
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.custom_minimum_size = Vector2(INFO_WIDTH - 12.0, 0)
	scroll.add_child(_story)
	col.add_child(scroll)
	return col


func _show_info(id: String) -> void:
	var kind := Abilities.kind_of(id)
	var info := Abilities.info(kind)
	_ability_icon.texture = Abilities.icon(kind)
	_ability_name.text = info.get("name", "—")
	_ability_desc.text = info.get("desc", "")
	_story.text = Abilities.story(id)


## A portrait's cell: the portrait in its medallion, the name under it.
func _cell(id: String, name_text: String) -> Button:
	var b := UiKit.button("", 14)
	b.name = "Cell_" + id
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): pick(id))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := UiKit.medallion(CharacterArt.portrait_texture(id), FACE)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(face)
	var label := UiKit.label(name_text, 14, UiKit.TEXT, true)
	label.name = "Name"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)
	b.add_child(col)
	# (the one travelling now)
	var using := UiKit.label("使用中", 12, UiKit.GOLD_BRIGHT, true)
	using.name = "InUse"
	using.position = Vector2(4, 2)
	using.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(using)
	return b


## Shows `id` on the right (fetched first, on the web, if it isn't here).
func pick(id: String) -> void:
	if not _cells.has(id):
		return
	_picked = id
	for k in _cells:
		var cell: Button = _cells[k]
		UiKit.style_tab(cell, k == id)
		cell.get_node("InUse").visible = k == Profile.character
		(cell.find_child("Name", true, false) as Label).add_theme_color_override("font_color",
			UiKit.GOLD_BRIGHT if k == Profile.character else UiKit.TEXT)
	_title.text = Profile.character_name(id)
	_show_info(id)
	if CharacterPacks.has(id):
		_show(id)
	else:
		_viewer.visible = false
		_cover.visible = true
		_cover_text.text = "%s 下載中" % Profile.character_name(id)
		_refresh_choose()
		var got: bool = await CharacterPacks.wait_for(id)
		if not is_inside_tree() or _picked != id:
			return
		if got:
			_show(id)
		else:
			_cover_text.text = "%s 下載失敗\n再點一次重試" % Profile.character_name(id)
	_refresh_choose()


func _show(id: String) -> void:
	_cover.visible = false
	_viewer.visible = true
	_viewer.rig.set_character(id)


func _on_progress(id: String, ratio: float) -> void:
	if id == _picked and _cover.visible:
		_cover_text.text = "%s 下載中 %d%%" % [Profile.character_name(id), roundi(ratio * 100.0)] if ratio > 0.0 \
			else "%s 下載中 %.1f MB" % [Profile.character_name(id), CharacterPacks.downloaded(id) / 1048576.0]


func _refresh_choose() -> void:
	var here := CharacterPacks.has(_picked)
	var same := _picked == Profile.character
	_choose.disabled = same or not here
	_choose.text = "使用中" if same else ("選擇" if here else "下載中")


## Travels as the one picked: it takes over at the fire, the page closes.
func choose() -> void:
	if _picked == "" or _picked == Profile.character or not CharacterPacks.has(_picked):
		return
	var camp: Object = get_meta("camp", null)
	if camp != null and is_instance_valid(camp) and camp.has_method("choose_character"):
		camp.call("choose_character", _picked)
	else:
		Profile.choose_character(_picked)
		UiKit.page_back(self)


func _on_back() -> void:
	UiKit.page_back(self)


func _exit_tree() -> void:
	if CharacterPacks.progressed.is_connected(_on_progress):
		CharacterPacks.progressed.disconnect(_on_progress)
