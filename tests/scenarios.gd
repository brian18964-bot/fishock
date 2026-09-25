extends Node

## The scenarios run by tests/run_tests.gd: each loads the real game scene,
## plays out a scenario (scripted input, the real game logic) and checks
## the outcome. Kept apart from run_tests.gd so it can use the game's
## classes and autoloads (a -s script is compiled before those exist).

const TESTS := [
	"test_map_generation",
	"test_refuel",
	"test_sacrifice_and_altar_stages",
	"test_turn_rock",
	"test_escape",
	"test_big_ghost_caged_without_heart",
	"test_big_ghost_heart_frees",
	"test_big_ghost_follows_the_light",
	"test_big_ghost_eats_thrown_fish",
	"test_big_ghost_fish_taken_back",
	"test_light_flash_stuns",
	"test_floating_ghost_budget",
	"test_backpack_grid",
	"test_water_ghost",
	"test_willow_talk",
	"test_altar_corrosion",
	"test_reset_run",
]

var main: Node
var gs: Node
var failures: Array[String] = []
var checks := 0
var _current := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	gs = get_tree().root.get_node("GameState")
	for t in TESTS:
		if only != "" and t != only:
			continue
		_current = t
		var before := failures.size()
		await _fresh_game()
		await call(t)
		print("%s %s" % ["PASS" if failures.size() == before else "FAIL", t])
	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  FAILED: " + f)
	get_tree().quit(1 if not failures.is_empty() else 0)


# --- helpers -----------------------------------------------------------------

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append("%s: %s" % [_current, what])


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await frames(int(s * 60.0))


func _fresh_game() -> void:
	seed(7)
	gs.reset_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	await frames(2)


func player() -> Player:
	return main.get_node("Player")


func key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func tap(k: Key) -> void:
	key(k, true)
	await frames(3)
	key(k, false)
	await frames(2)


## Puts the player at `pos` (and the camera with them).
func put(pos: Vector2) -> void:
	player().global_position = pos
	player().get_node("Camera2D").reset_smoothing()
	await frames(3)


func first(group: String) -> Node:
	return main.get_tree().get_first_node_in_group(group)


func of_script(file: String) -> Array:
	var out := []
	for c in main.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with(file):
			out.append(c)
	return out


func fish(name := "臭肚魚", tier := "near") -> Dictionary:
	return {"name": name, "value": 4.0, "tier": tier, "size": Inventory.size_for_catch(tier, false)}


# --- tests -------------------------------------------------------------------

func test_map_generation() -> void:
	var zones := main.get_tree().get_nodes_in_group("water_zones")
	check(zones.size() >= 3, "at least 3 water zones (got %d)" % zones.size())
	var rocks := of_script("flip_rock.gd")
	check(rocks.size() >= 8 and rocks.size() <= 10, "8-10 flip rocks (got %d)" % rocks.size())
	for n in ["FuelStation", "Altar", "EscapePoint", "GhostCage", "BigGhost", "Willow"]:
		check(main.get_node_or_null(n) != null, "has " + n)
	for rock in rocks:
		check(Ripple.water_at(main.get_tree(), rock.global_position) == null, "rock out of the water")
	var altar: Node2D = main.get_node("Altar")
	var escape: Node2D = main.get_node("EscapePoint")
	check(altar.global_position.distance_to(escape.global_position) > 300.0, "altar and escape apart")
	check(escape.get_node("Light").visible == false, "escape dark before the quota")


func test_refuel() -> void:
	var lantern: Lantern = player().get_node("Lantern")
	lantern.fuel = 20.0
	var station: Node2D = main.get_node("FuelStation")
	# From above the drums too (user request).
	await put(station.global_position + Vector2(0, -62))
	var offer := player().interaction()
	check(offer.get("verb", "") == "補充", "refuel offered above the station (got %s)" % offer)
	await tap(KEY_E)
	check(lantern.fuel >= lantern.max_fuel - 0.5, "lamp refilled")


func test_sacrifice_and_altar_stages() -> void:
	var altar: Node2D = main.get_node("Altar")
	var willow: Node2D = main.get_node("Willow")
	for i in 10:
		gs.add_carried_fish({"name": "魚", "value": 4.0, "tier": "near"})
	await put(altar.global_position + Vector2(0, 10))
	check(player().interaction().get("verb", "") == "獻祭", "offering offered at the altar")
	var before: float = gs.quota_progress
	key(KEY_E, true)
	await seconds(2.0)
	key(KEY_E, false)
	await frames(2)
	check(gs.quota_progress > before, "quota rose")
	check(gs.carried_fish.size() < 10, "fish offered one by one")
	gs.quota_progress = gs.quota_target * 0.5
	await seconds(8.0)
	check(willow.stage() == "tend", "Willow tends the altar past a third")
	check(willow.global_position.distance_to(altar.global_position + willow.FRONT) < 3.0, "Willow in front of the altar")
	check(willow._dir == willow.DIR_UP, "Willow faces the altar")
	gs.quota_progress = gs.quota_target * 0.9
	await seconds(2.0)
	check(altar._glow > 0.2, "altar glows past two thirds")


func test_turn_rock() -> void:
	var rock: Node2D = of_script("flip_rock.gd")[0]
	await put(rock.global_position + Vector2(-16, 12))
	check(player().interaction().get("verb", "") == "翻開", "turn offered by a rock")
	await tap(KEY_E)
	check(not rock.active, "rock turned at a tap")
	await seconds(1.0)
	check(rock._roller.position.length() > 15.0, "rock rolled aside")


func test_escape() -> void:
	var escape: Node2D = main.get_node("EscapePoint")
	await put(escape.global_position + Vector2(0, 20))
	check(player().interaction().get("verb", "") != "逃離", "no escape before the quota")
	gs.quota_progress = gs.quota_target
	gs._enter_escape_phase()
	await seconds(3.0)
	check(escape.get_node("Light").visible, "runes lit once the quota is met")
	check(player().interaction().get("verb", "") == "逃離", "escape offered")
	await tap(KEY_E)
	check(gs.run_over, "run ended by escaping")


func _big_ghost_catch() -> Node:
	var bg = main.get_node("BigGhost")
	var cage: Node2D = main.get_node("GhostCage")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	player().set_physics_process(false)
	await put(cage.global_position + Vector2(-60, 50))
	player().set_physics_process(true)
	return bg


func test_big_ghost_caged_without_heart() -> void:
	var bg = await _big_ghost_catch()
	for _i in 60 * 30:
		await get_tree().process_frame
		if gs.run_over:
			break
	check(gs.run_over, "caught and killed without a heart")


func test_big_ghost_heart_frees() -> void:
	gs.grant_heart()
	var bg = await _big_ghost_catch()
	var freed := false
	for _i in 60 * 30:
		await get_tree().process_frame
		if bg.mode == bg.Mode.REST:
			freed = true
			break
	check(freed, "the heart breaks the cage open")
	check(not gs.run_over, "survived")
	check(not player().held, "player let go")
	check(not gs.has_heart, "heart spent")


func test_big_ghost_follows_the_light() -> void:
	var bg = main.get_node("BigGhost")
	var lantern: Lantern = player().get_node("Lantern")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	await frames(5)
	bg.global_position = Vector2(1500, 300)
	bg.mode = bg.Mode.WANDER
	player().set_physics_process(false)
	await put(bg.global_position + Vector2(-130, 0))
	player().aim_dir = Vector2.RIGHT
	lantern.lit = true
	await frames(10)
	check(bg.mode == bg.Mode.CHASE, "charges when lit (mode %s)" % bg.Mode.keys()[bg.mode])
	lantern.lit = false
	player().global_position += Vector2(0, 200)
	await seconds(2.5)
	check(bg.mode in [bg.Mode.SEARCH, bg.Mode.WANDER], "gives up out of the light (mode %s)" % bg.Mode.keys()[bg.mode])
	await seconds(5.0)
	check(bg.mode == bg.Mode.WANDER, "back to wandering")
	player().set_physics_process(true)


func test_big_ghost_eats_thrown_fish() -> void:
	var bg = main.get_node("BigGhost")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	await frames(5)
	bg.global_position = Vector2(1500, 300)
	bg.mode = bg.Mode.CHASE
	await put(bg.global_position + Vector2(-120, 0))
	player().aim_dir = Vector2.RIGHT
	gs.add_carried_fish(fish())
	player().throw_fish(0)
	await frames(3)
	check(bg.mode == bg.Mode.EAT, "goes for the fish (mode %s)" % bg.Mode.keys()[bg.mode])
	await seconds(8.0)
	check(bg.mode == bg.Mode.REST, "leaves you be once fed (mode %s)" % bg.Mode.keys()[bg.mode])
	check(main.get_tree().get_nodes_in_group("dropped_fish").is_empty(), "fish eaten")


func test_big_ghost_fish_taken_back() -> void:
	var bg = main.get_node("BigGhost")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	await frames(5)
	bg.global_position = Vector2(1500, 300)
	bg.mode = bg.Mode.CHASE
	await put(bg.global_position + Vector2(-200, 0))
	player().aim_dir = Vector2.RIGHT
	gs.add_carried_fish(fish())
	player().throw_fish(0)
	await frames(3)
	var dropped: Node = main.get_tree().get_first_node_in_group("dropped_fish")
	check(bg.mode == bg.Mode.EAT, "goes for the fish")
	dropped.pick_up()
	await frames(3)
	check(bg.mode == bg.Mode.WANDER, "picked back up: nothing eaten, back to wandering (mode %s)" % bg.Mode.keys()[bg.mode])


func test_light_flash_stuns() -> void:
	var lantern: Lantern = player().get_node("Lantern")
	var bg = main.get_node("BigGhost")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	await frames(5)
	player().set_physics_process(false)
	await put(Vector2(1300, 400))
	bg.global_position = player().global_position + Vector2(0, 150)
	bg.mode = bg.Mode.WANDER
	bg.set_physics_process(false)
	player().aim_dir = Vector2.DOWN
	lantern.lit = true
	lantern.flash_cooldown = 0.0
	await frames(3)
	lantern.boost = 1.0
	lantern.release_flash()
	check(bg.stun_timer > Lantern.FLASH_STUN_DURATION, "a charged flash stuns the big ghost longer (%.2f)" % bg.stun_timer)
	check(lantern.boost == 0.0, "the charge is spent")
	bg.set_physics_process(true)
	player().set_physics_process(true)


func test_floating_ghost_budget() -> void:
	for i in 8:
		gs.add_carried_fish(fish())
	var times := []
	var count_before: int = gs.ghost_interferences
	player().set_physics_process(false)
	await put(Vector2(700, 400))
	var last: int = gs.ghost_interferences
	for f in 60 * 130:
		await get_tree().process_frame
		if gs.ghost_interferences != last:
			last = gs.ghost_interferences
			times.append(f / 60.0)
		if f % 600 == 0:
			var g: Node2D = main.get_node("Ghost")
			if g.global_position.distance_to(player().global_position) > 500.0:
				# Keep it within reach so the test doesn't wait on a long drift.
				g.global_position = player().global_position + Vector2(260, 0)
	player().set_physics_process(true)
	check(gs.ghost_interferences - count_before <= 4, "at most 4 a run")
	check(times.size() >= 2, "it does come now and then (%d)" % times.size())
	for i in range(1, times.size()):
		check(times[i] - times[i - 1] >= 19.9, "20 s apart (%.1f)" % (times[i] - times[i - 1]))


func test_backpack_grid() -> void:
	var p := player()
	var used := Inventory.used_cells(p)
	check(used > 0, "bait and gear take cells")
	gs.add_carried_fish(fish("大", "far"))
	check(Inventory.used_cells(p) == used + 4, "a large fish takes 2x2")
	var n := 0
	while Inventory.fits_with(p, [{"kind": "fish", "size": Vector2i(2, 2)}]) and n < 20:
		gs.add_carried_fish(fish("大", "far"))
		n += 1
	check(not Inventory.fits_with(p, [{"kind": "fish", "size": Vector2i(2, 2)}]), "fills up")
	check(not Inventory.pack(Inventory.items(p)).is_empty(), "what's in it still packs")
	check(Inventory.used_cells(p) <= Inventory.COLS * Inventory.ROWS, "never over capacity")
	# Bag UI opens and closes.
	var bag: Backpack = null
	for c in main.get_children():
		if c is Backpack:
			bag = c
	await tap(KEY_I)
	check(bag.is_open(), "backpack opens")
	var stick: Node = main.get_node("HUD/Panel/AimJoystick")
	check(stick.process_mode == Node.PROCESS_MODE_DISABLED, "the sticks ignore touches under the open bag")
	bag.toggle()
	check(not bag.is_open(), "backpack closes")
	check(stick.process_mode != Node.PROCESS_MODE_DISABLED, "the sticks work again")


func test_water_ghost() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(shore + Vector2(0, 30))
	player()._apply_water_ghost_attack()
	await frames(2)
	var ghosts := main.get_tree().get_nodes_in_group("water_ghosts")
	check(ghosts.size() == 1, "the water ghost shows up")
	check(player().water_ghost_timer > 0.0, "the player is afflicted")
	await seconds(12.0)
	check(main.get_tree().get_nodes_in_group("water_ghosts").is_empty(), "and goes back under")


func test_willow_talk() -> void:
	var willow: Node2D = main.get_node("Willow")
	var altar: Node2D = main.get_node("Altar")
	gs.quota_progress = gs.quota_target
	gs._enter_escape_phase()
	await seconds(10.0)
	check(willow.can_talk(), "Willow can be talked to once the quota is met")
	await put(willow.global_position + Vector2(0, 24))
	check(player().interaction().get("verb", "") == "對話", "talk offered")
	await tap(KEY_E)
	var box: DialogBox = null
	for c in main.get_children():
		if c is DialogBox:
			box = c
	check(box != null and box.is_open(), "the dialog opens")
	check(box._text.text.contains("供品"), "it lists the offerings")
	box.close()


func test_altar_corrosion() -> void:
	var altar: Node2D = main.get_node("Altar")
	gs.evil_count = 2
	await seconds(4.0)
	check(altar._corruption > 0.5, "evil eats into the altar (%.2f)" % altar._corruption)
	check(altar._haze.emitting, "a haze rises off it")


func test_reset_run() -> void:
	gs.add_carried_fish(fish())
	gs.grant_heart()
	gs.quota_progress = 12.0
	gs.evil_count = 1
	gs.ghost_interferences = 3
	gs.reset_run()
	await frames(2)
	check(gs.carried_fish.is_empty(), "fish cleared")
	check(not gs.has_heart, "heart cleared")
	check(gs.quota_progress == 0.0, "quota cleared")
	check(gs.evil_count == 0, "evil cleared")
	check(gs.ghost_interferences == 0, "ghost budget renewed")
