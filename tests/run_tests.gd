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
	var scenarios: GDScript = load("res://tests/scenarios.gd")
	if scenarios == null or not scenarios.can_instantiate():
		# A script error: fail rather than hang (CI would wait forever).
		printerr("tests/scenarios.gd failed to compile")
		quit(1)
		return
	root.add_child(scenarios.new())
