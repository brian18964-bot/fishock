class_name GripOverlay
extends Control

## User request (Camp v2): caught by the big ghost, the screen closes in -
## darkening, throbbing with the heartbeat - and says what can get you
## loose before the time (BigGhost.GRAB_TIME, a bar running down) is up:
## the strong light (the light button), a fish thrown to it (誘惑), the
## heart (its own button here, when you have one - spent by hand).

var _player: Player
var _shade: TextureRect
var _bar: Control
var _heart: Button
var _hint: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_player = get_tree().current_scene.get_node("Player")
	_shade = UiKit.vignette(1.0)
	_shade.name = "Shade"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var title := UiKit.label("掙脫！", 30, Color(1.0, 0.45, 0.35), true, 6)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(330, 120)
	title.custom_minimum_size = Vector2(300, 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_bar = Bar.new()
	_bar.position = Vector2(355, 166)
	_bar.size = Vector2(250, 14)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_hint = UiKit.label("", 15, UiKit.TEXT, false, 4)
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(230, 188)
	_hint.custom_minimum_size = Vector2(500, 0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_heart = UiKit.button("用心臟掙脫", 18, "red")
	_heart.name = "UseHeart"
	_heart.custom_minimum_size = Vector2(190, 52)
	_heart.position = Vector2(385, 330)
	_heart.pressed.connect(func(): _player.use_heart_to_escape())
	add_child(_heart)


func _process(delta: float) -> void:
	var on: bool = _player.struggling
	visible = on
	if not on:
		_time = 0.0
		return
	_time += delta
	var big := get_tree().current_scene.get_node_or_null("BigGhost")
	var left: float = big.grip_left() if big != null else 0.0
	(_bar as Bar).share = clampf(left / BigGhost.GRAB_TIME, 0.0, 1.0)
	_bar.queue_redraw()
	# The heartbeat: two beats a second, closing in.
	var beat := pow(maxf(sin(_time * TAU * 1.6), 0.0), 6.0)
	_shade.modulate = Color(0.25, 0.0, 0.0, 0.55 + 0.25 * beat + 0.15 * minf(_time, 1.0))
	var ways := ["強光（燈光鍵）"]
	if GameState.lure_index() >= 0:
		ways.append("丟魚（誘惑）")
	if GameState.has_heart:
		ways.append("心臟")
	_hint.text = "　・　".join(ways)
	_heart.visible = GameState.has_heart


class Bar extends Control:
	var share := 1.0

	func _draw() -> void:
		UiKit.draw_bar(self, Rect2(Vector2.ZERO, size), share, Color(1.0, 0.35, 0.25))
