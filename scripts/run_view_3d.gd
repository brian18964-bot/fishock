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
## (user request: the trees' shadows were far too long - the moon was low,
## 27 degrees up; high now, about 57: a shadow two thirds of a tree's
## height)
## User requests: the moonlight half what it was, then the whole night's
## light (moon, ambient, fog) half again.
const MOON_DIM := 0.5
const NIGHT_DIM := 0.5
const MOON_DIR := Vector3(0.3, 1.2, -0.7)
## User request (phones were slow): how much there is to draw. Scattered
## things in CHUNK m squares (each drawn only on screen), plants none past
## COVER_REACH m.
const CHUNK := 12.0
const LOW_SCALE := 0.7
const COVER_REACH := 34.0
## User request: the map's edge a wall of tall pines, the traveller kept
## EDGE px in from it (so never seen walking up to it): how many, how
## tall (their scale), how deep a band out from the edge (m) - and a
## little in over it.
const BORDER_TREES := 520
const BORDER_SCALE := Vector2(1.7, 2.6)
const BORDER_DEPTH := 9.0
const BORDER_IN := 1.2
const EDGE := 90.0
## User request: the map and its ponds 2-3 times as big as the 2D run's
## (each way: 1.6 - 2.56 times the area).
const MAP_SCALE := 1.6
## The lamp's light against the 2D one's reach and strength.
const LAMP_REACH := 1.7
const LAMP_POWER := 1.15
## The rod while fishing, as in the 2D pictures (tools/render_player.py
## ROD_ANGLES): per frame of the clip, degrees up from pointing straight
## ahead (90 straight up, 180 straight back), ROD_SIDE out to the side of
## the hand holding it. Other clips hold it as the hand has it.
const ROD_ANGLES := {
	PlayerVisual.CLIP_CAST: [30, 70, 115, 150, 115, 70, 30, 18],
	PlayerVisual.CLIP_CAST_SHORT: [30, 70, 115, 150, 115, 70, 30, 18],
	# (user request: the hands sat awkwardly round a rod held flat - it's
	# held up toward the water now, the hands in front of the waist)
	PlayerVisual.CLIP_HOLD: [34, 34.5, 35, 35.5, 36, 35.5, 35, 34.5],
	PlayerVisual.CLIP_REEL: [32, 33.5, 32, 30.5, 32, 33.5, 32, 30.5],
	PlayerVisual.CLIP_FIGHT: [50, 54, 56, 54, 50, 46, 44, 46],
	PlayerVisual.CLIP_HOLD_RUN: [25, 28, 25, 22, 25, 28, 25, 22],
	PlayerVisual.CLIP_BITE: [34, 29, 36, 28, 35, 32, 36, 34],
	PlayerVisual.CLIP_TUG: [20, 48, 72, 80, 78, 72, 64, 56],
	PlayerVisual.CLIP_CATCH: [56, 68, 78, 84, 82, 74, 60, 44],
}
const ROD_SIDE := 25.0
## (the rod hand in toward the body's middle while fishing - CENTRED_CLIPS:
## this share of the way out to the shoulder kept; the rod's side angle
## then)
const CENTRE_KEEP := 0.55
const ROD_SIDE_CENTRED := 12.0
const CENTRED_CLIPS := [PlayerVisual.CLIP_HOLD, PlayerVisual.CLIP_BITE, PlayerVisual.CLIP_TUG,
	PlayerVisual.CLIP_REEL, PlayerVisual.CLIP_FIGHT]
## How fast the rod follows its angle (1/s), the arm comes in to hold it
## (s), and how fully the arm's brought after it.
const ROD_FOLLOW := 22.0
const ROD_EASE_IN := 0.15
const ARM_FOLLOW := 1.0
## The rod slung on the back (m behind the spine, its grip down from it),
## drawn or slung over STOW_TIME (s); the left hand up the rod from the
## grip (m), the reel and its crank (m along it, the crank's reach, turns
## a second); the hips' things out to the side (m).
const BACK_OUT := 0.22
const BACK_DOWN := 0.22
const STOW_TIME := 0.35
const FORE_GRIP := 0.3
const REEL_AT := 0.22
const CRANK_R := 0.07
const CRANK_TURNS := 1.4
const HIP_SIDE := 0.21
## The moves that take both hands (the lamp and the off hand's thing at
## the hips meanwhile).
const TWO_HANDED := ["pray", "pick", "kneel", "throw", "drink"]
## (the share of the rock's act the kick takes)
const KICK_SHARE := 0.55
## The moves (PlayerVisual) and the off hand's swings (Player.swing_kind)
## as the character's clips.
const MOVE_CLIPS := {"drink": "Drink", "look": "Look_Far", "eye": "Use_Eye", "pick": "Pick_Up", "lift": "Kick",
	"throw": "OverhandThrow", "cheer": "Victory", "fist": "Fist_Pump", "sad": "Disappointed", "scared": "Scared",
	"kneel": "Kneel"}
const ACT_CLIPS := {"chop": "TreeChopping", "slash": "Sword_Regular_A", "scoop": "Farm_Harvest", "shoot": "Pistol_Shoot"}
## The off hand's things, how long (m).
const OFFHAND_LENGTH := {"knife": 0.3, "hatchet": 0.48, "machete": 0.6, "glock": 0.2, "net": 0.7}
## (user request: the net's hoop smaller still - its breadth to its length)
const OFFHAND_GIRTH := {"net": 0.75}
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
	"ripple.gd", "atmosphere.gd", "weather_fx.gd", "dropped_fish.gd"]

## Asked for by the way the run was set off (the journey's 3D button, the
## settings'): the run that's starting is in 3D, and the ones after it (a
## retry) - until back at the camp (leave()).
## The one showing now.
static var active: RunView3D
## (tests: "low" or "high" in place of the device's own)
static var quality := ""
## User request: a run opens close on the traveller, who picks the lamp up
## off the ground (the rod already slung), then the camera draws back out
## and the night begins - INTRO: [the pick-up starting, its length, the
## hand closing on the lamp (share of it), the pull-out from .. to] (s).
## (Off for the tests that play a run straight away.)
static var intro := true
const INTRO := {"pick_at": 0.35, "pick": 1.8, "grab": 0.55, "pull_from": 2.0, "pull_to": 3.4}


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
var _beam: SpotLight3D
var _float: Node3D
var _float_body: MeshInstance3D
var _line: MeshInstance3D
var _guide: MeshInstance3D
var _guide_label: Label3D
## The eye items in 3D (user report: their effect and their guide never
## showed): the guide's name and how far; the 'true eye' over the head -
## the 2D one drawn again into a small view of its own, shown as a
## picture over the character (_sync_true_eye).
var _eye_label: Label3D
var _eye_view: SubViewport
var _eye_sprite: Sprite3D
var _eye_of := 0
var _ring: MeshInstance3D
## 2D picture -> its stand-in; 2D light -> its 3D light.
var _sprites := {}
var _lights := {}
## New nodes to look at next frame.
var _pending: Array = []
var _walk: Array = []  # [Rect2 (2D), deck height]
var _raised: Array = []
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
## The opening (INTRO): its time (-1 once over), whether the lamp's in
## hand yet, the lamp on the ground meanwhile.
var _intro_t := -1.0
var _intro_grabbed := true
var _intro_lamp: Node3D
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
## User request: the rod on the back while walking (1), in both hands to
## fish (0); the lamp and the off hand's thing in hand (1) or at the hips;
## the left hand let go of the rod (1).
var _stow := 1.0
var _lamp_in := 1.0
var _centred := 0.0
## (how much of the rod's angle the centred arm follows: a little holding,
## most of it on the strike so the arms come up with the rod)
var _arm_follow := 0.4
var _off_in := 1.0
var _left_free := 0.0
var _left_ik: TwoBoneIK3D
var _left_target: Marker3D
var _left_pole: Marker3D
var _crank := 0.0
var _offhand: Node3D
var _offhand_id := ""
var _tool := Lantern.Tool.LAMP
## User request: the light carried sways as it's walked - the lamp swinging
## in the hand or from the belt, the flashlight bobbing with the arm - and
## its light with it. The lamp at the hip: a damped pendulum of its own
## (as CharacterRig's in the hand), pushed by the hips' moves and the
## stride (GAIT_SWING: radians of push at a full walk, across and along).
const GAIT_SWING := Vector2(0.16, 0.07)
const LIGHT_SWAY := 1.3
var _hip_swing := Vector2.ZERO
var _hip_swing_vel := Vector2.ZERO
var _hip_last := Vector3.ZERO
var _hip_vel := Vector3.ZERO
## 2D pictures shown by models here instead (the start camp's).
var _replaced := {}


## User decision: the game is 3D from now on - every run (free runs, the
## campaign's levels, the tutorial) is the lakeside forest shown here; the
## 2D world under it holds the rules only, its pictures gone.
static func wants(_theme := "") -> bool:
	return true


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
	player.edge = EDGE
	_visual = player.get_node("Body")
	_environment()
	# The map's docks and boats come in a frame after it's made.
	for _i in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
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
	_landmarks()
	_cover()
	var t2 := Time.get_ticks_msec()
	_character()
	_line_and_float()
	_fireflies()
	_rest_2d_only(main)
	for n in main.get_children():
		_scan(n)
	print_verbose("RunView3D: land %d ms, props %d ms, the rest %d ms" % [t1 - t0, t2 - t1, Time.get_ticks_msec() - t2])
	player.cast_started.connect(func(at: Vector2, _t): _splash_ring(at))
	built = true
	if intro:
		_intro_t = 0.0
		_intro_grabbed = false


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
		if not zone.has_meta("bounds"):
			continue
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
	# (the altar stone - stepped up onto: [centre, radius px, top m])
	for r in _raised:
		if (r[0] as Vector2).distance_to(p) < float(r[1]):
			return LAND_Y + float(r[2])
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
	sh.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	# (the theme's two floors: its forest floor under the trees, grass in
	# the open)
	for pair in [["grass", "grass"], ["forest", "forest_floor"], ["path", "dirt"], ["stone", "lp_stone"], ["mud", "mud"]]:
		mat.set_shader_parameter(pair[0] + "_tex", load("res://assets/sprites/ground/%s_albedo.png" % pair[1]))
		mat.set_shader_parameter(pair[0] + "_nrm", load("res://assets/sprites/ground/%s_normal.png" % pair[1]))
	mi.material_override = mat
	add_child(mi)


## User request: the water was hard to tell from the land (and to find).
## Each pond's own shader (WATER_SHADER): its depth baked into a texture
## (WaterZone.depth) - pale and see-through at the very edge, a wet line
## along the shore, darker out deep; glossy, so the lamp's light (and the
## moon's) shines off it: walk near with the light up and it gleams.
func _water() -> void:
	var i := 0
	var sh := Shader.new()
	sh.code = WATER_SHADER
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
	for z in _zones():
		var zone: WaterZone = z
		var box: Rect2 = zone.get_meta("bounds")
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("wave_tex", t)
		mat.set_shader_parameter("moon_dir", MOON_DIR)
		mat.set_shader_parameter("depth_tex", _depth_texture(zone, box))
		mat.set_shader_parameter("box", Vector4(box.position.x / PX, box.position.y / PX, box.size.x / PX, box.size.y / PX))
		if zone.is_rare():
			mat.set_shader_parameter("deep", Color(0.05, 0.012, 0.09))
			mat.set_shader_parameter("shallow", Color(0.2, 0.08, 0.3))
			mat.set_shader_parameter("edge_tint", Color(0.75, 0.55, 1.0))
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


## How deep the pond is across its box (r: 0 at DEPTH_RANGE.x px out of the
## water, 1 at DEPTH_RANGE.y in).
const DEPTH_RANGE := Vector2(-20.0, 120.0)
const DEPTH_TEXEL := 6.0


func _depth_texture(zone: WaterZone, box: Rect2) -> Texture2D:
	var w := clampi(int(box.size.x / DEPTH_TEXEL), 8, 512)
	var h := clampi(int(box.size.y / DEPTH_TEXEL), 8, 512)
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var p := box.position + Vector2((x + 0.5) / w * box.size.x, (y + 0.5) / h * box.size.y)
			var d := zone.depth(p)
			img.set_pixel(x, y, Color.from_hsv(0, 0, clampf((d - DEPTH_RANGE.x) / (DEPTH_RANGE.y - DEPTH_RANGE.x), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always;
uniform sampler2D wave_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform vec4 box;
uniform vec3 deep : source_color = vec3(0.012, 0.03, 0.05);
uniform vec3 shallow : source_color = vec3(0.07, 0.13, 0.16);
uniform vec3 edge_tint : source_color = vec3(0.62, 0.78, 0.85);
uniform vec3 moon_dir = vec3(0.25, 0.22, -1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 buv = (wpos.xz - box.xy) / box.zw;
	// px in from the shore (DEPTH_RANGE)
	float d = mix(-20.0, 120.0, texture(depth_tex, buv).r);
	if (d < -2.0) { discard; }
	vec2 uv = wpos.xz * 0.05;
	vec3 a = texture(wave_tex, uv + vec2(TIME * 0.012, TIME * 0.006)).rgb;
	vec3 b = texture(wave_tex, uv * 1.7 - vec2(TIME * 0.009, -TIME * 0.011)).rgb;
	vec3 nm = normalize(mix(a, b, 0.5));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.3;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float deepness = smoothstep(4.0, 90.0, d);
	vec3 col = mix(shallow, deep, deepness);
	// the wet line along the shore, breathing a little
	float line = (1.0 - smoothstep(0.0, 7.0, abs(d - 3.0))) * (0.75 + 0.25 * sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5));
	ALBEDO = mix(col, edge_tint * 0.35, line * 0.6);
	vec3 wn = normalize(vec3((nm.x - 0.5) * 0.5, 1.0, (nm.y - 0.5) * 0.5));
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	vec3 r = reflect(-VIEW, vn);
	vec3 m = normalize((VIEW_MATRIX * vec4(normalize(moon_dir), 0.0)).xyz);
	float g = pow(max(dot(r, m), 0.0), 140.0);
	// (a faint night sky in it, more at a glance; the moon's glints)
	EMISSION = vec3(0.03, 0.045, 0.07) * fres + vec3(0.6, 0.7, 0.85) * g * 0.35 + edge_tint * line * 0.035;
	ROUGHNESS = 0.06;
	SPECULAR = 0.75;
	METALLIC = 0.15;
	ALPHA = clamp(0.55 + d * 0.06, 0.0, 0.97);
}
"""


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
	# (each the pine its 2D trunk was sized for - MapTree.kind, tree_scale:
	# the trunk's base as wide as its solid one, its branches over the head)
	for t in get_tree().get_nodes_in_group("trees"):
		var tree := t as Node2D
		if tree == null:
			continue
		var kind: String = str(tree.get("kind")) if tree.get("kind") != null else "pine_b"
		var mi := MeshInstance3D.new()
		mi.mesh = meshes.get(kind, meshes.pine_b)
		var s: float = float(tree.get("tree_scale")) if tree.get("tree_scale") != null else 0.9
		mi.scale = Vector3(s, s, s)
		mi.rotation.y = _rng.randf() * TAU
		mi.position = to3(tree.global_position, LAND_Y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		_trees.append([tree, mi])
	# The edge: a wall of tall pines, thick, from a little in over it out
	# past where the map ends (no shadows: the moon's are only near anyway).
	var rect := _map_rect()
	var inner := rect.grow(-BORDER_IN * PX)
	var made := 0
	while made < BORDER_TREES:
		var p := Vector2(_rng.randf_range(rect.position.x - BORDER_DEPTH * PX, rect.end.x + BORDER_DEPTH * PX),
			_rng.randf_range(rect.position.y - BORDER_DEPTH * PX, rect.end.y + BORDER_DEPTH * PX))
		if inner.has_point(p):
			continue
		made += 1
		var out := Vector2(maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0),
			maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)).length() / PX
		spots[pines[made % 3]].append(to3(p, LAND_Y + 1.4 * smoothstep(0.0, MARGIN, out)))
	for kind in pines:
		var xfs := []
		for at in spots[kind]:
			var s := _rng.randf_range(BORDER_SCALE.x, BORDER_SCALE.y)
			xfs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), at))
		_scatter(meshes[kind], xfs, false)
	# The rocks, bushes and turning stones: each exactly as big as its 2D
	# base (user request: nothing walks into anything).
	for n in main.get_children():
		var path := _script_name(n)
		var at: Vector2 = (n as Node2D).global_position if n is Node2D else Vector2.ZERO
		if path == "obstacle.gd":
			var r: Vector2 = n.get("radii")
			_fitted(str(n.get("model")), to3(at, LAND_Y - 0.05), r * 2.0 / PX, 0.0, true)
		elif path == "bush.gd":
			var d: float = float(n.get("radius")) * 2.0 / PX
			_fitted("fern", to3(at, LAND_Y), Vector2(d, d), _rng.randf() * TAU, false)
		elif path == "flip_rock.gd":
			var d: float = float(n.get("radius")) * 2.0 / PX
			var rock := _fitted(str(n.get("model")), to3(at, LAND_Y - 0.03), Vector2(d, d), _rng.randf() * TAU, true)
			if rock != null:
				_flip_rocks[n] = rock


## A model of the trial's (`name`) at `at`, as wide and deep as `base` (m;
## across x, z before `yaw`), its height in proportion.
func _fitted(name: String, at: Vector3, base: Vector2, yaw: float, shadow: bool) -> Node3D:
	var found := _model_mesh(name, true)
	if found.is_empty():
		return null
	var mesh: Mesh = found[0]
	var box := mesh.get_aabb()
	var sx := base.x / maxf(box.size.x, 0.01)
	var sz := base.y / maxf(box.size.z, 0.01)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3(sx, (sx + sz) * 0.5, sz)
	mi.rotation.y = yaw
	mi.position = at - Basis(Vector3.UP, yaw) * Vector3(box.get_center().x * sx, 0.0, box.get_center().z * sz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow and not _low else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


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
	for spec in FuelStation.DRUMS:
		var drum := CampModel.make("drum")
		if drum == null:
			continue
		drum.position = to3(at + spec[0], LAND_Y + (0.32 if spec[2] else 0.0))
		drum.rotation = Vector3(0, spec[1], PI * 0.5 if spec[2] else 0.0)
		drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(drum)
	var tent := CampModel.make("tent_%d" % clampi(Profile.camp_tent, 1, 9))
	if tent != null:
		tent.position = to3(at + FuelStation.tent_spot(), LAND_Y)
		tent.rotation.y = PI
		tent.scale = Vector3.ONE * FuelStation.TENT_SCALE
		tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(tent)
	for name in ["Visual", "Tent"]:
		var n := station.get_node_or_null(name)
		if n != null:
			_replaced[n] = true


## The altar and the rune stones of the way out (the escape point) as
## their models (tools/build_run3d_models.py); the stones' runes glow
## as the 2D ones do once the offering's made.
func _landmarks() -> void:
	for spec in [["Altar", "altar", 2.3], ["EscapePoint", "runes", 2.4]]:
		var at := main.get_node_or_null(spec[0]) as Node2D
		var path: String = CREATURE_DIR + spec[1] + ".glb"
		if at == null or not ResourceLoader.exists(path):
			continue
		var model: Node3D = (load(path) as PackedScene).instantiate()
		add_child(model)
		var box := _aabb(model)
		var k: float = float(spec[2]) / maxf(maxf(box.size.x, box.size.z), 0.001)
		if spec[1] == "altar":
			# User request: the altar stone can be stood on (its top).
			_raised.append([at.global_position, float(spec[2]) * 0.5 * PX * 0.92, box.size.y * k])
		model.scale = Vector3.ONE * k
		model.position = to3(at.global_position, LAND_Y) - Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
		_weather(model, spec[1])
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var visual := at.get_node_or_null("Visual")
		if visual != null:
			_replaced[visual] = true
		if spec[1] == "runes":
			var glow := at.get_node_or_null("Glow")
			if glow != null:
				_replaced[glow] = true
				_rune_glow = [glow, model]


func _sync_runes() -> void:
	if _rune_glow.is_empty() or not is_instance_valid(_rune_glow[0]):
		return
	var glow: CanvasItem = _rune_glow[0]
	var lit := glow.modulate.a * glow.self_modulate.a if _shown(glow) else 0.0
	for mi in (_rune_glow[1] as Node3D).find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.get_surface_override_material_count():
			var mat := m.get_surface_override_material(i) as StandardMaterial3D
			if mat != null:
				mat.emission_enabled = lit > 0.01
				mat.emission = Color(0.35, 0.85, 1.0)
				mat.emission_energy_multiplier = lit * 1.6


## Ferns, lily pads and washed-up logs where the map's ground cover is
## (GroundCover.kind). User request: not crowded - the map scatters few.
func _cover() -> void:
	var ferns := []
	var mesh := _model_mesh("fern", true)
	for n in main.get_children():
		if _script_name(n) != "ground_cover.gd":
			continue
		var p: Vector2 = (n as Node2D).global_position
		match str(n.get("kind")):
			"lilypad":
				var leaf := CampModel.make("lotus_leaf")
				if leaf != null:
					leaf.position = to3(p, WATER_Y + 0.01)
					leaf.rotation.y = _rng.randf() * TAU
					leaf.scale = Vector3.ONE * _rng.randf_range(0.22, 0.34)
					add_child(leaf)
			"driftwood":
				var log := CampModel.make("log")
				if log != null:
					log.position = to3(p, WATER_Y + 0.05)
					log.rotation.y = _rng.randf() * TAU
					log.scale = Vector3.ONE * 0.6
					add_child(log)
			"plant", "shrub":
				if mesh.is_empty():
					continue
				var s: float = _rng.randf_range(0.55, 0.8) / maxf(mesh[1], 0.01)
				ferns.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)),
					to3(p, maxf(_height_at(_depth(p, _zones())), WATER_Y))))
	if not mesh.is_empty():
		_scatter(mesh[0], ferns, false, COVER_REACH)


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
	if REST_2D.has(_script_name(n)):
		_rest_2d_only.call_deferred(n)
	if n is SplashFx:
		_splash.call_deferred(n)
	elif n is Sprite2D or n is AnimatedSprite2D or n is PointLight2D:
		_pending.append(n)


## User request (a phone game - heat): what only the hidden 2D world draws -
## its light twins, silhouette shadows, the body's front layer, its rain
## and fireflies (CPU particles) - stops working away unseen; the 3D view
## has its own.
const REST_2D := ["light_twin.gd", "silhouette_shadow.gd", "body_front.gd", "weather_fx.gd"]


func _rest_2d_only(from: Node) -> void:
	if not is_instance_valid(from):
		return
	var all := [from]
	all.append_array(from.find_children("*", "", true, false))
	for n in all:
		if REST_2D.has(_script_name(n)):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			if n is CanvasItem:
				(n as CanvasItem).visible = false


## A splash (SplashFx) in 3D: droplets thrown up and a ring on the water;
## a fish leaping clear in an arc and back in.
const JUMP_FISH := "res://assets/models/fish/rainbow_trout.glb"


func _splash(fx: SplashFx) -> void:
	if not is_instance_valid(fx) or not built:
		return
	var at: Vector2 = fx.global_position
	var y := WATER_Y + 0.02
	var drops := CPUParticles3D.new()
	drops.one_shot = true
	drops.emitting = true
	drops.amount = 14 if not _low else 8
	drops.lifetime = 0.7
	drops.explosiveness = 0.9
	drops.direction = Vector3.UP
	drops.spread = 35.0
	drops.initial_velocity_min = 1.0
	drops.initial_velocity_max = 2.2 if fx.kind != "splash_bite" else 1.4
	drops.gravity = Vector3(0, -6.0, 0)
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.2
	var q := SphereMesh.new()
	q.radius = 0.025
	q.height = 0.05
	q.radial_segments = 4
	q.rings = 2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.9, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	drops.mesh = q
	drops.position = to3(at, y)
	add_child(drops)
	get_tree().create_timer(1.2).timeout.connect(drops.queue_free)
	_splash_ring(at)
	if fx.kind.begins_with("fish_jump") and ResourceLoader.exists(JUMP_FISH):
		var fish: Node3D = (load(JUMP_FISH) as PackedScene).instantiate()
		add_child(fish)
		var box := _aabb(fish)
		var k := 0.45 / maxf(maxf(box.size.x, box.size.z), 0.01)
		fish.scale = Vector3.ONE * k
		var dir := Vector3(1 if fx.kind.ends_with("right") else -1, 0, 0)
		var from := to3(at, WATER_Y) - dir * 0.4
		fish.position = from
		fish.look_at(fish.position + dir, Vector3.UP)
		var tw := create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(fish):
				fish.position = from + dir * 0.8 * t + Vector3.UP * 0.55 * sin(t * PI)
				fish.rotation.z = (t - 0.5) * 1.6, 0.0, 1.0, 0.7)
		tw.tween_callback(fish.queue_free)


## Stands up the pictures (and lights) under `n` that nothing else shows.
func _scan(n: Node) -> void:
	if n == self or n is CanvasLayer or n is SubViewport or MODELLED.has(_script_name(n)):
		return
	if n == player or n.name in ["Bobber", "Line", "GroundBackground", "Darkness"] and n.get_parent() == main:
		return
	if _creature_kind(n) != "":
		_add_creature(n)
	if (n is Sprite2D or n is AnimatedSprite2D) and not _replaced.has(n) and not _modelled(n):
		_stand_up(n)
	elif n is PointLight2D:
		_add_light(n)
	for c in n.get_children():
		_scan(c)


# ---------------------------------------------------------------- the creatures

## User request: the animals, the ghosts and the willow were the 2D
## pictures stood up - 3D models now (tools/build_run3d_models.py), each
## moving and turning as its 2D one does, its clip by how fast it goes
## (or what it's doing). kind: [size (m), sized by its height ("h") or its
## length ("l"), raised off the ground (m)]. The small ones are made a
## little larger than life, as the 2D pictures made them, to be seen.
const CREATURES := {
	"deer": [1.5, "h", 0.0], "stag": [1.8, "h", 0.0], "fox": [0.62, "h", 0.0], "wolf": [0.9, "h", 0.0],
	"husky": [0.8, "h", 0.0], "shiba": [0.62, "h", 0.0], "horse": [1.9, "h", 0.0], "white_horse": [1.9, "h", 0.0],
	"cow": [1.5, "h", 0.0], "bull": [1.6, "h", 0.0], "donkey": [1.35, "h", 0.0], "alpaca": [1.6, "h", 0.0],
	"rat": [0.8, "l", 0.0], "frog": [0.5, "l", 0.0], "snake": [1.3, "l", 0.0], "spider": [0.65, "l", 0.0],
	"black_spider": [0.6, "l", 0.0], "wasp": [0.45, "l", 0.55], "grasshopper": [0.45, "l", 0.0],
	"ghost": [1.1, "h", 0.9], "dragon": [2.3, "h", 0.0], "water_ghost": [1.6, "h", 0.0], "willow": [1.2, "h", 0.0],
}
const CREATURE_DIR := "res://assets/models/run3d/"
const BY_SCRIPT := {"ghost.gd": "ghost", "big_ghost.gd": "dragon", "water_ghost.gd": "water_ghost", "willow.gd": "willow"}
## node -> {node: Node3D (the holder), model, anim, clip, yaw, last (2D pos)}
var _creatures := {}
var _rune_glow: Array = []
## User request: the big ghost is a dragon now (tools/build_dragon.py) -
## the characters' skeleton under a dragon's head, wings, feet and tail,
## a ragged robe - and, as the ghost did, a lantern glowing green, in the
## hand its Idle (Idle_Lantern) holds up. The lantern hangs from its bail
## (CharacterRig.LAMP_BAIL), swinging as the dragon moves; the 2D one's
## light (BigGhost.lamp_light) is drawn from it.
const DRAGON_HAND := "hand_r"
const DRAGON_LAMP_SIZE := 1.6
const DRAGON_LAMP_GREEN := Color(0.55, 1.0, 0.6)


## What 3D model `n` (a node of the 2D world) is shown as ("": none).
func _creature_kind(n: Node) -> String:
	var kind := ""
	if n is Critter:
		kind = (n as Critter).species
	else:
		kind = BY_SCRIPT.get(_script_name(n), "")
	if kind == "" or not CREATURES.has(kind) or not ResourceLoader.exists(CREATURE_DIR + kind + ".glb"):
		return ""
	return kind


## Under something shown as a model (its own pictures not stood up; its
## glows - added on - still are).
func _modelled(n: Node) -> bool:
	var cm := (n as CanvasItem).material as CanvasItemMaterial if n is CanvasItem else null
	if cm != null and cm.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		return false
	var p := n.get_parent()
	while p != null and p != main:
		if _creatures.has(p):
			return true
		p = p.get_parent()
	return false


func _add_creature(n: Node) -> void:
	if _creatures.has(n):
		return
	var kind := _creature_kind(n)
	var holder := Node3D.new()
	holder.name = "Creature_" + kind
	add_child(holder)
	var model: Node3D = (load(CREATURE_DIR + kind + ".glb") as PackedScene).instantiate()
	holder.add_child(model)
	var box := _aabb(model)
	var spec: Array = CREATURES[kind]
	var along := box.size.y if spec[1] == "h" else maxf(box.size.x, box.size.z)
	var k := float(spec[0]) / maxf(along, 0.001)
	model.scale = Vector3.ONE * k
	model.position = Vector3(-(box.position.x + box.size.x * 0.5) * k, -box.position.y * k + float(spec[2]),
		-(box.position.z + box.size.z * 0.5) * k)
	var small: bool = float(spec[0]) < 1.0 and spec[1] == "l"
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small or _low \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_weather(model, kind)
	var anim: AnimationPlayer = null
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		anim = aps[0]
		for a in anim.get_animation_list():
			if a != "Claw" and a != "Eat" and a != "Attack":
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var at := (n as Node2D).global_position
	_creatures[n] = {"node": holder, "model": model, "anim": anim, "clip": "", "kind": kind, "yaw": 0.0,
		"last": at, "size": float(spec[0]), "lift": float(spec[2]), "time": _rng.randf() * 10.0}
	if kind == "dragon":
		_dragon_gear(_creatures[n], model)


## The dragon's lantern on its hand, its tail and wings swaying
## (EarTailSway: the tail_* and wing_* bones).
func _dragon_gear(c: Dictionary, model: Node3D) -> void:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk := sks[0] as Skeleton3D
	sk.add_child(EarTailSway.new())
	var hand := BoneAttachment3D.new()
	hand.bone_name = DRAGON_HAND
	sk.add_child(hand)
	var lamp: Node3D = CharacterRig.LAMP.instantiate()
	lamp.name = "GreenLantern"
	add_child(lamp)
	for mi in lamp.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as BaseMaterial3D
			mat.albedo_color = src.albedo_color * Color(0.6, 1.0, 0.65)
			mat.emission_enabled = true
			mat.emission = DRAGON_LAMP_GREEN * 0.5
			mat.emission_energy_multiplier = 0.6
			m.set_surface_override_material(i, mat)
	var glow := OmniLight3D.new()
	glow.name = "Flame"
	glow.light_color = DRAGON_LAMP_GREEN
	glow.light_energy = 0.6
	glow.omni_range = 0.9
	glow.position = Vector3(0, 0.13, 0)
	lamp.add_child(glow)
	c.hand = hand
	c.lamp = lamp
	c.swing = Vector2.ZERO
	c.swing_vel = Vector2.ZERO
	c.hand_last = Vector3.ZERO


## Hung from the dragon's hand by its bail, upright, swinging as the hand
## moves (a pendulum, as the traveller's).
func _hang_dragon_lamp(c: Dictionary, delta: float) -> void:
	var hand: Node3D = c.hand
	var lamp: Node3D = c.lamp
	lamp.visible = (c.node as Node3D).visible
	var model: Node3D = c.model
	var k := model.global_basis.get_scale().x * DRAGON_LAMP_SIZE
	var grip := hand.global_position
	var last: Vector3 = c.hand_last
	var vel := (grip - last) / maxf(delta, 0.001) if last != Vector3.ZERO else Vector3.ZERO
	c.hand_last = grip
	var yaw := Basis(Vector3.UP, float(c.yaw))
	var push := Vector2((yaw.inverse() * vel).x, (yaw.inverse() * vel).z).limit_length(4.0)
	var sw: Vector2 = c.swing
	var sv: Vector2 = c.swing_vel
	sv += (-sw * 30.0 - push * 0.9 * 6.0 - sv * 3.0) * delta
	sw = (sw + sv * delta).limit_length(0.6)
	c.swing = sw
	c.swing_vel = sv
	var b := yaw * Basis(Vector3.BACK, -sw.x) * Basis(Vector3.RIGHT, sw.y)
	lamp.global_transform = Transform3D(b.scaled(Vector3.ONE * k), grip - (b.scaled(Vector3.ONE * k)) * CharacterRig.LAMP_BAIL)


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.get_aabb()
		var sk := m.get_node_or_null(m.skeleton) as Skeleton3D if m.skeleton != NodePath("") else null
		if sk != null and m.skin != null and m.skin.get_bind_count() > 1:
			# (a skinned mesh is drawn where its bones put it: its own space
			# mapped by how the bones' bind places (in it) sit in the model)
			b = _skinned_box(n, m, sk, b)
		else:
			b = m.transform * b
			var p := m.get_parent()
			while p != null and p != n and p is Node3D:
				b = (p as Node3D).transform * b
				p = p.get_parent()
		box = b if first else box.merge(b)
		first = false
	return box


static func _skinned_box(n: Node3D, m: MeshInstance3D, sk: Skeleton3D, b: AABB) -> AABB:
	# Where its vertices are drawn at rest, each by the bone weighing on it
	# most (every few: enough for the box).
	var to_model := n.global_transform.affine_inverse() * sk.global_transform
	var binds := []
	for i in m.skin.get_bind_count():
		var bone := m.skin.get_bind_bone(i)
		if bone < 0:
			bone = sk.find_bone(m.skin.get_bind_name(i))
		binds.append(to_model * sk.get_bone_global_rest(maxi(bone, 0)) * m.skin.get_bind_pose(i))
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for s in m.mesh.get_surface_count():
		var arr := m.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones = arr[Mesh.ARRAY_BONES]
		var weights = arr[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or verts.is_empty():
			continue
		var per: int = bones.size() / verts.size()
		for v in range(0, verts.size(), 3):
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			var bi: int = int(bones[v * per + best])
			if bi < 0 or bi >= binds.size():
				continue
			var p: Vector3 = (binds[bi] as Transform3D) * verts[v]
			lo = lo.min(p)
			hi = hi.max(p)
	if lo == Vector3.INF:
		return b
	return AABB(lo, hi - lo)


## The ghosts and the willow came without pictures (their paint was
## Blender's own): weathered here - their colours under a mottled grime -
## and the ghosts a little see-through and lit from within.
func _weather(model: Node3D, kind: String) -> void:
	if not kind in ["ghost", "big_ghost", "water_ghost", "willow", "altar", "runes"]:
		return
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.width = 128
	tex.height = 128
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.45, 0.45, 0.45), Color(1, 1, 1)])
	tex.color_ramp = ramp
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = src.albedo_color if src != null else Color(0.5, 0.5, 0.5)
			if src != null and src.albedo_texture != null:
				mat.albedo_texture = src.albedo_texture
			else:
				mat.albedo_texture = tex
				mat.uv1_triplanar = true
				mat.uv1_scale = Vector3.ONE * 0.6
			mat.roughness = 0.85
			if kind in ["ghost", "big_ghost"]:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color * 0.6 + Color(0.05, 0.12, 0.08)
				mat.emission_energy_multiplier = 0.5
				mat.rim_enabled = true
				mat.rim = 0.6
			m.set_surface_override_material(i, mat)


func _sync_creatures(delta: float) -> void:
	for n in _creatures.keys():
		var c: Dictionary = _creatures[n]
		var holder: Node3D = c.node
		if not is_instance_valid(n):
			holder.queue_free()
			if c.has("lamp"):
				(c.lamp as Node).queue_free()
			_creatures.erase(n)
			continue
		var node := n as Node2D
		var on := _shown(node)
		if n is Critter and not (n as Critter).active:
			on = false
		holder.visible = on
		if c.has("lamp"):
			_hang_dragon_lamp(c, delta)
			# (asleep its lantern's out, as the 2D one's)
			(c.lamp as Node).get_node("Flame").visible = int(n.get("mode")) != BigGhost.Mode.ASLEEP
		if not on:
			continue
		c.time += delta
		var at := node.global_position
		var vel := (at - (c.last as Vector2)) / maxf(delta, 0.001)
		if n is CharacterBody2D:
			vel = (n as CharacterBody2D).velocity
		c.last = at
		var y := ground_y(at)
		var kind: String = c.kind
		var lift := 0.0
		match kind:
			"ghost":
				lift = 0.15 * sin(c.time * 2.2)
				holder.rotation.z = 0.08 * sin(c.time * 1.3)
			"wasp":
				lift = 0.06 * sin(c.time * 6.0)
			"water_ghost":
				# Sunk in the water as the 2D one is (its picture lowered).
				var v: Node2D = n.get("_visual")
				if v != null:
					lift = -v.position.y / PX
		# User request (3D: smooth, no "it was 2D"): the 2D world moves in
		# physics steps, the picture in frames - eased toward where it is,
		# so a step never shows as a hitch; its pace eased too, so a clip
		# doesn't flick between walking and standing.
		var target := to3(at, y + lift)
		if not c.has("shown") or (c.shown as Vector3).distance_to(target) > 3.0:
			c.shown = target
		c.shown = (c.shown as Vector3).lerp(target, 1.0 - exp(-delta * 16.0))
		holder.position = c.shown
		c.pace = lerpf(float(c.get("pace", 0.0)), vel.length() / PX, 1.0 - exp(-delta * 7.0))
		var speed: float = c.pace
		if kind == "ghost":
			# (it leans into where it drifts, and its sheet sways)
			var lean := clampf(speed * 0.12, 0.0, 0.3)
			holder.rotation.x = lerpf(holder.rotation.x, lean, minf(1.0, delta * 4.0))
			holder.scale = Vector3(1.0 - 0.04 * sin(c.time * 3.1), 1.0 + 0.05 * sin(c.time * 3.1), 1.0 - 0.04 * sin(c.time * 3.1))
		elif kind == "willow":
			# (no rig: it stands - breathing, and swaying in its rite)
			var v2: Node2D = n.get("visual")
			if v2 != null:
				holder.rotation.z = v2.rotation
				holder.scale = Vector3(1.0, v2.scale.y / maxf(v2.scale.x, 0.0001), 1.0)
		if speed > 0.08 or (vel.length() / PX > 0.2):
			var want := atan2(vel.x, vel.y)
			c.yaw = lerp_angle(float(c.yaw), want, minf(1.0, delta * 6.0))
		elif kind == "willow":
			# (turned the way the 2D one faces: the altar, or the traveller)
			var sector: int = Willow.SECTOR_TO_DIR.find(int(n.get("_dir")))
			if sector >= 0:
				var face := Vector2.RIGHT.rotated(sector * PI / 4.0)
				c.yaw = lerp_angle(float(c.yaw), atan2(face.x, face.y), minf(1.0, delta * 3.0))
		elif kind in ["water_ghost", "dragon"] and player != null:
			# (stood still: facing the traveller)
			var to := player.global_position - at
			if to.length() > 1.0:
				c.yaw = lerp_angle(float(c.yaw), atan2(to.x, to.y), minf(1.0, delta * 4.0))
		holder.rotation.y = c.yaw
		var anim: AnimationPlayer = c.anim
		if anim == null:
			continue
		var clip := "Idle"
		var rate := 1.0
		var size: float = c.size
		match kind:
			"dragon":
				var mode: int = n.get("mode")
				match mode:
					BigGhost.Mode.GRAB:
						clip = "Grab"
					BigGhost.Mode.EAT:
						clip = "Eat" if speed < 0.3 else "Chase"
					BigGhost.Mode.CHASE, BigGhost.Mode.SEARCH:
						clip = "Chase" if speed > 0.3 else "Walk"
						rate = clampf(speed / 2.2, 0.7, 1.4)
					_:
						var moving := speed > (0.05 if c.clip == "Walk" else 0.12)
						clip = "Walk" if moving else "Idle"
						if moving:
							rate = clampf(speed / 0.9, 0.5, 1.6)
			"water_ghost":
				clip = "Claw" if int(n.get("_phase")) == 2 else "Walk"
			_:
				# (hysteresis: it starts walking past 0.12 m/s, stops under 0.05)
				var moving := speed > (0.05 if c.clip in ["Walk", "Run"] else 0.12)
				if moving:
					var run := speed > size * (2.0 if c.clip == "Run" else 2.4) and anim.has_animation("Run")
					clip = "Run" if run else "Walk"
					rate = clampf(speed / (size * (2.6 if run else 0.9)), 0.5, 2.5)
		if not anim.has_animation(clip):
			clip = "Idle" if anim.has_animation("Idle") else anim.get_animation_list()[0]
		if clip != c.clip:
			c.clip = clip
			anim.play(clip, 0.25)
		anim.speed_scale = rate


## A fish dropped or thrown (DroppedFish; user decision: no pictures - its
## own 3D model, lying on its side, flapping a while, arcing when thrown;
## going grey as it spoils).
var _drops := {}


func _sync_dropped_fish(delta: float) -> void:
	for n in _drops.keys():
		if not is_instance_valid(n):
			(_drops[n] as Node3D).queue_free()
			_drops.erase(n)
	for n in get_tree().get_nodes_in_group("dropped_fish"):
		var d := n as Node2D
		if d == null:
			continue
		if not _drops.has(d):
			var id: String = str(d.get("fish_id"))
			var fish := FishModel.make(id)
			if fish == null:
				fish = FishModel.make(JUMP_FISH.get_file().get_basename())
			if fish == null:
				continue
			var holder := Node3D.new()
			holder.name = "Dropped_" + id
			add_child(holder)
			var pivot := Node3D.new()
			holder.add_child(pivot)
			pivot.add_child(fish)
			var box := fish.mesh.get_aabb()
			var lengthwise_x := box.size.x >= box.size.z
			var want: float = float(DroppedFish.LENGTH.get(str(d.get("size")), 26.0)) / PX
			var k := want / maxf(maxf(box.size.x, box.size.z), 0.001)
			fish.position = -box.get_center()
			pivot.scale = Vector3.ONE * k
			# (on its side: rolled about its length, its flank on the ground)
			if lengthwise_x:
				pivot.rotation.x = PI * 0.5
			else:
				pivot.rotation.z = PI * 0.5
			pivot.position.y = (box.size.z if lengthwise_x else box.size.x) * k * 0.5
			holder.rotation.y = randf() * TAU
			_drops[d] = holder
		var h: Node3D = _drops[d]
		h.visible = _shown(d)
		var visual := d.get_node_or_null("Visual") as Node2D
		var up := -visual.position.y / PX if visual != null else 0.0
		h.position = to3(d.global_position, ground_y(d.global_position) + 0.02 + up)
		var fresh: float = clampf(d.call("_freshness"), 0.0, 1.0) if d.has_method("_freshness") else 1.0
		var fishmi := h.get_child(0).get_child(0) as MeshInstance3D
		if fishmi != null:
			# (a fresh one flaps; up in the air it tumbles)
			FishModel.swim(fishmi, delta, 0.6 * fresh if up < 0.05 else 1.0)
			if up > 0.05:
				h.rotation.y += delta * 6.0


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
		if _creature_kind(p) != "":
			_add_creature(p)
		p = p.get_parent()
	return not _replaced.has(n) and not _modelled(n)


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
	# (the dragon's: from its lantern)
	var c: Dictionary = _creatures.get(l.get_parent(), {})
	if c.has("lamp"):
		o.global_position = (c.lamp as Node3D).get_node("Flame").global_position


# ---------------------------------------------------------------- the traveller

func _character() -> void:
	pivot = Node3D.new()
	pivot.name = "Traveller"
	add_child(pivot)
	rig = CharacterRig.new()
	rig.auto_idle = false
	pivot.add_child(rig)
	_arm_ik()
	# User report: no shadow under the character. A soft dark patch at its
	# feet always (sunk in the ground's bumps before - drawn over it now);
	# on a phone the only one (its 77 000 triangles aren't drawn a second
	# time into the moon's shadow).
	if _low:
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blob := MeshInstance3D.new()
	blob.name = "FootShadow"
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.render_priority = -1
	bm.albedo_color = Color(0, 0, 0, 0.7 if _low else 0.5)
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
	blob.position = Vector3(0, 0.05, 0)
	pivot.add_child(blob)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.72, 0.4)
	# (falling off gently: lighting the ground far round without burning
	# out the one holding it)
	_lamp.omni_attenuation = 0.65
	# (glinting off the water: how it shows where the water is)
	_lamp.light_specular = 0.9
	_lamp.shadow_enabled = not _low
	add_child(_lamp)
	_beam = SpotLight3D.new()
	_beam.name = "Beam"
	_beam.spot_angle = 26.0
	_beam.spot_attenuation = 0.8
	_beam.light_specular = 0.9
	_beam.shadow_enabled = not _low
	_beam.visible = false
	add_child(_beam)
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
	# (eased up and down: stepping onto the altar stone, off a dock)
	var to_y := ground_y(feet)
	var y_now := pivot.position.y if absf(pivot.position.y - to_y) < 1.0 else to_y
	pivot.position = to3(feet, move_toward(y_now, to_y, get_process_delta_time() * 2.4))
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
## time to hold it at (>= 0: scrubbed, not played)]. User request: each
## thing done its own move (the library's - tools/build_menu_character.py):
## a tree chopped, a blade swung, a live bait scooped up, the pistol
## fired; a rock turned over, a thing picked up, the 誘惑 bait thrown; the
## offering's prayer; what went wrong - the line snapped, the bait taken,
## the water ghost's grab, the ghost's grip, dizzy - and the oil drum
## carried.
func _pick_clip() -> Array:
	var v := _visual
	var speed := player.velocity.length() / PX
	# (in the ghost's grip: terrified, struggling)
	if v.struggling:
		return ["Terrified", 1.4, -1.0]
	if player.swing_kind == "shoo" and player.swing_left > 0.0:
		# (a beast waved off - user request: no weapon needed)
		return ["Wave_Big", 1.0, minf(1.0 - player.swing_left / maxf(player.swing_total, 0.01), 0.999)]
	if v.acting >= 0:
		# (user request: each use played out at its clip's own pace, after
		# the thing's drawn from the hip - Player.SWINGS; scrubbed smoothly
		# by the time, not the 2D sheet's frames)
		var act: String = ACT_CLIPS.get(player.swing_kind, "Interact")
		var since: float = player.swing_total - player.swing_left - Player.SWING_DRAW
		var play: float = player.swing_total - Player.SWING_DRAW
		var t := clampf(since / maxf(play, 0.01), 0.0, 1.0)
		match act:
			"TreeChopping":
				# (the loop's two blows, the second landing at the hit)
				return [act, 1.0, fposmod(t * 2.0, 1.0) if t < 0.999 else 0.999]
			"Sword_Regular_A":
				# (the slash in the first part, then held a moment)
				return [act, 1.0, clampf(t / 0.7, 0.0, 0.999)]
		return [act, 1.0, minf(t, 0.999)]
	if v.move != "":
		match v.move:
			"walk":
				return ["Walk", clampf(speed / WALK_PACE, 0.4, 2.4), -1.0]
			"sad_walk":
				return ["Walk", clampf(speed / WALK_PACE * 0.8, 0.3, 1.5), -1.0]
			"sad_idle":
				return ["Sad", 1.0, -1.0]
			"dizzy":
				# (the ghosts' muddle: reeling about)
				return ["Dizzy", 1.0, -1.0]
			"pray":
				return ["Pray", 1.0, -1.0]
		var t: float = 1.0 - player.move_left / maxf(player.move_time, 0.01) if player.move_left > 0.0 else -1.0
		var name: String = MOVE_CLIPS.get(v.move, "Idle")
		t = clampf(t, 0.0, 1.0) if t >= 0.0 else -1.0
		if name == "Kick" and t >= 0.0:
			# (the kick in the first part - its foot on the stone at
			# Player.ROCK_HEAVE_AT - then stood looking down)
			var kick := Player.ROCK_HEAVE_TIME * KICK_SHARE
			return ["Kick", 1.0, minf(t * Player.ROCK_HEAVE_TIME / kick, 0.999)]
		match player.move_note:
			"stolen":
				# (the water ghost's grab: knocked staggering - not off its feet
				# - a fish gone, then the fright)
				if t >= 0.0 and t < 0.4:
					return ["Hit_Knockback", 1.0, t / 0.4 * 0.3]
				return ["Scared", 1.0, (t - 0.4) / 0.6 if t >= 0.0 else -1.0]
		return [name, 1.0, t]
	if player.carrying_oil_drum:
		# (the drum held in both arms, walking it home)
		return ["Walk_Carry", clampf(speed / WALK_PACE, 0.0, 2.0), -1.0]
	match v.clip:
		PlayerVisual.CLIP_RUN, PlayerVisual.CLIP_HOLD_RUN:
			if speed * PX < PlayerVisual.WALK_MAX:
				return ["Walk", clampf(speed / WALK_PACE, 0.4, 2.4), -1.0]
			return ["Run", clampf(speed / RUN_PACE, 0.6, 2.0), -1.0]
		PlayerVisual.CLIP_CAST, PlayerVisual.CLIP_CAST_SHORT:
			# Wound back with the charge (frames 0-3), the whip (4-7).
			# (smoothly between the sheet's frames - v.cast_f)
			var f: float = v.cast_f if v.cast_f >= 0.0 else float(v.frame_in_clip)
			var keys := [0.0, 0.1, 0.2, 0.3, 0.4, 0.52, 0.68, 0.9]
			var lo := clampi(floori(f), 0, 7)
			var t: float = lerpf(keys[lo], keys[mini(lo + 1, 7)], f - lo)
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
		if scrub < 0.0 and not name in ["Fish_Catch", "Interact", "PickUp_Table", "Hit_Knockback", "Scared"]:
			a.loop_mode = Animation.LOOP_LINEAR
		anim.play(name, 0.18)
	if scrub >= 0.0:
		# (bug: at speed 0 the player's crossfade into the clip never moved
		# on - the body stayed in the pose it came from and the act wasn't
		# seen at all. It runs at speed 1, the fade going on, and is put
		# where the act's time has it every frame.)
		anim.speed_scale = 1.0
		# (a clip shorter than its act runs off its end and stops on its
		# own - put back on, at the act's time)
		if anim.current_animation != name:
			anim.play(name, 0.0)
		anim.seek(scrub * a.length, true)
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
	# The left arm onto the rod (user request: fishing with both hands -
	# the left on the rod above the grip, cranking the reel as it reels).
	_left_target = Marker3D.new()
	_left_target.name = "ReelHand"
	add_child(_left_target)
	_left_pole = Marker3D.new()
	_left_pole.name = "ReelElbow"
	add_child(_left_pole)
	_left_ik = TwoBoneIK3D.new()
	_left_ik.name = "ReelArm"
	sk.add_child(_left_ik)
	_left_ik.setting_count = 1
	_left_ik.set_root_bone_name(0, "upperarm_l")
	_left_ik.set_middle_bone_name(0, "lowerarm_l")
	_left_ik.set_end_bone_name(0, "hand_l")
	_left_ik.set_target_node(0, _left_ik.get_path_to(_left_target))
	_left_ik.set_pole_node(0, _left_ik.get_path_to(_left_pole))
	_left_ik.influence = 0.0
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
		var f: float = _visual.cast_f if _visual.cast_f >= 0.0 else float(_visual.frame_in_clip)
		var lo := clampi(floori(f), 0, 7)
		var want := deg_to_rad(lerpf(float(angles[lo]), float(angles[mini(lo + 1, 7)]), clampf(f - lo, 0.0, 1.0)))
		_rod_up = want if _rod_on < 0.05 else lerpf(_rod_up, want, minf(1.0, delta * ROD_FOLLOW))
	_ik.influence = _rod_on * ARM_FOLLOW
	_gear_state(delta)
	var sk := rig.skeleton
	var b := pivot.global_basis.orthonormalized()
	var shoulder := sk.global_transform * sk.get_bone_global_pose(_shoulder_bone).origin
	# (rod angle -> the arm's: holding low (18) the hand's at the waist,
	# forward; straight up (90) at the brow; back over the shoulder past it)
	var phi := deg_to_rad(-38.0) + (_rod_up - deg_to_rad(18.0)) * 0.95
	# (fishing: the hands low, in front of the waist, whatever the rod's
	# angle - it's the wrist that tips it up, not the arm)
	var settled_now := fishing and _visual.clip in CENTRED_CLIPS
	if settled_now or _centred > 0.0:
		_arm_follow = move_toward(_arm_follow, 1.5 if _visual.clip == PlayerVisual.CLIP_TUG else 0.4, delta / 0.15)
		var low := deg_to_rad(-58.0) + (_rod_up - deg_to_rad(35.0)) * _arm_follow
		phi = lerpf(phi, low, smoothstep(0.0, 1.0, _centred))
	var reach := b.z * cos(phi) + Vector3.UP * sin(phi)
	# User request: holding, waiting, reeling and fighting, the rod hand
	# comes in toward the middle of the body (the reeling hand meets it
	# there, not reaching across); out to its side only for the cast.
	var settled := fishing and _visual.clip in CENTRED_CLIPS
	_centred = move_toward(_centred, 1.0 if settled else 0.0, delta / 0.4)
	var shoulder_l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin
	var middle := (shoulder + shoulder_l) * 0.5
	var from := (shoulder - b.x * 0.05).lerp(middle + (shoulder - middle) * CENTRE_KEEP, smoothstep(0.0, 1.0, _centred))
	# (reaching less far out while fishing: the elbow bent, the hands in
	# close in front of the waist)
	_ik_target.global_position = from + reach * _arm_len * lerpf(0.8, 0.58 + (_arm_follow - 0.4) * 0.2, smoothstep(0.0, 1.0, _centred))
	# (the elbow out to the side and down)
	# (the elbow out to the side and down; tucked in, down by the ribs, while
	# fishing with the hands in front)
	var tuck := smoothstep(0.0, 1.0, _centred)
	_ik_pole.global_position = shoulder - b.x * lerpf(0.5, 0.2, tuck) + Vector3.DOWN * lerpf(0.35, 0.6, tuck) - b.z * lerpf(0.15, 0.25, tuck)
	# The left hand up the rod from the right (as it was placed last frame),
	# going round the reel's crank while it reels.
	var rod := _rod()
	var two := (1.0 - _stow) * (1.0 - _left_free)
	_left_ik.influence = two
	if rod != null and two > 0.0:
		var rb := rod.global_basis.orthonormalized()
		var at := rod.global_position + rb.y * FORE_GRIP
		if _visual.clip in [PlayerVisual.CLIP_REEL, PlayerVisual.CLIP_FIGHT] or player.state == Player.State.REELING:
			_crank += delta * TAU * CRANK_TURNS
			at = rod.global_position + rb.y * REEL_AT + (rb.x * cos(_crank) + rb.z * sin(_crank)) * CRANK_R + b.x * 0.06
		_left_target.global_position = at
		var tuck_l := smoothstep(0.0, 1.0, _centred)
		_left_pole.global_position = shoulder_l + b.x * lerpf(0.5, 0.22, tuck_l) + Vector3.DOWN * lerpf(0.4, 0.6, tuck_l) - b.z * lerpf(0.1, 0.25, tuck_l)


## Once the arms are posed: the rod in the hand, pointed (ROD_ANGLES)
## while fishing, else as the hand holds it - or slung on the back; the
## lamp and the off hand's thing in hand, or hung at the hips.
func _hold_rod() -> void:
	var rod := _rod()
	var sk := rig.skeleton
	var b := pivot.global_basis.orthonormalized()
	if rod != null:
		var hand := sk.global_transform * sk.get_bone_global_pose(_hand_bone)
		var rest: Transform3D = rod.get_meta("rest")
		var held := hand * rest
		if _rod_on > 0.0:
			var side := deg_to_rad(lerpf(ROD_SIDE, ROD_SIDE_CENTRED, smoothstep(0.0, 1.0, _centred)))
			# (the model faces +z; its right hand's side is -x)
			var dir := (b.z * cos(side) * cos(_rod_up) - b.x * sin(side) * cos(_rod_up) + Vector3.UP * sin(_rod_up)).normalized()
			var x := dir.cross(b.x if absf(dir.dot(b.z)) > 0.9 else b.z).normalized()
			var aimed := Transform3D(Basis(x, dir, x.cross(dir)).scaled(Vector3.ONE * CharacterRig.ROD_SCALE), held.origin)
			held = held.interpolate_with(aimed, _rod_on)
		if _stow > 0.0:
			held = held.interpolate_with(_on_back(sk, b), smoothstep(0.0, 1.0, _stow))
		rod.global_transform = held
	_hang_gear(sk, b)


## The rod slung across the back: the grip down by the left hip, the tip
## up over the right shoulder.
func _on_back(sk: Skeleton3D, b: Basis) -> Transform3D:
	var spine := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spine_03")).origin
	var dir := (Vector3.UP * 0.9 - b.x * 0.42).normalized()
	var z := (-b.z - dir * dir.dot(-b.z)).normalized()
	var x := dir.cross(z).normalized()
	var at := spine - b.z * BACK_OUT - dir * BACK_DOWN
	return Transform3D(Basis(x, dir, z).scaled(Vector3.ONE * CharacterRig.ROD_SCALE), at)


## The lamp (or flashlight) and the off hand's thing: in the hands
## (_lamp_in, _off_in 1), at the left and right hips (0).
func _hang_gear(sk: Skeleton3D, b: Basis) -> void:
	var pelvis := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("pelvis")).origin
	var lamp := rig._hang if rig._hang != null and is_instance_valid(rig._hang) else null
	if lamp == null:
		var att: Node3D = rig.attachments.get("hand_l")
		if att != null and att.get_child_count() > 0:
			lamp = att.get_child(0) as Node3D
	if lamp != null and lamp == rig._hang:
		# (the oil lamp: the rig hangs it from the fingers; down at the hip
		# here instead, upright)
		rig.gait_push = _gait() * 0.6
		if _lamp_in < 1.0:
			var sc := lamp.global_basis.get_scale().x
			# (hung from the belt by its bail, swinging)
			var hook := pelvis + b.x * HIP_SIDE + b.z * 0.03 + Vector3.DOWN * 0.12 + Vector3.UP * CharacterRig.LAMP_BAIL.y * sc
			_swing_hip_lamp(hook)
			var bs := Basis(Vector3.UP, pivot.global_rotation.y)
			if _hip_swing.length() > 0.001:
				bs = Basis(Vector3(_hip_swing.y, 0.0, -_hip_swing.x).normalized(), _hip_swing.length()) * bs
			bs = bs.scaled(Vector3.ONE * sc)
			var hip := Transform3D(bs, hook - bs * CharacterRig.LAMP_BAIL)
			lamp.global_transform = hip.interpolate_with(lamp.global_transform, smoothstep(0.0, 1.0, _lamp_in))
	elif lamp != null:
		# (the flashlight: clipped at the hip, pointed ahead)
		if not lamp.has_meta("rest"):
			lamp.set_meta("rest", lamp.transform)
			lamp.top_level = true
		var att: Node3D = rig.attachments.get("hand_l")
		var inhand: Transform3D = att.global_transform * (lamp.get_meta("rest") as Transform3D)
		var sc := inhand.basis.get_scale().x
		var hip := Transform3D(Basis(Vector3.UP, pivot.global_rotation.y - PI * 0.5).scaled(Vector3.ONE * sc),
			pelvis + b.x * HIP_SIDE + b.z * 0.08)
		lamp.global_transform = hip.interpolate_with(inhand, smoothstep(0.0, 1.0, _lamp_in))
	if _offhand != null:
		var hand := sk.global_transform * sk.get_bone_global_pose(_hand_bone)
		var len: float = _offhand.get_meta("length", 0.4)
		# In the hand: out ahead and up from the fist; at the hip: hung down
		# by the right thigh.
		var up := (b.z * 0.55 + Vector3.UP * 0.8).normalized()
		if _visual.acting >= 0:
			# (swung: along the forearm)
			var fore := hand.origin - sk.global_transform * sk.get_bone_global_pose(sk.find_bone("lowerarm_r")).origin
			up = fore.normalized() if fore.length() > 0.01 else up
		var in_hand := _along(up, hand.origin + up * len * 0.35, b)
		var at_hip := _along((Vector3.DOWN * 0.95 + b.z * 0.2).normalized(), pelvis - b.x * HIP_SIDE + Vector3.DOWN * 0.1, b)
		_offhand.global_transform = at_hip.interpolate_with(in_hand, smoothstep(0.0, 1.0, _off_in))


## The stride's push on a hanging light: side to side with each step,
## forward and back twice a stride, as hard as the walk is quick.
func _gait() -> Vector2:
	var speed := player.velocity.length() / PX
	if speed < 0.2 or rig == null or rig.anim == null or rig.anim.current_animation not in ["Walk", "Run", "Walk_Carry"]:
		return Vector2.ZERO
	var phase := rig.anim.current_animation_position / maxf(rig.anim.current_animation_length, 0.01) * TAU
	var k := clampf(speed / 1.6, 0.0, 1.3)
	var b := pivot.global_basis.orthonormalized()
	var across := sin(phase) * GAIT_SWING.x * k
	var along := cos(phase * 2.0) * GAIT_SWING.y * k
	var push := b.x * across + b.z * along
	return Vector2(push.x, push.z)


## The lamp at the hip as a pendulum from `hook` (world).
func _swing_hip_lamp(hook: Vector3) -> void:
	var delta := get_process_delta_time()
	if delta <= 0.0:
		return
	var vel := (hook - _hip_last) / delta
	var acc := (vel - _hip_vel) / delta
	if _hip_last == Vector3.ZERO:
		acc = Vector3.ZERO
	_hip_vel = vel
	_hip_last = hook
	var push := Vector2(-acc.x, -acc.z) * 0.012 + _gait()
	_hip_swing_vel += (push.limit_length(0.45) - _hip_swing) * 60.0 * delta - _hip_swing_vel * 5.0 * delta
	_hip_swing = (_hip_swing + _hip_swing_vel * delta).limit_length(0.5)


## How the light carried is swinging now (radians, the world's x and z),
## in the hand or at the hip.
func light_swing() -> Vector2:
	return rig.lamp_swing().lerp(_hip_swing, 1.0 - _lamp_in) if rig != null else Vector2.ZERO


## The off hand's thing placed along `dir`, its middle at `at`.
func _along(dir: Vector3, at: Vector3, b: Basis) -> Transform3D:
	var side := dir.cross(b.x if absf(dir.dot(b.x)) < 0.9 else b.z).normalized()
	var bs := Basis(side, dir, side.cross(dir))
	return Transform3D(bs, at)


## What's where this frame (eased): the rod in the hands or on the back,
## the lamp and the off hand's thing in hand or at the hips. As the 2D
## one has them (PlayerVisual.rod_on_back()): the rod drawn to fish, slung
## otherwise; both hands on it while it's drawn, and for the moves that
## take both (TWO_HANDED) - the things in them hung at the hips then.
func _gear_state(delta: float) -> void:
	var rod_out := not _visual.rod_on_back() and not (_visual.clip == PlayerVisual.CLIP_HOLD_RUN
		and player.state == Player.State.IDLE) and not player.carrying_oil_drum
	_stow = move_toward(_stow, 0.0 if rod_out else 1.0, delta / STOW_TIME)
	var both := rod_out or _visual.move in TWO_HANDED or (_visual.acting >= 0 and player.swing_kind in ["chop", "scoop"])
	# (the left hand off the rod: the struggle in the ghost's grip)
	_left_free = move_toward(_left_free, 1.0 if _visual.struggling else 0.0, delta / STOW_TIME)
	_lamp_in = move_toward(_lamp_in, 0.0 if both or player.carrying_oil_drum else 1.0, delta / STOW_TIME)
	var swinging := _visual.acting >= 0
	# User request: walking about, only the lamp in hand; the off hand's
	# thing stays at the hip till it's used (drawn for the swing, put back
	# after).
	_off_in = move_toward(_off_in, 1.0 if swinging else 0.0, delta / Player.SWING_DRAW)
	_sync_offhand()


## The off hand's thing (Profile.offhand()) as its model.
func _sync_offhand() -> void:
	var id := Profile.offhand()
	if id == _offhand_id:
		return
	_offhand_id = id
	if _offhand != null:
		_offhand.queue_free()
		_offhand = null
	var path := "res://assets/models/items/%s.glb" % id
	if id == "" or not ResourceLoader.exists(path):
		return
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.name = "Offhand"
	add_child(holder)
	holder.add_child(model)
	var box := _aabb(model)
	# (its longest side along the holder's y, its middle at the origin,
	# sized as OFFHAND_LENGTH has it; the heavier end - the head, the
	# blade, the hoop - up, away from the hand)
	var axis := 0
	for k in 3:
		if box.size[k] > box.size[axis]:
			axis = k
	var length: float = OFFHAND_LENGTH.get(id, 0.4)
	var k := length / maxf(box.size[axis], 0.001)
	var heavy := _heavy_end(model, axis, box)
	var rot := Basis.IDENTITY
	match axis:
		0:
			rot = Basis(Vector3.BACK, PI * 0.5 * (-1.0 if heavy > 0.0 else 1.0))
		1:
			rot = Basis.IDENTITY if heavy > 0.0 else Basis(Vector3.RIGHT, PI)
		2:
			rot = Basis(Vector3.RIGHT, PI * 0.5 * (-1.0 if heavy > 0.0 else 1.0))
	var sc := Vector3.ONE * k * float(OFFHAND_GIRTH.get(id, 1.0))
	sc[axis] = k
	model.transform = Transform3D(rot * Basis.from_scale(sc), rot * (-box.get_center() * sc))
	holder.set_meta("length", length)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_offhand = holder


## Which end of `model` along `axis` is the heavier (+1 the far end): the
## side its vertices crowd to from the box's middle.
func _heavy_end(model: Node3D, axis: int, box: AABB) -> float:
	var sum := 0.0
	var n := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var to_model := model.global_transform.affine_inverse() * m.global_transform
		for si in m.mesh.get_surface_count():
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in range(0, verts.size(), 4):
				sum += (to_model * verts[v])[axis] - box.get_center()[axis]
				n += 1
	return sum / maxf(n, 1)


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
	# (seen from above whichever way its triangles wind)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	_eye_label = _guide_label.duplicate() as Label3D
	_eye_label.font_size = 34
	add_child(_eye_label)


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
	_eye_guide(im)
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


## The eyes' and the binoculars' way (Player.guide - GuideArrow's, in 3D):
## a soft arrow on the ground from the feet toward the place, chevrons
## drifting out along it, the place's name and how far past its head, and
## a ring opening out on the place itself.
const EYE_ARROW := {"start": 0.55, "length": 1.25, "head": 0.55, "head_length": 0.45, "shaft": 0.17}


func _eye_guide(im: ImmediateMesh) -> void:
	var g: GuideArrow = player.guide
	_eye_label.visible = false
	if g == null or not g.active():
		return
	var fade := clampf(g.time_left / GuideArrow.FADE, 0.0, 1.0)
	var soft := g.color.lerp(Color(0.8, 0.8, 0.8), 1.0 - GuideArrow.SOFT)
	var feet := _feet()
	var y := ground_y(feet) + 0.04
	var from := to3(feet, y)
	var at := to3(g.target, ground_y(g.target) + 0.04)
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-dir.z, 0, dir.x)
	var a: Dictionary = EYE_ARROW
	var tip: float = a.start + a.length
	var neck: float = tip - float(a.head_length)
	var pt := func(along: float, across: float) -> Vector3: return from + dir * along + side * across
	var c := Color(soft, 0.55 * fade)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft: float = a.shaft * 0.5
	for p in [pt.call(a.start, shaft), pt.call(neck, shaft), pt.call(neck, -shaft),
			pt.call(a.start, shaft), pt.call(neck, -shaft), pt.call(a.start, -shaft),
			pt.call(neck, float(a.head) * 0.5), pt.call(tip, 0.0), pt.call(neck, -float(a.head) * 0.5)]:
		im.surface_set_color(c)
		im.surface_add_vertex(p)
	# (chevrons drifting out ahead of it)
	for i in 2:
		var k := fmod(_time * 0.7 + i * 0.5, 1.0)
		var along := tip + 0.15 + 0.55 * k
		var ca := Color(soft, 0.5 * sin(k * PI) * fade)
		for seg in [[pt.call(along - 0.15, 0.17), pt.call(along, 0.0)], [pt.call(along, 0.0), pt.call(along - 0.15, -0.17)]]:
			var d: Vector3 = (seg[1] - seg[0]).normalized()
			var w := Vector3(-d.z, 0, d.x) * 0.025
			for p in [seg[0] + w, seg[1] + w, seg[1] - w, seg[0] + w, seg[1] - w, seg[0] - w]:
				im.surface_set_color(ca)
				im.surface_add_vertex(p)
	# (on the place: a faint ring opening out, a still one inside it)
	var k := fmod(_time * 0.6, 1.0)
	for ring in [[0.35 + 0.9 * k, 0.05, 0.5 * (1.0 - k)], [0.3, 0.04, 0.45]]:
		var r: float = ring[0]
		var cr := Color(soft, float(ring[2]) * fade)
		for i in 32:
			var a0 := i * TAU / 32.0
			var a1 := (i + 1) * TAU / 32.0
			var o0 := Vector3(cos(a0), 0, sin(a0))
			var o1 := Vector3(cos(a1), 0, sin(a1))
			for p in [at + o0 * r, at + o0 * (r + ring[1]), at + o1 * (r + ring[1]), at + o0 * r, at + o1 * (r + ring[1]), at + o1 * r]:
				im.surface_set_color(cr)
				im.surface_add_vertex(p)
	im.surface_end()
	var meters := roundi(g.target.distance_to(player.global_position) / GuideArrow.PX_PER_M)
	_eye_label.text = "%s %d 公尺" % [g.label, meters] if meters > 2 else g.label
	_eye_label.modulate = Color(soft.lerp(Color.WHITE, 0.3), 0.85 * fade)
	_eye_label.position = pt.call(tip + 0.9, 0.0) + Vector3(0, 0.25, 0)
	_eye_label.visible = true


## The 'true eye' over the head (TrueEye), while the 2D one's open.
func _sync_true_eye() -> void:
	var eye := player.get_node_or_null("TrueEye")
	var id := eye.get_instance_id() if eye != null else 0
	if id != _eye_of:
		_eye_of = id
		if _eye_view != null:
			_eye_view.queue_free()
			_eye_sprite.queue_free()
			_eye_view = null
			_eye_sprite = null
		if eye != null:
			_eye_view = SubViewport.new()
			_eye_view.size = Vector2i(320, 240)
			_eye_view.transparent_bg = true
			_eye_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(_eye_view)
			var holder := Node2D.new()
			holder.position = Vector2(160, 120) - TrueEye.LIFT * 2.0
			holder.scale = Vector2.ONE * 2.0
			_eye_view.add_child(holder)
			var copy := TrueEye.new()
			copy.kind = eye.kind
			copy.look_dir = eye.look_dir
			holder.add_child(copy)
			_eye_sprite = Sprite3D.new()
			_eye_sprite.texture = _eye_view.get_texture()
			_eye_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_eye_sprite.shaded = false
			_eye_sprite.no_depth_test = true
			_eye_sprite.render_priority = 3
			_eye_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			_eye_sprite.pixel_size = 0.011
			add_child(_eye_sprite)
	if _eye_sprite != null:
		# (well over the head - clear of a button over it)
		_eye_sprite.global_position = pivot.global_position + Vector3(0, 3.1, 0)


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
	_moon.light_energy = 0.55 * MOON_DIM
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
	# (user request: too bright - finding the water is part of it; the
	# lamp's what shows it)
	# (user requests: the moonlight halved, then the whole night halved
	# again - NIGHT_DIM; the lamp as it was)
	_env.ambient_light_energy = lerpf(0.09, 0.3, k) * NIGHT_DIM
	_env.ambient_light_color = Color(0.2, 0.26, 0.38).lerp(Color(0.42, 0.45, 0.5), k)
	_moon.light_energy = lerpf(0.12, 0.34, k) * MOON_DIM * NIGHT_DIM
	_moon.light_color = Color(0.62, 0.72, 0.95).lerp(Color(0.9, 0.88, 0.85), k)
	_env.fog_light_color = (Color(0.05, 0.07, 0.11).lerp(Color(0.2, 0.22, 0.25), k) * NIGHT_DIM)
	_env.background_color = _env.fog_light_color * 0.5
	# The traveller's own light: the lamp's (or flashlight's) reach and
	# strength, at the hand.
	var lantern: PointLight2D = player.get_node_or_null("Lantern")
	if lantern != null:
		var on := lantern.enabled and lantern.visible
		_sync_tool(lantern)
		var beam := _tool == Lantern.Tool.FLASHLIGHT
		_lamp.visible = on and not beam
		_beam.visible = on and beam
		if on:
			var half := 128.0
			if lantern.texture != null:
				half = lantern.texture.get_width() * 0.5
			var reach := clampf(half * lantern.texture_scale / PX * LAMP_REACH, 2.5, 24.0)
			# (at the lamp, wherever it is - in the hand or at the hip - a
			# little out from the body, so it lights the ground round it more
			# than the one holding it)
			var at := pivot.global_position + Vector3(0, 1.0, 0)
			var held := _held_light()
			if held != null:
				at = held.global_position + Vector3(0, 0.1, 0)
			if beam:
				# (the flashlight's beam: where it's aimed, down a little)
				_beam.spot_range = reach * 1.3
				_beam.light_energy = lantern.energy * LAMP_POWER * 2.2
				_beam.light_color = lantern.color
				_beam.global_position = at + Vector3(0, 0.3, 0)
				var aim := Vector3(player.aim_dir.x, 0, player.aim_dir.y).normalized()
				if aim.length() < 0.5:
					aim = pivot.global_basis.z.normalized()
				var dir := (aim * 4.0 + Vector3.DOWN * 1.4).normalized()
				if held != null:
					# (where the flashlight itself points - bobbing with the
					# arm in the hand, with the hips at the belt - half of it)
					var points := held.global_basis.x.normalized()
					dir = dir.lerp(points, 0.45 if _lamp_in > 0.5 else 0.25).normalized()
				_beam.look_at(_beam.global_position + dir * 4.0, Vector3.UP)
			else:
				_lamp.omni_range = reach
				_lamp.light_energy = lantern.energy * LAMP_POWER
				_lamp.light_color = lantern.color
				# (held up over the head, as a lantern lights the way: not glaring
				# off the one under it)
				# (swinging with the lamp - user request)
				var sw := light_swing() * LIGHT_SWAY
				_lamp.global_position = at + pivot.global_basis.z.normalized() * 0.45 + Vector3(0, 0.85, 0) \
					+ Vector3(sw.x, 0.0, sw.y)


## The opening (INTRO): the lamp on the ground at the feet, picked up, then
## in the hand and lit there; walked off, it's over at once.
func _update_intro(delta: float) -> void:
	if _intro_t < 0.0:
		return
	var held := _held_light()
	if _intro_lamp == null and held != null:
		_intro_lamp = held.duplicate() as Node3D
		_intro_lamp.top_level = true
		add_child(_intro_lamp)
		var b := pivot.global_basis.orthonormalized()
		var at := pivot.global_position + b.z * 0.42 + b.x * 0.12
		_intro_lamp.global_transform = Transform3D(Basis(Vector3.UP, pivot.global_rotation.y).scaled(held.global_basis.get_scale()),
			Vector3(at.x, ground_y(_feet()), at.z))
	var was := _intro_t
	_intro_t += delta
	var pick_at: float = INTRO.pick_at
	if was < pick_at and _intro_t >= pick_at and player.state == Player.State.IDLE:
		player.perform("pick", float(INTRO.pick))
	var grab := pick_at + float(INTRO.pick) * float(INTRO.grab)
	var walked := player.velocity.length() > 8.0 or player.state != Player.State.IDLE
	if not _intro_grabbed and (_intro_t >= grab or walked):
		_intro_grabbed = true
		if _intro_lamp != null:
			_intro_lamp.queue_free()
			_intro_lamp = null
	if held != null:
		held.visible = _intro_grabbed
	if not _intro_grabbed and _intro_lamp != null:
		# (its light on the ground with it till then)
		_lamp.global_position = _intro_lamp.global_position + Vector3(0, 0.45, 0)
	if walked and _intro_t < float(INTRO.pull_from):
		_intro_t = float(INTRO.pull_from)
	if _intro_t >= float(INTRO.pull_to):
		_intro_t = -1.0


## The lamp (or flashlight) model the character has.
func _held_light() -> Node3D:
	if rig._hang != null and is_instance_valid(rig._hang):
		return rig._hang
	var att: Node3D = rig.attachments.get("hand_l")
	if att != null and att.get_child_count() > 0:
		return att.get_child(0) as Node3D
	return null


## The flashlight in hand when it's the one on (Lantern.tool), the lamp
## otherwise; its light a beam ahead, not the lamp's all round.
func _sync_tool(lantern: Node) -> void:
	var tool := int(lantern.get("tool"))
	if tool == _tool:
		return
	_tool = tool
	if tool == Lantern.Tool.FLASHLIGHT:
		rig._hang = null
		rig.equip_flashlight()
	else:
		rig.equip_lamp()


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
	# (the creatures first: the dragon's light is from its lantern)
	_sync_creatures(delta)
	for l in _lights.keys():
		if not is_instance_valid(l):
			(_lights[l] as Node).queue_free()
			_lights.erase(l)
			continue
		_sync_light(l, _lights[l])
	_sync_dropped_fish(delta)
	_sync_runes()
	# (a stone being turned over: where it's rolled to, tipped over)
	for n in _flip_rocks:
		if is_instance_valid(n) and float(n.get("turned")) > 0.0 and not n.has_meta("settled"):
			var roller = n.get("_roller")
			var r3: Node3D = _flip_rocks[n]
			if not r3.has_meta("home"):
				r3.set_meta("home", r3.position - to3((n as Node2D).global_position))
			r3.position = to3((roller as Node2D).global_position, 0.0) + (r3.get_meta("home") as Vector3) \
				+ Vector3(0, 0.08 * sin(float(n.get("turned")) * PI), 0)
			r3.rotation.z = (roller as Node2D).rotation
			if float(n.get("turned")) >= 1.0:
				n.set_meta("settled", true)
	for pair in _trees:
		if is_instance_valid(pair[0]):
			(pair[1] as Node3D).visible = (pair[0] as Node2D).visible
	_place_traveller(delta)
	_animate()
	_aim_rod(delta)
	if _drum != null:
		# (user decision: no pictures - the can lying about is the model too)
		var lying := main.get_node_or_null("OilDrum") as Node2D
		_drum.visible = player.carrying_oil_drum or (lying != null and lying.visible and _shown(lying))
		if _drum.visible and not player.carrying_oil_drum:
			_drum.global_position = to3(lying.global_position, LAND_Y)
			_drum.global_rotation = Vector3.ZERO
		elif _drum.visible:
			# (held in both arms in front, walked home)
			var b := pivot.global_basis.orthonormalized()
			_drum.global_position = pivot.global_position + b.z * 0.42 + Vector3(0, 0.55, 0)
			_drum.global_rotation = Vector3(0, pivot.global_rotation.y, 0)
	_update_line()
	_update_guide()
	_sync_true_eye()
	_update_light()
	_update_intro(delta)
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
	if _intro_t >= 0.0:
		# (the opening: close in front of the traveller, drawing back out
		# to the usual view)
		var b := pivot.global_basis.orthonormalized()
		var head := pivot.global_position + Vector3(0, 0.95, 0)
		var close_at := head + b.z * 2.1 + b.x * 0.8 + Vector3(0, 0.55, 0)
		var close := Transform3D(Basis.looking_at(head - close_at, Vector3.UP), close_at)
		var k := smoothstep(float(INTRO.pull_from), float(INTRO.pull_to), _intro_t)
		camera.global_transform = close.interpolate_with(camera.global_transform, k)
	_dodge_buttons(delta)
	# Further out, the trees near the camera stay solid longer.
	var k := dist / CAMERA_DISTANCE
	for m in _fade_mats:
		m.distance_fade_min_distance = FADE_NEAR * k
		m.distance_fade_max_distance = FADE_FAR * k


## The ground: grass in the open, forest floor under the trees, dirt
## paths, stone and mud by the water (from the first 3D trial).
const GROUND_SHADER := """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec4 paint;
void vertex() { paint = COLOR; }
void fragment() {
	vec2 uv = UV * 0.25;
	vec3 c = mix(texture(grass_tex, uv).rgb, texture(forest_tex, uv * 0.9).rgb, paint.a);
	vec3 n = mix(texture(grass_nrm, uv).rgb, texture(forest_nrm, uv * 0.9).rgb, paint.a);
	c = mix(c, texture(mud_tex, uv).rgb * 0.8, paint.b);
	n = mix(n, texture(mud_nrm, uv).rgb, paint.b);
	c = mix(c, texture(path_tex, uv * 1.2).rgb, paint.r);
	n = mix(n, texture(path_nrm, uv * 1.2).rgb, paint.r);
	c = mix(c, texture(stone_tex, uv * 0.8).rgb * 0.6, paint.g);
	n = mix(n, texture(stone_nrm, uv * 0.8).rgb, paint.g);
	ALBEDO = c * 0.85;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = 0.92;
}
"""
