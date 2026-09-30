extends CanvasLayer

const STATE_TEXT := {
	"IDLE": "待機（移動／蓄力拋竿）",
	"CHARGING": "蓄力中...",
	"WAITING": "等待魚上鉤...",
	"BITE": "咬鉤了！快提竿！",
	"REELING": "收線中（按住收線／放開鬆線）",
}

@onready var state_label: Label = $Panel/StateLabel
@onready var quota_label: Label = $Panel/QuotaLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var fuel_bar: ProgressBar = $Panel/FuelBar
@onready var fuel_label: Label = $Panel/FuelLabel
@onready var phase_label: Label = $Panel/PhaseLabel
@onready var evil_label: Label = $Panel/EvilLabel
@onready var offering_label: Label = $Panel/OfferingLabel
@onready var run_end_label: Label = $Panel/RunEndLabel
@onready var time_label: Label = $Panel/TimeLabel
@onready var gear_label: Label = $Panel/GearLabel
@onready var heart_label: Label = $Panel/HeartLabel
@onready var gold_label: Label = $Panel/GoldLabel
@onready var back_to_title_button: Button = $Panel/BackToTitleButton
@onready var sacrifice_bar: ProgressBar = $Panel/SacrificeBar
@onready var relight_bar: ProgressBar = $Panel/RelightBar
@onready var affliction_label: Label = $Panel/AfflictionLabel
@onready var weather_label: Label = $Panel/WeatherLabel

const WEATHER_TEXT := {
	"CLEAR": "",
	"FOG": "🌫 起霧了（視野變差）",
	"STORM": "⛈ 暴風雨（鬼更活躍、水鬼更常出沒）",
	"FISH_RUN": "🐟 魚汛（上魚率提升）",
}

const PHASE_TEXT := {
	"FISHING": "階段：白天釣魚中",
	"ESCAPE": "階段：額度已滿！可逃離或繼續賭供品",
	"DONE": "階段：本輪結束",
}

var _message_timer: float = 0.0
var _quota_view: QuotaView
var _energy_view: EnergyView
var _sticks: Array = []
var _lantern: Lantern
var _player: Player


func _ready() -> void:
	var player: Player = get_tree().current_scene.get_node("Player")
	_player = player
	player.state_changed.connect(_on_state_changed)
	player.sacrifice_progress_updated.connect(_on_sacrifice_progress_updated)
	GameState.quota_updated.connect(_on_quota_updated)
	GameState.inventory_updated.connect(_on_inventory_updated)
	GameState.message_posted.connect(_on_message)
	GameState.day_phase_changed.connect(_on_day_phase_changed)
	GameState.offering_pool_updated.connect(_on_offering_pool_updated)
	GameState.run_ended.connect(_on_run_ended)
	GameState.night_fell.connect(_on_night_fell)
	GameState.weather_changed.connect(_on_weather_changed)
	_on_weather_changed("CLEAR")
	_on_quota_updated(GameState.quota_progress, GameState.quota_target)
	_on_inventory_updated(GameState.carried_fish)
	_on_state_changed("IDLE")
	_on_offering_pool_updated(GameState.offering_pool, GameState.evil_count)

	_lantern = player.get_node("Lantern")
	_lantern.relight_progress_updated.connect(_on_relight_progress_updated)
	back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	_build_top()


## User request (HUD cleanup): the lists of numbers go - status, quota,
## weather, phase, evil offerings, the offering pool, gold, the fishing
## mode - leaving: the quota as a bar at the top middle with the time left
## under it, and the light's energy (as a percentage) with a brightness
## bar at the top right. The sticks are invisible till touched. Passing
## messages show under the time.
func _build_top() -> void:
	for n in [state_label, quota_label, gear_label, phase_label, evil_label, offering_label, gold_label,
			weather_label, heart_label, affliction_label, time_label, fuel_label, fuel_bar, sacrifice_bar]:
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
	var help := get_node_or_null("Panel/HelpLabel")
	if help != null:
		help.visible = false
	_quota_view = QuotaView.new()
	_quota_view.name = "QuotaView"
	$Panel.add_child(_quota_view)
	_energy_view = EnergyView.new()
	_energy_view.name = "EnergyView"
	_energy_view.lantern = _lantern
	$Panel.add_child(_energy_view)
	# User request: no narrating text lines.
	message_label.visible = false
	message_label.position = Vector2(180, 50)
	message_label.size = Vector2(600, 24)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	message_label.add_theme_constant_override("outline_size", 4)
	relight_bar.position = Vector2(762, 84)
	relight_bar.size = Vector2(190, 8)
	_sticks = [$Panel/MoveJoystick, $Panel/AimJoystick]
	for stick in _sticks:
		stick.modulate.a = 0.0


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""
	# The sticks show (faintly) only while they're held.
	for stick in _sticks:
		var want := 0.55 if stick.is_pressed else 0.0
		stick.modulate.a = move_toward(stick.modulate.a, want, delta * 4.0)
	_quota_view.queue_redraw()
	_energy_view.queue_redraw()
	# The fight panel takes the middle of the top while a fish is on.
	_quota_view.visible = _player.state != Player.State.REELING
	return

	if _lantern.tool == Lantern.Tool.LAMP:
		fuel_bar.max_value = _lantern.max_fuel
		fuel_bar.value = _lantern.fuel
		if DisplayServer.is_touchscreen_available():
			fuel_label.text = "煤燈燃油（已熄滅，長按燈鈕或畫面空白處點燃）" if not _lantern.lit else "煤燈燃油"
		else:
			fuel_label.text = "煤燈燃油（已熄滅，按住 L 點燃）" if not _lantern.lit else "煤燈燃油（L 熄滅）"
	else:
		fuel_bar.max_value = 100.0
		fuel_bar.value = _lantern.charge
		if _lantern.charge <= 0.0:
			var how := "長按燈鈕或畫面空白處換" if DisplayServer.is_touchscreen_available() else "按住 L 換"
			fuel_label.text = "手電筒沒電（電池 %d，%s）" % [Profile.batteries, how]
		else:
			fuel_label.text = "手電筒電量（電池 %d）" % Profile.batteries

	if GameState.is_night or GameState.day_phase != GameState.DayPhase.FISHING:
		time_label.text = ""
	else:
		var total: int = int(GameState.time_remaining)
		time_label.text = "剩餘時間：%02d:%02d" % [total / 60, total % 60]

	if _player.carrying_oil_drum:
		gear_label.text = "提著油箱中，沒辦法釣魚，送去煤油站吧"
	elif _player.fishing_mode == Player.FishingMode.BOBBER:
		gear_label.text = "釣法：浮標（餌 x%d）－背包裡切換" % _player.bait_count
	else:
		gear_label.text = "釣法：路亞 %s－背包裡切換" % _player.lure_label(_player.current_lure)

	heart_label.text = "❤ 已持有心臟" if GameState.has_heart else ""
	affliction_label.text = "⚠ " + _player.affliction_text if _player.water_ghost_timer > 0.0 else ""

	gold_label.text = "金幣：%d（庫存假餌 %d）" % [Profile.gold, Profile.loadout_lure_total()]

	if _player.pending_bait_flavor != "":
		gear_label.text += "（下竿餌料：%s）" % _player.pending_bait_flavor


func _on_state_changed(new_state: String) -> void:
	state_label.text = "狀態：%s" % STATE_TEXT.get(new_state, new_state)


func _on_sacrifice_progress_updated(progress: float) -> void:
	sacrifice_bar.visible = progress > 0.0
	sacrifice_bar.value = progress


func _on_relight_progress_updated(progress: float) -> void:
	relight_bar.visible = progress > 0.0
	relight_bar.value = progress


func _on_quota_updated(progress: float, target: float) -> void:
	quota_label.text = "獻祭額度：%.0f / %.0f" % [progress, target]


func _on_inventory_updated(_carried: Array) -> void:
	pass  # the fish carried and the speed are on the character card now (StatusCard)


func _on_message(text: String) -> void:
	message_label.text = text
	_message_timer = 2.5


func _on_day_phase_changed(phase: String) -> void:
	phase_label.text = PHASE_TEXT.get(phase, phase)


func _on_offering_pool_updated(pool: Array, evil_count: int) -> void:
	evil_label.text = "邪惡供品：%d / 3" % evil_count
	if pool.is_empty():
		offering_label.text = "供品池：尚無供品"
		return
	var text := "供品池："
	for o in pool:
		if o.taken:
			continue
		if o.is_evil:
			text += "[邪惡] "
		else:
			text += "[%s] " % _rarity_label(o.rarity)
	offering_label.text = text


## The run's end (user request: the MMO look): a parchment scroll - how it
## went, what came home - and the way back to the main screen.
func _on_run_ended(success: bool, message: String) -> void:
	run_end_label.text = message
	run_end_label.visible = false
	back_to_title_button.visible = false
	var shade := ColorRect.new()
	shade.name = "RunEnd"
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Panel.add_child(shade)
	var scroll := PanelContainer.new()
	scroll.add_theme_stylebox_override("panel", UiKit.parchment_box())
	scroll.custom_minimum_size = Vector2(520, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var title := UiKit.label("成功逃離" if success else "本輪失敗", 28, Color(0.36, 0.1, 0.04) if success else Color(0.45, 0.06, 0.04), true, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(UiKit.divider(360))
	var body := UiKit.label(message, 17, Color(0.23, 0.14, 0.06), false, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 460
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)
	var home := UiKit.button("回主畫面", 18, "red")
	home.name = "BackHome"
	home.custom_minimum_size = Vector2(200, 48)
	home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home.pressed.connect(_on_back_to_title_pressed)
	col.add_child(home)
	scroll.add_child(col)
	shade.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH


func _on_back_to_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_night_fell() -> void:
	phase_label.text = "階段：☠ 夜晚降臨！鬼已進入獵殺模式"


func _on_weather_changed(weather: String) -> void:
	weather_label.text = WEATHER_TEXT.get(weather, "")


func _rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史詩"
		_:
			return rarity


## The quota, top middle: an ornate bar filling toward the target (gold
## once it's full), the time left (or the phase) under it.
class QuotaView extends Control:
	const W := 300.0
	const H := 20.0
	const FILL := Color(0.78, 0.5, 0.2)
	const FULL := Color(1.0, 0.8, 0.3)

	func _ready() -> void:
		position = Vector2(480.0 - W / 2.0, 6)
		size = Vector2(W, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var share := clampf(GameState.quota_progress / maxf(GameState.quota_target, 1.0), 0.0, 1.0)
		var bar := Rect2(0, 0, W, H)
		UiKit.draw_bar(self, bar, share, FULL if share >= 1.0 else FILL)
		for x in [-2.0, W + 2.0]:
			_gem(Vector2(x, H * 0.5))
		var text := "獻祭  %d / %d" % [int(GameState.quota_progress), int(GameState.quota_target)]
		UiKit.draw_text(self, Vector2(0, 15), text, 13, Color(1, 0.96, 0.86), HORIZONTAL_ALIGNMENT_CENTER, W, true)
		var under := ""
		var col := UiKit.TEXT
		if GameState.is_night:
			under = "夜晚降臨"
			col = UiKit.DANGER
		elif GameState.day_phase == GameState.DayPhase.ESCAPE:
			under = "額度已滿！去發光的符文石柱逃離"
			col = FULL
		elif GameState.day_phase == GameState.DayPhase.FISHING:
			var total: int = int(GameState.time_remaining)
			under = "%02d:%02d" % [total / 60, total % 60]
			if total < 60:
				col = Color(1.0, 0.55, 0.4)
		if under != "":
			UiKit.draw_text(self, Vector2(0, 42), under, 18, col, HORIZONTAL_ALIGNMENT_CENTER, W, true)

	## A small gold diamond capping the bar's end.
	func _gem(c: Vector2) -> void:
		var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)])
		draw_colored_polygon(pts, Color(0.05, 0.03, 0.02))
		var inner := PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)])
		draw_polygon(inner, PackedColorArray([Color(1.0, 0.9, 0.55), Color(0.8, 0.6, 0.2), Color(0.45, 0.3, 0.08), Color(0.8, 0.6, 0.2)]))


## The light, top right (user request): above all, how much fuel is left -
## a big bar with the percentage - and under it, small, how bright the
## light is (its real output: the dimmest setting still gives 35%; drag
## across the panel to turn it up or down). The light dims by itself once
## the fuel's low (Lantern.AUTO_DIM_BELOW); brighter burns faster.
class EnergyView extends Control:
	const W := 200.0
	const BAR := Rect2(14, 28, 172, 18)
	var lantern: Lantern
	var _dragging := false
	var _drag_x := 0.0

	func _ready() -> void:
		position = Vector2(960.0 - W - 8.0, 4)
		size = Vector2(W, 74)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_to_group("hud_block")

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_drag_x = event.position.x
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			if lantern != null and lantern.lit:
				lantern.set_brightness_share(lantern.brightness_share() + (event.position.x - _drag_x) / 120.0)
			_drag_x = event.position.x
			accept_event()

	func _set_from(x: float) -> void:
		if lantern != null and lantern.lit:
			lantern.set_brightness_share((x - BAR.position.x) / BAR.size.x)

	## The light's output as shown: its brightness (0.35..1) as a percentage.
	func output_percent() -> int:
		return roundi(lantern.brightness * 100.0) if lantern.lit else 0

	func _draw() -> void:
		if lantern == null:
			return
		UiKit.frame_box(true).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var ink := UiKit.TEXT
		var low := UiKit.DANGER
		var share := lantern.energy_share()
		var name := "煤燈燃料" if lantern.tool == Lantern.Tool.LAMP else "手電筒電量"
		UiKit.draw_text(self, Vector2(16, 21), name, 13, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		if lantern.tool == Lantern.Tool.FLASHLIGHT:
			UiKit.draw_text(self, Vector2(0, 21), "電池 ×%d" % Profile.batteries, 12, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT, W - 16.0)
		# The fuel: the main thing.
		var col := Color(1.0, 0.68, 0.22)
		if share < Lantern.AUTO_DIM_BELOW:
			col = Color(1.0, 0.45, 0.15) if share >= 0.12 else low
		UiKit.draw_bar(self, BAR, share, col)
		var pct := "%d%%" % roundi(share * 100.0)
		UiKit.draw_text(self, BAR.position + Vector2(0, 14), pct, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, BAR.size.x, true)
		# The light's output, small.
		var out := "熄滅（長按燈鈕點燃）" if not lantern.lit else "亮度 %d%%　←拖曳調整→" % output_percent()
		UiKit.draw_text(self, Vector2(16, 62), out, 12, low if not lantern.lit else UiKit.DIM)
