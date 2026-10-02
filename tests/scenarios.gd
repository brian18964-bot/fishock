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
	"test_map_generation",
	"test_all_themes",
	"test_ruined_town",
	"test_beach_sea",
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
	"test_lure_retrieve",
	"test_fish_by_style",
	"test_main_menu",
	"test_catch_details",
	"test_warehouse_and_bag",
	"test_lure_throw_and_drops",
	"test_hud_top",
	"test_bag_drag_out",
	"test_fish_tank",
	"test_camp_spirit_and_tents",
	"test_camp_life",
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
	"test_desert_bones",
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


func _fresh_game(rng_seed := 7) -> void:
	seed(rng_seed)
	# The plain free run unless a test plays a level.
	camp().clear()
	gs.reset_run()
	# A run an earlier test ended isn't one to come home from.
	gs.last_return = ""
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


## Every map style builds: trees, rocks and bushes from its families, its
## ground, light and pond colour.
func test_all_themes() -> void:
	var gen_script = load("res://scripts/map_generator.gd")
	for theme in gen_script.THEMES:
		gen_script.forced_theme = theme
		await _fresh_game()
		var gen = main.get_node("MapGenerator")
		check(gen.theme_name == theme, "%s: picked" % theme)
		var trees := of_script("tree.gd")
		var ok := trees.size() > 0
		for t in trees:
			ok = ok and t.sprite.texture != null
		check(ok, "%s: %d trees, all drawn" % [theme, trees.size()])
		var rocks := of_script("obstacle.gd")
		check(rocks.all(func(r): return r.sprite.texture != null), "%s: rocks drawn" % theme)
		var look: String = gen.theme.look
		var strays := {}
		for n in _all_nodes(main):
			if n is Sprite2D and n.texture is CanvasTexture and n.texture.diffuse_texture != null:
				var path: String = n.texture.diffuse_texture.resource_path
				var art := _art_look(path)
				if art != "" and art != look:
					strays[path.get_file()] = true
		check(strays.is_empty(), "%s (%s): no art of the other look %s" % [theme, look, str(strays.keys())])
		if gen.theme.has("shore_critters"):
			var kinds := {}
			for c in of_script("/critter.gd"):
				kinds[c.species] = true
			check(gen.theme.shore_critters.all(func(k): return kinds.has(k)), "%s: its shore creatures %s" % [theme, str(kinds.keys())])
		var floors: Array = gen.theme.floor.slice(0, 2)
		check(floors.all(func(f): return f.begins_with("lp_") == (look == "lowpoly")), "%s: its look's floor" % theme)
		var tint: Color = main.get_node("Darkness").tint
		check(tint == gen.theme.get("tint", Color.WHITE), "%s: its light" % theme)
		if gen.theme.has("water"):
			var zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
			var base: Color = zone._surface_material.get_shader_parameter("base_color")
			check(base.is_equal_approx(gen.theme.water.base), "%s: its pond colour" % theme)
	gen_script.forced_theme = ""
	# User decision: only the detailed look is dealt to players for now.
	var gen = main.get_node("MapGenerator")
	var dealt := {}
	for i in 400:
		dealt[gen._pick_theme()] = true
	check(dealt.keys().all(func(t): return gen_script.THEMES[t].look == "detailed"),
		"only detailed styles are played %s" % str(dealt.keys()))
	check(dealt.size() >= 8, "and all of them turn up (%d)" % dealt.size())


## User request: a ruined town, fishing in its flooded streets - its old
## gas station behind the spawn point, signals at the crossings. Its streets
## are painted into the ground (no wooden docks: user feedback); buildings line them, clear of the ponds,
## the landmarks and each other, their walls never rising over a road;
## wrecked cars stand on the roads; everything built is solid.
func test_ruined_town() -> void:
	var gen_script = load("res://scripts/map_generator.gd")
	for s in [7, 21, 99]:
		gen_script.forced_theme = "ruins"
		await _fresh_game(s)
		var gen = main.get_node("MapGenerator")
		var town: TownBuilder = gen.town
		check(town != null, "seed %d: a town was built" % s)
		if town == null:
			continue
		var streets := false
		for n in _all_nodes(main):
			if n is CanvasItem and n.material is ShaderMaterial and n.material.get_shader_parameter("streets_on"):
				streets = n.material.get_shader_parameter("streets") != null
		check(streets, "seed %d: streets painted into the ground" % s)
		var props := of_script("ruin_prop.gd")
		var buildings := props.filter(func(p): return p.entry.kind == "building")
		var wrecks := props.filter(func(p): return p.entry.kind == "wreck")
		check(buildings.size() >= 10, "seed %d: buildings line the streets (%d)" % [s, buildings.size()])
		check(wrecks.size() >= 5, "seed %d: wrecked cars (%d)" % [s, wrecks.size()])
		check(buildings.any(func(b): return b.entry.family == "gas_station"), "seed %d: the old gas station" % s)
		check(props.any(func(p): return p.entry.family == "traffic_light"), "seed %d: traffic signals" % s)
		var fixed := [MapGenerator.SPAWN_POS, main.get_node("Altar").global_position,
			main.get_node("EscapePoint").global_position]
		var bad := []
		for i in buildings.size():
			var b: RuinProp = buildings[i]
			var r := b.base_rect()
			for z in get_tree().get_nodes_in_group("water_zones"):
				if z.contains(r.get_center()):
					bad.append("%s in water" % b.entry.name)
			for f in fixed:
				# The gas station stands behind the spawn point's drums on purpose.
				if b.entry.family == "gas_station" and f == MapGenerator.SPAWN_POS:
					if r.grow(20.0).has_point(f):
						bad.append("gas station over the spawn point")
					continue
				if r.grow(TownBuilder.CLEAR_OF_FIXED - 1.0).has_point(f):
					bad.append("%s on a landmark" % b.entry.name)
			for j in range(i + 1, buildings.size()):
				if r.grow(-1.0).intersects(buildings[j].base_rect()):
					bad.append("%s overlaps %s" % [b.entry.name, buildings[j].entry.name])
			if town._hangs_over_road(b.entry, b.position):
				bad.append("%s over a road" % b.entry.name)
		check(bad.is_empty(), "seed %d: buildings placed clear %s" % [s, str(bad.slice(0, 4))])
		var off_road := wrecks.filter(func(w): return not town.road_rects.any(
			func(r: Rect2): return r.grow(4.0).has_point(w.position)))
		check(off_road.is_empty(), "seed %d: the cars are on the roads" % s)
		check(props.all(func(p): return p.get_children().any(func(c): return c is CollisionPolygon2D)),
			"seed %d: all solid" % s)
		check(props.all(func(p): return p.sprite.texture != null), "seed %d: all drawn" % s)
		var town_ways := get_tree().get_nodes_in_group("walkways")
		check(town_ways.all(func(w): return w is Jetty and w.style == "concrete"),
			"seed %d: no wooden docks in town - concrete platforms" % s)
		check(not town_ways.is_empty(), "seed %d: a platform out over a pond" % s)
	gen_script.forced_theme = ""


## User request: the beach's water is the sea - a big sweep of it along
## one side, no docks; the rocky coast with rock ridges running in from
## it, the palm beach with its palms along the sand; the spawn point dry. And every leafless tree in one weathered colour.
func test_beach_sea() -> void:
	var gen_script = load("res://scripts/map_generator.gd")
	for run in [[7, "beach_rocky"], [21, "beach_sandy"], [99, "beach_rocky"], [5, "beach_sandy"]]:
		var s: int = run[0]
		gen_script.forced_theme = run[1]
		await _fresh_game(s)
		var gen = main.get_node("MapGenerator")
		var commons := get_tree().get_nodes_in_group("water_zones_common")
		var wet := 0
		var total := 0
		for x in range(20, int(Player.WORLD_WIDTH), 40):
			for y in range(20, int(Player.WORLD_HEIGHT), 40):
				total += 1
				if commons.any(func(z): return z.contains(Vector2(x, y))):
					wet += 1
		check(float(wet) / total > 0.25, "seed %d: the sea covers a good part of the map (%d%%)" % [s, 100 * wet / total])
		var ways := get_tree().get_nodes_in_group("walkways")
		check(ways.all(func(w): return w is Jetty), "seed %d: no wooden docks on the beach" % s)
		# User request: a rock jetty out into the deep instead.
		check(not ways.is_empty(), "seed %d: a rock jetty out into the sea" % s)
		for j in ways:
			var tip: Vector2 = j.position - j.dir * (j.half_length - 6.0)
			check(Dock.on_walkway(get_tree(), tip) and commons.any(func(z): return z.contains(tip)),
				"seed %d: its end stands over the sea" % s)
		if gen.theme.get("ridges", 0) > 0:
			var big := of_script("obstacle.gd").filter(func(r): return r.size > 1.2)
			check(big.size() >= 10, "seed %d: rock ridges (%d boulders)" % [s, big.size()])
		if gen.theme.get("beach_trees", 0) > 0:
			var palms := of_script("tree.gd").filter(func(t): return gen._sea_distance(t.position) < gen.theme.coast.sand_width)
			check(palms.size() >= 12, "seed %d: palms along the beach (%d)" % [s, palms.size()])
		check(not get_tree().get_nodes_in_group("water_zones").any(
			func(z): return z.distance_to_edge(MapGenerator.SPAWN_POS) < 80.0), "seed %d: the spawn point is dry" % s)
	gen_script.forced_theme = ""
	var colours := []
	for name in ["dead_tree/dead_tree_%d", "bare_tree/bare_tree_%d"]:
		for i in range(1, 11 if name.begins_with("bare") else 6):
			var img: Image = load("res://assets/sprites/%s_55deg_albedo.png" % (name % i)).get_image()
			if img.is_compressed():
				img.decompress()
			var sum := Vector3.ZERO
			var n := 0
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					var c := img.get_pixel(x, y)
					if c.a > 0.5:
						sum += Vector3(c.r, c.g, c.b)
						n += 1
			colours.append(sum / maxf(n, 1))
	var spread := 0.0
	for a in colours:
		for b in colours:
			spread = maxf(spread, (a - b).length())
	check(spread < 0.12, "leafless trees all one colour (spread %.2f)" % spread)


## User feedback: the finely drawn and the flat-coloured art don't mix.
## Which look a scenery texture belongs to ("" for the shared art - the
## player, the landmarks, animals, lily pads).
const DETAILED_DIRS := ["bare_tree", "birch_tree", "bush", "dead_tree", "ground_cover", "leafy_tree", "maple_tree",
	"oak_tree", "palm_tree", "pine", "rock", "twisted_tree", "props", "beach_palm", "ruins", "bones"]
const LOWPOLY_DIRS := ["autumn_tree", "bonsai_tree", "bush2", "conifer", "jungle_tree", "lowpoly", "meadow_tree",
	"snow_tree", "rock2"]


func _art_look(path: String) -> String:
	var dir := path.get_base_dir().get_file()
	var file := path.get_file()
	if dir == "shore":
		return "" if file.begins_with("lilypads") else "detailed"
	if dir == "rock2" and (file.begins_with("boulder2_") or file.begins_with("sea_rock_")):
		return "detailed"
	if dir in DETAILED_DIRS:
		return "detailed"
	if dir in LOWPOLY_DIRS:
		return "lowpoly"
	return ""


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
		var spawn := Vector2(1200, 700)
		for z in main.get_tree().get_nodes_in_group("water_zones"):
			if z.distance_to_edge(spawn) < 80.0:
				wet += 1
		for z in main.get_tree().get_nodes_in_group("water_zones_common"):
			var has := false
			for w in main.get_tree().get_nodes_in_group("walkways"):
				if z.contains(w.walk_rect.get_center()) or z.distance_to_edge(w.walk_rect.get_center()) < 1.0:
					has = true
			if docked and not has:
				dockless += 1
	check(wet == 0, "the spawn point is on dry land on every map (%d wet)" % wet)
	check(dockless <= 4, "(nearly) every pond has a dock out into it (%d without)" % dockless)


## The generated catalog's textures and every sound the game asks for exist.
func test_catalog_and_sounds() -> void:
	var missing := []
	for table in [NatureCatalog.TREES, NatureCatalog.ROCKS, NatureCatalog.BUSHES]:
		for v in table:
			for key in ["albedo", "normal"]:
				if not ResourceLoader.exists(v[key]):
					missing.append(v[key])
	check(missing.is_empty(), "catalog textures all there %s" % str(missing))
	var sounds := ["cast", "plop", "nibble", "splash", "splash_small", "reel_loop", "creak_loop", "snap",
		"perfect", "catch", "fail", "ignite", "extinguish", "flash", "step_soft", "step_hard", "step_wood",
		"step_snow", "chain_loop", "whisper", "moan", "emerge", "cage", "heartbeat_loop", "offering",
		"rock_flip", "tap", "swipe_hit", "flop", "thunder", "escape", "amb_night", "amb_day", "amb_water",
		"amb_rain", "amb_wind", "amb_swamp", "amb_jungle", "amb_surf", "music_day", "music_night",
		"ui_click", "ui_open", "ui_close", "coins", "amb_camp", "camp_crickets_loop", "music_camp", "chop",
		"gunshot"]
	var lost := sounds.filter(func(n): return Sfx.stream(n) == null)
	check(lost.is_empty(), "every sound loads %s" % str(lost))
	var toggle: SoundToggle = null
	for c in main.get_children():
		if c is SoundToggle:
			toggle = c
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = SoundToggle.CENTER
	var was: bool = Sfx.muted
	toggle._input(tap)
	check(Sfx.muted != was, "the speaker mutes")
	toggle._input(tap)
	check(Sfx.muted == was, "and unmutes")
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
	for c in of_script("/critter.gd"):
		c._dir = Art.facing8(Vector2.RIGHT, 0)
		c.velocity = Vector2.ZERO
		c._animate(0.1)
		var sprite: Sprite2D = c.sprite
		check(sprite.flip_h and sprite.frame < sprite.hframes * sprite.vframes,
			"%s facing right: mirrored, frame %d of %d" % [c.species, sprite.frame, sprite.hframes * sprite.vframes])
		c._dir = Art.facing8(Vector2.LEFT, 0)
		c._animate(0.1)
		check(not sprite.flip_h, "%s facing left: as rendered" % c.species)
	# User request (beach): crabs walk side-on, and never turn up at random.
	var crab: Critter = load("res://scenes/critter.tscn").instantiate()
	crab.species = "crab"
	main.add_child(crab)
	crab.global_position = player().global_position + Vector2(200, 0)
	crab._mode = crab.Mode.WANDER
	crab._target = crab.global_position + Vector2(300, 0)
	await frames(20)
	check(crab._dir == 0 or crab._dir == 4, "a crab walking right faces across its way (facing %d)" % crab._dir)
	var dealt := {}
	for i in 200:
		dealt[crab._pick_species()] = true
	check(not dealt.has("crab"), "crabs aren't dealt at random")
	crab.queue_free()


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
	player()._set_state(Player.State.IDLE)


## User request: each map style has its fish - the shared freshwater ones,
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
	var gen_script = load("res://scripts/map_generator.gd")
	for theme in gen_script.STYLES.values().map(func(st): return st.themes).reduce(func(a, b): return a + b, []):
		check(FishData.THEME_WATERS.has(theme), "%s: has waters" % theme)
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
	# The map sets the waters.
	gen_script.forced_theme = "beach_sandy"
	await _fresh_game()
	check(FishData.waters == "sea", "a beach fishes the sea")
	gen_script.forced_theme = "ruins"
	await _fresh_game()
	check(FishData.waters == "ruins", "the ruined town fishes its own")
	gen_script.forced_theme = ""
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
	Profile.bag.append({"id": "rod_4", "count": 1, "cell": Vector2i(3, 2), "found": true})
	Profile.lose_found_gear()
	check(Profile.bag_count("rod_4") == 0 and Profile.bag_count("rod_0") == 1, "dying loses gear found on the map, not what was brought")
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
	ev._set_from(ev.BAR.position.x)
	check(is_equal_approx(lantern.brightness, Lantern.MIN_BRIGHTNESS), "the panel sets it")
	check(not main.get_node("HUD/Panel/MessageLabel").visible, "no narrating text")
	lantern.fuel = lantern.max_fuel
	lantern.brightness = 0.75


## User request (fish tank): fish carried out of a run go in the tank; the
## main screen says so; the tank page shows them swimming, lists them, and
## sells them.
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
	check(Profile.tank.size() == 2 and GameState.carried_fish.is_empty(), "two in the tank, the rotten one thrown away")
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
	await seconds(1.2)
	check(not is_instance_valid(cover) and TitleScreen.sound_unlocked, "a tap lets the sound in")
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
	# A tap on the backpack (by the crate) opens the warehouse too.
	var pack: Node3D = camp.hotspots.warehouse.parts.filter(func(p): return p[0].name == "backpack")[0][0]
	var at: Vector2 = camp.camera.unproject_position(pack.global_position + Vector3(0, 0.25, 0)) / title.RENDER_SCALE
	check(title.spot_at(at) == "warehouse", "the backpack is the warehouse's too")
	for down in [true, false]:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = down
		tap.position = at
		title._on_home_input(tap)
	await seconds(0.8)
	var bag_page: Control = title._page
	check(bag_page != null and bag_page.find_child("WarehouseWindow", true, false) != null, "tapping the backpack opens the warehouse")
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


## User request (Camp v2): the merchant's tea and rations lift the spirit
## there and then; the tents are earned by achievements (escapes, gold
## spent, the fish log, a legend) and pitched from the equipment page's
## 營地 tab, and the camp's tent changes with it.
func test_camp_spirit_and_tents() -> void:
	var saved := Profile.snapshot()
	Profile.load_data({"gold": 100, "spirit": 50.0})
	check(Profile.buy_snack("tea") and is_equal_approx(Profile.spirit, 70.0) and Profile.gold == 85, "tea: +20 spirit for 15 gold")
	check(Profile.buy_snack("rations") and is_equal_approx(Profile.spirit, 100.0) and Profile.gold == 55, "rations: up to full")
	check(not Profile.buy_snack("tea") and Profile.gold == 55, "nothing bought when the spirit's full")
	check(int(Profile.stats.gold_spent) == 45, "what's spent is counted (%d)" % int(Profile.stats.gold_spent))
	var loaded := Profile.snapshot()
	Profile.load_data(loaded)
	check(is_equal_approx(Profile.spirit, 100.0) and int(Profile.stats.gold_spent) == 45, "spirit and stats saved")
	# The shop sells them, on its 道具 tab.
	var shop: Control = load("res://scenes/shop.tscn").instantiate()
	get_tree().root.add_child(shop)
	await frames(2)
	shop._show_tab("item")
	await frames(1)
	check(shop.find_child("Card_tea", true, false) != null and shop.find_child("Card_rations", true, false) != null,
		"the merchant sells tea and rations")
	Profile.add_spirit(-40.0)
	(shop.find_child("Card_tea", true, false) as Button).pressed.emit()
	await frames(1)
	var have: Button = shop.find_child("Have", true, false)
	check(have != null, "a lowered spirit can have tea")
	if have != null:
		have.pressed.emit()
		await frames(1)
	check(is_equal_approx(Profile.spirit, 80.0) and Profile.gold == 40, "had at once (spirit %d)" % Profile.spirit)
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


## User request (Camp v2): the character lives at the camp by its spirit -
## busy (all of it, dancing over 90), tired, worn (mostly sitting), spent
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
		0: ["sit"], 1: ["sit", "trough", "warm", "stand"],
		2: ["sit", "crate", "trough", "lean", "lake", "merchant", "warm", "watch", "stand"],
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
	Profile.spirit = 95.0
	var busy := {}
	for _i in 200:
		life._choose()
		busy[life.activity] = true
	check(busy.has("dance") and busy.has("sit") and busy.has("tent"), "busy, it dances, mends and sits (%s)" % ", ".join(busy.keys()))
	check(not busy.has("chop") and not busy.has("gather"), "no chopping or carrying (dropped)")
	Profile.spirit = 80.0
	var danced := false
	for _i in 200:
		life._choose()
		danced = danced or life.activity == "dance"
	check(not danced, "no dancing under 90")
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
	# A tap: a wave when busy; worn out, a shake of the head.
	life._plan.clear()
	life._step = {}
	life.seated = false
	Profile.spirit = 80.0
	life.tap()
	check(life._step.get("do", "") == "face" and life._plan.size() >= 1 and life._plan[0].get("clip", "") == "Interact",
		"tapped, it turns and waves")
	Profile.spirit = 10.0
	life._plan.clear()
	life._step = {}
	life.tap()
	check(life._plan.size() >= 1 and life._plan[0].get("clip", "") == "Idle_No", "spent, it shakes its head")
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
		"it walks up to him, face to face, and he talks (%.2f m)" % gap.length())
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
	# Setting out: the lamp off the drum (lit, hanging from its fingers),
	# and the game fades in as it goes.
	Profile.spirit = 80.0
	title._setting_off = true
	title._on_solo()
	check(life.busy == "depart" and title._scene_piece == "depart", "出發夜釣 sets it off")
	var lamp: Node3D = camp.find_child("DrumLamp", true, false)
	var took := false
	for _i in 900:
		await frames(1)
		if not lamp.visible:
			took = true
			break
	check(took and camp.character.attachments.hand_l.get_child_count() == 1, "it takes the lamp from the drum")
	check(camp.character.find_child("LampLight", true, false) != null, "and it's lit")
	var done := {"gone": false}
	life.plan_done.connect(func(tag): done.gone = done.gone or tag == "depart")
	await seconds(0.6)
	var held: Node3D = camp.character.attachments.hand_l.get_child(0)
	var grip: Vector3 = camp.character._grip()
	var bail: Vector3 = held.global_transform * CharacterRig.LAMP_BAIL
	check(bail.distance_to(grip) < 0.02 and held.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.9,
		"the lamp hangs upright by its bail from the fingers (%.3f m off)" % bail.distance_to(grip))
	for _i in 240:
		if done.gone:
			break
		await frames(1)
	check(done.gone, "lamp in hand, off it goes (the game fades in)")
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
	check(life.busy == "wake" and life.rig.anim.assigned_animation == "LayToIdle", "back from a run lost, it wakes by the fire")
	await seconds(6.0)
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
		var size: Vector2 = camp().MAP_SIZES[r.map]
		check(is_equal_approx(Player.WORLD_WIDTH, size.x) and is_equal_approx(Player.WORLD_HEIGHT, size.y),
			"%s: the %s map" % [l.id, r.map])
		var gen: MapGenerator = main.get_node("MapGenerator")
		check(gen.theme_name == r.theme, "%s: its look (%s)" % [l.id, gen.theme_name])
		var rare := get_tree().get_nodes_in_group("water_zones_rare").size()
		var common := get_tree().get_nodes_in_group("water_zones_common").size()
		check(rare == int(r.ponds[1]), "%s: %d dark pond(s), got %d" % [l.id, int(r.ponds[1]), rare])
		if not gen.theme.get("sea", false) and int(r.ponds[0]) >= 0:
			check(common == int(r.ponds[0]), "%s: %d pond(s), got %d" % [l.id, int(r.ponds[0]), common])
		check(gs.quota_target == float(r.quota) and gs.day_duration == float(r.day), "%s: quota and day" % l.id)
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
	check(Player.WORLD_WIDTH < 1400.0 and gs.day_duration == 0.0, "a small map with no clock")
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
	check(is_equal_approx(gs.quota_target, 45.0) and is_equal_approx(gs.day_duration, 180.0), "貪念 and 急潮")
	var floating := get_tree().get_nodes_in_group("ghosts").filter(func(g): return not g is BigGhost).size()
	check(floating == 3, "群鬼: three floating ghosts (%d)" % floating)
	await frames(2)
	check(main.get_node("BigGhost").mode != BigGhost.Mode.ASLEEP, "早醒: the big ghost's up from the start")
	check(Player.WORLD_WIDTH == 2400.0, "the free run's full map")
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
	check(Player.WORLD_WIDTH < 1400.0, "on its small map")


## The profile's things as they are, to put back after a test that buys.
func _keep_profile() -> Dictionary:
	return {"gold": Profile.gold, "storage": Profile.storage.duplicate(true), "bag": Profile.bag.duplicate(true),
		"equipped": Profile.equipped.duplicate(true)}


func _restore_profile(kept: Dictionary) -> void:
	Profile.gold = kept.gold
	Profile.storage = kept.storage
	Profile.bag = kept.bag
	Profile.equipped = kept.equipped


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
	Profile.equipped["weapon"] = ""
	check(Profile.buy_weapon("hatchet"), "a hatchet bought")
	check(not Profile.buy_weapon("hatchet"), "only once")
	check(Profile.equip("hatchet") and Profile.weapon.get("chop", 0) == 2, "worn in the weapon slot, chops")
	check(Items.def("hatchet").slot == "weapon", "the weapon slot")
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
	check(spider.sprite.texture.diffuse_texture != null, "its colouring loads")
	var skins := {}
	for i in 40:
		spider.set_species("black_spider")
		skins[spider.skin] = true
	check(skins.size() >= 5, "colourings drawn at random (%d seen)" % skins.size())
	# Caught: two baits, and sometimes a bite.
	var poisoned := false
	for i in 30:
		seed(100 + i)
		p.poison_timer = 0.0
		var bait: int = p.bait_count
		p._catch_black_spider("黑蜘蛛", "蜘蛛")
		check(p.bait_count >= bait + 1, "bait for it")
		if p.poison_timer > 0.0:
			poisoned = true
			break
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
	Profile.equipped["weapon"] = ""
	var trees := main.get_tree().get_nodes_in_group("trees")
	check(not trees.is_empty(), "the map has trees")
	if trees.is_empty():
		_restore_profile(kept)
		return
	var tree: MapTree = trees[0]
	await put(tree.global_position + Vector2(20, 6))
	check(p.choppable_tree() == null, "no chopping bare-handed")
	Profile.equipped["weapon"] = "hatchet"
	check(p.choppable_tree() == tree, "a hatchet chops the tree in reach")
	check(p.interaction().get("verb", "") == "砍樹", "chopping offered at the tree")
	await tap(KEY_E)
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
	Profile.equipped["weapon"] = "knife"
	gs.add_carried_fish(fish())
	var carried: int = gs.carried_fish.size()
	p.water_ghost_timer = 0.0
	p.animal_attack("狼")
	check(gs.carried_fish.size() == carried, "the knife keeps the fish")
	check(p.water_ghost_timer <= Player.PARRY_DEBUFF_DURATION, "only a short stagger")
	Profile.equipped["weapon"] = ""
	p.water_ghost_timer = 0.0
	p.animal_attack("狼")
	check(gs.carried_fish.size() < carried, "bare-handed the fish is knocked loose")
	p.water_ghost_timer = 0.0
	# The pistol: a round a shot, the big ghost hears it.
	Profile.equipped["weapon"] = "glock"
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
	wolf.queue_free()
	_restore_profile(kept)
	await frames(1)


## User request: a desert map strewn with the animal carcasses - bones
## among the rocks (solid, never turned over), oases with their own fish,
## black spiders about the water.
func test_desert_bones() -> void:
	var gen_script = load("res://scripts/map_generator.gd")
	gen_script.forced_theme = "desert"
	await _fresh_game(5)
	gen_script.forced_theme = ""
	var gen = main.get_node("MapGenerator")
	check(gen.theme_name == "desert", "the desert picked")
	var bones := of_script("obstacle.gd").filter(func(r): return r.sprite.texture.diffuse_texture.resource_path.contains("/bones/"))
	check(bones.size() >= 3, "bones lie about (%d)" % bones.size())
	check(bones.all(func(b): return b.collision.polygon.size() > 0), "and are solid")
	var flips := of_script("flip_rock.gd")
	check(flips.all(func(f): return not f._visual.texture.diffuse_texture.resource_path.contains("/bones/")),
		"no bones among the rocks to turn")
	check(FishData.waters == "desert", "the oases have their own fish")
	var own: Array = FishData.STYLE_FISH.desert[0] + [FishData.STYLE_FISH.desert[1]]
	check(own.all(func(id): return FishData.FISH.has(id) and ResourceLoader.exists("res://assets/sprites/fish/%s.png" % id)),
		"each with its picture")
	var spiders := of_script("/critter.gd").filter(func(c): return c.species == "black_spider")
	check(not spiders.is_empty(), "black spiders about the water")
