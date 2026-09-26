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
	"test_big_ghost_night_hunt",
	"test_big_ghost_eats_thrown_fish",
	"test_big_ghost_fish_taken_back",
	"test_light_flash_stuns",
	"test_right_stick_casts",
	"test_right_stick_tap_cast",
	"test_cast_only_near_water",
	"test_walking_off_reels_in",
	"test_fight_swipe",
	"test_fight_enrage_tension",
	"test_fight_sweet_spot",
	"test_perfect_hook",
	"test_light_lure",
	"test_light_button_tap_and_hold",
	"test_light_button_relights",
	"test_long_press_brightness",
	"test_status_card_opens_bag",
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


## Somewhere at least `d` from any water's edge.
func away_from_water(d: float) -> Vector2:
	for y in range(120, int(Player.WORLD_HEIGHT) - 120, 40):
		for x in range(120, int(Player.WORLD_WIDTH) - 120, 40):
			var p := Vector2(x, y)
			var nearest := INF
			for z in main.get_tree().get_nodes_in_group("water_zones"):
				nearest = minf(nearest, z.distance_to_edge(p))
			if nearest > d and nearest < d + 60.0:
				return p
	return Vector2.ZERO


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


## Time's up: night falls and the big ghost hunts the player down, lamp
## or no lamp.
func test_big_ghost_night_hunt() -> void:
	var bg = main.get_node("BigGhost")
	var lantern: Lantern = player().get_node("Lantern")
	player().set_physics_process(false)
	await put(Vector2(1300, 400))
	lantern.lit = false
	bg.global_position = player().global_position + Vector2(260, 120)
	bg.mode = bg.Mode.WANDER
	await frames(10)
	check(bg.mode == bg.Mode.WANDER, "by day, unlit, it leaves you be")
	gs.time_remaining = 0.0
	await frames(3)
	check(gs.is_night, "time's up: night")
	await frames(3)
	check(bg.mode == bg.Mode.CHASE, "at night it comes for you (mode %s)" % bg.Mode.keys()[bg.mode])
	var before: float = bg.global_position.distance_to(player().global_position)
	await seconds(1.5)
	var after: float = bg.global_position.distance_to(player().global_position)
	check(after < before - 60.0, "straight at you (%.0f -> %.0f)" % [before, after])
	check(bg.mode in [bg.Mode.CHASE, bg.Mode.CARRY], "without losing you in the dark")
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


## The right stick fishes: its pull sets how far the cast goes.
func test_right_stick_casts() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(shore + Vector2(0, 60))
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	stick.is_pressed = true
	stick.output = Vector2(0, -0.5)
	await frames(10)
	check(player().state == Player.State.CHARGING, "a finger on the right stick starts the cast")
	check(player().charge_time / Player.MAX_CHARGE_TIME < 0.15, "the charge builds up gradually (%.2f)" % (player().charge_time / Player.MAX_CHARGE_TIME))
	await seconds(2.3)
	check(absf(player().charge_time / Player.MAX_CHARGE_TIME - 0.5) < 0.05, "half pulled, half the charge (%.2f)" % (player().charge_time / Player.MAX_CHARGE_TIME))
	check(player().aim_dir.dot(Vector2.UP) > 0.95, "the cast aims where the stick points")
	stick._reset()
	await frames(5)
	check(player().state != Player.State.CHARGING and player().state != Player.State.IDLE, "letting go casts")


## A tap on the right stick (no drag) casts out the usual distance.
func test_right_stick_tap_cast() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(shore + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	check(player().state == Player.State.CHARGING, "a tap starts the cast")
	stick._reset()
	await frames(1)
	check(absf(player().charge_time / Player.MAX_CHARGE_TIME - Player.CAST_TAP_RATIO) < 0.01, "a tap casts at the usual distance (%.2f)" % (player().charge_time / Player.MAX_CHARGE_TIME))


## Too far from the water, the stick doesn't cast.
func test_cast_only_near_water() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(away_from_water(Player.CAST_SHORE_RANGE + 10.0))
	check(player()._nearest_water_edge_distance() > Player.CAST_SHORE_RANGE, "standing back from the water")
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	check(player().state == Player.State.IDLE, "no cast from back there")
	stick._reset()
	await frames(2)


## With a line out, walking off from the water reels it in.
func test_walking_off_reels_in() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(shore + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	player().bait_count = 5
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	stick._reset()
	await frames(2)
	check(player().state == Player.State.WAITING, "cast from the bank")
	await put(shore + Vector2(0, 80))
	check(player().state == Player.State.WAITING, "a step or two back is fine")
	await put(away_from_water(Player.REEL_IN_SHORE_RANGE + 10.0))
	check(player().state == Player.State.IDLE, "too far off, the line comes in")


## A sideways dash: flick the stick the other way in time and the fish
## loses stamina; too late and it's a miss.
func test_fight_swipe() -> void:
	var tier: Dictionary = FishData.TIERS["mid"] if FishData.TIERS.has("mid") else FishData.TIERS.values()[0]
	var fight := FishFight.new("advanced", "", tier, 1.0)
	fight._jump_cooldown = 99.0
	fight._run_timer = 99.0
	fight.run_left = 1.0
	fight.run_side = Vector2.RIGHT
	fight.swipe_left = FishFight.SWIPE_WINDOW
	fight._swipe_armed = false
	check(fight.mood() == "side_run", "the fish reads as dashing sideways")
	var before := fight.progress
	var events := fight.update(0.05, false, Vector2.LEFT, Vector2.UP)
	check(not events.has("swipe_hit"), "a stick already held that way isn't a flick")
	events = fight.update(0.05, false, Vector2.ZERO, Vector2.UP)
	events = fight.update(0.05, false, Vector2.LEFT, Vector2.UP)
	check(events.has("swipe_hit"), "flicking against the dash hits")
	check(absf(fight.progress - before - FishFight.SWIPE_DAMAGE) < 0.01, "the fish loses stamina (%.2f)" % (fight.progress - before))
	check(fight.run_left == 0.0 and fight.swipe_left == 0.0, "the dash is broken")
	fight.run_left = 1.0
	fight.run_side = Vector2.LEFT
	fight.swipe_left = FishFight.SWIPE_WINDOW
	var missed := false
	for i in 25:
		if fight.update(0.05, false, Vector2.LEFT, Vector2.UP).has("swipe_miss"):
			missed = true
	check(missed, "flicking the wrong way runs out the time")
	check(fight.swipe_left == 0.0, "the window closes")


## A berserk fish drives the tension up much faster.
func test_fight_enrage_tension() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var calm := FishFight.new("master", "", tier, 1.0)
	var mad := FishFight.new("master", "", tier, 1.0)
	mad.enraged = true
	for f in [calm, mad]:
		f._jump_cooldown = 99.0
		f._run_timer = 99.0
		f.tension = 0.1
		f.update(0.2, true, Vector2.ZERO, Vector2.UP)
	check(mad.tension - 0.1 > (calm.tension - 0.1) * 1.5, "berserk, the line tightens fast (%.3f vs %.3f)" % [mad.tension, calm.tension])
	check(mad.mood() == "enraged", "and it reads as berserk")


## The light button: a tap stuns a ghost close by briefly; held, it charges.
func test_light_button_tap_and_hold() -> void:
	var lantern: Lantern = player().get_node("Lantern")
	var ghost: Node2D = main.get_node("Ghost")
	ghost.set_physics_process(false)
	await put(Vector2(1300, 400))
	ghost.global_position = player().global_position + Vector2(50, 10)
	lantern.lit = true
	lantern.flash_cooldown = 0.0
	player().skill_held = true
	await frames(3)
	player().skill_held = false
	await frames(3)
	check(ghost.stun_timer > 0.5 and ghost.stun_timer < Lantern.FLASH_STUN_DURATION, "a tap stuns the ghost close by, briefly (%.2f)" % ghost.stun_timer)
	ghost.stun_timer = 0.0
	ghost.global_position = player().global_position + Vector2(0, 140)
	lantern.flash_cooldown = 0.0
	player().skill_held = true
	player().skill_aim = Vector2.DOWN
	player().skill_dragged = true
	await seconds(1.5)
	check(lantern.boost > 0.9, "held, the light charges (%.2f)" % lantern.boost)
	player().skill_held = false
	await frames(3)
	check(ghost.stun_timer > Lantern.FLASH_STUN_DURATION, "a charged flash holds it longer (%.2f)" % ghost.stun_timer)
	ghost.set_physics_process(true)


## Reeling with the tension in the sweet spot gains line faster.
func test_fight_sweet_spot() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var inside := FishFight.new("normal", "", tier, 1.0)
	var outside := FishFight.new("normal", "", tier, 1.0)
	inside.tension = FishFight.SWEET_CENTER
	outside.tension = 0.1
	for f in [inside, outside]:
		f._jump_cooldown = 99.0
		f._run_timer = 99.0
		f.update(0.05, true, Vector2.ZERO, Vector2.UP)
	check(inside.progress > outside.progress * 1.4, "in the sweet spot, reeling gains faster (%.4f vs %.4f)" % [inside.progress, outside.progress])
	var r := inside.sweet_range()
	check(r.x < FishFight.SWEET_CENTER and r.y > FishFight.SWEET_CENTER, "the sweet spot sits around the middle")


## Striking right as the float goes under is a perfect strike.
func test_perfect_hook() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	var stick = main.get_node("HUD/Panel/AimJoystick")
	for late in [false, true]:
		player().tier_data = FishData.get_tier_data("mid").duplicate()
		player().tier_data.bite_window = 1.0
		player().difficulty_key = "normal"
		player().fish_habit = ""
		player().is_heart_catch = false
		player()._start_bite()
		check(player().perfect_hook_left() > 0.0, "the perfect moment opens with the bite")
		if late:
			await seconds(player().perfect_hook_window() + 0.1)
			check(player().perfect_hook_left() == 0.0, "and passes")
		stick._touch_index = 7
		await frames(2)
		stick._reset()
		check(player().state == Player.State.REELING, "the strike hooks it")
		if late:
			check(not player().fight.perfect and player().fight.progress < 0.05, "a late strike is an ordinary one")
		else:
			check(player().fight.perfect and player().fight.progress >= FishFight.PERFECT_HOOK_STAMINA - 0.01, "a quick strike is perfect: the fish starts worn (%.2f)" % player().fight.progress)
		player()._set_state(Player.State.IDLE)
		player().fight = null
		await frames(2)


## Holding a charged light on the float brings a bite sooner.
func test_light_lure() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(shore + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	player().fishing_mode = Player.FishingMode.BOBBER
	player().bait_count = 5
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	stick._reset()
	await frames(2)
	check(player().state == Player.State.WAITING, "cast and waiting")
	player().cast_target = player().global_position + Vector2(0, -90)
	player().cast_outcome = Player.CastOutcome.BITE
	player().nibbles_left = 0
	player().wait_timer = 30.0
	var lantern: Lantern = player().get_node("Lantern")
	lantern.lit = true
	await seconds(1.0)
	check(player().light_lure == 0.0, "the lamp alone doesn't lure")
	var before: float = player().wait_timer
	player().skill_held = true
	await seconds(2.0)
	check(player().light_lure > 0.5, "held on the float, the charged light lures (%.2f)" % player().light_lure)
	check(before - player().wait_timer > 3.0, "the bite comes sooner (%.2f s off in 2 s)" % (before - player().wait_timer))
	player().skill_held = false
	await frames(3)
	check(player().light_lure == 0.0, "let go, it stops")
	player()._set_state(Player.State.IDLE)


## The light button, held with the lamp out, relights it (no flash).
func test_light_button_relights() -> void:
	var tc: TouchControls = null
	for c in main.get_children():
		if c is TouchControls:
			tc = c
	tc.visible = true
	var lantern: Lantern = player().get_node("Lantern")
	lantern.put_out()
	lantern.fuel = maxf(lantern.fuel, 50.0)
	var down := InputEventScreenTouch.new()
	down.index = 4
	down.position = tc._skill_center
	down.pressed = true
	tc._input(down)
	await frames(2)
	check(not player().skill_held, "held while out, it doesn't charge a flash")
	await seconds(Lantern.RELIGHT_DURATION + 0.3)
	check(lantern.lit, "held, the lamp relights")
	var up := InputEventScreenTouch.new()
	up.index = 4
	up.position = tc._skill_center
	up.pressed = false
	tc._input(up)
	await frames(2)
	check(lantern.lit and not Input.is_key_pressed(KEY_L), "letting go leaves it lit")
	tc.visible = false


## Long-pressing an empty spot brings up the brightness slider.
func test_long_press_brightness() -> void:
	var tc: TouchControls = null
	for c in main.get_children():
		if c is TouchControls:
			tc = c
	tc.visible = true
	var spot := Vector2(470, 200)
	check(tc._is_empty_spot(spot), "an empty spot counts as empty")
	check(not tc._is_empty_spot(Vector2(802, 382)), "the right stick doesn't")
	check(not tc._is_empty_spot(tc._skill_center), "the light button doesn't")
	check(not tc._is_empty_spot(Vector2(40, 30)), "the character card doesn't")
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.position = spot
	down.pressed = true
	tc._input(down)
	await seconds(0.6)
	check(tc._slider.visible, "the slider comes up after a long press")
	var lantern: Lantern = player().get_node("Lantern")
	var before := lantern.brightness
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = spot + Vector2(0, -40)
	tc._input(drag)
	check(lantern.brightness > before, "sliding up brightens")
	drag.position = spot + Vector2(0, 200)
	tc._input(drag)
	check(not lantern.lit, "slid to the bottom, the lamp's out")
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.position = spot
	up.pressed = false
	tc._input(up)
	check(not tc._slider.visible, "letting go hides it")
	tc.visible = false


func test_status_card_opens_bag() -> void:
	var card: StatusCard = null
	var bag: Backpack = null
	for c in main.get_children():
		if c is StatusCard:
			card = c
		if c is Backpack:
			bag = c
	check(card != null, "there's a character card")
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(40, 30)
	tap.pressed = true
	card._input(tap)
	check(bag.is_open(), "tapping it opens the backpack")
	bag.toggle()
	check(StatusCard.speed_share(player()) > 0.99, "full speed when unladen")
	player().ghost_confuse(3.0)
	check(StatusCard.speed_share(player()) < 0.7, "slowed when dizzy")
	check(StatusCard.conditions(player()).size() > 0, "and it says why")


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
