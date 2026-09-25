extends SceneTree

## Soak test: a bot plays with random input (walking, casting, interacting,
## throwing fish, the backpack, switching light and fishing mode) through a
## whole day into the night, so errors that only turn up in unplanned
## combinations show in the log.
##
##   godot --headless --fixed-fps 60 -s tests/soak.gd -- [seed=N] [minutes=M]

const KEYS := [KEY_W, KEY_A, KEY_S, KEY_D]
var args := {}
var frame := 0
var total := 0
var held: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	total = int(float(args.get("minutes", "4")) * 60.0 * 60.0)
	seed(int(args.get("seed", "1")))


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		change_scene_to_file("res://scenes/main.tscn")
		return false
	if frame == 6:
		root.get_node("GameState").start_run()
	if frame < 10:
		return false
	var gs = root.get_node("GameState")
	if gs.run_over:
		print("soak: run ended at %.0f s: %s" % [frame / 60.0, gs.get("last_message") if "last_message" in gs else ""])
		gs.reset_run()
		change_scene_to_file("res://scenes/main.tscn")
		frame = 3
		total -= 600
		return false
	if frame % 20 == 0:
		_act()
	if frame >= total:
		print("soak: done")
		return true
	return false


func _act() -> void:
	var r := randf()
	if r < 0.35:
		for k in held:
			_key(k, false)
		held.clear()
		var k: int = KEYS[randi() % 4]
		_key(k, true)
		held.append(k)
		if randf() < 0.4:
			var k2: int = KEYS[randi() % 4]
			_key(k2, true)
			held.append(k2)
	elif r < 0.5:
		_key(KEY_SPACE, randf() < 0.6)
	elif r < 0.6:
		_tap(KEY_E)
	elif r < 0.64:
		_tap(KEY_G)
	elif r < 0.67:
		_tap(KEY_I)
	elif r < 0.7:
		_tap(KEY_TAB)
	elif r < 0.72:
		_tap(KEY_K)
	elif r < 0.75:
		_tap(KEY_L)
	elif r < 0.77:
		_tap(KEY_F)
	elif r < 0.8:
		var gs = root.get_node("GameState")
		gs.time_remaining = maxf(gs.time_remaining - 20.0, 0.0)


func _key(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _tap(k: int) -> void:
	_key(k, true)
	await process_frame
	await process_frame
	_key(k, false)
