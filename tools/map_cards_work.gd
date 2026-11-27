extends "res://tests/scenarios.gd"
## tools/map_cards.gd's work: see there.

const Audit := preload("res://tests/overlap_audit.gd")
## (the maps without a card yet, as DepartChooser.MAPS has them)
const THEMES := ["city", "countryside", "japan", "england", "china", "adobe"]
const CARD := Vector2i(400, 225)
## Where the traveller may stand: this far back from a pond's edge (px), the pond ahead.
const BACK := 60.0
## What's in view ahead of a place (px): from this near to this far up the screen, this wide at its
## nearest and this much wider for each px further.
const AHEAD := Vector2(120.0, 1400.0)
const WIDE := 160.0
const WIDEN := 0.6
## The camera: this far behind and above the traveller (m), looking at this point ahead of them.
const CAM_FROM := Vector3(0.0, 2.6, 4.4)
const CAM_AT := Vector3(0.0, 1.0, -7.0)
const CAM_FOV := 50.0
## The picture's brightness, contrast and saturation (Image.adjust_bcs).
const LIFT := Vector3(1.35, 1.08, 1.05)


func _run() -> void:
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	Campaign.dev_all_open = true
	var want := _arg("THEMES")
	for theme in (want.split(",") if want != "" else PackedStringArray(THEMES)):
		await _card(theme)
	get_tree().quit()


## A setting from the command line (KEY=value after --) or the environment.
func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return OS.get_environment(key)


func _card(theme: String) -> void:
	seed(int(_arg("SEED")) if _arg("SEED") != "" else 11)
	Campaign.free_events = false
	camp().clear()
	gs.reset_run()
	gs.last_return = ""
	camp().begin_free([], theme)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	for _i in 900:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	await frames(30)
	still_ghosts()
	var view: RunView3D = RunView3D.active
	var spot := _spot(view)
	var p := player()
	var lantern := p.get_node_or_null("Lantern")
	if lantern != null:
		lantern.lit = true
		lantern.fuel = lantern.max_fuel
	await put(spot)
	p.aim_dir = Vector2.UP
	await frames(90)
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	# (as the first six cards: from behind the traveller and a little above, looking out over the
	# pond to what's beyond it)
	var me: Vector3 = view.pivot.global_position
	var cam := Camera3D.new()
	view.add_child(cam)
	cam.global_position = me + CAM_FROM
	cam.look_at(me + CAM_AT, Vector3.UP)
	cam.fov = CAM_FOV
	cam.make_current()
	await frames(6)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	# (16:9, the middle of it, then the card's size)
	var h := mini(img.get_height(), img.get_width() * 9 / 16)
	var w := h * 16 / 9
	img = img.get_region(Rect2i((img.get_width() - w) / 2, (img.get_height() - h) / 2, w, h))
	img.resize(CARD.x, CARD.y, Image.INTERPOLATE_LANCZOS)
	# (lifted a little, as the first six read: a night lit by the traveller's lamp, not lost in it)
	img.adjust_bcs(LIFT.x, LIFT.y, LIFT.z)
	var path := "res://assets/ui/depart/map_%s.png" % theme
	img.save_png(path)
	print("CARD %s: %s, the traveller at %s" % [theme, path, str(spot)])


## Where the traveller stands for the picture: back from a pond's near edge, on open dry ground, the
## pond ahead of them up the screen - the place with the most of the village in view beyond it
## (buildings; a bridge counted twice).
func _spot(view: RunView3D) -> Vector2:
	var seen := []
	for t in Audit.things(get_tree(), view):
		if t.kind in ["building", "bridge"]:
			seen.append([t.c, 2.0 if t.kind == "bridge" else 1.0])
	var best := MapGenerator.SPAWN_POS
	var most := -1.0
	for zone in main.get_tree().get_nodes_in_group("water_zones_common"):
		for dir in [Vector2.DOWN, Vector2(-0.5, 1.0).normalized(), Vector2(0.5, 1.0).normalized()]:
			var p: Vector2 = (zone as WaterZone).shore_point(dir) + dir * BACK
			if Ripple.water_at(get_tree(), p) != null or not Solids.is_free(get_tree(), p, 14.0):
				continue
			if not Rect2(Vector2(120, 120), Vector2(Player.WORLD_WIDTH - 240, Player.WORLD_HEIGHT - 240)).has_point(p):
				continue
			var score := 0.0
			for s in seen:
				var d: Vector2 = (s[0] as Vector2) - p
				var up := -d.y
				if up > AHEAD.x and up < AHEAD.y and absf(d.x) < WIDE + up * WIDEN:
					score += float(s[1])
			if score > most:
				most = score
				best = p
	return best
