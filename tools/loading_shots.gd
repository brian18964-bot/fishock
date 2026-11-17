extends SceneTree
## The renders behind the loading cards (assets/loading, scripts/main.gd's loading screen):
##   OUT=dir STAGE=y WHAT=dragon xvfb-run godot --rendering-driver opengl3 --resolution 1920x1080 \\
##       --fixed-fps 60 -s res://tools/loading_shots.gd
## (see loading_shots_work.gd for the stages), then tools/loading_cards.py.


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/loading_shots_work.gd") as GDScript).new())
