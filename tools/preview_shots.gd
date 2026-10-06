extends SceneTree
## Controlled captures of the real player (sheet, rod, front layer) for
## review (user request, round 5: fixed bright light, camera and
## background; no passing creatures or effects):
##   godot --path . -s "$PWD/tools/preview_shots.gd" -- out=<dir> zoom=7 clips=cast,hold tiers=0
##       dirs=0,1,..7 frames=0,..7 variants=clean,marked,nofront,norod
## Everything in the scene but the player is hidden and stopped (map,
## critters, ghosts, fog, grade, vignette, the darkness tint, every light
## and the HUD), the clear colour is fixed (BG), and the player is lit by
## one fixed broad light (KEY, up-left, reading the normal maps) over a
## fixed ambient (AMBIENT) - the same light for every capture. Each job: clip, facing, frame, rod tier,
## variant:
##   clean    as the game draws it
##   marked   + the grip (green), the line's exit = held_rod.tip_position()
##            (yellow, where main.gd starts the fishing line) and the axis
##   nofront  without the front layer (BodyFront)
##   norod    without the rod (and so without the front layer)
## bend=<rad> (round 6, the candidate's rod bends while a fish is on): in
## hold, reel, fight and hold_run the rod bent that much toward a fish
## straight ahead (FISH_AHEAD px), as held_rod.gd bends it - fixed, not
## eased or shaken, so every capture of a cell is the same; jolt=1: the
## fight's yank frame jolted toward the fish as the game jolts it.
## character=<id>: the character travelling (Profile.CHARACTERS).
const BG := Color(0.72, 0.74, 0.70)
const AMBIENT := Color(0.78, 0.78, 0.80)
const KEY_ENERGY := 0.85
const KEY_OFFSET := Vector2(-90, -120)
const KEY_HEIGHT := 110.0
const CLIPS := ["idle", "run", "cast", "hold", "busy", "reel", "fight", "hold_run"]
const BENT := ["hold", "reel", "fight", "hold_run"]
const FISH_AHEAD := 150.0
## Facing (sheet column) -> the way it faces on screen.
const FACING := [Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)]

var args := {}
var main: Node
var player: Node2D
var body: Sprite2D
var rod: Node2D
var front: Sprite2D
var marks: Node2D
var queue := []
var step := 0
var wait := 0
var started := false


class Marks extends Node2D:
	var rod: Node2D

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if rod == null or not rod.visible:
			return
		var g: Vector2 = to_local(rod.global_position)
		var t: Vector2 = to_local(rod.tip_position())
		draw_line(g, t, Color(1, 0.1, 0.1, 0.9), 0.4)
		draw_circle(g, 1.2, Color(0.1, 1, 0.2, 0.9))
		draw_circle(t, 1.0, Color(1, 0.9, 0.1, 0.95))


func _list(key: String, default: String) -> Array:
	return args.get(key, default).split(",")


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	seed(int(args.get("seed", "5")))
	# character=<id>: who's travelling (user request: the four animals in
	# the game; Profile.CHARACTERS) - for this capture only, not saved.
	# (after the Profile's own save is read in)
	if args.has("character"):
		var profile: Node = root.get_node("Profile")
		var id: String = args.character
		if profile.is_node_ready():
			profile.character = id
		else:
			profile.ready.connect(func(): profile.character = id, CONNECT_ONE_SHOT)
	RenderingServer.set_default_clear_color(BG)
	change_scene_to_file("res://scenes/main.tscn")


func _quiet() -> void:
	# main itself too: its camera framing eases the zoom back to the game's
	# every frame (main.gd _update_camera), so the view drifted between
	# setting a job up and capturing it
	main.set_process(false)
	main.set_physics_process(false)
	# everything but the player: hidden and stopped
	for n in main.get_children():
		if n == player:
			continue
		if n is CanvasItem:
			n.visible = false
		elif n is CanvasLayer:
			n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
	# the darkness tint fixed (its breathing stopped with the rest)
	var dark: CanvasModulate = main.get_node_or_null("Darkness")
	if dark != null:
		dark.visible = true
		dark.color = AMBIENT
	var key := PointLight2D.new()
	var g := GradientTexture2D.new()
	g.width = 64
	g.height = 64
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color.WHITE)
	g.gradient = grad
	key.texture = g
	key.texture_scale = 40.0
	key.energy = KEY_ENERGY
	key.height = KEY_HEIGHT
	key.position = KEY_OFFSET
	key.process_mode = Node.PROCESS_MODE_ALWAYS
	player.add_child(key)
	# the player's own extras and lights
	for n in player.get_children():
		if n is Light2D:
			n.enabled = false
			n.visible = false
		elif n.name in ["CastGuide", "FacingIndicator"]:
			n.visible = false
	# every CanvasLayer anywhere (a hidden Node2D doesn't hide the layers
	# under it: the atmosphere's grade and breathing vignette live there)
	for n in root.find_children("*", "CanvasLayer", true, false):
		n.visible = false


func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	if not started:
		step += 1
		if step == 5:
			root.get_node("GameState").start_run()
		if step == 40:
			main = current_scene
			player = main.get_node("Player")
			body = player.get_node("Body")
			rod = player.get_node("Rod")
			front = player.get_node_or_null("BodyFront")
			body.set_process(false)
			player.set_physics_process(false)
			player.process_mode = Node.PROCESS_MODE_DISABLED
			body.process_mode = Node.PROCESS_MODE_DISABLED
			rod.process_mode = Node.PROCESS_MODE_ALWAYS
			if front != null:
				front.process_mode = Node.PROCESS_MODE_ALWAYS
			_quiet()
			var cam: Camera2D = player.get_node("Camera2D")
			cam.process_mode = Node.PROCESS_MODE_ALWAYS
			cam.position_smoothing_enabled = false
			marks = Marks.new()
			marks.rod = rod
			marks.z_index = 10
			marks.process_mode = Node.PROCESS_MODE_ALWAYS
			player.add_child(marks)
			for tier in _list("tiers", "0"):
				for c in _list("clips", "cast,hold,hold_run,reel,fight"):
					for d in _list("dirs", "0,1,2,3,4,5,6,7"):
						for f in _list("frames", "0,1,2,3,4,5,6,7"):
							for m in _list("variants", "clean,marked"):
								queue.append([int(tier), c, int(d), int(f), m])
			started = true
		return false
	if queue.is_empty():
		return true
	var job: Array = queue[0]
	if wait == 0:
		var cam2: Camera2D = player.get_node("Camera2D")
		cam2.zoom = Vector2.ONE * float(args.get("zoom", "7"))
		cam2.reset_smoothing()
		root.get_node("Profile").rod_tier = job[0]
		rod._apply_tier()
		var clip: int = CLIPS.find(job[1])
		body.clip = clip
		body.dir = job[2]
		body.frame_in_clip = job[3]
		var row: int = clip * 8 + job[2]
		var rows_half: int = 32
		body.frame = (row % rows_half) * body.hframes + (row / rows_half) * 8 + job[3]
		var v: String = job[4]
		body.position = Vector2(0, 10)
		if args.has("bend") and rod.has_method("bend_toward"):
			rod.process_mode = Node.PROCESS_MODE_DISABLED
			var amount := float(args.bend) if job[1] in BENT else 0.0
			var fish: Vector2 = player.global_position + FACING[job[2]].normalized() * FISH_AHEAD
			var vis: Dictionary = body.get_script().get_script_constant_map()
			var held: Dictionary = rod.get_script().get_script_constant_map()
			if job[1] == "fight" and job[3] == vis.get("YANK_FRAME", -1):
				amount += held.get("BEND_YANK", 0.0)
				if args.get("jolt", "") == "1":
					body.position += FACING[job[2]].normalized() * vis.get("YANK_JOLT", 0.0)
			rod.bend = 0.0
			rod.place(0.0)
			rod.bend = rod.bend_toward(fish, amount)
			rod.place(0.0)
		marks.visible = v.begins_with("marked")
		rod.self_modulate.a = 0.0 if v.begins_with("norod") else 1.0
		if front != null:
			front.self_modulate.a = 0.0 if v.begins_with("nofront") or v.begins_with("norod") else 1.0
		wait = 1
		return false
	wait += 1
	if wait < int(args.get("settle", "4")):
		return false
	var img := root.get_texture().get_image()
	var c := img.get_size() / 2
	var half := int(args.get("half", "130"))
	var up := int(args.get("up", "40"))
	img = img.get_region(Rect2i(c.x - half, c.y - half - up, half * 2, half * 2))
	img.save_png("%s/t%d_%s_d%d_f%d_%s.png" % [args.out, job[0], job[1], job[2], job[3], job[4]])
	queue.pop_front()
	wait = 0
	return false
