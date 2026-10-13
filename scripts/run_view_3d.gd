class_name RunView3D
extends Node3D

## User request (after the 3D trial, scenes/proto3d.tscn): a whole run in
## true 3D - the lakeside forest (MapGenerator "forest_pine"), playable from
## start to end, fishing and all. The run itself doesn't change: every rule
## still lives in the 2D world (main.tscn - the player, the water, the
## fish, the ghosts, the camera's framing). This only shows it in 3D, the
## 2D world hidden under it (the screen's layers - the buttons, the bag,
## the fight panel - stay as they are):
##   the land     one painted mesh over the map, down under the water where
##                each pond is (WaterZone.depth), mud along the shores, a
##                rise of forest round the edge
##   the water    each pond's own surface (rare ones purple)
##   the props    the map's pines, rocks, bushes, plants, the stones that
##                turn over, docks and steps and boats as 3D models, where
##                the map put them
##   the rest     everything else the map shows - the animals, the ghosts,
##                the altar, the rune pillar, splashes - stood up as the same
##                pictures, facing the camera
##   the light    the map's lights as lights, the night's dark as the sky's
##   the traveller the character's 3D model (CharacterRig) acting out what
##                the 2D one shows (PlayerVisual: walking, running, the cast
##                wound with the charge, waiting, the bite, reeling, the
##                fight, the catch, its moves), the rod in hand, the line
##                out to a float on the water
##   the camera   up and behind at the trial's angle, as close as the 2D
##                one's zoom says and framed where it frames (main.gd)
## 2D world px -> metres: PX (the pictures' own density, Art.DENSITY's).

const PROTO := preload("res://scripts/proto3d.gd")
const PROTO_MODELS := "res://assets/models/proto3d/"
const PX := 27.108
## The theme it's for.
const THEME := "forest_pine"
const CAMERA_PITCH := 46.0
## How far back at the 2D camera's walking zoom (main.gd WALK_ZOOM); out
## with it when the shot has to take in the line.
const CAMERA_DISTANCE := 9.5
const CAMERA_FOV := 42.0
## The run's ground and water heights (m).
const WATER_Y := -0.12
const LAND_Y := 0.05
const DECK_Y := 0.32
## The ground grid (m) and how far past the map's edge it goes.
const CELL := 0.5
const MARGIN := 14.0
## Walking up to WALK_PACE m/s is the walk clip at its own pace; RUN_PACE
## the run's.
const WALK_PACE := 0.8
const RUN_PACE := 3.0
const TURN_RATE := 14.0
## Trees between the camera and the traveller: dithered out this close to
## the camera (m).
const FADE_NEAR := 5.5
const FADE_FAR := 8.6
const MOON_DIR := Vector3(0.35, 0.55, -1.0)
## User request (phones were slow): how much there is to draw. Scattered
## things in CHUNK m squares (each drawn only on screen), plants none past
## COVER_REACH m; the pines round the edge; the extra grass.
const CHUNK := 12.0
const LOW_SCALE := 0.7
const COVER_REACH := 34.0
const BORDER_TREES := 260
const EXTRA_GRASS := 1300
## The rod while fishing, as in the 2D pictures (tools/render_player.py
## ROD_ANGLES): per frame of the clip, degrees up from pointing straight
## ahead (90 straight up, 180 straight back), ROD_SIDE out to the side of
## the hand holding it. Other clips hold it as the hand has it.
const ROD_ANGLES := {
	PlayerVisual.CLIP_CAST: [30, 70, 115, 150, 115, 70, 30, 18],
	PlayerVisual.CLIP_CAST_SHORT: [30, 70, 115, 150, 115, 70, 30, 18],
	PlayerVisual.CLIP_HOLD: [18, 18.5, 19, 19.5, 20, 19.5, 19, 18.5],
	PlayerVisual.CLIP_REEL: [25, 26.5, 25, 23.5, 25, 26.5, 25, 23.5],
	PlayerVisual.CLIP_FIGHT: [50, 54, 56, 54, 50, 46, 44, 46],
	PlayerVisual.CLIP_HOLD_RUN: [25, 28, 25, 22, 25, 28, 25, 22],
	PlayerVisual.CLIP_BITE: [18, 13, 20, 12, 19, 16, 20, 18],
	PlayerVisual.CLIP_TUG: [20, 48, 72, 80, 78, 72, 64, 56],
	PlayerVisual.CLIP_CATCH: [56, 68, 78, 84, 82, 74, 60, 44],
}
const ROD_SIDE := 25.0
## How fast the rod follows its angle (1/s), the arm comes in to hold it
## (s), and how fully the arm's brought after it.
const ROD_FOLLOW := 22.0
const ROD_EASE_IN := 0.15
const ARM_FOLLOW := 1.0
## The camera's room round the traveller and the float when it frames
## them both (m).
const FRAME_ROOM := Vector2(3.6, 4.2)
const FRAME_EASE := 3.0
const MAX_DISTANCE := 30.0
## Dodging the buttons (_dodge_buttons): how far toward the hidden thing
## the view's aimed, how much further back, how fast.
const DODGE_SHIFT := 0.45
const DODGE_BACK := 0.25
const DODGE_RATE := 1.6
## (scripts whose nodes are shown here by models of their own; the rest of
## the map's pictures are stood up as they are)
const MODELLED := ["tree.gd", "bush.gd", "obstacle.gd", "ground_cover.gd", "dock.gd", "water_zone.gd",
	"flip_rock.gd", "silhouette_shadow.gd", "player.gd", "map_generator.gd", "light_twin.gd", "day_vision.gd",
	"ripple.gd", "atmosphere.gd", "weather_fx.gd"]

## Asked for by the way the run was set off (the journey's 3D button, the
## settings'): the run that's starting is in 3D, and the ones after it (a
## retry) - until back at the camp (leave()).
static var wanted := false
## The one showing now.
static var active: RunView3D
## (tests: "low" or "high" in place of the device's own)
static var quality := ""


## User request (phones were slow): on a phone, lighter - one pass of the
## moon's shadows, none from the lamp, no glow, the 3D drawn at
## LOW_SCALE of the screen's resolution (the buttons stay sharp).
static func low_end() -> bool:
	if quality != "":
		return quality == "low"
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())

var main: Node2D
var player: Player
var camera: Camera3D
var rig: CharacterRig
var pivot: Node3D
var built := false
var _env: Environment
var _moon: DirectionalLight3D
var _visual: PlayerVisual
var _lamp: OmniLight3D
var _float: Node3D
var _float_body: MeshInstance3D
var _line: MeshInstance3D
var _guide: MeshInstance3D
var _guide_label: Label3D
var _ring: MeshInstance3D
## 2D picture -> its stand-in; 2D light -> its 3D light.
var _sprites := {}
var _lights := {}
## New nodes to look at next frame.
var _pending: Array = []
var _walk: Array = []  # [Rect2 (2D), deck height]
var _flip_rocks := {}
var _trees := []  # [MapTree, MeshInstance3D]
var _drum: Node3D
var _clip := ""
var _yaw := PI
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _fade_mats: Array[StandardMaterial3D] = []
var _models := {}
var _low := false
var _scaled := false
var _dist := CAMERA_DISTANCE
var _dodge := 0.0
var _dodge_at := Vector3.ZERO
var _blocked: Array = []
var _ik: TwoBoneIK3D
var _ik_target: Marker3D
var _ik_pole: Marker3D
var _arm_len := 0.5
var _hand_bone := -1
var _shoulder_bone := -1
var _rod_up := 0.3
var _rod_on := 0.0
## 2D pictures shown by models here instead (the start camp's).
var _replaced := {}


## Whether `theme` is to be shown in 3D now.
static func wants(theme: String) -> bool:
	return wanted and theme == THEME


## A run in 3D next (and the map it's for).
static func request() -> void:
	wanted = true
	MapGenerator.forced_theme = THEME


## Back at the camp: runs are 2D again.
static func leave() -> void:
	if wanted and MapGenerator.forced_theme == THEME:
		MapGenerator.forced_theme = ""
	wanted = false


static func to3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x / PX, y, p.y / PX)


static func to2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * PX


## Where on the screen a point of the 2D world is - in 3D when the run is
## shown in 3D (the screen's buttons over the things they're for), else
## the 2D camera's.
static func screen_point(vp: Viewport, world: Vector2, lift := 0.0) -> Vector2:
	if active == null or not is_instance_valid(active) or active.camera == null:
		return vp.get_canvas_transform() * world
	return active.camera.unproject_position(to3(world, active.ground_y(world) + lift))


## The 2D world point under the mouse (the ground it points at).
static func mouse_world(vp: Viewport, fallback: Vector2) -> Vector2:
	if active == null or not is_instance_valid(active) or active.camera == null:
		return fallback
	var m := vp.get_mouse_position()
	var from := active.camera.project_ray_origin(m)
	var dir := active.camera.project_ray_normal(m)
	if dir.y > -0.001:
		return fallback
	return to2(from + dir * ((LAND_Y - from.y) / dir.y))


static func attach(to: Node2D) -> RunView3D:
	var view := RunView3D.new()
	view.name = "RunView3D"
	view.main = to
	to.add_child(view)
	return view


func _ready() -> void:
	active = self
	_rng.seed = 11
	player = main.get_node("Player")
	_visual = player.get_node("Body")
	_environment()
	# The map's docks and boats come in a frame after it's made.
	await get_tree().process_frame
	await get_tree().process_frame
	_build()
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if active == self:
		active = null
	if _scaled:
		get_viewport().scaling_3d_scale = 1.0


func _build() -> void:
	# The 2D world goes; the screen's own layers stay.
	main.visible = false
	for layer in main.find_children("*", "CanvasLayer", true, false):
		# (layers drawn in the 2D world's place - the fireflies, the 誘惑
		# throw's arc - would sit wrong over the 3D one)
		if (layer as CanvasLayer).follow_viewport_enabled:
			(layer as CanvasLayer).visible = false
	var t0 := Time.get_ticks_msec()
	_ground()
	_water()
	_docks()
	var t1 := Time.get_ticks_msec()
	_trees_and_rocks()
	_start_camp()
	_cover()
	var t2 := Time.get_ticks_msec()
	_character()
	_line_and_float()
	_fireflies()
	for n in main.get_children():
		_scan(n)
	print_verbose("RunView3D: land %d ms, props %d ms, the rest %d ms" % [t1 - t0, t2 - t1, Time.get_ticks_msec() - t2])
	player.cast_started.connect(func(at: Vector2, _t): _splash_ring(at))
	built = true


# ---------------------------------------------------------------- the land

func _zones() -> Array:
	return get_tree().get_nodes_in_group("water_zones")


## The map's own rect (2D px).
func _map_rect() -> Rect2:
	var cam: Camera2D = player.get_node("Camera2D")
	return Rect2(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)


## How deep under the shore `p` is (2D px, + in the water) - the deepest of
## the ponds near it.
func _depth(p: Vector2, zones: Array) -> float:
	var best := -1000.0
	for z in zones:
		var zone: WaterZone = z
		var r: Rect2 = zone.get_meta("bounds")
		if not r.has_point(p):
			continue
		best = maxf(best, zone.depth(p))
	return best


func _height_at(depth: float) -> float:
	if depth > 0.0:
		return WATER_Y - 1.1 * smoothstep(0.0, 70.0, depth)
	return WATER_Y + (LAND_Y - WATER_Y) * smoothstep(0.0, 26.0, -depth)


## The ground's height under `p` (2D): a deck's, else the land's.
func ground_y(p: Vector2) -> float:
	for w in _walk:
		if (w[0] as Rect2).has_point(p):
			return float(w[1])
	return maxf(_height_at(_depth(p, _zones())), WATER_Y)


func _ground() -> void:
	var zones := _zones()
	for z in zones:
		var zone: WaterZone = z
		var box := Rect2()
		var first := true
		for l in zone.world_lobes():
			var r := Rect2(l.x - l.z, l.y - l.z, l.z * 2.0, l.z * 2.0)
			box = r if first else box.merge(r)
			first = false
		zone.set_meta("bounds", box.grow(WaterZone.SHORE_BLEND + WaterZone.WARP_AMP_A + WaterZone.WARP_AMP_B + 40.0))
	var rect := _map_rect()
	var lo := Vector2(rect.position.x / PX - MARGIN, rect.position.y / PX - MARGIN)
	var hi := Vector2(rect.end.x / PX + MARGIN, rect.end.y / PX + MARGIN)
	var n := Vector2i(int((hi.x - lo.x) / CELL) + 1, int((hi.y - lo.y) / CELL) + 1)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.08
	var share: float = 0.35
	var floor_spec = MapGenerator.THEMES[THEME].get("floor", [])
	if floor_spec is Array and floor_spec.size() > 2:
		share = float(floor_spec[2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n.y:
		for i in n.x:
			var x := lo.x + i * CELL
			var z := lo.y + j * CELL
			var p2 := Vector2(x, z) * PX
			var d := _depth(p2, zones)
			var y := _height_at(d) + 0.025 * noise.get_noise_2d(x * 3.0, z * 3.0)
			# Past the map's edge the forest rises a little: a frame.
			var out := Vector2(maxf(maxf(rect.position.x - p2.x, p2.x - rect.end.x), 0.0),
				maxf(maxf(rect.position.y - p2.y, p2.y - rect.end.y), 0.0)).length() / PX
			y += 1.4 * smoothstep(0.0, MARGIN, out)
			var wob := noise.get_noise_2d(x, z)
			# r: (no paths here) g: (no stone) b: the mud shore, a: the
			# forest floor (else grass)
			var mud := 1.0 - smoothstep(0.0, 70.0 + wob * 30.0, -d)
			var forest := clampf(0.5 + (noise.get_noise_2d(x * 0.6 + 40.0, z * 0.6) - (share - 0.5)) * 1.6, 0.0, 1.0)
			forest = maxf(forest, smoothstep(0.0, 4.0, out))
			st.set_color(Color(0.0, 0.0, mud, 1.0 - forest))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, y, z))
	for j in n.y - 1:
		for i in n.x - 1:
			var a := j * n.x + i
			for k in [a, a + 1, a + n.x, a + 1, a + n.x + 1, a + n.x]:
				st.add_index(k)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = PROTO.GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	# (the theme's two floors: its forest floor under the trees, grass in
	# the open)
	for pair in [["grass", "grass"], ["forest", "forest_floor"], ["path", "dirt"], ["stone", "lp_stone"], ["mud", "mud"]]:
		mat.set_shader_parameter(pair[0] + "_tex", load("res://assets/sprites/ground/%s_albedo.png" % pair[1]))
		mat.set_shader_parameter(pair[0] + "_nrm", load("res://assets/sprites/ground/%s_normal.png" % pair[1]))
	mi.material_override = mat
	add_child(mi)


func _water() -> void:
	var i := 0
	for z in _zones():
		var zone: WaterZone = z
		var sh := Shader.new()
		# (calmer than the trial's: long low swells, not a rough chop)
		sh.code = PROTO.WATER_SHADER.replace("NORMAL_MAP_DEPTH = 0.55", "NORMAL_MAP_DEPTH = 0.22") \
			.replace("wpos.xz * 0.08", "wpos.xz * 0.05").replace("g * 0.7", "g * 0.18")
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var noise := FastNoiseLite.new()
		noise.seed = 17
		noise.frequency = 0.04
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.noise = noise
		t.as_normal_map = true
		t.bump_strength = 6.0
		mat.set_shader_parameter("wave_tex", t)
		mat.set_shader_parameter("moon_dir", MOON_DIR)
		if zone.is_rare():
			mat.set_shader_parameter("deep", Color(0.06, 0.015, 0.11))
			mat.set_shader_parameter("shallow", Color(0.2, 0.08, 0.3))
		var box: Rect2 = zone.get_meta("bounds")
		var q := PlaneMesh.new()
		q.size = box.size / PX
		var mi := MeshInstance3D.new()
		mi.name = "Water%d" % i
		mi.mesh = q
		mi.material_override = mat
		mi.position = to3(box.get_center(), WATER_Y + i * 0.002)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		i += 1


# ---------------------------------------------------------------- the props

func _docks() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.2, 0.12)
	wood.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.11, 0.07)
	for n in get_tree().get_nodes_in_group("walkways"):
		var dock := n as Dock
		if dock == null:
			continue
		if dock._is_boat:
			var boat := CampModel.make("boat")
			if boat != null:
				boat.position = to3(dock.global_position, WATER_Y - 0.5)
				boat.scale = Vector3.ONE * 0.6
				boat.rotation.y = {"up": 0.0, "down": PI, "left": PI * 0.5, "right": -PI * 0.5}.get(dock.bow, 0.0)
				add_child(boat)
			continue
		var r: Rect2 = dock.walk_rect
		if r.size == Vector2.ZERO:
			continue
		var stairs := dock.descend != ""
		var size := r.size / PX
		var centre := to3(r.get_center())
		var vertical := size.y > size.x
		var along := size.y if vertical else size.x
		var across := size.x if vertical else size.y
		if stairs:
			# Steps down to the water, the way they lead.
			var steps := 5
			var dir: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}.get(dock.descend, Vector2.DOWN)
			for k in steps:
				var t := (k + 0.5) / steps
				var at := r.get_center() + dir * (t - 0.5) * (r.size.y if vertical else r.size.x)
				var step := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(across if vertical else along / steps, 0.08, along / steps if vertical else across)
				step.mesh = b
				step.material_override = wood
				step.position = to3(at, lerpf(DECK_Y, WATER_Y + 0.02, t) - 0.04)
				add_child(step)
			_walk.append([r, (DECK_Y + WATER_Y) * 0.5])
			continue
		var count := int(along / 0.32)
		for k in count:
			var plank := MeshInstance3D.new()
			var b := BoxMesh.new()
			var off := -along * 0.5 + (k + 0.5) * along / count
			b.size = Vector3(across, 0.06, 0.28) if vertical else Vector3(0.28, 0.06, across)
			plank.mesh = b
			plank.material_override = wood if k % 3 != 1 else dark
			plank.position = centre + (Vector3(0, 0, off) if vertical else Vector3(off, 0, 0)) + Vector3(0, DECK_Y - 0.03, 0)
			plank.rotation.y = _rng.randf_range(-0.02, 0.02)
			add_child(plank)
		for k in int(along / 1.6) + 1:
			for side in [-0.5, 0.5]:
				var post := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.07
				c.bottom_radius = 0.08
				c.height = 1.6
				post.mesh = c
				post.material_override = dark
				var a := -along * 0.5 + k * 1.6
				post.position = centre + (Vector3(side * across, -0.45, a) if vertical else Vector3(a, -0.45, side * across))
				add_child(post)
		_walk.append([r, DECK_Y])


## The map's trees as the camp's pines; its rocks, bushes and turning
## stones as the trial's nature models; and a wall of pines round the edge.
func _trees_and_rocks() -> void:
	var pines := ["pine_a", "pine_b", "pine_c"]
	var meshes := {}
	for p in pines:
		meshes[p] = _faded(CampModel.tree_mesh(p))
	var spots := {"pine_a": [], "pine_b": [], "pine_c": []}
	for t in get_tree().get_nodes_in_group("trees"):
		var tree := t as Node2D
		if tree == null:
			continue
		var kind: String = pines[absi(hash(tree.name)) % pines.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[kind]
		var s := _rng.randf_range(0.7, 1.0)
		mi.scale = Vector3(s, s, s)
		mi.rotation.y = _rng.randf() * TAU
		mi.position = to3(tree.global_position, LAND_Y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		_trees.append([tree, mi])
	# The edge: thick with them, out past where the map ends.
	var rect := _map_rect()
	for k in BORDER_TREES:
		var p := Vector2(_rng.randf_range(rect.position.x - MARGIN * PX, rect.end.x + MARGIN * PX),
			_rng.randf_range(rect.position.y - MARGIN * PX, rect.end.y + MARGIN * PX))
		var inside := rect.grow(-30.0).has_point(p)
		if inside:
			continue
		var out := Vector2(maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0),
			maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)).length() / PX
		spots[pines[k % 3]].append(to3(p, LAND_Y + 1.4 * smoothstep(0.0, MARGIN, out)))
	for kind in pines:
		var xfs := []
		for at in spots[kind]:
			var s := _rng.randf_range(0.75, 1.15)
			xfs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), at))
		# (out past the edge: no shadows - the moon's are only near anyway)
		_scatter(meshes[kind], xfs, false)
	for n in main.get_children():
		var path := _script_name(n)
		if path == "obstacle.gd":
			var w := _footprint(n) / PX
			_prop(["rock_medium", "rock_medium_2"][absi(hash(n.name)) % 2], to3((n as Node2D).global_position, LAND_Y - 0.05),
				clampf(w * 1.1, 0.5, 3.0), _rng.randf() * TAU, true, true)
		elif path == "bush.gd":
			_prop("fern", to3((n as Node2D).global_position, LAND_Y), _rng.randf_range(1.1, 1.5), _rng.randf() * TAU, false, true)
		elif path == "flip_rock.gd":
			var rock := _prop("rock_medium_2", to3((n as Node2D).global_position, LAND_Y - 0.05), 0.55, _rng.randf() * TAU, true, true)
			if rock != null:
				_flip_rocks[n] = rock


## The camp at the start (FuelStation): its fire, drums and tent as the
## camp's own models, where its picture has them.
func _start_camp() -> void:
	var station := main.get_node_or_null("FuelStation") as Node2D
	if station == null:
		return
	var at := station.global_position
	var fire := CampModel.make("campfire", 1.4)
	if fire != null:
		fire.position = to3(at + FuelStation.FLAME, LAND_Y)
		fire.scale = Vector3.ONE * 0.8
		add_child(fire)
	for spec in [[Vector2(-40, -40), 0.3, false], [Vector2(-27, -48), 1.1, false], [Vector2(-31, -22), 0.6, true]]:
		var drum := CampModel.make("drum")
		if drum == null:
			continue
		drum.position = to3(at + spec[0], LAND_Y + (0.32 if spec[2] else 0.0))
		drum.rotation = Vector3(0, spec[1], PI * 0.5 if spec[2] else 0.0)
		drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(drum)
	var tent := CampModel.make("tent_%d" % clampi(Profile.camp_tent, 1, 9))
	if tent != null:
		tent.position = to3(at + FuelStation.TENT_AT, LAND_Y)
		tent.rotation.y = PI
		tent.scale = Vector3.ONE * 0.8
		tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(tent)
	for name in ["Visual", "Tent"]:
		var n := station.get_node_or_null(name)
		if n != null:
			_replaced[n] = true


## Grass, ferns, mushrooms, reeds and lily pads where the map's ground
## cover is (by its picture).
func _cover() -> void:
	# kind: [model, size, sized by its width]
	# ("#card": the grass card, _grass_card)
	var kinds := {"grass": ["#card", 0.45, false], "tall": ["#card", 0.65, false],
		"clover": ["#card", 0.3, false], "plant": ["fern", 0.8, true], "shrub": ["fern", 0.65, true],
		"mushroom": ["mushroom", 0.22, false], "reeds": ["#card", 0.95, false],
		"pebble": ["rock_medium", 0.25, true], "stone": ["rock_path_1", 0.55, true]}
	var at := {}
	for n in main.get_children():
		if _script_name(n) != "ground_cover.gd":
			continue
		var s := n as Sprite2D
		var tex: Texture2D = s.texture
		if tex is CanvasTexture:
			tex = (tex as CanvasTexture).diffuse_texture
		var file := tex.resource_path.get_file() if tex != null else ""
		var kind := "grass"
		if file.contains("lily"):
			var leaf := CampModel.make("lotus_leaf")
			if leaf != null:
				leaf.position = to3(s.global_position, WATER_Y + 0.01)
				leaf.rotation.y = _rng.randf() * TAU
				leaf.scale = Vector3.ONE * _rng.randf_range(0.22, 0.34)
				add_child(leaf)
			continue
		if file.contains("drift"):
			var log := CampModel.make("log")
			if log != null:
				log.position = to3(s.global_position, WATER_Y + 0.05)
				log.rotation.y = _rng.randf() * TAU
				log.scale = Vector3.ONE * 0.6
				add_child(log)
			continue
		for key in ["mushroom", "clover", "shrub", "plant", "reed", "pebble", "rock_path", "tall"]:
			if file.contains(key):
				kind = {"reed": "reeds", "rock_path": "stone"}.get(key, key)
				break
		at.get_or_add(kind, []).append(s.global_position)
	for kind in at:
		var spec: Array = kinds[kind]
		var mesh := [_grass_card(), 1.0] if spec[0] == "#card" else _model_mesh(spec[0], spec[2])
		if mesh.is_empty():
			continue
		var list: Array = at[kind]
		var xfs := []
		for p in list:
			var s: float = float(spec[1]) / maxf(mesh[1], 0.01) * _rng.randf_range(0.75, 1.25)
			xfs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)),
				to3(p, maxf(_height_at(_depth(p, _zones())), WATER_Y))))
		_scatter(mesh[0], xfs, false, COVER_REACH)
	# Plenty more grass than the 2D map's: the 3D ground's bare without.
	var card := _grass_card()
	var rect := _map_rect()
	var zones := _zones()
	var xfs := []
	for k in EXTRA_GRASS:
		var p := Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
		if _depth(p, zones) > -14.0 or _on_walk(p):
			continue
		var s := _rng.randf_range(0.3, 0.5)
		xfs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.3, s, s * 1.3)), to3(p, LAND_Y)))
	_scatter(card, xfs, false, COVER_REACH)


## User request (phones were slow): grass as two crossed cards with a tuft
## drawn on them - 4 triangles a tuft, not the model's 600. Lit as the
## ground is (their normals straight up), so they sit in it.
func _grass_card() -> Mesh:
	if _models.has("#card"):
		return _models["#card"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for a in [0.0, PI * 0.5]:
		var d := Vector3(cos(a), 0, sin(a)) * 0.5
		var quad := [[-d, Vector2(0, 1)], [d, Vector2(1, 1)], [d + Vector3.UP, Vector2(1, 0)], [-d + Vector3.UP, Vector2(0, 0)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/models/run3d/grass_card.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.surface_set_material(0, mat)
	_models["#card"] = m
	return m


## Many of one mesh, in square chunks of the map (CHUNK m) - each its own
## MultiMesh, so the ones off screen aren't drawn - and none past `reach`
## (m) from the camera (0: always).
func _scatter(mesh: Mesh, xfs: Array, shadow: bool, reach := 0.0) -> void:
	if mesh == null or xfs.is_empty():
		return
	var cells := {}
	for xf in xfs:
		var o: Vector3 = (xf as Transform3D).origin
		cells.get_or_add(Vector2i(floori(o.x / CHUNK), floori(o.z / CHUNK)), []).append(xf)
	for c in cells:
		var list: Array = cells[c]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if reach > 0.0:
			mmi.visibility_range_end = reach
		add_child(mmi)


func _on_walk(p: Vector2) -> bool:
	for w in _walk:
		if (w[0] as Rect2).grow(10.0).has_point(p):
			return true
	return false


## How wide a thing's collision is (2D px).
func _footprint(n: Node) -> float:
	for c in n.find_children("*", "CollisionPolygon2D", true, false):
		var poly: PackedVector2Array = (c as CollisionPolygon2D).polygon
		if poly.size() > 2:
			var lo := poly[0]
			var hi := poly[0]
			for v in poly:
				lo = lo.min(v)
				hi = hi.max(v)
			return (hi - lo).x * absf((c as Node2D).global_scale.x)
	for c in n.find_children("*", "CollisionShape2D", true, false):
		var sh: Shape2D = (c as CollisionShape2D).shape
		if sh is RectangleShape2D:
			return (sh as RectangleShape2D).size.x
		if sh is CircleShape2D:
			return (sh as CircleShape2D).radius * 2.0
	return PX


## A copy of `mesh` whose materials dither away close to the camera.
func _faded(mesh: Mesh) -> Mesh:
	if mesh == null:
		return null
	var m: Mesh = mesh.duplicate()
	for s in m.get_surface_count():
		var src := m.surface_get_material(s)
		if src is StandardMaterial3D:
			var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			mat.distance_fade_min_distance = FADE_NEAR
			mat.distance_fade_max_distance = FADE_FAR
			m.surface_set_material(s, mat)
			_fade_mats.append(mat)
	return m


func _model_mesh(name: String, wide := false) -> Array:
	var key := name + ("#wide" if wide else "")
	if _models.has(key):
		return _models[key]
	var path := PROTO_MODELS + name + ".glb"
	if not ResourceLoader.exists(path):
		return []
	var inst: Node = (load(path) as PackedScene).instantiate()
	var found: Array = []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		var box := m.get_aabb()
		found = [m, maxf(box.size.x, box.size.z) if wide else box.size.y]
		break
	inst.free()
	_models[key] = found
	return found


func _prop(name: String, at: Vector3, size: float, yaw: float, shadow := true, wide := false) -> Node3D:
	var mesh := _model_mesh(name, wide)
	if mesh.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh[0]
	mi.scale = Vector3.ONE * (size / maxf(mesh[1], 0.01))
	mi.position = at
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _script_name(n: Node) -> String:
	var s: Script = n.get_script()
	return s.resource_path.get_file() if s != null else ""


# ---------------------------------------------------------------- the rest

func _on_node_added(n: Node) -> void:
	if n is Sprite2D or n is AnimatedSprite2D or n is PointLight2D:
		_pending.append(n)


## Stands up the pictures (and lights) under `n` that nothing else shows.
func _scan(n: Node) -> void:
	if n == self or n is CanvasLayer or n is SubViewport or MODELLED.has(_script_name(n)):
		return
	if n == player or n.name in ["Bobber", "Line", "GroundBackground", "Darkness"] and n.get_parent() == main:
		return
	if (n is Sprite2D or n is AnimatedSprite2D) and not _replaced.has(n):
		_stand_up(n)
	elif n is PointLight2D:
		_add_light(n)
	for c in n.get_children():
		_scan(c)


## Whether a new node is one to show (not under something modelled, a
## layer of the screen's, or a picture drawn into a texture).
func _wanted(n: Node) -> bool:
	if not is_instance_valid(n) or not n.is_inside_tree() or not main.is_ancestor_of(n):
		return false
	var p := n
	while p != main:
		if p is CanvasLayer or p is SubViewport or p == player or MODELLED.has(_script_name(p)):
			return false
		if p.get_parent() == main and p.name in ["Bobber", "Line", "GroundBackground"]:
			return false
		p = p.get_parent()
	return true


func _stand_up(n: Node2D) -> void:
	if _sprites.has(n):
		return
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.shaded = true
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (a glow drawn added on in 2D - the altar's halo, the pillar's, the
	# fire's embers: added on here too, unlit)
	var cm := n.material as CanvasItemMaterial
	if cm != null and cm.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		var m := StandardMaterial3D.new()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		s.material_override = m
	else:
		# (the 2D pictures keep their shading in a normal map, lit by the
		# 2D lights: lit here by the 3D ones the same way)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.9
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.material_override = m
	add_child(s)
	_sprites[n] = s
	_sync_sprite(n, s)


## Shown as the 2D world would show it: the main scene's own visibility
## aside (it's hidden).
func _shown(n: CanvasItem) -> bool:
	var p: Node = n
	while p != null and p != main:
		if p is CanvasItem and not (p as CanvasItem).visible:
			return false
		p = p.get_parent()
	return true


func _sync_sprite(n: Node2D, s: Sprite3D) -> void:
	var on := _shown(n)
	s.visible = on
	if not on:
		return
	var tex: Texture2D
	if n is Sprite2D:
		var sp := n as Sprite2D
		tex = sp.texture
		s.hframes = sp.hframes
		s.vframes = sp.vframes
		s.frame = clampi(sp.frame, 0, sp.hframes * sp.vframes - 1)
		s.region_enabled = sp.region_enabled
		s.region_rect = sp.region_rect
		s.centered = sp.centered
		s.offset = Vector2(sp.offset.x, -sp.offset.y)
		s.flip_h = sp.flip_h
		s.flip_v = sp.flip_v
	else:
		var an := n as AnimatedSprite2D
		if an.sprite_frames != null and an.sprite_frames.has_animation(an.animation):
			tex = an.sprite_frames.get_frame_texture(an.animation, an.frame)
		s.hframes = 1
		s.vframes = 1
		s.frame = 0
		s.centered = an.centered
		s.offset = Vector2(an.offset.x, -an.offset.y)
		s.flip_h = an.flip_h
		s.flip_v = an.flip_v
	var nrm: Texture2D = null
	if tex is CanvasTexture:
		nrm = (tex as CanvasTexture).normal_texture
		tex = (tex as CanvasTexture).diffuse_texture
	if s.texture != tex:
		s.texture = tex
		var m := s.material_override as StandardMaterial3D
		if m != null:
			m.albedo_texture = tex
			if m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				m.normal_enabled = nrm != null
				m.normal_texture = nrm
	var sc := n.global_scale
	if sc.x < 0.0:
		s.flip_h = not s.flip_h
	s.pixel_size = absf(sc.x) / PX
	var c := Color.WHITE
	var p: Node = n
	while p != null and p != main:
		if p is CanvasItem:
			c *= (p as CanvasItem).modulate
		p = p.get_parent()
	s.modulate = c * n.self_modulate
	# (a shadow lies on the ground as it lies; so does a slab under
	# everything - the altar's - its 55-degree picture stretched back out)
	var flat := n.name == "Shadow" or n.z_index <= -3
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_ENABLED
	if s.material_override is StandardMaterial3D:
		var sm := s.material_override as StandardMaterial3D
		sm.albedo_color = s.modulate
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_ENABLED
	s.rotation = Vector3(-PI * 0.5, -n.global_rotation, 0.0) if flat else Vector3.ZERO
	s.scale = Vector3(1.0, 1.0 / sin(deg_to_rad(55.0)), 1.0) if flat else Vector3.ONE
	var at := n.global_position
	s.position = to3(at, ground_y(at) + (0.07 if flat else 0.0))


func _add_light(l: PointLight2D) -> void:
	if _lights.has(l) or l.get_parent() == player:
		return
	var o := OmniLight3D.new()
	o.omni_attenuation = 1.3
	o.shadow_enabled = false
	add_child(o)
	_lights[l] = o
	_sync_light(l, o)


func _sync_light(l: PointLight2D, o: OmniLight3D) -> void:
	var on := l.enabled and _shown(l)
	o.visible = on
	if not on:
		return
	var half := 128.0
	if l.texture != null:
		half = l.texture.get_width() * 0.5
	o.omni_range = clampf(half * l.texture_scale / PX * 0.9, 1.0, 14.0)
	o.light_color = l.color
	o.light_energy = l.energy * 1.4
	o.position = to3(l.global_position, ground_y(l.global_position) + 1.2)


# ---------------------------------------------------------------- the traveller

func _character() -> void:
	pivot = Node3D.new()
	pivot.name = "Traveller"
	add_child(pivot)
	rig = CharacterRig.new()
	rig.auto_idle = false
	pivot.add_child(rig)
	_arm_ik()
	if _low:
		# (on a phone the character's 77 000 triangles aren't drawn a second
		# time into the moon's shadow: a soft dark patch under it instead)
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var blob := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		q.orientation = PlaneMesh.FACE_Y
		blob.mesh = q
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(0, 0, 0, 0.55)
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		g.gradient = grad
		bm.albedo_texture = g
		blob.material_override = bm
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blob.position = Vector3(0, 0.03, 0)
		pivot.add_child(blob)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.72, 0.4)
	_lamp.omni_attenuation = 1.2
	_lamp.light_specular = 0.3
	_lamp.shadow_enabled = not _low
	add_child(_lamp)
	_drum = CampModel.make("drum")
	if _drum != null:
		_drum.scale = Vector3.ONE * 0.55
		_drum.visible = false
		add_child(_drum)
	_place_traveller(0.0)


func _feet() -> Vector2:
	return player.global_position + Player.FEET


func _place_traveller(delta: float) -> void:
	var feet := _feet()
	pivot.position = to3(feet, ground_y(feet))
	# Which way it faces: as the 2D one does (the way it runs; the aim
	# when it's fishing or still; the ghost holding it).
	var moving := player.velocity.length() > 8.0
	var face: Vector2 = player.aim_dir
	if _visual.struggling:
		face = player.grab_from - player.global_position
	elif moving and player.state != Player.State.CHARGING:
		face = player.velocity
	if face.length() > 0.01:
		var want := atan2(face.x, face.y)
		_yaw = want if delta <= 0.0 else lerp_angle(_yaw, want, minf(1.0, delta * TURN_RATE))
	pivot.rotation.y = _yaw


## The clip the 2D picture shows, as the 3D model's: [name, speed, or a
## time to hold it at (>= 0: scrubbed, not played)].
func _pick_clip() -> Array:
	var v := _visual
	var speed := player.velocity.length() / PX
	# (in the ghost's grip: flailing - Sad_B, first used here, hardly moved)
	if v.struggling:
		return ["Disappointed", 1.8, -1.0]
	if v.acting >= 0:
		var t := float(v.frame_in_clip) / PlayerVisual.FRAMES
		return ["PickUp_Table" if player.swing_kind == "scoop" else "Interact", 1.0, t]
	if v.move != "":
		match v.move:
			"walk":
				return ["Walk", clampf(speed / WALK_PACE, 0.4, 2.4), -1.0]
			"sad_walk":
				return ["Walk", clampf(speed / WALK_PACE * 0.8, 0.3, 1.5), -1.0]
			"sad_idle":
				return ["Sad", 1.0, -1.0]
			"dizzy":
				return ["Sad", 0.6, -1.0]
		var timed := {"drink": "Drink", "look": "Look_Around", "eye": "Peek", "pick": "PickUp_Table",
			"lift": "Chest_Open", "throw": "Interact", "cheer": "Victory", "fist": "Fist_Pump", "sad": "Disappointed",
			"scared": "Peek", "pray": "Fixing_Kneeling", "kneel": "Crouch_Idle"}
		var t: float = 1.0 - player.move_left / maxf(player.move_time, 0.01) if player.move_left > 0.0 else -1.0
		return [timed.get(v.move, "Idle"), 1.0, clampf(t, 0.0, 1.0) if t >= 0.0 else -1.0]
	match v.clip:
		PlayerVisual.CLIP_RUN, PlayerVisual.CLIP_HOLD_RUN:
			if speed * PX < PlayerVisual.WALK_MAX:
				return ["Walk", clampf(speed / WALK_PACE, 0.4, 2.4), -1.0]
			return ["Run", clampf(speed / RUN_PACE, 0.6, 2.0), -1.0]
		PlayerVisual.CLIP_CAST, PlayerVisual.CLIP_CAST_SHORT:
			# Wound back with the charge (frames 0-3), the whip (4-7).
			var f := v.frame_in_clip
			var t: float = [0.0, 0.1, 0.2, 0.3, 0.4, 0.52, 0.68, 0.9][clampi(f, 0, 7)]
			return ["Fish_Cast", 1.0, t]
		PlayerVisual.CLIP_HOLD:
			return ["Fish_Hold", 1.0, -1.0]
		PlayerVisual.CLIP_BITE:
			return ["Fish_Bite", 1.2, -1.0]
		PlayerVisual.CLIP_TUG:
			return ["Fish_Tug", 1.3, -1.0]
		PlayerVisual.CLIP_REEL:
			return ["Fish_Reel", 1.0, -1.0]
		PlayerVisual.CLIP_FIGHT:
			return ["Fish_Fight", 1.0, -1.0]
		PlayerVisual.CLIP_CATCH:
			return ["Fish_Catch", 1.0, -1.0]
		PlayerVisual.CLIP_BUSY:
			return ["Fixing_Kneeling", 1.0, -1.0]
	return ["Idle", 1.0, -1.0]


func _animate() -> void:
	var anim := rig.anim
	if anim == null:
		return
	var pick := _pick_clip()
	var name: String = pick[0]
	if not anim.has_animation(name):
		name = "Idle"
	var a := anim.get_animation(name)
	var scrub: float = pick[2]
	if name != _clip:
		_clip = name
		if scrub < 0.0 and not name in ["Fish_Catch", "Interact", "PickUp_Table"]:
			a.loop_mode = Animation.LOOP_LINEAR
		anim.play(name, 0.18)
	if scrub >= 0.0:
		anim.speed_scale = 0.0
		var at := scrub * a.length
		if absf(anim.current_animation_position - at) > 0.001:
			anim.seek(at, true)
	else:
		anim.speed_scale = float(pick[1])


## User report: casting, the arm didn't move - the rod swung on its own.
## The fishing clips (KayKit's) keep the rod hand almost still (the
## rod's own bones did the work there), so while fishing the rod is
## pointed as the 2D pictures point it (ROD_ANGLES) and the right arm is
## brought after it (a two-bone IK on it, RodArm): low and forward
## holding, raised for the strike and the fight, up over the shoulder in
## the cast's backswing and down through the whip. The rod is held at the
## hand's grip, wherever the arm has it.
func _arm_ik() -> void:
	var sk := rig.skeleton
	if sk == null:
		return
	_ik_target = Marker3D.new()
	_ik_target.name = "RodHand"
	add_child(_ik_target)
	_ik_pole = Marker3D.new()
	_ik_pole.name = "RodElbow"
	add_child(_ik_pole)
	_ik = TwoBoneIK3D.new()
	_ik.name = "RodArm"
	sk.add_child(_ik)
	_ik.setting_count = 1
	_ik.set_root_bone_name(0, "upperarm_r")
	_ik.set_middle_bone_name(0, "lowerarm_r")
	_ik.set_end_bone_name(0, "hand_r")
	_ik.set_target_node(0, _ik.get_path_to(_ik_target))
	_ik.set_pole_node(0, _ik.get_path_to(_ik_pole))
	_ik.influence = 0.0
	var a := sk.find_bone("upperarm_r")
	var b := sk.find_bone("lowerarm_r")
	var c := sk.find_bone("hand_r")
	_arm_len = sk.get_bone_global_rest(a).origin.distance_to(sk.get_bone_global_rest(b).origin) \
		+ sk.get_bone_global_rest(b).origin.distance_to(sk.get_bone_global_rest(c).origin)
	_hand_bone = c
	_shoulder_bone = a
	sk.skeleton_updated.connect(_hold_rod)


func _rod() -> Node3D:
	var att: Node3D = rig.attachments.get("hand_r")
	if att == null or att.get_child_count() == 0:
		return null
	var rod := att.get_child(0) as Node3D
	if not rod.has_meta("rest"):
		rod.set_meta("rest", rod.transform)
		# (placed by hand each frame, after the arm's been posed)
		rod.top_level = true
	return rod


## How the rod's to be held this frame (ROD_ANGLES eased toward), and
## where the arm's to reach for it.
func _aim_rod(delta: float) -> void:
	if _ik == null:
		return
	var plain := _visual.move == "" and _visual.acting < 0 and not _visual.struggling
	var angles = ROD_ANGLES.get(_visual.clip) if plain else null
	var fishing := angles != null and not (_visual.clip == PlayerVisual.CLIP_HOLD_RUN and player.state == Player.State.IDLE)
	_rod_on = move_toward(_rod_on, 1.0 if fishing else 0.0, delta / ROD_EASE_IN)
	if fishing:
		var want := deg_to_rad(float(angles[clampi(_visual.frame_in_clip, 0, 7)]))
		_rod_up = want if _rod_on < 0.05 else lerpf(_rod_up, want, minf(1.0, delta * ROD_FOLLOW))
	_ik.influence = _rod_on * ARM_FOLLOW
	var sk := rig.skeleton
	var b := pivot.global_basis.orthonormalized()
	var shoulder := sk.global_transform * sk.get_bone_global_pose(_shoulder_bone).origin
	# (rod angle -> the arm's: holding low (18) the hand's at the waist,
	# forward; straight up (90) at the brow; back over the shoulder past it)
	var phi := deg_to_rad(-38.0) + (_rod_up - deg_to_rad(18.0)) * 0.95
	var reach := b.z * cos(phi) + Vector3.UP * sin(phi)
	_ik_target.global_position = shoulder - b.x * 0.05 + reach * _arm_len * 0.8
	# (the elbow out to the side and down)
	_ik_pole.global_position = shoulder - b.x * 0.5 + Vector3.DOWN * 0.35 - b.z * 0.15


## Once the arm's posed: the rod in the hand, pointed (ROD_ANGLES) while
## fishing, else as the hand holds it.
func _hold_rod() -> void:
	var rod := _rod()
	if rod == null:
		return
	var sk := rig.skeleton
	var hand := sk.global_transform * sk.get_bone_global_pose(_hand_bone)
	var rest: Transform3D = rod.get_meta("rest")
	var held := hand * rest
	if _rod_on <= 0.0:
		rod.global_transform = held
		return
	var side := deg_to_rad(ROD_SIDE)
	var b := pivot.global_basis.orthonormalized()
	# (the model faces +z; its right hand's side is -x)
	var dir := (b.z * cos(side) * cos(_rod_up) - b.x * sin(side) * cos(_rod_up) + Vector3.UP * sin(_rod_up)).normalized()
	var x := dir.cross(b.x if absf(dir.dot(b.z)) > 0.9 else b.z).normalized()
	var aimed := Transform3D(Basis(x, dir, x.cross(dir)).scaled(Vector3.ONE * CharacterRig.ROD_SCALE), held.origin)
	rod.global_transform = held.interpolate_with(aimed, _rod_on)


func _line_and_float() -> void:
	_float = Node3D.new()
	_float.name = "Float"
	add_child(_float)
	_float_body = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	_float_body.mesh = s
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.25, 0.15)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.35, 0.2)
	fm.emission_energy_multiplier = 0.5
	_float_body.material_override = fm
	_float.add_child(_float_body)
	var tip := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.008
	c.bottom_radius = 0.012
	c.height = 0.14
	tip.mesh = c
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(1.0, 0.95, 0.8)
	tm.emission_enabled = true
	tm.emission = Color(1.0, 0.9, 0.6)
	tip.material_override = tm
	tip.position = Vector3(0, 0.1, 0)
	_float.add_child(tip)
	_float.visible = false
	_line = MeshInstance3D.new()
	_line.mesh = ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.9, 0.92, 0.95, 0.75)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_guide = MeshInstance3D.new()
	_guide.mesh = ImmediateMesh.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.vertex_color_use_as_albedo = true
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.no_depth_test = true
	gm.render_priority = 2
	_guide.material_override = gm
	_guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_guide)
	_guide_label = Label3D.new()
	_guide_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_guide_label.no_depth_test = true
	_guide_label.font_size = 40
	_guide_label.outline_size = 10
	_guide_label.pixel_size = 0.006
	_guide_label.visible = false
	add_child(_guide_label)


## The rod's tip (world), or the hand if there's no rod.
func _rod_tip() -> Vector3:
	var att: Node3D = rig.attachments.get("hand_r")
	if att != null and att.get_child_count() > 0:
		return (att.get_child(0) as Node3D).global_transform * Vector3(0, 6.0, 0)
	return pivot.global_position + Vector3(0, 1.2, 0)


func _update_line() -> void:
	var bobber: Node2D = main.get_node("Bobber")
	var on := bobber.visible
	_float.visible = on
	var im := _line.mesh as ImmediateMesh
	im.clear_surfaces()
	if not on:
		return
	var at: Vector2 = bobber.global_position
	var y := WATER_Y + 0.02 if _depth(at, _zones()) > 0.0 else ground_y(at) + 0.05
	var bob := 0.0
	var lure: LureVisual = main.get_node_or_null("Bobber/Lure")
	if lure != null and lure.float_state == LureVisual.FloatState.BITING:
		bob = -0.05 * absf(sin(_time * 18.0))
	_float.position = to3(at, y + bob)
	(_float_body.material_override as StandardMaterial3D).albedo_color = bobber.modulate if bobber.modulate != Color.WHITE else Color(0.95, 0.25, 0.15)
	var from := _rod_tip()
	var to := _float.position + Vector3(0, 0.06, 0)
	# Slack when it's waiting, drawn tight on a fish.
	var sag := 0.45 if player.state == Player.State.WAITING else 0.08
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 17:
		var t := i / 16.0
		var p := from.lerp(to, t)
		p.y -= sag * 4.0 * t * (1.0 - t) * minf(from.distance_to(to) / 6.0, 1.5)
		im.surface_add_vertex(p)
	im.surface_end()


## While a cast is wound: dots out to where it'll land, a ring there, how
## far in 公尺 (cast_guide.gd's, in 3D); the 誘惑 throw's ring too.
func _update_guide() -> void:
	var im := _guide.mesh as ImmediateMesh
	im.clear_surfaces()
	_guide_label.visible = false
	var target := Vector2.INF
	var color := Color(1.0, 0.92, 0.6, 0.7)
	if player.state == Player.State.CHARGING:
		var ratio: float = player.charge_time / Player.MAX_CHARGE_TIME
		target = player.landing_point(ratio)
		var water: bool = player._find_water_zone(target) != null
		color = Color(0.85, 0.95, 1.0, 0.9) if water else Color(1.0, 0.35, 0.3, 0.9)
		var meters := (target - player.global_position).length() / Player.PX_PER_M
		_guide_label.text = "%.1f 公尺" % meters
		_guide_label.modulate = color
		_guide_label.visible = true
	elif player._lure_charging:
		target = player.lure_target()
		color = Color(1.0, 0.75, 0.4, 0.85)
	if target == Vector2.INF:
		return
	var from := to3(_feet(), ground_y(_feet()) + 0.05)
	var land := to3(target, ground_y(target) + 0.05)
	_guide_label.position = land + Vector3(0, 0.55, 0)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := from.distance_to(land)
	var n := int(length / 0.35)
	for i in range(2, n):
		var p := from.lerp(land, float(i) / n)
		p.y = maxf(p.y, WATER_Y + 0.05)
		_disc(im, p, 0.05, Color(color, color.a * 0.85))
	for i in 32:
		var a0 := i * TAU / 32.0
		var a1 := (i + 1) * TAU / 32.0
		var r0 := 0.26
		var r1 := 0.32
		var p0 := land + Vector3(cos(a0), 0, sin(a0)) * r0
		var p1 := land + Vector3(cos(a0), 0, sin(a0)) * r1
		var p2 := land + Vector3(cos(a1), 0, sin(a1)) * r1
		var p3 := land + Vector3(cos(a1), 0, sin(a1)) * r0
		for p in [p0, p1, p2, p0, p2, p3]:
			im.surface_set_color(color)
			im.surface_add_vertex(p)
	im.surface_end()


func _disc(im: ImmediateMesh, at: Vector3, r: float, color: Color) -> void:
	for i in 8:
		var a0 := i * TAU / 8.0
		var a1 := (i + 1) * TAU / 8.0
		for p in [at, at + Vector3(cos(a0), 0, sin(a0)) * r, at + Vector3(cos(a1), 0, sin(a1)) * r]:
			im.surface_set_color(color)
			im.surface_add_vertex(p)


## The small ring where a cast lands (main.gd's Ripple, in 3D).
func _splash_ring(at: Vector2) -> void:
	if _depth(at, _zones()) <= 0.0:
		return
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.18
	t.outer_radius = 0.22
	ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.92, 1.0, 0.6)
	ring.material_override = m
	ring.scale = Vector3(1, 0.05, 1)
	ring.position = to3(at, WATER_Y + 0.01)
	add_child(ring)
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(4.0, 0.05, 4.0), 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.2)
	tw.chain().tween_callback(ring.queue_free)


func _fireflies() -> void:
	var p := CPUParticles3D.new()
	p.name = "Fireflies"
	p.amount = 40
	p.lifetime = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(9.0, 1.0, 6.0)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	var q := SphereMesh.new()
	q.radius = 0.025
	q.height = 0.05
	q.radial_segments = 6
	q.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 1.0, 0.45)
	q.material = m
	p.mesh = q
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = fade
	p.position = Vector3(0, 1.2, 0)
	pivot.add_child(p)
	p.top_level = true


# ---------------------------------------------------------------- the night

func _environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.03, 0.05)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.2, 0.26, 0.38)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.05, 0.07, 0.11)
	_env.fog_density = 0.018
	_low = low_end()
	_env.glow_enabled = not _low
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.08
	if _low:
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = LOW_SCALE
		_scaled = true
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = Color(0.62, 0.72, 0.95)
	_moon.light_energy = 0.55
	_moon.shadow_enabled = true
	# (the moon's glare off the water kept small)
	_moon.light_specular = 0.2
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if _low else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_moon.directional_shadow_max_distance = 20.0 if _low else 28.0
	add_child(_moon)
	_moon.look_at(_moon.global_position - MOON_DIR.normalized(), Vector3.UP)
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.far = 140.0
	add_child(camera)
	camera.current = true


## The 2D night's dark (main's Darkness) as the 3D one's light: the
## ambient and the moon down with it.
func _update_light() -> void:
	var dark: CanvasModulate = main.get_node_or_null("Darkness")
	if dark == null:
		return
	var c := dark.color
	var level := maxf(c.r, maxf(c.g, c.b))
	# (0.26 the first of the day - dusk already; 0.035 the night)
	var k := clampf((level - 0.035) / (0.26 - 0.035), 0.0, 1.0)
	_env.ambient_light_energy = lerpf(0.22, 0.5, k)
	_env.ambient_light_color = Color(0.2, 0.26, 0.38).lerp(Color(0.42, 0.45, 0.5), k)
	_moon.light_energy = lerpf(0.28, 0.5, k)
	_moon.light_color = Color(0.62, 0.72, 0.95).lerp(Color(0.9, 0.88, 0.85), k)
	_env.fog_light_color = Color(0.05, 0.07, 0.11).lerp(Color(0.2, 0.22, 0.25), k)
	_env.background_color = _env.fog_light_color * 0.5
	# The traveller's own light: the lamp's (or flashlight's) reach and
	# strength, at the hand.
	var lantern: PointLight2D = player.get_node_or_null("Lantern")
	if lantern != null:
		var on := lantern.enabled and lantern.visible
		_lamp.visible = on
		if on:
			var half := 128.0
			if lantern.texture != null:
				half = lantern.texture.get_width() * 0.5
			_lamp.omni_range = clampf(half * lantern.texture_scale / PX * 1.1, 2.0, 16.0)
			_lamp.light_energy = lantern.energy * 1.3
			_lamp.light_color = lantern.color
			var att: Node3D = rig.attachments.get("hand_l")
			# (a little out from the body, so it lights the ground round it
			# more than the one holding it)
			var at := pivot.global_position + Vector3(0, 1.0, 0)
			if att != null:
				at = att.global_position + Vector3(0, 0.1, 0)
			_lamp.global_position = at + pivot.global_basis.z.normalized() * 0.35 + Vector3(0, 0.25, 0)


# ---------------------------------------------------------------- each frame

func _process(delta: float) -> void:
	if not built:
		return
	_time += delta
	# What came into the 2D world since (critters, splashes, drops).
	for n in _pending:
		if _wanted(n):
			if n is PointLight2D:
				_add_light(n)
			else:
				_stand_up(n)
	_pending.clear()
	for n in _sprites.keys():
		if not is_instance_valid(n):
			(_sprites[n] as Node).queue_free()
			_sprites.erase(n)
			continue
		_sync_sprite(n, _sprites[n])
	for l in _lights.keys():
		if not is_instance_valid(l):
			(_lights[l] as Node).queue_free()
			_lights.erase(l)
			continue
		_sync_light(l, _lights[l])
	for n in _flip_rocks:
		if is_instance_valid(n):
			var roller = n.get("_roller")
			if roller is Node2D:
				var r3: Node3D = _flip_rocks[n]
				r3.position = to3((roller as Node2D).global_position, LAND_Y - 0.05)
				r3.rotation.z = (roller as Node2D).rotation
	for pair in _trees:
		if is_instance_valid(pair[0]):
			(pair[1] as Node3D).visible = (pair[0] as Node2D).visible
	_place_traveller(delta)
	_animate()
	_aim_rod(delta)
	if _drum != null:
		_drum.visible = player.carrying_oil_drum
		if _drum.visible:
			var att: Node3D = rig.attachments.get("hand_l")
			_drum.global_position = (att.global_position if att != null else pivot.global_position) - Vector3(0, 0.35, 0)
	_update_line()
	_update_guide()
	_update_light()
	_update_camera(delta)


## User request: the float, the cast's ring and its metres were hidden
## under the buttons at the bottom right (the lamp, 誘惑, the quick slots).
## While one would be, the camera eases toward it and back a little
## (_dodge 0..1), till it's clear; then eases home.
func _dodge_buttons(delta: float) -> void:
	if _blocked.is_empty():
		# (where TouchControls draws the light and 誘惑 buttons round the
		# right stick, and QuickSlots its three)
		var aim := TouchControls.AIM_CENTER
		for spec in [[TouchControls.SKILL_ANGLE, TouchControls.SKILL_DISTANCE, TouchControls.SKILL_RADIUS],
				[TouchControls.LURE_ANGLE, TouchControls.LURE_DISTANCE, TouchControls.LURE_RADIUS]]:
			var c: Vector2 = aim + Vector2.RIGHT.rotated(deg_to_rad(float(spec[0]))) * float(spec[1])
			var r := float(spec[2]) + 16.0
			_blocked.append(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
		for c in QuickSlots.CENTERS:
			var h := QuickSlots.SIDE * 0.5 + 12.0
			_blocked.append(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0))
	var points := []
	var bobber: Node2D = main.get_node("Bobber")
	if bobber.visible:
		points.append(_float.position)
	if player.state == Player.State.CHARGING:
		var land := player.landing_point(player.charge_time / Player.MAX_CHARGE_TIME)
		points.append(to3(land, ground_y(land)))
		points.append(_guide_label.position)
	var hidden: Variant = null
	for p in points:
		var at := camera.unproject_position(p)
		for r in _blocked:
			if (r as Rect2).has_point(at):
				hidden = p
	if hidden != null:
		_dodge_at = hidden
		_dodge = move_toward(_dodge, 1.0, delta * DODGE_RATE)
	elif points.is_empty() or _dodge > 0.0:
		_dodge = move_toward(_dodge, 0.0 if points.is_empty() else _dodge, delta * DODGE_RATE * 0.5)


## Up and behind it at CAMERA_PITCH: as far back as the 2D camera's zoom
## says, aimed where it frames (main.gd), and shaken when it is.
func _update_camera(delta: float) -> void:
	var frame: Vector2 = main.get("_frame_offset") if main.get("_frame_offset") != null else Vector2.ZERO
	var shake := 0.0
	if main.get("_shake") != null:
		shake = float(main.get("_shake"))
	var target := to3(_feet() + frame, ground_y(_feet()))
	# (eased toward what's under the buttons: see _dodge_buttons)
	target = target.lerp(_dodge_at, _dodge * DODGE_SHIFT)
	if shake > 0.05:
		target += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake / PX
	# Back far enough to take in the frame (the traveller and the float,
	# main.gd's framing), in this camera's own view.
	var half := frame.abs() / PX
	var vp := get_viewport().get_visible_rect().size
	var tan_v := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var tan_h := tan_v * vp.x / maxf(vp.y, 1.0)
	var need := maxf((half.x + FRAME_ROOM.x) / tan_h,
		(half.y + FRAME_ROOM.y) * sin(deg_to_rad(CAMERA_PITCH)) / tan_v)
	var want := clampf(need, CAMERA_DISTANCE, MAX_DISTANCE)
	_dist = lerpf(_dist, want, minf(1.0, delta * FRAME_EASE))
	var dist := _dist * (1.0 + _dodge * DODGE_BACK)
	var pitch := deg_to_rad(CAMERA_PITCH)
	var look := target + Vector3(0, 0.8, 0)
	var at := look + Vector3(0, sin(pitch), cos(pitch)) * dist
	camera.global_transform = Transform3D(Basis.looking_at(look - at, Vector3.UP), at)
	_dodge_buttons(delta)
	# Further out, the trees near the camera stay solid longer.
	var k := dist / CAMERA_DISTANCE
	for m in _fade_mats:
		m.distance_fade_min_distance = FADE_NEAR * k
		m.distance_fade_max_distance = FADE_FAR * k
