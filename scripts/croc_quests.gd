class_name CrocQuests
extends RefCounted

## User request: Mr. Croc (鱷魚先生) by the camp's water - our crocodile character, there now and
## then on the shore - asks the traveller for fish and pays for them. After JOIN_AFTER of his
## errands he has one of his own (for now: the dream fish of a map - the alligator gar of 1-5, the
## great lake in the deep wood), and that done, he joins the characters who travel
## (Profile.join_character). Nothing says he might (user request: the players aren't to know the
## crocodile can be played): the character page doesn't show him till then
## (Campaign.character_shown), and none of his words hint at it.
##
## User request (the second round, as a game's quest giver does it): more than one errand at a
## time, offered a few at a time (one more each time back at camp, up to OFFER_MAX on offer and
## ACTIVE_MAX taken); each with a little story of its own ("今天特別想吃那種肚子大大的、頭小小的魚"
## - 交給鱷魚先生 5 條鯉魚 - 獎勵 150 金幣); the fish really handed over, a few now and the rest later
## (2/5), from wherever they're kept at camp - the bag, the clasp, the tank, the warehouse, the
## bucket; never a locked one, a golden one or a rotten one, the cheapest first.
##
## How it goes (all of it mine for now - the user can change any of it): he's first met once
## FROM_LEVEL's been cleared; back at camp he's by the water CHANCE of the time (always, with fish
## to hand him); the errand's fish one already caught at least once (the everyday fresh ones if
## none yet) - how many by how rare (NEED), paid GOLD_EACH a fish.

const FROM_LEVEL := "1-1"
const CHANCE := 0.6
const JOIN_AFTER := 30
const DREAM_FISH := "alligator_gar"
const DREAM_WHERE := "1-5"
const DREAM_GOLD := 500
const NEED := {"common": [4, 8], "uncommon": [2, 4], "rare": [1, 1]}
const GOLD_EACH := {"common": 30, "uncommon": 70, "rare": 300}
## (how often an errand's fish is of each kind, where there's a choice)
const KIND_WEIGHT := {"common": 0.6, "uncommon": 0.32, "rare": 0.08}
## (errands on offer at once, taken at once)
const OFFER_MAX := 2
const ACTIVE_MAX := 3
## The character id he is (Profile.CHARACTERS).
const ID := "croc"

## Each errand's story: by its fish - [title, what he says]. Fish with none of their own take one of
## ANY_STORY's (the fish's name put in for {fish}).
const STORY := {
	"carp": ["大肚子的魚", "今天特別想吃那種肚子大大的、頭小小的魚。"],
	"crucian": ["熬一鍋湯", "天涼了，想熬一鍋奶白色的魚湯。要那種扁扁的、刺多但很鮮的小魚。"],
	"grass_carp": ["啃草的傢伙", "湖邊的水草被啃得亂七八糟，八成是那種愛吃草的長身子魚幹的。抓幾條來給我瞧瞧。"],
	"tilapia": ["什麼水都能活", "有一種魚，再髒的水裡都活得好好的。煎得酥酥的，最好吃了。"],
	"catfish": ["長鬍子的老朋友", "我年輕時有個朋友，嘴邊留著長鬍子，整天躲在泥巴裡……我是說魚啦。"],
	"bass": ["大嘴巴", "有一種魚，嘴巴大得能吞下一隻青蛙。那隻青蛙商人最怕牠了，呵呵。"],
	"bluegill": ["小小的太陽", "想看看那種腮邊有一抹藍、圓得像小太陽的魚。"],
	"rainbow_trout": ["身上有彩虹", "聽說有種魚身上掛著一道彩虹，雨後的夜裡最愛跳。"],
	"eel": ["滑溜溜的", "抓起來滑溜溜的那種，烤得油亮油亮……光想就流口水。"],
	"loach": ["泥巴裡的小鬍子", "在泥巴裡鑽來鑽去的小傢伙，炒一盤剛好下酒。"],
	"sardine": ["一大群", "海裡那種一群一群、銀亮銀亮的小魚，醃起來能放好久。"],
	"saury": ["像把刀", "秋天最肥的那種，細長得像一把刀，烤到焦焦的最香。"],
	"mackerel": ["背上的波浪", "背上有波浪花紋的海魚，撒點鹽烤一烤就好。"],
	"horse_mackerel": ["一排硬鱗", "身體側邊長著一排硬鱗的小海魚，炸過連骨頭都能吃。"],
	"herring": ["醃一罐", "那種一網能撈上一大堆的海魚，醃一罐，冬天慢慢吃。"],
	"sea_bream": ["喜事的魚", "紅通通的，辦喜事一定要有的那種魚。最近……也沒什麼喜事啦。"],
	"sea_bass": ["海裡的鱸", "湖裡的鱸魚吃膩了，換換海裡的口味。"],
	"flounder": ["兩隻眼睛一邊", "有一種魚，兩隻眼睛擠在同一邊，平平地躺在海底裝石頭。"],
	"cod": ["雪白的肉", "肉雪白雪白、一片一片剝得開的那種，冬天吃最暖。"],
	"puffer": ["會生氣的魚", "一生氣就鼓成一顆球的傢伙。處理不好可是會出事的……放心，我很小心。"],
	"cutlassfish": ["銀色的帶子", "長長扁扁、閃著銀光，像一條帶子在水裡飄。"],
	"grouper": ["石頭縫裡的", "躲在石頭縫裡、身上斑斑點點的大嘴魚，清蒸最好。"],
	"mullet": ["冬天的烏金", "冬天游過海邊的那種，魚卵曬乾了比金子還貴。"],
	"croaker": ["會叫的魚", "夜裡會咕咕叫的金黃色魚。你聽過嗎？"],
	"yellowtail": ["黃尾巴", "尾巴黃黃的、肥滋滋的海魚。冬天的最好吃。"],
	"mahi": ["海上的追風者", "頭方方的、身上一片金綠，追著船跑的那種，力氣大得很。"],
	"conger": ["牙尖嘴利", "長長的、牙齒尖尖的海鰻。咬人很痛，可是熬湯很香。"],
	"scorpionfish": ["醜但好吃", "長得很醜、背上的刺會扎人，可是煮湯一絕。"],
}
const ANY_STORY := [
	["老朋友的口味", "以前常跟老朋友一起吃{fish}……好想再嚐嚐那個味道。"],
	["夜裡嘴饞", "不知道為什麼，今晚特別想吃{fish}。"],
	["湖邊的傳聞", "聽說這陣子{fish}特別多，幫我看看是不是真的？"],
	["我的收藏", "我想把各種魚都看過一遍。這次輪到{fish}了。"],
	["寄給孫子", "遠方的孫子說沒看過{fish}，我想做成魚乾寄給他。"],
	["比個大小", "那隻青蛙說他見過比我還大的{fish}。哼，我才不信。"],
]
const DREAM_STORY := ["一生的等待", "你幫了我這麼多次……老實說，我一直在等一條魚。深林大湖裡的鱷雀鱔——我年輕時見過牠一次，就再也忘不了。你願意替我去找找嗎？"]
## (his first words in a talk: the first time, and after)
const FIRST_HELLO := "喔，是你啊。我常在這水邊晃。"
const HELLO := ["又是你啊，釣客。", "坐吧，火旁邊暖和。", "今天水面很安靜。", "嗯？有事找我？", "來得正好，我正無聊呢。"]
## (on a handing over: all of it, part of it)
const THANKS := ["好孩子，就是這個味道。", "太好了，今晚有得吃了。", "辛苦你了，這是說好的。"]
const MORE := ["還差一些，不急。", "慢慢來，水會等你的。", "嗯，先收下這些。"]

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
	if not ready_list().is_empty():
		return true
	if here_roll < 0:
		here_roll = 1 if randf() < CHANCE else 0
	return here_roll == 1


## All his errands: on offer and taken - [{id, fish, need, given, gold, taken, title, text, dream}].
static func quests() -> Array:
	_upgrade()
	return Profile.croc.quests


static func offered() -> Array:
	return quests().filter(func(q): return not q.taken)


static func active() -> Array:
	return quests().filter(func(q): return q.taken)


## How many of his errands have been done.
static func done() -> int:
	return int(Profile.croc.get("done", 0))


static func quest_by_id(id: int) -> Dictionary:
	for q in quests():
		if int(q.id) == id:
			return q
	return {}


## (a save from the first round: its one errand - counted from the catches - kept as one of these,
## nothing handed over yet)
static func _upgrade() -> void:
	if not Profile.croc.has("quests"):
		Profile.croc["quests"] = []
	var old = Profile.croc.get("quest")
	if old is Dictionary and not (old as Dictionary).is_empty():
		var q := _make(str(old.get("fish", "carp")), bool(old.get("dream", false)))
		q.need = int(old.get("need", q.need))
		q.taken = bool(old.get("taken", false))
		Profile.croc.quests.append(q)
	Profile.croc.erase("quest")


## Each time he's by the water when the camp's come back to: one more errand on offer, up to
## OFFER_MAX (and the dream fish's alone, once JOIN_AFTER are done). The errands he offers now.
static func come_by() -> Array:
	var list := quests()
	if done() >= JOIN_AFTER:
		if not list.any(func(q): return q.get("dream", false)):
			list.append(_make(DREAM_FISH, true))
			Profile._changed()
	elif offered().size() < OFFER_MAX:
		list.append(_make(pick_fish(), false))
		Profile._changed()
	return offered()


static func _make(fish: String, dream: bool) -> Dictionary:
	var serial := int(Profile.croc.get("serial", 0)) + 1
	Profile.croc["serial"] = serial
	if dream:
		return {"id": serial, "fish": fish, "need": 1, "given": 0, "gold": DREAM_GOLD, "taken": false, "dream": true,
			"title": DREAM_STORY[0], "text": DREAM_STORY[1]}
	var kind := kind_of(fish)
	var span: Array = NEED[kind]
	var need := randi_range(int(span[0]), int(span[1]))
	var story: Array = STORY.get(fish, ANY_STORY[randi() % ANY_STORY.size()])
	return {"id": serial, "fish": fish, "need": need, "given": 0, "gold": need * int(GOLD_EACH[kind]), "taken": false,
		"dream": false, "title": story[0], "text": str(story[1]).replace("{fish}", fish_name(fish))}


## Why errand `id` can't be taken ("" it can).
static func cant_take(id: int) -> String:
	var q := quest_by_id(id)
	if q.is_empty() or q.taken:
		return "沒有這個委託"
	if active().size() >= ACTIVE_MAX and not q.get("dream", false):
		return "手上的委託太多了（最多 %d 個）" % ACTIVE_MAX
	return ""


static func take(id: int) -> bool:
	if cant_take(id) != "":
		return false
	quest_by_id(id)["taken"] = true
	Profile._changed()
	return true


static func give_up(id: int) -> void:
	var q := quest_by_id(id)
	if q.is_empty():
		return
	quests().erase(q)
	Profile._changed()


## The fish at camp that could go to errand `q`: [{fish, src, index, where}], the cheapest first -
## never a locked, golden or rotten one.
static func fish_for(q: Dictionary) -> Array:
	var out := Profile.home_fish().filter(func(h):
		var f: Dictionary = h.fish
		return str(f.get("id", "")) == str(q.fish) and not Locks.fish(f) and not f.get("golden", false) \
			and FishLife.state(f) != "rotten")
	out.sort_custom(func(a, b): return FishLife.sale_value(a.fish) < FishLife.sale_value(b.fish))
	return out


## Whether errand `q`'s been taken and some of its fish could be handed over now.
static func can_give(q: Dictionary) -> bool:
	return q.taken and int(q.given) < int(q.need) and not fish_for(q).is_empty()


## The taken errands with fish to hand over now.
static func ready_list() -> Array:
	return active().filter(func(q): return can_give(q))


## Whether there's something to talk to him about - an errand on offer, or fish to hand him (the
## scroll over his head at camp).
static func has_news() -> bool:
	return not offered().is_empty() or not ready_list().is_empty()


## (the first round's name for it: there's fish to hand him)
static func ready_to_hand_in() -> bool:
	return not ready_list().is_empty()


## Hands him errand `id`'s fish - as many as there are, up to what's still wanted:
## {given (this time), done (the errand complete), gold, joined (he's joined the characters)};
## {} if none could be.
static func give(id: int) -> Dictionary:
	var q := quest_by_id(id)
	if q.is_empty() or not can_give(q):
		return {}
	var want := int(q.need) - int(q.given)
	var picks: Array = fish_for(q).slice(0, want)
	# (out of each place from the back, so the indices left still hold)
	picks.sort_custom(func(a, b): return a.index > b.index)
	if picks.any(func(p): return p.src == "tank"):
		Profile.settle_fortune()
	for p in picks:
		(Profile.fish_list(str(p.src)) as Array).remove_at(int(p.index))
	q.given = int(q.given) + picks.size()
	var out := {"given": picks.size(), "done": false, "gold": 0, "joined": false}
	if int(q.given) >= int(q.need):
		quests().erase(q)
		Profile.croc["done"] = done() + 1
		Profile.add_gold(int(q.gold))
		out.done = true
		out.gold = int(q.gold)
		if q.get("dream", false):
			Profile.join_character(ID)
			out.joined = true
	Profile._changed()
	return out


## An errand's fish: one caught before (by how rare - KIND_WEIGHT), the everyday fresh ones if none
## - not one already asked for.
static func pick_fish() -> String:
	var asked := quests().map(func(q): return str(q.fish))
	var by_kind := {"common": [], "uncommon": [], "rare": []}
	for id in FishData.FISH:
		if id == DREAM_FISH or id in asked or Profile.record("caught_" + str(id)) <= 0.0:
			continue
		by_kind[kind_of(id)].append(id)
	if (by_kind.common as Array).is_empty() and (by_kind.uncommon as Array).is_empty() and (by_kind.rare as Array).is_empty():
		var fresh := FishData.COMMON_FRESH.filter(func(f): return not f in asked)
		return fresh[randi() % fresh.size()] if not fresh.is_empty() else FishData.COMMON_FRESH[0]
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


## What errand `q` asks: "交給鱷魚先生 5 條鯉魚".
static func goal_text(q: Dictionary) -> String:
	return "交給鱷魚先生 %d 條%s" % [int(q.need), fish_name(str(q.fish))]


## Its count: "2/5".
static func count_text(q: Dictionary) -> String:
	return "%d/%d" % [int(q.given), int(q.need)]


## His first words in a talk.
static func hello() -> String:
	if done() == 0 and active().is_empty():
		return FIRST_HELLO
	return HELLO[randi() % HELLO.size()]
