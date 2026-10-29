extends SceneTree

## Launcher for the progression simulator (tools/sim_core.gd): the game's
## autoloads only exist once the tree runs, so the real script is loaded late.
##
##   godot --headless --path . -s tools/sim_progress.gd -- [seeds=N] [out=PATH]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	(load("res://tools/sim_core.gd") as GDScript).new().run(OS.get_cmdline_user_args())
	quit()
