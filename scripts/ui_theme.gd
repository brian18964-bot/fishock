extends Node

## Puts the UI kit's theme (UiKit.make_theme) on the root window before any
## screen is built, so every control - menus, the HUD, dialogs - wears it.


func _enter_tree() -> void:
	UiKit.install_theme(get_tree().root)
