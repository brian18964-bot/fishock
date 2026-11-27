extends "res://tests/scenarios.gd"
## tools/verify/verify.gd tool=overlap - user request: "所有物件不可以有穿圖、卡圖的情況，動物們也不能被
## 物件卡住跟穿圖". Each level (LEVELS env, comma list; all of them else) is loaded as it's played
## (SEED env, 7 else), its 3D world built, and gone over:
##
##   - things in one another, as they're drawn: every building's and yard thing's own outline read
##     from its 3D model (its meshes' box in its own frame, turned and scaled as it stands - eaves,
##     porches and sheds included), the trees' trunks and (over a building taller than its lowest
##     leaves) their crowns, the rocks and stones, the fences and walls (as long thin boxes), the
##     bridges and docks; any two of them overlapping by more than SLACK px (a crown CROWN_SLACK) -
##     the camp's own parts aside, laid out by hand;
##   - things standing in the water: a building's or yard thing's outline, a trunk or a stone in
##     a pond further than WET px;
##   - the animals: the level run on for ANIMAL_TIME s (time sped up), each animal followed - its
##     body (BODY_SHARE of its own radius) in a building's, a yard thing's, a trunk's, a stone's or a
##     fence's outline by more than SLACK px, in the water, or meaning to go somewhere and hardly
##     moving for STUCK_FOR s (stuck);
##
## and OUT/overlap.tsv gets a line a level (each kind of trouble's count), OUT/overlap.txt the
## details (the worst first, with where on the map). With CAMERA=1 and a display, each trouble's
## place is drawn too (OUT/<level>_<n>.png).

const Audit := preload("res://tests/overlap_audit.gd")
const ANIMAL_TIME := 60.0
const SPEED_UP := 3.0

var OUT := OS.get_environment("OUT")
var _tsv: FileAccess
var _txt: FileAccess
var _camp := Vector2.ZERO


func _run() -> void:
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	Campaign.dev_all_open = true
	if OUT == "":
		OUT = "user://overlap"
	DirAccess.make_dir_recursive_absolute(OUT)
	_tsv = FileAccess.open(OUT + "/overlap.tsv", FileAccess.WRITE)
	_txt = FileAccess.open(OUT + "/overlap.txt", FileAccess.WRITE)
	_tsv.store_line("level\ttheme\tthings\tin_each_other\tcrowns\tin_water\tanimals\tanimal_in\tanimal_water\tanimal_stuck")
	var ids: Array = []
	var want := OS.get_environment("LEVELS")
	for lv in Campaign.LEVELS:
		if want == "" or str(lv.id) in want.split(","):
			ids.append(str(lv.id))
	var total := 0
	for id in ids:
		total += await _level(id)
	print("OVERLAP %d levels, %d troubles in all" % [ids.size(), total])
	_tsv.close()
	_txt.close()
	get_tree().quit()


func _level(id: String) -> int:
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7)
	camp().begin_level(id)
	gs.last_return = ""
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	for _i in 900:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	await frames(6)
	var view: RunView3D = RunView3D.active
	var st := main.get_node_or_null("FuelStation") as Node2D
	_camp = st.global_position if st != null else MapGenerator.SPAWN_POS
	var things := Audit.things(get_tree(), view)
	var found := Audit.each_other(things, _camp)
	var crowns := Audit.crowns(things)
	var wet := Audit.in_water(get_tree(), things)
	var beasts: Dictionary = await _animals(things)
	var n: int = found.size() + crowns.size() + wet.size() + beasts.inside.size() + beasts.water.size() + beasts.stuck.size()
	_tsv.store_line("%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d" % [id, MapGenerator.current_theme, things.size(), found.size(), crowns.size(),
		wet.size(), beasts.count, beasts.inside.size(), beasts.water.size(), beasts.stuck.size()])
	_txt.store_line("== %s (%s): %d things, %d animals" % [id, MapGenerator.current_theme, things.size(), beasts.count])
	for group in [["in each other", found], ["crown in a building", crowns], ["in the water", wet],
			["animal in something", beasts.inside], ["animal in the water", beasts.water], ["animal stuck", beasts.stuck]]:
		var list: Array = group[1]
		list.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
		for row in list.slice(0, 12):
			_txt.store_line("  %s: %s" % [group[0], row[1]])
	_txt.flush()
	_tsv.flush()
	print("LEVEL %s %s: %d things - in each other %d, crowns %d, in water %d | %d animals - in things %d, in water %d, stuck %d" % [id,
		MapGenerator.current_theme, things.size(), found.size(), crowns.size(), wet.size(), beasts.count, beasts.inside.size(),
		beasts.water.size(), beasts.stuck.size()])
	if OS.get_environment("CAMERA") == "1":
		await _pictures(id, found + crowns + wet + beasts.inside + beasts.stuck)
	return n


func _animals(things: Array) -> Dictionary:
	var w := Audit.animal_watch(things)
	Engine.time_scale = SPEED_UP
	var t := 0.0
	while t < ANIMAL_TIME:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * SPEED_UP
		t += dt
		Audit.animal_step(get_tree(), main, w, dt)
	Engine.time_scale = 1.0
	return {"count": w.seen.size(), "inside": w.inside.values(), "water": w.water.values(), "stuck": w.stuck.values()}


# ------------------------------------------------------------------ pictures

func _pictures(id: String, rows: Array) -> void:
	var view: RunView3D = RunView3D.active
	# (by day, no fog, nothing see-through, no HUD)
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	view.add_child(sun)
	for we in view.get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var e: Environment = (we as WorldEnvironment).environment
		if e != null:
			e.ambient_light_energy = 2.2
			e.fog_enabled = false
			e.volumetric_fog_enabled = false
	if view._ruin_mat != null:
		CityBuild.update(view._ruin_mat, Vector3(0, -200, 0))
	view.set_process(false)
	var cam := Camera3D.new()
	view.add_child(cam)
	var k := 0
	for row in rows.slice(0, 8):
		var at: Vector2 = row[2]
		var c := RunView3D.to3(at)
		cam.global_position = c + Vector3(0.0, 9.0, 9.0)
		cam.look_at(c, Vector3.UP)
		cam.fov = 45.0
		cam.make_current()
		await frames(6)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [OUT, id, k])
		k += 1
	cam.queue_free()
