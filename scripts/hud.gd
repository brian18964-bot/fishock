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
@onready var inventory_label: Label = $Panel/InventoryLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var progress_bar: ProgressBar = $Panel/ProgressBar
@onready var tension_bar: ProgressBar = $Panel/TensionBar
@onready var fuel_bar: ProgressBar = $Panel/FuelBar
@onready var phase_label: Label = $Panel/PhaseLabel
@onready var evil_label: Label = $Panel/EvilLabel
@onready var offering_label: Label = $Panel/OfferingLabel
@onready var run_end_label: Label = $Panel/RunEndLabel
@onready var time_label: Label = $Panel/TimeLabel

const PHASE_TEXT := {
	"FISHING": "階段：白天釣魚中",
	"ESCAPE": "階段：額度已滿！可逃離或繼續賭供品",
	"DONE": "階段：本輪結束",
}

var _message_timer: float = 0.0
var _lantern: Lantern


func _ready() -> void:
	var player := get_tree().current_scene.get_node("Player")
	player.state_changed.connect(_on_state_changed)
	player.reel_progress.connect(_on_reel_progress)
	GameState.quota_updated.connect(_on_quota_updated)
	GameState.inventory_updated.connect(_on_inventory_updated)
	GameState.message_posted.connect(_on_message)
	GameState.day_phase_changed.connect(_on_day_phase_changed)
	GameState.offering_pool_updated.connect(_on_offering_pool_updated)
	GameState.run_ended.connect(_on_run_ended)
	GameState.night_fell.connect(_on_night_fell)
	_on_quota_updated(GameState.quota_progress, GameState.quota_target)
	_on_inventory_updated(GameState.carried_fish)
	_on_state_changed("IDLE")
	_on_offering_pool_updated(GameState.offering_pool, GameState.evil_count)

	_lantern = player.get_node("Lantern")
	fuel_bar.max_value = _lantern.MAX_FUEL
	fuel_bar.value = _lantern.fuel


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""
	fuel_bar.value = _lantern.fuel

	if GameState.is_night or GameState.day_phase != GameState.DayPhase.FISHING:
		time_label.text = ""
	else:
		var total: int = int(GameState.time_remaining)
		time_label.text = "剩餘時間：%02d:%02d" % [total / 60, total % 60]


func _on_state_changed(new_state: String) -> void:
	state_label.text = "狀態：%s" % STATE_TEXT.get(new_state, new_state)
	var reeling := new_state == "REELING"
	progress_bar.visible = reeling
	tension_bar.visible = reeling


func _on_reel_progress(progress: float, tension: float) -> void:
	progress_bar.value = progress
	tension_bar.value = tension


func _on_quota_updated(progress: float, target: float) -> void:
	quota_label.text = "獻祭額度：%.0f / %.0f" % [progress, target]


func _on_inventory_updated(carried: Array) -> void:
	inventory_label.text = "隨身漁獲：%d 條" % carried.size()


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


func _on_run_ended(_success: bool, message: String) -> void:
	run_end_label.text = message
	run_end_label.visible = true


func _on_night_fell() -> void:
	phase_label.text = "階段：☠ 夜晚降臨！鬼已進入獵殺模式"


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
