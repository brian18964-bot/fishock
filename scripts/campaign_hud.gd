class_name CampaignHud
extends CanvasLayer

## User request (the campaign): over a level -
##   - the level's name and what it asks, under the event feed on the left:
##     getting out, and the ★★ / ★★★ conditions with how they stand now;
##   - Willow's tutorial (Campaign.TUTORIALS): one line at a time at the top
##     middle, the next once it's done (or after a while, for a line that
##     only tells);
##   - a guide arrow to where the line says to go: bobbing over it when it's
##     on screen, at the screen's edge pointing its way when it isn't;
##   - the level's name and opening words, big, as it starts.
## All drawn on one Node2D: cheap on a phone.

## (user report: at 150 the event feed's lines - StatusCard, down to 187 with a state's icons over
## them - were written across its title: under them now, the fish cards (FishAlerts) under it)
const PANEL_AT := Vector2(10, 190)
const PANEL_W := 236.0
const ROW := 19.0
const TEXT_SIZE := 12
## (user report: at 74 its right end ran under the light's box - HUD.EnergyView, down to 92)
const BOX_Y := 98.0
const BOX_Y_FIGHT := 164.0
const BOX_W := 520.0
const BOX_PAD := 10.0
const MEDAL := 40.0
## A step that's already done still shows this long before the next.
const MIN_SHOW := 1.4
## User request: Willow's line in the middle of the screen fades after a while - the guide arrow
## stays. Shown BOX_HOLD s, then gone over BOX_FADE s (a new line shows again). Her word on a lesson
## come up (Campaign.aside) the same, ASIDE_HOLD s.
const BOX_HOLD := 8.0
const BOX_FADE := 1.0
const ASIDE_HOLD := 9.0
const BANNER_TIME := 4.0
const CH_NUM := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二"]
const STAR_ON := Color(1.0, 0.82, 0.3)
const STAR_OFF := Color(0.42, 0.4, 0.36)
const OK := Color(0.72, 0.95, 0.55)
const BAD := Color(1.0, 0.55, 0.45)
const ARROW := Color(1.0, 0.86, 0.4)
## How far from the player an off-screen target's arrow circles.
const ORBIT := 74.0
## How far toward an off-screen target (px in the world) its way is read at.
const ARROW_STEP := 90.0

var steps: Array = []
var step := -1
var _step_time := 0.0
var _box_alpha := 0.0
var _t := 0.0
## Willow's word on a lesson, showing (from Campaign.aside_queue), and how long it has been.
var _aside := ""
var _aside_time := 0.0
var _level: Dictionary
var _view: Node2D


func _ready() -> void:
	layer = 4
	_level = Campaign.level(Campaign.level_id)
	steps = Campaign.tutorial_steps()
	_view = Node2D.new()
	_view.draw.connect(_draw_all)
	add_child(_view)
	_next_step()


## Where the objectives' panel ends, down the left (0 outside a level): FishAlerts' cards go under it.
static func panel_bottom() -> float:
	if not Campaign.is_level():
		return 0.0
	var conds: Array = Campaign.level(Campaign.level_id).get("stars", [])
	return PANEL_AT.y + 26.0 + ROW * (1 + conds.size()) + 4.0


func _next_step() -> void:
	step += 1
	_step_time = 0.0
	_box_alpha = 0.0


func _step_done(s: Array) -> bool:
	var until: Dictionary = s[1]
	if until.has("after"):
		return _step_time >= float(until.after)
	return Campaign.value(str(until.stat)) >= float(until.get("min", 1))


func _process(delta: float) -> void:
	_t += delta
	if step < steps.size():
		_step_time += delta
		_box_alpha = minf(1.0, _box_alpha + delta * 3.0)
		if _step_time >= MIN_SHOW and _step_done(steps[step]):
			_next_step()
	# (not over the level's opening card: after it)
	if _aside == "" and not Campaign.aside_queue.is_empty() and _t >= BANNER_TIME:
		_aside = str(Campaign.aside_queue.pop_front())
		_aside_time = 0.0
	if _aside != "":
		_aside_time += delta
		if _aside_time >= ASIDE_HOLD + BOX_FADE:
			_aside = ""
	_view.queue_redraw()


## How much of Willow's line shows now: in, held BOX_HOLD s, out.
static func hold_alpha(shown: float, hold: float) -> float:
	return clampf(minf(shown * 3.0, (hold + BOX_FADE - shown) / BOX_FADE), 0.0, 1.0)


func _draw_all() -> void:
	if GameState.run_over:
		return
	_draw_panel()
	if _aside != "":
		_draw_box([_aside, {}, ""], hold_alpha(_aside_time, ASIDE_HOLD), false)
	if step < steps.size():
		if _aside == "":
			_draw_box(steps[step], hold_alpha(_step_time, BOX_HOLD) * _box_alpha)
		var where := str(steps[step][2])
		if where != "":
			_draw_arrow(Campaign.target(where))
	if _t < BANNER_TIME:
		_draw_banner()


# ---------------------------------------------------------------- objectives

func _draw_panel() -> void:
	var conds: Array = _level.get("stars", [])
	var h := 26.0 + ROW * (1 + conds.size()) + 4.0
	var r := Rect2(PANEL_AT, Vector2(PANEL_W, h))
	_view.draw_rect(r, Color(0, 0, 0, 0.42))
	_view.draw_rect(Rect2(r.position, Vector2(2, h)), Color(STAR_ON, 0.8))
	var title := "%s　%s" % [_level.get("id", ""), _level.get("name", "")]
	UiKit.draw_text(_view, PANEL_AT + Vector2(10, 18), title, 14, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var y := PANEL_AT.y + 26.0
	# ★: out - the quota first, then the rune stones.
	var out_text := "湊滿額度，從渡石離開"
	var status := "%d/%d" % [int(GameState.quota_progress), int(GameState.quota_target)]
	var met := GameState.day_phase != GameState.DayPhase.FISHING
	if met:
		out_text = "去發光的渡石離開"
		status = ""
	_row(y, met, out_text, status, OK if met else UiKit.TEXT)
	y += ROW
	for c in conds:
		var st := _status(c)
		_row(y, Campaign.condition_met(c), str(c.text), st[0], st[1])
		y += ROW


func _row(y: float, lit: bool, text: String, status: String, status_color: Color) -> void:
	_star(Vector2(PANEL_AT.x + 16, y + 6), 6.5, STAR_ON if lit else STAR_OFF)
	UiKit.draw_text(_view, Vector2(PANEL_AT.x + 28, y + 11), text, TEXT_SIZE, UiKit.TEXT)
	if status != "":
		UiKit.draw_text(_view, Vector2(PANEL_AT.x, y + 11), status, TEXT_SIZE, status_color,
			HORIZONTAL_ALIGNMENT_RIGHT, PANEL_W - 8.0)


## How a ★★/★★★ condition stands: [words, colour].
func _status(c: Dictionary) -> Array:
	var key := str(c.stat)
	var v := Campaign.value(key)
	var ok := Campaign.condition_met(c)
	match key:
		"elapsed":
			return ["%s/%s" % [_clock(v), _clock(float(c.max))], OK if ok else BAD]
		"time_left":
			if GameState.day_duration <= 0.0:
				return ["", OK]
			return ["剩 %s" % _clock(v), OK if ok else BAD]
	if c.has("min"):
		return ["%d/%d" % [int(minf(v, float(c.min))), int(c.min)], OK if ok else UiKit.DIM]
	return ["✓" if ok else "✗", OK if ok else BAD]


static func _clock(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	return "%d:%02d" % [s / 60, s % 60]


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	_view.draw_colored_polygon(pts, color)


# ---------------------------------------------------------------- Willow's line

func _draw_box(s: Array, a := 1.0, counted := true) -> void:
	if a <= 0.0:
		return
	var text := Campaign.say(str(s[0]))
	var font := UiKit.font()
	var width := BOX_W - BOX_PAD * 2.0 - MEDAL - 10.0
	# (as many lines as it wraps to - a longer word of Willow's three or four - the box as tall)
	var lh := font.get_height(15)
	var lines := clampi(roundi(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 15).y / lh), 1, 4)
	var h := maxf(MEDAL + 8.0, 16.0 + lines * lh)
	# Under the fight panel while a fish is on (it takes the top middle).
	var y := BOX_Y
	if Campaign._player != null and Campaign._player.state == Player.State.REELING:
		y = BOX_Y_FIGHT
	var r := Rect2(480.0 - BOX_W / 2.0, y, BOX_W, h)
	_view.draw_rect(r, Color(0.05, 0.04, 0.03, 0.82 * a))
	_view.draw_rect(r, Color(0.62, 0.46, 0.17, 0.9 * a), false, 1.5)
	var medal_c := r.position + Vector2(BOX_PAD + MEDAL / 2.0, h / 2.0)
	_view.draw_circle(medal_c, MEDAL * 0.38, Color(0.12, 0.2, 0.12, a))
	_view.draw_texture_rect(UiKit.tex("medallion"), Rect2(medal_c - Vector2.ONE * MEDAL / 2.0, Vector2.ONE * MEDAL), false, Color(1, 1, 1, a))
	UiKit.draw_text(_view, medal_c + Vector2(-8, 6), "柳", 16, Color(UiKit.GOLD_BRIGHT, a), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var tx := r.position.x + BOX_PAD + MEDAL + 10.0
	var top := r.position.y + (h - lines * lh) / 2.0 + font.get_ascent(15)
	_view.draw_multiline_string_outline(font, Vector2(tx, top), text,
		HORIZONTAL_ALIGNMENT_LEFT, width, 15, lines, 4, Color(0, 0, 0, 0.85 * a))
	_view.draw_multiline_string(font, Vector2(tx, top), text,
		HORIZONTAL_ALIGNMENT_LEFT, width, 15, lines, Color(UiKit.TEXT, a))
	# Which line of how many.
	if counted:
		UiKit.draw_text(_view, Vector2(r.position.x, r.end.y + 13.0), "%d / %d" % [step + 1, steps.size()], 11,
			Color(UiKit.DIM, a), HORIZONTAL_ALIGNMENT_RIGHT, BOX_W - 6.0)


# ---------------------------------------------------------------- the arrow

func _draw_arrow(world: Vector2) -> void:
	if world == Vector2.INF:
		return
	var vp := _view.get_viewport()
	var screen: Vector2 = RunView3D.screen_point(vp, world)
	var size := vp.get_visible_rect().size
	var bob := sin(_t * 4.0) * 5.0
	if not RunView3D.behind_camera(world) and Rect2(Vector2.ZERO, size).grow(-20.0).has_point(screen):
		# Over it, pointing down - and (user request: the way plainer) a ring on the ground there,
		# widening and fading, again and again.
		for k in 2:
			var grow := fmod(_t * 0.7 + k * 0.5, 1.0)
			var rx := 20.0 + 26.0 * grow
			_view.draw_set_transform(screen, 0.0, Vector2(1.0, 0.5))
			_view.draw_arc(Vector2.ZERO, rx, 0.0, TAU, 40, Color(ARROW, 0.75 * (1.0 - grow)), 3.0, true)
			_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_chevron(screen + Vector2(0, -46.0 + bob), Vector2.DOWN, 1.5)
		return
	# Off screen: circling the player, pointing its way. (user report: after the offering, the way to
	# the stones pointed off at the forest's edge until walked back a little - the stones far down
	# the screen were behind the tilted camera, and a point behind it comes out mirrored: the way is
	# read off a point a short step from the player toward it, always in front)
	var from: Vector2 = Campaign._player.global_position
	var me: Vector2 = RunView3D.screen_point(vp, from)
	var dir := way_on_screen(vp, from, world)
	_chevron(me + Vector2(0, -16) + dir * (ORBIT + bob), dir, 1.6)


## The way on screen from `from` toward `to` (2D world points), read a short step toward it.
static func way_on_screen(vp: Viewport, from: Vector2, to: Vector2) -> Vector2:
	var me: Vector2 = RunView3D.screen_point(vp, from)
	var step_to := from + (to - from).limit_length(ARROW_STEP)
	return (RunView3D.screen_point(vp, step_to) - me).normalized()


func _chevron(tip_side: Vector2, dir: Vector2, s: float) -> void:
	var side := dir.orthogonal()
	var tip := tip_side + dir * 12.0 * s
	var back := tip_side - dir * 6.0 * s
	var pts := PackedVector2Array([tip, back + side * 13.0 * s, tip_side - dir * 1.0 * s, back - side * 13.0 * s])
	var outline := PackedVector2Array([tip + dir * 2.5, back + side * 16.0 * s - dir * 1.5,
		tip_side - dir * 3.5 * s, back - side * 16.0 * s - dir * 1.5])
	_view.draw_colored_polygon(outline, Color(0, 0, 0, 0.75))
	_view.draw_colored_polygon(pts, ARROW)


# ---------------------------------------------------------------- the opening

func _draw_banner() -> void:
	var a := clampf(minf(_t / 0.5, (BANNER_TIME - _t) / 0.8), 0.0, 1.0)
	var ch: Dictionary = Campaign.chapter(int(_level.get("chapter", 1)))
	# (six maps, six chapters - the sixth, 海崖, was shown as the fifth)
	var top := "第%s章　%s" % [CH_NUM[clampi(int(_level.chapter) - 1, 0, CH_NUM.size() - 1)], ch.get("name", "")]
	var r := Rect2(190, 146, 580, 122)
	_view.draw_rect(r, Color(0, 0, 0, 0.6 * a))
	_view.draw_rect(r, Color(0.62, 0.46, 0.17, 0.8 * a), false, 1.5)
	UiKit.draw_text(_view, Vector2(r.position.x, 174), top, 14, Color(UiKit.DIM, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiKit.draw_text(_view, Vector2(r.position.x, 208), "%s　%s" % [_level.id, _level.name], 28, Color(UiKit.GOLD_BRIGHT, a),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, true)
	var font := UiKit.font()
	var intro := str(_level.get("intro", ""))
	_view.draw_multiline_string_outline(font, Vector2(r.position.x + 16, 232), intro, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - 32, 14, 2, 3, Color(0, 0, 0, 0.8 * a))
	_view.draw_multiline_string(font, Vector2(r.position.x + 16, 232), intro, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - 32, 14, 2, Color(UiKit.TEXT, a))
