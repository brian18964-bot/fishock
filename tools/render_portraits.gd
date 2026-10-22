extends SceneTree

## The status card's faces (assets/ui/portraits/<id>.png, CharacterArt
## .portrait_texture): each character's head and shoulders off its 3D model,
## at the first frame of its idle, turned a little to its left, on a clear
## background.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 200x112 \
##     -s "$PWD/tools/render_portraits.gd" -- id [id ...]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/portrait_maker.gd") as GDScript).new())
