extends Node

## The scenarios run by tests/run_tests.gd: each loads the real game scene,
## plays out a scenario (scripted input, the real game logic) and checks
## the outcome. Kept apart from run_tests.gd so it can use the game's
## classes and autoloads (a -s script is compiled before those exist).

const TESTS := [
	"test_campaign_levels_build",
	"test_campaign_level_one",
	"test_campaign_night_ends_safe_level",
	"test_campaign_curses",
	"test_campaign_unlocks_and_achievements",
	"test_journey_page",
	"test_run_3d",
	"test_map_generation",
	"test_layout_clear",
	"test_proto3d",
	"test_camp3d",
	"test_glow_mushroom",
	"test_death_loses_finds",
	"test_fish_life",
	"test_mythic_traits",
	"test_tank_moves_and_feeding",
	"test_oxy_items",
	"test_oxy_algae",
	"test_character_abilities",
	"test_run_menu_and_auto_defend",
	"test_wolf_bites",
	"test_run_intro_and_eye_guide",
	"test_intro_lamp_clear",
	"test_spawn_on_land_docks_out",
	"test_catalog_and_sounds",
	"test_creature_animation",
	"test_refuel",
	"test_sacrifice_and_altar_stages",
	"test_turn_rock",
	"test_escape",
	"test_big_ghost_grab_lost",
	"test_big_ghost_heart_frees",
	"test_big_ghost_light_frees",
	"test_big_ghost_fish_frees",
	"test_big_ghost_follows_the_light",
	"test_big_ghost_night_hunt",
	"test_big_ghost_eats_thrown_fish",
	"test_big_ghost_fish_taken_back",
	"test_big_ghost_appears_on_waking",
	"test_touch_flash_holds_ghosts",
	"test_bait_slot",
	"test_light_flash_stuns",
	"test_right_stick_casts",
	"test_right_stick_tap_cast",
	"test_cast_whip_follows_wind_up",
	"test_rod_bends_with_the_fish",
	"test_characters",
	"test_character_packs",
	"test_usable_items",
	"test_quick_slots",
	"test_player_moves",
	"test_live_bait_and_net",
	"test_cast_only_near_water",
	"test_walking_off_reels_in",
	"test_fight_swipe",
	"test_fight_enrage_tension",
	"test_fight_sweet_spot", "test_fight_line_distance", "test_fight_fish_keeps_its_water", "test_fight_line_out", "test_fight_leap_far_out",
	"test_fight_swim_out_by_fish", "test_fight_spent_reeled_in", "test_fight_opening", "test_fight_fish_swims", "test_fight_leap_close_in", "test_crank_by_turning_the_stick", "test_offhand_swing_and_wear",
	"test_perfect_hook",
	"test_light_lure",
	"test_lure_retrieve",
	"test_lure_strike_direction",
	"test_fish_by_style",
	"test_main_menu",
	"test_catch_details",
	"test_warehouse_and_bag",
	"test_lists_scroll_under_a_finger",
	"test_lure_throw_and_drops",
	"test_hud_top",
	"test_bag_drag_out",
	"test_fish_tank",
	"test_camp_spirit_and_tents",
	"test_camp_life",
	"test_ears_and_tails",
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
	"test_shop_new_wares",
	"test_black_spider",
	"test_chop_and_weapons",
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
	# (runs start straight away - the opening has its own test)
	RunView3D.intro = false
	for t in TESTS:
		if only != "" and not t in only.split(","):
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


func _fresh_game(rng_seed := 7) -> void:
	seed(rng_seed)
	# The plain free run unless a test plays a level.
	camp().clear()
	gs.reset_run()
	# A run an earlier test ended isn't one to come home from.
	gs.last_return = ""
	# (every test's gear as good as new: casts wear the rod; nothing in the
	# off hand - a tap of the right stick casts - unless a test puts it on)
	Profile.wear.clear()
	Profile.unequip("offhand")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	await frames(2)


func player() -> Player:
	return main.get_node("Player")


func camp() -> Node:
	return get_tree().root.get_node("Campaign")


## Into level `id` the way the results screen's buttons go (no camp).
func play_level(id: String) -> void:
	camp().begin_level(id)
	gs.last_return = ""
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	await frames(3)


## A clean slate of campaign progress (the profile is the real one).
func reset_progress() -> void:
	Profile.campaign = {"levels": {}, "chapter_bonus": [], "curse_clears": 0, "best_curses": 0}
	Profile.achievements = {}
	Profile.records = {}


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


func fish(name := "鯉魚", tier := "near") -> Dictionary:
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


func _all_nodes(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out


## User bug report: the spawn point was under water on some maps. Across
## many maps it's on dry land, and every common pond has a dock reaching
## out into it (none lying along the bank).
func test_spawn_on_land_docks_out() -> void:
	var wet := 0
	var dockless := 0
	for s in range(1, 41):
		seed(s * 7919)
		gs.reset_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		await frames(3)
		main = get_tree().current_scene
		var docked: bool = main.get_node("MapGenerator").theme.get("docks", true)
		var spawn := MapGenerator.SPAWN_POS
		for z in main.get_tree().get_nodes_in_group("water_zones"):
			if z.distance_to_edge(spawn) < 80.0:
				wet += 1
		# (user request: one dock, on the biggest water)
		var commons: Array = main.get_tree().get_nodes_in_group("water_zones_common")
		commons.sort_custom(func(a, b): return MapGenerator._zone_area(a) > MapGenerator._zone_area(b))
		for i in commons.size():
			var z = commons[i]
			var has := false
			for w in main.get_tree().get_nodes_in_group("walkways"):
				if z.contains(w.walk_rect.get_center()) or z.distance_to_edge(w.walk_rect.get_center()) < 1.0:
					has = true
			if docked and has != (i == 0):
				dockless += 1
	check(wet == 0, "the spawn point is on dry land on every map (%d wet)" % wet)
	check(dockless <= 2, "a dock on the biggest water only (%d maps otherwise)" % dockless)


## User request (3D): nothing in anything, nothing crowded. No two solid
## bases overlap (the camp's own parts aside - laid out by hand), no two
## trees' branches meet, none over the bank; and a ghost walked straight
## at a tree goes round it, never into it.
func test_layout_clear() -> void:
	var camp: Vector2 = main.get_node("FuelStation").global_position
	var bases := Solids.all(get_tree())
	var hits := []
	for i in bases.size():
		for j in range(i + 1, bases.size()):
			var a: Array = bases[i]
			var b: Array = bases[j]
			if (a[0] as Vector2).distance_to(camp) < 150.0 and (b[0] as Vector2).distance_to(camp) < 150.0:
				continue
			var gap: float = (a[0] as Vector2).distance_to(b[0]) - maxf(a[1].x, a[1].y) - maxf(b[1].x, b[1].y)
			if gap < 0.0:
				hits.append([a[0], b[0], gap])
	check(bases.size() > 20 and hits.is_empty(), "no solid in another (%d solids; %s)" % [bases.size(), str(hits)])
	var trees := get_tree().get_nodes_in_group("trees")
	var crowns := 0
	var over_bank := 0
	for i in trees.size():
		var t: MapTree = trees[i]
		var shore := INF
		for zone in get_tree().get_nodes_in_group("water_zones"):
			shore = minf(shore, zone.distance_to_edge(t.global_position))
		if shore < t.canopy():
			over_bank += 1
		for j in range(i + 1, trees.size()):
			if t.global_position.distance_to(trees[j].global_position) < t.canopy() + trees[j].canopy():
				crowns += 1
	check(crowns == 0, "no two trees' branches meet (%d)" % crowns)
	check(over_bank == 0, "no branches over the bank (%d)" % over_bank)
	var tree: MapTree = trees[0]
	var at := tree.global_position + Vector2(-80, 1)
	var inside := 0
	for _i in 120:
		at = Solids.step(get_tree(), at, at + Vector2(2.5, 0), 16.0)
		if at.distance_to(tree.global_position) < tree.trunk_radius + 15.5:
			inside += 1
	check(inside == 0 and at.x > tree.global_position.x + 20.0, "a ghost goes round a tree, not through (%d inside, got to %.0f)" % [inside, at.x - tree.global_position.x])


## The generated catalog's textures and every sound the game asks for exist.
func test_catalog_and_sounds() -> void:
	var sounds := ["cast", "plop", "nibble", "splash", "splash_small", "reel_loop", "creak_loop", "snap",
		"perfect", "catch", "fail", "ignite", "extinguish", "flash", "step_soft", "step_hard", "step_wood",
		"step_snow", "chain_loop", "whisper", "moan", "emerge", "cage", "heartbeat_loop", "offering",
		"rock_flip", "tap", "swipe_hit", "flop", "thunder", "escape", "amb_night", "amb_day", "amb_water",
		"amb_rain", "amb_wind", "amb_swamp", "amb_jungle", "amb_surf", "music_day", "music_night",
		"ui_click", "ui_open", "ui_close", "coins", "amb_camp", "camp_crickets_loop", "music_camp", "chop",
		"gunshot"]
	var lost := sounds.filter(func(n): return Sfx.stream(n) == null)
	check(lost.is_empty(), "every sound loads %s" % str(lost))
	# (user request, round 3: the sound's switch is in the gear menu in a run)
	var toggle: SoundToggle = null
	for c in main.get_children():
		if c is SoundToggle:
			toggle = c
	check(toggle != null and not toggle.shown and not toggle.contains(SoundToggle.CENTER), "no speaker on the screen in a run")
	var hud = main.get_node("HUD")
	hud.open_run_menu()
	await frames(2)
	var switch: Button = hud.find_child("SoundSwitch", true, false)
	var was: bool = Sfx.muted
	switch.pressed.emit()
	check(Sfx.muted != was and switch.text.contains("關" if Sfx.muted else "開"), "the menu's switch mutes")
	switch.pressed.emit()
	check(Sfx.muted == was, "and unmutes")
	get_tree().paused = false
	hud.get_node("RunMenuLayer/RunMenuShade").queue_free()
	await frames(2)
	for bed in ["amb_rain", "amb_camp", "camp_crickets_loop", "music_camp"]:
		var s := Sfx.stream(bed)
		var loops: bool = s.loop if s is AudioStreamOggVorbis else \
			s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
		check(loops, "%s loops" % bed)


## User feedback: the big and small ghosts were stiff, the animals walked
## stiffly - they animate and turn through 8 facings now.
func test_creature_animation() -> void:
	check(Art.facing8(Vector2(1, 0.5), 6) == 6, "a heading near the facing keeps it")
	check(Art.facing8(Vector2(1, 1), 6) == 7, "a diagonal turns it")
	check(Art.facing8(Vector2(-1, 0), 0) == 2, "left faces left")
	var bg = main.get_node("BigGhost")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	bg.global_position = Vector2(1500, 300)
	bg.mode = bg.Mode.CHASE
	await put(bg.global_position + Vector2(-220, 0))
	var chase_from: int = bg.CLIPS.float * bg.DIRS
	var seen := {}
	for i in 30:
		await frames(2)
		seen[bg.visual.frame] = true
	check(seen.size() >= 4, "the big ghost moves (%d frames seen)" % seen.size())
	check(seen.keys().all(func(f): return f >= chase_from and f < chase_from + bg.CLIPS.chase * bg.DIRS),
		"lurching through its chase frames %s" % str(seen.keys()))
	check(bg.lamp_light.position != Vector2.ZERO, "its lantern is placed")
	var ghost: Node2D = of_script("/ghost.gd")[0]
	seen = {}
	for i in 30:
		await frames(2)
		seen[ghost.visual.frame] = true
	check(seen.size() >= 4, "a floating ghost flutters (%d frames seen)" % seen.size())
	check(seen.keys().all(func(f): return f < ghost.visual.hframes * ghost.visual.vframes), "within its sheet")
	var wg := WaterGhost.summon(player())
	check(wg != null, "a water ghost comes up")
	if wg != null:
		await frames(40)
		check(wg._visual.frame < WaterGhost.DIRS * WaterGhost.COLS, "it walks on its walk rows")
		wg._next(WaterGhost.Phase.CLING)
		await frames(10)
		check(wg._visual.frame >= WaterGhost.DIRS * WaterGhost.COLS, "and claws on its claw rows (frame %d)" % wg._visual.frame)
		wg.queue_free()
	# (user decision: 3D only) every critter and animal about is shown as
	# its own model.
	for c in of_script("/critter.gd"):
		check(RunView3D.CREATURES.has(c.species) and ResourceLoader.exists(RunView3D.CREATURE_DIR + c.species + ".glb"),
			"%s: a 3D model" % c.species)


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
	# User request: a tap opens the bag to pick which fish to offer.
	await tap(KEY_E)
	var bag: Backpack = player().backpack()
	check(bag.is_open() and bag.mode() == "sacrifice", "a tap at the altar opens the bag to pick the fish")
	bag.select("fish", 0)
	bag.select("fish", 3)
	await frames(1)
	var offer_button: Button = bag.find_child("Offer", true, false)
	check(offer_button != null and not offer_button.disabled, "an offer button for the picked fish")
	offer_button.pressed.emit()
	await frames(2)
	check(gs.quota_progress > before, "quota rose")
	check(gs.carried_fish.size() == 8, "the two picked were offered")
	check(not bag.is_open(), "and the bag closed")
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
	# (user request: the heave seen first - the stone tips as it comes)
	check(rock._roller.position.length() < 0.5, "not tipped before the heave")
	await seconds(Player.ROCK_HEAVE_AT + FlipRock.ROLL_TIME + 0.2)
	var moved: float = rock._roller.position.length()
	check(moved > 6.0 and moved < 20.0, "rock tipped aside, only just (%.1f px)" % moved)
	check(absf(rock._roller.rotation) < 0.6, "leaning over a little, not rolled (%.2f)" % rock._roller.rotation)


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
	# (user request: down on a knee at the 渡石 a moment first)
	check(player().move_kind == "kneel" and not gs.run_over, "a knee bent at the 渡石 first")
	await seconds(Player.ESCAPE_KNEEL + 0.2)
	check(gs.run_over, "run ended by escaping")


func _big_ghost_catch() -> Node:
	var bg = main.get_node("BigGhost")
	var cage: Node2D = main.get_node("GhostCage")
	gs.time_remaining = gs.DAY_DURATION * 0.7
	player().set_physics_process(false)
	await put(cage.global_position + Vector2(-60, 50))
	player().set_physics_process(true)
	# Close enough that it notices (not left to where it wanders).
	bg.global_position = player().global_position + Vector2(50, 0)
	bg.mode = bg.Mode.WANDER
	return bg


## User request (Camp v2): caught, there are a few seconds to struggle
## free; not free in time, the run is lost - the player wakes at the camp,
## spirit down by 25.
func test_big_ghost_grab_lost() -> void:
	Profile.spirit = 80.0
	var bg = await _big_ghost_catch()
	var grabbed := false
	for _i in 60 * 20:
		await get_tree().process_frame
		if bg.mode == bg.Mode.GRAB:
			grabbed = true
			break
	check(grabbed and player().held and player().struggling, "seized where it stands, struggling")
	var spot: Vector2 = player().global_position
	var overlay: Control = main.find_child("Grip", true, false)
	await frames(2)
	check(overlay != null and overlay.visible, "the screen closes in")
	check(not overlay.find_child("UseHeart", true, false).visible, "no heart, no heart button")
	check(player().get_node("Body").struggling, "the struggle sheet")
	await seconds(1.0)
	check(player().global_position.distance_to(spot) < 1.0 and not gs.run_over, "not carried off - held, the clock running")
	for _i in 60 * 5:
		await get_tree().process_frame
		if gs.run_over:
			break
	check(gs.run_over and gs.last_cause == "caught" and gs.last_return == "lost", "not free in time: taken")
	check(is_equal_approx(Profile.spirit, 55.0), "spirit -25 (%d)" % Profile.spirit)
	Profile.spirit = 100.0


func _wait_grab(bg) -> bool:
	for _i in 60 * 20:
		await get_tree().process_frame
		if bg.mode == bg.Mode.GRAB:
			return true
	return false


func test_big_ghost_heart_frees() -> void:
	gs.grant_heart()
	var bg = await _big_ghost_catch()
	check(await _wait_grab(bg), "seized")
	await frames(2)
	check(gs.has_heart and player().held, "the heart isn't spent by itself")
	var button: Button = main.find_child("UseHeart", true, false)
	check(button != null and button.visible, "a heart: its button")
	button.pressed.emit()
	await frames(2)
	check(bg.mode == bg.Mode.REST, "the heart breaks its grip")
	check(not gs.run_over, "survived")
	check(not player().held and player().knocked(), "let go, staggering back")
	check(not gs.has_heart, "heart spent")
	await seconds(1.0)
	check(not player().knocked() and not player().get_node("Body").struggling, "back on its feet")


func test_big_ghost_light_frees() -> void:
	var bg = await _big_ghost_catch()
	check(await _wait_grab(bg), "seized")
	var lantern: Lantern = player().get_node("Lantern")
	lantern.lit = true
	lantern.flash_cooldown = 0.0
	# A quick tap of the light button: the strong light in its face.
	player().skill_held = true
	await frames(2)
	player().skill_held = false
	await frames(3)
	check(bg.mode == bg.Mode.REST and bg.stun_timer > 0.0, "the strong light makes it let go (mode %s)" % bg.Mode.keys()[bg.mode])
	check(not player().held and not gs.run_over, "free")


func test_big_ghost_fish_frees() -> void:
	gs.add_carried_fish(fish())
	gs.set_lure(0)
	var bg = await _big_ghost_catch()
	check(await _wait_grab(bg), "seized")
	# 誘惑, tapped: a fish thrown a little way.
	player().lure_held = true
	await frames(2)
	player().lure_held = false
	for _i in 60:
		await get_tree().process_frame
		if bg.mode != bg.Mode.GRAB:
			break
	check(bg.mode == bg.Mode.EAT, "it drops you for the fish (mode %s)" % bg.Mode.keys()[bg.mode])
	check(not player().held and not gs.run_over, "free")


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
	check(bg.mode in [bg.Mode.CHASE, bg.Mode.GRAB], "without losing you in the dark")
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


## User request: the dragon isn't on the map till it sets out; then it comes
## out somewhere at random, on land, well away from the traveller.
func test_big_ghost_appears_on_waking() -> void:
	var bg = main.get_node("BigGhost")
	bg._go_home()
	await frames(2)
	check(bg.mode == bg.Mode.ASLEEP and not bg.visible, "asleep: not on the map")
	var lair: Vector2 = bg._lair.global_position + BigGhost.HOME
	var far := 0
	for _i in 8:
		var at: Vector2 = bg._spawn_point()
		if at.distance_to(player().global_position) >= BigGhost.SPAWN_AWAY and not bg._wet(at) and not bg._in_safe_zone(at):
			far += 1
	check(far >= 7, "where it comes out: on land, far from the traveller (%d/8)" % far)
	gs.time_remaining = gs.DAY_DURATION * 0.3
	Campaign.rules.big_wake = 0
	for _i in 30:
		await frames(1)
		if bg.mode != bg.Mode.ASLEEP:
			break
	await frames(2)
	check(bg.mode != bg.Mode.ASLEEP and bg.visible and bg.global_position.distance_to(lair) > 10.0,
		"awake: out on the map, not at its lair")
	Campaign.rules.big_wake = -1
	bg._go_home()


## User report: aimed and charged on the light button and let go at a ghost
## - nothing: it didn't stop, no flash. The whole touch path, at a floating
## ghost and at the dragon, both moving.
func test_touch_flash_holds_ghosts() -> void:
	var tc: TouchControls = null
	for c in main.get_children():
		if c is TouchControls:
			tc = c
	tc.visible = true
	var lantern: Lantern = player().get_node("Lantern")
	lantern.lit = true
	lantern.fuel = lantern.max_fuel
	await put(Vector2(1300, 400))
	var ghost: Node2D = main.get_node("Ghost")
	var bg = main.get_node("BigGhost")
	for target in [ghost, bg]:
		lantern.flash_cooldown = 0.0
		# (user report: 58% left - a full charge must still go off)
		lantern.fuel = lantern.max_fuel * 0.58
		if target == bg:
			bg.mode = bg.Mode.WANDER
			ghost.global_position = player().global_position + Vector2(-600, -600)
		target.global_position = player().global_position + Vector2(0, 130)
		await frames(2)
		var down := InputEventScreenTouch.new()
		down.index = 5
		down.position = tc._skill_center
		down.pressed = true
		tc._input(down)
		var drag := InputEventScreenDrag.new()
		drag.index = 5
		drag.position = tc._skill_center + Vector2(0, 60)
		tc._input(drag)
		for _i in 90:
			target.global_position = player().global_position + Vector2(0, 130)
			await frames(1)
		var up := InputEventScreenTouch.new()
		up.index = 5
		up.position = drag.position
		up.pressed = false
		tc._input(up)
		await frames(3)
		var at: Vector2 = target.global_position
		check(target.stun_timer > Lantern.FLASH_STUN_DURATION, "%s: flashed, held (%.2f s)" % [target.name, target.stun_timer])
		var view: RunView3D = RunView3D.active
		if view != null:
			check(view._flash_light.visible, "%s: the flash seen" % target.name)
		await seconds(1.0)
		check(target.global_position.distance_to(at) < 2.0, "%s: and stays put (%.1f px)" % [target.name, target.global_position.distance_to(at)])
	# Short of a full charge's cost: it goes off as strong as it can; with
	# nothing to pay for one, it says so (in the feed), not silently.
	lantern.fuel = lantern.max_fuel * (Lantern.FLASH_SHARE * 1.2)
	check(lantern.affordable_charge() > 0.0 and lantern.affordable_charge() < 1.0, "a little fuel: part of a charge")
	lantern.fuel = lantern.max_fuel * Lantern.FLASH_SHARE * 0.5
	var card: StatusCard = main.find_child("StatusCard", true, false)
	lantern.flash_cooldown = 0.0
	lantern.boost = 1.0
	lantern.release_flash()
	await frames(2)
	check(lantern.affordable_charge() < 0.0 and card != null and card.feed.size() > 0 and str(card.feed[0][0]).contains("燈油不夠"),
		"too little: told so")
	lantern.fuel = lantern.max_fuel
	bg._go_home()
	tc.visible = false


## User request (round 3): the right side, bottom up - the light, 誘惑, the
## three quick slots, the bait on the line - none over another or the
## stick's middle; the bait slot shows what's on the hook and swaps it from
## a little window over it (between casts).
func test_bait_slot() -> void:
	var bs: BaitSlot = main.get_node("BaitSlot")
	var spots := [[TouchControls.SKILL_AT, TouchControls.SKILL_RADIUS], [TouchControls.LURE_AT, TouchControls.LURE_RADIUS],
		[BaitSlot.AT, BaitSlot.SIDE * 0.5]]
	for c in QuickSlots.CENTERS:
		spots.append([c, QuickSlots.SIDE * 0.5])
	var clear := true
	for i in spots.size():
		var a: Vector2 = spots[i][0]
		if a.distance_to(TouchControls.AIM_CENTER) < float(spots[i][1]) + 60.0 or a.x + float(spots[i][1]) > 960.0:
			clear = false
		for j in range(i + 1, spots.size()):
			if a.distance_to(spots[j][0]) < float(spots[i][1]) + float(spots[j][1]) + 4.0:
				clear = false
	check(clear, "the buttons clear of each other and of the stick")
	var stick: Control = main.get_node("HUD/Panel/AimJoystick")
	check(stick.get_global_rect().get_center().distance_to(TouchControls.AIM_CENTER) < 2.0,
		"the stick where the reel's drawn (%s)" % stick.get_global_rect().get_center())
	check(TouchControls.SKILL_AT.y > TouchControls.LURE_AT.y and TouchControls.LURE_AT.y > QuickSlots.CENTERS[0].y
		and QuickSlots.CENTERS[0].y > BaitSlot.AT.y, "bottom up: light, 誘惑, the quick slots, the bait")
	var p := player()
	p.live_bait = ""
	p.fishing_mode = Player.FishingMode.BOBBER
	check(BaitSlot.current(p)[0] == "bait" and int(BaitSlot.current(p)[1]) == p.bait_count, "the base bait shown, and how many")
	Profile.bag_put("live_worm", 2)
	p.lure_stock["minnow"] = 1
	var ids := BaitSlot.choices(p).map(func(c): return c[0])
	check("bait" in ids and "live_worm" in ids and "lure_minnow" in ids, "what there is to fish with: %s" % [ids])
	bs.tap()
	await frames(2)
	check(bs.picker_open(), "tapped: the window over it")
	var b: Button = bs.find_child("Bait_live_worm", true, false)
	check(b != null, "the worms in it")
	b.pressed.emit()
	await frames(2)
	check(not bs.picker_open() and p.live_bait == "worm" and BaitSlot.current(p)[0] == "live_worm", "picked: the worm on the hook")
	bs.tap()
	await frames(2)
	(bs.find_child("Bait_lure_minnow", true, false) as Button).pressed.emit()
	await frames(2)
	check(p.fishing_mode == Player.FishingMode.LURE and BaitSlot.current(p)[0] == "lure_minnow", "and a lure on the line")
	p.state = Player.State.WAITING
	bs.tap()
	await frames(2)
	check(not bs.picker_open(), "mid-cast: not now")
	p.state = Player.State.IDLE
	(BaitSlot.choices(p)[0][3] as Callable).call()
	check(p.fishing_mode == Player.FishingMode.BOBBER and p.live_bait == "", "back to the base bait")
	var card: StatusCard = main.find_child("StatusCard", true, false)
	check(not StatusCard.SHOW_GEAR, "no bait under the character card any more")


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


## User request (round 5): letting go of a charge plays on from the
## wind-up frame it got to, one frame at a time - no cut to the whip's top.
func test_cast_whip_follows_wind_up() -> void:
	check(PlayerVisual.whip_start(-1) == 4, "no wind-up shown: the whip as before")
	check(PlayerVisual.whip_start(3) == 4, "a full wind-up whips from frame 4")
	check(PlayerVisual.whip_start(0) == 1 and PlayerVisual.whip_start(1) == 2, "an early release plays on from the next frame")
	# User request: long casts two-handed, short ones one-handed.
	check(PlayerVisual.cast_clip(1.0) == PlayerVisual.CLIP_CAST and PlayerVisual.cast_clip(PlayerVisual.TWO_HAND_RATIO) == PlayerVisual.CLIP_CAST,
		"a long cast: two-handed")
	check(PlayerVisual.cast_clip(Player.CAST_TAP_RATIO) == PlayerVisual.CLIP_CAST_SHORT and PlayerVisual.cast_clip(0.1) == PlayerVisual.CLIP_CAST_SHORT,
		"a short one (a tap too): one-handed")
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	var shore: Vector2 = zone.shore_point(Vector2.DOWN)
	await put(shore + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	var visual = player().get_node("Body")
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	stick._reset()
	var seen := []
	for i in 30:
		await frames(1)
		# (a tap is a short cast: one-handed, user request)
		if visual.clip == PlayerVisual.CLIP_CAST_SHORT and (seen.is_empty() or seen[-1] != visual.frame_in_clip):
			seen.append(visual.frame_in_clip)
	check(not seen.is_empty() and seen[0] <= 2, "a tap's whip starts next to its wind-up (%s)" % [seen])
	var steps_ok := true
	for i in range(1, seen.size()):
		steps_ok = steps_ok and seen[i] - seen[i - 1] <= 2 and seen[i] > seen[i - 1]
	check(steps_ok, "and runs forward without a cut (%s)" % [seen])


## (Candidate, user request round 6: the fight shows the fish pulling.)
## The rod is straight with no fish on; hooked, it bends toward the line,
## more as the tension rises; the line leaves its bent tip; a run's yank
## jolts the body toward the fish and bends the rod harder.
## User request: the animals in the game (the four, then the deer and the
## sheep), tapping the camp's fire to
## change who's travelling - each with its own pictures in the run (the
## sheet, its front layer and rod data, the struggle sheet) and its own
## model at camp.
## The Mixamo clips every camp model has (CampLife plays them).
const CAMP_MIXAMO := ["Lie_Down", "Lying", "Sleep_B", "Ground_Sit", "Ground_Stand", "Seat_Rest", "Seat_Clap", "Seat_Drink",
	"Drink", "Stretch_Neck", "Stretch_Arms", "Look_Around", "Peek", "Wave_Big", "Wave", "Beckon", "Clap", "Fist_Pump",
	"Victory", "Disappointed", "Sad", "Sad_B"]


func test_characters() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 100, "spirit": 95.0})
	for c in Profile.CHARACTERS:
		var id: String = c[0]
		var data := CharacterArt.rod_data(id)
		# (user decision: 3D only - its model and its portrait, no sheets)
		check(CharacterArt.model(id) != null and CharacterArt.portrait_texture(id) != null, "%s: its model and portrait" % id)
		check(data.clips == PlayerVisual.CLIP_NAMES and data.rod.has("fight") and data.has("front") and data.has("crank"),
			"%s: its rod data has every clip, the front layer and the crank" % id)
		var body: Node3D = CharacterArt.model(id).instantiate()
		var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
		var clips := ["Idle", "Walk", "Interact", "Sitting_Idle", "Sitting_Enter", "Fixing_Kneeling"]
		check(clips.all(func(n): return anim.has_animation(n)), "%s: its camp model has the camp's clips" % id)
		# (user request: the user's Mixamo clips at the camp too)
		var missing: Array = CAMP_MIXAMO.filter(func(n): return not anim.has_animation(n))
		check(missing.is_empty(), "%s: and the Mixamo ones (%s)" % [id, ", ".join(missing)])
		var loops := ["Lying", "Sleep_B", "Ground_Sit", "Seat_Rest", "Sad"].filter(func(n): return anim.has_animation(n))
		check(loops.all(func(n): return anim.get_animation(n).loop_mode == Animation.LOOP_LINEAR), "%s: the loops loop" % id)
		# Sat on the log as Sitting_Idle is (the hips where its seat is).
		var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
		var pelvis := sk.find_bone("pelvis")
		var seat_at := {}
		for n in ["Sitting_Idle", "Seat_Drink", "Seat_Clap", "Seat_Rest"]:
			var a3 := anim.get_animation(n)
			if a3 == null:
				continue
			var tr := a3.find_track(NodePath("%s:pelvis" % body.get_path_to(sk)), Animation.TYPE_POSITION_3D)
			if tr >= 0:
				seat_at[n] = a3.position_track_interpolate(tr, a3.length * 0.5)
		var off := 0.0
		for n in seat_at:
			off = maxf(off, (seat_at[n] as Vector3).distance_to(seat_at.get("Sitting_Idle", seat_at[n])))
		check(seat_at.size() == 4 and off < 0.01, "%s: tea, a clap, a rest on the log, sat as it sits (%.3f)" % [id, off])
		body.free()
		# Its moves in a run (their data: the 3D view plays them as clips).
		var md := CharacterArt.moves_data(id)
		check(md.get("clips", []) == PlayerVisual.MOVE_NAMES, "%s: every move" % id)
		var face := CharacterArt.portrait_texture(id).get_image()
		check(not face.is_invisible(), "%s: the card's portrait has its head in it" % id)
		# (user request: each one's own body measured - tools/measure_bodies.gd)
		var fit := CharacterArt.fit(id)
		check(["grip", "grip_axis", "hand_l", "hand_r", "forearm", "shoulder", "pelvis", "arm", "front", "side", "walk"].all(
			func(k): return fit.has(k)) and float(fit.grip_room) > 0.005, "%s: its body measured, a hole in its fist" % id)

	# At camp: the fire is a thing to tap - it opens the characters' page
	# (user request): the camera in close on the fire, everyone's portrait
	# down the left, the one picked whole on the right; 選擇 and it takes
	# over at the fire.
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	var camp: CampStage = title.find_child("Camp", true, false)
	check(camp.hotspots.has("character"), "the fire can be tapped")
	check(camp.character.character == "cat", "the black cat to start")
	var fire: Vector2 = camp.camera.unproject_position(camp.hotspots.character.parts[0][1]) / TitleScreen.RENDER_SCALE
	check(title.spot_at(fire) == "character", "the fire's where it's tapped")
	var lamp_was: Vector3 = camp.spots.lamp.at
	var home_cam: Vector3 = camp.camera.global_position
	var seen := []
	for i in Profile.CHARACTERS.size():
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = fire
		title._on_home_input(press)
		var lift := press.duplicate() as InputEventMouseButton
		lift.pressed = false
		title._on_home_input(lift)
		await seconds(0.8)
		var page = title.get("_page")
		check(page is CharacterPage, "tap %d: the characters' page opens" % (i + 1))
		if not page is CharacterPage:
			break
		if i == 0:
			var near_fire: float = camp.camera.global_position.distance_to(CampStage.FIRE_AT)
			check(near_fire < home_cam.distance_to(CampStage.FIRE_AT) - 2.0, "the camera's in close on the fire (%.1f m)" % near_fire)
			check(page._cells.size() == Profile.CHARACTERS.size(), "every character's portrait in the list")
			check(page._cells.cat.get_node("InUse").visible and not page._cells.owl.get_node("InUse").visible,
				"the one travelling marked")
			check(page._viewer.rig.character == "cat" and page._choose.disabled, "it shows the one travelling first, not to choose again")
		var id: String = Profile.CHARACTERS[(i + 1) % Profile.CHARACTERS.size()][0]
		page.pick(id)
		await frames(3)
		check(page._viewer.rig.character == id and page._viewer.rig.anim != null and not page._choose.disabled,
			"%s picked: shown whole on the right" % id)
		check(page._title.text == Profile.character_name(id), "named over it (%s)" % page._title.text)
		page.choose()
		await frames(3)
		seen.append(Profile.character)
		check(camp.character.character == Profile.character and Profile.character == id and camp.character.anim != null
			and camp.character.anim.is_playing(), "chosen: %s at the fire, alive" % id)
		check(title._who.text.ends_with(Profile.character_name()), "the card names it (%s)" % title._who.text)
		check(title.get("_page") == null and title._spot_label.text == Profile.character_name(), "the page closed, its name over the fire")
		if i == 0:
			check(camp.spots.lamp.at.distance_to(lamp_was) > 0.01, "it stands where its own hand reaches the lamp")
		await seconds(0.6)
	var round := Profile.CHARACTERS.slice(1).map(func(c): return c[0]) + ["cat"]
	check(seen == round, "round them all and back (%s)" % [seen])
	title.queue_free()
	await frames(1)

	# Into a run as the one chosen: its sheet, its rod data.
	Profile.character = "bear"
	await _fresh_game()
	var visual: PlayerVisual = player().get_node("Body")
	check((visual.texture as CanvasTexture).diffuse_texture == CharacterArt.sheet("bear")[0], "in the run it's the bear")
	var off: Array = CharacterArt.rod_data("bear").offset
	check(visual._sheet_offset == Vector2(off[0], off[1]), "framed by its own rod data")
	check(Profile.snapshot().character == "bear", "and it's saved")
	Profile.load_data(saved)
	Profile._save()


## User request (the web build's size): on the web only the first
## character comes with the game, each other one a pack fetched when it's
## wanted (CharacterPacks) - the game opened with one not fetched waits for
## it behind a cover; one not fetched picked on the fire's page shows how far
## along where it'll stand, and can be chosen once it's in. (Here they're all on disk:
## `missing` makes them look not fetched, a fetch only pretending.)
func test_character_packs() -> void:
	var saved := Profile.snapshot()
	check(Profile.CHARACTERS.all(func(c): return CharacterPacks.has(c[0])), "off the web every character's there")
	Profile.load_data({"gold": 100, "spirit": 95.0, "character": "dog"})
	CharacterPacks.missing = {"dog": true, "owl": true}
	CharacterPacks.pretend_time = 0.6
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	check(title.find_child("PackCover", true, false) != null and title.find_child("Camp", true, false) == null,
		"opened as one not fetched: a cover while it comes, no camp yet")
	await seconds(1.0)
	var camp: CampStage = title.find_child("Camp", true, false)
	check(title.find_child("PackCover", true, false) == null and camp != null and camp.character.character == "dog",
		"then the camp, with it there")
	title.queue_free()
	await frames(2)
	# One not fetched picked at the fire (the owl).
	Profile.choose_character("cat")
	title = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	camp = title.find_child("Camp", true, false)
	title.open_page("character")
	await frames(2)
	var page: CharacterPage = title.get("_page")
	page.pick("owl")
	await frames(2)
	check(CharacterPacks.fetching("owl") and page._cover.visible and page._cover_text.text.contains("下載中")
		and page._choose.disabled and page._viewer.rig.character == "cat", "the owl not here: fetched first, how far along where it'll stand")
	page.choose()
	await frames(2)
	check(Profile.character == "cat" and camp.character.character == "cat", "not to be chosen till it's in")
	await seconds(1.0)
	check(not page._cover.visible and page._viewer.rig.character == "owl" and not page._choose.disabled, "once it's in, shown")
	page.choose()
	await frames(2)
	check(camp.character.character == "owl" and Profile.character == "owl", "and chosen, the owl takes over")
	title.queue_free()
	await frames(2)
	# User report: stuck on 下載角色 with an empty bar on a phone. A slow
	# one offers a way in as the cat after a few seconds.
	Profile.load_data({"gold": 100, "spirit": 95.0, "character": "dog"})
	CharacterPacks.missing = {"dog": true}
	CharacterPacks.pretend_time = 9.0
	title = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await seconds(7.0)
	var skip: Button = null
	var cover := title.find_child("PackCover", true, false)
	if cover != null:
		for b in cover.find_children("*", "Button", true, false):
			skip = b
	check(skip != null and skip.visible, "a slow fetch: the cover offers a way in")
	if skip != null:
		skip.pressed.emit()
	await frames(4)
	camp = title.find_child("Camp", true, false)
	check(camp != null and Profile.character == "cat" and camp.character.character == "cat", "in as the cat")
	await seconds(2.5)
	title.queue_free()
	await frames(2)
	CharacterPacks.missing = {}
	CharacterPacks.pretend_time = 0.0
	Profile.load_data(saved)
	Profile._save()


## User request (round 7): the user's earthworm, grasshopper and small
## fish as live baits and a live shrimp made for them; the rations off the
## menu; two potions (one to make you stronger, one to keep ghosts off),
## an eyeball that shows the way to the altar and binoculars that find the
## 渡石 - bought in the shop, packed in the bag, used from it.
func test_usable_items() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 1000})
	for id in ["live_worm", "live_cricket", "live_shrimp", "live_minnow"] + Profile.USABLE_ORDER:
		var model := Items.model_path(id)
		check(model != "" and ResourceLoader.exists(model), "%s: its 3D model (%s)" % [id, model])
		check(Items.square_icon(id) != null and Items.icon(id) != null, "%s: its icons" % id)
	check(Profile.LIVE_BAITS.cricket.name == "蚱蜢", "the grasshopper in the cricket's place")
	check(not Profile.SNACKS.has("rations") and not "rations" in Profile.SNACK_ORDER, "no more rations")
	for id in Profile.USABLE_ORDER:
		if Profile.USABLES[id].get("sold", true):
			check(Profile.buy_usable(id), "%s can be bought" % Profile.USABLES[id].name)
	# (the glow mushroom isn't sold - only picked on the map)
	check(not Profile.buy_usable("glow_mushroom"), "the glow mushroom isn't for sale")
	Profile._store("glow_mushroom", 1)
	check(not Profile.buy_usable("binoculars"), "the binoculars only once")
	check(Profile.buy_usable("potion_ward") and Profile.buy_usable("eyeball"), "the rest by the many")
	for id in Profile.USABLE_ORDER:
		Profile.to_bag(id, Profile.stored(id))
	await _fresh_game()
	var p := player()
	var kinds := Inventory.items(p).filter(func(it): return it.kind == "use").map(func(it): return it.item)
	check(Profile.USABLE_ORDER.all(func(id): return id in kinds), "packed, they're things to use in the bag (%s)" % [kinds])

	# The increase potion: faster, and a fight's tension builds slower.
	var before := StatusCard.speed_share(p)
	check(p.use_item("potion_vigor") and p.vigor_timer > 0.0, "drunk: stronger for a while")
	check(Profile.bag_count("potion_vigor") == 0, "and it's gone from the bag")
	check(StatusCard.speed_share(p) > before * 1.2, "faster on its feet")
	check(StatusCard.effects(p).any(func(e): return e[0] == "potion_vigor"), "the card shows it (a slot under it)")
	check(not p.use_item("potion_vigor"), "none left to drink")

	# The ghost-ward potion: the big ghost can't grab, a floating one can't
	# come close, the water ghost won't rise.
	var big: BigGhost = get_tree().get_first_node_in_group("big_ghost")
	check(p.use_item("potion_ward") and p.ward_timer > 0.0, "the ghost-ward potion drunk")
	if big != null:
		big.global_position = p.global_position + Vector2(10, 0)
		big._try_catch()
		check(not p.held, "the big ghost can't grab")
		big._move_toward(p.global_position, 200.0, 0.5)
		check(big.global_position.distance_to(p.global_position) >= Player.WARD_RADIUS - 0.5, "nor come near")
	var floating = get_tree().get_nodes_in_group("ghosts").filter(func(g): return not g is BigGhost)
	if not floating.is_empty():
		var g = floating[0]
		g.global_position = p.global_position + Vector2(0, -150)
		g._move_toward(p.global_position, 400.0, 1.0)
		check(g.global_position.distance_to(p.global_position) >= Player.WARD_RADIUS - 0.5, "a floating ghost stops short")
		check(not g._should_haunt(), "and won't come to make trouble")
	p._apply_water_ghost_attack()
	check(p.water_ghost_timer == 0.0 and get_tree().get_nodes_in_group("water_ghosts").is_empty(), "the water ghost doesn't rise")
	check(Profile.bag_count("potion_ward") == 1, "one of the two drunk")

	# Round 8 (user request): the eyeball shows the 渡石, the golden eye the
	# altar, the ghost eye the nearest ghost (following it), the binoculars
	# the nearest water.
	var stone: Node2D = main.get_node("EscapePoint")
	check(p.use_item("eyeball") and p.guide.active() and p.guide.target == stone.global_position, "the eyeball points at the 渡石")
	check(Profile.bag_count("eyeball") == 1, "and is used up")
	# User request: a true eye opens over the head a moment, looking the
	# way; the arrow lies faint on the ground at the feet.
	var eye: TrueEye = p.get_node_or_null("TrueEye")
	check(eye != null and eye.kind == "eyeball" and eye.look_dir.dot((stone.global_position - p.global_position).normalized()) > 0.99,
		"a true eye opens over the head, looking the 渡石's way")
	await seconds(0.2)
	check(p.guide.visible, "the arrow shows")
	check(p.guide.get_parent() == p and p.guide.position == Player.FEET and p.guide.show_behind_parent,
		"lying on the ground at the feet, under the character")
	await seconds(0.5)
	check(is_instance_valid(eye) and eye.openness() == 1.0, "open wide")
	await seconds(TrueEye.TIME)
	check(not is_instance_valid(eye), "and gone again in a moment")
	var altar: Node2D = main.get_node("Altar")
	check(p.use_item("eye_altar") and p.guide.target == altar.global_position, "the golden eye points at the altar")
	var ghost := p.nearest_ghost()
	if ghost != null:
		check(p.use_item("eye_ghost") and p.guide.target == ghost.global_position, "the ghost eye points at the nearest ghost")
		ghost.global_position += Vector2(30, 0)
		await frames(2)
		var now := p.nearest_ghost()
		check(now != null and p.guide.target.distance_to(now.global_position) < 4.0, "and follows it as it moves")
	var water := p.nearest_water()
	check(not water.is_empty(), "there's water to find")
	check(p.use_item("binoculars") and p.guide.target == water.at, "the binoculars find the nearest water (%s)" % water.get("name", ""))
	var on_shore: bool = water.d >= Player.BINOCULARS_SKIP or get_tree().get_nodes_in_group("water_zones").size() == 1
	check(on_shore, "past the water you're standing at")
	check(Profile.bag_count("binoculars") == 1, "and are kept")
	check(not p.use_item("binoculars") and p.binoculars_cooldown > 0.0, "but need a while before the next look")
	p.guide.time_left = 0.0
	await frames(2)
	check(not p.guide.visible, "the arrow goes when its time's up")
	Profile.load_data(saved)
	Profile._save()


## Round 8 (user request): what's caught or found on the map goes in the
## bag as a real live bait (the shrimp and the small fish only bought);
## the landing net, worn in its slot and taken in hand in a run, catches
## from further off and is bitten less; snakes and bees may poison too.
## User request: three quick slots over the right stick, set by the
## player (an empty one tapped, or one held, opens a picker of what's in
## the bag) and used the moment they're tapped - any finger; kept between
## runs.
func _touch(at: Vector2, down: bool, finger := 1) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.pressed = down
	ev.position = at
	get_viewport().push_input(ev, true)
	await frames(1)


func test_quick_slots() -> void:
	var saved := Profile.snapshot()
	Profile.quick_slots = ["", "", ""]
	Profile.bag = Profile.bag.filter(func(e): return not e.id in Profile.USABLES)
	Profile.bag.append({"id": "potion_vigor", "count": 2, "cell": Vector2i(7, 0)})
	Profile.bag.append({"id": "eyeball", "count": 1, "cell": Vector2i(7, 1)})
	var quick: QuickSlots = main.get_node("QuickSlots")
	check(quick.slots.size() == 3, "three quick slots")
	for s in quick.slots:
		# (user request, round 3: between 誘惑 and the bait on the line)
		check(s.position.y + s.size.y < TouchControls.LURE_AT.y - TouchControls.LURE_RADIUS + 20.0 and s.position.y > BaitSlot.AT.y
			and s.position.x > 640.0, "over the right stick, under the bait (%s)" % s.position)
	var touch: TouchControls = main.find_children("*", "TouchControls", false, false)[0]
	check(not touch._is_empty_spot(quick.CENTERS[0]), "a long press on one isn't the lamp's brightness")
	# An empty one tapped (a second finger - the first on the left stick): the picker.
	await _touch(quick.CENTERS[0], true, 1)
	await _touch(quick.CENTERS[0], false, 1)
	check(quick.picker_open(), "an empty slot tapped opens the picker")
	var pick: Button = quick.find_child("Pick_potion_vigor", true, false)
	check(pick != null and quick.find_child("Pick_binoculars", true, false) == null, "with what's in the bag to use")
	pick.pressed.emit()
	await frames(2)
	check(Profile.quick_slots[0] == "potion_vigor" and not quick.picker_open(), "set to the potion")
	var p := player()
	await _touch(quick.CENTERS[0], true, 1)
	await _touch(quick.CENTERS[0], false, 1)
	check(Profile.bag_count("potion_vigor") == 1 and p.vigor_timer > 0.0, "tapped, it's drunk at once")
	quick.open_picker(1)
	await frames(1)
	(quick.find_child("Pick_potion_vigor", true, false) as Button).pressed.emit()
	await frames(1)
	check(Profile.quick_slots[1] == "potion_vigor" and Profile.quick_slots[0] == "", "the same thing isn't in two slots")
	quick.open_picker(2)
	await frames(1)
	(quick.find_child("Pick_eyeball", true, false) as Button).pressed.emit()
	await frames(1)
	quick.tap(2)
	check(Profile.bag_count("eyeball") == 0 and p.get_node_or_null("TrueEye") != null, "the eye opens from its slot")
	quick.tap(2)
	check(quick.slots[2]._shake > 0.0 and Profile.quick_slots[2] == "eyeball", "none left: it shakes, still set")
	# Held: the picker, to clear it.
	await _touch(quick.CENTERS[1], true, 2)
	await seconds(QuickSlots.HOLD + 0.1)
	check(quick.picker_open(), "held, the picker opens")
	await _touch(quick.CENTERS[1], false, 2)
	(quick.find_child("ClearSlot", true, false) as Button).pressed.emit()
	await frames(1)
	check(Profile.quick_slots[1] == "" and Profile.bag_count("potion_vigor") == 1, "cleared, nothing used")
	check(Profile.snapshot().quick_slots == ["", "", "eyeball"], "kept in the save")
	Profile.load_data(saved)
	Profile._save()


## User request: the user's Mixamo clips played as the player does things -
## a potion drunk, a thing picked up, a rock turned, a fish landed (then a
## fist pumped), the fish lost - off the moves sheet, facing the aim
## (mirrored for the right-hand facings), cut short by walking off; dizzy
## when poisoned, head hung when worn right out.
func test_player_moves() -> void:
	var p := player()
	var body: PlayerVisual = p.get_node("Body")
	await put(away_from_water(200.0))
	p.aim_dir = Vector2.DOWN
	await frames(3)
	if body._move_data.is_empty():
		check(false, "the moves data is there for %s" % Profile.character)
		return
	p.perform("drink", 1.0)
	await frames(3)
	check(body.move == "drink", "drinking: the drink move")
	check(body.rod_on_back() and body.off_main_sheet(), "the rod on the back, the front layer off")
	var first := body.frame_in_clip
	await seconds(0.6)
	check(body.frame_in_clip > first, "playing through (%d -> %d)" % [first, body.frame_in_clip])
	await seconds(0.6)
	check(body.move == "" and body.texture == body._main_tex, "and back to the run sheet")
	# Facing right: drawn from the left facing, mirrored - its rod too.
	p.aim_dir = Vector2.RIGHT
	p.perform("pick", 1.0)
	await frames(3)
	check(body.move == "pick" and body.flip_h and body.move_flip, "facing right: mirrored")
	var raw: Array = body._move_data.rod["pick"][2][body.frame_in_clip]
	check(is_equal_approx(float(body.rod_cell()[0]), -float(raw[0])), "the rod on the back turned over with it")
	p.aim_dir = Vector2.DOWN
	await seconds(1.1)
	# Walking off cuts it short.
	p.perform("look", 2.0)
	await frames(2)
	key(KEY_D, true)
	await frames(8)
	check(body.move == "" and p.move_left == 0.0, "walking off cuts a move short")
	key(KEY_D, false)
	await frames(10)
	# User request: the left stick eased off, it walks (slow or brisk) -
	# pushed all the way, it runs.
	if (body._move_data.clips as Array).has("walk"):
		p._move_joystick.output = Vector2(0.3, 0.0)
		await frames(6)
		var f0 := body.frame_in_clip
		await seconds(0.4)
		check(body.move == "walk" and body.frame_in_clip != f0, "stick eased off: it walks (%s)" % body.move)
		p._move_joystick.output = Vector2(0.5, 0.0)
		await frames(6)
		check(body.move == "walk", "a little more: a brisk walk")
		p._move_joystick.output = Vector2(1.0, 0.0)
		await frames(6)
		check(body.move == "" and body.clip == PlayerVisual.CLIP_RUN, "all the way: it runs")
		p._move_joystick.output = Vector2.ZERO
		await frames(10)
	else:
		check(false, "the walk is on %s's moves sheet" % Profile.character)
	# A fish landed: the catch clip, then a fist pumped.
	p.catch_success.emit({"name": "鯉魚", "rarity": "common"})
	await frames(2)
	check(body.clip == PlayerVisual.CLIP_CATCH, "the landing first")
	await seconds(PlayerVisual.FRAMES / PlayerVisual.FPS[PlayerVisual.CLIP_CATCH] + 0.1)
	check(p.move_kind == "fist" and body.move == "fist", "then a fist pumped")
	await seconds(PlayerVisual.CHEER_TIME)
	# A snapped line: no sigh (user request) ...
	p.state = Player.State.REELING
	p._fail_catch("line_break")
	await frames(2)
	check(p.move_left <= 0.0 or p.move_kind != "sad", "the line snapped: no sigh")
	# ... but a fish lost after the fight: hangs its head.
	p.state = Player.State.REELING
	p._fail_catch("shook_off")
	await frames(2)
	check(body.move == "sad", "the fish lost: disappointed")
	await seconds(2.0)
	# Poisoned, standing: dizzy; worn right out: head hung.
	p.poison_timer = 3.0
	await frames(3)
	check(body.move == "dizzy", "poisoned: dizzy")
	p.poison_timer = 0.0
	var spirit := Profile.spirit
	Profile.spirit = 10.0
	await frames(3)
	check(body.move == "sad_idle", "worn right out: head hung")
	Profile.spirit = spirit
	await frames(3)
	check(body.move == "", "and itself again")
	# Things used: a potion drunk, a rock turned.
	Profile.bag.append({"id": "potion_vigor", "count": 1, "cell": Vector2i(7, 3)})
	check(p.use_item("potion_vigor") and p.move_kind == "drink", "a potion: drunk")


func test_live_bait_and_net() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 1000})
	for key in Critter.SPECIES:
		var d: Dictionary = Critter.SPECIES[key]
		if not d.get("ambient", false):
			check(Profile.LIVE_BAITS.has(d.get("bait", "")), "a caught %s is a live bait (%s)" % [key, d.get("bait", "")])
	check(Critter.SPECIES.grasshopper.bait == "cricket", "grasshoppers are caught on the map")
	check(Critter.SPECIES.wasp.label == "蜜蜂", "the bee")
	check(Critter.SPECIES.snake.get("venom", 0.0) > 0.0 and Critter.SPECIES.wasp.get("venom", 0.0) > 0.0,
		"snakes and bees may poison")
	for key in ["shrimp", "minnow"]:
		check(Critter.SPECIES.values().all(func(d): return d.get("bait", "") != key), "%s: only bought" % key)
	for key in ["rat", "snake", "crab", "bee", "black_spider"]:
		var id: String = "live_" + key
		check(not Profile.LIVE_BAITS[key].get("shop", true), "%s isn't sold" % key)
		check(ResourceLoader.exists(Items.model_path(id)) and Items.square_icon(id) != null and Items.icon(id) != null,
			"%s: its model and icons" % id)
	for f in FlipRock.BAIT_FLAVORS + MapTree.CHOP_BAIT:
		check(Player.FOUND_BAIT.has(f), "a %s found is a live bait" % f)
	check(load("res://scripts/equipment.gd").SLOT_LAYOUT.any(func(sl): return sl[0] == "offhand"), "an off-hand slot on the equipment page")
	check(ResourceLoader.exists(Items.model_path("net")) and Items.square_icon("net") != null and Items.icon("net") != null,
		"the net: its model and icons")
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await frames(2)
	shop._show_tab("bait")
	await frames(1)
	check(shop._grid.get_node_or_null("Card_live_rat") == null and shop._grid.get_node_or_null("Card_live_worm") != null,
		"the shop sells worms, not rats")
	shop._show_tab("gear")
	await frames(1)
	check(shop._grid.get_node_or_null("Card_net") != null, "and sells the net")
	shop.queue_free()
	check(Profile.buy_net() and not Profile.buy_net(), "the net, bought once")
	# User request: the weapons and the net share the off hand - one of them.
	check(Profile.buy_weapon("hatchet") and Profile.equip("hatchet") and Profile.offhand() == "hatchet", "the hatchet in the off hand")
	check(Profile.equip("net") and Profile.has_net() and Profile.weapon.is_empty() and Profile.stored("hatchet") == 1,
		"the net in its place - the hatchet back in the warehouse")
	await _fresh_game()
	Profile.equip("hatchet")
	var p := player()
	check(p.offhand_in_hand() and p.held_weapon().get("chop", 0) == 2, "between casts the off hand's thing is in hand")

	# Out on the map: a rat just out of reach of bare hands.
	var at := away_from_water(80.0)
	await put(at)
	var rat: Critter = load("res://scenes/critter.tscn").instantiate()
	rat.species = "rat"
	main.add_child(rat)
	rat.set_physics_process(false)
	rat.global_position = p.global_position + Vector2(36, 0)
	await frames(3)
	check(p.reachable_critter() == null, "out of reach with the hatchet in hand")
	Profile.equip("net")
	check(p.net_in_hand() and p.held_weapon().is_empty() and p.choppable_tree() == null, "the net in hand, no blade")
	check(StatusCard.gear(p)[1][0] == "net" and StatusCard.gear(p)[1][2], "the card's off-hand slot shows it, in hand")
	check(p.reachable_critter() == rat and p.interaction().get("verb", "") == "抓餌", "the net reaches it")
	p.live_bait = ""
	var wear := Profile.durability("net")
	check(p.swing() and p.swing_kind == "scoop", "a tap swings the net: a scoop")
	await seconds(Player.swing_time("scoop") + 0.1)
	check(Profile.bag_count("live_rat") == 1 and not rat.active, "scooped: a live rat in the bag")
	check(Profile.durability("net") == wear - 1, "and the net wears a little (%d -> %d)" % [wear, Profile.durability("net")])
	check(p.live_bait == "rat", "and on the hook, nothing else being on")
	check(Inventory.items(p).any(func(it): return it.kind == "live" and it.item == "live_rat"), "it shows in the bag")
	# User report: the net came down too late - the bait gone. A quick
	# sweep, further than a hand reaches, and the critter it was swept at
	# still caught if it's scuttled a little off meanwhile.
	check(Player.swing_time("scoop") <= 1.2 and Player.NET_REACH > 50.0 and Player.NET_REACH < 60.0, "a quick sweep, a reach past a hand's")
	var mouse: Critter = load("res://scenes/critter.tscn").instantiate()
	mouse.species = "rat"
	main.add_child(mouse)
	mouse.set_physics_process(false)
	mouse.global_position = p.global_position + Vector2(50, 0)
	await frames(3)
	var rats := Profile.bag_count("live_rat")
	check(p.interaction().get("verb", "") == "抓餌", "the net reaches it at %d px" % 50)
	check(p.swing("scoop"), "swept")
	p._scoop_target = mouse
	mouse.global_position = p.global_position + Vector2(70, 0)
	await seconds(Player.swing_time("scoop") + 0.1)
	check(Profile.bag_count("live_rat") == rats + 1, "scuttled a little off, still scooped up")
	# (user report, again: too slow, the bait ran - quicker still, and the
	# bait the net's come down over held still under it)
	check(Player.swing_time("scoop") <= 0.7 and float(Player.SWINGS.scoop[1]) <= 0.3, "the sweep quicker still")
	var frog: Critter = load("res://scenes/critter.tscn").instantiate()
	frog.species = "rat"
	main.add_child(frog)
	frog.global_position = p.global_position + Vector2(30, 0)
	await frames(3)
	var frog_at := frog.global_position
	check(p.interaction().get("verb", "") == "抓餌", "another in reach")
	frog.pin(0.5)
	await seconds(0.3)
	check(frog.global_position.distance_to(frog_at) < 1.0, "held still under the net (%.1f px)" % frog.global_position.distance_to(frog_at))
	frog.queue_free()
	# Bare-handed: caught at a touch, a quick grab (no bending down).
	Profile.equip("hatchet")
	var bug: Critter = load("res://scenes/critter.tscn").instantiate()
	bug.species = "rat"
	main.add_child(bug)
	bug.set_physics_process(false)
	bug.global_position = p.global_position + Vector2(10, 0)
	await frames(3)
	p._catch_critter()
	check(not bug.active and p.grab_left > 0.0 and p.swing_left == 0.0, "bare-handed: snatched up at once")
	Profile.equip("net")
	# Found under a rock: a live bait too.
	var worms := Profile.bag_count("live_worm")
	check(p.pocket_live_bait(Player.FOUND_BAIT["蚯蚓"]) == 1 and Profile.bag_count("live_worm") == worms + 1, "a worm found goes in the bag")
	# The bag shows the gear worn beside the grid.
	var bag: Backpack = p.backpack()
	bag.toggle()
	await frames(2)
	check(bag._gear_slots.size() == 3 and bag._gear_slots[1].slot == "offhand", "the bag has the gear slots")
	bag.toggle()
	Profile.equip("hatchet")
	check(p.held_weapon().get("chop", 0) == 2, "the hatchet back in hand")

	# A snake's bite and a bee's sting may poison.
	for sp in ["snake", "wasp"]:
		var poisoned := false
		for i in 40:
			seed(300 + i)
			p.poison_timer = 0.0
			var c: Critter = load("res://scenes/critter.tscn").instantiate()
			c.species = sp
			main.add_child(c)
			c.set_physics_process(false)
			c.global_position = p.global_position
			await frames(1)
			p.set_in_critter(true, c)
			p._catch_critter()
			c.queue_free()
			if p.poison_timer > 0.0:
				poisoned = true
				break
		check(poisoned, "a %s may poison" % Critter.SPECIES[sp].label)
	check(Profile.bag_count("live_snake") >= 1 and Profile.bag_count("live_bee") >= 1, "snakes and bees go in the bag")
	check(Player.NET_VENOM_MULT < 1.0, "the net makes a bite less likely")
	p.poison_timer = 0.0
	Profile.load_data(saved)
	Profile._save()


func test_rod_bends_with_the_fish() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	var rod = player().get_node("Rod")
	var visual = player().get_node("Body")
	await frames(20)
	check(absf(rod.bend) < 0.001, "no fish on: the rod straight (%.3f)" % rod.bend)
	var straight_tip: Vector2 = rod.tip_position()
	player().cast_target = player().global_position + Vector2(-60, -90)
	player().tier_data = FishData.get_tier_data("mid").duplicate()
	player().difficulty_key = "normal"
	player().fish_habit = ""
	player().is_heart_catch = false
	player()._hook_fish()
	player().fight.opening_left = 0.0  # (the strike's opening: test_fight_opening)
	player().fight.lively = false  # (its swimming about: test_fight_fish_swims)
	await frames(2)
	check(visual.clip == PlayerVisual.CLIP_TUG, "hooked: the strike plays (KayKit's Fishing_Tug)")
	# the strike over (the rod raised in it), the bend measured on the hold
	player().fight._run_timer = 99.0
	player().fight._jump_cooldown = 99.0
	for i in 60:
		if visual.clip != PlayerVisual.CLIP_TUG:
			break
		await frames(1)
	check(visual.clip == PlayerVisual.CLIP_HOLD, "the strike gives way to the hold")
	var bends := []
	for t in [0.1, 0.8]:
		player().fight.tension = t
		player().fight._run_timer = 99.0
		player().fight._jump_cooldown = 99.0
		player().tension = t
		await seconds(0.6)
		bends.append(absf(rod.bend))
	check(bends[0] > 0.05 and bends[1] > bends[0] + 0.3, "hooked, it bends - more at a high tension (%s)" % [bends])
	var to_line: Vector2 = rod.to_local(player().get_line_target_position())
	check(signf(rod.bend) == signf(to_line.y), "toward the line's side of it")
	var tip: Vector2 = rod.tip_position()
	var at_tip: Array = rod._at(rod._tip_along())
	check(tip.distance_to(rod.to_global(at_tip[0] + at_tip[1] * rod._offset.y * rod._scale().y)) < 0.01, "the line leaves the bent tip")
	check(tip.distance_to(straight_tip) > 0.5, "which has moved off the straight rod's (%.1f px)" % tip.distance_to(straight_tip))
	# cranking: the reel clip from its first frame (the crank turns on from
	# where the hand rests on it in the hold)
	await frames(5)
	check(visual.clip == PlayerVisual.CLIP_HOLD, "hooked, not cranking: the hold")
	key(KEY_SPACE, true)
	var first := -1
	for i in 10:
		await frames(1)
		if visual.clip == PlayerVisual.CLIP_REEL:
			first = visual.frame_in_clip
			break
	key(KEY_SPACE, false)
	check(first == 0, "cranking starts the reel at its first frame (%d)" % first)
	await frames(3)
	# a run: the fight clip, its yank
	player().fight.run_left = 2.0
	player().fight.run_side = Vector2.ZERO
	var home: Vector2 = visual.position
	var yanked := false
	var jolted := 0.0
	for i in 40:
		await frames(1)
		if visual.clip == PlayerVisual.CLIP_FIGHT and visual.yank > 0.9:
			yanked = true
			jolted = maxf(jolted, (visual.position - home).dot((player().cast_target - player().global_position).normalized()))
	check(yanked, "a run plays the fight, its yank at YANK_FRAME")
	check(jolted > 0.5, "the yank jolts the body toward the fish (%.2f px)" % jolted)
	await seconds(0.5)
	check(visual.position.distance_to(home) < 0.3 or visual.yank > 0.0, "and it eases back")
	player()._set_state(Player.State.IDLE)
	player().fight = null
	await seconds(0.6)
	check(absf(rod.bend) < 0.02, "the fish off: straight again (%.3f)" % rod.bend)


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
	await seconds(0.6)
	var view: RunView3D = RunView3D.active
	var half_reach := 0.0
	if view != null:
		half_reach = view._flash_aim.global_basis.get_scale().x
		check(view._flash_aim.visible, "aiming: the fan shows on the ground ahead")
	await seconds(0.9)
	check(lantern.boost > 0.9, "held, the light charges (%.2f)" % lantern.boost)
	if view != null:
		check(view._flash_aim.global_basis.get_scale().x > half_reach + 0.3,
			"charged, the fan reaches further (%.1f -> %.1f m)" % [half_reach, view._flash_aim.global_basis.get_scale().x])
	player().skill_held = false
	await frames(3)
	check(ghost.stun_timer > Lantern.FLASH_STUN_DURATION * 2.0, "a charged flash holds it longer (%.2f)" % ghost.stun_timer)
	if view != null:
		check(view._flash_light.visible and view._flash_light.light_energy > RunView3D.FLASH_BURST.x and view._flash_white.color.a > 0.2,
			"the flash: a bright burst, the screen blanching (%.1f, %.2f)" % [view._flash_light.light_energy, view._flash_white.color.a])
		await seconds(RunView3D.FLASH_FADE + 0.1)
		check(not view._flash_aim.visible and not view._flash_light.visible, "then gone")
	# (user request: held longer, stuns longer - in proportion)
	check(lantern.flash_stun(0.0) < lantern.flash_stun(0.5) and lantern.flash_stun(0.5) < lantern.flash_stun(1.0)
		and is_equal_approx(lantern.flash_stun(0.5) - lantern.flash_stun(0.0), lantern.flash_stun(1.0) - lantern.flash_stun(0.5)),
		"the hold sets the stun, in proportion")
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


## User request: the line out. Left alone the fish swims off with it,
## the crank brings it back - faster turned, faster in; all out, it's gone.
## User request: the fight shows the line out (線長) - as long as the cast
## at the strike (a far cast's line that much longer than a near one's),
## and longer as the fish goes deep; reeled, it comes up.
func test_fight_line_out() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 30))
	var p := player()
	p.aim_dir = Vector2.UP
	var lines := []
	for ratio in [0.0, 1.0]:
		p.charge_time = ratio * Player.MAX_CHARGE_TIME
		p._launch_cast()
		var cast_m: float = p.global_position.distance_to(p.cast_target) / Player.PX_PER_M
		p._hook_fish()
		check(absf(p.fight.line_out() - cast_m) < 2.5, "the line out starts as long as the cast (%.1f m, cast %.1f m)" % [p.fight.line_out(), cast_m])
		lines.append([cast_m, p.fight.line_out()])
		p._reset_line(Player.State.IDLE)
		await frames(2)
	check(lines[1][1] / lines[0][1] > 0.6 * lines[1][0] / lines[0][0], "a far cast's line that much longer (%s)" % [lines])
	var tier: Dictionary = FishData.TIERS.values()[0]
	var f := FishFight.new("advanced", "", tier, 1.0)
	f.open(0.8)
	f.opening_left = 0.0
	f.lively = false
	f._jump_cooldown = 99.0
	f._run_timer = 99.0
	f.distance = 15.0
	var at := f.line_out()
	f.run_left = 3.0
	f.run_side = Vector2.ZERO
	for i in 40:
		f.update(0.05, 0.0, Vector2.ZERO, Vector2.UP)
	check(f.depth > FishFight.DEPTH_HOOKED + 1.0 and f.line_out() > at + 1.0,
		"on its run it goes deep, the line out longer (%.1f m deep, %.1f -> %.1f m)" % [f.depth, at, f.line_out()])
	var deep := f.depth
	f.run_left = 0.0
	for i in 40:
		f.update(0.05, FishFight.CRANK_NORMAL, Vector2.ZERO, Vector2.UP)
	check(f.depth < deep, "reeled, it comes up (%.1f m)" % f.depth)


func test_fight_line_distance() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var idle := FishFight.new("normal", "", tier, 1.0)
	var slow := FishFight.new("normal", "", tier, 1.0)
	var fast := FishFight.new("normal", "", tier, 1.0)
	for f in [idle, slow, fast]:
		f._jump_cooldown = 99.0
		f._run_timer = 99.0
		f.line_max = 40.0
		f.distance = 15.0
		f.swim_out = 1.0
		f.tension = 0.3
	idle.update(1.0, 0.0, Vector2.ZERO, Vector2.UP)
	slow.update(1.0, FishFight.CRANK_NORMAL, Vector2.ZERO, Vector2.UP)
	fast.update(1.0, 1.0, Vector2.ZERO, Vector2.UP)
	check(idle.distance > 15.5, "left alone, the fish takes line (%.1f m)" % idle.distance)
	check(slow.distance < 15.0 and fast.distance < slow.distance, "the crank brings it in, faster turned faster (%.1f, %.1f)" % [slow.distance, fast.distance])
	check(fast.progress > slow.progress, "and wears the fish faster")
	check(fast.tension > slow.tension, "and the line tightens faster")
	# Never reeled: all the line goes and it's gone.
	var gone := FishFight.new("normal", "", tier, 1.0)
	gone._jump_cooldown = 99.0
	gone._run_timer = 99.0
	gone.line_max = 40.0
	gone.distance = 25.0
	gone.swim_out = 2.0
	for i in 400:
		gone.update(0.05, 0.0, Vector2.ZERO, Vector2.UP)
		if gone.result != "":
			break
	check(gone.result in ["line_out", "line_break"], "left to run, the line goes (%s)" % gone.result)
	check(gone.snap_why == "far", "for how far out it got")
	# A straight run takes line even while cranking.
	var run := FishFight.new("normal", "", tier, 1.0)
	run._jump_cooldown = 99.0
	run._run_timer = 99.0
	run.distance = 15.0
	run.run_left = 1.0
	run.update(0.5, 1.0, Vector2.ZERO, Vector2.UP)
	check(run.distance > 15.0, "on a run the drag slips - line goes out (%.1f)" % run.distance)


## User request: a hooked fish keeps to its water - fresh, it won't be
## cranked in past the near edge of where it took the bait (the line
## tightening instead); the bigger and rarer, the wider it roams; tired,
## it comes in.
func test_fight_fish_keeps_its_water() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var light := FishFight.new("normal", "", tier, 1.0)
	light.open(0.0)
	var heavy := FishFight.new("normal", "", tier, 1.0)
	heavy.open(1.0)
	for f in [light, heavy]:
		f.opening_left = 0.0
		f._jump_cooldown = 99.0
		f._run_timer = 99.0
		f.line_max = 40.0
		f.distance = 16.0
		f.swim_out = 0.5
		f.lively = false
		f.update(0.01, 0.0, Vector2.ZERO, Vector2.UP)
	check(heavy.roam > light.roam + 3.0, "a heavy fish roams wider (%.1f m vs %.1f m)" % [heavy.roam, light.roam])
	var top := 0.0
	for i in 200:
		light.progress = 0.05
		light.tension = minf(light.tension, 0.5)
		light.update(0.05, FishFight.CRANK_NORMAL, Vector2.ZERO, Vector2.UP)
		top = maxf(top, light.tension)
	check(light.distance >= light.home - light.roam - 1.0,
		"fresh, cranked 10 s: kept to its water (%.1f m, edge %.1f m)" % [light.distance, light.home - light.roam])
	check(top >= 0.5, "dragged at the edge, the line tight (%.2f)" % top)
	# Tired, it comes in.
	light.progress = 0.95
	light.tension = 0.2
	for i in 60:
		light.update(0.05, FishFight.CRANK_NORMAL, Vector2.ZERO, Vector2.UP)
		light.tension = minf(light.tension, 0.5)
	check(light.distance < light.home - light.roam - 2.0, "worn out, it's brought in (%.1f m)" % light.distance)
	# Let be at the edge, it swims back out.
	var back := FishFight.new("normal", "", tier, 1.0)
	back.open(0.5)
	back.opening_left = 0.0
	back._jump_cooldown = 99.0
	back._run_timer = 99.0
	back.lively = false
	back.distance = 16.0
	back.swim_out = 0.0
	back.update(0.01, 0.0, Vector2.ZERO, Vector2.UP)
	back.distance = back.near_limit()
	var at := back.distance
	for i in 20:
		back.update(0.05, 0.0, Vector2.ZERO, Vector2.UP)
	check(back.distance > at + 0.5, "let be at the edge, it heads back out (%.1f -> %.1f m)" % [at, back.distance])


## Out in the red, a leap snaps the line outright; near, it's only the
## usual "let go".
func test_fight_leap_far_out() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	for far in [false, true]:
		var f := FishFight.new("master", "", tier, 1.0)
		f.diff = f.diff.duplicate()
		f.diff.jump = 1000.0
		f._jump_cooldown = 0.0
		f._run_timer = 99.0
		f.line_max = 40.0
		f.distance = 38.0 if far else 10.0
		f.swim_out = 0.0
		var events := f.update(0.05, 0.0, Vector2.ZERO, Vector2.UP)
		check(events.has("jump"), "it leaps")
		if far:
			check(f.result == "line_break" and f.snap_why == "leap", "far out, the leap snaps the line (%s)" % f.result)
		else:
			check(f.result == "", "close in, the line holds")


## User feedback (fights over too fast): worn out, the fish is spent, not
## landed - it has to be reeled in to the bank; left too long it recovers.
func test_fight_spent_reeled_in() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var f := FishFight.new("normal", "", tier, 1.0)
	f._jump_cooldown = 99.0
	f._run_timer = 99.0
	f.line_max = 40.0
	f.distance = 15.0
	f.swim_out = 1.0
	f.progress = 0.995
	var events := f.update(0.1, 1.0, Vector2.ZERO, Vector2.UP)
	check(events.has("spent") and f.spent and f.result == "", "worn out it's spent, not landed (%s)" % f.result)
	check(f.mood() == "spent", "the panel says so")
	f.diff = f.diff.duplicate()
	f.diff.jump = 1000.0
	f._jump_cooldown = 0.0
	f.update(0.1, 1.0, Vector2.ZERO, Vector2.UP)
	check(f.jump_left <= 0.0 and f.run_left <= 0.0, "spent, it doesn't leap or run")
	var recovered := false
	for i in 40:
		if f.update(0.1, 0.0, Vector2.ZERO, Vector2.UP).has("recover"):
			recovered = true
			break
	check(recovered and not f.spent and f.progress < 1.0, "left un-reeled, it gets its breath back (%.2f)" % f.progress)
	f.progress = 0.995
	var t := 0.0
	while f.result == "" and t < 30.0:
		f.diff.jump = 0.0
		f.update(0.1, FishFight.CRANK_NORMAL if f.tension < 0.6 else 0.0, Vector2.ZERO, Vector2.UP)
		t += 0.1
	check(f.result == "landed" and f.distance <= FishFight.LAND_DISTANCE, "reeled in to the bank, it's landed (%s, %.1f m)" % [f.result, f.distance])


## User request: struck, the fish puts its own tension on the line - the
## harder the catch the higher, or low then a surge; hold the stick to ride
## it (and read it), let go and it throws the hook, crank straight into a
## surge and the line snaps.
func test_fight_opening() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var make := func(curve: Vector3) -> FishFight:
		var f := FishFight.new("master", "", tier, 1.0)
		f._jump_cooldown = 99.0
		f._run_timer = 99.0
		f.line_max = 40.0
		f.distance = 10.0
		f.swim_out = 0.5
		f.open(1.0)
		f.lively = false  # (its swimming about: test_fight_fish_swims)
		f.open_curve = curve
		f.tension = curve.x
		return f
	# A surge: low at first, then it pulls hard - held, the line rides it.
	var held: FishFight = make.call(Vector3(0.15, 0.9, 0.5))
	held.hold = true
	var early := 0.0
	var peak := 0.0
	var events := []
	var t := 0.0
	while held.result == "" and held.opening_left > 0.0:
		events.append_array(held.update(0.05, 0.0, Vector2.ZERO, Vector2.UP))
		t += 0.05
		if t < 0.4:
			early = maxf(early, held.tension)
		peak = maxf(peak, held.tension)
	check(early < 0.3 and peak > 0.75, "a surge: low at first (%.2f), then hard (%.2f)" % [early, peak])
	check(held.result == "" and events.has("opened"), "held through it, the fish is still on (%s)" % held.result)
	check(held.distance > 10.0, "and it took line on the surge (%.1f m)" % held.distance)
	# Cranked straight into it: the line snaps.
	var rushed: FishFight = make.call(Vector3(0.15, 0.9, 0.5))
	rushed.hold = true
	for i in 60:
		rushed.update(0.05, 1.0, Vector2.ZERO, Vector2.UP)
		if rushed.result != "":
			break
	check(rushed.result == "line_break" and rushed.snap_why == "rush", "cranked straight into the surge, it snaps (%s %s)" % [rushed.result, rushed.snap_why])
	# Let go: slack, and it throws the hook.
	var slack: FishFight = make.call(Vector3(0.3, 0.3, 0.0))
	slack.hold = false
	check(slack.mood() == "opening", "struck: it's on")
	for i in 30:
		slack.update(0.05, 0.0, Vector2.ZERO, Vector2.UP)
		if slack.result != "":
			break
	check(slack.result == "shook_off" and slack.snap_why == "slack", "let go, the line slack, it's off (%s)" % slack.result)
	# The harder the fish, the more it pulls at first.
	var pulls := []
	for h in [0.0, 1.0]:
		var sum := 0.0
		for i in 40:
			var f := FishFight.new("normal", "", tier, 1.0)
			f.open(h)
			sum += maxf(f.open_curve.x, f.open_curve.y)
		pulls.append(sum / 40.0)
	check(pulls[1] > pulls[0] + 0.3, "a hard fish pulls far harder at first (%.2f vs %.2f)" % pulls)
	# And how hard it is: its difficulty, size, rarity and temper.
	var p := player()
	p.difficulty_key = "novice"
	p.current_tier = "near"
	p.is_rare_catch = false
	p.is_epic_catch = false
	p.fish_trait = "calm"
	var light := p.fish_heft()
	p.difficulty_key = "master"
	p.current_tier = "far"
	p.is_rare_catch = true
	p.is_epic_catch = true
	p.fish_trait = "wild"
	check(light < 0.1 and p.fish_heft() > 0.9, "a small calm one is light, a far wild legend heavy (%.2f, %.2f)" % [light, p.fish_heft()])
	p.is_rare_catch = false
	p.is_epic_catch = false


## User request: struck, the fish swims about the water - out, along the
## bank, in - in bursts that jerk the line, the bigger and harder the
## further and harder; it tires as the fight goes, and a hard one may
## rally late on. The line turns with it (Player._follow_line).
func test_fight_fish_swims() -> void:
	seed(11)
	var tier: Dictionary = FishData.TIERS.values()[0]
	var across := []
	var jumps := []
	for h in [0.0, 1.0]:
		var f := FishFight.new("master" if h > 0.5 else "novice", "", tier, 1.0)
		f._jump_cooldown = 999.0
		f._run_timer = 999.0
		f.line_max = 60.0
		f.distance = 15.0
		f.swim_out = 0.0
		f.open(h)
		f.hold = true
		var sideways := 0.0
		var lo := 1.0
		var hi := 0.0
		for i in 240:
			f.update(1.0 / 30.0, 0.0, Vector2.ZERO, Vector2.UP)
			sideways += absf(f.lateral) / 30.0
			if f.opening_left <= 0.0:
				lo = minf(lo, f.tension)
				hi = maxf(hi, f.tension)
		across.append(sideways)
		jumps.append(hi - lo)
	check(across[0] > 0.2, "even a small calm fish swims about (%.1f m across)" % across[0])
	check(across[1] > across[0] * 2.0 and across[1] > 2.0, "a big hard one much further (%.1f m vs %.1f m)" % [across[1], across[0]])
	check(jumps[1] > jumps[0], "and jerks the line harder (tension ranging %.2f vs %.2f)" % [jumps[1], jumps[0]])
	# It tires as the fight goes; a hard one may rally.
	var f := FishFight.new("master", "", tier, 1.0)
	f.open(1.0)
	f._jump_cooldown = 999.0
	f._run_timer = 999.0
	f.opening_left = 0.0
	f.update(0.02, 0.0, Vector2.ZERO, Vector2.UP)
	var fresh := f.vigor
	f.progress = 0.7
	f.update(0.02, 0.0, Vector2.ZERO, Vector2.UP)
	check(fresh > 0.95 and f.vigor < 0.6, "lively when struck, tiring as it's worn (%.2f -> %.2f)" % [fresh, f.vigor])
	f.progress = FishFight.RALLY_AT + 0.01
	var events := f.update(0.02, 0.0, Vector2.ZERO, Vector2.UP)
	check(events.has("rally") and f.vigor >= FishFight.RALLY_VIGOR and f.progress < FishFight.RALLY_AT, "a master rallies late on (%s)" % [events])
	# In the game: the line turns as it swims across it.
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	var p := player()
	p.aim_dir = Vector2.UP
	p.cast_target = p.global_position + Vector2(0, -150)
	p.cast_water_zone = zone
	p.tier_data = FishData.get_tier_data("mid").duplicate()
	p.difficulty_key = "master"
	p.fish_habit = ""
	p.is_heart_catch = false
	p.is_epic_catch = true
	p._hook_fish()
	p.fight.hold = true
	p.fight.opening_left = 0.0
	p.fight._jump_cooldown = 999.0
	p.fight._run_timer = 999.0
	p.fight.swim_out = 0.0
	p.fight.tension_rise = 0.0
	var start: Vector2 = (p.cast_target - p.global_position).normalized()
	var turned := 0.0
	for i in 120:
		if p.fight == null:
			break
		p.fight.tension = 0.3
		await frames(1)
		turned = maxf(turned, absf(start.angle_to(p.cast_target - p.global_position)))
	check(turned > 0.05, "the line swings round as it swims (%.2f rad)" % turned)
	p._reset_line(Player.State.IDLE)


## User request: a leap snaps the line only out far - close in, a light
## touch on the crank is let off and even reeling into it is survived.
func test_fight_leap_close_in() -> void:
	var tier: Dictionary = FishData.TIERS.values()[0]
	var leap := func(at: float, crank: float) -> FishFight:
		var f := FishFight.new("normal", "", tier, 1.0)
		f._jump_cooldown = 999.0
		f._run_timer = 999.0
		f.line_max = 40.0
		f.distance = at
		f.swim_out = 0.0
		f.tension = 0.4
		f.jump_left = FishFight.JUMP_TIME
		for i in int(FishFight.JUMP_TIME * 30.0):
			f.update(1.0 / 30.0, crank, Vector2.ZERO, Vector2.UP)
		return f
	var touch: FishFight = leap.call(8.0, 0.12)
	check(touch.result == "" and touch.tension <= 0.41, "close in, a light touch on the crank is let off (%.2f)" % touch.tension)
	var near: FishFight = leap.call(8.0, 1.0)
	check(near.result == "", "close in, even reeling into the leap is survived (%.2f)" % near.tension)
	var far: FishFight = leap.call(27.0, 1.0)
	check(far.tension > near.tension + 0.3 or far.result != "", "further out it strains it far more (%.2f vs %.2f)" % [far.tension, near.tension])


## User request: rarer, wilder fish pull line away faster.
func test_fight_swim_out_by_fish() -> void:
	var p := player()
	p.difficulty_key = "normal"
	p.is_rare_catch = false
	p.is_epic_catch = false
	p.fish_trait = "calm"
	p.current_tier = "near"
	var calm := p.swim_out_rate()
	p.fish_trait = "wild"
	var wild := p.swim_out_rate()
	p.is_epic_catch = true
	p.current_tier = "far"
	var legend := p.swim_out_rate()
	check(wild > calm and legend > wild * 1.3, "calm %.2f < wild %.2f < legendary off the far water %.2f" % [calm, wild, legend])


## User request: the right stick turned round cranks the reel; held still
## it doesn't.
func test_crank_by_turning_the_stick() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	var stick = main.get_node("HUD/Panel/AimJoystick")
	player().aim_dir = Vector2.UP
	player().cast_target = player().global_position + Vector2(0, -120)
	player().tier_data = FishData.get_tier_data("mid").duplicate()
	player().difficulty_key = "normal"
	player().fish_habit = ""
	player().is_heart_catch = false
	player()._hook_fish()
	player().fight.opening_left = 0.0  # (the strike's opening: test_fight_opening)
	player().fight._run_timer = 99.0
	player().fight._jump_cooldown = 99.0
	check(player().fight.distance > 5.0 and player().fight.distance < player().fight.line_max, "hooked, the line's out to the fish (%.1f m)" % player().fight.distance)
	stick.is_pressed = true
	stick.output = Vector2.RIGHT * 0.8
	await frames(20)
	check(player().crank < FishFight.HELD_AT, "the stick held still doesn't reel (%.2f)" % player().crank)
	var start: float = player().fight.distance
	for i in 40:
		stick.output = Vector2.RIGHT.rotated(i * 0.25) * 0.8
		await frames(1)
	check(player().crank > 0.5, "turned round, it cranks (%.2f)" % player().crank)
	check(player().fight.distance < start, "and the line comes in (%.1f -> %.1f m)" % [start, player().fight.distance])
	check(player().is_cranking() and player().get_node("Body").clip == PlayerVisual.CLIP_REEL, "the reel turns on the sprite")
	stick.is_pressed = false
	stick.output = Vector2.ZERO
	player()._reset_line(Player.State.IDLE)


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


## User feedback: a lure came in far too fast a tap, and every fish struck
## right at the end by the player. A tap reels in a little; the strike
## comes partway along.
func test_lure_retrieve() -> void:
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	player().lure_stock = {"minnow": 3}
	player()._sync_lures()
	player().fishing_mode = Player.FishingMode.LURE
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	stick._reset()
	await frames(2)
	check(player().state == Player.State.WAITING, "lure cast and retrieving")
	player().cast_outcome = Player.CastOutcome.BITE
	player()._lure_nibbles.clear()
	player()._lure_bite_at = 0.5
	player()._wait_duration = 6.0
	player().retrieve_progress = 0.0
	for _i in 3:
		stick._touch_index = 7
		await frames(1)
		stick._reset()
		await frames(1)
	var tapped: float = player().retrieve_progress
	check(tapped > 0.05 and tapped < 0.15, "three taps reel it in a little (%.2f)" % tapped)
	check(player().state == Player.State.WAITING, "no strike yet")
	player().retrieve_progress = 0.49
	stick._touch_index = 7
	await frames(2)
	stick._reset()
	await frames(2)
	check(player().state == Player.State.BITE, "the strike comes partway in")
	var bites := []
	for _i in 200:
		player()._roll_catch_outcome()
		bites.append(player()._lure_bite_at)
	check(bites.min() < 0.3 and bites.max() > 0.7, "anywhere along the retrieve (%.2f-%.2f)" % [bites.min(), bites.max()])
	# User request: cranked faster, it comes in faster.
	var paces := []
	for turning in [0.0, 0.25]:
		player()._set_state(Player.State.WAITING)
		player()._lure_bite_at = 5.0
		player().retrieve_progress = 0.0
		stick._touch_index = 7
		stick.is_pressed = true
		for i in 60:
			stick.output = Vector2.RIGHT.rotated(i * turning) * 0.9
			await frames(1)
		paces.append(player().retrieve_progress)
		stick.is_pressed = false
		stick.output = Vector2.ZERO
		stick._reset()
		await frames(1)
	# (less the press's own nudge)
	var tap_in := Player.LURE_CLICK_AMOUNT
	check(paces[1] - tap_in > (paces[0] - tap_in) * 2.5,
		"cranked, it comes in faster than held still (%.3f vs %.3f)" % [paces[1] - tap_in, paces[0] - tap_in])
	player()._set_state(Player.State.IDLE)


## User request: a lure's bite shows which way to strike; how near the
## flick comes decides it - true (under 20 deg): on, a tenth of its stamina
## gone; 20-40: 80%; 40-90: 70%; beyond (or no way given): 60%; not struck
## in time: away.
func test_lure_strike_direction() -> void:
	check(Player.lure_strike_chance(10.0) == 1.0 and Player.lure_strike_chance(30.0) == 0.8
		and Player.lure_strike_chance(60.0) == 0.7 and Player.lure_strike_chance(120.0) == 0.6
		and Player.lure_strike_chance(-1.0) == 0.6, "the tiers")
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	player().aim_dir = Vector2.UP
	player().lure_stock = {"minnow": 3}
	player()._sync_lures()
	player().fishing_mode = Player.FishingMode.LURE
	var stick = main.get_node("HUD/Panel/AimJoystick")
	stick._touch_index = 7
	await frames(4)
	stick._reset()
	await frames(2)
	check(player().state == Player.State.WAITING, "lure cast")
	player().cast_outcome = Player.CastOutcome.BITE
	player()._lure_nibbles.clear()
	player().retrieve_progress = 0.5
	player()._lure_bite_at = 0.5
	await frames(2)
	check(player().state == Player.State.BITE and player().strike_dir.length() > 0.99, "a bite, a way to strike")
	var line: Vector2 = (player().cast_target - player().global_position).normalized()
	check(absf(player().strike_dir.dot(line.orthogonal())) > 0.7 and player().strike_dir.dot(line) <= 0.01,
		"across the line, back toward the bank")
	await frames(2)
	check(main.get_node("FightPanel")._drawn, "the way shown")
	# Flicked true: on, worn a tenth.
	player().touch_aim = player().strike_dir.rotated(deg_to_rad(10.0))
	stick._touch_index = 7
	await frames(2)
	stick._reset()
	player().touch_aim = Vector2.ZERO
	check(player().state == Player.State.REELING and player().fight.stamina() <= 0.9 + 0.001,
		"struck true: on, %.0f%% stamina" % (player().fight.stamina() * 100.0))
	player()._set_state(Player.State.IDLE)
	# Off by more: the chance it's on, each tier.
	for case in [[30.0, 0.8], [60.0, 0.7], [150.0, 0.6]]:
		var on := 0
		for _i in 300:
			player()._start_bite()
			player()._strike_lure(player().strike_dir.rotated(deg_to_rad(case[0])))
			if player().state == Player.State.REELING:
				on += 1
				check(player().fight.stamina() > 0.95, "off the way: nothing off it")
			player()._set_state(Player.State.IDLE)
		check(absf(on / 300.0 - case[1]) < 0.09, "%d deg off: on %.0f%% (%.0f%%)" % [case[0], on / 3.0, case[1] * 100.0])
	# User request: struck without letting go - cranking the lure in, the
	# bite comes, the thumb goes on round to the way and stops there.
	player()._set_state(Player.State.WAITING)
	stick._touch_index = 7
	stick.is_pressed = true
	stick.output = Vector2.RIGHT * 0.9
	await frames(1)
	player()._start_bite()
	for i in 8:
		stick.output = Vector2.RIGHT.rotated(i * 0.3) * 0.9
		await frames(1)
	check(player().state == Player.State.BITE, "cranking on doesn't strike")
	stick.output = player().strike_dir * 0.9
	await frames(14)
	check(player().state == Player.State.REELING and player().strike_off >= 0.0 and player().strike_off < 5.0,
		"taken on to the way and held there: struck that way (%.0f deg)" % player().strike_off)
	stick.is_pressed = false
	stick.output = Vector2.ZERO
	stick._reset()
	player()._set_state(Player.State.IDLE)
	await frames(2)
	# Not struck in time: away.
	player()._set_state(Player.State.WAITING)
	player()._start_bite()
	await seconds(player().bite_timer + 0.3)
	check(player().state == Player.State.IDLE, "not struck in time: away")



## its own four and its rarest; the sea its own. A cast only brings up fish
## of the map's waters, the rare pools only the style's own and better,
## small fish close in and big ones far out.
func test_fish_by_style() -> void:
	check(FishData.COMMON_FRESH.size() == 10, "10 shared freshwater fish")
	check(FishData.SEA_COMMON.size() >= 15 and FishData.SEA_COMMON.size() <= 20, "15-20 sea fish")
	var sea_rare: int = FishData.SEA_RARE.size() + FishData.SEA_LEGEND.size()
	check(sea_rare >= 5 and sea_rare <= 8, "5-8 rare sea fish")
	var ids := {}
	for style in FishData.STYLE_FISH:
		var own: Array = FishData.STYLE_FISH[style][0]
		check(own.size() >= 3 and own.size() <= 5, "%s: 3-5 fish of its own" % style)
		for id in own + [FishData.STYLE_FISH[style][1]]:
			check(not ids.has(id), "%s: %s belongs to one style only" % [style, id])
			ids[id] = true
	# Sampling: the forest's fish stay in the forest, the sea's in the sea.
	for water in ["forest", "ruins", "sea"]:
		var seen := {}
		for tier in ["near", "mid", "far"]:
			for rarity in ["common", "rare", "epic"]:
				for zone in ["common", "rare"]:
					for _i in 30:
						var f: Dictionary = FishData.pick_species(tier, zone, rarity, "", water)
						seen[f.id] = rarity
						check(f.id in FishData.FISH, "a real species")
		var allowed: Array = FishData.SEA_COMMON + FishData.SEA_RARE + FishData.SEA_LEGEND if water == "sea" \
			else FishData.COMMON_FRESH + FishData.STYLE_FISH[water][0] + [FishData.STYLE_FISH[water][1]]
		var strays: Array = seen.keys().filter(func(id): return not id in allowed)
		check(strays.is_empty(), "%s: only its own fish %s" % [water, str(strays)])
		if water != "sea":
			check(seen.has(FishData.STYLE_FISH[water][1]), "%s: its rarest can turn up" % water)
			check(FishData.pick_species("mid", "common", "epic", "", water).id == FishData.STYLE_FISH[water][1],
				"%s: a legendary catch is its rarest" % water)
	# The map sets the waters (the forest's, the one place now).
	await _fresh_game()
	check(FishData.waters == "forest", "the forest fishes its own (%s)" % FishData.waters)
	# Reach: the sardine only close in, the swordfish only far out.
	check(FishData.FISH.sardine.reach == ["near"] and FishData.FISH.swordfish.reach == ["far"], "reach")
	for _i in 40:
		check(FishData.pick_species("near", "common", "common", "", "sea").id != "cod", "no cod close in")


## User request (playtest): a catch has a length, a weight and a trait
## (for the fish tank), shown on the catch card and kept in the bag.
func test_catch_details() -> void:
	var p := player()
	GameState.carried_fish.clear()
	p.tier_data = FishData.get_tier_data("mid").duplicate()
	p.tier_data.label = "鯉魚"
	p.fish_id = "carp"
	p.current_tier = "mid"
	p.is_heart_catch = false
	p.is_epic_catch = false
	p.caught_in_hotspot = false
	p._succeed_catch()
	await frames(1)
	check(GameState.carried_fish.size() == 1, "the carp is in the bag")
	var f: Dictionary = GameState.carried_fish[0]
	var span: Array = FishData.LENGTH_CM.carp
	check(f.has("length") and f.length >= span[0] and f.length <= span[1], "a carp's length (%s)" % str(f.get("length")))
	check(float(f.get("weight", 0.0)) > 0.1, "and weight (%s kg)" % str(f.get("weight")))
	check(FishData.TANK_TRAITS.has(f.get("tank_trait", "")), "and a tank trait")
	var card: CatchCard = main.find_children("*", "CatchCard", true, false)[0]
	card.show_catch(f, false)
	check(card._measure.text.contains("cm") and card._measure.text.contains(FishData.trait_name(f.tank_trait)),
		"the card shows them: " + card._measure.text)
	# Small near-shore fish stay small, legends run past the top.
	for _i in 30:
		check(FishData.measure("sardine", "small").length <= 12 + 13 * 0.36, "a small sardine is small")
		check(FishData.measure("bluefin", "huge").weight > 100.0, "a legendary bluefin is heavy")
	var traits := {}
	for _i in 200:
		traits[FishData.roll_tank_trait("sardine")] = true
	check(traits.has("school") and traits.size() > 1, "sardines school, now and then one doesn't")
	GameState.carried_fish.clear()


## User request (warehouse): the warehouse and the bag packed for the next
## run - the shop fills the warehouse, things move between the two (by
## drag or by a card with a count), stack up to a cell's worth, keep their
## place in the bag, and go into the run from there.
func test_warehouse_and_bag() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 2000})
	for _i in 12:
		Profile.buy_lure("minnow")
	check(Profile.stored("lure_minnow") == 12 and Profile.bag_count("lure_minnow") == 0, "bought lures wait in the warehouse")
	check(Profile.bag_count("bait") == Profile.base_bait(), "the base bait takes its cells in the bag")
	check(Profile.to_storage(Profile.bag_at(Profile.bag[0].cell)) == 0, "and can't be put in the warehouse")
	check(Profile.to_bag("lure_minnow", 12) == 12 and Profile.bag.filter(func(e): return e.id == "lure_minnow").size() == 2,
		"ten to a cell: two stacks")
	for _i in 4:
		Profile.buy_battery()
	check(Profile.to_bag("battery", 4, Vector2i(5, 1)) == 4, "batteries packed")
	var bi := Profile.bag_at(Vector2i(5, 1))
	check(bi >= 0 and Profile.bag[bi].id == "battery" and int(Profile.bag[bi].count) == 3,
		"three to a cell, the first stack where it was dropped")
	check(not Profile.bag_move(bi, Profile.bag[0].cell), "not onto something else")
	check(Profile.bag_move(bi, Vector2i(7, 3)) and Profile.bag[Profile.bag_at(Vector2i(7, 3))].id == "battery", "moved to a free cell")
	# User request (Camp v2): the backpack's own page can throw things away.
	var li := Profile.bag.map(func(e): return e.id).find("lure_minnow")
	check(Profile.bag_discard(li, 1) == 1 and Profile.bag_count("lure_minnow") == 11, "a lure thrown away")
	Profile.bag[li].count += 1
	check(Profile.bag_discard(0) == 0, "the base bait can't be thrown away")
	check(Profile.buy_rod() and Profile.stored("rod_1") == 1 and Profile.rod_tier == 0, "a rod bought waits in the warehouse")
	check(Profile.equip("rod_1") and Profile.rod_tier == 1 and Profile.stored("rod_0") == 1, "put on, the old one stored")
	check(Profile.to_bag("rod_0", 1, Vector2i(3, 3)) == 1, "a spare rod packed")
	check(not Profile.bag_fits("battery", Vector2i(5, 3)), "a rod takes three cells")
	Profile.found_this_run.clear()
	Profile.bag.append({"id": "rod_4", "count": 1, "cell": Vector2i(3, 2)})
	Profile.note_found("rod_4", 1)
	var worms := {"id": "live_worm", "count": 3, "cell": Vector2i(-9, -9)}
	Profile.bag.append(worms)
	Profile.note_found("live_worm", 1)
	Profile.lose_found_gear()
	check(Profile.bag_count("rod_4") == 0 and Profile.bag_count("rod_0") == 1, "dying loses gear found on the map, not what was brought")
	check(int(worms.count) == 2 and Profile.found_this_run.is_empty(), "as many as were found, the rest of the stack kept")
	Profile.bag.erase(worms)
	check(Profile.equip("rod_0") and Profile.rod_tier == 0 and Profile.stored("rod_1") == 1 and Profile.bag_count("rod_0") == 0,
		"put on from the bag, the other one stored")
	check(Profile.buy_flashlight() and Profile.equip("flashlight") and Profile.has_flashlight, "the flashlight bought and worn")
	check(Profile.unequip("light") and not Profile.has_flashlight and Profile.stored("flashlight") == 1, "taken off, to the warehouse")
	check(not Profile.unequip("rod"), "there's always a rod on")
	# What the run takes: the bag, where it was packed.
	check(int(Profile.lure_stock.get("minnow", 0)) == 12 and Profile.batteries == 4, "the bag's lures and batteries go in")
	var items := Inventory.items(null)
	var placed := Inventory.pack(items)
	for k in items.size():
		if items[k].has("cell"):
			check(placed[k].position == items[k].cell, "%s packed where it was put" % items[k].label)
	check(Profile.use_battery() and Profile.batteries == 3, "a battery used comes out of the bag")
	check(Profile.bag_take("lure_minnow", 2) == 2 and Profile.bag_count("lure_minnow") == 10, "lures lost come out too")

	# The shop asks how many and where to.
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await frames(2)
	var had := Profile.bag_count("lure_zebra")
	shop.buy_dialog("lure_zebra", int(Profile.LURES.zebra.cost))
	await frames(1)
	var amount_slider: HSlider = shop.find_child("Amount", true, false)
	check(amount_slider != null and shop.find_child("To_equip", true, false) == null, "a count, and no 裝備 for a lure")
	amount_slider.value = 3
	(shop.find_child("To_bag", true, false) as Button).pressed.emit()
	await frames(1)
	check(Profile.bag_count("lure_zebra") == had + 3, "three bought straight into the bag")
	shop.queue_free()
	await frames(1)
	# Live baits: bought, packed, put on the hook one per float cast.
	check(Profile.buy_live_bait("worm") and Profile.buy_live_bait("worm"), "live worms bought")
	check(Profile.to_bag("live_worm", 2) == 2, "and packed")
	var pl := player()
	var base_before: int = pl.bait_count
	pl.choose_live_bait("worm")
	pl.use_bait_for_cast()
	check(pl.pending_bait_flavor == "蚯蚓" and Profile.bag_count("live_worm") == 1 and pl.bait_count == base_before,
		"a cast uses a worm, not a base bait")
	pl.use_bait_for_cast()
	pl.use_bait_for_cast()
	check(pl.live_bait == "" and pl.bait_count == base_before - 1, "out of worms, back to the base bait")
	pl.pending_bait_flavor = ""
	pl.bait_count = base_before
	# The shop's sections: cards with pictures.
	var shop2: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop2)
	await frames(2)
	for t in ["gear", "bait", "item", "upgrade"]:
		shop2._show_tab(t)
		await frames(1)
		check(shop2.find_children("Card_*", "Button", true, false).size() > 0, "shop section %s has cards" % t)
	shop2._show_tab("bait")
	await frames(1)
	check(shop2.find_child("Card_live_cricket", true, false) != null, "live baits for sale")
	check(Items.square_icon("lure_zebra") != null and Items.square_icon("rod_4") != null and Items.square_icon("up_bag") == null,
		"the wares have square icons (the MMO look)")
	# User request (show the gear on the character): a rod tried on.
	shop2._show_tab("gear")
	await frames(1)
	(shop2.find_child("Card_rod_4", true, false) as Button).pressed.emit()
	await frames(1)
	var try_on: Button = shop2.find_child("TryOn", true, false)
	check(try_on != null, "a rod can be tried on")
	try_on.button_pressed = true
	await frames(2)
	var view: CharacterViewer = shop2.find_child("TryOnView", true, false)
	var held: BoneAttachment3D = view.rig.attachments.get("hand_r") if view != null else null
	check(held != null and held.get_child_count() == 1 and held.get_child(0).scene_file_path.ends_with("lvl5.glb"),
		"the character holds the rod tried on")
	shop2.queue_free()
	await frames(1)
	# The page: drag from the warehouse onto the bag, and back.
	var page: Control = load("res://scenes/warehouse.tscn").instantiate()
	get_tree().root.add_child(page)
	await frames(3)
	check(page.find_child("Tab_tackle", true, false) != null and page.find_child("Tab_other", true, false) != null, "tabs")
	page._show_tab("gear")
	var bag = page._bag
	var drop_at: Vector2 = bag.global_position + Vector2(3.5, 2.5) * bag.cell
	page.pressed({"from": "storage", "id": "rod_1"}, page._storage.global_position + Vector2(10, 10))
	var motion := InputEventMouseMotion.new()
	motion.position = drop_at
	page._input(motion)
	check(page._dragging, "a drag starts")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = drop_at
	page._input(up)
	await frames(1)
	var ri := Profile.bag_at(Vector2i(3, 2))
	check(ri >= 0 and Profile.bag[ri].id == "rod_1" and Profile.stored("rod_1") == 0, "dragged into the bag, where it was let go")
	check(page.move({"from": "bag", "id": "rod_1", "index": ri}, {"to": "storage"}) and Profile.stored("rod_1") == 1, "and back")
	# A tap: the card, a count, into the bag.
	Profile.storage["battery"] = 5
	page.card({"from": "storage", "id": "battery"})
	await frames(1)
	var amount: Label = page.find_child("Amount", true, false)
	check(amount != null and amount.text == "5", "the card offers all five")
	var slider: HSlider = page.find_children("*", "HSlider", true, false)[0]
	slider.value = 2
	(page.find_child("Act_放進背包", true, false) as Button).pressed.emit()
	await frames(1)
	check(Profile.stored("battery") == 3 and Profile.batteries == 5, "two of them packed (%d left)" % Profile.stored("battery"))
	page.queue_free()
	await frames(1)
	Profile.load_data(saved)
	Profile._save()


## User request: the bigger things to tap, and a window that runs on past
## what shows scrolls under a finger from anywhere on it - over a ware's
## card (a button) too, without picking it; a tap still picks it. The
## warehouse's boxes scroll up and down, and a thing dragged sideways out of
## them still goes to the bag.
func _pointer(kind: String, at: Vector2) -> void:
	var ev: InputEvent
	if kind == "move":
		ev = InputEventMouseMotion.new()
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = kind == "down"
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev, true)
	await frames(1)


func _swipe(from: Vector2, by: Vector2) -> void:
	await _pointer("down", from)
	for k in range(1, 7):
		await _pointer("move", from + by * k / 6.0)
	await _pointer("up", from + by)


func test_lists_scroll_under_a_finger() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 99999})
	# The pages as at the camp: no run's camera moving the screen, nothing of
	# the run's drawn over them.
	var cam := get_viewport().get_camera_2d()
	cam.enabled = false
	var layers := main.find_children("*", "CanvasLayer", true, false).filter(func(l): return l.visible)
	for l in layers:
		l.visible = false
	await frames(1)
	check(Backpack.CELL >= 70.0, "the run's bag cells are bigger (%d)" % Backpack.CELL)
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await frames(3)
	var scroll: DragScroll = shop.find_child("WareScroll", true, false)
	check(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.size.y, "the wares run past the window")
	var card: Button = shop.find_child("Card_rod_1", true, false)
	var picked := [0]
	card.pressed.connect(func(): picked[0] += 1)
	var on_card := card.get_global_rect().get_center()
	await _pointer("down", on_card)
	for k in range(1, 7):
		await _pointer("move", on_card + Vector2(0, -25.0 * k))
	var at := scroll.scroll_vertical
	check(at > 100, "dragged up over a card, the list scrolls (%d)" % at)
	await _pointer("up", on_card + Vector2(0, -150))
	await frames(3)
	check(picked[0] == 0, "and the card isn't picked")
	check(scroll.scroll_vertical > at, "let go, it glides on a little")
	await seconds(1.5)
	scroll.scroll_vertical = 0
	await frames(2)
	await _pointer("down", card.get_global_rect().get_center())
	await _pointer("up", card.get_global_rect().get_center())
	check(picked[0] == 1, "a tap still picks it")
	shop.queue_free()
	await frames(1)

	# The warehouse: up and down scrolls, sideways is a drag to the bag.
	for k in Profile.LIVE_BAITS:
		Profile._store("live_" + k, 3)
	for l in Profile.LURES:
		Profile._store("lure_" + l, 3)
	var page: Control = load("res://scenes/warehouse.tscn").instantiate()
	get_tree().root.add_child(page)
	await frames(3)
	page._show_tab("tackle")
	await frames(2)
	var wscroll: DragScroll = page.find_child("StorageScroll", true, false)
	var storage = page._storage
	check(storage.cell >= 90.0 and page._bag.cell >= 68.0, "the warehouse's boxes and the bag's cells are bigger")
	check(wscroll.get_v_scroll_bar().max_value > wscroll.size.y, "a full tab runs past the window")
	var first: String = storage.ids()[0]
	var box_at: Vector2 = storage.global_position + storage.box(0).get_center()
	await _swipe(box_at, Vector2(0, -120))
	check(wscroll.scroll_vertical > 60 and not page._dragging and page._card == null,
		"dragged up on a thing, the boxes scroll - no drag, no card (%d)" % wscroll.scroll_vertical)
	await seconds(1.5)
	wscroll.scroll_vertical = 0
	await frames(2)
	var had := Profile.stored(first)
	var into: Vector2 = page._bag.global_position + Vector2(6.5, 3.5) * page._bag.cell
	await _pointer("down", box_at)
	for k in range(1, 7):
		await _pointer("move", box_at.lerp(into, k / 6.0))
	check(page._dragging and wscroll.scroll_vertical == 0, "dragged sideways, the thing is picked up")
	await _pointer("up", into)
	check(Profile.stored(first) < had and Profile.bag_count(first) > 0, "and goes into the bag")
	page.queue_free()
	await frames(1)
	cam.enabled = true
	for l in layers:
		if is_instance_valid(l):
			l.visible = true
	Profile.load_data(saved)
	Profile._save()


## User request (誘惑): a fish is picked from the bag as the lure; charged
## and aimed, it's thrown out (the big ghost goes for it); the button goes
## blank once it's gone (thrown or offered). And (for multiplayer) things
## can be put down from the bag and picked up again.
func test_lure_throw_and_drops() -> void:
	var saved := Profile.snapshot()
	gs.carried_fish.clear()
	for i in 3:
		gs.add_carried_fish({"name": "鯉魚", "id": "carp", "value": 4.0, "size": "small"})
	var p := player()
	check(gs.lure_index() == -1, "no lure fish at first")
	p.pick_lure_fish()
	await frames(1)
	var bag: Backpack = p.backpack()
	check(bag.is_open() and bag.mode() == "pick_lure", "the bag opens to pick one")
	bag.select("fish", 1)
	await frames(1)
	(bag.find_child("ConfirmLure", true, false) as Button).pressed.emit()
	await frames(1)
	check(gs.lure_index() == 1 and not bag.is_open(), "picked (after confirming)")
	var before := get_tree().get_nodes_in_group("dropped_fish").size()
	p.lure_pull = 1.0
	p.lure_held = true
	await frames(4)
	check(p.lure_charge > 0.99 and p._lure_guide.visible, "charged, the landing shown")
	var aim := p.lure_target()
	p.lure_held = false
	await frames(2)
	check(gs.carried_fish.size() == 2 and gs.lure_index() == -1, "thrown: out of the bag, the button blank again")
	await seconds(0.8)
	var landed := false
	for d in get_tree().get_nodes_in_group("dropped_fish"):
		if d.global_position.distance_to(aim) < 4.0:
			landed = true
	check(landed and get_tree().get_nodes_in_group("dropped_fish").size() == before + 1, "it landed where aimed")
	# Settings: the cheapest fish carried becomes the next lure.
	Profile.set_setting("auto_lure", true)
	gs.add_carried_fish({"name": "沙丁魚", "id": "sardine", "value": 1.0, "size": "small"})
	gs.set_lure(0)
	p.lure_pull = 0.2
	p.lure_held = true
	await frames(3)
	p.lure_held = false
	await frames(2)
	var li: int = gs.lure_index()
	check(li >= 0 and gs.carried_fish[li].id == "sardine", "auto: the cheapest is picked next")
	Profile.set_setting("auto_lure", false)
	gs.set_lure(0)
	gs.sacrifice_at(0)
	check(gs.lure_index() == -1, "an offered lure fish leaves the button blank")
	# Put down and picked up.
	Profile.load_data({"gold": 0})
	Profile.bag_put("battery", 2)
	p.put_item_down(Profile.bag.map(func(e): return e.id).find("battery"))
	await frames(2)
	check(Profile.batteries == 0 and get_tree().get_nodes_in_group("dropped_items").size() == 1, "batteries put down")
	check(p.interaction().get("verb", "") == "撿起", "and offered to pick up")
	await tap(KEY_E)
	await frames(2)
	check(Profile.batteries == 2 and get_tree().get_nodes_in_group("dropped_items").is_empty(), "picked up again")
	p.put_fish_down(0)
	check(gs.carried_fish.size() == 0, "a fish put down")
	Profile.load_data(saved)
	Profile._save()


## User request: drag things out of the bag to put them down; rare fish
## (and gear, special things) ask first.
func test_bag_drag_out() -> void:
	gs.carried_fish.clear()
	gs.add_carried_fish({"name": "鯉魚", "id": "carp", "value": 3.0, "size": "small", "rarity": "common"})
	gs.add_carried_fish({"name": "金鱒", "id": "golden_trout", "value": 30.0, "size": "large", "rarity": "epic"})
	var bag: Backpack = player().backpack()
	bag.toggle()
	await frames(2)
	var grid = bag._grid
	var drag := func(kind_index: int) -> void:
		var i: int = -1
		for k in grid.items.size():
			if grid.items[k].kind == "fish" and grid.items[k].index == kind_index:
				i = k
		var r: Rect2i = grid.placed[i]
		var at := (Vector2(r.position) + Vector2(r.size) / 2.0) * Backpack.CELL
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = at
		grid._gui_input(press)
		var out := at + Vector2(-600, 0)
		var move := InputEventMouseMotion.new()
		move.position = out
		grid._gui_input(move)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = out
		grid._gui_input(up)
	# The common carp (index 0) goes straight down.
	drag.call(0)
	await frames(2)
	check(gs.carried_fish.size() == 1 and gs.carried_fish[0].id == "golden_trout", "a common fish dragged out is put down")
	bag._rebuild()
	await frames(1)
	drag.call(0)
	await frames(1)
	check(gs.carried_fish.size() == 1 and bag.find_child("DropConfirm", true, false) != null, "a rare one asks first")
	(bag.find_child("ConfirmDrop", true, false) as Button).pressed.emit()
	await frames(2)
	check(gs.carried_fish.is_empty(), "and goes down once confirmed")
	bag.toggle()
	await frames(1)


## User request (HUD): no lists of numbers - the quota as a bar at the top
## middle with the time under it, the light's energy as a percentage with a
## brightness bar; the sticks unseen till touched; a flash costs a share
## of the energy; the light dims by itself as it runs down.
func test_hud_top() -> void:
	check(main.find_child("QuotaView", true, false) != null and main.find_child("EnergyView", true, false) != null,
		"quota bar and energy panel")
	for n in ["StateLabel", "QuotaLabel", "GearLabel", "PhaseLabel", "EvilLabel", "OfferingLabel", "GoldLabel", "WeatherLabel", "FuelBar"]:
		check(not main.get_node("HUD/Panel/" + n).visible, n + " hidden")
	check(main.get_node("HUD/Panel/MoveJoystick").modulate.a < 0.05, "the sticks are unseen")
	var lantern: Lantern = player().get_node("Lantern")
	lantern.fuel = lantern.max_fuel
	lantern.flash_cooldown = 0.0
	lantern._try_flash()
	check(absf(lantern.fuel - lantern.max_fuel * (1.0 - Lantern.FLASH_SHARE)) < 0.5, "a flash takes its share")
	lantern.brightness = Lantern.MAX_BRIGHTNESS
	await seconds(1.5)
	check(is_equal_approx(lantern.brightness, Lantern.MAX_BRIGHTNESS), "above 30% the light holds its brightness")
	lantern.fuel = lantern.max_fuel * 0.25
	await seconds(2.0)
	check(lantern.brightness < Lantern.MAX_BRIGHTNESS, "below 30% it dims as it burns")
	var ev = main.find_child("EnergyView", true, false)
	var held := lantern.brightness
	ev._set_from(ev.BAR.position.x)
	check(is_equal_approx(lantern.brightness, held), "the panel doesn't set it (user request: no turning it up or down)")
	# The dark deepening: the same light, burning more oil for it.
	lantern.fuel = lantern.max_fuel
	lantern._stage_power = 0.62
	check(lantern.night_cost() > 1.5, "late at night it burns half again as fast and more (x%.1f)" % lantern.night_cost())
	lantern._stage_power = 1.0
	check(not main.get_node("HUD/Panel/MessageLabel").visible, "no narrating text")
	lantern.fuel = lantern.max_fuel
	lantern.brightness = 0.75


## User request (fish tank): fish carried out of a run go in the tank; the
## main screen says so; the tank page shows them swimming, lists them, and
## sells them.
## User request: fish have a vitality (活性) and then a freshness (新鮮度),
## and traits that bend them (FishLife).
func test_fish_life() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 0})
	# A catch rolls its life.
	var f := FishLife.roll({"id": "carp", "name": "鯉魚", "value": 10.0, "rarity": "common"})
	check(FishLife.has_life(f) and f.vit > 0.0 and f.vit <= 1.0 and not f.dead and not f.rotten and f.fresh == 1.0, "a catch has its life")
	# Starts and paces differ fish to fish (not all alike).
	var starts := {}
	var lives := {}
	for _i in 60:
		var g := FishLife.roll({"id": "carp", "rarity": "common"})
		starts[snappedf(g.vit, 0.05)] = true
		lives[snappedf(g.vit_life, 50.0)] = true
	check(starts.size() >= 5 and lives.size() >= 3, "starts and paces differ (%d, %d)" % [starts.size(), lives.size()])
	# The traits' reach: 垂死 starts low, 生猛 high; none clash.
	var dying := true
	var vigorous := true
	var clash := false
	for _i in 300:
		var g := FishLife.roll({"id": "bass", "rarity": "epic"})
		var t: Array = g.life_traits
		dying = dying and (not "dying" in t or g.vit < 0.3)
		vigorous = vigorous and (not "vigorous" in t or g.vit >= 0.9)
		for group in FishLife.EXCLUSIVE:
			var n := 0
			for x in group:
				n += 1 if x in t else 0
			clash = clash or n > 1
		clash = clash or t.size() > 2
	check(dying and vigorous and not clash, "垂死 starts under 30%, 生猛 over 90%, none clash, at most two")
	# Time: alive, then dead, then rotten.
	var a := {"id": "carp", "value": 10.0, "vit": 0.5, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 200.0, "dead": false, "rotten": false,
		"life_traits": []}
	check(FishLife.tick(a, 25.0) == "" and absf(a.vit - 0.25) < 0.001 and FishLife.state(a) == "alive", "vitality runs down: 25 s of 50 left")
	check(FishLife.tick(a, 25.0) == "died" and FishLife.state(a) == "dead" and a.vit == 0.0, "at nothing it's dead")
	check(FishLife.tick(a, 100.0) == "" and absf(a.fresh - 0.5) < 0.001, "dead: the freshness runs down (half in 100 of 200 s)")
	check(FishLife.tick(a, 100.0) == "rotted" and FishLife.state(a) == "rotten" and a.value == 0.0, "at nothing it's rotten, worth nothing")
	# One long tick carries its spare time into the freshness.
	var b := {"vit": 0.1, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 200.0, "dead": false, "rotten": false, "life_traits": []}
	FishLife.tick(b, 110.0)
	check(b.dead and absf(b.fresh - 0.5) < 0.001, "a long tick: died at 10 s, the other 100 s of 200 on its freshness (%.2f)" % b.fresh)
	# The traits' reach on the pace.
	var base := {"vit": 1.0, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 100.0, "dead": false, "rotten": false, "life_traits": []}
	var tough := base.duplicate(true)
	tough.life_traits = ["tough"]
	var weary := base.duplicate(true)
	weary.life_traits = ["weary"]
	check(FishLife.vit_rate(tough) < FishLife.vit_rate(base) and FishLife.vit_rate(weary) > FishLife.vit_rate(base), "頑強 slower, 厭世 faster")
	var filthy := base.duplicate(true)
	filthy.life_traits = ["filthy"]
	var clean := base.duplicate(true)
	clean.life_traits = ["clean"]
	check(FishLife.fresh_rate(filthy) > FishLife.fresh_rate(base) and FishLife.fresh_rate(clean) < FishLife.fresh_rate(base), "骯髒 faster, 潔身 slower")
	var night := base.duplicate(true)
	night.life_traits = ["nocturnal"]
	check(FishLife.vit_rate(night, true) < FishLife.vit_rate(night, false), "夜行: slower at night")
	# 不死 never dies, 不腐 never rots, a spoiling kind rots as it dies.
	var imm := base.duplicate(true)
	imm.life_traits = ["immortal"]
	FishLife.tick(imm, 100000.0)
	check(FishLife.state(imm) == "alive" and imm.vit == 1.0, "不死 never dies")
	var imp := base.duplicate(true)
	imp.life_traits = ["imperishable"]
	imp.dead = true
	imp.vit = 0.0
	FishLife.tick(imp, 100000.0)
	check(FishLife.state(imp) == "dead" and imp.fresh == 1.0, "不腐 never rots")
	var spoil := base.duplicate(true)
	spoil.fresh_life = 0.5
	FishLife.tick(spoil, 200.0)
	check(FishLife.state(spoil) == "rotten", "one that spoils at once is rotten as it dies")
	var ghost := FishLife.roll({"id": "ghost_fish", "rarity": "epic"})
	check(ghost.fresh_life < 0.0 and FishLife.fresh_rate(ghost) == 0.0, "the ghost fish never rots")
	var sardine := FishLife.roll({"id": "sardine", "rarity": "common"})
	check(sardine.fresh_life <= FishLife.INSTANT, "the sardine spoils as it dies")
	# Traits together: 垂死 + 頑強 is low and slow; 垂死 + 潔身 dies at once and keeps.
	var dt := {"vit": 0.2, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 100.0, "dead": false, "rotten": false, "life_traits": ["dying", "tough"]}
	var dc := {"vit": 0.2, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 100.0, "dead": false, "rotten": false, "life_traits": ["dying", "clean"]}
	check(FishLife.lifespan_left(dt) > FishLife.lifespan_left(dc) * 2.0, "垂死 + 頑強 outlasts 垂死 + 潔身 on its vitality")
	check(FishLife.fresh_rate(dc) < FishLife.fresh_rate(dt), "垂死 + 潔身 keeps longer once dead")
	# What it's worth.
	var w := {"value": 10.0, "dead": false, "rotten": false, "vit": 0.5, "fresh": 1.0}
	check(FishLife.sale_value(w) == 10, "alive: its value")
	w.dead = true
	w.fresh = 1.0
	var fresh_price := FishLife.sale_value(w)
	w.fresh = 0.0
	check(fresh_price == 9 and FishLife.sale_value(w) == 4, "dead: by how fresh (%d / %d)" % [fresh_price, FishLife.sale_value(w)])
	w.rotten = true
	check(FishLife.sale_value(w) == 0, "rotten: nothing")
	# Carried in a run the bag's fish age (GameState).
	GameState.carried_fish.clear()
	var c := {"name": "鯉魚", "id": "carp", "value": 10.0, "size": "small"}
	GameState.add_carried_fish(c)
	check(FishLife.has_life(c), "a fish put in the bag has a life")
	c.vit = 0.01
	c.life_traits = []
	c.vit_life = 10.0
	GameState.run_started = true
	GameState.run_over = false
	GameState._age_fish(2.0)
	check(FishLife.state(c) == "dead", "the bag's fish age with the run")
	# Brought home: the living to the tank, the dead to the box, the rotten too.
	var live := FishLife.roll({"name": "鯽魚", "id": "crucian", "value": 4.0, "size": "small", "rarity": "common"})
	live.life_traits = []
	var corpse := FishLife.roll({"name": "鯰魚", "id": "catfish", "value": 8.0, "size": "medium", "rarity": "common"})
	corpse.life_traits = []
	FishLife.kill(corpse)
	var rot := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	FishLife.rot(rot)
	GameState.carried_fish = [live, corpse, rot]
	Profile.tank.clear()
	Profile.fish_box.clear()
	var text: String = GameState._bring_fish_home()
	check(Profile.tank.size() == 1 and Profile.tank[0].name == "鯽魚", "alive: in the tank")
	check(Profile.fish_box.size() == 2 and text.contains("死掉的魚 1 條") and text.contains("腐敗的魚 1 條"), "dead and rotten: in the box (%s)" % text)
	check(not Profile.add_to_tank(corpse), "a dead one can't go in the tank")
	# Sold to the merchant: the dead for their worth, the rotten not at all.
	var gold := Profile.gold
	var price := FishLife.sale_value(Profile.fish_box[0])
	check(Profile.box_sellable() == 1 and Profile.box_worth() == price, "one to sell (%d)" % price)
	check(Profile.sell_from_box(1) == 0 and Profile.fish_box.size() == 2, "the rotten one can't be sold")
	check(Profile.sell_box_all() == price and Profile.gold == gold + price and Profile.fish_box.size() == 1, "sold: the gold in, the rotten kept")
	Profile.discard_from_box(0)
	check(Profile.fish_box.is_empty(), "the rotten one thrown away")
	# It's kept (saved, loaded).
	Profile.add_to_fish_box(corpse)
	var snap := Profile.snapshot()
	Profile.fish_box.clear()
	Profile.load_data(snap)
	check(Profile.fish_box.size() == 1, "the box is saved")
	# On the ground it goes on.
	var d: DroppedFish = load("res://scenes/dropped_fish.tscn").instantiate() if ResourceLoader.exists("res://scenes/dropped_fish.tscn") else null
	if d != null:
		get_tree().root.add_child(d)
		var drop := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 10.0, "size": "small", "rarity": "common"})
		drop.life_traits = []
		drop.vit = 0.01
		drop.vit_life = 10.0
		d.setup(drop)
		d._process(5.0)
		check(FishLife.state(d.life) == "dead", "on the ground its life goes on")
		check(FishLife.state(d.as_fish()) == "dead" and d.as_fish().has("life_traits"), "picked up: as it was")
		d.queue_free()
	GameState.carried_fish.clear()
	GameState.run_started = false
	Profile.load_data(saved)


## User request: the very rare traits (財神 引路魚 鐵匠 惡靈 天使).
func test_mythic_traits() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 0})
	# They come up now and then, one at most, never among the common ones' draw.
	var seen := {}
	for _i in 4000:
		var f := FishLife.roll({"id": "bass", "rarity": "epic"})
		var n := 0
		for t in f.life_traits:
			if t in FishLife.MYTHIC:
				n += 1
				seen[t] = true
		if n > 1:
			check(false, "one mythic trait at most")
	check(seen.size() == FishLife.MYTHIC.size(), "all five come up (%d)" % seen.size())
	# The angel (alive) and the wraith (rotten) in the bag.
	var angel := {"vit": 0.5, "vit_life": 100.0, "dead": false, "rotten": false, "life_traits": ["angel"]}
	var wraith := {"vit": 0.0, "dead": true, "rotten": true, "life_traits": ["wraith"]}
	var living_wraith := {"vit": 0.5, "dead": false, "rotten": false, "life_traits": ["wraith"]}
	check(absf(FishLife.beast_ward([angel]) - 0.5) < 0.001 and absf(FishLife.imp_rate([angel]) - 0.4) < 0.001, "angel: beasts -50%, imps -60%")
	check(absf(FishLife.beast_ward([wraith]) - 0.2) < 0.001 and absf(FishLife.imp_rate([wraith]) - 1.1) < 0.001, "wraith (rotten): beasts -20%, imps +10%")
	check(FishLife.beast_ward([living_wraith]) == 0.0 and FishLife.imp_rate([living_wraith]) == 1.0, "a wraith that's not rotten does nothing")
	check(absf(FishLife.beast_ward([angel, wraith]) - 0.6) < 0.001, "together: beasts -60%")
	var dead_angel := {"vit": 0.0, "dead": true, "rotten": false, "life_traits": ["angel"]}
	check(FishLife.beast_ward([dead_angel]) == 0.0, "a dead angel does nothing")
	# The ghosts' gap runs slower/faster by the carried.
	GameState.reset_run()
	GameState.run_started = true
	GameState.carried_fish = [angel.duplicate(true)]
	var quiet0: float = GameState._ghost_quiet
	GameState._process(1.0)
	var slow: float = GameState._ghost_quiet - quiet0
	GameState.carried_fish.clear()
	quiet0 = GameState._ghost_quiet
	GameState._process(1.0)
	var plain: float = GameState._ghost_quiet - quiet0
	check(slow < plain * 0.5, "with the angel the imps are slow to come (%.2f vs %.2f)" % [slow, plain])
	# A beast's pounce turned aside.
	Abilities.forced = false
	var p := player()
	if p != null:
		GameState.carried_fish = [angel.duplicate(true)]
		var hits := 0
		for _i in 200:
			p.water_ghost_timer = 0.0
			# (a pounce that lands knocks a fish loose: the angel back each time)
			GameState.carried_fish = [angel.duplicate(true)]
			p.animal_attack("狼")
			hits += 1 if p.water_ghost_timer > 0.0 else 0
		check(hits > 60 and hits < 140, "the angel turns about half the pounces aside (%d of 200 landed)" % hits)
		GameState.carried_fish.clear()
	# The fortune fish: gold by the hour, to a cap.
	Profile.tank.clear()
	Profile.now_override = 1000000.0
	Profile.fortune_clock = 0.0
	Profile.settle_fortune()
	var rich := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	rich.life_traits = ["fortune"]
	check(Profile.add_to_tank(rich), "a fortune fish in the tank")
	Profile.now_override = 1000000.0 + 3600.0 * 2.5
	check(Profile.settle_fortune() == 50 and Profile.gold == 50, "2.5 hours: 50 gold")
	Profile.now_override += 3600.0 * 0.5
	check(Profile.settle_fortune() == 10, "and the half hour kept: 10 more")
	Profile.now_override += 3600.0 * 100.0
	check(Profile.settle_fortune() == 240, "capped at 12 hours (240)")
	var rich2 := rich.duplicate(true)
	check(Profile.add_to_tank(rich2), "a second one")
	Profile.now_override += 3600.0
	check(Profile.settle_fortune() == 40, "two: 40 an hour")
	# The guide fish: a night escaped, now and then an eye.
	Profile.tank.clear()
	var guide := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	guide.life_traits = ["guide"]
	Profile.add_to_tank(guide)
	GameState.is_night = false
	check(GameState._guide_gift() == "", "by day: nothing")
	GameState.is_night = true
	Abilities.forced = true
	var gift: String = GameState._guide_gift()
	Abilities.forced = false
	var eyes := 0
	for id in FishLife.GUIDE_EYES:
		eyes += Profile.stored(id)
	check(gift.contains("引路魚帶回了") and eyes == 1, "a night escaped: an eye in the warehouse (%s)" % gift)
	GameState.is_night = false
	# The smith: gear worn down is mended.
	Profile.wear["knife"] = 20
	Profile.add_stored("knife", 1)
	check("knife" in Profile.repairable(), "worn gear can be mended")
	check(Profile.repair("knife", FishLife.SMITH_REPAIR) == 5 and Profile.durability("knife") == 25, "5 uses back")
	check(Profile.repair("knife", 1000) == 35 and not Profile.wear.has("knife"), "never past full")
	Profile.now_override = 0.0
	GameState.carried_fish.clear()
	GameState.run_started = false
	Profile.load_data(saved)


## User request: fish out of the tank into the bag or the warehouse, and
## back; the smith fed a rotten fish mends gear.
func test_tank_moves_and_feeding() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 0})
	var carp := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	carp.life_traits = []
	Profile.tank = [carp]
	check(Profile.fish_places(carp, "tank") == ["pack", "stash"], "a living fish in the tank: bag, warehouse")
	check(Profile.move_fish("tank", 0, "pack") == "" and Profile.tank.is_empty() and Profile.pack_fish.size() == 1, "taken out into the bag")
	check(Profile.move_fish("pack", 0, "stash") == "" and Profile.stash_fish.size() == 1, "from the bag to the warehouse")
	check(Profile.move_fish("stash", 0, "tank") == "" and Profile.tank.size() == 1, "and back in the tank")
	var corpse := FishLife.roll({"name": "鯰魚", "id": "catfish", "value": 8.0, "size": "medium", "rarity": "common"})
	FishLife.kill(corpse)
	Profile.fish_box = [corpse]
	check(Profile.move_fish("box", 0, "tank") != "" and Profile.fish_box.size() == 1, "a dead one can't go in the tank")
	check(Profile.fish_places(corpse, "box") == ["pack", "stash"], "a dead one: bag or warehouse")
	check(Profile.move_fish("box", 0, "pack") == "" and Profile.pack_fish.size() == 1, "a dead one in the bag")
	# Full: the warehouse has a limit.
	Profile.stash_fish.clear()
	for _i in Profile.STASH_SIZE:
		Profile.stash_fish.append(carp.duplicate(true))
	check(Profile.move_fish("tank", 0, "stash") != "", "the warehouse is full")
	Profile.stash_fish.clear()
	# The bag's fish go on the run.
	Profile.pack_fish = [carp.duplicate(true)]
	GameState.reset_run()
	GameState.start_run()
	check(GameState.carried_fish.size() == 1 and Profile.pack_fish.is_empty(), "packed fish go on the run")
	GameState.carried_fish.clear()
	GameState.run_started = false
	# The page: tabs and moves, and the smith.
	var page: Control = load("res://scenes/fish_tank.tscn").instantiate()
	Profile.tank = [carp]
	Profile.pack_fish = []
	get_tree().root.add_child(page)
	await frames(3)
	check(page.find_child("Tab_tank", true, false) != null and page.find_child("Tab_pack", true, false) != null, "the page has its tabs")
	page.find_child("Tab_pack", true, false).pressed.emit()
	await frames(2)
	check(page.find_child("List", true, false).get_child_count() == 1, "the bag tab: its empty note")
	page.find_child("Tab_tank", true, false).pressed.emit()
	await frames(2)
	page._card_for(0)
	await frames(2)
	var mv: Button = page.find_child("Move_pack", true, false)
	check(mv != null and page.find_child("FeedFish", true, false) == null, "the card offers the bag; no feeding a plain fish")
	mv.pressed.emit()
	await frames(2)
	check(Profile.pack_fish.size() == 1 and Profile.tank.is_empty(), "the button moved it")
	# The smith.
	var smith := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	smith.life_traits = ["smith"]
	Profile.tank = [smith]
	var rotten := FishLife.roll({"name": "鯽魚", "id": "crucian", "value": 3.0, "size": "small", "rarity": "common"})
	FishLife.rot(rotten)
	Profile.fish_box = [rotten]
	Profile.wear["knife"] = 10
	Profile.add_stored("knife", 1)
	page._rebuild()
	page._card_for(0)
	await frames(2)
	var feed: Button = page.find_child("FeedFish", true, false)
	check(feed != null, "the smith can be fed")
	feed.pressed.emit()
	await frames(2)
	check(page.find_child("Modal", true, false) != null, "it asks which rotten fish")
	page._feed_gear(0)
	await frames(2)
	var mended: Button = null
	for b in page.find_child("Modal", true, false).find_children("*", "Button", true, false):
		if b.text.begins_with("小刀") or b.text.contains("耐久 10"):
			mended = b
	check(mended != null, "it asks which gear")
	if mended != null:
		mended.pressed.emit()
	await frames(2)
	check(Profile.durability("knife") == 15 and Profile.fish_box.is_empty(), "the knife mended 5; the rotten fish eaten")
	page.queue_free()
	Profile.load_data(saved)


## User request: the oxygenated fish box, the oxygen algae and the frozen soil.
func test_oxy_items() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 500})
	# The slow: vitality runs at a quarter for its time, then as it was.
	var f := {"vit": 1.0, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 100.0, "dead": false, "rotten": false, "life_traits": []}
	check(FishLife.use_algae(f) == "" and f.vit_slow == FishLife.ALGAE_TIME, "algae on a living fish")
	FishLife.tick(f, 100.0)
	# 100 s at a quarter: 25%
	check(absf(f.vit - 0.75) < 0.001 and f.vit_slow == 80.0, "100 s of the 180 slowed: a quarter gone (%.2f)" % f.vit)
	FishLife.tick(f, 100.0)
	# the last 80 s slowed (20%), then 20 s at full (20%)
	check(absf(f.vit - 0.35) < 0.001 and f.vit_slow == 0.0, "the slow runs out, then the usual pace (%.2f)" % f.vit)
	var left := FishLife.lifespan_left({"vit": 0.5, "vit_life": 100.0, "dead": false, "rotten": false, "life_traits": [], "vit_slow": 100.0})
	check(absf(left - 125.0) < 0.01, "its lifespan counts the slow: 100 s at a quarter take a quarter of it, the rest 25 s (%.1f)" % left)
	var d := {"vit": 0.0, "dead": true, "rotten": false, "fresh": 1.0, "fresh_life": 100.0, "life_traits": []}
	check(FishLife.use_algae(d) != "", "no algae on a dead fish")
	check(FishLife.use_frozen(d) == "" and d.fresh_slow == FishLife.FROZEN_TIME, "frozen soil on a dead one")
	FishLife.tick(d, 200.0)
	check(absf(d.fresh - 0.5) < 0.001, "200 s slowed: 50 of 100 s's worth (%.2f)" % d.fresh)
	var alive := {"vit": 0.5, "vit_life": 100.0, "fresh": 1.0, "fresh_life": 100.0, "dead": false, "rotten": false, "life_traits": []}
	FishLife.use_frozen(alive)
	FishLife.tick(alive, 10.0)
	check(alive.fresh_slow == FishLife.FROZEN_TIME, "frozen soil's time waits till it's dead")
	var rot := {"dead": true, "rotten": true, "vit": 0.0, "fresh": 0.0, "life_traits": []}
	check(FishLife.use_frozen(rot) != "", "nor on a rotten one")
	# Items.
	check(Items.def("oxy_box").size == Vector2i(6, 1) and Items.def("oxy_box").slot == "offhand", "the box: six cells, the off hand")
	check(Items.def("oxy_algae").has("use") and Items.def("frozen_soil").has("use"), "the two are things to use")
	check(Profile.max_durability("oxy_box") > 0, "the box wears")
	# Bought, worn.
	var gold := Profile.gold
	check(Profile.buy_oxy_box() and Profile.gold == gold - Profile.OXY_BOX_COST and Profile.stored("oxy_box") == 1, "bought once")
	check(not Profile.buy_oxy_box(), "not twice")
	# Unworn it takes six cells of the bag, a row.
	Profile.bag.clear()
	check(Profile.bag_fits("oxy_box", Vector2i(0, 0)) and not Profile.bag_fits("oxy_box", Vector2i(3, 0)), "six cells wide: it needs a row's room")
	check(Profile.equip("oxy_box") and Profile.has_oxy_box(), "worn in the off hand")
	# In a run: fish in and out, each a use; what's in doesn't run down.
	GameState.reset_run()
	GameState.run_started = true
	var a := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	a.life_traits = []
	a.vit = 0.5
	a.vit_life = 100.0
	var b := a.duplicate(true)
	GameState.carried_fish = [a, b]
	var uses := Profile.durability("oxy_box")
	check(GameState.oxy_put(0) == "" and GameState.oxy_fish.size() == 1 and GameState.carried_fish.size() == 1, "one in the box")
	check(Profile.durability("oxy_box") == uses - 1, "a use of the box")
	GameState._age_fish(10.0)
	check(absf(GameState.oxy_fish[0].vit - 0.5) < 0.0001 and GameState.carried_fish[0].vit < 0.45, "in the box it doesn't run down, the other does")
	check(GameState.oxy_take(0) == "" and GameState.oxy_fish.is_empty() and GameState.carried_fish.size() == 2, "taken out")
	check(Profile.durability("oxy_box") == uses - 2, "and another use")
	for _i in Profile.OXY_SLOTS:
		GameState.carried_fish.append(a.duplicate(true))
	GameState.carried_fish = GameState.carried_fish.slice(0, 8)
	for _i in Profile.OXY_SLOTS:
		GameState.oxy_put(0)
	check(GameState.oxy_fish.size() == Profile.OXY_SLOTS and GameState.oxy_put(0) == "魚箱滿了", "six slots")
	# Lost with the run unless escaped.
	var home := GameState.oxy_fish.size()
	GameState.run_over = false
	GameState.end_run(false, "lost")
	check(GameState.oxy_fish.is_empty(), "not escaped: what's in the box is lost too (%d)" % home)
	# Escaped: they come home.
	Profile.tank.clear()
	GameState.reset_run()
	var c := a.duplicate(true)
	GameState.oxy_fish = [c]
	GameState.run_started = true
	GameState.end_run(true, "ok")
	check(Profile.tank.size() == 1, "escaped: the boxed fish come home too")
	# It breaks: what's in it comes out.
	GameState.reset_run()
	Profile.wear["oxy_box"] = 1
	GameState.carried_fish = [a.duplicate(true)]
	GameState.oxy_fish = [a.duplicate(true)]
	GameState.oxy_put(0)
	check(not Profile.has_oxy_box() and GameState.oxy_fish.is_empty() and GameState.carried_fish.size() == 2, "broken: the fish are back out")
	# The off hand's box isn't swung.
	Profile.add_stored("oxy_box", 1)
	Profile.equip("oxy_box")
	var p := player()
	if p != null:
		check(not p.offhand_in_hand(), "the box hangs at the hip: nothing to swing")
	Profile.equipped["offhand"] = ""
	# The algae on the map; used on a fish.
	GameState.carried_fish.clear()
	GameState.run_started = false
	Profile.load_data(saved)


func test_fish_tank() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 0})
	GameState.carried_fish = [
		{"name": "鯉魚", "id": "carp", "value": 6.0, "size": "medium", "length": 55.0, "weight": 2.3, "tank_trait": "glutton"},
		{"name": "沙丁魚", "id": "sardine", "value": 2.0, "size": "small"},
		{"name": "鯉魚", "id": "carp", "value": 0.0, "rotten": true, "size": "small"},
	]
	var text: String = GameState._bring_fish_home()
	check(text.contains("將 鯉魚、沙丁魚 放進魚缸"), "the message: " + text)
	check(Profile.tank.size() == 2 and GameState.carried_fish.is_empty(), "two in the tank, the rotten one brought home apart")
	check(Profile.fish_box.size() == 1 and text.contains("腐敗的魚 1 條帶回來了"), "the rotten one in the fish box, told: " + text)
	Profile.fish_box.clear()
	check(Profile.tank[1].has("length") and Profile.tank[1].has("tank_trait"), "an old-style fish gets its measure")
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(2)
	check(title.find_child("TankNews", true, false) != null and Profile.tank_news.is_empty(), "the main screen tells, once")
	title.queue_free()
	var page: Control = load("res://scenes/fish_tank.tscn").instantiate()
	get_tree().root.add_child(page)
	await seconds(1.0)
	var tank = page.find_child("Tank", true, false)
	check(tank.fish().size() == 2, "both swim in the tank")
	var inside := true
	for s in tank.fish():
		inside = inside and tank.inside(s)
	check(inside, "and stay in the water")
	# User request (3D out of the game): the tank is 3D; a tap on a fish
	# picks it.
	check(tank is Aquarium, "the tank is 3D")
	if tank is Aquarium:
		var s: Node3D = tank.fish()[0]
		check(tank.pick(tank.camera.unproject_position(s.global_position)) >= 0, "a tap on a fish in the 3D tank picks it")
	check(page.find_child("Fish_0", true, false) != null and page.find_child("Fish_1", true, false) != null, "the list")
	check(page.find_child("FishLog", true, false) != null, "the fish log is reached from the tank")
	tank.feed()
	check(tank.food().size() > 0, "food goes in")
	page._card_for(0)
	await frames(1)
	check(page.find_child("Preview", true, false) is ItemPreview, "the fish's card shows it in 3D")
	(page.find_child("Sell", true, false) as Button).pressed.emit()
	await frames(2)
	check(Profile.tank.size() == 1 and Profile.gold == 6, "sold for its value (gold %d)" % Profile.gold)
	page.queue_free()
	await frames(1)
	Profile.load_data(saved)
	Profile._save()


## User request: a mobile-game main screen - the player's own character in
## 3D, the shop, the equipment page, single player and multiplayer - and
## the equipment page and the fish log it leads to.
func test_main_menu() -> void:
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	title._on_settings()
	await frames(1)
	check(title.find_child("AutoLure", true, false) != null, "settings: the auto-lure option")
	# User request (MMO look, 3D out of the game): the main screen is a 3D
	# camp with the character by the fire.
	var camp: CampStage = title.find_child("Camp", true, false)
	check(camp != null, "the main screen is the 3D camp")
	var rig: CharacterRig = camp.character
	var hand: BoneAttachment3D = rig.attachments.get("hand_r")
	# User request (Camp v2): at camp the hands are empty - the lamp sits on
	# the drum, the rod leans by the tent.
	check(hand == null or hand.get_child_count() == 0, "the character's hands are empty at camp")
	check(rig.anim != null and rig.anim.is_playing(), "it breathes (idle)")
	check(title.find_child("Settings", true, false) != null, "the settings gear")
	# User report: on the web the camp was silent until a tap - the first
	# time in, it asks for one, and that tap clears it.
	title.tap_to_start()
	var cover: Control = title.find_child("TapToStart", true, false)
	check(cover != null, "the web asks for a tap to start the sound")
	var splash := cover.get_child(0) as TextureRect
	check(splash != null and splash.texture != null, "the loading screen's picture stays up behind 輕觸畫面進入遊戲")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	cover.gui_input.emit(press)
	await seconds(0.3)
	# User report: the tap went through to 出發夜釣 and opened the journey -
	# the cover holds on until the finger's up, and then it's only the camp.
	check(is_instance_valid(cover) and cover.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the cover keeps catching while the finger's down")
	var lift := press.duplicate() as InputEventMouseButton
	lift.pressed = false
	cover.gui_input.emit(lift)
	await seconds(1.2)
	check(not is_instance_valid(cover) and TitleScreen.sound_unlocked, "a tap lets the sound in")
	check(title.get("_page") == null, "the tap only goes into the camp (no page opened under it)")
	# User feedback: the crickets were loud and steady - softer now, and now
	# and then they fade away to nothing and take up again little by little.
	var crickets: CampCrickets = title.find_child("Crickets", true, false)
	check(crickets != null and crickets.playing, "the crickets sing")
	crickets._enter(CampCrickets.State.SING, 0.05)
	await seconds(0.3)
	check(crickets.state == CampCrickets.State.FALL, "they hush now and then")
	crickets._enter(CampCrickets.State.FALL, 0.2)
	await seconds(0.4)
	check(crickets.state == CampCrickets.State.HUSH and crickets.volume_db <= CampCrickets.SILENT_DB + 0.1, "until they can't be heard")
	crickets._enter(CampCrickets.State.HUSH, 0.05)
	await seconds(0.3)
	check(crickets.state == CampCrickets.State.RISE and crickets._span >= CampCrickets.RISE.x
		and crickets.volume_db < CampCrickets.LEVEL_DB - 20.0, "and come back slowly, not all at once")
	crickets._enter(CampCrickets.State.RISE, 0.1)
	await seconds(0.3)
	check(crickets.state == CampCrickets.State.SING and absf(crickets.volume_db - CampCrickets.LEVEL_DB) <= CampCrickets.SWELL_DB + 0.1,
		"to their soft song")
	for want in ["Play", "Multiplayer"]:
		check(title.find_child(want, true, false) != null, "main screen has " + want)
	# The pages are the camp's things: the crate, the backpack, the tent, the
	# trough, the merchant's stall.
	for want in ["warehouse", "equipment", "fish_tank", "shop"]:
		check(camp.hotspots.has(want), "the camp's thing for " + want)
	check(not camp.hotspots.has("bag"), "no bag page of its own")
	# User request: a log tapped, it goes and sits on it.
	camp.life.act_on("sit", 1)
	for _i in 60 * 20:
		await frames(1)
		if camp.life.seated:
			break
	check(camp.life.seated and camp.character_pivot.position.distance_to(camp.spots.seat_1.at) < 0.3, "a log tapped: it sits on it")
	# The frog merchant potters about his stall (user request).
	var frog: CampMerchant = camp.merchant
	# (Not while the character happens to be visiting him: he stands to talk.)
	if frog.visitor != null:
		frog.release()
	var was := frog.position
	frog._wait = 0.0
	await seconds(1.0)
	check(frog.position.distance_to(was) > 0.1 and frog.places.has("inside"), "the frog merchant potters about, now and then inside")
	# The boat moored alongside the dock.
	check(absf(CampStage.BOAT_AT.x - CampStage.DOCK_AT.x) < 1.3, "the boat lies alongside the dock")
	check(title.find_child("CampList", true, false) == null, "no list of pages down the side")
	# User request: nothing over the character's head; the player's card
	# (name and spirit) top left.
	check(title.find_child("Nameplate", true, false) == null, "no nameplate over its head")
	var card: Control = title.find_child("PlayerCard", true, false)
	check(card != null and card.position.x < 40 and card.position.y < 40 and card.find_child("Spirit", true, false) != null,
		"the player's card top left, with the spirit")
	# A tap on the backpack (by the crate) opens the warehouse too - user
	# request: the character goes to it first and rummages in it.
	var pack: Node3D = camp.hotspots.backpack.parts[0][0]
	var at: Vector2 = camp.camera.unproject_position(pack.global_position + Vector3(0, 0.25, 0)) / title.RENDER_SCALE
	check(title.spot_at(at) == "backpack", "the backpack's own thing")
	for down in [true, false]:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = down
		tap.position = at
		title._on_home_input(tap)
	await seconds(0.5)
	check(title._page == null and camp.life._asked, "tapped: the character goes to it first")
	for _i in 60 * 20:
		await frames(1)
		if title._page != null:
			break
	# (at whichever side of it was nearest - CampStage.stand_at)
	var by_pack := Vector2(camp.character_pivot.position.x - pack.global_position.x, camp.character_pivot.position.z - pack.global_position.z).length()
	check(by_pack < 1.3 and camp.clearance(camp.character_pivot.position) > 0.0,
		"and gets down at the backpack (%s, %.2f m off it)" % [camp.character_pivot.position, by_pack])
	# (its name popped up as it came near)
	check(title._near == "backpack" or title._near == "warehouse" or not title._home.visible, "the name of what it's near")
	await seconds(0.8)
	var bag_page: Control = title._page
	check(bag_page != null and bag_page.find_child("WarehouseWindow", true, false) != null, "then the warehouse opens")
	UiKit.page_back(bag_page)
	await seconds(1.0)
	# A page opens over the camp (the camera glides to its spot) and closes
	# back to it.
	title.open_page("shop")
	await seconds(1.0)
	var page: Control = title._page
	check(page != null and page.get_meta("camp", null) == title and not title._home.visible, "the shop opens over the camp")
	var spot: Array = CampStage.STATIONS.shop
	check(camp.camera.position.distance_to(spot[0]) < 0.05, "the camera went to the stall")
	UiKit.page_back(page)
	await seconds(1.0)
	check(title._page == null and title._home.visible, "back to the camp")
	title.queue_free()
	await frames(1)

	var equip: Control = load("res://scenes/equipment.tscn").instantiate()
	get_tree().root.add_child(equip)
	await frames(3)
	for key in ["rod", "light", "hat", "top", "pack"]:
		check(equip.find_child("Slot_" + key, true, false) != null, "equipment slot " + key)
	check(equip.find_child("Storage", true, false) != null and equip.find_child("Bag", true, false) != null,
		"the equipment page shows the warehouse's gear and the bag")
	equip.queue_free()
	await frames(1)

	var book: Control = load("res://scenes/fish_log.tscn").instantiate()
	get_tree().root.add_child(book)
	await frames(2)
	var cells := book.find_children("Fish_*", "Button", true, false)
	check(cells.size() == FishData.FISH.size(), "the fish log shows every species (%d)" % cells.size())
	book._card("golden_koi", {"count": 1, "best_value": 30.0})
	await frames(1)
	var turn: ItemPreview = book.find_child("Preview", true, false)
	check(turn != null and turn._fish != null, "a caught fish's card turns it in 3D")
	book.queue_free()
	await frames(1)


## User request (Camp v2): the merchant's tea and food lift the spirit
## there and then; the tents are earned by achievements (escapes, gold
## spent, the fish log, a legend) and pitched from the equipment page's
## 營地 tab, and the camp's tent changes with it.
func test_camp_spirit_and_tents() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 100, "spirit": 50.0})
	check(Profile.buy_snack("tea") and is_equal_approx(Profile.spirit, 70.0) and Profile.gold == 85, "tea: +20 spirit for 15 gold")
	check(Profile.buy_snack("loaf") and is_equal_approx(Profile.spirit, 100.0) and Profile.gold == 50, "a loaf: up to full")
	check(not Profile.buy_snack("tea") and Profile.gold == 50, "nothing bought when the spirit's full")
	check(int(Profile.stats.gold_spent) == 50, "what's spent is counted (%d)" % int(Profile.stats.gold_spent))
	var loaded := Profile.snapshot()
	Profile.load_data(loaded)
	check(is_equal_approx(Profile.spirit, 100.0) and int(Profile.stats.gold_spent) == 50, "spirit and stats saved")
	# The shop sells them, on its 道具 tab.
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await frames(2)
	shop._show_tab("item")
	await frames(1)
	check(shop.find_child("Card_tea", true, false) != null and shop.find_child("Card_loaf", true, false) != null,
		"the merchant sells tea and bread")
	check(shop.find_child("Card_rations", true, false) == null, "and no more rations (user request)")
	Profile.add_spirit(-40.0)
	(shop.find_child("Card_tea", true, false) as Button).pressed.emit()
	await frames(1)
	var have: Button = shop.find_child("Have", true, false)
	check(have != null, "a lowered spirit can have tea")
	if have != null:
		have.pressed.emit()
		await frames(1)
	check(is_equal_approx(Profile.spirit, 80.0) and Profile.gold == 35, "had at once (spirit %d)" % Profile.spirit)
	shop.queue_free()
	await frames(1)

	# Tents: the lean-to to start; the rest earned.
	check(Profile.camp_tent == 8 and Profile.tent_unlocked(8), "the stick lean-to to start")
	check(not Profile.tent_unlocked(9) and not Profile.pitch_tent(9) and Profile.camp_tent == 8, "a tent not earned can't be pitched")
	for _i in 10:
		Profile.record_escape()
	check(Profile.tent_unlocked(9) and Profile.pitch_tent(9) and Profile.camp_tent == 9, "ten escapes earn the woven hut")
	check(not Profile.tent_unlocked(2), "no legend yet")
	Profile.record_catch("測試魚", 1.0, 10.0, "", true)
	check(Profile.tent_unlocked(2), "a legend earns the bearskin tent")
	Profile.fish_log.clear()
	var ids: Array = FishData.FISH.keys()
	for i in ceili(ids.size() * 0.2):
		Profile.fish_log[FishData.FISH[ids[i]].name] = {"count": 1, "best_value": 1.0}
	check(Profile.log_percent() >= 20.0 and Profile.tent_unlocked(7) and not Profile.tent_unlocked(1), "a fifth of the log earns tent 7, not tent 1")

	# The equipment page's 營地 tab, over the camp: tap a tent to pitch it.
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	var camp: CampStage = title.find_child("Camp", true, false)
	title.open_page("equipment")
	await seconds(0.8)
	var page: Control = title._page
	page._show_tab("camp")
	await frames(1)
	check(page.find_child("CampWindow", true, false).visible and not page.find_child("Storage", true, false).is_visible_in_tree(),
		"the 營地 tab shows the tents instead of the warehouse")
	var cards := page.find_children("Tent_*", "", true, false)
	check(cards.size() == Profile.TENTS.size(), "every tent on the tab (%d)" % cards.size())
	page._on_tent(Profile.TENTS.map(func(t): return t[0]).find(2))
	await frames(1)
	check(Profile.camp_tent == 2, "tapping an earned tent pitches it")
	check(camp.find_child("tent_2", true, false) != null and camp.find_child("tent_9", true, false) == null,
		"the camp's tent changes with it")
	check(camp.hotspots.has("equipment"), "and it still opens the equipment")
	page._on_tent(Profile.TENTS.map(func(t): return t[0]).find(4))
	check(Profile.camp_tent == 2 and "還沒解鎖" in page._tent_note.text, "a locked one says what it needs")
	title.queue_free()
	await frames(1)
	Profile.load_data(saved)
	Profile._save()


## User request: the ears (the owl's tufts) and tails move on their own -
## on the camp's 3D character (its ear and tail bones, EarTailSway) and on
## the game's sprite (PlayerVisual's lines for the shader to turn).
func test_ears_and_tails() -> void:
	var rig := CharacterRig.new()
	rig.hold_gear = false
	add_child(rig)
	rig.set_character("cat")
	await frames(3)
	var sway: EarTailSway = rig.skeleton.get_node("EarTailSway")
	await frames(2)
	var kinds := sway.chains.map(func(c): return c.kind)
	check(kinds.count("ear") == 2 and kinds.count("tail") == 1, "the cat's two ears and its tail (%s)" % [kinds])
	var ear: Dictionary = sway.chains[kinds.find("ear")]
	ear.next = sway._time
	sway._schedule(ear)
	sway._time += 0.08
	check(absf(sway._angle(ear, 0, ear.bones.size())) > 3.0, "an ear flicks (%.1f deg)" % sway._angle(ear, 0, ear.bones.size()))
	sway._time += 1.0
	sway._schedule(ear)
	check(ear.at < 0.0 or sway._time - ear.at < EarTailSway.EAR_TIME, "and settles")
	# User request: they go with its steps too - set off, they swing back.
	check(sway.follow_steps, "the ears and tail follow its steps")
	var most := 0.0
	for i in 20:
		rig.position.z += 0.004 * i
		await frames(1)
		most = maxf(most, sway._lag.length())
	check(most > 2.0, "setting off swings them (%.1f deg)" % most)
	rig.queue_free()
	# In the game: the sheet's ear and tail lines, turned now and then.
	var body: PlayerVisual = player().get_node("Body")
	check(body._data.has("sway") and not body._data.get("sway_names", []).is_empty(), "the sheet has its ears' lines (%s)" % [body._data.get("sway_names", [])])
	await frames(2)
	check(not body._sway_lines.is_empty(), "the shader is given them")
	for s in body._sway:
		s.next = body._sway_time
	await frames(4)
	var turned := false
	for t in body._sway_turns:
		turned = turned or absf(t) > 0.01
	check(turned, "and one turns (%s)" % [body._sway_turns])
	check(body.material is ShaderMaterial and body.material.get_shader_parameter("sway_count") == body._sway_lines.size(), "the body's shader has them")


## User request (Camp v2): the character lives at the camp by its spirit -
## busy (all of it - no dancing, user request), tired, worn (mostly sitting), spent
## (only sitting); waves (nods, shakes its head) when tapped; holds still
## under a page; sets out with the lamp and the rod into the 渡石, comes
## home out of it, or wakes by the fire.
func test_camp_life() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 100, "spirit": 95.0})
	var title: Control = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	var camp: CampStage = title.find_child("Camp", true, false)
	var life: CampLife = camp.life
	check(life != null and CampLife.tier() == 3, "the camp has a life; at 95 it's busy")
	# What it picks, by how it feels.
	var allowed := {
		0: ["sit"], 1: ["sit", "fire", "nap", "ground", "trough", "stand"],
		2: ["sit", "fire", "nap", "ground", "crate", "trough", "lean", "lake", "look", "stretch", "merchant", "watch", "stand"],
	}
	for spirit in [20.0, 40.0, 60.0]:
		Profile.spirit = spirit
		var t := CampLife.tier()
		var seen := {}
		life.seated = false
		for _i in 120:
			life._choose()
			seen[life.activity] = true
		var stray: Array = seen.keys().filter(func(k): return not k in allowed[t])
		check(stray.is_empty(), "spirit %d picks only what it can (%s)" % [spirit, ", ".join(stray)])
	# Too short for the drum (its lid at their chin): never leans on it.
	var was_char := camp.character.character
	camp.set_character("cat")
	var leant := false
	for _i in 200:
		life._choose()
		leant = leant or life.activity == "lean"
	check(not leant, "the cat never leans on the drum (it'd go into it)")
	camp.set_character(was_char)
	Profile.spirit = 95.0
	var busy := {}
	for _i in 400:
		life._choose()
		busy[life.activity] = int(busy.get(life.activity, 0)) + 1
	check(busy.has("sit") and busy.has("tent"), "busy, it mends and sits (%s)" % ", ".join(busy.keys()))
	# User request: not forever on the go - mostly stood at the fire or sat
	# on a log, a good while each.
	var calm: int = int(busy.get("sit", 0)) + int(busy.get("fire", 0))
	check(calm > 400 * 0.6, "mostly at the fire or on the log (%d of 400)" % calm)
	var at_fire: Array = life._activity("fire", 3)
	check(at_fire[-1].get("do", "") == "loop" and float(at_fire[-1].time) >= CampLife.FIRE_TIME[3].x,
		"stood at the fire a good while (%.0f s)" % float(at_fire[-1].time))
	# Nothing meant for another while it's on its own (the merchant aside:
	# he's there), no drink it wasn't bought, and lying down only in the
	# tent.
	var lone := {}
	for t in 4:
		for _i in 40:
			for n in CampLife.WEIGHTS:
				if n == "merchant":
					continue
				for st in life._activity(n, t):
					if str(st.get("clip", "")) in ["Sitting_Talking", "Seat_Clap", "Clap", "Wave", "Wave_Big", "Beckon", "Idle_Talking", "Seat_Drink", "Drink"]:
						lone[n + ":" + str(st.clip)] = true
	check(lone.is_empty(), "on its own: no clap, no talk, no wave, no drink (%s)" % ", ".join(lone.keys()))
	var nap: Array = life._activity("nap", 1)
	var nap_clips: Array = nap.filter(func(st): return st.has("clip")).map(func(st): return st.clip)
	check(nap_clips == ["Lie_Down", "Lying", "Sleep_B", "Lying", "LayToIdle"], "a nap: down, asleep, up (%s)" % ", ".join(nap_clips))
	var lie_at := Vector3.INF
	for st in nap:
		if st.get("straight", false):
			lie_at = st.to
			break
	check(lie_at.distance_to(CampStage.TENT_AT) < 0.6, "it naps in the tent (%.2f m from its middle)" % lie_at.distance_to(CampStage.TENT_AT))
	check(not busy.has("chop") and not busy.has("gather") and not busy.has("dance"), "no chopping, carrying or dancing (dropped)")
	# Its ways round the camp keep off the fire.
	var path := camp.route(camp.spots.home.at, camp.spots.stone.at)
	var clear := true
	var from: Vector3 = camp.spots.home.at
	for p in path:
		for k in 10:
			var q: Vector3 = from.lerp(p, k / 10.0)
			if Vector2(q.x - CampStage.FIRE_AT.x, q.z - CampStage.FIRE_AT.z).length() < 0.7:
				clear = false
		from = p
	check(clear and path.size() >= 2, "the way to the stone goes round the fire (%d points)" % path.size())
	# User request: never through anything on the ground - every way between
	# the camp's spots keeps off the logs, drums, crate, trough, tent...
	var through := 0
	for na in camp.spots:
		for nb in camp.spots:
			if na == nb:
				continue
			var a: Vector3 = camp.spots[na].at
			var b: Vector3 = camp.spots[nb].at
			var prev := a
			for p in camp.route(a, b):
				var n := int(prev.distance_to(p) / 0.1)
				for k in range(1, n):
					var q: Vector3 = prev.lerp(p, float(k) / n)
					for o in camp.obstacles:
						if CampStage._to_segment(q, o[0], o[1]) < o[2] - 0.02 \
								and CampStage._to_segment(a, o[0], o[1]) >= o[2] and CampStage._to_segment(b, o[0], o[1]) >= o[2]:
							through += 1
				prev = p
	check(through == 0, "no way between the spots goes through anything (%d)" % through)
	var wild: CampWildlife = camp.find_child("Wildlife", true, false)
	check(wild != null and not wild.walking() and wild.path.size() >= 2, "an animal now and then on the far bank (none at first)")
	wild.start("deer")
	check(wild.walking(), "one sets off")
	# User request: no taps on it - a tap on the character leaves it be.
	life._plan.clear()
	life._step = {}
	life.seated = false
	life.pivot.position = camp.spots.home.at
	life.pivot.rotation.y = 0.0
	life._plan = [{"do": "loop", "clip": "Idle", "time": 30.0}]
	life._next()
	await frames(2)
	var on_it: Vector2 = camp.camera.unproject_position(life.pivot.global_position + Vector3(0, 0.7, 0)) / title.RENDER_SCALE
	check(title._near_character(on_it), "(the tap is on it)")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = on_it
	title._on_home_input(press)
	var let_go := press.duplicate() as InputEventMouseButton
	let_go.pressed = false
	title._on_home_input(let_go)
	await frames(2)
	check(life._step.get("clip", "") == "Idle" and life._plan.is_empty() and life.pivot.rotation.y == 0.0,
		"a tap on the character: it carries on as it was")
	life.pivot.position = camp.spots.lean.at
	# Standing about somewhere tight (by the drum), it steps out first too.
	check(life._activity("stand", 3)[0].get("do", "") == "walk" and life._activity("stretch", 3)[0].get("do", "") == "walk",
		"standing about or stretching by the drum: out from it first")
	life.pivot.position = camp.spots.home.at
	check(life._activity("stand", 3)[0].get("do", "") == "loop", "with room round it, just where it is")
	life._plan.clear()
	life._step = {}
	# User request: a drag swipes the view left and right - the character
	# isn't spun round by it any more.
	var yaw_was := life.pivot.rotation.y
	var swipe := InputEventMouseButton.new()
	swipe.button_index = MOUSE_BUTTON_LEFT
	swipe.pressed = true
	swipe.position = Vector2(700, 420)
	title._on_home_input(swipe)
	for k in 10:
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(700 - k * 12, 420)
		mv.relative = Vector2(-12, 0)
		title._on_home_input(mv)
	var up := swipe.duplicate() as InputEventMouseButton
	up.pressed = false
	title._on_home_input(up)
	await frames(30)
	check(camp.view_pan > 1.0 and absf(life.pivot.rotation.y - yaw_was) < 0.001 and camp.camera.global_position.x > CampStage.STATIONS.home[0].x + 0.8,
		"a swipe to the left moves the view right (%.2f m), the character not turned" % camp.view_pan)
	camp.pan_view(-10.0)
	check(is_equal_approx(camp.view_pan, CampStage.PAN_RANGE.x), "as far as the camp goes")
	# User request: the 渡石 out on the left - swiped to it, it's there,
	# and a tap on it is 出發夜釣 (the journey page).
	camp.view_pan = CampStage.PAN_RANGE.x
	await frames(90)
	var stone_px: Vector2 = camp.camera.unproject_position(CampStage.STONE_AT + Vector3(0, 0.8, 0))
	check(Rect2(Vector2.ZERO, Vector2(camp.get_viewport().size)).has_point(stone_px) and camp.hotspot_at(stone_px) == "journey",
		"swiped left, the 渡石 is in view and tappable (%s)" % stone_px)
	var on_stone := InputEventMouseButton.new()
	on_stone.button_index = MOUSE_BUTTON_LEFT
	on_stone.pressed = true
	on_stone.position = stone_px / title.RENDER_SCALE
	title._on_home_input(on_stone)
	var off_stone := on_stone.duplicate() as InputEventMouseButton
	off_stone.pressed = false
	title._on_home_input(off_stone)
	# (user request: it walks over and lays a hand on the stone first)
	for _i in 60 * 25:
		await frames(1)
		if title._page != null:
			break
	check(title._page != null and title._page.name.to_lower().contains("journey"), "a tap on it opens the journey (出發夜釣)")
	UiKit.page_back(title._page)
	await seconds(0.8)
	camp.view_pan = 0.0
	# User request: lying down only in the tent - in under it, down, asleep,
	# up and out.
	Profile.spirit = 40.0
	life._plan.clear()
	life._step = {}
	life.seated = false
	life.down = ""
	life.pivot.position = camp.spots.tent.at
	life._plan = life._activity("nap", 1)
	life._next()
	var lay := false
	for _i in 900:
		await frames(1)
		if life.rig.anim.assigned_animation == "Lying":
			lay = true
			break
	check(lay and life.down == "LayToIdle" and life.pivot.position.distance_to(camp.spots.bed.at) < 0.05, "it lies down in the tent")
	life._plan.clear()
	life._step = {}
	life.down = ""
	# The merchant's tea bought: sat on the log, a cup of it; his food: a
	# bite at the fire.
	Profile.spirit = 60.0
	Profile.gold = 500
	life.pivot.position = camp.spots.home.at
	title.open_page("shop")
	await frames(2)
	check(Profile.buy_snack("tea") and life.treat_due == "tea", "tea bought at the merchant's")
	UiKit.page_back(title._page)
	await seconds(0.8)
	var tea: Array = [life._step] + life._plan
	check(life.activity == "tea" and tea.any(func(st): return st.get("clip", "") == "Seat_Drink"), "back at the camp it sits and has its tea")
	life._plan.clear()
	life._step = {}
	life.seated = false
	Profile.spirit = 60.0
	life.treat("roll")
	var food: Array = life._choose()
	check(food.any(func(st): return st.get("clip", "") == "Consume") and not food.any(func(st): return st.get("clip", "") == "Seat_Drink"),
		"food: a bite at the fire")
	life._plan.clear()
	life._step = {}
	# Sat on the ground by the fire; worn out, head down where it stands.
	var ground: Array = life._activity("ground", 2)
	check(ground.any(func(st): return st.get("clip", "") == "Ground_Stand" and st.get("back", false))
		and ground.any(func(st): return st.get("clip", "") == "Ground_Sit"), "it sits on the ground by the fire")
	Profile.spirit = 40.0
	life.pivot.position = camp.spots.home.at
	check(life._idle() == "Sad" and life._activity("stand", 1)[0].get("clip", "") in ["Sad", "Sad_B"], "worn out, it stands low")
	Profile.spirit = 80.0
	check(life._idle() == "Idle", "in good spirits, at ease")
	# Every clip it plays is in the model.
	var unknown := {}
	for t in 4:
		for _i in 30:
			for n in CampLife.WEIGHTS:
				for st in life._activity(n, t):
					if st.has("clip") and not life.rig.anim.has_animation(st.clip):
						unknown[st.clip] = true
	check(unknown.is_empty(), "every clip it plays, the model has (%s)" % ", ".join(unknown.keys()))
	life._plan.clear()
	life._step = {}
	Profile.spirit = 10.0
	# Spent, it sits and stays sat.
	life._plan.clear()
	life._step = {}
	life.sit_now()
	for _i in 6:
		life._plan = life._choose()
		check(life.activity == "sit" and not life._plan.any(func(st): return st.get("clip", "") == "Sitting_Exit"),
			"spent, it never gets up")
	# A word with the frog merchant: he stops for it, they face each other,
	# he talks back, then goes on his way.
	Profile.spirit = 80.0
	life._plan = life._activity("merchant", 3)
	life._step = {}
	life._next()
	var frog: CampMerchant = camp.merchant
	check(frog.visitor == life.pivot, "the merchant stops for the visit")
	var talked := false
	for _i in 1500:
		await frames(1)
		if frog._anim != null and frog._anim.current_animation == "Talk":
			talked = true
			break
	var gap := frog.global_position - life.pivot.position
	gap.y = 0.0
	var facing := Vector3(sin(life.pivot.rotation.y), 0, cos(life.pivot.rotation.y))
	check(talked and gap.length() < 2.0 and facing.dot(gap.normalized()) > 0.9,
		"it walks up to him, face to face, and he talks (%.2f m, talked %s, facing %.2f)" % [gap.length(), talked, facing.dot(gap.normalized())])
	for _i in 900:
		await frames(1)
		if frog.visitor == null:
			break
	check(frog.visitor == null, "and he goes on his way after")
	# A page: it holds still.
	title.open_page("shop")
	await frames(2)
	check(life.paused, "it holds still under a page")
	UiKit.page_back(title._page)
	await seconds(0.8)
	check(not life.paused, "and carries on after")
	# Setting out (user request): no going for the lamp - it stays on the
	# drum (picked up out in the night, the run's opening); off at once.
	Profile.spirit = 80.0
	title._setting_off = true
	var done := {"gone": false}
	life.plan_done.connect(func(tag): done.gone = done.gone or tag == "depart")
	title._on_solo()
	check(life.busy == "depart" and title._scene_piece == "depart", "出發夜釣 sets it off")
	for _i in 240:
		if done.gone:
			break
		await frames(1)
	check(done.gone, "off it goes at once, up off a log first if sat (the game fades in)")
	var lamp: Node3D = camp.find_child("DrumLamp", true, false)
	await seconds(1.0)
	check(lamp.visible and camp.character.attachments.hand_l.get_child_count() == 0, "the lamp left on the drum")
	check(life._step.get("do", "") == "walk", "walking off to the 渡石")
	check(camp.find_child("Rod", true, false).visible and camp.character.attachments.hand_r.get_child_count() == 0,
		"the rod stays by the tent")
	title.queue_free()
	await frames(1)

	# Home again, escaped: out of the stone with the lamp; a tap skips to it
	# put away.
	GameState.last_return = "escaped"
	title = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	camp = title.find_child("Camp", true, false)
	life = camp.life
	check(GameState.last_return == "" and life.busy == "home", "back from a run escaped, it comes home")
	check(not camp.find_child("DrumLamp", true, false).visible and camp.character.attachments.hand_l.get_child_count() == 1,
		"lamp in hand")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(480, 300)
	title._on_home_input(down)
	title._on_home_input(down)
	await frames(2)
	check(life.busy == "" and title._scene_piece == "" and camp.find_child("DrumLamp", true, false).visible
		and camp.character.attachments.hand_l.get_child_count() == 0, "a tap skips to the lamp on the drum")
	# And straight out again.
	title._setting_off = true
	title._on_solo()
	check(life.busy == "depart" and life.plan_done.get_connections().size() == 1, "sets out again (one listener)")
	title.queue_free()
	await frames(1)
	# Lost: it wakes by the fire, gets up.
	GameState.last_return = "lost"
	title = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await frames(3)
	life = (title.find_child("Camp", true, false) as CampStage).life
	check(life.busy == "wake" and life.rig.anim.assigned_animation == "LayToIdle"
		and life.pivot.position.distance_to(CampStage.TENT_AT) < 0.6, "back from a run lost, it wakes in the tent")
	check(life._plan.any(func(st): return st.get("clip", "") == "Disappointed"), "and sighs, getting up")
	await seconds(16.0)
	check(life.busy == "" and title._scene_piece == "", "and gets up")
	title.queue_free()
	await frames(1)
	# Resting at the camp: a point a minute.
	Profile.spirit = 50.0
	Profile._rest_time = 0.0
	Profile.rest(59.0)
	check(is_equal_approx(Profile.spirit, 50.0), "not before the minute's up")
	Profile.rest(1.5)
	check(is_equal_approx(Profile.spirit, 51.0), "a point of spirit for a minute's rest")
	# Away with the game closed: the camp's minutes still count.
	Profile.camp_since = Time.get_unix_time_from_system() - 10.0 * 60.0 - 5.0
	Profile.arrive_at_camp()
	check(is_equal_approx(Profile.spirit, 61.0), "ten minutes away at the camp: +10 (%d)" % Profile.spirit)
	Profile.leave_camp()
	check(Profile.camp_since == 0.0, "out on a run, the camp's clock stops")
	# Low spirit tells: bag rows, pace, the strike window.
	Profile.spirit = 40.0
	check(Profile.bag_rows() == Inventory.ROWS - 2 and Profile.SPIRIT_SPEED[Profile.spirit_penalty()] == 0.8,
		"at 40: two bag rows shut, 80% pace")
	Profile.spirit = 20.0
	check(Profile.bag_rows() == Inventory.ROWS - 3 and Profile.SPIRIT_WINDOW[Profile.spirit_penalty()] == 0.7,
		"at 20: three rows shut, 70% of the strike window")
	check(not Profile.bag_fits("battery", Vector2i(0, Inventory.ROWS - 1)), "nothing new goes in a shut row")
	Profile.load_data(saved)
	Profile._save()


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
	await seconds(Lantern.RELIGHT_DURATION * 0.5)
	# (user request: no ring on the screen - the progress is a bar in the
	# fuel box)
	check(not tc._ring.visible and lantern.relight_progress > 0.2, "relighting: no ring, the bar in the fuel box (%.2f)" % lantern.relight_progress)
	await seconds(Lantern.RELIGHT_DURATION * 0.5 + 0.3)
	check(lantern.lit, "held, the lamp relights")
	var up := InputEventScreenTouch.new()
	up.index = 4
	up.position = tc._skill_center
	up.pressed = false
	tc._input(up)
	await frames(2)
	check(lantern.lit and not Input.is_key_pressed(KEY_L), "letting go leaves it lit")
	tc.visible = false


## User request: the lamp's brightness isn't set by hand - a long press on
## an empty spot only relights it; no slider comes up.
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
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.position = spot
	down.pressed = true
	tc._input(down)
	await seconds(0.6)
	check(not tc._slider.visible, "no brightness slider")
	var lantern: Lantern = player().get_node("Lantern")
	var before := lantern.brightness
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = spot + Vector2(0, -40)
	tc._input(drag)
	check(lantern.brightness == before and lantern.lit, "sliding doesn't change it")
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.position = spot
	up.pressed = false
	tc._input(up)
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
	# User request: what happens on the run, in a few words under the card.
	card.feed.clear()
	player()._fail_catch("bait_nibbled")
	check(not card.feed.is_empty() and card.feed[0][0] == "餌被小魚偷吃了", "a nibbled-off bait shows under the card")
	player()._fail_catch("no_bite")
	player().animal_attack("狼")
	check(card.feed.size() == 3 and card.feed[0][0].begins_with("狼撲上來"), "a wolf attack, newest on top")
	player().animal_attack("狼")
	gs.report("小鬼偷走了餌")
	check(card.feed.size() == StatusCard.FEED_LINES, "three lines at most")
	var count := card.feed.size()
	gs.report("小鬼偷走了餌")
	check(card.feed.size() == count and card.feed[0][0] == "小鬼偷走了餌", "the same again refreshes its line")
	await seconds(StatusCard.FEED_LIFE + StatusCard.FEED_FADE + 0.3)
	check(card.feed.is_empty(), "and they fade away")


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
	# User report: a thing in the bag's bottom row - its card ran off the
	# screen, 使用 out of reach. Its card stays on the screen, buttons and all.
	bag.toggle()
	gs.carried_fish.clear()
	Profile.storage["eyeball"] = 1
	Profile.to_bag("eyeball", 1)
	bag.toggle()
	var eye := {}
	for it in Inventory.items(p):
		if it.kind == "use" and it.item == "eyeball":
			eye = it
	bag._selected = {"kind": eye.kind, "index": eye.index}
	bag._rebuild()
	bag._place_card(Rect2(Vector2(420, 488), Vector2(48, 48)))
	await frames(3)
	var card: Control = bag._card
	var use_button: Control = null
	for b in card.find_children("*", "Button", true, false):
		if (b as Button).text == "使用":
			use_button = b
	check(use_button != null and card.get_global_rect().end.y <= 540.0
		and Rect2(0, 0, 960, 540).encloses(use_button.get_global_rect()),
		"a bottom-row thing's card on the screen, 使用 in reach (%s)" % str(card.get_global_rect()))
	await seconds(1.0)
	check(use_button != null and is_instance_valid(use_button) and use_button.is_inside_tree(),
		"its buttons not swapped under the finger by the bag's refresh")
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


# --- the campaign (docs/CAMPAIGN.md) ------------------------------------------

## User request: levels from a small map to the full one - every level's map
## comes out as its rules say: its size, its ponds, its look, its quota and
## day, which threats are in it.
func test_campaign_levels_build() -> void:
	for l in camp().LEVELS:
		var r: Dictionary = camp().rules_for(l.id)
		await play_level(l.id)
		var size: Vector2 = (camp().MAP_SIZES[r.map] * RunView3D.MAP_SCALE).round()
		check(is_equal_approx(Player.WORLD_WIDTH, size.x) and is_equal_approx(Player.WORLD_HEIGHT, size.y),
			"%s: the %s map" % [l.id, r.map])
		var gen: MapGenerator = main.get_node("MapGenerator")
		check(gen.theme_name == MapGenerator.THEME, "%s: the forest (%s)" % [l.id, gen.theme_name])
		var rare := get_tree().get_nodes_in_group("water_zones_rare").size()
		var common := get_tree().get_nodes_in_group("water_zones_common").size()
		check(rare == int(r.ponds[1]), "%s: %d dark pond(s), got %d" % [l.id, int(r.ponds[1]), rare])
		if not gen.theme.get("sea", false) and int(r.ponds[0]) >= 0:
			check(common == int(r.ponds[0]), "%s: %d pond(s), got %d" % [l.id, int(r.ponds[0]), common])
		check(gs.quota_target == float(r.quota) and is_equal_approx(gs.day_duration, float(r.day) * gs.DAY_PACE), "%s: quota and day" % l.id)
		var big: Node = main.get_node("BigGhost")
		check((big.process_mode != Node.PROCESS_MODE_DISABLED) == r.big_ghost, "%s: the big ghost %s" % [l.id, "in" if r.big_ghost else "out"])
		var floating := get_tree().get_nodes_in_group("ghosts").filter(func(g): return not g is BigGhost).size()
		check(floating == int(r.ghosts), "%s: %d floating ghost(s), got %d" % [l.id, int(r.ghosts), floating])
		if not r.hunters:
			check(get_tree().get_nodes_in_group("hunters").is_empty(), "%s: no beasts" % l.id)
		# The start, the altar, the stones and the camp on dry land inside the map.
		for n in ["Player", "Altar", "EscapePoint", "FuelStation"]:
			var p: Vector2 = main.get_node(n).global_position
			check(Rect2(0, 0, size.x, size.y).has_point(p) and Ripple.water_at(get_tree(), p) == null,
				"%s: %s on dry land in the map" % [l.id, n])
		var hud: CampaignHud = null
		for c in main.get_children():
			if c is CampaignHud:
				hud = c
		check(hud != null and (str(r.tutorial) == "" or hud.steps.size() > 0), "%s: objectives and tutorial up" % l.id)


## The first level end to end: the tutorial follows along, the run scores
## its stars and its reward, and the next level opens.
func test_campaign_level_one() -> void:
	reset_progress()
	await play_level("1-1")
	var hud: CampaignHud = null
	for c in main.get_children():
		if c is CampaignHud:
			hud = c
	check(hud != null and hud.step == 0, "the tutorial starts at its first line")
	check(Player.WORLD_WIDTH < 1400.0 * RunView3D.MAP_SCALE and gs.day_duration == 0.0, "a small map with no clock")
	await put(get_tree().get_nodes_in_group("water_zones_common")[0].shore_point(Vector2.DOWN) + Vector2(0, 14))
	await seconds(1.6)
	check(hud.step >= 1, "walking to the water moves the tutorial on")
	var gold: int = Profile.gold
	player().cast_started.emit(player().global_position, "near")
	player().hook_success.emit()
	var f := fish()
	player().catch_success.emit(f)
	gs.add_carried_fish(f)
	check(camp().value("catch") == 1.0, "the catch is counted")
	gs.sacrifice_at(0)
	await frames(2)
	check(gs.day_phase == gs.DayPhase.ESCAPE, "one fish meets the quota")
	gs.escape()
	await frames(3)
	var res: Dictionary = camp().result
	check(res.success and res.stars == [true, true, true], "all three stars (%s)" % str(res.get("stars")))
	check(Profile.level_stars("1-1") == [true, true, true], "the stars are kept")
	check(camp().level_open("1-2") and not camp().level_open("1-3"), "1-2 opens, 1-3 doesn't yet")
	check(Profile.gold == gold + 40 + 3 * camp().STAR_GOLD + 30, "first clear, new stars and the achievement paid (%d)" % (Profile.gold - gold))
	check(Profile.has_achievement("first_crossing"), "初渡 earned")
	var results: Node = main.find_child("CampaignResults", true, false)
	check(results != null and results.find_child("Next", true, false) != null, "the results screen, with 下一關")
	# Again, slower and with a fish lost: nothing more to win.
	await play_level("1-1")
	player().catch_failed.emit("line_break")
	check(not camp().condition_met(camp().level("1-1").stars[0]), "a lost fish loses ★★ this time")
	gs.add_carried_fish(fish())
	gs.sacrifice_at(0)
	gold = Profile.gold
	gs.escape()
	await frames(2)
	check(Profile.gold == gold and Profile.level_stars("1-1") == [true, true, true], "stars already won stay won, no gold twice")


## A level with nothing deadly at night ends at nightfall - and the first
## chapter's are safe: nothing found is lost.
func test_campaign_night_ends_safe_level() -> void:
	reset_progress()
	await play_level("1-4")
	var found := {"id": "battery", "count": 1, "cell": Vector2i(-9, -9), "found": true}
	Profile.bag.append(found)
	gs.time_remaining = 0.5
	await seconds(1.0)
	check(gs.run_over and not camp().result.success, "nightfall ends the run")
	check(found in Profile.bag, "safe: the found battery is kept")
	Profile.bag.erase(found)
	check(camp().stars_earned(false) == [false, false, false], "no stars for a lost run")


## After the last chapter: curses on the free run.
func test_campaign_curses() -> void:
	camp().begin_free(["rush", "greed", "horde", "early"])
	gs.last_return = ""
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	await frames(3)
	check(is_equal_approx(gs.quota_target, 45.0) and is_equal_approx(gs.day_duration, 180.0 * gs.DAY_PACE), "貪念 and 急潮")
	var floating := get_tree().get_nodes_in_group("ghosts").filter(func(g): return not g is BigGhost).size()
	check(floating == 3, "群鬼: three floating ghosts (%d)" % floating)
	await frames(2)
	check(main.get_node("BigGhost").mode != BigGhost.Mode.ASLEEP, "早醒: the big ghost's up from the start")
	check(Player.WORLD_WIDTH == roundf(2400.0 * RunView3D.MAP_SCALE), "the free run's full map")
	gs.quota_progress = 50.0
	gs._enter_escape_phase()
	var gold: int = Profile.gold
	gs.escape()
	await frames(2)
	check(int(camp().result.curse_gold) == int(roundf(50.0 * 1.05)) and Profile.gold >= gold + int(camp().result.curse_gold),
		"the curses pay on the way out (%d)" % int(camp().result.curse_gold))


## Chapters open in order and on stars; achievements count across runs.
func test_campaign_unlocks_and_achievements() -> void:
	reset_progress()
	check(camp().level_open("1-1") and not camp().level_open("1-2") and not camp().chapter_open(2), "only 1-1 to begin with")
	for id in ["1-1", "1-2", "1-3", "1-4", "1-5"]:
		Profile.record_level(id, [true, true, false], 100.0)
	check(camp().chapter_open(2) and camp().level_open("2-1") and not camp().level_open("2-2"), "chapter 2 after 1-5")
	check(camp().free_open(), "the free run after chapter 1")
	for id in ["2-1", "2-2", "2-3", "2-4"]:
		Profile.record_level(id, [true, false, false], 100.0)
	check(not camp().chapter_open(3), "chapter 3 waits for 2-5")
	Profile.record_level("2-5", [true, false, false], 100.0)
	check(camp().stars_total() == 15 and camp().chapter_open(3), "chapter 3 at 10 stars or more (15)")
	check(not camp().chapter_open(4), "chapter 4 needs chapter 3")
	check(camp().danger(camp().rules_for("1-1")) == 0 and camp().danger(camp().rules_for("5-5")) == 5, "danger from none to the most")
	Profile.add_records({"catch": 99.0})
	check(not camp().achievement_done(camp().achievement("catch_100")), "99 fish isn't 百尾")
	Profile.add_records({"catch": 1.0})
	var got: Array = camp().check_achievements()
	check("catch_100" in got and Profile.has_achievement("catch_100"), "百尾 at 100")
	check(not "catch_100" in camp().check_achievements(), "and only once")


## User request: the lakeside forest as a whole run in 3D (RunView3D) -
## the same run, shown in 3D: the map's things where the map put them, the
## traveller acting out the 2D one's clips, fishing and all.
func test_run_3d() -> void:
	await _fresh_game()
	var view: RunView3D = null
	for _i in 120:
		view = RunView3D.active
		if view != null and view.built:
			break
		await frames(1)
	check(view != null and view.built and main.get_node("MapGenerator").theme_name == RunView3D.THEME,
		"set off in 3D: the lakeside forest, shown in 3D")
	if view == null or not view.built:
		return
	check(not main.visible and main.get_node("HUD/Panel").is_visible_in_tree() and view.camera.current,
		"the 2D world hidden, the screen's layers still up, the 3D camera on")
	# User request: its map and ponds bigger, the edge a wall of pines kept
	# off, no grass cards.
	check(is_equal_approx(Player.WORLD_WIDTH, roundf(2400.0 * RunView3D.MAP_SCALE)) and MapGenerator._pond_scale() > 1.4,
		"the 3D run's map and ponds bigger (%d px across)" % Player.WORLD_WIDTH)
	check(player().edge == RunView3D.EDGE and not view._models.has("#card"), "kept off the edge's pines; no grass cards")
	# Walking about: the rod slung on the back, the lamp in hand.
	check(view._stow > 0.99 and view._lamp_in > 0.99, "between casts: the rod on the back, the lamp in hand")
	var waters := 0
	for c in view.get_children():
		if c.name.begins_with("Water"):
			waters += 1
	check(waters == main.get_tree().get_nodes_in_group("water_zones").size(), "a surface for every pond")
	check(view._trees.size() == main.get_tree().get_nodes_in_group("trees").size(), "the map's trees, each a pine")
	# User request: the animals, the ghosts, the willow as 3D models now
	# (tools/build_run3d_models.py), not their pictures stood up.
	var modelled := 0
	var pictured := 0
	for n in view._creatures:
		if n is Critter:
			modelled += 1
	for n in view._sprites:
		if n.get_parent() is Critter:
			pictured += 1
	check(modelled > 0 and pictured == 0, "its animals as 3D models (%d), none as pictures (%d)" % [modelled, pictured])
	var ghoul: Node = main.get_node("BigGhost")
	check(view._creatures.has(ghoul) and view._creatures.has(main.get_node("Willow")), "the big ghost and the willow as models")
	ghoul.mode = BigGhost.Mode.CHASE
	await frames(3)
	check(view._creatures[ghoul].clip == "Chase", "the big ghost hunting: its chase clip (%s)" % view._creatures[ghoul].clip)
	ghoul.mode = BigGhost.Mode.ASLEEP
	var altar_visual: Node = main.get_node("Altar/Visual")
	check(view._replaced.has(altar_visual), "the altar as its model")
	# The screen's buttons over what they're for: the 3D camera's view.
	var feet: Vector2 = player().global_position + Player.FEET
	var at := RunView3D.screen_point(main.get_viewport(), feet)
	var size := main.get_viewport().get_visible_rect().size
	check(Rect2(Vector2.ZERO, size).has_point(at), "the traveller on screen (%s)" % at)
	var from := view.camera.project_ray_origin(at)
	var dir := view.camera.project_ray_normal(at)
	var hit := from + dir * ((view.ground_y(feet) - from.y) / dir.y)
	check(RunView3D.to2(hit).distance_to(feet) < 3.0, "and back from the screen to the same spot")
	# Running about: the run clip; it faces the way it goes.
	key(KEY_D, true)
	await seconds(0.6)
	check(view._clip == "Run" and view.rig.anim.current_animation == "Run", "running: the run clip (%s)" % view._clip)
	check(view.pivot.global_basis.z.x > 0.8, "facing the way it runs")
	key(KEY_D, false)
	await seconds(0.3)
	# Fishing: the cast wound up and thrown, the float out on the water.
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 40))
	player().aim_dir = Vector2.UP
	key(KEY_SPACE, true)
	await seconds(0.5)
	check(view._clip == "Fish_Throw" and view._guide_label.visible, "winding a cast: the cast clip, how far it'll go")
	check(view._stow < 0.01 and view._lamp_in < 0.01 and view._left_ik.influence > 0.9,
		"fishing: the rod drawn, both hands on it, the lamp at the hip")
	key(KEY_SPACE, false)
	for _i in 60:
		await frames(1)
		if player().state == Player.State.WAITING:
			break
	await seconds(0.5)
	check(player().state == Player.State.WAITING and view._float.visible
		and absf(view._float.position.y - RunView3D.WATER_Y) < 0.1, "the float out on the water")
	check(view._clip == "Fish_Wait", "waiting with the rod out (%s)" % view._clip)
	var tip := view._rod_tip()
	var hand: Vector3 = view.rig.attachments["hand_r"].global_position
	var toward := view._float.position - view.pivot.global_position
	toward.y = 0.0
	check(tip.y > hand.y + 0.3 and (tip - hand).dot(toward.normalized()) > 0.4, "the rod held up and out toward the float")
	# User report: the rod's guides were on top - under it now (the models'
	# guides on the rod's -z).
	var guides := -view._rod().global_basis.z.normalized()
	check(guides.y < -0.5, "the rod's guides hang under it (%s)" % guides)
	# User report: the arm didn't move with the rod - it's brought after
	# it now (RodArm).
	var hold_hand: float = view.rig.attachments["hand_r"].global_position.y - view.pivot.global_position.y
	check(view._ik != null and view._ik.influence > 0.9, "the rod arm follows the rod while fishing")
	# The float under the buttons at the bottom right: the camera makes
	# room (_dodge_buttons).
	# (a button on the right with water under it - the layout moved round
	# the stick, not every one's over the lake)
	# (the ground under each button; the traveller stepped a little so the
	# nearest bit of water to one is under it - on its own shore still)
	var unders := []
	for button_at in [TouchControls.SKILL_AT, TouchControls.LURE_AT] + QuickSlots.CENTERS + [BaitSlot.AT]:
		var from_cam := view.camera.project_ray_origin(button_at)
		var ray := view.camera.project_ray_normal(button_at)
		unders.append(RunView3D.to2(from_cam + ray * ((RunView3D.WATER_Y - from_cam.y) / ray.y)))
	var step := Vector2.INF
	for u in unders:
		for r in range(0, 420, 20):
			for k in 16:
				var w: Vector2 = u + Vector2.RIGHT.rotated(k * TAU / 16.0) * r
				if player()._find_water_zone(w) != null and (w - u).length() < step.length() \
						and player()._find_water_zone(player().global_position + (w - u)) == null:
					step = w - u
			if step != Vector2.INF:
				break
	check(step != Vector2.INF, "water near one of the buttons")
	var stand: Vector2 = player().global_position + step
	# (held still meanwhile: a step while the float's out would wind it in)
	player().set_physics_process(false)
	var stood: Vector2 = player().global_position
	var float_was: Vector2 = main.get_node("Bobber").global_position
	var target_was: Vector2 = player().cast_target
	player().global_position = stand
	await frames(4)
	var under := Vector2.ZERO
	for button_at in [TouchControls.SKILL_AT, TouchControls.LURE_AT] + QuickSlots.CENTERS + [BaitSlot.AT]:
		var from_cam := view.camera.project_ray_origin(button_at)
		var ray := view.camera.project_ray_normal(button_at)
		var spot := RunView3D.to2(from_cam + ray * ((RunView3D.WATER_Y - from_cam.y) / ray.y))
		if player()._find_water_zone(spot) != null:
			under = spot
			break
	check(under != Vector2.ZERO, "water under one of the buttons")
	player().cast_target = under
	main.get_node("Bobber").global_position = under
	await seconds(1.2)
	var seen := view.camera.unproject_position(view._float.position)
	var covered := false
	for r in view._blocked:
		covered = covered or (r as Rect2).has_point(seen)
	check(view._dodge > 0.05 and not covered, "the float under a button: the camera makes room (%.2f)" % view._dodge)
	player().global_position = stood
	main.get_node("Bobber").global_position = float_was
	player().cast_target = target_was
	await frames(2)
	player().set_physics_process(true)
	# (that spot may be on the bank - the line in again: cast again)
	if player().state != Player.State.WAITING:
		player()._set_state(Player.State.IDLE)
		await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 40))
		player().aim_dir = Vector2.UP
		key(KEY_SPACE, true)
		await seconds(0.5)
		key(KEY_SPACE, false)
		for _i in 90:
			await frames(1)
			if player().state == Player.State.WAITING:
				break
		await seconds(1.0)
	check(player().state == Player.State.WAITING, "out on the water again")
	# A bite, the strike: their clips.
	player().nibbles_left = 0
	player().cast_outcome = Player.CastOutcome.BITE
	player().wait_timer = 0.01
	for _i in 120:
		await frames(1)
		if player().state == Player.State.BITE:
			break
	await frames(3)
	check(view._clip == "Fish_Bite", "a bite: the bite clip (%s)" % view._clip)
	key(KEY_SPACE, true)
	await frames(6)
	check(player().state == Player.State.REELING and view._clip == "Fish_Tug", "struck: the strike clip (%s)" % view._clip)
	await frames(14)
	var strike_hand: float = view.rig.attachments["hand_r"].global_position.y - view.pivot.global_position.y
	check(strike_hand > hold_hand + 0.15, "the strike raises the arm with the rod (%.2f -> %.2f m)" % [hold_hand, strike_hand])
	# User request (the fight stood stiff): the fish running, hauling on it
	# low and braced - the arms still on the rod.
	player().fight.opening_left = 0.0
	# (user request: the rod bends with the fish's pull - more the harder -
	# and the body sways with it)
	player().fight.run_left = 0.0
	await frames(30)
	var light_bend := view.bend
	var straight_tip := view.rod_tip_straight()
	player().fight.run_left = 3.0
	await frames(6)
	check(view._clip == "Fish_Pull" and view._ik.influence > 0.9, "the fish running: hauling on it (%s)" % view._clip)
	var most := 0.0
	var lean := 0.0
	var tip_off := 0.0
	for _i in 40:
		player().tension = 0.9
		await frames(1)
		most = maxf(most, view.bend)
		lean = maxf(lean, view._lean.length())
		tip_off = maxf(tip_off, view._rod_tip().distance_to(view.rod_tip_straight()))
	check(light_bend > 0.02 and most > light_bend + 0.4 and most <= RunView3D.BEND_MAX,
		"the rod bent with the pull: %.2f held, %.2f running hard" % [light_bend, most])
	check(tip_off > 0.1 and lean > 0.03, "its tip bowed (%.2f m), the line from it; the body swaying (%.2f rad)" % [tip_off, lean])
	player().fight.run_left = 0.0
	key(KEY_SHIFT, true)
	await frames(8)
	check(view._clip == "Fish_Reel", "reeling it in: the reel's sway (%s)" % view._clip)
	key(KEY_SHIFT, false)
	key(KEY_SPACE, false)
	await frames(30)
	check(view._clip == "Fish_Hold", "neither: held still (%s)" % view._clip)
	# (user request: stepping back only when walked back, away from the line)
	key(KEY_S, true)
	await frames(10)
	check(view._clip == "Fish_Back", "walked back from the line: stepping back (%s)" % view._clip)
	var faced := Vector2(sin(view._yaw), cos(view._yaw)).dot((player().cast_target - player().global_position).normalized())
	check(faced > 0.5 and player().state == Player.State.REELING, "stepping back facing the fish, still on")
	key(KEY_S, false)
	# User request: turned round and run off, the line snaps.
	var away: Vector2 = -(player().cast_target - player().global_position).normalized()
	for _i in 40:
		player()._move_joystick.output = away
		await frames(1)
		if player().state != Player.State.REELING:
			break
	player()._move_joystick.output = Vector2.ZERO
	check(player().state == Player.State.IDLE, "run off from the fish: the line snapped")
	player()._set_state(Player.State.IDLE)
	player().fight = null
	player().line_cleared.emit()
	await frames(4)
	check(not view._float.visible, "the line in: no float")
	# User request: each thing done its own move.
	for pair in [["lift", "", "Kick"], ["pray", "", "Pray"], ["sad", "escaped", "Disappointed"]]:
		player().perform(pair[0], 1.5, pair[1])
		await frames(6)
		check(view._clip == pair[2], "%s %s: the %s clip (%s)" % [pair[0], pair[1], pair[2], view._clip])
		player().move_left = 0.0
		await seconds(0.3)
	player().carrying_oil_drum = true
	await frames(4)
	check(view._clip == "Walk_Carry" and view._lamp_in < 1.0, "carrying the oil drum: in both arms")
	player().carrying_oil_drum = false
	# On a phone: lighter (no glow, one shadow pass, none from the lamp,
	# the 3D drawn smaller, grass as cards).
	RunView3D.quality = "low"
	await _fresh_game()
	for _i in 120:
		view = RunView3D.active
		if view != null and view.built:
			break
		await frames(1)
	check(view._low and not view._env.glow_enabled and not view._lamp.shadow_enabled
		and is_equal_approx(main.get_viewport().scaling_3d_scale, RunView3D.LOW_SCALE)
		and view._moon.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "phone: the lighter settings")
	RunView3D.quality = ""


## The journey page: the camp's 出發夜釣 opens it; a locked level can't be
## picked; setting off walks out of the camp into the level.
func test_journey_page() -> void:
	reset_progress()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	await frames(4)
	var title: Node = get_tree().current_scene
	title._on_play()
	await frames(30)
	var page: Node = title.find_child("Journey", true, false)
	check(page != null, "出發夜釣 opens the journey")
	check(page.selected == "1-1", "the first level picked to begin with")
	page.select("1-3")
	await frames(2)
	check(page.find_child("Go", true, false) == null, "a locked level has no 出發")
	page._show_tab("achievements")
	await frames(2)
	check(page.find_child("Achievements", true, false) != null, "the achievements tab")
	page._show_tab("free")
	await frames(2)
	check(page.find_child("GoFree", true, false) == null or camp().free_open(), "the free run waits for chapter 1")
	page._show_tab("story")
	page.select("1-1")
	await frames(2)
	page._depart_level("1-1")
	for i in 60 * 25:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.name == "Main":
			break
	main = get_tree().current_scene
	check(main != null and main.name == "Main" and camp().level_id == "1-1", "off into 1-1")
	check(Player.WORLD_WIDTH < 1400.0 * RunView3D.MAP_SCALE, "on its small map")


## The profile's things as they are, to put back after a test that buys.
func _keep_profile() -> Dictionary:
	return {"gold": Profile.gold, "storage": Profile.storage.duplicate(true), "bag": Profile.bag.duplicate(true),
		"equipped": Profile.equipped.duplicate(true), "wear": Profile.wear.duplicate(true)}


func _restore_profile(kept: Dictionary) -> void:
	Profile.gold = kept.gold
	Profile.storage = kept.storage
	Profile.bag = kept.bag
	Profile.equipped = kept.equipped
	Profile.wear = kept.wear
	Profile._sync_rod()
	Profile._save()


## User request: the frog and the low-poly spider as live baits; the
## knives, the hatchet, the pistol (and its rounds), the flashlight, the
## food and the cup for the tea, all in the shop.
func test_shop_new_wares() -> void:
	var kept := _keep_profile()
	Profile.gold = 5000
	for id in ["live_frog", "live_spider", "knife", "hatchet", "machete", "glock", "ammo", "roll", "loaf", "cheese", "tea", "battery",
			"flashlight"]:
		var d := Items.def(id)
		check(not d.is_empty(), "%s is a thing" % id)
		check(Items.icon(id) != null, "%s has a picture" % id)
		check(Items.square_icon(id) != null, "%s has a square icon" % id)
		var model := Items.model_path(id)
		check(model != "" and ResourceLoader.exists(model), "%s has a model (%s)" % [id, model])
	check(Items.model_path("tea").ends_with("cup.glb"), "the tea is served in the cup")
	check(Profile.buy_live_bait("frog") and Profile.buy_live_bait("spider"), "live frog and spider bought")
	check(Profile.stored("live_frog") >= 1 and Profile.stored("live_spider") >= 1, "into the warehouse")
	Profile.storage.erase("hatchet")
	Profile.bag = Profile.bag.filter(func(e): return e.id != "hatchet")
	Profile.equipped["offhand"] = ""
	check(Profile.buy_weapon("hatchet"), "a hatchet bought")
	check(not Profile.buy_weapon("hatchet"), "only once")
	check(Profile.equip("hatchet") and Profile.weapon.get("chop", 0) == 2, "worn in the off hand, chops")
	check(Items.def("hatchet").slot == "offhand" and Items.def("net").slot == "offhand", "the off-hand slot (with the net)")
	var rounds := Profile.stored("ammo")
	check(Profile.buy_ammo() and Profile.stored("ammo") == rounds + 1, "a round bought")
	var spirit := Profile.spirit
	Profile.spirit = 10.0
	check(Profile.buy_snack("cheese") and Profile.spirit > 10.0, "the cheese is had for spirit")
	Profile.spirit = spirit
	# The shop shows them.
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await frames(2)
	shop._show_tab("gear")
	await frames(1)
	for id in Profile.WEAPON_ORDER:
		check(shop._grid.get_node_or_null("Card_" + id) != null, "the shop sells the %s" % id)
	shop._show_tab("bait")
	await frames(1)
	check(shop._grid.get_node_or_null("Card_live_frog") != null and shop._grid.get_node_or_null("Card_live_spider") != null,
		"the frog and the spider on the bait tab")
	shop._show_tab("item")
	await frames(1)
	for id in ["ammo", "roll", "loaf", "cheese", "tea"]:
		check(shop._grid.get_node_or_null("Card_" + id) != null, "the shop has %s" % id)
	shop.queue_free()
	_restore_profile(kept)
	await frames(1)


## User request: a real black spider, in many colourings, caught for bait
## but maybe poisonous - a big slow-down.
func test_black_spider() -> void:
	var p := player()
	var at := away_from_water(80.0)
	await put(at)
	var spider := Critter.spawn_black_spider(main, at + Vector2(40, 0), at)
	await frames(2)
	check(spider.species == "black_spider" and spider.is_venomous(), "a venomous black spider")
	check(spider.skin >= 1 and spider.skin <= 8, "in one of the 8 colourings (%d)" % spider.skin)
	var skins := {}
	for i in 40:
		spider.set_species("black_spider")
		skins[spider.skin] = true
	check(skins.size() >= 5, "colourings drawn at random (%d seen)" % skins.size())
	# Caught: two live baits in the bag (round 8), and sometimes a bite.
	var poisoned := false
	var kept := _keep_profile()
	for i in 30:
		seed(100 + i)
		p.poison_timer = 0.0
		Profile.bag_take("live_black_spider", 99)
		var s2 := Critter.spawn_black_spider(main, at, at)
		await frames(1)
		s2.global_position = p.global_position
		p.set_in_critter(true, s2)
		p._catch_critter()
		check(Profile.bag_count("live_black_spider") == Player.BLACK_SPIDER_BAIT, "two live black spiders in the bag")
		if p.poison_timer > 0.0:
			poisoned = true
			break
	_restore_profile(kept)
	check(poisoned, "its bite poisons, sometimes")
	check(StatusCard.speed_share(p) < 0.5, "poison slows a lot (%.2f)" % StatusCard.speed_share(p))
	check(StatusCard.conditions(p).any(func(c): return str(c[0]).begins_with("中毒")), "the card says poisoned")
	p.poison_timer = 0.0
	# Caught where it ran: gone for good (a spawned one).
	await put(spider.global_position)
	await frames(3)
	if p._critter == spider:
		p._catch_critter()
		await frames(2)
		check(not is_instance_valid(spider), "a spawned spider is gone once caught")
	# Live spider bait halves fake bites; the live frog is big bait.
	check("活青蛙" in Player.BIG_BAIT_FLAVORS, "the live frog is big bait")


## User request: the weapons in a run - a blade turns a pounce aside, the
## hatchet and the machete chop trees (bait, or a black spider), the
## pistol scares a beast off but the shot brings the big ghost.
func test_chop_and_weapons() -> void:
	var kept := _keep_profile()
	var p := player()
	Profile.equipped["offhand"] = ""
	var trees := main.get_tree().get_nodes_in_group("trees")
	check(not trees.is_empty(), "the map has trees")
	if trees.is_empty():
		_restore_profile(kept)
		return
	var tree: MapTree = trees[0]
	await put(tree.global_position + Vector2(20, 6))
	check(p.choppable_tree() == null, "no chopping bare-handed")
	Profile.equipped["offhand"] = "hatchet"
	check(p.choppable_tree() == tree, "a hatchet chops the tree in reach")
	check(p.interaction().get("verb", "") == "砍樹", "chopping offered at the tree")
	await tap(KEY_E)
	check(p.swing_kind == "chop", "the hatchet swung (a chop)")
	await seconds(Player.swing_time("chop"))
	check(tree.chopped, "chopped with a tap")
	check(p.choppable_tree() != tree, "each tree once")
	# Chopped all over, the trees give bait and spiders.
	var found := 0
	var spiders := 0
	seed(11)
	for t in trees:
		if t.chopped:
			continue
		var r: Dictionary = t.chop(p.global_position, 2)
		found += 1 if r.get("found", false) else 0
		spiders += 1 if r.get("spider", false) else 0
	check(found > 0 and spiders > 0, "chopping finds bait (%d) and spiders (%d)" % [found, spiders])
	# A blade parries.
	Profile.equipped["offhand"] = "knife"
	gs.add_carried_fish(fish())
	var carried: int = gs.carried_fish.size()
	p.water_ghost_timer = 0.0
	p.animal_attack("狼")
	check(gs.carried_fish.size() == carried, "the knife keeps the fish")
	check(p.water_ghost_timer <= Player.PARRY_DEBUFF_DURATION, "only a short stagger")
	Profile.equipped["offhand"] = ""
	p.water_ghost_timer = 0.0
	p.animal_attack("狼")
	check(gs.carried_fish.size() < carried, "bare-handed the fish is knocked loose")
	p.water_ghost_timer = 0.0
	# The pistol: a round a shot, the big ghost hears it.
	Profile.equipped["offhand"] = "glock"
	Profile.storage["ammo"] = 3
	Profile.to_bag("ammo", 3)
	var wolf: Critter = load("res://scenes/critter.tscn").instantiate()
	wolf.ambient = true
	wolf.species = "wolf"
	main.add_child(wolf)
	wolf.global_position = p.global_position + Vector2(100, 0)
	var bg := first("big_ghost")
	var rounds := Profile.bag_count("ammo")
	check(p.shoot_at(wolf), "the pistol fires")
	check(Profile.bag_count("ammo") == rounds - 1, "a round used")
	if bg != null:
		check(bg.mode == bg.Mode.SUSPICIOUS, "the big ghost comes to look")
	Profile.bag = Profile.bag.filter(func(e): return e.id != "ammo")
	check(not p.shoot_at(wolf), "no rounds, no shot")
	# User request: nothing in hand, a tap shoos a beast come close off.
	Profile.equipped["offhand"] = ""
	wolf._cooldown = 0.0
	wolf._mode = Critter.Mode.CHASE
	check(p.shoos(), "a wolf near, empty-handed: a tap shoos")
	# (the parry's slash above played out)
	p.swing_left = 0.0
	p.swing_kind = ""
	await tap(KEY_Q)
	check(p.swing_kind == "shoo", "waving it off (%s)" % p.swing_kind)
	await seconds(Player.swing_time("shoo"))
	check(not wolf.is_hunting() and wolf._cooldown > 0.0, "the wolf runs")
	wolf.global_position = p.global_position + Vector2(Player.SHOO_REACH + 60.0, 0)
	check(not p.shoos(), "none near: nothing to shoo")
	wolf.queue_free()
	_restore_profile(kept)
	await frames(1)


## User request: the off hand. A tap of the right stick swings what's in
## it; held on, the rod's drawn off the back and cast (the off hand's thing
## to the hip); every use wears a thing, and worn out it breaks.
func test_offhand_swing_and_wear() -> void:
	var kept := _keep_profile()
	var p := player()
	var stick = main.get_node("HUD/Panel/AimJoystick")
	var body: PlayerVisual = p.get_node("Body")
	var prop: OffhandProp = p.get_node("Offhand")
	Profile.gold = 5000
	if Profile.owned("knife") == 0:
		Profile.buy_weapon("knife")
	Profile.equip("knife")
	var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	p.aim_dir = Vector2.UP
	await frames(3)
	check(p.offhand_in_hand() and prop.visible, "the knife in hand between casts")
	var in_hand: Array = prop.shown.duplicate()
	check(body.rod_on_back(), "the rod on the back")
	# A tap: a swing, not a cast.
	stick._touch_index = 0
	stick.is_pressed = true
	stick.output = Vector2.ZERO
	await frames(4)
	stick._touch_index = -1
	stick.is_pressed = false
	await frames(2)
	check(p.state == Player.State.IDLE and p.swing_kind == "slash", "a tap swings the knife (%s)" % p.swing_kind)
	check(body.acting == PlayerVisual.ACTIONS.find("slash"), "its swing on the sprite")
	await seconds(Player.SWING_TIME + 0.1)
	check(Profile.durability("knife") == Profile.max_durability("knife") - 1, "the swing wears it")
	check(body.acting < 0, "and back to standing")
	# Held on: the rod drawn, and a cast.
	var rod_uses := Profile.durability(Profile.equipped.rod)
	stick._touch_index = 0
	stick.is_pressed = true
	await seconds(Player.SWING_TAP + 0.2)
	check(p.state == Player.State.CHARGING, "held on, the cast charges")
	await frames(20)
	check(not body.rod_on_back() and not prop.shown.is_empty() and prop.shown[0].distance_to(in_hand[0]) > 0.5,
		"the rod in hand, the knife to the hip")
	stick._touch_index = -1
	stick.is_pressed = false
	await frames(3)
	check(p.state != Player.State.CHARGING, "let go, it's cast")
	check(Profile.durability(Profile.equipped.rod) == rod_uses - 1, "the cast wears the rod")
	p._reset_line(Player.State.IDLE)
	await frames(2)
	# Worn out: it breaks, and it's gone - the shop sells another.
	Profile.wear["knife"] = 1
	check(p.swing(), "swung once more")
	await seconds(Player.SWING_TIME + 0.1)
	check(Profile.offhand() == "" and Profile.owned("knife") == 0, "worn out, the knife broke and is gone")
	check(Profile.buy_weapon("knife"), "and can be bought again")
	# The rod: the wooden one comes back when the last rod breaks.
	Profile.wear[Profile.equipped.rod] = 1
	var tier_before := Profile.rod_tier
	Profile.wear_out(Profile.equipped.rod)
	check(str(Profile.equipped.rod) != "", "a rod still worn after one breaks (was tier %d, now %d)" % [tier_before, Profile.rod_tier])
	# In the bag: gear dragged onto its slot goes on, the old into the bag.
	Profile.storage.erase("knife")
	Profile.bag = Profile.bag.filter(func(e): return Items.def(e.id).get("slot", "") == "")
	Profile.equipped["offhand"] = ""
	Profile._store("knife", 1)
	Profile.to_bag("knife", 1)
	if Profile.owned("hatchet") == 0:
		Profile._store("hatchet", 1)
	Profile.equip("hatchet")
	var bag: Backpack = p.backpack()
	var at := -1
	for i in Profile.bag.size():
		if Profile.bag[i].id == "knife":
			at = i
	check(at >= 0 and bag.equip_from_bag(at), "the knife put on from the bag")
	check(Profile.offhand() == "knife" and Profile.bag_count("hatchet") == 1, "the hatchet into the bag in its place")
	check(bag.unequip_to_bag("offhand") and Profile.offhand() == "" and Profile.bag_count("knife") == 1, "and off again")
	_restore_profile(kept)
	await frames(1)



## User request (after Vaultbreakers): the run's trial in 3D perspective -
## walked about with the stick, walking when it's eased off and running when
## it's pushed, round things, not into the lake, out along the dock; the
## camera after it from up and behind.
func test_proto3d() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 100, "spirit": 90.0})
	var p: Node3D = load("res://scenes/proto3d.tscn").instantiate()
	get_tree().root.add_child(p)
	await frames(5)
	var cam: Camera3D = p.camera
	var down := rad_to_deg(-cam.global_transform.basis.z.angle_to(Vector3(cam.global_transform.basis.z.x, 0, cam.global_transform.basis.z.z)))
	check(absf(absf(down) - p.CAMERA_PITCH) < 2.0, "the camera looks down at %.0f degrees" % absf(down))
	var stick = p._joystick
	var from: Vector3 = p.pivot.position
	stick.output = Vector2(0.3, 0.0)
	await seconds(1.0)
	check(p.character.anim.current_animation == "Walk" and p.pivot.position.x > from.x + 0.8,
		"stick eased off: it walks (%s)" % p.character.anim.current_animation)
	stick.output = Vector2(1.0, 0.0)
	await seconds(0.6)
	check(p.character.anim.current_animation == "Run", "pushed all the way: it runs (%s)" % p.character.anim.current_animation)
	# Round the fire, not through it.
	p.pivot.position = p.PLAZA + Vector3(0, 0, 2.5)
	stick.output = Vector2(0.0, -1.0)
	var nearest := INF
	for _i in 60:
		await frames(1)
		nearest = minf(nearest, Vector2(p.pivot.position.x, p.pivot.position.z).distance_to(Vector2(p.PLAZA.x, p.PLAZA.z)))
	check(nearest > 0.85, "not through the fire (%.2f m)" % nearest)
	# Not into the lake; out along the dock.
	p.pivot.position = Vector3(-6.0, 0, p._shore_z(-6.0) + 2.0)
	await seconds(1.5)
	check(p.pivot.position.z >= p._shore_z(p.pivot.position.x) + 0.3, "it stops at the water's edge")
	p.pivot.position = Vector3(2.4, 0.32, float(p._dock_span[1]) - 0.5)
	await seconds(1.2)
	check(p._on_dock(p.pivot.position) and p.pivot.position.z < p._shore_z(2.4) - 1.0 and is_equal_approx(p.pivot.position.y, 0.32),
		"out along the dock over the water")
	stick.output = Vector2.ZERO
	await frames(10)
	check(p.character.anim.current_animation == "Idle", "let go: it stands")
	p.queue_free()
	await frames(2)
	Profile.load_data(saved)


## User request: the walkable 3D camp is the main screen - a tap on a
## thing, the traveller walks over, does it, and its page opens; a log, it
## sits; the old camp a button away.
func test_camp3d() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 100, "spirit": 90.0})
	TitleScreen.sound_unlocked = true
	var camp = load("res://scenes/camp3d.tscn").instantiate()
	get_tree().root.add_child(camp)
	await seconds(1.0)
	var stage: CampStage = camp._stage
	check(stage != null and stage.free_camera, "the old camp's place, the camera free")
	for name in ["warehouse", "equipment", "fish_tank", "shop", "character"]:
		check(stage.hotspots.has(name), "%s still there to tap" % name)
	var pivot: Node3D = stage.character_pivot
	# The stick walks it (its own life let go), the camera after it.
	var from := pivot.position
	var cam_from: Vector3 = stage.camera.position
	for _i in 40:
		camp._joystick.output = Vector2(1, 0)
		await frames(1)
	camp._joystick.output = Vector2.ZERO
	check(pivot.position.x > from.x + 1.0 and stage.life.paused, "walked right with the stick (%s)" % str(pivot.position))
	await frames(10)
	check(stage.camera.position.x > cam_from.x + 0.5, "the camera followed")
	# Into nothing: pushed at the crate, it stops at it.
	var crate_spot: Vector3 = stage.spots.crate.at
	pivot.position = crate_spot
	var crate_room: float = stage.clearance(crate_spot)
	var at_crate := Vector2(CampStage.CRATE_AT.x - crate_spot.x, CampStage.CRATE_AT.z - crate_spot.z).normalized()
	for _i in 90:
		camp._joystick.output = at_crate
		await frames(1)
		# (up to it, no nearer than its own body - CampStage.body)
		check(stage.clearance(pivot.position) >= minf(crate_room, stage.body) - 0.01,
			"never into the crate (%s, %.2f m off)" % [str(pivot.position), stage.clearance(pivot.position)]) if _i % 30 == 29 else null
	camp._joystick.output = Vector2.ZERO
	# Nor into the lake - but out along the dock, up on its planks.
	pivot.position = CampStage.DOCK_AT + Vector3(0, 0, 0.6)
	for _i in 60:
		camp._joystick.output = Vector2(0, -1)
		await frames(1)
	camp._joystick.output = Vector2.ZERO
	check(stage.on_dock(pivot.position) and pivot.position.z < CampStage.DOCK_AT.z - 1.0 and pivot.position.y > 0.1,
		"out on the dock (%s)" % str(pivot.position))
	pivot.position = Vector3(-1.0, 0, -5.0)
	for _i in 60:
		camp._joystick.output = Vector2(0, -1)
		await frames(1)
	camp._joystick.output = Vector2.ZERO
	check(not stage._in_lake(pivot.position, 0.25), "not into the lake (%s)" % str(pivot.position))
	pivot.position = CampStage.CHARACTER_AT
	# A tap on a thing: over to it, then its page.
	for page in ["warehouse", "fish_tank", "equipment", "shop"]:
		camp._ask(page)
		var t := 0.0
		while camp._page == null and t < 30.0:
			await frames(6)
			t += 0.1
		check(camp._page != null and camp._page.scene_file_path.ends_with(page + ".tscn"), "%s: walked over, opened (%.1f s)" % [page, t])
		camp.close_page()
		await frames(3)
	# Sat on a log, the stick gets it up first, then walks.
	camp._ask("sit")
	var w := 0.0
	while not stage.life.seated and w < 25.0:
		await frames(6)
		w += 0.1
	check(stage.life.seated, "sat on the log")
	for _i in 150:
		camp._joystick.output = Vector2(0, 1)
		await frames(1)
	camp._joystick.output = Vector2.ZERO
	check(not stage.life.seated, "up off the log, walked off")
	# The menu along the bottom: the page at once, the character off to the
	# crate behind it.
	await seconds(1.0)
	var before: Vector3 = pivot.position
	camp.quick("warehouse")
	await frames(3)
	check(camp._page != null and camp._page.scene_file_path.ends_with("warehouse.tscn"), "the menu: the warehouse at once")
	await seconds(1.0)
	check(not stage.life.paused and pivot.position.distance_to(before) > 0.3, "the character goes to the crate behind it")
	camp.close_page()
	await frames(3)
	# Never through the merchant.
	var m: Node3D = stage.merchant
	check(not camp.walkable(m.global_position + Vector3(0.2, 0, 0)), "the merchant's a body to walk round")
	# User request: the fish tank from whichever side it's nearest - from
	# its right, the right side; and stood clear of it.
	var trough: Node3D = stage.hotspots.fish_tank.parts[0][0]
	for side in [1.0, -1.0]:
		var spot: Dictionary = stage.stand_at("trough", trough.global_position + Vector3(2.0 * side, 0, 0), 0.3)
		check((spot.at.x - trough.global_position.x) * side > 0.8 and stage.clearance(spot.at) > 0.3,
			"the trough from its %s side (%s)" % ["right" if side > 0 else "left", spot.at])
	# User report: sat on a log, 坐下 stayed up in front of it - a thing's
	# name goes once it's tapped, and while sat.
	stage.life.sit_now()
	await frames(30)
	check(not camp._near_label.visible or camp._near_label.modulate.a < 0.05, "no name up while it sits")
	camp.queue_free()
	await frames(2)
	Profile.load_data(saved)
	Profile._save()


## User request: the glow mushroom - only under the trees, glowing on the
## map; picked (採集) into the bag; rubbed to crumbs and sprinkled on, a
## faint blue light all round for 30 s, its slot under the card.
## User request: dying loses what was picked up on the map that run - the
## whole way: picked, caught, the run lost to the big ghost; what was
## brought stays.
func test_death_loses_finds() -> void:
	var saved := Profile.snapshot()
	await _fresh_game()
	check(not Campaign.rules.safe, "the free run isn't a safe one")
	var p := player()
	var before := {}
	for e in Profile.bag:
		before[e.id] = int(before.get(e.id, 0)) + int(e.count)
	await frames(2)
	var shrooms := get_tree().get_nodes_in_group("glow_mushrooms")
	if not shrooms.is_empty():
		p.global_position = (shrooms[0] as Node2D).global_position + Vector2(12, 0)
		await frames(2)
		p._pick_mushroom(p.reachable_mushroom())
	var worms := p.pocket_live_bait("worm", 2)
	var got := Profile.bag_count("glow_mushroom") - int(before.get("glow_mushroom", 0))
	check(got == (0 if shrooms.is_empty() else 1) and worms > 0, "a mushroom picked, %d worms caught" % worms)
	gs.caught()
	await frames(2)
	check(gs.run_over, "caught: the run's lost")
	var after := {}
	for e in Profile.bag:
		after[e.id] = int(after.get(e.id, 0)) + int(e.count)
	check(after == before, "the bag as it was brought - the finds gone, nothing else (%s / %s)" % [after, before])
	Profile.load_data(saved)


## User request: the oxygen algae in the shallows - picked, used on a fish.
func test_oxy_algae() -> void:
	var saved := Profile.snapshot()
	await _fresh_game()
	var view: RunView3D = null
	for _i in 120:
		view = RunView3D.active
		if view != null and view.built:
			break
		await frames(1)
	var algae := get_tree().get_nodes_in_group("oxy_algae")
	check(algae.size() >= 1, "oxy algae on the map (%d)" % algae.size())
	var shore := true
	for a in algae:
		var near := INF
		for z in get_tree().get_nodes_in_group("water_zones"):
			near = minf(near, absf((z as WaterZone).depth((a as Node2D).global_position)))
		shore = shore and near < 20.0
	check(shore, "each in the shallows by a shore")
	if view != null:
		await frames(2)
		check(view._plants.size() == algae.size(), "each shown in 3D (%d)" % view._plants.size())
	var p := player()
	var a: OxyAlgae = algae[0]
	p.global_position = a.global_position + Vector2(12, 0)
	await frames(2)
	check(p.interaction().get("verb", "") == "採集" and p.interaction().get("name", "") == "魚氧藻", "by one: 採集 魚氧藻 offered")
	var had := Profile.bag_count("oxy_algae")
	p._pick_mushroom(p.reachable_mushroom())
	await frames(2)
	check(Profile.bag_count("oxy_algae") == had + 1 and int(Profile.found_this_run.get("oxy_algae", 0)) == 1, "picked: in the bag, noted as found")
	await seconds(Player.GATHER_TIME * Player.GATHER_TAKE + 0.2)
	check(not is_instance_valid(a), "then gone from the map")
	# Used on a fish.
	var f := FishLife.roll({"name": "鯉魚", "id": "carp", "value": 6.0, "size": "small", "rarity": "common"})
	f.life_traits = []
	GameState.carried_fish = [f]
	p.move_left = 0.0
	check(p.fish_for("oxy_algae") == 0, "a fish that needs it")
	check(p.use_on_fish("oxy_algae", 0) and f.vit_slow == FishLife.ALGAE_TIME and Profile.bag_count("oxy_algae") == had, "used on it")
	check(p.fish_for("oxy_algae") == -1, "already helped: none to pick")
	# The card's picker.
	var panel := FishPickPanel.new("t", "oxy_algae")
	get_tree().root.add_child(panel)
	await frames(2)
	check(panel.find_child("Fish_0", true, false) != null and (panel.find_child("Fish_0", true, false) as Button).disabled == false, "the picker lists the fish")
	panel.queue_free()
	GameState.carried_fish.clear()
	Profile.load_data(saved)


func test_glow_mushroom() -> void:
	var saved := Profile.snapshot()
	await _fresh_game()
	var view: RunView3D = null
	for _i in 120:
		view = RunView3D.active
		if view != null and view.built:
			break
		await frames(1)
	var shrooms := get_tree().get_nodes_in_group("glow_mushrooms")
	check(shrooms.size() >= 1, "glow mushrooms on the map (%d)" % shrooms.size())
	var under_trees := true
	for m in shrooms:
		var near := INF
		for t in get_tree().get_nodes_in_group("trees"):
			near = minf(near, (m as Node2D).global_position.distance_to(t.global_position) - float(t.trunk_radius))
		under_trees = under_trees and near < GlowMushroom.FROM_TRUNK.y + 1.0
	check(under_trees, "each at a tree's foot")
	if view != null:
		check(view._mushrooms.size() == shrooms.size(), "each shown in 3D, glowing (%d)" % view._mushrooms.size())
	var p := player()
	var m: GlowMushroom = shrooms[0]
	p.global_position = m.global_position + Vector2(12, 0)
	await frames(2)
	check(p.interaction().get("verb", "") == "採集", "by one: 採集 offered")
	var had := Profile.bag_count("glow_mushroom")
	p._pick_mushroom(p.reachable_mushroom())
	await frames(2)
	check(Profile.bag_count("glow_mushroom") == had + 1 and is_instance_valid(m) and p.reachable_mushroom() != m,
		"picked: in the bag (still there till the hands reach it)")
	check(int(Profile.found_this_run.get("glow_mushroom", 0)) == 1, "noted as found on the map (lost should it die)")
	await seconds(Player.GATHER_TIME * Player.GATHER_TAKE + 0.2)
	check(not is_instance_valid(m), "then gone from the map")
	check(p.move_kind == "gather", "gathered (crouched, picked, up)")
	if view != null:
		await frames(2)
		check(view._mushrooms.size() == shrooms.size() - 1, "and gone in 3D")
	# Put down and picked up again: still the map's.
	var gi := Profile.bag.map(func(e): return e.id).find("glow_mushroom")
	if gi >= 0:
		var n := Profile.bag_count("glow_mushroom")
		p.put_item_down(gi)
		var dropped: DroppedItem = get_tree().get_nodes_in_group("dropped_items").back()
		check(dropped.found == 1 and not Profile.found_this_run.has("glow_mushroom"), "put down: the find goes with it")
		p._pick_up_item(dropped)
		check(Profile.bag_count("glow_mushroom") == n and dropped.found == 0 and int(Profile.found_this_run.get("glow_mushroom", 0)) == 1,
			"picked up again: found again (%d of %d)" % [Profile.bag_count("glow_mushroom"), n])
	p.move_left = 0.0
	check(p.use_item("glow_mushroom") and Profile.bag_count("glow_mushroom") == had, "used from the bag")
	check(p.move_kind == "crumble" and p.glow_strength() == 0.0, "rubbed to crumbs first - not lit yet")
	# User request: the gathering and the digging (for later), the user's
	# Mixamo clips, on every character (tools/add_clips.py).
	for id in CharacterArt.REACH:
		var body: Node = CharacterArt.model(id).instantiate()
		var ap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
		check(ap.has_animation("Gathering") and ap.has_animation("Digging"), "%s can gather and dig" % id)
		body.free()
	check(StatusCard.effects(p).any(func(e): return e[0] == "glow_mushroom"), "its slot under the card")
	await seconds(Player.CRUMBLE_TIME + 0.5)
	check(p.glow_strength() > 0.5, "then a faint blue light all round (%.2f)" % p.glow_strength())
	if view != null:
		check(view._glow_light.visible and is_equal_approx(view._glow_light.omni_range, Player.GLOW_RADIUS / RunView3D.PX),
			"lit in 3D, %.1f m round" % view._glow_light.omni_range)
	p.glow_timer = 1.0
	await seconds(1.2)
	check(p.glow_strength() == 0.0 and StatusCard.effects(p).is_empty(), "30 s on, it's out")
	Profile.load_data(saved)
	Profile._save()


## User request: each character its own ability (Abilities), told at the
## fire with its story; each shown on the card and going off with its own
## show.
func test_character_abilities() -> void:
	var saved := Profile.snapshot()
	for c in Profile.CHARACTERS:
		var kind := Abilities.kind_of(c[0])
		check(kind != "" and Abilities.icon(kind) != null and Abilities.story(c[0]) != "",
			"%s: its ability (%s), its badge and its story" % [c[1], Abilities.info(kind).get("name", "?")])
	# At the fire: the picked one's ability and story.
	var page: CharacterPage = load("res://scenes/character_page.tscn").instantiate() if ResourceLoader.exists("res://scenes/character_page.tscn") else CharacterPage.new()
	get_tree().root.add_child(page)
	await frames(2)
	page.pick("croc")
	await frames(1)
	check(page._ability_name.text == "水中霸王" and page._story.text == Abilities.story("croc"), "the fire's page tells it")
	page.queue_free()
	Abilities.forced = true
	var fired := []
	# The cat: quicker at night.
	Profile.character = "cat"
	await _fresh_game()
	var p := player()
	p.ability_triggered.connect(func(k, _at, _n): fired.append(k))
	var day := StatusCard.speed_share(p)
	GameState.is_night = true
	await frames(2)
	check(is_equal_approx(StatusCard.speed_share(p), day * Abilities.CAT_NIGHT_SPEED) and fired.has("cat"),
		"the cat: 15% quicker once night's fallen, and it shows")
	GameState.is_night = false
	# The owl: brighter in the dark.
	Profile.character = "owl"
	fired.clear()
	await _fresh_game()
	p = player()
	p.ability_triggered.connect(func(k, _at, _n): fired.append(k))
	var lantern: Lantern = p.get_node("Lantern")
	check(not p.unlit(), "the lamp lit: not in the dark")
	await frames(2)
	lantern.fuel = 0.0
	await frames(2)
	check(p.unlit() and fired.has("owl"), "lamp out: the owl's sight comes on")
	var view := RunView3D.active
	if view != null:
		await seconds(1.0)
		check(view._env.tonemap_exposure > RunView3D.EXPOSURE * 1.05, "the view brighter (%.2f)" % view._env.tonemap_exposure)
	# The dog: something sniffed out close by, named, to pick up or not.
	Profile.character = "dog"
	fired.clear()
	await _fresh_game()
	p = player()
	var notes := []
	p.ability_triggered.connect(func(k, _at, n): fired.append(k); notes.append(n))
	var before := get_tree().get_nodes_in_group("dropped_items").size() + get_tree().get_nodes_in_group("glow_mushrooms").size()
	check(p.sniff() and fired.has("dog") and notes[0] != "", "the dog sniffs something out (%s)" % [notes])
	await frames(2)
	check(get_tree().get_nodes_in_group("dropped_items").size() + get_tree().get_nodes_in_group("glow_mushrooms").size() == before + 1,
		"and it's there on the ground")
	view = RunView3D.active
	if view != null:
		await frames(2)
		check(view._tags.size() == 1, "named in 3D")
		var put_down := DroppedItem.make("potion_ward", 1)
		put_down.position = p.global_position + Vector2(30, 0)
		main.add_child(put_down)
		await frames(2)
		check(view._items.has(put_down), "a thing put down: its model on the ground")
		put_down.pick_up()
		await frames(2)
		check(not view._items.has(put_down), "and gone once it's picked up")
		view._tags[0][2] = RunView3D.NAME_TAG_TIME
		await frames(2)
		check(view._tags.is_empty(), "the name goes after a while")
	# The sheep: two mushrooms for one.
	Profile.character = "sheep"
	await _fresh_game()
	p = player()
	var m: GlowMushroom = get_tree().get_nodes_in_group("glow_mushrooms")[0]
	p.global_position = m.global_position + Vector2(10, 0)
	var had := Profile.bag_count("glow_mushroom")
	p._pick_mushroom(m)
	check(Profile.bag_count("glow_mushroom") == had + 2, "the sheep picks two")
	# The bear's strike and the croc's haul.
	for kind in ["bear", "croc"]:
		Profile.character = kind
		await _fresh_game()
		p = player()
		fired.clear()
		p.ability_triggered.connect(func(k, _at, _n): fired.append(k))
		var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
		await put(zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
		p.aim_dir = Vector2.UP
		p.cast_target = p.global_position + Vector2(0, -150)
		p.cast_water_zone = zone
		p.tier_data = FishData.get_tier_data("mid").duplicate()
		p.difficulty_key = "normal"
		p.fish_habit = ""
		p.is_heart_catch = false
		p._hook_fish()
		if kind == "bear":
			check(fired.has("bear") and p.fight.progress >= Abilities.BEAR_WEAR - 0.01, "the bear's strike: the fish 15% down at once")
		else:
			p.fight.progress = 1.0 - Abilities.CROC_AT + 0.01
			await frames(3)
			check(fired.has("croc"), "the croc hauls it straight in")
	Abilities.forced = false
	Profile.load_data(saved)
	Profile._save()


## User requests: a blade in hand is swung at a beast coming for you by
## itself; and a menu in the run leaves it for the camp.
func test_run_menu_and_auto_defend() -> void:
	var kept := _keep_profile()
	await _fresh_game()
	var p := player()
	Profile.equipped["offhand"] = "knife"
	var wolf: Critter = load("res://scenes/critter.tscn").instantiate()
	wolf.ambient = true
	wolf.species = "wolf"
	main.add_child(wolf)
	wolf.global_position = p.global_position + Vector2(80, 0)
	wolf._cooldown = 0.0
	wolf._mode = Critter.Mode.CHASE
	wolf._mode_timer = 5.0
	await frames(3)
	check(p.swing_kind == "slash", "the blade swung by itself (%s)" % p.swing_kind)
	await seconds(Player.swing_time("slash"))
	check(not wolf.is_hunting(), "the wolf driven off")
	# User report: a wolf held at the camp's edge was swung at again and
	# again and the player, stood to each swing, was stuck: the blade's own
	# swings don't stop them walking, and come no oftener than AUTO_DEFEND_GAP.
	wolf._mode = Critter.Mode.CHASE
	wolf._mode_timer = 5.0
	wolf.global_position = p.global_position + Vector2(70, 0)
	# (held where it is - it'd bite, the bite's stagger not what's tested)
	wolf.set_physics_process(false)
	await seconds(Player.AUTO_DEFEND_GAP + 0.1)
	var from := p.global_position
	key(KEY_A, true)
	await seconds(0.4)
	key(KEY_A, false)
	check(p.global_position.distance_to(from) > 20.0, "walking on through the blade's own swing (%.0f px)" % p.global_position.distance_to(from))
	wolf.queue_free()
	Profile.equipped["offhand"] = ""
	# User report: a beast after you from the camp's far side stuck there,
	# pressed into it: it goes round now - a wolf (the camp's narrow way),
	# and the big ghost round the lit camp it can't come into.
	var camp: Node2D = main.get_tree().get_nodes_in_group("fuel_stations")[0]
	var round_camp: Array = FuelStation.bounds()
	var mid: Vector2 = camp.global_position + (round_camp[0] as Vector2)
	var r: float = round_camp[1]
	await put(mid + Vector2(0, r + 8))
	var hunter: Critter = load("res://scenes/critter.tscn").instantiate()
	hunter.ambient = true
	hunter.species = "wolf"
	main.add_child(hunter)
	hunter.global_position = mid + Vector2(0, -(r + 24))
	var nearest := INF
	for _i in 60 * 8:
		hunter._mode = Critter.Mode.CHASE
		hunter._mode_timer = 5.0
		hunter._cooldown = 0.0
		await frames(1)
		nearest = minf(nearest, hunter.global_position.distance_to(p.global_position))
	check(nearest < 60.0, "a wolf on the camp's far side came round it (%.0f px, %.0f apart)" % [nearest, 2.0 * r + 32.0])
	hunter.queue_free()
	var bg = main.get_node("BigGhost")
	var lit: Vector2 = camp.global_position
	await put(lit + Vector2(0, BigGhost.SAFE_RADIUS + 40))
	bg.global_position = lit + Vector2(0, -(BigGhost.SAFE_RADIUS + 60))
	var closest := INF
	for _i in 60 * 12:
		if bg.mode != BigGhost.Mode.GRAB:
			bg.mode = BigGhost.Mode.CHASE
			bg._timer = 5.0
			bg._lost = 0.0
			bg._target = p.global_position
		await frames(1)
		closest = minf(closest, bg.global_position.distance_to(p.global_position))
	check(closest < BigGhost.CATCH_RADIUS + 10.0, "the big ghost came round the lit camp to you (%.0f px)" % closest)
	bg.mode = BigGhost.Mode.ASLEEP
	p.release()
	await frames(2)
	# The menu: the run paused under it; back to the camp from it.
	var hud: Node = main.get_node("HUD")
	hud.open_run_menu()
	await frames(2)
	check(get_tree().paused and hud.get_node_or_null("RunMenuLayer/RunMenuShade") != null, "the menu, the run paused")
	var leave: Button = hud.find_child("LeaveRun", true, false)
	check(leave != null, "回到營地 offered")
	leave.pressed.emit()
	await frames(6)
	check(not get_tree().paused and get_tree().current_scene.scene_file_path == Camp3D.SCENE, "back at the camp")
	_restore_profile(kept)
	await frames(1)


## User report: a wolf trailed the traveller and never bit. Caught up, it
## bites (and runs off); fewer of them about, and no husky to mistake.
func test_wolf_bites() -> void:
	await _fresh_game()
	Profile.equipped["offhand"] = ""
	var p := player()
	await put(away_from_water(120.0))
	var wolf: Critter = load("res://scenes/critter.tscn").instantiate()
	wolf.ambient = true
	wolf.species = "wolf"
	main.add_child(wolf)
	wolf.global_position = p.global_position + Vector2(90, 0)
	wolf._cooldown = 0.0
	var bit := false
	for _i in 60 * 4:
		await frames(1)
		if p.water_ghost_timer > 0.0:
			bit = true
			break
	check(bit, "caught up, the wolf bites (%s)" % p.affliction_text)
	wolf.queue_free()
	var animals: Dictionary = MapGenerator.THEMES["forest_pine"].animals
	var total := 0.0
	for k in animals:
		total += float(animals[k])
	check(not animals.has("husky") and float(animals.get("wolf", 0.0)) / total < 0.1,
		"wolves a few in a hundred of the animals, no husky")


## User request: the big hands into the lamp in the opening, the lamp into
## the bellies - nothing of the traveller deep in the lamp, nor in the drum it's
## taken off, the whole opening through (its skin posed after the arms are
## brought round - SkinPoints), for a big-handed one, a round one and the
## smallest. The lamp as solid: [from, to, radius] up it (its own frame).
const LAMP_SOLID := [[0.0, 0.11, 0.065], [0.11, 0.23, 0.058], [0.23, 0.25, 0.079], [0.25, 0.305, 0.044]]
## (the opening as it was - user request - its moves the clips': a hand,
## an arm brushing the lamp or the drum's rim in passing, no deeper)
const LAMP_TOUCH := 0.06
const DRUM_TOUCH := 0.08


func test_intro_lamp_clear() -> void:
	var kept := _keep_profile()
	var was: String = Profile.character
	for id in ["croc", "bear2", "cat"]:
		Profile.character = id
		RunView3D.intro = true
		await _fresh_game()
		var view: RunView3D = null
		for _i in 300:
			view = RunView3D.active
			if view != null and view.built:
				break
			await frames(1)
		view.show_intro()
		var pts := SkinPoints.new(view.rig, 2)
		var worst := {"lamp": 0.0, "drum": 0.0}
		var n := [0]
		var rr := FuelStation.DRUM_RADIUS / RunView3D.PX
		var look := func():
			n[0] += 1
			if n[0] % 3 != 0 or view._intro_t < 0.0:
				return
			var lamp: Node3D = view._intro_lamp if view._intro_lamp != null else view._held_light()
			if lamp == null:
				return
			var inv := lamp.global_transform.affine_inverse()
			var k := lamp.global_basis.get_scale().x
			for p in pts.world():
				var l := inv * p
				var r := Vector2(l.x, l.z).length()
				for seg in LAMP_SOLID:
					if l.y > seg[0] and l.y < seg[1] and r < seg[2]:
						worst.lamp = maxf(worst.lamp, minf(seg[2] - r, minf(l.y - seg[0], seg[1] - l.y)) * k)
				if view._lamp_drum != null:
					var d := view._lamp_drum.global_position
					var flat := Vector2(p.x - d.x, p.z - d.z).length()
					if flat < rr and p.y < view._lamp_drum_top:
						worst.drum = maxf(worst.drum, minf(rr - flat, view._lamp_drum_top - p.y))
		view.rig.skeleton.skeleton_updated.connect(look)
		while view._intro_t >= 0.0 and view._intro_t < float(RunView3D.INTRO.pull_from) + 0.3:
			await frames(1)
		view.rig.skeleton.skeleton_updated.disconnect(look)
		check(view._intro_grabbed and view.lamp_lit(), "%s: the lamp taken and lit" % id)
		check(worst.lamp < LAMP_TOUCH, "%s: no more than brushing the lamp (%.3f m in at most)" % [id, worst.lamp])
		check(worst.drum < DRUM_TOUCH, "%s: nor the drum (%.3f m)" % [id, worst.drum])
	RunView3D.intro = false
	Profile.character = was
	_restore_profile(kept)


## User requests: a run opens on the traveller picking up the lamp (the
## camera close, then drawing back out); and the eye items' way and eye
## show in 3D.
func test_run_intro_and_eye_guide() -> void:
	var kept := _keep_profile()
	RunView3D.intro = true
	await _fresh_game()
	var view: RunView3D = null
	for _i in 120:
		view = RunView3D.active
		if view != null and view.built:
			break
		await frames(1)
	await frames(2)
	check(view != null and view._intro_t >= 0.0 and not view._intro_grabbed and view._intro_lamp != null
		and view._intro_lamp.global_position.y > 0.7, "the opening: the lamp on the drum")
	# (user request: a loading screen till it's built and drawn, then the
	# fog clears and the opening plays)
	for _i in 300:
		if view._intro_shown:
			break
		await frames(1)
	check(view._intro_shown and view._intro_t < 0.2, "the opening waits for the loading screen")
	await seconds(0.5)
	check(main.get_node_or_null("Loading") == null, "the loading screen gone")
	await seconds(0.7)
	var close := view.camera.global_position.distance_to(view.pivot.global_position)
	var behind := (view.camera.global_position - view.pivot.global_position).dot(view.pivot.global_basis.z)
	check(view._clip == "PickUp_Table" and close < 3.5 and behind < 0.0 and not main.get_node("HUD").visible,
		"taking the lamp off the drum, the camera close behind (%.1f m), no buttons" % close)
	# (user request: the hand on the lamp before it comes off the drum, then
	# a strike at its glass, the glow only once it's lit)
	var gap_at_grab := INF
	while not view._intro_grabbed and view._intro_t >= 0.0:
		gap_at_grab = view._intro_gap
		await frames(1)
	check(view._intro_grabbed and gap_at_grab < RunView3D.INTRO_TOUCH + 0.02,
		"the lamp taken only with the hand on it (%.3f m)" % gap_at_grab)
	while view._intro_t >= 0.0 and view._intro_t < float(RunView3D.INTRO.light_from) + 0.1:
		await frames(1)
	check(not view.lamp_lit(), "not lit yet while the hand strikes")
	while view._intro_t >= 0.0 and view._intro_t < float(RunView3D.INTRO.light_at) + 0.4:
		await frames(1)
	var held := view._held_light()
	var glow_mat := RunView3D.lamp_glow(held, RunView3D.LAMP_FLAME) if held != null else null
	check(view.lamp_lit() and glow_mat != null and float(glow_mat.get_shader_parameter("glow")) > 0.0,
		"lit: the glass glows")
	var faces := (view.camera.global_position - view.pivot.global_position).dot(view.pivot.global_basis.z)
	check(view._intro_grabbed and faces > 0.0, "lighting it: the camera round in front, at the lamp")
	# (user request, round 3: then straight out - no turning round)
	var yaw_lit: float = view._yaw
	var swung := 0.0
	var drift := 0.0
	var screen := view.get_viewport().get_visible_rect().size
	while view._intro_t >= 0.0:
		swung = maxf(swung, absf(angle_difference(yaw_lit, view._yaw)))
		# (user report: drawing out, the traveller slid off to the bottom
		# right - kept near the middle of the frame now)
		var seen := view.camera.unproject_position(view.pivot.global_position + Vector3(0, 0.8, 0))
		drift = maxf(drift, ((seen - screen * 0.5) / screen).length())
		await frames(1)
	check(swung < 0.05, "no turn after lighting it (%.2f rad)" % swung)
	check(drift < 0.2, "drawing out, the traveller kept near the middle (%.2f of the screen at most)" % drift)
	await seconds(0.2)
	var far := view.camera.global_position.distance_to(view.pivot.global_position)
	check(view._intro_t < 0.0 and far > close + 2.0 and main.get_node("HUD").visible,
		"the camera back out (%.1f m), the buttons back" % far)
	RunView3D.intro = false
	# An eye: its way on the ground, named, and the eye over the head.
	Profile.storage["eyeball"] = 1
	Profile.to_bag("eyeball", 1)
	check(player().use_item("eyeball"), "the eye used")
	await frames(4)
	check(view._eye_label.visible and view._eye_label.text.begins_with("渡石"), "the way shown: %s" % view._eye_label.text)
	check(view._eye_sprite != null, "the true eye over the head")
	await seconds(TrueEye.TIME + 0.3)
	check(view._eye_sprite == null, "the eye gone again")
	# Walked, the lamp swings in the hand, its light with it.
	var biggest := 0.0
	var lights := []
	for _i in 90:
		player()._move_joystick.output = Vector2(0.6, 0.0)
		await frames(1)
		biggest = maxf(biggest, view.light_swing().length())
		lights.append(view._lamp.global_position - view.pivot.global_position)
	player()._move_joystick.output = Vector2.ZERO
	var spread := 0.0
	for l in lights:
		spread = maxf(spread, (l - lights[0]).length())
	check(biggest > 0.05 and spread > 0.04, "walking: the lamp swings (%.2f rad), its light moves (%.2f m)" % [biggest, spread])
	# (user request: an unlit lamp, or one with no fuel, hangs at the hip)
	var lantern: Lantern = player().get_node("Lantern")
	lantern.lit = false
	await seconds(RunView3D.STOW_TIME + 0.3)
	check(view._lamp_in == 0.0 and not view.lamp_lit(), "unlit: the lamp hung at the hip")
	# (user request, round 3: relit by hand - taken up, the other hand
	# striking at its glass - then held)
	key(KEY_L, true)
	await seconds(Lantern.RELIGHT_DURATION * 0.6)
	check(not lantern.lit and view._relight > 0.9 and view._lamp_in > 0.9 and view._ik.influence > 0.9,
		"relighting: lamp up in the hand, the other at its glass")
	await seconds(Lantern.RELIGHT_DURATION * 0.5 + 0.2)
	key(KEY_L, false)
	await seconds(RunView3D.STOW_TIME + 0.4)
	check(lantern.lit and view._lamp_in == 1.0 and view._relight == 0.0, "lit again: back in the hand")
	# (and the fuel box's button puts it straight out)
	var energy = main.get_node("HUD/Panel/EnergyView")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = energy.OUT_BUTTON.get_center()
	energy._gui_input(tap)
	await seconds(RunView3D.STOW_TIME + 0.3)
	check(not lantern.lit and view._lamp_in == 0.0, "熄燈: out at a tap, hung at the hip")
	lantern.lit = true
	await seconds(RunView3D.STOW_TIME + 0.3)
	# User request: the big ghost is a dragon now - a skeleton, its clip by
	# what it's doing, a green lantern in its hand, its light from it.
	var bg = main.get_node("BigGhost")
	bg.set_physics_process(false)
	bg.global_position = player().global_position + Vector2(-110, -40)
	bg.mode = bg.Mode.WANDER
	await seconds(1.5)
	var c: Dictionary = view._creatures.get(bg, {})
	check(c.get("kind") == "dragon" and c.has("lamp") and c.anim != null, "the big ghost shown as the dragon, lantern and all")
	var rig: DragonRig = c.get("rig")
	check(c.get("clip") == "Idle_Lamp" and (c.node as Node3D).find_children("*", "EarTailSway", true, false).size() == 1
		and rig != null and rig.spread == 0.0, "standing, the traveller near: the lantern held up, its tail swaying, its wings folded")
	# (user request: the lantern down at its side when no one's near)
	bg.global_position = player().global_position + Vector2(-RunView3D.DRAGON_NOTICE * RunView3D.PX - 120, 0)
	await seconds(1.5)
	check(c.clip == "Idle", "no one near: the lantern down (%s)" % c.clip)
	bg.global_position = player().global_position + Vector2(-110, -40)
	await seconds(1.5)
	var hand: Vector3 = (c.hand as Node3D).global_position
	var bail: Vector3 = (c.lamp as Node3D).global_transform * CharacterRig.LAMP_BAIL
	check(hand.distance_to(bail) < 0.05, "the lantern hangs from its hand (%.2f m)" % hand.distance_to(bail))
	var glow: OmniLight3D = view._lights.get(bg.lamp_light)
	var flame: Vector3 = (c.lamp as Node3D).get_node("Flame").global_position
	check(glow != null and glow.global_position.distance_to(flame) < RunView3D.DRAGON_LIGHT_OFF + 0.01
		and glow.light_color.g > glow.light_color.r, "its green light from the lantern (a little off its body)")
	# Holding the traveller: its wings open - and its body kept out of
	# theirs, however near the 2D one is (user request: no clipping).
	bg.global_position = player().global_position + Vector2(6, 3)
	bg.mode = bg.Mode.GRAB
	await seconds(0.6)
	var apart := Vector2((c.node as Node3D).global_position.x - view.pivot.global_position.x,
		(c.node as Node3D).global_position.z - view.pivot.global_position.z).length()
	check(c.clip == "Grab" and rig.spread == 1.0 and apart > RunView3D.DRAGON_ROOM - 0.05,
		"grabbing: Grab, wings open, held off the traveller (%.2f m)" % apart)
	bg.mode = bg.Mode.ASLEEP
	bg.set_physics_process(true)
	_restore_profile(kept)
	await frames(1)
