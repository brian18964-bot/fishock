extends RefCounted
## tools/sim_fights.gd's work: see there.

## The anglers: how tight they let the line get before easing off (0..1), how long they take
## to answer a move (s), how often they don't answer it at all.
const SKILL := {
	"新手": {"ease": 0.7, "answer": 1.2, "miss": 0.35},
	"一般": {"ease": 0.55, "answer": 0.6, "miss": 0.12},
	"熟練": {"ease": 0.5, "answer": 0.3, "miss": 0.02},
}
## The gear: the rod's tier, and each of the four stats.
const GEAR := {
	"起步": {"rod": 0, "stat": 0},
	"中期": {"rod": 2, "stat": 30},
	"後期": {"rod": 4, "stat": 60},
}
const CAST_M := {"near": 7.0, "mid": 12.0, "far": 18.0}


func run(args: Array) -> void:
	var n := 40
	var out := "/tmp/sim_fights.json"
	for a in args:
		if a.begins_with("n="):
			n = int(a.substr(2))
		elif a.begins_with("out="):
			out = a.substr(4)
	var rows := []
	for rarity in ["common", "rare", "epic"]:
		for temper in ["calm", "normal", "wild"]:
			for water in ["near", "mid", "far"]:
				var diff := FishData.difficulty_for(rarity, temper)
				var size := Inventory.size_for_catch(water, rarity == "epic")
				for gear in GEAR:
					for skill in SKILL:
						var landed := 0
						var time := 0.0
						var why := {}
						for i in n:
							var r := _fight(rarity, temper, water, diff, size, GEAR[gear], SKILL[skill], 1000 + i)
							if r.result == "landed":
								landed += 1
								time += r.time
							else:
								var key: String = r.result if r.result != "" else "timeout"
								why[key] = int(why.get(key, 0)) + 1
						rows.append({"rarity": rarity, "temper": temper, "water": water, "difficulty": diff, "size": size,
							"gear": gear, "skill": skill, "landed": float(landed) / n,
							"seconds": time / maxi(landed, 1), "lost": why})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"n": n, "rows": rows}, "\t"))
	f.close()
	print("sim_fights: %d kinds of fight x %d each -> %s" % [rows.size(), n, out])


## One fight, set up as Player._hook_fish does, played by a bot of `skill`.
func _fight(rarity: String, temper: String, water: String, diff: String, size: String, gear: Dictionary, skill: Dictionary, seed_n: int) -> Dictionary:
	seed(seed_n)
	var rod: Dictionary = Profile.ROD_TIERS[int(gear.rod)]
	var f := FishFight.new(diff, "", FishData.TIERS[water], 1.0, rod)
	f.max_hp = FishFight.hp_for(rarity, size)
	f.stat_might = float(gear.stat)
	f.stat_react = float(gear.stat)
	f.stat_resil = float(gear.stat)
	f.stat_endure = float(gear.stat)
	var heft: float = float(Player.HEFT_DIFFICULTY.get(diff, 0.0)) + float(Player.HEFT_SIZE.get(size, 0.0)) + float(Player.HEFT_TRAIT.get(temper, 0.0))
	if rarity == "epic":
		heft += Player.HEFT_EPIC
	elif rarity == "rare":
		heft += Player.HEFT_RARE
	f.open(clampf(heft, 0.0, 1.0))
	f.line_max = Player.LINE_BASE + Player.LINE_PER_TIER * int(gear.rod)
	f.distance = clampf(float(CAST_M[water]), FishFight.MIN_DISTANCE, f.line_max * 0.72)
	var pull: float = FishData.DIFFICULTY[diff].pull
	var rate := Player.SWIM_OUT * pull * pull * float(Player.SWIM_OUT_TRAIT.get(temper, 1.0))
	if rarity == "epic":
		rate *= Player.SWIM_OUT_EPIC
	elif rarity == "rare":
		rate *= Player.SWIM_OUT_RARE
	if water == "far":
		rate *= Player.SWIM_OUT_FAR
	f.swim_out = rate
	f.field = true
	f.plan(size, temper)
	var t := 0.0
	var dt := 0.05
	var asked := 0.0
	var answers := true
	while f.result == "" and t < 300.0:
		var counter := Vector2.ZERO
		if f.prompt_active():
			# (a way asked: answered - or not - a while after it's asked)
			if asked == 0.0:
				answers = randf() >= float(skill.miss)
			asked += dt
			if answers and asked > float(skill.answer):
				counter = f.prompt_dir()
		else:
			asked = 0.0
		var reel := 1.0 if (f.tension < float(skill.ease) and f.cur_move == "" and f.mood() != "jump") else 0.0
		# (the strike's opening: held, as the game asks)
		if f.opening_left > 0.0:
			reel = 0.0
		f.strain = f.stat_strain()
		# (the stick's held all the while - but let go as it leaps)
		f.hold = f.mood() != "jump"
		if f.mood() == "snag" and f.tension < 0.85:
			reel = 1.0
		f.update(dt, reel, counter, Vector2.UP)
		t += dt
	return {"result": f.result, "time": t}
