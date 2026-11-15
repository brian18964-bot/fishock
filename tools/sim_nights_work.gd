extends "res://tests/scenarios.gd"
## tools/sim_nights.gd's work: see there.

## Another blow this soon after the last one wore off (s) counts as the same run of them.
const CHAIN_GAP := 2.0
## How long past nightfall the angler stays (s).
const AFTER_DARK := 90.0


func _run() -> void:
	var themes := ["forest_pine", "snow_pine", "autumn"]
	var seeds := 2
	var out := "/tmp/sim_nights.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("themes="):
			themes = Array(a.substr(7).split(","))
		elif a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("out="):
			out = a.substr(4)
	var nights := []
	for theme in themes:
		for s in seeds:
			var night := await _night(theme, 11 + s * 7)
			nights.append(night)
			print("NIGHT %-8s seed %d: %3.0f s, %d casts %d landed | frightened %d (%.1f s) muddled %d (%.1f s) | before dark %s | longest run of them %d blows %.1f s | %s | %s" % [
				theme if theme != "" else "forest", night.seed, night.seconds, night.casts, night.landed, night.fear, night.fear_s,
				night.confuse, night.confuse_s, night.by_dark, night.chain, night.chain_s, night.end, night.by])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(nights, "\t"))
	f.close()
	get_tree().quit()


func _night(theme: String, seed_n: int) -> Dictionary:
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	seed(seed_n)
	camp().clear()
	gs.reset_run()
	gs.last_return = ""
	camp().begin_free([], theme)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	for _i in 600:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	await frames(120)
	var p := player()
	p.bait_count = 99
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var spot: Vector2 = zone.shore_point(Vector2.DOWN) + Vector2(0, 60)
	await put(spot)
	var night := {"theme": theme, "seed": seed_n, "seconds": 0.0, "casts": 0, "landed": 0, "fear": 0, "fear_s": 0.0,
		"confuse": 0, "confuse_s": 0.0, "chain": 0, "chain_s": 0.0, "by": {}, "by_dark": {}, "end": "stayed %d s into the hunt" % int(AFTER_DARK)}
	var was_fear := 0.0
	var was_confuse := 0.0
	var clear_for := 99.0
	var chain := 0
	var chain_s := 0.0
	var t := 0.0
	var dt := 1.0 / 60.0
	var landed_before: int = gs.run_catches.size()
	var dark_at := -1.0
	while t < 600.0:
		if gs.run_over:
			night.end = "died or left"
			break
		# (on past nightfall a while: the hunt's when the ghosts and the dragon come)
		if gs.is_night:
			if dark_at < 0.0:
				dark_at = t
				night.by_dark = {"fear": night.fear, "confuse": night.confuse}
			if t - dark_at > AFTER_DARK:
				break
		# The angler: cast, strike, fight; back to the water's edge when idle.
		match p.state:
			Player.State.IDLE:
				key(KEY_SPACE, false)
				key(KEY_SHIFT, false)
				if p.fear_timer <= 0.0 and p.water_ghost_timer <= 0.0 and p.move_left <= 0.0:
					if p.global_position.distance_to(spot) > 40.0:
						p.global_position = spot
					p.aim_dir = Vector2.UP
					p.charge_time = p.MAX_CHARGE_TIME * 0.5
					p._launch_cast()
					night.casts += 1
			Player.State.BITE:
				key(KEY_SPACE, true)
			Player.State.REELING:
				var f: FishFight = p.fight
				if f != null:
					var s: TouchJoystick = p._move_joystick
					if f.prompt_active() and f.answer_left < f.swipe_window() - 0.5:
						s.output = FightPanel.to_frame(f.prompt_dir())
						s.is_pressed = true
					else:
						s.output = Vector2.ZERO
						s.is_pressed = false
					var reel := f.opening_left <= 0.0 and f.cur_move == "" and f.tension < 0.55 and f.mood() != "jump"
					key(KEY_SPACE, reel or f.opening_left > 0.0)
					key(KEY_SHIFT, reel)
			_:
				key(KEY_SPACE, false)
				key(KEY_SHIFT, false)
		await frames(1)
		t += dt
		# What's on it now.
		var fear: float = p.fear_timer
		var confuse: float = p.water_ghost_timer
		var hit := false
		if fear > was_fear + 0.05:
			night.fear += 1
			night.by[p.fear_text] = int(night.by.get(p.fear_text, 0)) + 1
			hit = true
		if confuse > was_confuse + 0.05:
			night.confuse += 1
			night.by[p.affliction_text] = int(night.by.get(p.affliction_text, 0)) + 1
			hit = true
		if fear > 0.0:
			night.fear_s += dt
		elif confuse > 0.0:
			night.confuse_s += dt
		if hit:
			chain = chain + 1 if clear_for < CHAIN_GAP else 1
			if chain == 1:
				chain_s = 0.0
		if fear > 0.0 or confuse > 0.0:
			clear_for = 0.0
			chain_s += dt
		else:
			clear_for += dt
		if chain > night.chain or (chain == night.chain and chain_s > night.chain_s):
			night.chain = chain
			night.chain_s = chain_s
		was_fear = fear
		was_confuse = confuse
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	night.seconds = t
	night.landed = gs.run_catches.size() - landed_before
	return night
