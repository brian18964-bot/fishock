extends "res://tests/scenarios.gd"
## Verification: a bot plays each level through with the game's own mechanics - it stands at a shore and
## casts (Space held and let go), strikes on the bite, fights the fish with the sticks (answering a way
## asked when one is, reeling when the line's easy), carries its catch to the altar and offers it, and
## leaves by the stones. It's quicker than a person (it's set down at the water, at the altar): what it
## can't do in a level's time, a player can't. Written per level to OUT/bot.tsv.

const GAME_CAP := 900.0
var rows := []


func _run() -> void:
	gs = get_tree().root.get_node("GameState")
	var only := OS.get_environment("LEVELS")
	reset_progress()
	Campaign.dev_all_open = true
	for l in camp().LEVELS:
		if only != "" and not str(l.id) in only.split(","):
			continue
		seed(31 + rows.size())
		await _play(l)
	var f := FileAccess.open(OS.get_environment("OUT") + "/bot.tsv", FileAccess.WRITE)
	f.store_string("id\tname\toutcome\tgame_s\tday_s\tquota\tcatches\tlanded_of\tbranch\tprompts\tcauses\n" + "\n".join(rows) + "\n")
	f.close()
	print("\n".join(rows))
	get_tree().quit()


func _play(l: Dictionary) -> void:
	var id := str(l.id)
	print("LEVEL %s BEGIN" % id)
	# (back at the camp between levels a player sells the bones brought home or puts them away: the bag
	# keeps only its lures)
	Profile.bag = Profile.bag.filter(func(e): return str(e.get("id", "")).begins_with("lure_"))
	await play_level(id)
	for _i in 600:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	var p := player()
	var stick: TouchJoystick = p._move_joystick
	var bag_desc := []
	var cells := 0
	for it in Inventory.items(p):
		cells += int(it.size.x) * int(it.size.y)
		bag_desc.append("%s%s" % [str(it.get("label", it.kind)), "x%d" % int(it.count) if int(it.get("count", 0)) > 1 else ""])
	print("BAG %s: %d of %d cells: %s" % [str(l.id), cells, Inventory.COLS * Inventory.ROWS, ", ".join(bag_desc)])
	var dropped := 0
	var fails := {}
	p.catch_failed.connect(func(r): fails[str(r)] = int(fails.get(str(r), 0)) + 1)
	var zones := get_tree().get_nodes_in_group("water_zones_common") + get_tree().get_nodes_in_group("water_zones_rare")
	var own: Array = camp().rules.get("fish", []) + camp().rules.get("fish_epic", [])
	var t0 := Time.get_ticks_msec()
	var catches := 0
	var fights := 0
	var branch := 0
	var prompts := 0
	var causes := {}
	var zi := 0
	var game_t := 0.0
	while not gs.run_over and gs.day_phase == gs.DayPhase.FISHING and game_t < GAME_CAP:
		p.bait_count = maxi(p.bait_count, 3)
		var z: WaterZone = zones[zi % zones.size()]
		zi += 1
		var samples: Array = z.shore_samples(40.0)
		if samples.is_empty():
			continue
		var home: Vector2 = main.get_node("FuelStation").global_position
		samples.sort_custom(func(a, b): return (a[0] as Vector2).distance_to(home) < (b[0] as Vector2).distance_to(home))
		var pick: Array = samples[randi() % mini(6, samples.size())]
		var way: Vector2 = pick[1]
		await put(pick[0] + way * 34.0 - Player.FEET)
		p.velocity = Vector2.ZERO
		p.aim_dir = -way
		# Cast: held, let go.
		key(KEY_SPACE, true)
		await seconds(randf_range(0.35, 0.7))
		key(KEY_SPACE, false)
		var waited := 0.0
		while waited < 1.5 and p.state != Player.State.WAITING:
			await frames(3)
			waited += 0.05
		if p.state != Player.State.WAITING:
			p._reset_line(Player.State.IDLE)
			await frames(3)
			game_t = float(camp().run.get("elapsed", 0.0))
			continue
		# The bite.
		waited = 0.0
		while waited < 30.0 and p.state == Player.State.WAITING and not gs.run_over:
			await frames(3)
			waited += 0.05
		if p.state == Player.State.BITE:
			await seconds(0.12)
			key(KEY_SPACE, true)
			await frames(4)
			key(KEY_SPACE, false)
		await frames(6)
		if p.state == Player.State.REELING and p.fight != null:
			fights += 1
			var before: int = gs.carried_fish.size()
			var t := 0.0
			while p.state == Player.State.REELING and t < 150.0 and p.fight != null:
				await frames(3)
				t += 0.05
				var f: FishFight = p.fight
				if f == null:
					break
				if f.prompt_active():
					prompts += 1
				if f.prompt_active() and f.answer_left < f.swipe_window() - 0.35:
					stick.output = FightPanel.to_frame(f.prompt_dir())
					stick.is_pressed = true
				else:
					stick.output = Vector2.ZERO
					stick.is_pressed = false
				var reel := f.opening_left <= 0.0 and f.cur_move == "" and f.tension < 0.7 and f.mood() != "jump"
				key(KEY_SPACE, reel or f.opening_left > 0.0)
				key(KEY_SHIFT, reel)
			key(KEY_SPACE, false)
			key(KEY_SHIFT, false)
			stick.output = Vector2.ZERO
			stick.is_pressed = false
			await seconds(1.0)
			if gs.carried_fish.size() > before:
				catches += 1
				if str(gs.carried_fish.back().get("id", "")) in own:
					branch += 1
			elif p.fight != null and str(p.fight.result) == "landed":
				dropped += 1
			else:
				var why := str(p.fight.result) if p.fight != null else "lost"
				causes[why] = int(causes.get(why, 0)) + 1
		else:
			causes["no_bite"] = int(causes.get("no_bite", 0)) + 1
			p._reset_line(Player.State.IDLE)
			await frames(3)
		# To the altar with what's carried, when it would make the quota or the bag's getting full.
		var carried := 0.0
		for fish in gs.carried_fish:
			carried += FishLife.offer_value(fish)
		if gs.carried_fish.size() > 0:
			await put(main.get_node("Altar").global_position + Vector2(0, 40))
			while not gs.carried_fish.is_empty() and gs.day_phase == gs.DayPhase.FISHING:
				if gs.sacrifice_at(0).is_empty():
					break
			await frames(3)
		game_t = float(camp().run.get("elapsed", 0.0))
	var tut := ""
	for c in main.get_children():
		if c is CampaignHud and not (c as CampaignHud).steps.is_empty():
			tut = "%d/%d" % [mini((c as CampaignHud).step, (c as CampaignHud).steps.size()), (c as CampaignHud).steps.size()]
	var outcome := "timeout"
	if gs.day_phase == gs.DayPhase.ESCAPE and not gs.run_over:
		await put(main.get_node("EscapePoint").global_position)
		await seconds(0.4)
		key(KEY_E, true)
		await frames(3)
		key(KEY_E, false)
		await seconds(Player.ESCAPE_KNEEL + 1.5)
		if not gs.run_over:
			gs.escape()
			await frames(3)
			outcome = "escaped(by call)"
		else:
			outcome = "escaped"
	elif gs.run_over:
		outcome = "ended:" + str(gs.last_cause)
	var res: Dictionary = camp().result
	if outcome.begins_with("escaped") and not res.get("success", false):
		outcome += "/no-success"
	if tut != "":
		causes["tutorial_before_escape"] = tut
	causes["dropped"] = dropped
	causes["fail_signals"] = fails
	for k in ["stolen", "grabbed", "animal_hit", "water_ghost_hit"]:
		if float(camp().run.get(k, 0.0)) > 0.0:
			causes[k] = int(camp().run.get(k, 0.0))
	rows.append("%s\t%s\t%s\t%.0f\t%.0f\t%.0f/%.0f\t%d\t%d/%d\t%d\t%d\t%s" % [id, l.name, outcome, float(camp().run.get("elapsed", game_t)),
		gs.day_duration, gs.quota_progress, gs.quota_target, catches, catches, fights, branch, prompts, JSON.stringify(causes)])
	print("BOT ", rows.back(), "  (real %d s)" % ((Time.get_ticks_msec() - t0) / 1000))
	print("LEVEL %s END" % id)
