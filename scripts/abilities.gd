class_name Abilities
extends RefCounted

## User request: each character its own ability (and its own story - told
## at the camp's fire, CharacterPage). The two of a kind (the two owls, the
## two dogs...) share their kind's ability; each has its own story.
##   cat    夜貓子    night fallen (GameState.is_night - the dragon ghost
##                   out), CAT_NIGHT_SPEED as fast on its feet
##   owl    夜視      no light of its own (the lamp or the flashlight out,
##                   no glow mushroom on), OWL_DARK_SIGHT the brightness
##                   (RunView3D: the whole view's exposure)
##   dog    敏感嗅覺  every DOG_SNIFF_STEP px walked, DOG_SNIFF_CHANCE it
##                   sniffs something out close by - a "!" over its head,
##                   the thing there with its name (DOG_FINDS); picked up
##                   or left, as the player likes (Player._sniff)
##   bear   展現力量  the first strike after each cast, BEAR_CHANCE it
##                   takes BEAR_WEAR of the fish's stamina at once
##   deer   森林友好  rare (and better) fish DEER_RARE more likely
##   sheep  採集高手  gathering a plant on the map (the glow mushroom),
##                   SHEEP_CHANCE of two
##   croc   水中霸王  the fish worn down to CROC_AT of its stamina,
##                   CROC_CHANCE (once a fight) it's hauled straight in
## Each shows on the run's character card (StatusCard: lit while it's
## working, flashing when it goes off) and goes off with its own show
## (Player.ability_triggered -> RunView3D.ability_fx).

const CAT_NIGHT_SPEED := 1.15
const OWL_DARK_SIGHT := 1.2
const DOG_SNIFF_STEP := 360.0
const DOG_SNIFF_CHANCE := 0.10
## What the dog may turn up: [item, how many] - live baits that don't run
## off, and the glow mushroom.
const DOG_FINDS := [["live_worm", 2], ["live_cricket", 1], ["glow_mushroom", 1]]
const BEAR_CHANCE := 0.10
const BEAR_WEAR := 0.15
const DEER_RARE := 0.05
const SHEEP_CHANCE := 0.10
const CROC_AT := 0.10
const CROC_CHANCE := 0.05

const ICONS := "res://assets/ui/abilities/%s.svg"
## Each kind's: its name, what it does, the colour its show goes off in.
const KINDS := {
	"cat": {"name": "夜貓子", "desc": "夜晚降臨（龍鬼出沒）後，移動速度提高 15%。", "color": Color(0.78, 0.62, 1.0)},
	"owl": {"name": "夜視", "desc": "身上沒有任何光源（煤燈、手電筒熄滅，也沒有發光蘑菇）時，整個畫面亮度提高 20%。",
		"color": Color(1.0, 0.78, 0.35)},
	"dog": {"name": "敏感嗅覺", "desc": "走路時每走一段路，有 10% 機率嗅到附近的東西：頭上冒出驚嘆號，道具出現在附近（活餌或發光蘑菇），要不要撿自己決定。",
		"color": Color(1.0, 0.9, 0.3)},
	"bear": {"name": "展現力量", "desc": "每次拋竿後第一次刺魚時，有 10% 機率再多扣魚 15% 的體力。",
		"color": Color(1.0, 0.45, 0.3)},
	"deer": {"name": "森林友好", "desc": "稀有以上的魚出現機率提高 5%。", "color": Color(0.55, 1.0, 0.55)},
	"sheep": {"name": "採集高手", "desc": "採集地圖上的植物（例如發光蘑菇）時，有 10% 機率拿到雙倍。",
		"color": Color(0.95, 0.95, 0.8)},
	"croc": {"name": "水中霸王", "desc": "搏魚時，魚的體力剩下 10% 時，有 5% 機率直接把魚拉上岸。",
		"color": Color(0.45, 0.85, 1.0)},
}

## Each one's story (user request), by character.
const STORIES := {
	"cat": "沒有人知道黑貓從哪裡來。牠總在月亮最圓的晚上出現在營火邊，舔著爪子，好像早就認識這裡的每一個人。\n大家說，牠走過的渡石從來不會熄滅；越是黑的夜，牠的腳步越輕。",
	"owl": "雪鴞來自極北的冰原，那裡的冬天沒有白晝。\n牠學會在黑暗裡看清每一道水紋，所以從不帶太亮的燈——光太亮，反而會把真正想看的東西嚇跑。",
	"owl2": "角鴞住在老橡樹的樹洞裡，聽了一輩子森林的夜話。\n牠說，鬼也會說話，只是聲音太小，只有在燈熄了以後才聽得見。",
	"dog": "吉娃娃個子小，膽子卻比誰都大。牠曾經一路嗅著味道，在夜裡追著一條魚的腥味走了三個山頭。\n牠的鼻子從不說謊：哪裡有好東西，牠總是第一個知道。",
	"dog3": "牧羊犬替老牧人看了一輩子的羊群，牧人走後，牠帶著那根舊釣竿上路。\n牠不怕黑，只怕走散——所以每走一段路，總會停下來嗅一嗅，確定大家都還在。",
	"bear": "棕熊年輕時在激流裡徒手抓鮭魚，一掌就能把魚拍上岸。\n後來牠學會了用釣竿，但每當魚上鉤，那股想一把拉起來的蠻力，還是藏不住。",
	"bear2": "台灣黑熊胸前那道白色的月牙，是山神留給牠的記號。\n牠從高山的溪源一路走下來，聽說渡石的另一邊，有一條從沒見過的大魚。",
	"deer": "紅鹿是森林的老朋友，樹會替牠讓路，溪流會替牠指路。\n牠站在水邊的時候，連最害羞的稀有魚，也會游近一點來看看牠。",
	"deer2": "梅花鹿背上的白點，據說是一場流星雨落下的痕跡。\n牠安靜、溫柔，森林裡的生靈都信任牠——連水裡那些罕見的魚，也願意為牠浮上來。",
	"sheep": "綿羊看起來慢吞吞的，卻是採集的好手：哪一片草地長了什麼，牠閉著眼睛都知道。\n牠的毛裡總是藏著一些亂七八糟的寶貝，是一路上順手摘的。",
	"sheep2": "黑面羊來自霧氣很重的高地，從小在石縫裡找吃的。\n牠說，好東西都長在別人看不見的地方——低頭多看一眼，常常就有兩份。",
	"croc": "鱷魚在水裡活了比誰都久，牠懂魚的每一個念頭。\n當魚累了、想喘口氣的那一瞬間，牠就知道——那是收線的時候。",
}


## (tests: every chance comes up)
static var forced := false


## A chance come up (`chance` of the time).
static func roll(chance: float) -> bool:
	return forced or randf() < chance


## A character's kind ("owl2" -> "owl").
static func species(id: String) -> String:
	var k := id
	while k.length() > 0 and k[k.length() - 1] >= "0" and k[k.length() - 1] <= "9":
		k = k.substr(0, k.length() - 1)
	return k


## The kind of ability `id` has ("" none).
static func kind_of(id := "") -> String:
	var k := species(id if id != "" else Profile.character)
	return k if KINDS.has(k) else ""


## Whether the one travelling now has `kind`'s ability.
static func has(kind: String) -> bool:
	return kind_of() == kind


static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, {})


static func story(id: String) -> String:
	return STORIES.get(id, "")


static var _icons := {}


static func icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		var path := ICONS % kind
		_icons[kind] = load(path) if ResourceLoader.exists(path) else null
	return _icons[kind]


## Whether `kind`'s ability is working on `p` now (the cat at night, the owl
## in the dark); the ones that go off by chance always "ready".
static func active(kind: String, p: Player) -> bool:
	match kind:
		"cat":
			return GameState.is_night
		"owl":
			return p != null and p.unlit()
	return true
