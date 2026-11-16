extends "res://tests/scenarios.gd"
## tools/map_audit.gd's work: see there.

const Audit := preload("res://tests/map_audit.gd")


func _run() -> void:
	var seeds := 24
	var levels := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("levels="):
			levels = a.substr(7) != "0"
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	var bad := 0
	var maps := 0
	# (the seed lays the map out, the theme only dresses it: each seed its own layout, the
	# themes taken in turn)
	var themes := ["forest_pine", "snow_pine", "autumn"]
	for s in seeds:
		var theme: String = themes[s % themes.size()]
		seed(100 + s * 13)
		camp().clear()
		gs.reset_run()
		gs.last_return = ""
		camp().begin_free([], theme)
		bad += await _check("%s/%d" % [theme, 100 + s * 13])
		maps += 1
	if levels:
		for lv in Campaign.LEVELS:
			reset_progress()
			seed(7)
			camp().begin_level(lv.id)
			gs.last_return = ""
			bad += await _check("level %s" % lv.id)
			maps += 1
	print("AUDIT %d maps, %d with problems" % [maps, bad])
	get_tree().quit()


func _check(tag: String) -> int:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	for _i in 300:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	await frames(4)
	var p := player()
	if p == null:
		print("MAP %s: no traveller" % tag)
		return 1
	var t0 := Time.get_ticks_msec()
	var got: Dictionary = Audit.audit(p, main)
	var walk: Dictionary = Audit.walk_traps(p)
	got.traps = walk.traps
	got.pushed = walk.walked
	var line := "MAP %-18s %6d cells, %4d walked from, %d trap places, %d unreached, %d pockets (%d ms)" % [tag, got.cells, got.pushed,
		got.traps.size(), got.unreached.size(), got.pockets.size(), Time.get_ticks_msec() - t0]
	print(line)
	for t in got.traps.slice(0, 8):
		print("   trap at %s" % str(t))
	for u in got.unreached:
		print("   unreached: %s" % u[0])
	for pk in got.pockets.slice(0, 5):
		print("   pocket of %d cells about %s" % [pk.cells, str(pk.at)])
	return 1 if not got.traps.is_empty() or not got.unreached.is_empty() else 0
