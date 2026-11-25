extends "res://tests/scenarios.gd"
## Verification: all 26 levels in order as a player would clear them, the developer's all-open off -
## each one open only when its turn comes, the branch's own fish caught (★★), the quota offered,
## out by the stones; the stars, the first clear's gold and items, and what opens next.

var rows := []


func _run() -> void:
	gs = get_tree().root.get_node("GameState")
	reset_progress()
	var levels: Array = camp().LEVELS
	var stop := OS.get_environment("STOP")
	for i in levels.size():
		var l: Dictionary = levels[i]
		if stop != "" and i > 0 and levels[i - 1].id == stop:
			break
		var r: Dictionary = camp().rules_for(l.id)
		check(camp().level_open(l.id), "%s open on its turn" % l.id)
		if i + 1 < levels.size():
			check(not camp().level_open(levels[i + 1].id), "%s not open before %s is cleared" % [levels[i + 1].id, l.id])
		var gold0: int = Profile.gold
		var items0 := {}
		for k in (l.reward.get("items", {}) as Dictionary):
			items0[k] = Profile.stored(k)
		await play_level(l.id)
		check(camp().level_id == l.id and FishData.branch_fish == r.get("fish", []), "%s: started, its own fish set" % l.id)
		var own: Array = r.get("fish", []) + r.get("fish_epic", [])
		var f := fish()
		f["id"] = own[0]
		f["name"] = FishData.FISH[own[0]].name
		f["value"] = float(r.quota) + 1.0
		player().cast_started.emit(player().global_position, "near")
		player().hook_success.emit()
		player().catch_success.emit(f)
		gs.add_carried_fish(f)
		var two: bool = camp().condition_met(l.stars[0])
		gs.sacrifice_at(0)
		await frames(2)
		var quota_ok: bool = gs.day_phase == gs.DayPhase.ESCAPE
		gs.escape()
		await frames(3)
		var res: Dictionary = camp().result
		var stars: Array = res.get("stars", [])
		check(res.get("success", false) and stars.size() == 3 and stars[0] and stars[1], "%s: cleared, ★ and ★★ (%s)" % [l.id, str(stars)])
		var paid := Profile.gold - gold0
		for k in items0:
			check(Profile.stored(k) - int(items0[k]) == int(l.reward.items[k]), "%s: its reward %s x%d into the warehouse" % [l.id, k, int(l.reward.items[k])])
		check(paid >= int(l.reward.get("gold", 0)), "%s: first clear paid %d (reward %d)" % [l.id, paid, int(l.reward.get("gold", 0))])
		rows.append("%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s" % [l.id, l.name, "y" if quota_ok else "n", "y" if two else "n", str(stars), paid,
			int(l.reward.get("gold", 0)), JSON.stringify(l.reward.get("items", {}))])
		# (a map's last branch cleared: the next map's first opens - and not before)
		if i + 1 < levels.size() and levels[i + 1].chapter != l.chapter:
			check(camp().chapter_open(levels[i + 1].chapter) and camp().level_open(levels[i + 1].id),
				"chapter %d done: chapter %d opens" % [l.chapter, levels[i + 1].chapter])
	check(camp().curses_open(), "every map cleared: the curses open")
	var out := FileAccess.open(OS.get_environment("OUT") + "/play.tsv", FileAccess.WRITE)
	out.store_string("id\tname\tquota\tstar2\tstars\tpaid\treward_gold\treward_items\n" + "\n".join(rows) + "\n")
	out.close()
	print("\n".join(rows))
	print("\n%d checks, %d failed" % [checks, failures.size()])
	for x in failures:
		print("  FAILED: " + x)
	get_tree().quit()
