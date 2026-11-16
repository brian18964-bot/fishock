extends RefCounted
## tools/sim_fights.gd's work: see there.

## The anglers: how tight they let the line get before easing off (0..1), how long they take
## to answer a move (s), how often they don't answer it at all.
## `see`: how late they see the tension bar (s, a person's reaction); `low`: how slack they let
## it go before reeling again; `hold`: whether the thumb stays on the stick while they ease off
## (頂住) or comes off it (放線).
const SKILL := {
	"新手": {"ease": 0.7, "low": 0.15, "answer": 1.2, "miss": 0.35, "see": 0.45, "hold": 0.4},
	"一般": {"ease": 0.6, "low": 0.25, "answer": 0.6, "miss": 0.12, "see": 0.3, "hold": 0.7},
	"熟練": {"ease": 0.55, "low": 0.3, "answer": 0.3, "miss": 0.02, "see": 0.18, "hold": 0.95},
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
		if a == "sweep":
			_sweep(n)
			return
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
	# (what they see is the tension `see` s ago; reeling or easing off till they see it's time)
	var seen := []
	var reeling := true
	var thumb := randf() < float(skill.hold)
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
		seen.append(f.tension)
		var lag := int(round(float(skill.see) / dt))
		var looks: float = seen[maxi(seen.size() - 1 - lag, 0)]
		if looks > float(skill.ease):
			reeling = false
		elif looks < float(skill.low):
			reeling = true
		var reel := 1.0 if (reeling and f.cur_move == "" and f.mood() != "jump") else 0.0
		# (the strike's opening: held, as the game asks)
		if f.opening_left > 0.0:
			reel = 0.0
		f.strain = f.stat_strain()
		# (the stick's held all the while - but let go as it leaps)
		# (held through the strike's opening, as the game says to; after it, the thumb as theirs is)
		f.hold = f.opening_left > 0.0 or (f.mood() != "jump" and (reel > 0.0 or thumb))
		if f.mood() == "snag" and looks < 0.85:
			reel = 1.0
		f.update(dt, reel, counter, Vector2.UP)
		t += dt
	return {"result": f.result if f.result == "" or f.result == "landed" else "%s/%s" % [f.result, f.snap_why], "time": t}


## How the landing goes with how late the tension's seen (the reaction), the rest of the
## angler as 一般, the gear as 起步: per fish, the share landed and the tension's rise reeling.
func _sweep(n: int) -> void:
	var sees := [0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5]
	print("反應(s)  " + "  ".join(sees.map(func(x): return "%5.2f" % x)))
	for spec in [["common", "calm", "mid"], ["common", "normal", "mid"], ["common", "wild", "mid"], ["rare", "normal", "far"], ["epic", "normal", "near"]]:
		var diff := FishData.difficulty_for(spec[0], spec[1])
		var size := Inventory.size_for_catch(spec[2], spec[0] == "epic")
		var line := "%-6s %-6s %-4s" % spec
		for see in sees:
			var skill: Dictionary = SKILL["一般"].duplicate()
			skill.see = see
			var landed := 0
			for i in n:
				if _fight(spec[0], spec[1], spec[2], diff, size, GEAR["起步"], skill, 1000 + i).result == "landed":
					landed += 1
			line += "  %4d%%" % roundi(100.0 * landed / n)
		print(line)
	# how fast the tension climbs reeling steadily (no moves), per fish
	for spec in [["common", "normal", "mid"], ["epic", "normal", "near"]]:
		seed(5)
		var diff := FishData.difficulty_for(spec[0], spec[1])
		var f := FishFight.new(diff, "", FishData.TIERS[spec[2]], 1.0, Profile.ROD_TIERS[0])
		f.open(0.0)
		f.opening_left = 0.0
		f.distance = 12.0
		f.tension = 0.2
		var t := 0.0
		while f.tension < 0.95 and t < 10.0 and f.result == "":
			f.update(0.05, 1.0, Vector2.ZERO, Vector2.UP)
			t += 0.05
		print("%s %s: 一直收線，張力 0.2 -> 0.95 用 %.2f 秒" % [spec[0], spec[1], t])
