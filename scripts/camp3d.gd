class_name Camp3D
extends TitleScreen

## The main screen (user request): the camp as it was designed - the tent
## on the left with the crate and the backpack by it, the drums by the fire
## with the lamp on one, the cut drum of water (the fish tank) on the
## right, the merchant's stall, his boat at the dock (CampStage) - only now
## walked about in, as the 3D trial was (scenes/proto3d.tscn): the left
## stick (or WASD / the arrows) walks, pushed all the way runs, and the
## camera follows close behind and above. A tap on a thing still sends the
## character over to do it, then its page opens (CampLife.act_on); near a
## thing its name shows. Left alone a while it carries on with its own
## life at the camp. The old camp (scenes/title_screen.tscn, the camera
## fixed) is kept, a button away (舊營地).

const SCENE := "res://scenes/camp3d.tscn"
const OLD_CAMP := "res://scenes/title_screen.tscn"
## The camera: how far it looks down (degrees), how far back (m), its field
## of view, how fast it follows.
## (user request: halfway out to the run's camera - RunView3D)
const CAMERA_PITCH := 43.0
const CAMERA_DISTANCE := 7.75
const CAMERA_FOV := 42.0
const CAMERA_EASE := 4.0
## Walking up to WALK_MAX m/s (the Walk clip at its own pace WALK_PACE),
## past it running (RUN_PACE); RUN_SPEED with the stick all the way.
const WALK_MAX := 1.5
const WALK_PACE := 0.8
const RUN_PACE := 3.0
const RUN_SPEED := 3.2
const TURN_RATE := 12.0
## Left alone this long (s), it goes back to its own life at the camp.
const LIVE_AGAIN := 25.0
## How near (m) it can come to the frog merchant.
const MERCHANT_ROOM := 0.55

## The menu along the bottom: [page, its name].
const QUICK := [["shop", "商城"], ["warehouse", "倉庫"], ["equipment", "裝備"], ["fish_tank", "魚缸"], ["journey", "出發"]]

var _joystick: Control
## A page opened from the menu: the camp stays live under it, the character
## off doing its bit.
var _quick_on := false
## The stick's walking it (CampLife paused), it's getting up first (off a
## log, off the ground), how long it's been left alone.
var _driving := false
var _rising := false
var _idle_for := 0.0


func _build() -> void:
	super._build()
	if _stage == null:
		return
	_stage.free_camera = true
	var cam := _stage.camera
	cam.fov = CAMERA_FOV
	cam.transform = _follow_transform()
	# The stick, bottom left (shown while it's held); 多人連線 moved out of
	# its way.
	var stick: Control = load("res://addons/virtual_joystick/virtual_joystick_scene.tscn").instantiate()
	stick.name = "MoveJoystick"
	stick.set("use_input_actions", false)
	stick.set("joystick_mode", 1)
	stick.set("visibility_mode", 2)
	_home.add_child(stick)
	_joystick = stick
	# User request: a menu - each opens its page at once,
	# the character going over to do its bit behind it (出發夜釣 is its
	# 出發 now; 多人連線 up under the gold).
	var play := _home.get_node_or_null("Play") as Control
	if play != null:
		play.visible = false
	var multi := _home.get_node_or_null("Multiplayer") as Control
	if multi != null:
		multi.position = Vector2(764, 94)
		multi.custom_minimum_size = Vector2(126, 34)
		multi.size = Vector2(126, 34)
	# (user request: folded into one button, bottom right - tapped, the
	# five open up above it)
	var bar := VBoxContainer.new()
	bar.name = "QuickMenu"
	bar.add_theme_constant_override("separation", 6)
	bar.visible = false
	for entry in QUICK:
		var b := UiKit.button(entry[1], 16, "red" if entry[0] == "journey" else "gray")
		b.name = "Quick_" + entry[0]
		b.custom_minimum_size = Vector2(116, 42)
		var page: String = entry[0]
		b.pressed.connect(func():
			bar.visible = false
			quick(page))
		bar.add_child(b)
	_home.add_child(bar)
	bar.position = Vector2(828, 476 - QUICK.size() * 48)
	var menu := UiKit.button("功能 ▲", 17, "red")
	menu.name = "QuickToggle"
	menu.position = Vector2(828, 478)
	menu.custom_minimum_size = Vector2(116, 48)
	menu.pressed.connect(func():
		bar.visible = not bar.visible
		menu.text = "功能 ▼" if bar.visible else "功能 ▲")
	_home.add_child(menu)
	var old := UiKit.button("舊營地", 14, "gray")
	old.name = "OldCamp"
	old.position = Vector2(764, 54)
	old.custom_minimum_size = Vector2(126, 34)
	old.pressed.connect(func(): get_tree().change_scene_to_file(OLD_CAMP))
	_home.add_child(old)
	var hint := UiKit.label("左搖桿走動，推到底奔跑　輕觸營地的東西：走過去使用", 12, UiKit.DIM, false, 2)
	hint.name = "Hint"
	hint.position = Vector2(16, 70)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home.add_child(hint)


## Up and behind the character, looking down at CAMERA_PITCH.
func _follow_transform() -> Transform3D:
	var look := _stage.character_pivot.position + Vector3(0, 0.75, 0)
	var pitch := deg_to_rad(CAMERA_PITCH)
	var at := look + Vector3(0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE
	return Transform3D(Basis.looking_at(look - at, Vector3.UP), at)


func _process(delta: float) -> void:
	super._process(delta)
	if _stage == null or _stage.character == null or _stage.character.anim == null:
		return
	_drive(delta)
	var pivot := _stage.character_pivot
	if not _driving:
		# (up on the dock's planks, down off them, whoever's walking it)
		pivot.position.y = move_toward(pivot.position.y,
			CampStage.DOCK_DECK if _stage.on_dock(pivot.position) else 0.0, delta * 2.0)
	# The camera after it, eased - not while it glides to a page.
	var cam := _stage.camera
	var gliding: bool = _stage._cam_tween != null and _stage._cam_tween.is_running()
	if _page == null and not gliding:
		var k := minf(1.0, delta * CAMERA_EASE)
		cam.transform = cam.transform.interpolate_with(_follow_transform(), k)
		cam.fov = lerpf(cam.fov, CAMERA_FOV, k)


func _stick() -> Vector2:
	var v := Vector2.ZERO
	if _joystick != null and _joystick.get("output") != null:
		v = _joystick.output
	if v.length() < 0.05:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v.y += 1.0
		# (a shift held: walking, from the keyboard)
		v = v.normalized() * (0.35 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	return v.limit_length(1.0)


## The stick walks it: whatever it was doing it lets go of (up off a log
## first), and goes where it's pushed - round nothing: into nothing either
## (CampStage.roomy: the camp's things, the lake), out along the dock.
func _drive(delta: float) -> void:
	var life := _stage.life
	var stick := _stick() if _page == null and _home.visible and _scene_piece == "" and life.busy == "" else Vector2.ZERO
	if stick.length() < 0.05:
		if _driving:
			_driving = false
			_play("Idle", 0.2)
		if _rising and life._step.is_empty() and life._plan.is_empty():
			_rising = false
		if life.paused and _page == null and _scene_piece == "":
			_idle_for += delta
			if _idle_for >= LIVE_AGAIN:
				life.paused = false
				life._rest = 1.0
		return
	_idle_for = 0.0
	_asked_page = ""
	# Sat or down on the ground: up first (the stick waits).
	if life.seated or life.down != "":
		if not _rising:
			_rising = true
			life.paused = false
			life._plan = life._get_up()
			life._step = {}
			life._next()
		return
	if _rising and not (life._step.is_empty() and life._plan.is_empty()):
		return
	_rising = false
	if not _driving:
		_driving = true
		life._plan.clear()
		life._step = {}
		life.activity = ""
	life.paused = true
	var pivot := _stage.character_pivot
	var move := Vector3(stick.x, 0, stick.y) * RUN_SPEED
	var speed := move.length()
	var from := pivot.position
	var to := from + move * delta
	# (along whatever it's walked into, if not through it)
	for step in [to, Vector3(to.x, from.y, from.z), Vector3(from.x, from.y, to.z)]:
		# (somewhere tight already - set down there: out the way it's roomier)
		if walkable(step) or (not walkable(from) and not _stage._in_lake(step, 0.3)
				and _stage.clearance(step) > _stage.clearance(from)):
			pivot.position = Vector3(step.x, 0.0, step.z)
			break
	pivot.position.y = CampStage.DOCK_DECK if _stage.on_dock(pivot.position) else 0.0
	pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(move.x, move.z), minf(1.0, delta * TURN_RATE))
	var anim := _stage.character.anim
	if speed <= WALK_MAX or not anim.has_animation("Run"):
		_play("Walk", 0.2)
		anim.speed_scale = clampf(speed / WALK_PACE, 0.4, 2.2)
	else:
		_play("Run", 0.2)
		anim.speed_scale = clampf(speed / RUN_PACE, 0.6, 1.6)


## Ground it can stand on: in the camp, clear of its things, not in the
## lake - or out on the dock.
func walkable(p: Vector3) -> bool:
	# (round the merchant too - user report: walked through him)
	var m := _stage.merchant
	if m != null and Vector2(p.x - m.global_position.x, p.z - m.global_position.z).length() < MERCHANT_ROOM:
		return false
	return _stage.on_dock(p) or _stage.roomy(p, _stage.body)


func _play(clip: String, blend: float) -> void:
	var anim := _stage.character.anim
	if anim.current_animation != clip and anim.has_animation(clip):
		anim.play(clip, blend)
	if clip == "Idle":
		anim.speed_scale = 1.0


## A tap on a thing: off it goes to do it (its own life back on to do it).
func _ask(spot: String) -> void:
	_driving = false
	_idle_for = 0.0
	_stage.life.paused = false
	super._ask(spot)


## The menu's `page` at once (user request), the character off to do its
## bit there meanwhile - the camp kept moving under the page.
func quick(page: String) -> void:
	if _stage == null or _page != null or _scene_piece != "":
		return
	_driving = false
	_rising = false
	_idle_for = 0.0
	_asked_page = ""
	_near_used = page
	_near_reached = false
	var life := _stage.life
	life.paused = false
	life.act_on(page, 0, Callable())
	_quick_on = true
	open_page(page)


func open_page(page: String, tab := "") -> void:
	super.open_page(page, tab)
	if _quick_on and _stage != null:
		_stage.life.hold(false)
		_live(true)


func close_page() -> void:
	_quick_on = false
	super.close_page()


func _live(on: bool) -> void:
	super._live(on or _quick_on)
