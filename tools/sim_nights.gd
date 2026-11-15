extends SceneTree
## Fear and confusion, counted over whole nights (user request: how often a traveller is
## frightened or muddled, and for how long). A bot stands at the water and fishes - casts,
## strikes, fights - from the start of a free night until a minute and a half into the dragon's hunt (or
## it dies); every time it's frightened (can't move) or muddled (steering scrambled) is noted:
## what did it, how long it lasted, and whether another came before it had got clear.
##
##   godot --headless --fixed-fps 60 --path . -s "$PWD/tools/sim_nights.gd" -- [themes=forest_pine,snow_pine,autumn] [seeds=2] [out=/tmp/sim_nights.json]
## (the work's in sim_nights_work.gd, loaded once the game's autoloads are up)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/sim_nights_work.gd") as GDScript).new())
