class_name CrocTalk
extends ColorRect

## User request: talking to Mr. Croc, as a game's quest giver is talked to - his window: his first
## words, then his errands in a list (the ones with fish to hand him, the new ones he offers, the
## ones under way), each with its sign; one tapped opens its page - its story, what it asks (with
## how much has been handed over: 2/5), the reward - and what can be done: take it, hand over the
## fish there are, give it up. (CrocQuests holds the errands; TitleScreen opens this.)

signal joined(gold: int)

const W := 500.0
## (the signs by each errand: one to hand fish over to, a new one, one under way)
const GIVE := Color(1.0, 0.8, 0.25)
const NEW := Color(1.0, 0.92, 0.55)
const UNDER_WAY := Color(0.62, 0.6, 0.55)

var _col: VBoxContainer
var _panel: PanelContainer


func _init() -> void:
	name = "CrocTalk"
	color = Color(0, 0, 0, 0.55)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var made := UiKit.window("鱷魚先生")
	_panel = made[0]
	_col = made[1]
	_panel.custom_minimum_size = Vector2(W, 0)
	_col.add_theme_constant_override("separation", 8)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_panel)
	add_child(center)
	show_list()


func _clear() -> void:
	for c in _col.get_children().slice(1):
		_col.remove_child(c)
		c.queue_free()


func _words(text: String, size := 16, colour := UiKit.TEXT) -> Label:
	var l := UiKit.label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 40.0
	_col.add_child(l)
	return l


## His window's first page: his words, his errands by what can be done with them.
func show_list(said := "") -> void:
	_clear()
	_words(said if said != "" else CrocQuests.hello(), 17)
	var ready := CrocQuests.ready_list()
	var offered := CrocQuests.offered()
	var waiting := CrocQuests.active().filter(func(q): return not q in ready)
	var any := false
	for group in [[ready, GIVE, "give"], [offered, NEW, "new"], [waiting, UNDER_WAY, "wait"]]:
		for q in group[0]:
			any = true
			_col.add_child(_entry(q, group[1], group[2]))
	if not any:
		_words("「今天沒什麼事，陪我看看湖就好。」", 15, UiKit.DIM)
	var bye := UiKit.button("再見", 16)
	bye.name = "Bye"
	bye.custom_minimum_size = Vector2(120, 42)
	bye.size_flags_horizontal = Control.SIZE_SHRINK_END
	bye.pressed.connect(queue_free)
	_col.add_child(bye)


## An errand in the list: its sign, its title, its count once it's under way.
func _entry(q: Dictionary, sign: Color, kind: String) -> Button:
	var b := Button.new()
	b.name = "Quest_%d" % int(q.id)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(W - 40.0, 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var mark := QuestSign.new()
	mark.kind = kind
	mark.tint = sign
	mark.custom_minimum_size = Vector2(28, 34)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var title := UiKit.label(str(q.title), 17, sign if kind != "wait" else UiKit.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	if q.taken:
		var n := UiKit.label("（%s）" % CrocQuests.count_text(q), 15, UiKit.DIM)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(n)
	b.add_child(row)
	var id := int(q.id)
	b.pressed.connect(func(): show_quest(id))
	return b


## Errand `id`'s page: its story, what it asks and how far along, the reward - take it / hand over
## what there is / give it up / back.
func show_quest(id: int, said := "") -> void:
	var q := CrocQuests.quest_by_id(id)
	if q.is_empty():
		show_list()
		return
	_clear()
	_words(str(q.title), 20, UiKit.GOLD_BRIGHT).name = "QuestTitle"
	_words("「%s」" % str(q.text), 16)
	_col.add_child(UiKit.divider(W - 40.0))
	_words("委託內容", 14, UiKit.GOLD)
	var goal := _words("%s（%s）" % [CrocQuests.goal_text(q), CrocQuests.count_text(q)] if q.taken else CrocQuests.goal_text(q), 16)
	goal.name = "Goal"
	if q.taken:
		var have := CrocQuests.fish_for(q)
		if have.is_empty():
			_words("營地裡還沒有可以交的%s。" % CrocQuests.fish_name(str(q.fish)), 14, UiKit.DIM)
		else:
			var where := {}
			for h in have:
				where[h.where] = int(where.get(h.where, 0)) + 1
			var parts := []
			for w in where:
				parts.append("%s %d" % [w, where[w]])
			_words("可以交 %d 條（%s）——上鎖的魚和金色的魚不會交出去。" % [have.size(), "、".join(parts)], 14, UiKit.USE)
	_words("獎勵", 14, UiKit.GOLD)
	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 8)
	reward.add_child(UiKit.gold_label(int(q.gold), 17))
	_col.add_child(reward)
	if said != "":
		_words("鱷魚先生：「%s」" % said, 15, UiKit.GOLD_BRIGHT).name = "Said"
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_END
	acts.add_theme_constant_override("separation", 8)
	if not q.taken:
		var why := CrocQuests.cant_take(id)
		var take := _button("接受委託", "Take", "red", acts)
		take.disabled = why != ""
		take.pressed.connect(func():
			CrocQuests.take(id)
			show_list("好，就拜託你了。"))
		if why != "":
			_words(why, 14, Color(0.95, 0.55, 0.4))
	else:
		var n := mini(CrocQuests.fish_for(q).size(), int(q.need) - int(q.given))
		var give := _button("交出 %d 條" % n if n > 0 else "交出", "Give", "red", acts)
		give.disabled = n <= 0
		give.pressed.connect(func(): _give(id))
		var drop := _button("放棄委託", "GiveUp", "gray", acts)
		drop.pressed.connect(func():
			CrocQuests.give_up(id)
			show_list("沒關係，下次吧。"))
	_button("返回", "Back", "gray", acts).pressed.connect(func(): show_list())
	_col.add_child(acts)


func _button(text: String, node_name: String, kind: String, into: Control) -> Button:
	var b := UiKit.button(text, 16, kind)
	b.name = node_name
	b.custom_minimum_size = Vector2(110, 42)
	into.add_child(b)
	return b


## Hands over errand `id`'s fish there are: done, paid (and, his own errand done, he joins); part
## of it, the page again with the new count.
func _give(id: int) -> void:
	var got := CrocQuests.give(id)
	if got.is_empty():
		return
	Sfx.play("coins" if got.done else "ui_click", -4.0)
	if got.joined:
		joined.emit(int(got.gold))
		queue_free()
		return
	if got.done:
		show_list("%s（獲得 %d 金幣）" % [CrocQuests.THANKS[randi() % CrocQuests.THANKS.size()], int(got.gold)])
	else:
		show_quest(id, CrocQuests.MORE[randi() % CrocQuests.MORE.size()])


## An errand's sign in the list: a rolled scroll (QuestScroll) - gold with a tick to hand over to,
## bright for a new one, grey for one under way.
class QuestSign extends Control:
	var kind := "new"
	var tint := Color.WHITE

	func _draw() -> void:
		QuestScroll.draw(self, Rect2(Vector2.ZERO, size), tint if kind != "wait" else Color(0.6, 0.58, 0.52), kind == "give")
