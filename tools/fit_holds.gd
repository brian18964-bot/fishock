extends SceneTree
## Each character's hold on the rod, fitted to its own body (user report: one way of holding
## it for all of them put a round one's forearm through its chest; and worked out as the game
## ran, by an outline of the body, it couldn't be checked). Run in a night's fishing, one
## character at a time: every place the right hand might hold the rod - across from the
## middle to its shoulder, three heights, three reaches - is tried waiting on a bite and
## reeling, and the forearm and hand checked against the body's real surface (HoldCheck). The
## place nearest the middle that's clear and in reach is kept; then how near the left hand
## comes to the reel's place under the rod, clear of the body. Written to
## assets/sprites/player/<id>/fit.json as `hold` (RunView3D._hold_fit).
##
##   for c in cat owl dog bear deer sheep bear2 dog3 deer2 owl2 croc sheep2; do
##     godot --headless --fixed-fps 60 --path . -s "$PWD/tools/fit_holds.gd" -- $c; done
## (the fitting's in fit_holds_work.gd, loaded once the game's autoloads are up)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/fit_holds_work.gd") as GDScript).new())
