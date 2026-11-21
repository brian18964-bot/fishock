extends SceneTree
## The sandy beach's surf, drawn by the game (scripts/surf.gd): from the shore, obliquely above the
## water's edge, a picture every STEP s - the waves running up the sand and back, their foam, the
## sand wet where they reached and drying - and the sand's wetness picture itself at the end:
##   OUT=dir [SEED=3] [N=16] [STEP=0.5] [H=2.6] [DIST=4.5] xvfb-run godot --rendering-driver opengl3 \\
##       --resolution 1280x720 --fixed-fps 60 -s res://tools/surf_shots.gd


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/surf_shots_work.gd") as GDScript).new())
