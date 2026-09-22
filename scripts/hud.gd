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

var _message_timer: float = 0.0
var _lantern: Lantern


func _ready() -> void:
	var player := get_tree().current_scene.get_node("Player")
	player.state_changed.connect(_on_state_changed)
	player.reel_progress.connect(_on_reel_progress)
	GameState.quota_updated.connect(_on_quota_updated)
	GameState.inventory_updated.connect(_on_inventory_updated)
	GameState.message_posted.connect(_on_message)
	_on_quota_updated(GameState.quota_progress, GameState.quota_target)
	_on_inventory_updated(GameState.carried_fish)
	_on_state_changed("IDLE")

	_lantern = player.get_node("Lantern")
	fuel_bar.max_value = _lantern.MAX_FUEL
	fuel_bar.value = _lantern.fuel


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""
	fuel_bar.value = _lantern.fuel


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
