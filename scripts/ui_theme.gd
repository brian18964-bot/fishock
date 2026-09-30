extends Node

## Puts the UI kit's theme (UiKit.make_theme) on the root window before any
## screen is built, so every control - menus, the HUD, dialogs - wears it.
## Controls under a CanvasLayer (the HUD, the bag, dialogs) don't inherit
## the window's theme, so each top control added there gets it too.

var _theme: Theme


func _enter_tree() -> void:
	_theme = UiKit.make_theme()
	get_tree().root.theme = _theme
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Control and (node as Control).theme == null:
		var parent := node.get_parent()
		if parent != null and not parent is Control and not parent is Window:
			(node as Control).theme = _theme
