class_name StatusCard
extends CanvasLayer

## User request: the character's status as a card in a corner - a portrait,
## their name, how fast they're moving and whatever's wrong with them (the
## water ghost's hold, a dizzy spell, carrying the oil drum, caught by the
## big ghost), plus the heart and the fish carried. Tapping it opens the
## backpack (it replaces the backpack button, clearing the controls).
## Top left, where most games keep the player's own status; the right side
## is left to the time, the lamp and the thumbs.
##
## Plain for now: the whole UI is to be redesigned later.

const NAME := "釣客"
const POS := Vector2(10, 8)
const SIZE := Vector2(238, 62)
const PORTRAIT := 50.0
## The portrait: the player sheet's first frame (idle, facing down), head
## and shoulders.
const PORTRAIT_REGION := Rect2(50, 34, 44, 44)
const INK := Color(1.0, 0.96, 0.88)
const DIM := Color(1.0, 0.96, 0.88, 0.7)
const WARN := Color(1.0, 0.55, 0.45)

var _view: Node2D
var _portrait: AtlasTexture
var _font: Font
var _touchscreen := false


func _ready() -> void:
	layer = 4
	_touchscreen = DisplayServer.is_touchscreen_available()
	_font = ThemeDB.fallback_font
	var custom_path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if custom_path != "":
		_font = load(custom_path)
	_portrait = AtlasTexture.new()
	_portrait.atlas = PlayerVisual.SHEET[0]
	_portrait.region = PORTRAIT_REGION
	_view = Node2D.new()
	_view.draw.connect(_draw_card)
	add_child(_view)


func contains(pos: Vector2) -> bool:
	return Rect2(POS, SIZE).has_point(pos)


func _process(_delta: float) -> void:
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _touchscreen:
		pos = event.position
	if pos.x < 0.0 or not contains(pos):
		return
	for c in get_parent().get_children():
		if c is DialogBox and c.is_open():
			return
		if c is Backpack:
			c.toggle()
			get_viewport().set_input_as_handled()
			return


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## How fast the player moves now, as a share of full speed.
static func speed_share(p: Player) -> float:
	var share := Player.carry_speed_ratio(GameState.carried_fish.size())
	if p.water_ghost_timer > 0.0:
		share *= Player.WATER_GHOST_SPEED_MULT
	if p.carrying_oil_drum:
		share *= Player.OIL_DRUM_SPEED_MULT
	return share


## What's wrong (or of note), most pressing first.
static func conditions(p: Player) -> Array:
	var out := []
	if p.held:
		out.append(["被大鬼抓住了", WARN])
	if p.water_ghost_timer > 0.0:
		out.append([p.affliction_text, WARN])
	if p.carrying_oil_drum:
		out.append(["提著油箱", DIM])
	if GameState.has_heart:
		out.append(["❤ 心臟", Color(1.0, 0.5, 0.5)])
	return out


func _draw_card() -> void:
	var p := _player()
	if p == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.04, 0.55)
	box.border_color = Color(1.0, 0.85, 0.55, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	_view.draw_style_box(box, Rect2(POS, SIZE))
	# Portrait in a round frame.
	var c := POS + Vector2(6.0 + PORTRAIT * 0.5, SIZE.y * 0.5)
	_view.draw_circle(c, PORTRAIT * 0.5, Color(0.12, 0.14, 0.16, 0.9))
	_view.draw_texture_rect(_portrait, Rect2(c - Vector2.ONE * PORTRAIT * 0.42, Vector2.ONE * PORTRAIT * 0.84), false)
	_view.draw_arc(c, PORTRAIT * 0.5, 0.0, TAU, 40, Color(1.0, 0.85, 0.55, 0.8), 2.0)
	var x := POS.x + PORTRAIT + 14.0
	var line := x
	_view.draw_string(_font, Vector2(x, POS.y + 20), NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	var hint := "點我開背包" if _touchscreen else "點我開背包（I）"
	_view.draw_string(_font, Vector2(x + 46, POS.y + 20), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.4))
	var share := speed_share(p)
	var speed_ink := INK if share > 0.95 else (DIM if share > 0.7 else WARN)
	_view.draw_string(_font, Vector2(x, POS.y + 38), "移動速度 %d%%　漁獲 %d 條" % [roundi(share * 100.0), GameState.carried_fish.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, speed_ink)
	for cond in conditions(p):
		var w := _font.get_string_size(cond[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if line + w > POS.x + SIZE.x - 4.0:
			break
		_view.draw_string(_font, Vector2(line, POS.y + 55), cond[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cond[1])
		line += w + 8.0
