class_name Camp3D
extends "res://scripts/proto3d.gd"

## User request: the walkable 3D lakeside camp (the trial, proto3d.gd) is
## the main screen now; the old camp (scenes/title_screen.tscn) is kept, a
## button away (舊營地). Walk about with the left stick, or tap a thing:
## the traveller walks over and does it, then its page opens -
##   the fire       warms its hands (then the next traveller round it)
##   a log          sits down on it (till the stick's touched)
##   the crate      opens its lid - the warehouse
##   the pack       rummages through it - the warehouse
##   the tent       ducks in to tidy - the equipment
##   the fish drum  crouches to look in - the fish tank
##   the merchant   a word with him - the shop
##   the 渡石        a moment before it - the journey (and setting off)
## Coming near a thing its name shows over it. No stone place or stepping
## stones on the ground (user request), no grass strewn (walked through);
## the drum half as big again, the tent, crate, pack and fire bigger.

const SCENE := "res://scenes/camp3d.tscn"
const OLD_CAMP := "res://scenes/title_screen.tscn"
## How near (m) a thing's name shows; how far (screen px) a tap may miss it.
const NAME_NEAR := 3.0
const TAP_REACH := 70.0
const WALK_STICK := 0.42
const MERCHANT_AT := Vector3(4.6, 0, -5.6)

## name -> {label (shown), node, stand (where the traveller stands),
## face (what it faces), clip, time (s), page ("" none), then (Callable)}
var spots := {}
var page: Control
var _layer: CanvasLayer
var _labels := {}
var _merchant: Node3D
var _merchant_anim: AnimationPlayer
## The errand on: [spot name, "walk"/"act"/"sit"], the act's time left.
var _errand := []
var _act_left := 0.0
var _sat := false
var _pressed_at := Vector2(-1, -1)
var _fade: ColorRect
var _toast: Label
var _toast_left := 0.0
var _best_near := INF
var _stuck := 0.0


func _init() -> void:
	stones = false
	strew = false
	prop_scale = {"drum_trough": 1.5, "tent": 1.25, "crate": 1.25, "backpack": 1.3, "campfire": 1.2}


func _ready() -> void:
	Campaign.clear()
	GameState.reset_run()
	Engine.max_fps = TitleScreen.MENU_FPS
	Sfx.ambience("amb_camp")
	Sfx.music("music_camp")
	# (the one travelling may be a character not fetched yet on the web -
	# fetched first behind a cover; failing that, the first one)
	if not CharacterPacks.has(Profile.character):
		var cover := CharacterPacks.cover(_cover_parent(), Profile.character)
		var got: bool = await CharacterPacks.wait_for(Profile.character)
		cover.queue_free()
		if not got:
			Profile.character = Profile.CHARACTERS[0][0]
	super._ready()
	_add_merchant()
	_make_spots()
	_camp_hud()
	Profile.arrive_at_camp()
	var back := GameState.last_return
	GameState.last_return = ""
	if back != "":
		_say("平安回到營地" if back == "escape" else "在營火旁醒來……")
	if not Profile.tank_news.is_empty():
		var names: Array = Profile.tank_news.duplicate()
		Profile.clear_tank_news()
		_say("將 %s 放進魚缸" % "、".join(names.slice(0, 6)))
	if OS.has_feature("web") and not TitleScreen.sound_unlocked:
		_tap_to_start()
	CharacterPacks.fetch(Profile.character_after())


func _cover_parent() -> Control:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 5
		add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	return root


# ---------------------------------------------------------------- the places

func _add_merchant() -> void:
	var path := "res://assets/models/camp/frog_merchant.glb"
	if not ResourceLoader.exists(path):
		return
	_merchant = (load(path) as PackedScene).instantiate()
	_merchant.name = "Merchant"
	add_child(_merchant)
	var box := RunView3D._aabb(_merchant)
	var k := 1.05 / maxf(box.size.y, 0.001)
	_merchant.scale = Vector3.ONE * k
	_merchant.position = MERCHANT_AT - Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	_merchant.rotation.y = atan2(PLAZA.x - MERCHANT_AT.x, PLAZA.z - MERCHANT_AT.z)
	var aps := _merchant.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_merchant_anim = aps[0]
		for a in _merchant_anim.get_animation_list():
			_merchant_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if _merchant_anim.has_animation("Idle"):
			_merchant_anim.play("Idle")
	_block(MERCHANT_AT, 0.5)
	places["merchant"] = _merchant


func _make_spots() -> void:
	var fire: Node3D = places.get("fire")
	if fire != null:
		_spot("fire", "營火", fire.position, fire.position + Vector3(0.0, 0, 1.45), "Crouch_Idle", 1.6, "",
			_next_traveller)
	for k in 2:
		var log: Node3D = places.get("log_%d" % k)
		if log == null:
			continue
		# (stood just in front of it, facing the fire; sat, the hips go back
		# onto it)
		var face := (PLAZA - log.position).normalized()
		_spot("log_%d" % k, "坐木", log.position, log.position + face * 0.33, "", 0.0, "")
		spots["log_%d" % k].face = log.position + face * 3.0
		spots["log_%d" % k].sit = true
	var crate: Node3D = places.get("crate")
	if crate != null:
		_spot("crate", "倉庫", crate.position, crate.position + Vector3(0.9, 0, 0.7), "Chest_Open", 1.4, "warehouse")
	var pack: Node3D = places.get("backpack")
	if pack != null:
		_spot("backpack", "背包", pack.position, pack.position + Vector3(0.6, 0, 0.8), "Fixing_Kneeling", 2.2, "warehouse")
	var trough: Node3D = places.get("drum_trough")
	if trough != null:
		_spot("trough", "魚缸", trough.position, trough.position + Vector3(0.4, 0, 1.3), "Crouch_Idle", 1.6, "fish_tank")
	var tent: Node3D = places.get("tent")
	if tent != null:
		_spot("tent", "帳篷", tent.position, tent.position + Vector3(-2.3, 0, 0.3), "Interact", 2.0, "equipment")
	if _merchant != null:
		_spot("merchant", "商人", MERCHANT_AT, MERCHANT_AT + (PLAZA - MERCHANT_AT).normalized() * 1.3, "Idle_Talking", 1.8, "shop")
	var stone: Node3D = places.get("stone")
	if stone != null:
		_spot("stone", "渡石：出發", stone.position, stone.position + Vector3(0.6, 0, 1.4), "Pray", 1.6, "journey")
	# Their names, shown when near.
	for name in spots:
		var l := Label3D.new()
		l.text = spots[name].label
		l.font = UiKit.font(true)
		l.font_size = 44
		l.outline_size = 10
		l.modulate = Color(1.0, 0.86, 0.5)
		l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
		l.pixel_size = 0.0045
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = (spots[name].at as Vector3) + Vector3(0, 1.9 if name in ["tent", "stone", "merchant"] else 1.3, 0)
		l.modulate.a = 0.0
		add_child(l)
		_labels[name] = l


func _spot(name: String, label: String, at: Vector3, stand: Vector3, clip: String, time: float, to_page: String,
		then: Callable = Callable()) -> void:
	stand.y = 0.0
	# (just clear of whatever's solid there, toward where it was asked for)
	for _pass in 3:
		for b in blockers:
			var off: Vector3 = stand - b[0]
			off.y = 0.0
			var r: float = b[1] + 0.32
			if off.length() < r:
				stand = b[0] + (off.normalized() if off.length() > 0.01 else Vector3.BACK) * r
	spots[name] = {"label": label, "at": at, "stand": stand, "face": at, "clip": clip, "time": time,
		"page": to_page, "then": then, "sit": false}


# ---------------------------------------------------------------- the screen

func _camp_hud() -> void:
	# (the trial's own title, hint and back button go: this is the camp)
	for c in get_children():
		if c is CanvasLayer and c != _layer:
			for n in c.get_children():
				if n is Label or n is Button:
					n.queue_free()
	if _layer == null:
		_cover_parent()
	var card := UiKit.label("", 18, UiKit.GOLD_BRIGHT, true, 3)
	card.name = "PlayerCard"
	card.position = Vector2(16, 12)
	_layer.add_child(card)
	_refresh_card()
	Profile.profile_changed.connect(_refresh_card)
	var hint := UiKit.label("輕觸營地裡的東西：走過去使用　｜　渡石：出發夜釣", 13, UiKit.DIM, false, 2)
	hint.position = Vector2(16, 42)
	hint.name = "Hint"
	_layer.add_child(hint)
	var old := UiKit.button("舊營地", 15, "gray")
	old.name = "OldCamp"
	old.position = Vector2(836, 12)
	old.custom_minimum_size = Vector2(108, 38)
	old.pressed.connect(func(): get_tree().change_scene_to_file(OLD_CAMP))
	_layer.add_child(old)
	_toast = UiKit.label("", 17, UiKit.GOLD_BRIGHT, true, 4)
	_toast.position = Vector2(0, 470)
	_toast.size = Vector2(960, 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_layer.add_child(_toast)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.03, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _refresh_card() -> void:
	var card := _layer.get_node_or_null("PlayerCard") as Label if _layer != null else null
	if card != null:
		card.text = "釣客・%s　　精神 %d" % [Profile.character_name(), roundi(Profile.spirit)]


func _say(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast_left = 3.5


## The browser keeps a page quiet till it's touched: a tap lets the sound in.
func _tap_to_start() -> void:
	var cover := ColorRect.new()
	cover.name = "TapToStart"
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.color = Color(0.02, 0.027, 0.043, 0.85)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(cover)
	var words := UiKit.label("輕觸畫面進入遊戲", 24, Color(0.91, 0.76, 0.35), true, 5)
	words.set_anchors_preset(Control.PRESET_CENTER)
	words.position = Vector2(380, 250)
	cover.add_child(words)
	cover.gui_input.connect(func(e: InputEvent):
		if not (e is InputEventMouseButton or e is InputEventScreenTouch):
			return
		cover.accept_event()
		if e.pressed:
			return
		TitleScreen.sound_unlocked = true
		Sfx.play("ui_open", -6.0)
		cover.queue_free())


# ---------------------------------------------------------------- pages

## The page over the camp (the same pages the old camp opens).
func open_page(to: String) -> void:
	if page != null:
		page.queue_free()
		page = null
	Sfx.play("ui_open", -6.0)
	var p: Control = load("res://scenes/%s.tscn" % to).instantiate()
	p.set_meta("over_camp", true)
	p.set_meta("camp", self)
	p.modulate.a = 0.0
	page = p
	_layer.add_child(p)
	_layer.move_child(_fade, -1)
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.25)


func close_page() -> void:
	if page != null:
		page.queue_free()
		page = null
		Sfx.play("ui_close", -8.0)
	_refresh_card()


func depart_level(id: String) -> void:
	close_page()
	Campaign.begin_level(id)
	_set_off()


func depart_free(curses: Array = []) -> void:
	close_page()
	Campaign.begin_free(curses)
	_set_off()


## Off through the 渡石's light: the camp fades, the run starts.
func _set_off() -> void:
	_errand = ["", "leaving"]
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		Profile.leave_camp()
		GameState.start_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))


# ---------------------------------------------------------------- errands

func _unhandled_input(event: InputEvent) -> void:
	if page != null or (not _errand.is_empty() and _errand[1] == "leaving"):
		return
	var at := Vector2(-1, -1)
	var down := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
		down = event.pressed
	elif event is InputEventScreenTouch:
		at = event.position
		down = event.pressed
	else:
		return
	if down:
		_pressed_at = at
		return
	# (a tap: let go about where it came down)
	if _pressed_at.x < 0.0 or _pressed_at.distance_to(at) > 24.0:
		return
	_pressed_at = Vector2(-1, -1)
	var hit := spot_at(at)
	if hit != "":
		go_do(hit)


## The thing under a tap at `screen` ("" none).
func spot_at(screen: Vector2) -> String:
	var best := ""
	var near := TAP_REACH * get_viewport().get_visible_rect().size.y / 540.0
	for name in spots:
		var p: Vector3 = (spots[name].at as Vector3) + Vector3(0, 0.6, 0)
		if camera.is_position_behind(p):
			continue
		var d := camera.unproject_position(p).distance_to(screen)
		if d < near:
			near = d
			best = name
	return best


## Walks over to `name` and does it (then its page).
func go_do(name: String) -> void:
	if not spots.has(name):
		return
	if _sat:
		_sat = false
	_errand = [name, "walk"]
	_best_near = INF
	_stuck = 0.0


func _input_dir() -> Vector2:
	var manual := super._input_dir()
	if manual.length() > 0.05:
		# (the stick or the keys: whatever it was doing, it's off)
		if not _errand.is_empty() and _errand[1] != "leaving":
			_errand = []
		_sat = false
		return manual
	if _errand.is_empty() or _errand[1] != "walk" or pivot == null:
		return Vector2.ZERO
	var s: Dictionary = spots[_errand[0]]
	var to: Vector3 = s.stand - pivot.position
	to.y = 0.0
	# (there - or as near as it gets: no nearer for a while)
	if to.length() < _best_near - 0.02:
		_best_near = to.length()
		_stuck = 0.0
	else:
		_stuck += get_process_delta_time()
	if to.length() < 0.15 or (_stuck > 0.6 and to.length() < 1.5):
		_arrive()
		return Vector2.ZERO
	# (round what's in the way: veering off past anything solid on the line)
	var dir := Vector2(to.x, to.z).normalized()
	var pos := Vector2(pivot.position.x, pivot.position.z)
	for b in blockers:
		var rel := Vector2(b[0].x, b[0].z) - pos
		var along := rel.dot(dir)
		if along <= 0.0 or along > to.length():
			continue
		var perp := rel - dir * along
		var room: float = float(b[1]) + 0.45
		if perp.length() < room:
			var away := -perp.normalized() if perp.length() > 0.01 else dir.orthogonal()
			dir = (dir + away * (1.0 - perp.length() / room) * 1.6).normalized()
	return dir * minf(WALK_STICK, to.length() * 0.6 + 0.12)


func _arrive() -> void:
	var s: Dictionary = spots[_errand[0]]
	var face: Vector3 = s.face - pivot.position
	pivot.rotation.y = atan2(face.x, face.z)
	if s.sit:
		_errand = []
		_sat = true
		_act_left = 1.2
		return
	_errand = [_errand[0], "act"]
	_act_left = float(s.time)
	if _errand[0] == "merchant" and _merchant_anim != null and _merchant_anim.has_animation("Talk"):
		_merchant_anim.play("Talk", 0.3)


func _held_clip() -> String:
	if _sat:
		return "Sitting_Enter" if _act_left > 0.0 else "Sitting_Idle"
	if not _errand.is_empty() and _errand[1] == "act":
		var clip: String = spots[_errand[0]].clip
		return clip if character != null and character.anim != null and character.anim.has_animation(clip) else "Idle"
	return ""


func _process(delta: float) -> void:
	super._process(delta)
	if pivot == null:
		return
	if _act_left > 0.0:
		_act_left -= delta
		if _act_left <= 0.0 and not _errand.is_empty() and _errand[1] == "act":
			var s: Dictionary = spots[_errand[0]]
			var name: String = _errand[0]
			_errand = []
			if name == "merchant" and _merchant_anim != null and _merchant_anim.has_animation("Idle"):
				_merchant_anim.play("Idle", 0.3)
			if (s.then as Callable).is_valid():
				(s.then as Callable).call()
			if s.page != "":
				open_page(s.page)
	# Names over the things near.
	for name in _labels:
		var l: Label3D = _labels[name]
		var d := Vector2(pivot.position.x - (spots[name].at as Vector3).x, pivot.position.z - (spots[name].at as Vector3).z).length()
		var want := 1.0 if d < NAME_NEAR else 0.0
		l.modulate.a = move_toward(l.modulate.a, want, delta * 3.0)
	if _toast != null and _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)


## The fire tapped: the next traveller round it (fetched first on the web).
func _next_traveller() -> void:
	var id := Profile.character_after()
	if not CharacterPacks.has(id):
		_say("%s 下載中……" % Profile.character_name(id))
		var got: bool = await CharacterPacks.wait_for(id)
		if not got or not is_inside_tree():
			_say("%s 下載失敗，再點一次營火重試" % Profile.character_name(id))
			return
	Profile.choose_character(id)
	if character != null:
		character.set_character(id)
	_refresh_card()
	_say("換成 %s 出發" % Profile.character_name(id))
	CharacterPacks.fetch(Profile.character_after())
