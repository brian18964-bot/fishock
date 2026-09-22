extends Control

@onready var gold_label: Label = $GoldLabel
@onready var rows_container: VBoxContainer = $RowsContainer
@onready var back_button: Button = $BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	Profile.gold_updated.connect(_on_profile_changed)
	Profile.profile_changed.connect(_on_profile_changed)
	_refresh_gold()
	_rebuild_rows()


func _on_profile_changed(_arg = null) -> void:
	_refresh_gold()
	_rebuild_rows()


func _refresh_gold() -> void:
	gold_label.text = "金幣：%d" % Profile.gold


func _rebuild_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()

	for key in Profile.UPGRADE_DEFS.keys():
		rows_container.add_child(_make_upgrade_row(key))

	rows_container.add_child(_make_lure_row())


func _make_upgrade_row(key: String) -> Control:
	var def: Dictionary = Profile.UPGRADE_DEFS[key]
	var level: int = Profile.get_upgrade_level(key)
	var max_level: int = def.max_level
	var maxed: bool = level >= max_level
	var next_cost: int = 0
	if not maxed:
		next_cost = def.costs[level]

	var row := HBoxContainer.new()

	var label := Label.new()
	if maxed:
		label.text = "%s：Lv.%d/%d（已滿級）" % [def.label, level, max_level]
	else:
		label.text = "%s：Lv.%d/%d（升級需要 %d 金幣）" % [def.label, level, max_level, next_cost]
	label.custom_minimum_size = Vector2(440, 32)
	row.add_child(label)

	var button := Button.new()
	button.text = "升級"
	button.custom_minimum_size = Vector2(80, 32)
	button.disabled = maxed or Profile.gold < next_cost
	button.pressed.connect(func(): _buy_upgrade(key))
	row.add_child(button)

	return row


func _make_lure_row() -> Control:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = "假餌（下輪庫存 %d，賽前備貨）：每個 %d 金幣" % [Profile.loadout_lures, Profile.LURE_COST]
	label.custom_minimum_size = Vector2(440, 32)
	row.add_child(label)

	var button := Button.new()
	button.text = "購買"
	button.custom_minimum_size = Vector2(80, 32)
	button.disabled = Profile.gold < Profile.LURE_COST
	button.pressed.connect(_buy_lure)
	row.add_child(button)

	return row


func _buy_upgrade(key: String) -> void:
	Profile.buy_upgrade(key)


func _buy_lure() -> void:
	Profile.buy_lure()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
