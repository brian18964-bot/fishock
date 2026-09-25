extends SceneTree

## Automated scenario tests (tests/scenarios.gd), headless and at a fixed
## step so they run as fast as the machine allows:
##
##   godot --headless --fixed-fps 60 -s tests/run_tests.gd [-- only=test_name]
##
## Exits 1 if any check fails - CI runs this before building the web game.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	root.add_child(load("res://tests/scenarios.gd").new())
