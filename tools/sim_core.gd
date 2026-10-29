extends RefCounted

## Progression simulator (user request: verify a character from a beginner to
## the first try at an epic fish to landing them steadily, with the items, the
## gold and the stat-affix fish carried, so the numbers - and the new gear and
## items to come - have something to stand on).
##
## Runs the game's OWN rules - the catch rolls (Player constants, FishData
## pools, rarity upgrades), lengths, the gate (FishData.gate_for / Stats), the
## affixes (FishLife.roll), vitality (FishLife.tick), sale values - for a
## player who plays whole runs one after another. What the game can't tell (a
## real fight, the ghosts) is an assumption, listed in ASSUME below and in the
## report.
##
##   godot --headless --path . -s tools/sim_progress.gd -- [seeds=N] [out=PATH]
##
## Writes the results as JSON (default /tmp/sim_progress.json).

## --- what the game can't say, assumed (change and re-run) ---
const ASSUME := {
	"run_seconds": 405.0,      # a free-play day: 300 s x DAY_PACE 1.35, the whole of it fished
	"cycle_extra": 20.0,       # s a cast takes besides its wait (strike, fight, reel in, walk, cast)
	"survive": 0.92,           # the share of runs escaped (ghosts, beasts, the night)
	"land": {"novice": 0.97, "normal": 0.90, "advanced": 0.80, "master": 0.62},  # a fight won, by difficulty
	"carry_affix": 4,          # affix fish carried at once (the bag has room for the catches too); scenario C: 8
	"dropper_gold": 80,        # a 洗點滴瓶: redraws a carried fish's stat affixes (used on fish whose numbers sit below the middle of their ranges)
	"rare_zone_share": 0.25,   # share of casts in a rare water zone
	"hotspot_casts": 3,        # casts a run at a hotspot
	"far_share": [0.2, 0.25, 0.3, 0.4, 0.5],  # share of far casts by rod tier (the farther rods reach)
	"live_bait_gold": 100,     # from this much gold the hotspot casts use a live frog (x2 rare, x2 epic)
	"level_runs": 25,          # the first runs clear the campaign's levels in order (first-clear gold)
	"max_runs": 300,
}

## Hypothetical gear (not in the game yet): four pieces - line (resil), float
## (react), hook (might), keeper rope (endure) - each of five tiers; what a piece
## of each tier gives, and what buying that tier costs. Scenarios "B" and "C".
const GEAR_VALUES := [0, 6, 12, 18, 25]
const GEAR_COSTS := [0, 60, 110, 180, 280]
const GEAR_STAT := ["resil", "react", "might", "endure"]

const WATERS := ["forest", "deadwood", "rocky", "tropical", "prehistoric", "swamp", "snow", "autumn", "ruins", "desert", "sea"]


func run(args: Array) -> void:
	var seeds := 60
	var out := "/tmp/sim_progress.json"
	for a in args:
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("out="):
			out = a.substr(4)
	var result := {"assume": ASSUME, "gear_values": GEAR_VALUES, "gear_costs": GEAR_COSTS, "scenarios": {}}
	for scen in ["A", "B", "C"]:
		var runs := []
		for s in seeds:
			runs.append(_player_life(scen, 1000 + s))
		result.scenarios[scen] = runs
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	print("wrote ", out)


# --- one character's life ----------------------------------------------------

func _player_life(scen: String, seed_n: int) -> Dictionary:
	seed(seed_n)
	var st := {"gold": 0, "rod": 0, "gear": [0, 0, 0, 0], "tank": [], "wins": 0, "feeds": 0, "droppers": 0, "weak_pending": []}
	var log := []
	var mile := {}
	var epic_ready_streak := 0
	var leg_ready_streak := 0
	for run in range(1, int(ASSUME.max_runs) + 1):
		var rec := _run(st, scen, run)
		log.append(rec)
		# milestones (the run each first happens)
		for key in ["giant_land", "rare_land", "epic_try", "epic_land", "leg_try", "leg_land"]:
			if rec.get(key, 0) > 0 and not mile.has(key):
				mile[key] = run
		if st.rod >= 4 and not mile.has("rod4"):
			mile["rod4"] = run
		for t in range(1, 5):
			if st.rod >= t and not mile.has("rod%d" % t):
				mile["rod%d" % t] = run
		# "steady": at least 80 % of the epic (2-stat) and legend (3-stat) kinds'
		# gates met on what's carried, 5 runs in a row
		if rec.ready_epic >= 0.8:
			epic_ready_streak += 1
			if epic_ready_streak >= 5 and not mile.has("steady_epic"):
				mile["steady_epic"] = run - 4
		else:
			epic_ready_streak = 0
		if rec.ready_leg >= 0.8:
			leg_ready_streak += 1
			if leg_ready_streak >= 5 and not mile.has("steady_leg"):
				mile["steady_leg"] = run - 4
		else:
			leg_ready_streak = 0
		if mile.has("steady_epic") and mile.has("steady_leg") and run > maxi(int(mile.steady_epic), int(mile.steady_leg)) + 30:
			break
	return {"mile": mile, "log": log}


func _stat_totals(st: Dictionary, carried: Array, scen: String) -> Dictionary:
	var out := {}
	for stat in Stats.IDS:
		out[stat] = Stats.rod_stat(stat, st.rod)
		if scen != "A":
			out[stat] += GEAR_VALUES[int(st.gear[GEAR_STAT.find(stat)])]
		for f in carried:
			if FishLife.stats_count(f) and FishLife.has_trait(f, stat):
				out[stat] += int(FishLife.val_of(f, stat))
	return out


## Whether the totals clear `need` (with the challenge range): "ok", "soft"
## (within the range) or the stat that's short.
func _gate(totals: Dictionary, need: Dictionary) -> Dictionary:
	var soft := 0.0
	for s in Stats.ORDER:
		if need.has(s):
			var gap := float(int(need[s]) - int(totals[s])) / float(need[s])
			if gap > Stats.CHALLENGE:
				return {"fail": s, "gap": gap}
			soft = maxf(soft, gap)
	return {"fail": "", "soft": clampf(soft, 0.0, Stats.CHALLENGE)}


func _pick_tier(rod: int) -> String:
	var far: float = ASSUME.far_share[rod]
	var r := randf()
	if r < far:
		return "far"
	return "mid" if r < far + (1.0 - far) * 0.5 else "near"


## How ready the player is for each kind of epic and legend fish: the share of
## (species, size) gates the totals clear - the epic (2 stats) and legend (3)
## kinds apart.
func _ready_shares(totals: Dictionary) -> Dictionary:
	var epic_ok := 0
	var epic_n := 0
	var leg_ok := 0
	var leg_n := 0
	for id in FishData.SEA_RARE:
		for q in [0.2, 0.5, 0.8, 1.0]:
			var span: Array = FishData.LENGTH_CM[id]
			var need := FishData.gate_for(id, "epic", lerpf(float(span[0]), float(span[1]), q))
			epic_n += 1
			if _gate(totals, need).fail == "":
				epic_ok += 1
	var legs := FishData.SEA_LEGEND.duplicate()
	for style in FishData.STYLE_FISH:
		legs.append(FishData.STYLE_FISH[style][1])
	for id in legs:
		for q in [0.2, 0.5, 0.8, 1.0]:
			var span: Array = FishData.LENGTH_CM[id]
			var need := FishData.gate_for(id, "legend", lerpf(float(span[0]), float(span[1]), q))
			leg_n += 1
			if _gate(totals, need).fail == "":
				leg_ok += 1
	return {"epic": float(epic_ok) / epic_n, "leg": float(leg_ok) / leg_n}


func _run(st: Dictionary, scen: String, run: int) -> Dictionary:
	var water: String = WATERS[randi() % WATERS.size()]
	FishData.waters = water
	# the affix fish taken out of the tank into the bag (best stat sum first)
	var tank: Array = st.tank
	var carry: int = 8 if scen == "C" else int(ASSUME.carry_affix)
	tank.sort_custom(func(a, b): return _score(a) > _score(b))
	var carried := []
	for f in tank.duplicate():
		if carried.size() >= carry:
			break
		if FishLife.stats_count(f):
			carried.append(f)
			tank.erase(f)
	var spend := 0
	var income := 0
	var rec := {"run": run, "water": water, "casts": 0, "land": 0, "fails": {}, "giant_enc": 0, "giant_land": 0,
		"rare_land": 0, "epic_enc": 0, "epic_try": 0, "epic_land": 0, "leg_enc": 0, "leg_try": 0, "leg_land": 0}
	var cycle_total := 0.0
	var caught := []
	var elapsed := 0.0
	var hot_left: int = int(ASSUME.hotspot_casts)
	while elapsed < float(ASSUME.run_seconds):
		var tier := _pick_tier(st.rod)
		var td: Dictionary = FishData.get_tier_data(tier)
		var wait := randf_range(float(td.wait_min), float(td.wait_max))
		var cycle := wait + float(ASSUME.cycle_extra)
		elapsed += cycle
		for f in carried:
			FishLife.tick(f, cycle, false)
		rec.casts += 1
		var in_hot := hot_left > 0 and randf() < 0.3
		if in_hot:
			hot_left -= 1
		var rare_zone := randf() < float(ASSUME.rare_zone_share)
		# live frog on the hotspot casts when there's gold to spare
		var frog: bool = in_hot and st.gold >= int(ASSUME.live_bait_gold)
		if frog:
			st.gold -= 15
			spend += 15
		# --- the game's own cast roll ---
		var no_bite := Player.NO_BITE_CHANCE
		if in_hot or rare_zone:
			no_bite *= Player.HOTSPOT_NO_BITE_MULT
		if randf() < no_bite:
			continue
		var rare_chance := Player.FAR_RARE_CHANCE if tier == "far" else Player.NORMAL_RARE_CHANCE
		if rare_zone:
			rare_chance += Player.RARE_ZONE_RARE_CHANCE_BONUS
		if frog:
			rare_chance *= 2.0
		var is_rare := false
		if in_hot:
			is_rare = randf() < Player.HOTSPOT_RARE_CHANCE
		else:
			is_rare = randf() < rare_chance
		var epic_chance := Player.EPIC_CHANCE_OF_RARE * (2.0 if frog else 1.0)
		var is_epic := is_rare and randf() < epic_chance
		var rarity_key := "epic" if is_epic else ("rare" if is_rare else "common")
		var species := FishData.pick_species(tier, "rare" if rare_zone else "common", rarity_key)
		var size_key := Inventory.size_for_catch(tier, is_epic)
		var plan := FishData.measure(species.id, size_key)
		var disp := UiKit.fish_rarity({"id": species.id, "rarity": rarity_key})
		var need := FishData.gate_for(species.id, disp, float(plan.length))
		var kind := ""
		if not need.is_empty():
			if disp == "legend":
				kind = "leg"
			elif disp == "epic":
				kind = "epic"
			else:
				kind = "giant"
			rec["%s_enc" % kind] += 1
		var totals := _stat_totals(st, carried, scen)
		var g := _gate(totals, need)
		if g.fail != "":
			rec.fails[g.fail] = int(rec.fails.get(g.fail, 0)) + 1
			continue
		if kind != "" and kind != "giant":
			rec["%s_try" % kind] += 1
		var diff := FishData.difficulty_for(rarity_key, species.trait)
		var p: float = float(ASSUME.land[diff])
		var soft := float(g.get("soft", 0.0))
		p = clampf(p - soft * 3.0, 0.05, 0.99)
		if randf() >= p:
			continue
		rec.land += 1
		if kind != "":
			rec["%s_land" % kind] += 1
		if is_rare and not is_epic and not species.id in FishData.COMMON_FRESH:
			rec["rare_land"] += 1
		# the fish itself: value as Player makes it
		var value: float = float(td.value) * float(species.value_mult) * (Player.RARE_ZONE_VALUE_MULT if rare_zone else Player.COMMON_ZONE_VALUE_MULT)
		var fish := {"name": species.name, "id": species.id, "value": value, "tier": tier, "size": size_key, "rarity": rarity_key}
		fish.merge(plan)
		fish.value = FishData.value_for_length(species.id, float(fish.value), float(fish.length))
		FishLife.roll(fish)
		caught.append(fish)
	rec["elapsed"] = elapsed
	# --- the run ends ---
	var survived := randf() < float(ASSUME.survive)
	rec["survived"] = survived
	var gold_in := 0
	if survived:
		st.wins += 1
		for f in carried:
			if FishLife.state(f) == "alive":
				tank.append(f)
			else:
				gold_in += FishLife.sale_value(f)
		# the catches: affix fish worth keeping go in the tank, the rest are sold
		for f in caught:
			var keep := FishLife.stats_count(f) and _score(f) > 0 and tank.size() < Profile.TANK_SIZE
			if keep:
				tank.append(f)
			else:
				FishLife.tick(f, randf() * 120.0, false)
				gold_in += FishLife.sale_value(f)
		if st.wins <= int(ASSUME.level_runs):
			gold_in += int(Campaign.LEVELS[st.wins - 1].reward.get("gold", 0)) + Campaign.STAR_GOLD
	else:
		# a lost night: the brought fish come back weak (in the tank, no use until fed)
		for f in carried:
			if FishLife.make_weak(f):
				st.weak_pending.append(f)
			tank.append(f)
	st.gold += gold_in
	income += gold_in
	# the tank keeps only so many: the worst go
	tank.sort_custom(func(a, b): return _score(a) > _score(b))
	while tank.size() > Profile.TANK_SIZE:
		var worst: Dictionary = tank.pop_back()
		income += FishLife.sale_value(worst)
		st.gold += FishLife.sale_value(worst)
	# --- the shopping ---
	for f in st.weak_pending.duplicate():
		if st.gold >= 40:
			st.gold -= 40
			spend += 40
			st.feeds += 1
			FishLife.restore(f, 0.5)
		st.weak_pending.erase(f)
	if st.rod < 4 and st.gold >= int(Profile.ROD_TIERS[st.rod + 1].cost) + 20:
		var c: int = int(Profile.ROD_TIERS[st.rod + 1].cost)
		st.gold -= c
		spend += c
		st.rod += 1
	if scen != "A":
		# the lowest gear piece up a tier, when it's affordable (after the rods)
		var lowest := 0
		for i in 4:
			if int(st.gear[i]) < int(st.gear[lowest]):
				lowest = i
		var tier_next: int = int(st.gear[lowest]) + 1
		if tier_next < GEAR_VALUES.size() and st.gold >= int(GEAR_COSTS[tier_next]) + 20 and st.rod >= 2:
			st.gold -= int(GEAR_COSTS[tier_next])
			spend += int(GEAR_COSTS[tier_next])
			st.gear[lowest] = tier_next
	# the dropper, on the fish to be carried: below the middle of a range - redraw (up to 3 tries a fish)
	for f in tank.slice(0, carry):
		for _try in 3:
			if st.gold < int(ASSUME.dropper_gold) + 300 or not _below_middle(f):
				break
			st.gold -= int(ASSUME.dropper_gold)
			spend += int(ASSUME.dropper_gold)
			st.droppers += 1
			FishLife.use_dropper(f)
	var totals2 := _stat_totals(st, tank.slice(0, carry), scen)
	var after := _ready_shares(totals2)
	rec["ready_epic"] = after.epic
	rec["ready_leg"] = after.leg
	rec["gold"] = st.gold
	rec["rod"] = st.rod
	rec["gear"] = st.gear.duplicate()
	rec["income"] = income
	rec["spend"] = spend
	rec["tank_n"] = tank.size()
	rec["tank_stats"] = totals2
	rec["tank_affix_vals"] = tank.slice(0, carry).map(func(f): return _score(f))
	rec["droppers"] = st.droppers
	rec["feeds"] = st.feeds
	return rec


## What a fish's stat affixes sum to (0 when it has none).
func _score(f: Dictionary) -> int:
	var n := 0
	for stat in Stats.IDS:
		if FishLife.has_trait(f, stat):
			n += int(FishLife.val_of(f, stat))
	return n


## Whether any stat affix of `f` sits below the middle of its tier's range.
func _below_middle(f: Dictionary) -> bool:
	for stat in Stats.IDS:
		if FishLife.has_trait(f, stat):
			var r: Array = FishLife.STAT_RANGES[FishLife.tier_of(f, stat) - 1]
			if float(FishLife.val_of(f, stat)) < (float(r[0]) + float(r[1])) / 2.0:
				return true
	return false
