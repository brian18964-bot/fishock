extends "res://tools/loading_shots_work.gd"
## Verification: every level opened as the game opens it, drawn by the real renderer - from the
## game's own camera at the water nearest the start (the HUD on: the objectives), and from high
## over the map (its size, its waters) - in the level's own weather; what each run holds printed.

func _run() -> void:
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	var only := OS.get_environment("LEVELS")
	for l in camp().LEVELS:
		if only != "" and not str(l.id) in only.split(","):
			continue
		var r: Dictionary = camp().rules_for(l.id)
		print("LEVEL %s BEGIN" % l.id)
		seed(11)
		camp().clear()
		gs.reset_run()
		await play_level(l.id)
		var v: RunView3D = null
		for _i in 600:
			v = RunView3D.active
			if v != null and v.built:
				break
			await frames(1)
		if v == null or not v.built:
			print("INFO %s NOT BUILT" % l.id)
			continue
		# (its own weather, as its plan most often brings it)
		var want := ""
		if r.weather is Dictionary:
			var best := 0.0
			for k in (r.weather as Dictionary):
				if float(r.weather[k]) > best:
					best = float(r.weather[k])
					want = str(k)
		elif r.weather is Array:
			for step in r.weather:
				if step is Array and str(step[0]) != "CLEAR":
					want = str(step[0])
					break
		elif str(r.weather) == "foggy":
			want = "FOG"
		elif str(r.weather) == "stormy":
			want = "STORM"
		if want != "" and GameState.Weather.has(want):
			gs.weather = GameState.Weather[want]
			var w: Weather3D = v._weather3d
			w.fog_mult = float(Weather3D.FOG_MULT.get(want, 1.0))
			w.sea_fog = 1.0 if want == "SEA_FOG" else 0.0
		# Up to the nearest water, facing it.
		var p := player()
		var best_z: WaterZone = null
		for z in get_tree().get_nodes_in_group("water_zones"):
			if best_z == null or (z as Node2D).global_position.distance_to(p.global_position) < best_z.global_position.distance_to(p.global_position):
				best_z = z
		var kinds := {}
		for c in get_tree().get_nodes_in_group("critters"):
			kinds[c.get_script().resource_path.get_file()] = int(kinds.get(c.get_script().resource_path.get_file(), 0)) + 1
		print("INFO %s theme=%s size=%dx%d waters=%d/%d weather=%s ghosts=%d hunters=%d quota=%.0f day=%.0f critters=%s fish=%s/%s" % [l.id,
			main.get_node("MapGenerator").theme_name, Player.WORLD_WIDTH, Player.WORLD_HEIGHT,
			get_tree().get_nodes_in_group("water_zones_common").size(), get_tree().get_nodes_in_group("water_zones_rare").size(),
			GameState.Weather.keys()[gs.weather], get_tree().get_nodes_in_group("ghosts").size(), get_tree().get_nodes_in_group("hunters").size(),
			gs.quota_target, gs.day_duration, JSON.stringify(kinds), ",".join(FishData.branch_fish), ",".join(FishData.branch_epic)])
		if best_z != null:
			var to := (best_z.global_position - p.global_position).normalized()
			var edge: Vector2 = best_z.shore_point(-to)
			await put(edge - to * 70.0)
			p.aim_dir = to
		v.camera.make_current()
		# (past the level's opening card - CampaignHud.BANNER_TIME)
		await seconds(CampaignHud.BANNER_TIME + 1.0)
		await shot("lv_%s" % l.id)
		# From high over the map.
		hud(false)
		var mid := Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT) * 0.5
		var c := RunView3D.to3(mid, 0.0)
		var span := maxf(Player.WORLD_WIDTH, Player.WORLD_HEIGHT) / RunView3D.PX
		aim(c, c + Vector3(0, span * 0.62, span * 0.42), 55.0)
		_cam.far = span * 4.0
		await frames(2)
		# (for the map's layout only: no haze, lit as by a bright moon - its night put back after)
		v.set_process(false)
		var env: Environment = v._env
		var keep := [env.fog_enabled, env.ambient_light_energy, env.ambient_light_color]
		env.fog_enabled = false
		env.ambient_light_energy = 1.4
		env.ambient_light_color = Color(0.62, 0.66, 0.72)
		await frames(3)
		await shot("map_%s" % l.id)
		env.fog_enabled = keep[0]
		env.ambient_light_energy = keep[1]
		env.ambient_light_color = keep[2]
		v.set_process(true)
		hud(true)
		_cam.queue_free()
		_cam = null
		# A few seconds more of the run going on (anything it trips over printed between the marks).
		await seconds(3.0)
		print("LEVEL %s END" % l.id)
	get_tree().quit()
