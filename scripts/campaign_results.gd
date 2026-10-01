class_name CampaignResults
extends ColorRect

## User request (the campaign): a level's end - its three stars (the new
## ones flare up), what each one asked and whether it was done, what was
## earned (gold, items, achievements), what happened to the fish, and the
## way on: try again, the next level, or back to the camp. Read off
## Campaign.result (Campaign.finish(), run on the same signal first).

const STAR_ON := Color(1.0, 0.82, 0.3)
const STAR_OFF := Color(0.3, 0.27, 0.23)
const INK := Color(0.23, 0.14, 0.06)
const INK_DIM := Color(0.4, 0.3, 0.2)

var success := false
var message := ""
var _stars: Control
var _t := 0.0


static func show_for(parent: Control, won: bool, text: String) -> CampaignResults:
	var r := CampaignResults.new()
	r.name = "CampaignResults"
	r.success = won
	r.message = text
	parent.add_child(r)
	return r


func _ready() -> void:
	color = Color(0, 0, 0, 0.6)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var res: Dictionary = Campaign.result
	var lv := Campaign.level(str(res.get("level", Campaign.level_id)))
	var scroll := PanelContainer.new()
	scroll.add_theme_stylebox_override("panel", UiKit.parchment_box())
	scroll.custom_minimum_size = Vector2(560, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var head := UiKit.label("%s　%s" % [lv.get("id", ""), lv.get("name", "")], 15, INK_DIM, false, 0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var title := UiKit.label("通關！" if success else "失敗了", 28, Color(0.36, 0.1, 0.04) if success else Color(0.45, 0.06, 0.04), true, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_stars = Control.new()
	_stars.name = "Stars"
	_stars.custom_minimum_size = Vector2(500, 64)
	_stars.draw.connect(_draw_stars)
	col.add_child(_stars)
	# Each star's condition, done or not.
	var conds: Array = [{"text": "從符文石成功離開"}]
	conds.append_array(lv.get("stars", []))
	var got: Array = res.get("stars", [false, false, false])
	var before: Array = Profile.level_stars(str(lv.get("id", "")))
	for i in conds.size():
		var done: bool = bool(got[i]) if i < got.size() else false
		var kept: bool = bool(before[i])
		var mark := "✓" if done else ("（已取得）" if kept else "✗")
		var line := UiKit.label("★%s　%s　%s" % ["★".repeat(i), str(conds[i].text), mark], 15,
			Color(0.2, 0.4, 0.1) if done or kept else INK_DIM, false, 0)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(line)
	col.add_child(UiKit.divider(420))
	# What was earned.
	var earned := []
	if int(res.get("gold", 0)) > 0:
		earned.append("金幣 +%d" % int(res.gold))
	var items: Dictionary = res.get("items", {})
	for id in items:
		earned.append("%s ×%d" % [Items.name_of(id), int(items[id])])
	if not earned.is_empty():
		var reward := UiKit.label(("首次通關獎勵：" if res.get("first_clear", false) else "獎勵：") + "、".join(earned), 16,
			Color(0.45, 0.3, 0.02), true, 0)
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(reward)
	if res.get("chapter_full", false):
		var full := UiKit.label("這一章全部三星！額外 +%d 金幣" % Campaign.CHAPTER_GOLD, 15, Color(0.45, 0.3, 0.02), true, 0)
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(full)
	for id in res.get("achievements", []):
		var a := Campaign.achievement(id)
		var ach := UiKit.label("成就達成：%s（+%d 金幣）" % [a[2], int(a[4])], 15, Color(0.3, 0.2, 0.5), true, 0)
		ach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ach)
	if res.get("chapter_done", false):
		var nxt := Campaign.next_level(str(lv.id))
		var words := "第%d章完成！" % int(lv.chapter)
		if not nxt.is_empty():
			words += "下一章「%s」" % Campaign.chapter(int(nxt.chapter)).get("name", "")
			if not Campaign.chapter_open(int(nxt.chapter)):
				words += "需要 %d 顆星" % int(Campaign.chapter(int(nxt.chapter)).stars)
		if lv.id == "1-5":
			words += "　自由夜釣已開放"
		var done_l := UiKit.label(words, 15, INK, true, 0)
		done_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(done_l)
	var body := UiKit.label(message.strip_edges(), 14, INK_DIM, false, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 500
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)
	if not success:
		var tip := UiKit.label("這一關教的是：" + str(lv.get("teach", "")), 14, INK, false, 0)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size.x = 500
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tip)
	# The way on.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var retry := UiKit.button("再試一次", 17)
	retry.name = "Retry"
	retry.custom_minimum_size = Vector2(140, 46)
	retry.pressed.connect(func(): _play(str(lv.id)))
	row.add_child(retry)
	var nxt_level := Campaign.next_level(str(lv.id))
	if success and not nxt_level.is_empty() and Campaign.level_open(str(nxt_level.id)):
		var go := UiKit.button("下一關 ▶", 17, "red")
		go.name = "Next"
		go.custom_minimum_size = Vector2(150, 46)
		go.pressed.connect(func(): _play(str(nxt_level.id)))
		row.add_child(go)
	var home := UiKit.button("回營地", 17)
	home.name = "BackHome"
	home.custom_minimum_size = Vector2(130, 46)
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))
	row.add_child(home)
	col.add_child(row)
	scroll.add_child(col)
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.modulate.a = 0.0
	create_tween().tween_property(scroll, "modulate:a", 1.0, 0.4)


## Straight into level `id` (no walk back through the camp).
func _play(id: String) -> void:
	Campaign.begin_level(id)
	GameState.start_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> void:
	_t += delta
	if _stars != null:
		_stars.queue_redraw()


func _draw_stars() -> void:
	var res: Dictionary = Campaign.result
	var got: Array = res.get("stars", [false, false, false])
	var new_ones: Array = res.get("new_stars", [])
	var before: Array = Profile.level_stars(Campaign.level_id)
	var w := _stars.size.x
	for i in 3:
		var c := Vector2(w / 2.0 + (i - 1) * 70.0, 34.0 - (6.0 if i == 1 else 0.0))
		# One after another.
		var appear := clampf((_t - 0.3 - i * 0.35) / 0.3, 0.0, 1.0)
		var lit: bool = bool(got[i]) or bool(before[i])
		var r := (24.0 if i == 1 else 20.0) * (1.0 + (1.0 - appear) * 0.6 if lit else 1.0)
		_star(c, r + 3.0, Color(0.15, 0.1, 0.05, 0.8))
		_star(c, r, STAR_ON if lit and appear > 0.0 else STAR_OFF)
		if i in new_ones and appear >= 1.0:
			var glow := 0.5 + 0.5 * sin(_t * 5.0)
			_stars.draw_arc(c, r + 8.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.5 * glow), 2.0)


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	_stars.draw_colored_polygon(pts, color)
