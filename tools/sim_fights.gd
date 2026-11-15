extends SceneTree
## The fights, played out in bulk (user request: bots through many fights of every difficulty
## and size, to find what's too hard or too easy). Every kind of fish the night gives - its
## rarity, its temper, the water it's hooked in (which sets its size) - is fought many times by
## three anglers of different skill at three stages of gear, by the game's own fight
## (FishFight, set up as Player._hook_fish does).
##
##   godot --headless --path . -s "$PWD/tools/sim_fights.gd" -- [n=40] [out=/tmp/sim_fights.json]
## (the work's in sim_fights_work.gd, loaded once the game's autoloads are up)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	(load("res://tools/sim_fights_work.gd") as GDScript).new().run(OS.get_cmdline_user_args())
	quit()
