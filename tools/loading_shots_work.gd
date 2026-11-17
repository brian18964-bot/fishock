extends "res://tests/scenarios.gd"
## tools/loading_shots.gd's work: the pictures the loading cards are made from - the game's own
## night, drawn by the game, from a chosen camera. STAGE (env):
##   y   WHAT=cast|dragon|catch     the cast, the dragon coming down, a big fish landed
##   z   WHAT=altar|ghost|lamp|frost|oxy|shore  (THEME=snow_pine|autumn for the shore)
##   c2  CHAR=<id>                  a character from the front by the water (THEME as wished)
##   npc                            the camp's frog merchant
## Each writes PNGs to OUT; tools/loading_cards.py makes the cards from them.
var OUT := OS.get_environment("OUT")
var STAGE := OS.get_environment("STAGE")
var _hidden := []
var _cam: Camera3D


func _run() -> void:
	match STAGE:
		"y": await stage_y()
		"z": await stage_z()
		"c2": await stage_c2()
		"npc": await stage_npc()
	get_tree().quit()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("MARK ", name)


func hud(on: bool) -> void:
	if not on:
		for layer in main.find_children("*", "CanvasLayer", true, false):
			if (layer as CanvasLayer).visible:
				(layer as CanvasLayer).visible = false
				_hidden.append(layer)
	else:
		for layer in _hidden:
			if is_instance_valid(layer):
				(layer as CanvasLayer).visible = true
		_hidden.clear()


func begin(intro: bool) -> void:
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = intro
	seed(5)
	camp().clear()
	gs.reset_run()
	gs.last_return = ""
	camp().begin_free([], OS.get_environment("THEME"))
	var t0 := Time.get_ticks_msec()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	for _i in 400:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	print("LOAD run scene %d ms" % (Time.get_ticks_msec() - t0))


## The camera at `from`, looking at `at`.
func aim(at: Vector3, from: Vector3, fov := 40.0) -> void:
	var v: RunView3D = RunView3D.active
	if _cam == null:
		_cam = Camera3D.new()
		v.add_child(_cam)
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	_cam.fov = fov
	_cam.make_current()
	v.set_process(true)


## More loading art: the map's places and things.
func _z_shots(tag: String, at: Vector3, cams: Array) -> void:
	for j in cams.size():
		aim(at + cams[j][0], at + cams[j][1], float(cams[j][2]) if cams[j].size() > 2 else 50.0)
		await frames(4)
		await shot("z_%s_%d" % [tag, j])


## Loading art (not in the repo): the night as the game draws it, from a chosen camera.
func stage_y() -> void:
	await begin(false)
	await frames(150)
	hud(false)
	var p := player()
	for g in get_tree().get_nodes_in_group("ghosts") + get_tree().get_nodes_in_group("water_ghosts"):
		if not g is BigGhost:
			(g as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var lantern := p.get_node_or_null("Lantern")
	if lantern != null:
		lantern.lit = true
		lantern.fuel = lantern.max_fuel
	var v: RunView3D = RunView3D.active
	var what := OS.get_environment("WHAT")
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 46))
	p.aim_dir = Vector2.UP
	await frames(40)
	var me: Vector3 = v.pivot.global_position
	if what == "cast":
		p.charge_time = 0.0
		p.state = Player.State.CHARGING
		for i in 60:
			p.charge_time = p.MAX_CHARGE_TIME * minf(i / 50.0, 1.0)
			await frames(1)
		for j in 3:
			var cams := [[me + Vector3(0, 1.2, -1.5), me + Vector3(2.6, 1.0, 2.2)], [me + Vector3(0, 1.3, -2.0), me + Vector3(-2.4, 1.4, 2.6)], [me + Vector3(0, 1.0, -3.0), me + Vector3(3.6, 0.7, 0.9)]]
			aim(cams[j][0], cams[j][1], 50.0)
			await frames(3)
			await shot("y_cast_wind_%d" % j)
		p._launch_cast()
		for i in 6:
			aim(me + Vector3(0, 1.2, -1.5), me + Vector3(2.6, 1.0, 2.2), 50.0)
			await frames(4)
			await shot("y_cast_%d" % i)
	elif what == "dragon":
		var bg: BigGhost = main.get_node("BigGhost")
		gs.time_remaining = gs.DAY_DURATION * 0.3
		Campaign.rules.big_wake = 0
		for _i in 30:
			await frames(1)
			if bg.mode != bg.Mode.ASLEEP:
				break
		var rec: Dictionary = v._creatures.get(bg, {})
		for i in 30:
			await frames(6)
			var at: Vector3 = (rec.node as Node3D).global_position
			aim(at + Vector3(0, 1.3, 0), at + Vector3(1.6, 0.5, 7.6), 50.0)
			await shot("y_dragon_%02d" % i)
	elif what == "catch":
		var f := fish("鯉魚", "near")
		f.merge({"id": "carp", "length": 120.0, "weight": 20.0, "value": 9.0}, true)
		p.catch_success.emit(f)
		for i in 8:
			aim(me + Vector3(0, 1.6, -0.8), me + Vector3(3.8, 1.1, 1.4), 50.0)
			await frames(4)
			await shot("y_catch_%d" % i)


func stage_z() -> void:
	var what := OS.get_environment("WHAT")
	if OS.get_environment("CHAR") != "":
		Profile.choose_character(OS.get_environment("CHAR"))
	if what == "frost":
		Profile._store("shovel", 1)
		Profile.equip("shovel")
	await begin(false)
	await frames(150)
	hud(false)
	var p := player()
	var v: RunView3D = RunView3D.active
	var lantern := p.get_node_or_null("Lantern")
	if lantern != null:
		lantern.lit = true
		lantern.fuel = lantern.max_fuel
	var keep_ghost: Node = null
	if what == "ghost":
		keep_ghost = main.get_node("Ghost")
	for g in get_tree().get_nodes_in_group("ghosts") + get_tree().get_nodes_in_group("water_ghosts"):
		if not g is BigGhost and g != keep_ghost:
			(g as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	match what:
		"altar":
			var altar: Node2D = main.get_node("Altar")
			await put(altar.global_position + Vector2(-26, 30))
			p.aim_dir = (altar.global_position - p.global_position).normalized()
			await frames(40)
			var a3 := RunView3D.to3(altar.global_position)
			await _z_shots("altar", a3, [[Vector3(-0.8, 1.0, 0.4), Vector3(3.2, 2.0, 4.6)], [Vector3(-0.6, 0.9, 0.3), Vector3(-3.6, 1.6, 4.2)], [Vector3(0, 1.2, 0), Vector3(0.5, 2.6, 6.5), 44.0]])
		"ghost":
			await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 46))
			p.aim_dir = Vector2.UP
			await frames(20)
			keep_ghost.global_position = p.global_position + Vector2(46, -20)
			keep_ghost.process_mode = Node.PROCESS_MODE_DISABLED
			await frames(30)
			var me: Vector3 = v.pivot.global_position
			await _z_shots("ghost", me, [[Vector3(1.2, 1.4, -0.6), Vector3(-2.0, 1.5, 3.6)], [Vector3(1.4, 1.5, -0.8), Vector3(4.2, 1.2, 2.8)], [Vector3(1.6, 1.6, -1.0), Vector3(1.0, 1.0, 3.2), 56.0]])
		"lamp":
			var fs: Node2D = main.get_node("FuelStation")
			await put(fs.global_position + Vector2(40, 34))
			p.aim_dir = Vector2.LEFT
			gs.time_remaining = gs.DAY_DURATION * 0.55
			await frames(40)
			var f3 := RunView3D.to3(fs.global_position)
			await _z_shots("lamp", f3, [[Vector3(1.2, 1.0, 1.0), Vector3(4.8, 1.8, 5.2)], [Vector3(1.0, 0.9, 0.8), Vector3(-2.6, 1.4, 5.0)], [Vector3(1.6, 1.2, 1.2), Vector3(3.4, 1.0, 2.8), 46.0]])
		"frost":
			var ff: Node2D = get_tree().get_nodes_in_group("frost_flowers")[0]
			await put(ff.global_position + Vector2(-30, 22))
			p.aim_dir = Vector2.RIGHT
			await frames(40)
			var q3 := RunView3D.to3(ff.global_position)
			await _z_shots("frost", q3, [[Vector3(-0.6, 0.6, 0.3), Vector3(1.6, 1.3, 3.2)], [Vector3(-0.3, 0.5, 0.2), Vector3(-2.4, 1.0, 2.6)], [Vector3(0, 0.3, 0), Vector3(0.8, 0.9, 1.8), 46.0]])
		"oxy":
			var tree: Node2D = null
			for n in main.find_children("*", "", true, false):
				if n is OxyTree:
					tree = n
					break
			await put(tree.global_position + Vector2(-34, 24))
			p.aim_dir = Vector2.RIGHT
			await frames(40)
			var o3 := RunView3D.to3(tree.global_position)
			await _z_shots("oxy", o3, [[Vector3(-0.4, 0.5, 0.2), Vector3(1.4, 1.1, 2.6)], [Vector3(-0.2, 0.4, 0.1), Vector3(-2.0, 0.9, 2.4)], [Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 1.5), 46.0]])
		"shore":
			await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 46))
			p.aim_dir = Vector2.UP
			await frames(60)
			var me2: Vector3 = v.pivot.global_position
			await _z_shots("shore", me2, [[Vector3(0, 1.1, -1.0), Vector3(2.4, 1.2, 2.6)], [Vector3(0, 1.0, -1.2), Vector3(-2.6, 1.3, 2.2)], [Vector3(0, 1.2, -2.0), Vector3(0.4, 2.6, 4.8), 44.0]])


## Each character, from the front by the water, its lamp lit.
func stage_c2() -> void:
	Profile.choose_character(OS.get_environment("CHAR"))
	await begin(false)
	await frames(150)
	hud(false)
	var p := player()
	for g in get_tree().get_nodes_in_group("ghosts") + get_tree().get_nodes_in_group("water_ghosts"):
		if not g is BigGhost:
			(g as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var lantern := p.get_node_or_null("Lantern")
	if lantern != null:
		lantern.lit = true
		lantern.fuel = lantern.max_fuel
	var v: RunView3D = RunView3D.active
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 40))
	p.aim_dir = Vector2.DOWN
	await frames(90)
	var me: Vector3 = v.pivot.global_position
	var who := OS.get_environment("CHAR")
	# (0: the character on the frame's right, 1: on its left - room for the words the other side)
	var cams := [[Vector3(-1.25, 1.15, 0), Vector3(0.9, 1.35, 3.4), 46.0], [Vector3(1.25, 1.15, 0), Vector3(-0.9, 1.35, 3.4), 46.0]]
	for j in cams.size():
		aim(me + cams[j][0], me + cams[j][1], cams[j][2])
		await frames(6)
		await shot("c_%s_%d" % [who, j])


## The camp's frog merchant, from the title screen's 3D camp.
func stage_npc() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	await frames(240)
	var ts := get_tree().current_scene
	var stage: CampStage = ts.find_children("*", "CampStage", true, false)[0]
	var vp: SubViewport = stage.get_parent() as SubViewport
	print("XVP ", vp.size)
	vp.size = Vector2i(1920, 1080)
	var m: Node3D = stage.merchant
	var cam := Camera3D.new()
	stage.add_child(cam)
	for i in 10:
		await frames(40)
		var at := m.global_position + Vector3(0, 0.9, 0)
		var fwd := -m.global_basis.z.normalized()
		cam.global_position = at + m.global_basis.z.normalized() * 2.6 + m.global_basis.x.normalized() * 0.9 + Vector3(0, 0.3, 0)
		cam.look_at(at, Vector3.UP)
		cam.fov = 45
		cam.make_current()
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT + "/npc_%d.png" % i)
