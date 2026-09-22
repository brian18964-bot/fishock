extends Control

## User feedback: a long-term goal beyond gold/upgrades - a read-only log
## of every fish ever caught (name, times caught, best value), persisted
## via Profile.fish_log (see Profile.record_catch(), called from
## Player._succeed_catch()).

@onready var rows_container: VBoxContainer = $ScrollContainer/RowsContainer
@onready var back_button: Button = $BackButton
@onready var empty_label: Label = $EmptyLabel


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_rebuild_rows()


func _rebuild_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()

	var names := Profile.fish_log.keys()
	names.sort()
	empty_label.visible = names.is_empty()

	for fish_name in names:
		rows_container.add_child(_make_row(fish_name))


func _make_row(fish_name: String) -> Control:
	var entry: Dictionary = Profile.fish_log[fish_name]
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = "%s：釣過 %d 次，最高價值 %.0f" % [fish_name, int(entry.count), float(entry.best_value)]
	label.custom_minimum_size = Vector2(600, 32)
	row.add_child(label)

	return row


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
