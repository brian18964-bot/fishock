extends SceneTree
## The levels' verification tools (written while the maps' branches were checked over):
##   OUT=dir godot --headless --fixed-fps 60 -s res://tools/verify/verify.gd -- tool=bot [LEVELS=1-1,2-3 as env]
## tool=
##   bot        a bot plays each level with the game's own casting, strikes, fights, offerings and
##              escape (bot_work.gd) -> OUT/bot.tsv: outcome, time used of the day, quota, catches,
##              the branch's own fish caught, the fights' arrows seen (none before the 反甩 lesson),
##              why fights were lost (gate = too strong for the stats), the tutorial's step reached
##   play       all 26 levels cleared in order with the developer's all-open off: each opens only
##              on its turn, ★/★★, the first clear's rewards, the next map after the whole of one
##              (play_work.gd) -> OUT/play.tsv
##   catch_sim  each level's catches rolled as Player rolls them, 20000 casts: how often the
##              branch's own fish, catches to even odds (catch_sim_work.gd) -> OUT/catch_sim.tsv
##   shots      every level drawn by the real renderer: the game camera at the nearest water in the
##              level's own weather, and from high over the map (shots_work.gd) - needs a display:
##              xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 ...
##              then tools/verify/sheet.py OUT lv_ sheet.png OUT/catch_sim.tsv 4 (contact sheets)
## The weathers' odds per level: tools/verify/weather_odds.py (no Godot).


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var tool := "bot"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tool="):
			tool = a.substr(5)
	var script := load("res://tools/verify/%s_work.gd" % tool) as GDScript
	if script == null or not script.can_instantiate():
		printerr("no such verification tool: %s" % tool)
		quit(1)
		return
	root.add_child(script.new())
