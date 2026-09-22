extends Control

@onready var gold_label: Label = $GoldLabel
@onready var start_button: Button = $StartButton
@onready var shop_button: Button = $ShopButton
@onready var fish_log_button: Button = $FishLogButton


func _ready() -> void:
	# Title screen is always a "between runs" state, so this is a safe,
	# unconditional place to make sure the day timer isn't ticking while
	# the player is just sitting here or browsing the shop.
	GameState.reset_run()

	start_button.pressed.connect(_on_start_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	fish_log_button.pressed.connect(_on_fish_log_pressed)
	Profile.gold_updated.connect(_on_gold_updated)
	_refresh_gold()


func _on_gold_updated(_gold: int) -> void:
	_refresh_gold()


func _refresh_gold() -> void:
	gold_label.text = "金幣：%d" % Profile.gold


func _on_start_pressed() -> void:
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_fish_log_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/fish_log.tscn")
