class_name Stats
extends RefCounted

## User request: the four stats (屬性) that say which fish can be landed -
## 力量 (might: how hard the line is hauled on), 韌性 (resil: how much the line
## takes), 反應 (react: the strike's time), 耐力 (endure: how long the hands
## last). There's no levelling: every number comes from what's carried and
## worn - the rod, the fish carried alive (their stat affixes), gear, the
## items' timed boosts (GameState.stat_buffs), and an event's (GameState.
## stat_event). total() adds the sources; a fish's gate (FishData.gate_for) is
## measured against it at the strike.

const IDS := ["might", "resil", "react", "endure"]
const NAMES := {"might": "力量", "resil": "韌性", "react": "反應", "endure": "耐力"}
## What the fight meets them in, in order: the strike's time, the first rush,
## the line's strain, the long fight (the first of those short is what fails).
const ORDER := ["react", "might", "resil", "endure"]
## The most any stat can be.
const CAP := 200


## What each rod gives, by its tier ([react, might, resil, endure] - 6 a stat
## the wooden one, 24 in all more a tier, leaning: most of what's needed beyond
## comes from the fish carried and, later, gear): the wooden one balanced, the glass
## quick, the carbon tough and enduring, the sea rod strong and enduring, the
## gold one best at all and strongest in might and resilience.
const ROD_STATS := [[6, 6, 6, 6], [20, 8, 8, 12], [12, 12, 26, 22], [12, 34, 20, 32], [24, 36, 31, 29]]


static func rod_stat(stat: String, tier: int) -> int:
	return ROD_STATS[clampi(tier, 0, ROD_STATS.size() - 1)][ORDER.find(stat)]


## How far short of a gate (the share of the need) still lets you try the
## fish: 12 %, the fight harder by the gap (Player).
const CHALLENGE := 0.12


## [[where from, number], ...] for `stat`: the rod, each fish carried alive
## that has it, the gear worn, what's been drunk or an event's.
static func sources(stat: String) -> Array:
	var out := [["釣竿", rod_stat(stat, Profile.rod_tier)]]
	for f in GameState.carried_fish:
		if FishLife.stats_count(f) and FishLife.has_trait(f, stat):
			out.append([str(f.get("name", "魚")), int(FishLife.val_of(f, stat))])
	for slot in Profile.equipped:
		var id: String = Profile.equipped[slot]
		if id != "":
			var n := int(Items.def(id).get("stats", {}).get(stat, 0))
			if n != 0:
				out.append([Items.name_of(id), n])
	var buff: Array = GameState.stat_buffs.get(stat, [0, 0.0])
	if float(buff[1]) > 0.0 and int(buff[0]) != 0:
		out.append(["藥效", int(buff[0])])
	var ev := int(GameState.stat_event.get(stat, 0))
	if ev != 0:
		out.append(["活動", ev])
	return out


static func total(stat: String) -> int:
	var n := 0
	for s in sources(stat):
		n += int(s[1])
	return clampi(n, 0, CAP)


## The first stat (in the fight's order) that `need` ({stat: number}) is out
## of reach of - short by more than CHALLENGE: {stat, gap (the share of the need
## it's short)}; {} if every one is met or within the challenge range.
static func shortfall(need: Dictionary) -> Dictionary:
	for s in ORDER:
		if need.has(s):
			var gap := float(int(need[s]) - total(s)) / float(need[s])
			if gap > CHALLENGE:
				return {"stat": s, "gap": gap}
	return {}


## The most any stat is short but within the challenge range (0: all met).
static func soft_gap(need: Dictionary) -> float:
	var worst := 0.0
	for s in ORDER:
		if need.has(s):
			worst = maxf(worst, float(int(need[s]) - total(s)) / float(need[s]))
	return clampf(worst, 0.0, CHALLENGE)


static func all() -> Dictionary:
	var out := {}
	for s in IDS:
		out[s] = total(s)
	return out
