extends Node

## The scenarios run by tests/run_tests.gd: each loads the real game scene,
## plays out a scenario (scripted input, the real game logic) and checks
## the outcome. Kept apart from run_tests.gd so it can use the game's
## classes and autoloads (a -s script is compiled before those exist).

const TESTS := [
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
	"test_lure_retrieve",
	"test_fish_by_style",
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


func _fresh_game(rng_seed := 7) -> void:
	seed(rng_seed)
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
		check(get_tree().get_nodes_in_group("walkways").is_empty(), "seed %d: no wooden docks in town" % s)
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
		check(get_tree().get_nodes_in_group("walkways").is_empty(), "seed %d: no docks on the beach" % s)
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
	"oak_tree", "palm_tree", "pine", "rock", "twisted_tree", "props", "beach_palm", "ruins"]
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
		"amb_rain", "amb_wind", "amb_swamp", "amb_jungle", "amb_surf", "music_day", "music_night"]
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
	var loop := Sfx.stream("amb_rain") as AudioStreamWAV
	check(loop != null and loop.loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambience loops")


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
	# Close enough that it notices (not left to where it wanders).
	bg.global_position = player().global_position + Vector2(50, 0)
	bg.mode = bg.Mode.WANDER
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
