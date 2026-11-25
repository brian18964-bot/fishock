class_name CrocQuests
extends RefCounted

## User request: Mr. Croc (鱷魚先生) by the camp's water - our crocodile character, there now and
## then on the shore - asks the traveller for fish (catch so many of a kind), and pays for them.
## After JOIN_AFTER of his errands he has one of his own (for now: the dream fish of a map - the
## alligator gar of 1-5, the great lake in the deep wood), and that done, he joins the characters
## who travel (Profile.join_character). Nothing says he might (user request: the players aren't to
## know the crocodile can be played): the character page doesn't show him till then
## (Campaign.character_shown), and none of his words hint at it.
##
## How it goes (all of it mine for now - the user can change any of it): he's first met once
## FROM_LEVEL's been cleared; back at camp he's by the water CHANCE of the time (always, with an
## errand done to hand in); one errand at a time, offered and kept till taken (or given up); a
## fish counts once it's caught after the errand's taken, wherever, whether the night's won or lost
## (the lifetime records' "caught_<id>": Campaign._record_life) - nothing handed over.
## The errand's fish: one already caught at least once (the everyday fresh ones if none yet) -
## how many by how rare (NEED), paid GOLD_EACH a fish.

const FROM_LEVEL := "1-1"
const CHANCE := 0.6
const JOIN_AFTER := 30
const DREAM_FISH := "alligator_gar"
const DREAM_WHERE := "1-5"
const DREAM_GOLD := 500
const NEED := {"common": [12, 20], "uncommon": [5, 8], "rare": [1, 2]}
const GOLD_EACH := {"common": 8, "uncommon": 25, "rare": 150}
## (how often an errand's fish is of each kind, where there's a choice)
const KIND_WEIGHT := {"common": 0.55, "uncommon": 0.35, "rare": 0.1}
## The character id he is (Profile.CHARACTERS).
const ID := "croc"

## (whether he's by the water this time at camp: rolled once a visit, -1 not yet - GameState.start_run
## sets it back)
static var here_roll := -1


## Whether he's been met at all (and not yet joined the characters).
static func met() -> bool:
	return Campaign.level_done(FROM_LEVEL) and not joined()


static func joined() -> bool:
	return Profile.characters_joined.has(ID)


## Whether he's by the water now.
static func here() -> bool:
	if not met():
		return false
	if ready_to_hand_in():
		return true
	if here_roll < 0:
		here_roll = 1 if randf() < CHANCE else 0
	return here_roll == 1


## The errand offered or taken ({} none yet): {fish, need, gold, base (the record when taken), taken,
## dream}.
static func quest() -> Dictionary:
	return Profile.croc.get("quest", {})


## How many of his errands have been done.
static func done() -> int:
	return int(Profile.croc.get("done", 0))


## How many of the errand's fish have been caught since it was taken.
static func progress(q: Dictionary = quest()) -> int:
	if q.is_empty() or not q.get("taken", false):
		return 0
	return maxi(int(Profile.record("caught_" + str(q.fish)) - float(q.get("base", 0.0))), 0)


static func ready_to_hand_in() -> bool:
	var q := quest()
	return not q.is_empty() and q.get("taken", false) and progress(q) >= int(q.need)


## The errand on offer - the one kept from before, or a new one (the dream fish's, after JOIN_AFTER).
static func offer() -> Dictionary:
	var q := quest()
	if not q.is_empty():
		return q
	if done() >= JOIN_AFTER:
		q = {"fish": DREAM_FISH, "need": 1, "gold": DREAM_GOLD, "taken": false, "dream": true}
	else:
		var fish := pick_fish()
		var kind := kind_of(fish)
		var span: Array = NEED[kind]
		var need := randi_range(int(span[0]), int(span[1]))
		q = {"fish": fish, "need": need, "gold": need * int(GOLD_EACH[kind]), "taken": false}
	Profile.croc["quest"] = q
	Profile._changed()
	return q


static func take() -> void:
	var q := offer()
	q["taken"] = true
	q["base"] = Profile.record("caught_" + str(q.fish))
	Profile.croc["quest"] = q
	Profile._changed()


static func give_up() -> void:
	Profile.croc["quest"] = {}
	Profile._changed()


## The errand done and paid for: {gold, joined (he's joined the characters)}; {} if it isn't done.
static func hand_in() -> Dictionary:
	if not ready_to_hand_in():
		return {}
	var q := quest()
	Profile.croc["quest"] = {}
	Profile.croc["done"] = done() + 1
	Profile.add_gold(int(q.gold))
	var out := {"gold": int(q.gold), "joined": false}
	if q.get("dream", false):
		Profile.join_character(ID)
		out.joined = true
	Profile._changed()
	return out


## An errand's fish: one caught before (by how rare - KIND_WEIGHT), the everyday fresh ones if none.
static func pick_fish() -> String:
	var by_kind := {"common": [], "uncommon": [], "rare": []}
	for id in FishData.FISH:
		if id == DREAM_FISH or Profile.record("caught_" + str(id)) <= 0.0:
			continue
		by_kind[kind_of(id)].append(id)
	if (by_kind.common as Array).is_empty() and (by_kind.uncommon as Array).is_empty() and (by_kind.rare as Array).is_empty():
		return FishData.COMMON_FRESH[randi() % FishData.COMMON_FRESH.size()]
	var total := 0.0
	for k in by_kind:
		if not (by_kind[k] as Array).is_empty():
			total += float(KIND_WEIGHT[k])
	var roll := randf() * total
	for k in by_kind:
		var list: Array = by_kind[k]
		if list.is_empty():
			continue
		roll -= float(KIND_WEIGHT[k])
		if roll <= 0.0:
			return str(list[randi() % list.size()])
	return FishData.COMMON_FRESH[0]


## How rare a kind of fish is, for his errands: the everyday ones, a water's own, the rarest.
static func kind_of(id: String) -> String:
	if id in FishData.COMMON_FRESH or id in FishData.SEA_COMMON:
		return "common"
	if id in FishData.SEA_RARE or id in FishData.SEA_LEGEND or id in FishData.BRANCH_ONLY:
		return "rare"
	for style in FishData.STYLE_FISH.values():
		if id == style[1]:
			return "rare"
	return "uncommon"


static func fish_name(id: String) -> String:
	return str(FishData.FISH.get(id, {}).get("name", id))


## What he says now: [lines, the action ("take", "hand_in", "give_up" or "")].
static func words() -> Array:
	var q := offer()
	var name := fish_name(str(q.fish))
	if ready_to_hand_in():
		if q.get("dream", false):
			return [["……你真的釣到牠了。深林大湖的鱷雀鱔。",
				"我以為這輩子再也看不到了。謝謝你，釣客。"], "hand_in"]
		return [["%d 條%s，都釣到了？好孩子。" % [int(q.need), name], "這是說好的 %d 金幣。" % int(q.gold)], "hand_in"]
	if q.get("taken", false):
		var lines := ["%s：%d／%d" % [name, progress(q), int(q.need)]]
		lines.append("深林大湖的那一條。我還在等。" if q.get("dream", false) else "不急，水會等你的。")
		return [lines, "give_up"]
	var lines: Array = []
	if done() == 0:
		lines.append("我是鱷魚先生，在這片水邊住很久了。年紀大了，不太下水了……")
	if q.get("dream", false):
		lines += ["你幫了我這麼多次……老實說，我一直在等一條魚。",
			"深林大湖裡的鱷雀鱔。我年輕時見過牠一次，就再也忘不了。你願意替我去看看嗎？"]
	else:
		lines.append("這次想麻煩你釣 %d 條%s。帶回好消息，我給你 %d 金幣。" % [int(q.need), name, int(q.gold)])
	if done() > 0:
		lines.append("（已經幫他完成 %d 次委託）" % done())
	return [lines, "take"]
