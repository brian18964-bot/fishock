class_name QuestTracker
extends Control

## User request: the errands taken from Mr. Croc listed down the left - at camp and out on a run -
## each with how many of its fish have been handed over (2/5); out on a run, how many of them are
## being carried too. In a level it sits under the level's objectives (CampaignHud), as they're drawn;
## the fish alerts' cards go under it (FishAlerts._at).

const W := 236.0
const ROW := 19.0
const HEAD := 26.0
const TEXT_SIZE := 12
const REFRESH := 0.5
## (on a run: where it starts when there's nothing above it - the level's objectives' place)
const RUN_AT := Vector2(10, 190)
const DONE := Color(0.72, 0.95, 0.55)
const CARRIED := Color(0.55, 0.85, 1.0)

## Out on a run (the carried fish counted).
var in_run := false
var _t := 0.0


func _init(run := false) -> void:
	in_run = run
	name = "QuestTracker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if in_run:
		position = run_at()
	_fit()


## Where it starts on a run: under the level's objectives, if any.
static func run_at() -> Vector2:
	return Vector2(RUN_AT.x, maxf(RUN_AT.y, CampaignHud.panel_bottom() + 6.0))


## How tall it is with `n` errands (0: nothing shown).
static func height_for(n: int) -> float:
	return 0.0 if n <= 0 else HEAD + ROW * n + 4.0


## (on a run: where what's under it starts - FishAlerts)
static func run_bottom() -> float:
	var n := CrocQuests.active().size()
	return run_at().y + height_for(n) if n > 0 else 0.0


func _fit() -> void:
	var n := CrocQuests.active().size()
	visible = n > 0
	size = Vector2(W, height_for(n))
	queue_redraw()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH
		_fit()


## How many of errand `q`'s fish are being carried (on a run).
static func carried(q: Dictionary) -> int:
	var n := 0
	for f in GameState.carried_fish + GameState.oxy_fish:
		if str(f.get("id", "")) == str(q.fish) and FishLife.state(f) != "rotten" and not f.get("golden", false):
			n += 1
	return n


func _draw() -> void:
	var list := CrocQuests.active()
	if list.is_empty():
		return
	var h := height_for(list.size())
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, h)), Color(0, 0, 0, 0.42))
	draw_rect(Rect2(Vector2.ZERO, Vector2(2, h)), Color(QuestScroll.PAPER, 0.85))
	QuestScroll.draw(self, Rect2(Vector2(7, 3), Vector2(16, 20)))
	UiKit.draw_text(self, Vector2(28, 18), "鱷魚先生的委託", 14, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var y := HEAD
	for q in list:
		var done := int(q.given) >= int(q.need)
		UiKit.draw_text(self, Vector2(12, y + 11), "%d 條%s" % [int(q.need), CrocQuests.fish_name(str(q.fish))], TEXT_SIZE, UiKit.TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, W - 100.0)
		var status := "（%s）" % CrocQuests.count_text(q)
		var colour := DONE if done else UiKit.TEXT
		if in_run:
			var c := carried(q)
			if c > 0:
				UiKit.draw_text(self, Vector2(0, y + 11), "身上 %d" % c, TEXT_SIZE, CARRIED, HORIZONTAL_ALIGNMENT_RIGHT, W - 58.0)
		UiKit.draw_text(self, Vector2(0, y + 11), status, TEXT_SIZE, colour, HORIZONTAL_ALIGNMENT_RIGHT, W - 8.0)
		y += ROW
