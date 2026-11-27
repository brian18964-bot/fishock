extends SceneTree
## User report ("今天做的地圖我目前都無法測試"): the free night's map cards (DepartChooser.MAPS) for the
## ruined human world's maps - the city, the countryside, the Japanese, English and Chinese villages,
## the adobe village. Each one the game's own night on that map: a free night laid out, the traveller
## put on a shore with the water and the village ahead (the place with the most buildings in view),
## the HUD away, the game's camera as it plays; the picture cut to 16:9 and made 400x225, as the
## first six cards, into assets/ui/depart/map_<theme>.png.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 \\
##       --fixed-fps 60 --path . -s "$PWD/tools/map_cards.gd" [-- THEMES=city,adobe SEED=11]
## (THEMES and SEED may also be given as environment variables; the work's in map_cards_work.gd)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	root.add_child((load("res://tools/map_cards_work.gd") as GDScript).new())
