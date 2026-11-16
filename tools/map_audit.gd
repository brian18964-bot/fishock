extends SceneTree
## Every map gone over for places to get stuck (tests/map_audit.gd): the free nights' maps over
## many seeds (each seed its own layout, the three themes in turn), and the campaign's levels.
##
##   godot --headless --fixed-fps 60 --path . -s "$PWD/tools/map_audit.gd" -- [seeds=24] [levels=1]
## (the work's in map_audit_work.gd, loaded once the game's autoloads are up)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/map_audit_work.gd") as GDScript).new())
