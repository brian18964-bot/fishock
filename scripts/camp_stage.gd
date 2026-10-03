class_name CampStage
extends Node3D

## The main screen's 3D camp - the travellers' one safe place (user
## request: the camp rebuilt from the user's models; a clearing by a lake
## at night, everything in it something to tap): the campfire burning in
## its ring of stones, logs to sit on; on the left the weathered crate
## and the backpack leant against it (both the warehouse), the tent behind
## (the equipment page; which tent is Profile.camp_tent) with the rod leant
## beside it; behind the fire an old oil drum with the lamp on it, unlit,
## and another drum lying cut in half, water in it (the fish tank); off to
## the right, back by the water, the merchant's stall with the frog
## merchant, his covered boat tied up by the dock (the shop); far off at
## the water's edge the 渡石, the stone the travellers cross by - part of
## the view. The character rests by the fire, hands empty.
## Models: CampModel (tools/build_camp_models.py). Lit by the fire, the
## moon and a lamp at the stall (few lights, no shadows: cheap on a phone).
##
## Each page has a spot (STATIONS) the camera glides to; each tappable
## thing a hotspot (hotspot_at(), highlight()): a faint gold rim always,
## bright with its name while pressed or hovered.

const STATIONS := {
	"home": [Vector3(0.3, 2.3, 6.9), Vector3(-0.15, 0.75, -2.2), 42.0],
	"warehouse": [Vector3(-1.6, 1.5, 2.9), Vector3(-3.05, 0.45, 0.35), 38.0],
	"equipment": [Vector3(-1.4, 1.7, 1.6), Vector3(-3.4, 0.9, -2.6), 40.0],
	"shop": [Vector3(3.3, 1.7, -1.3), Vector3(5.9, 1.1, -5.7), 40.0],
	"fish_tank": [Vector3(2.25, 2.1, 1.6), Vector3(3.3, 0.25, 0.3), 40.0],
	"fish_log": [Vector3(2.25, 2.1, 1.6), Vector3(3.3, 0.25, 0.3), 40.0],
	"stone": [Vector3(-0.3, 1.8, -1.6), Vector3(-0.5, 0.9, -6.4), 42.0],
	"journey": [Vector3(-0.3, 1.8, -1.6), Vector3(-0.5, 0.9, -6.4), 42.0],
}
const CHARACTER_AT := Vector3(-0.35, 0.0, 0.6)
const FIRE_AT := Vector3(0.75, 0.0, -0.35)
const CRATE_AT := Vector3(-3.05, 0.0, 0.3)
## The crate drawn out longer than the pack's (user request: 30%, then
## 20% more).
const CRATE_LENGTH := 1.56
const BACKPACK_AT := Vector3(-2.2, 0.0, 1.05)
const TENT_AT := Vector3(-4.6, 0.0, -3.5)
const ROD_AT := Vector3(-2.95, 0.0, -2.55)
const DRUM_AT := Vector3(0.2, 0.0, -2.05)
## A second drum beside it (no lamp).
const DRUM_2_AT := Vector3(0.95, 0.0, -2.55)
## The fish trough out on the right, its length toward the camera.
const TROUGH_AT := Vector3(3.3, 0.0, 0.3)
const TROUGH_YAW := PI / 2.0
## The drums made bigger than life, easier to tap (user request: the drum
## 20%, the fish trough 30%).
const DRUM_SCALE := 1.2
const TROUGH_SCALE := 1.3
## The lamp on the drum's lid.
const LAMP_ON_DRUM := Vector3(0.05, 0.92 * DRUM_SCALE, 0.02)
## The 渡石 far off, on the shore short of the water: part of the view,
## not of the camp.
const STONE_AT := Vector3(-0.6, 0.0, -6.45)
const STONE_SCALE := 0.6
const HUT_AT := Vector3(6.1, 0.0, -6.0)
const HUT_YAW := -0.95
const HUT_SCALE := 0.8
## Where the frog merchant potters, round his stall (its own frame, before
## its scale): its front corners and counter, its sides, round the back
## (the way in - user request: not through the walls) and inside behind
## the counter (on the stall's floor, 0.7 up); "counter" is where a
## visitor stands while he's inside.
const MERCHANT_PLACES := {
	"corner": Vector3(1.9, 0.0, 1.5), "front": Vector3(-0.3, 0.0, 2.1), "front_l": Vector3(-2.0, 0.0, 1.5),
	"side_r": Vector3(2.3, 0.0, -0.3), "side_l": Vector3(-2.3, 0.0, -0.3),
	"back_r": Vector3(2.1, 0.0, -2.0), "back_l": Vector3(-2.1, 0.0, -2.0), "back": Vector3(0.3, 0.0, -2.2),
	"inside": Vector3(0.2, 0.7, 0.05), "counter": Vector3(0.2, 0.0, 2.0),
}
## ... and out from it (the camp's frame): to the foot of the dock, out on
## it by his boat, and a spot on the open ground toward the camp - still
## well clear of the fire.
const MERCHANT_OUT := {
	"dock_base": Vector3(3.0, 0.0, -6.6), "dock": Vector3(3.15, 0.225, -8.2), "lookout": Vector3(3.5, 0.0, -4.3),
}
## His ways between them (none through the stall: in by the back).
const MERCHANT_LINKS := {
	"inside": ["back"], "back": ["inside", "back_l", "back_r"],
	"back_l": ["back", "side_l"], "back_r": ["back", "side_r"],
	"side_l": ["back_l", "front_l"], "side_r": ["back_r", "corner"],
	"corner": ["side_r", "front", "lookout"], "front": ["corner", "front_l", "lookout"],
	"front_l": ["front", "side_l", "dock_base"], "dock_base": ["front_l", "dock", "lookout"],
	"dock": ["dock_base"], "lookout": ["corner", "front", "dock_base"],
}
## The frog's size (the model is 1.25 m): small enough to stand inside.
const MERCHANT_SCALE := 0.7
const DOCK_AT := Vector3(2.9, 0.0, -7.05)
## The boat afloat, tied up against the dock (its right side), its bow
## just short of the beach (user request); the pack's boat drawn in to 60%
## of its length.
## The model stands on its rudder, its keel half a metre up: sunk so the
## hull sits in the water.
const BOAT_AT := Vector3(3.97, -0.6, -9.05)
const BOAT_LENGTH := 0.6
const LAKE_CENTER := Vector3(0.0, 0.0, -20.6)
const LAKE_RADIUS := 13.5
const MOON_DIR := Vector3(0.1, 0.17, -1.0)
## The logs to sit on by the fire (thicker than the pack's log, so the
## hips sit on it: its top at about 0.52 m): [where, which way one sits on
## it (null: facing the fire)] - the second lies across behind the fire,
## sat on facing out. And the woodpile by the tent.
const SEATS := [[Vector3(-0.75, 0.0, -0.6), null], [Vector3(1.95, 0.0, -1.45), Vector3(0, 0, 1)]]
const SEAT_SCALE := Vector3(1.18, 1.18, 1.15)
const WOODPILE_AT := Vector3(-2.0, 0.0, -2.6)
## The water in the cut drum (its surface's height and size), and the lotus
## leaves floating on it, as in the fish tank page's ([x, z, radius], the
## drum's own frame).
const TROUGH_WATER := [0.33, Vector2(0.84, 0.52)]
const TROUGH_PADS := [[-0.24, 0.08, 0.12], [0.22, -0.11, 0.09], [0.02, 0.15, 0.065]]
const OUTLINE_COLOR := Color(1.0, 0.78, 0.38)

var camera: Camera3D
var character: CharacterRig
var character_pivot: Node3D
## page -> {node, label, center (world), radius (m), overlays: [ShaderMaterial]}
var hotspots := {}
## The character's life at the camp (CampLife): where it goes and does
## things - name -> {at (where it stands), face (what it looks at)} - and
## what it walks round ([centre, radius] on the ground).
var life: CampLife
var spots := {}
var obstacles: Array = []
var _fire_light: OmniLight3D
var _fire_glow: MeshInstance3D
var _embers_mat: StandardMaterial3D
var _stone_mat: StandardMaterial3D
var _boat: Node3D
var merchant: CampMerchant
var _tent_holder: Node3D
var _rod_holder: Node3D
var _water_mat: ShaderMaterial
var _drum_lamp: Node3D
var _stone_light: OmniLight3D
var _stone_flare := 0.0
var _lit := ""
var _tent_shown := -1
var _rod_shown := -1
var _time := 0.0
var _cam_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	_environment()
	_ground()
	_lake()
	_forest()
	_rocks()
	_fire()
	_seats()
	_crate()
	_tent()
	_drums()
	_stone()
	_stall()
	_dock()
	_wildlife()
	_places()
	_character()
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	go_to("home", false)
	Profile.profile_changed.connect(_on_profile_changed)


func _on_profile_changed() -> void:
	if not is_inside_tree():
		return
	# Only what changed (the profile changes with every coin).
	if Profile.camp_tent != _tent_shown:
		_dress_tent()
	if Profile.rod_tier != _rod_shown:
		_dress_rod()


# ---------------------------------------------------------------- camera

## Glides the camera to a station ("home", "shop", ...); `done` is called
## once it's there.
func go_to(station: String, animate := true, done := Callable()) -> void:
	var spot: Array = STATIONS.get(station, STATIONS.home)
	var to := Transform3D(Basis.IDENTITY, spot[0]).looking_at(spot[1], Vector3.UP)
	if _cam_tween != null:
		_cam_tween.kill()
	if not animate or not is_inside_tree():
		camera.transform = to
		camera.fov = spot[2]
		if done.is_valid():
			done.call()
		return
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(camera, "transform", to, 0.7)
	_cam_tween.tween_property(camera, "fov", spot[2], 0.7)
	if done.is_valid():
		_cam_tween.chain().tween_callback(done)


## Turns the character by `amount` (radians), as a drag on it does.
func turn_character(amount: float) -> void:
	character_pivot.rotation.y += amount


func _process(delta: float) -> void:
	_time += delta
	# The fire breathes: its light flickers, its glow swells, its embers pulse.
	var flick := 0.85 + 0.1 * sin(_time * 7.3) + 0.06 * sin(_time * 13.1 + 1.3) + 0.04 * sin(_time * 23.0)
	_fire_light.light_energy = 1.45 * flick
	_fire_glow.scale = Vector3.ONE * (0.95 + 0.08 * flick)
	_embers_mat.emission_energy_multiplier = 0.32 * flick
	# The 渡石's runes breathe, slowly - and blaze as someone crosses.
	_stone_flare = maxf(_stone_flare - delta * 0.6, 0.0)
	# Far off, a faint glow: part of the view, not a beacon.
	_stone_mat.emission_energy_multiplier = 0.16 + 0.08 * sin(_time * 1.3) + 3.0 * _stone_flare
	_stone_light.light_energy = 0.25 + 5.0 * _stone_flare
	# The boat rides the water.
	# The boat, tied up, rocks a little on the water.
	_boat.rotation = Vector3(sin(_time * 0.9) * 0.01, _boat.rotation.y, sin(_time * 0.7 + 1.0) * 0.02)
	_boat.position.y = BOAT_AT.y + sin(_time * 1.1) * 0.01


# ---------------------------------------------------------------- places

## The flat way from `from` to `to`.
static func _toward(from: Vector3, to: Vector3) -> Vector3:
	var d := to - from
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


func _spot(name: String, at: Vector3, face: Vector3) -> void:
	spots[name] = {"at": Vector3(at.x, 0.0, at.z), "face": face}


## Where the character goes and what it walks round (CampLife).
func _places() -> void:
	# A seat: standing just in front of the log, facing the way one sits on
	# it (sat, the hips go back onto it).
	for i in SEATS.size():
		var f := seat_facing(i)
		_spot("seat_%d" % i, SEATS[i][0] + f * 0.33, SEATS[i][0] + f * 3.0)
	_spot("home", CHARACTER_AT, CHARACTER_AT + Vector3(0.35, 0, 1.0))
	_spot("warm", FIRE_AT + Vector3(-0.6, 0, -0.85), FIRE_AT)
	_spot("dance", FIRE_AT + Vector3(0.55, 0, 1.05), Vector3(0.6, 0, 6.0))
	var tent_front := Vector3(sin(0.7), 0, cos(0.7))
	_spot("tent", TENT_AT + tent_front * 1.7, TENT_AT)
	var crate_side := Vector3(cos(0.55), 0, -sin(0.55))
	_spot("crate", CRATE_AT + crate_side * 0.94, CRATE_AT)
	_spot("trough", TROUGH_AT + Vector3(-0.78, 0, 0.1), TROUGH_AT)
	_spot("lean", DRUM_AT + Vector3(0, 0, 0.3), DRUM_AT + Vector3(0, 0, -3.0))
	_spot("lake", Vector3(1.3, 0, -6.35), Vector3(1.7, 0, -10.0))
	_spot("gather_0", Vector3(-2.3, 0, 1.6), Vector3(-2.6, 0, 2.6))
	_spot("gather_1", Vector3(1.9, 0, 1.6), Vector3(2.2, 0, 2.6))
	_spot("gather_2", Vector3(-0.7, 0, 1.95), Vector3(-0.9, 0, 3.0))
	# Where the reaching hand (CharacterRig.REACH) gets to the lamp's bail.
	var ahead := Vector3(0.6, 0, -0.8)
	var left := Vector3(ahead.z, 0, -ahead.x)
	var lamp_at := DRUM_AT + LAMP_ON_DRUM
	var stand := lamp_at - ahead * CharacterRig.REACH.z - left * CharacterRig.REACH.x
	_spot("lamp", stand, stand + ahead * 2.0)
	_spot("rod", ROD_AT + Vector3(0.45, 0, 0.35), ROD_AT + Vector3(0, 0, 0))
	_spot("stone", STONE_AT + Vector3(0, 0, 0.95), STONE_AT)
	_spot("stone_in", STONE_AT + Vector3(0, 0, 0.12), STONE_AT + Vector3(0, 0, -2.0))
	_spot("wake", FIRE_AT + Vector3(-0.95, 0, 0.55), FIRE_AT)
	# What it walks round: everything on the ground, as capsules [a, b,
	# radius] (a circle when a == b) - user request: never through things.
	var crate_dir := Vector3(cos(0.55), 0, -sin(0.55))
	var crate_half := 0.575 * CRATE_LENGTH - 0.3
	var t := Transform3D(Basis(Vector3.UP, HUT_YAW).scaled(Vector3.ONE * HUT_SCALE), HUT_AT)
	obstacles = [
		_round(FIRE_AT, 0.62), [CRATE_AT - crate_dir * crate_half, CRATE_AT + crate_dir * crate_half, 0.32],
		_round(BACKPACK_AT, 0.26), _round(DRUM_AT, 0.36), _round(DRUM_2_AT, 0.36),
		[TROUGH_AT - Vector3(0, 0, 0.2), TROUGH_AT + Vector3(0, 0, 0.2), 0.4],
		[WOODPILE_AT + Vector3(-0.55, 0, 0.1), WOODPILE_AT + Vector3(0.55, 0, 0.1), 0.35],
		_round(ROD_AT, 0.15), _round(TENT_AT, 1.45),
		[STONE_AT - Vector3(0.9, 0, 0), STONE_AT + Vector3(0.9, 0, 0), 0.25],
		[t * Vector3(-0.9, 0, 0), t * Vector3(0.9, 0, 0), 0.9],
	]
	for i in SEATS.size():
		var f := seat_facing(i)
		var along := Vector3(-f.z, 0, f.x)
		var at: Vector3 = SEATS[i][0]
		obstacles.append([at - along * 0.62, at + along * 0.62, 0.34])
	_build_grid()


static func _round(at: Vector3, r: float) -> Array:
	return [at, at, r]


## The way one sits on seat `i` (flat, unit).
func seat_facing(i: int) -> Vector3:
	var face: Variant = SEATS[i][1]
	return face if face != null else _toward(SEATS[i][0], FIRE_AT)


# ---------------------------------------------------------------- the ways

## The ground the character walks on, in cells (GRID_CELL m), solid where
## something stands (its body's width round it) or the lake is.
const GRID_AREA := Rect2(-9.0, -10.0, 19.0, 15.0)
const GRID_CELL := 0.2
const BODY := 0.18
var _grid: AStarGrid2D


func _build_grid() -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, ceili(GRID_AREA.size.x / GRID_CELL), ceili(GRID_AREA.size.y / GRID_CELL))
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			var p := _cell_point(Vector2i(x, y))
			if _in_lake(p, 0.3) or blocked(p, BODY):
				_grid.set_point_solid(Vector2i(x, y), true)


func _cell_of(p: Vector3) -> Vector2i:
	var c := Vector2i(floori((p.x - GRID_AREA.position.x) / GRID_CELL), floori((p.z - GRID_AREA.position.y) / GRID_CELL))
	return c.clamp(Vector2i.ZERO, _grid.region.size - Vector2i.ONE)


func _cell_point(c: Vector2i) -> Vector3:
	return Vector3(GRID_AREA.position.x + (c.x + 0.5) * GRID_CELL, 0.0, GRID_AREA.position.y + (c.y + 0.5) * GRID_CELL)


## Whether something stands within `pad` of `p` (the ground).
func blocked(p: Vector3, pad := 0.0) -> bool:
	for o in obstacles:
		if _to_segment(p, o[0], o[1]) < float(o[2]) + pad:
			return true
	return false


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return (ap - ab * t).length()


## The nearest open cell to `c` (itself if open).
func _open_near(c: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(c):
		return c
	for r in range(1, 12):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if _grid.is_in_boundsv(n) and not _grid.is_point_solid(n) and Vector2(dx, dy).length() < best_d:
					best = n
					best_d = Vector2(dx, dy).length()
		if best.x >= 0:
			return best
	return c


## Whether the straight way a -> b is clear. What a or b stands close by
## (a seat by its log, the lamp's spot by its drum) only keeps the way from
## going in any closer than they stand.
func _clear(a: Vector3, b: Vector3) -> bool:
	var n := ceili(Vector2(b.x - a.x, b.z - a.z).length() / (GRID_CELL * 0.5))
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		if _in_lake(p, 0.3):
			return false
		for o in obstacles:
			var r: float = o[2]
			var limit := r + BODY * 0.9
			var by := minf(_to_segment(a, o[0], o[1]), _to_segment(b, o[0], o[1]))
			if by < r + BODY:
				limit = minf(limit, by - 0.02)
			if _to_segment(p, o[0], o[1]) < limit:
				return false
	return true


## A way from `from` to `to` round everything in the way (a search over the
## ground's cells, then pulled taut): the points to walk through, `to` last.
func route(from: Vector3, to: Vector3) -> Array:
	var a := Vector3(from.x, 0, from.z)
	var b := Vector3(to.x, 0, to.z)
	if _grid == null or _clear(a, b):
		return [b]
	var cells := _grid.get_id_path(_open_near(_cell_of(a)), _open_near(_cell_of(b)), true)
	if cells.is_empty():
		return [b]
	var pts: Array = [a]
	for c in cells:
		pts.append(_cell_point(c))
	pts.append(b)
	# Pulled taut: from each point, on to the farthest one in a clear line.
	var out: Array = []
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## The 渡石 blazes (someone crossing).
func stone_flare() -> void:
	_stone_flare = 1.0


## The lamp taken off the drum (setting out) or put back (home) - eased
## down onto it from `from` (where it hung in the hand), if given.
func lamp_on_drum(on: bool, from: Variant = null) -> void:
	_drum_lamp.visible = on
	if on and from is Transform3D:
		var place := Transform3D(Basis.IDENTITY, DRUM_AT + LAMP_ON_DRUM)
		_drum_lamp.global_transform = from
		create_tween().tween_property(_drum_lamp, "global_transform", place, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Where the lamp stands on the drum (world).
func drum_lamp_place() -> Transform3D:
	return Transform3D(Basis.IDENTITY, DRUM_AT + LAMP_ON_DRUM)


# ---------------------------------------------------------------- hotspots

const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, fog_disabled;
uniform float grow = 0.02;
uniform float strength = 0.12;
uniform vec3 color : source_color = vec3(1.0, 0.78, 0.38);
void vertex() { VERTEX += NORMAL * grow; }
void fragment() { ALBEDO = color * strength * (0.75 + 0.25 * sin(TIME * 2.4)); }
"""
static var _outline_shader: Shader


## Makes `node` (and everything in it) a hotspot for `page`, named `label`,
## its middle `center` (world) and about `radius` metres round.
func _hotspot(page: String, node: Node3D, label: String, center: Vector3, radius: float, grow := 0.02) -> void:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE
	var spot: Dictionary = hotspots.get(page, {"label": label, "parts": [], "overlays": []})
	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_parameter("grow", grow)
	mat.set_shader_parameter("color", OUTLINE_COLOR)
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = mat
	spot.parts.append([node, center, radius])
	spot.overlays.append(mat)
	hotspots[page] = spot


## The page whose thing is under `at` (viewport pixels), nearest first; ""
## if none.
func hotspot_at(at: Vector2) -> String:
	var best := ""
	var best_d := INF
	for page in hotspots:
		for part in hotspots[page].parts:
			var c: Vector3 = part[1]
			if camera.is_position_behind(c):
				continue
			var p := camera.unproject_position(c)
			var edge := camera.unproject_position(c + camera.global_transform.basis.x * float(part[2]))
			var reach := (edge - p).length()
			var d := at.distance_to(p)
			var depth := camera.global_position.distance_to(c)
			if d < reach and depth < best_d:
				best = page
				best_d = depth
	return best


## Lights `page`'s thing up (pressed or hovered); "" for none.
func highlight(page: String) -> void:
	if page == _lit:
		return
	_lit = page
	for p in hotspots:
		for mat in hotspots[p].overlays:
			(mat as ShaderMaterial).set_shader_parameter("strength", 0.7 if p == page else 0.12)


## Where to show `page`'s name (world): over its first part.
func label_point(page: String) -> Vector3:
	var part: Array = hotspots[page].parts[0]
	return part[1] + Vector3(0, float(part[2]) * 0.9 + 0.2, 0)


# ---------------------------------------------------------------- world

func _environment() -> void:
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.012, 0.018, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.09, 0.14);
uniform vec3 moon_dir = vec3(0.25, 0.22, -1.0);
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.45));
	vec3 cell = floor(EYEDIR * 140.0);
	float star = step(0.9975, hash(cell)) * smoothstep(0.02, 0.25, EYEDIR.y);
	col += vec3(0.8, 0.85, 1.0) * star * 0.8;
	float m = max(dot(normalize(EYEDIR), normalize(moon_dir)), 0.0);
	col += vec3(0.85, 0.88, 0.8) * smoothstep(0.9993, 0.9996, m) * 1.4;
	col += vec3(0.25, 0.32, 0.45) * pow(m, 60.0) * 0.5 + vec3(0.1, 0.13, 0.2) * pow(m, 8.0) * 0.35;
	COLOR = col;
}
"""
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky_mat.set_shader_parameter("moon_dir", MOON_DIR)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.13, 0.16, 0.26)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.14)
	env.fog_density = 0.028
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The moon, low over the far shore: a cold light from behind.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.85
	moon.transform = Transform3D.IDENTITY.looking_at(-MOON_DIR, Vector3.UP)
	add_child(moon)


static func _noise_tex(size: int, freq: float, seed_value: int, normal := false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	return t


func _ground() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 fire_at = vec3(0.15, 0.0, -0.1);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.05).r;
	float n2 = texture(noise_tex, wpos.xz * 0.23 + vec2(0.37, 0.11)).r;
	vec3 grass = mix(vec3(0.035, 0.055, 0.035), vec3(0.075, 0.095, 0.05), n);
	vec3 dirt = mix(vec3(0.11, 0.085, 0.06), vec3(0.19, 0.14, 0.09), n2);
	float d = length(wpos.xz - fire_at.xz);
	float trodden = smoothstep(3.4, 1.4, d + (n - 0.5) * 1.6);
	// A worn path to the dock.
	float path = smoothstep(0.75, 0.25, abs(wpos.x - 1.4 - (0.6 - wpos.z) * 0.19 + sin(wpos.z * 0.7) * 0.25)) * step(wpos.z, 0.6) * step(-7.4, wpos.z);
	trodden = max(trodden, path * 0.8);
	ALBEDO = mix(grass, dirt, trodden) * (0.8 + n2 * 0.4);
	ROUGHNESS = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("noise_tex", _noise_tex(256, 0.02, 3))
	mat.set_shader_parameter("fire_at", FIRE_AT)
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)


func _lake() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D wave_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.012, 0.03, 0.05);
uniform vec3 shallow : source_color = vec3(0.04, 0.085, 0.11);
uniform vec3 moon_dir = vec3(0.25, 0.22, -1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.08;
	vec3 a = texture(wave_tex, uv + vec2(TIME * 0.012, TIME * 0.006)).rgb;
	vec3 b = texture(wave_tex, uv * 1.7 - vec2(TIME * 0.009, -TIME * 0.011)).rgb;
	vec3 nm = normalize(mix(a, b, 0.5));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.55;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep, shallow, fres);
	// The moon's path glittering on the ripples.
	vec3 wn = normalize(vec3((nm.x - 0.5) * 0.9, 1.0, (nm.y - 0.5) * 0.9));
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	vec3 r = reflect(-VIEW, vn);
	vec3 m = normalize((VIEW_MATRIX * vec4(normalize(moon_dir), 0.0)).xyz);
	float g = pow(max(dot(r, m), 0.0), 90.0);
	EMISSION = vec3(0.65, 0.72, 0.85) * g * 1.6;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	METALLIC = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("wave_tex", _noise_tex(256, 0.04, 17, true))
	mat.set_shader_parameter("moon_dir", MOON_DIR)
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_RADIUS
	disc.bottom_radius = LAKE_RADIUS
	disc.height = 0.02
	disc.radial_segments = 48
	disc.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = mat
	mi.position = LAKE_CENTER + Vector3(0, 0.02, 0)
	mi.scale = Vector3(1.9, 1.0, 1.0)
	add_child(mi)
	# A dark muddy shore round it.
	var shore := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = LAKE_RADIUS + 0.9
	ring.bottom_radius = LAKE_RADIUS + 0.9
	ring.height = 0.01
	ring.radial_segments = 48
	shore.mesh = ring
	shore.material_override = _mat(Color(0.05, 0.045, 0.035), 1.0)
	shore.position = LAKE_CENTER + Vector3(0, 0.006, 0)
	shore.scale = Vector3(1.9, 1.0, 1.0)
	add_child(shore)


## Where the lake is (its ellipse, a little way in from its shore).
func _in_lake(p: Vector3, margin := 0.0) -> bool:
	var d := Vector2((p.x - LAKE_CENTER.x) / 1.9, p.z - LAKE_CENTER.z)
	return d.length() < LAKE_RADIUS + margin


static func _mat(color: Color, rough := 0.9, emit := Color.BLACK, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
	return m


## A faceted rock (its faces flat-shaded).
static func _rock_mesh(seed_value: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.8
	sphere.radial_segments = 7
	sphere.rings = 4
	var st := SurfaceTool.new()
	st.create_from(sphere, 0)
	st.deindex()
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bumps := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.01)
		if not bumps.has(key):
			bumps[key] = rng.randf_range(0.8, 1.15)
		verts[i] = verts[i] * bumps[key]
		verts[i].y = maxf(verts[i].y, -0.1)
	var out := SurfaceTool.new()
	out.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		out.add_vertex(v)
	out.generate_normals()
	var mesh := out.commit()
	mesh.surface_set_material(0, _mat(Color(0.16, 0.16, 0.17)))
	return mesh


func _rocks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _rock_mesh(5)
	var spots := []
	# Along the near shore, and scattered.
	for i in 26:
		var a := lerpf(0.15, PI - 0.15, float(i) / 25.0)
		var p := LAKE_CENTER + Vector3(-cos(a) * (LAKE_RADIUS + 0.3) * 1.9, 0, sin(a) * (LAKE_RADIUS + 0.3))
		if absf(p.x - DOCK_AT.x) < 1.2:
			continue  # the dock
		spots.append(p + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.2, 0.5)))
	for i in 14:
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.5, 9.0)
		if not _in_lake(p, 1.0) and not (p.z > 2.0 and absf(p.x) < 4.0):
			spots.append(p)
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := _rng.randf_range(0.4, 1.3)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.5, 0.9), s))
		mm.set_instance_transform(i, Transform3D(basis, spots[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


# ---------------------------------------------------------------- the camp

func _put(name: String, at: Vector3, yaw := 0.0, glow := 1.0) -> MeshInstance3D:
	var m := CampModel.make(name, glow)
	if m == null:
		return null
	m.position = at
	m.rotation.y = yaw
	add_child(m)
	return m


## A pine (Quaternius) or a dead tree, as a MultiMesh of `spots`.
func _trees(model: String, spots: Array, scale_range: Vector2) -> void:
	if spots.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = CampModel.tree_mesh(model)
	if mm.mesh == null:
		return
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := _rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.15), s))
		mm.set_instance_transform(i, Transform3D(basis, spots[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _forest() -> void:
	var near := []
	for i in 70:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(8.5, 24.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if _in_lake(p, 1.5):
			continue
		if p.z > 3.0 and absf(p.x) < 7.0:
			continue  # keep the view from the camera clear
		near.append(p)
	# The far shore: a dark line of pines against the sky.
	var far := []
	for i in 56:
		far.append(Vector3(_rng.randf_range(-34.0, 34.0), 0, LAKE_CENTER.z - LAKE_RADIUS - _rng.randf_range(0.5, 7.0)))
	var models := ["pine_a", "pine_b", "pine_c"]
	for k in models.size():
		var mine := []
		for i in near.size():
			if i % models.size() == k:
				mine.append(near[i])
		for i in far.size():
			if i % models.size() == k:
				mine.append(far[i])
		_trees(models[k], mine, Vector2(0.5, 0.95))
	# Dead trees along the water.
	_trees("dead_a", [Vector3(-6.6, 0, -6.9), Vector3(8.4, 0, -6.6), Vector3(-9.5, 0, -8.4)], Vector2(0.45, 0.6))
	_trees("dead_b", [Vector3(-8.2, 0, -3.6), Vector3(9.6, 0, -2.4)], Vector2(0.45, 0.6))


## The campfire (the pack's stones and logs, its embers glowing), the
## flames and smoke from its flame pictures, sparks, the light it throws.
func _fire() -> void:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.position = FIRE_AT
	add_child(fire)
	var pit := CampModel.make("campfire", 0.5)
	pit.scale = Vector3.ONE * 0.85
	fire.add_child(pit)
	_embers_mat = pit.material_override as StandardMaterial3D
	_embers_mat.emission = Color(1.0, 0.55, 0.2)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.particles_anim_h_frames = 2
	flame_mat.particles_anim_v_frames = 2
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.albedo_texture = load(CampModel.DIR + "fire_flames.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.center_offset = Vector3(0, 0.17, 0)
	quad.material = flame_mat
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.mesh = quad
	flames.amount = 7
	flames.lifetime = 0.85
	flames.preprocess = 1.0
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.09
	flames.direction = Vector3.UP
	flames.spread = 8.0
	flames.gravity = Vector3(0, 0.6, 0)
	flames.initial_velocity_min = 0.15
	flames.initial_velocity_max = 0.35
	flames.scale_amount_min = 0.7
	flames.scale_amount_max = 1.15
	flames.anim_offset_max = 1.0
	var fcurve := Curve.new()
	fcurve.add_point(Vector2(0, 0.6))
	fcurve.add_point(Vector2(0.35, 1.0))
	fcurve.add_point(Vector2(1, 0.3))
	flames.scale_amount_curve = fcurve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.7, 0.0))
	ramp.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.78, 0.5, 0.5))
	ramp.add_point(0.6, Color(1.0, 0.58, 0.28, 0.3))
	flames.color_ramp = ramp
	flames.position = Vector3(0, 0.12, 0)
	fire.add_child(flames)
	# Smoke rising slowly into the dark.
	var smoke_mat := flame_mat.duplicate() as StandardMaterial3D
	smoke_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	smoke_mat.albedo_texture = load(CampModel.DIR + "fire_smoke.png")
	var sq := QuadMesh.new()
	sq.size = Vector2(0.9, 0.9)
	sq.material = smoke_mat
	var smoke := CPUParticles3D.new()
	smoke.mesh = sq
	smoke.amount = 6
	smoke.lifetime = 3.5
	smoke.preprocess = 3.5
	smoke.direction = Vector3.UP
	smoke.spread = 10.0
	smoke.gravity = Vector3(0.08, 0.15, 0)
	smoke.initial_velocity_min = 0.25
	smoke.initial_velocity_max = 0.4
	smoke.anim_offset_max = 1.0
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.6
	var sramp := Gradient.new()
	sramp.set_color(0, Color(0.5, 0.45, 0.42, 0.0))
	sramp.set_color(1, Color(0.3, 0.3, 0.32, 0.0))
	sramp.add_point(0.25, Color(0.45, 0.42, 0.4, 0.22))
	smoke.color_ramp = sramp
	smoke.position = Vector3(0, 0.9, 0)
	fire.add_child(smoke)
	# Sparks drifting up.
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_texture = UiKit.glow()
	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(0.05, 0.05)
	ember_quad.material = spark_mat
	var sparks := CPUParticles3D.new()
	sparks.mesh = ember_quad
	sparks.amount = 9
	sparks.lifetime = 2.6
	sparks.preprocess = 2.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.25
	sparks.direction = Vector3.UP
	sparks.spread = 25.0
	sparks.gravity = Vector3(0.15, 0.4, 0)
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	var eramp := Gradient.new()
	eramp.set_color(0, Color(1.0, 0.7, 0.3, 1.0))
	eramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	sparks.color_ramp = eramp
	sparks.position = Vector3(0, 0.4, 0)
	fire.add_child(sparks)
	# A soft glow round it, and the light it throws.
	_fire_glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(2.6, 2.6)
	var gmat := spark_mat.duplicate() as StandardMaterial3D
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gmat.vertex_color_use_as_albedo = false
	gmat.albedo_color = Color(1.0, 0.45, 0.12, 0.07)
	gq.material = gmat
	_fire_glow.mesh = gq
	_fire_glow.position = Vector3(0, 0.45, 0)
	fire.add_child(_fire_glow)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.56, 0.24)
	_fire_light.light_energy = 1.45
	_fire_light.omni_range = 7.0
	_fire_light.omni_attenuation = 1.4
	_fire_light.position = Vector3(0, 0.7, 0)
	fire.add_child(_fire_light)


## Logs to sit on by the fire, and a few stacked by the tent.
func _seats() -> void:
	for i in SEATS.size():
		# Lying across the way one sits on it (its length along its z).
		var f := seat_facing(i)
		_put("log", SEATS[i][0], atan2(-f.z, f.x)).scale = SEAT_SCALE
	# A few logs stacked by the tent.
	for k in 3:
		var l := _put("log", WOODPILE_AT + Vector3(-0.05 + k * 0.05, 0.17 if k == 2 else 0.0, -0.15 + k * 0.24 - (0.12 if k == 2 else 0.0)), 1.5)
		if l != null:
			l.scale = Vector3.ONE * 0.75


## The crate and the backpack leant against it (the warehouse, both).
func _crate() -> void:
	var crate := _put("crate", CRATE_AT, 0.55)
	crate.scale = Vector3(CRATE_LENGTH, 1.0, 1.0)
	_hotspot("warehouse", crate, "倉庫", CRATE_AT + Vector3(0, 0.35, 0), 0.9)
	# The backpack by it opens the warehouse too (user request).
	var pack := _put("backpack", BACKPACK_AT, 0.25)
	pack.rotation.x = -0.18
	_hotspot("warehouse", pack, "倉庫", BACKPACK_AT + Vector3(0, 0.28, 0), 0.38, 0.012)


## The tent (the equipment page): the one Profile.camp_tent names, and the
## rod the player has on leant beside it.
func _tent() -> void:
	_tent_holder = Node3D.new()
	_tent_holder.name = "Tent"
	_tent_holder.position = TENT_AT
	_tent_holder.rotation.y = 0.7
	_tent_holder.scale = Vector3.ONE * 0.85
	add_child(_tent_holder)
	_rod_holder = Node3D.new()
	_rod_holder.name = "Rod"
	_rod_holder.position = ROD_AT
	add_child(_rod_holder)
	_dress_tent()
	_dress_rod()


func _dress_tent() -> void:
	_tent_shown = Profile.camp_tent
	for c in _tent_holder.get_children():
		_tent_holder.remove_child(c)
		c.queue_free()
	var tent := CampModel.make("tent_%d" % clampi(Profile.camp_tent, 1, 9))
	if tent == null:
		tent = CampModel.make("tent_8")
	_tent_holder.add_child(tent)
	hotspots.erase("equipment")
	_hotspot("equipment", _tent_holder, "裝備", TENT_AT + Vector3(0, 1.0, 0), 1.35)
	# The rod belongs with the tent's hotspot too.
	_hotspot("equipment", _rod_holder, "裝備", ROD_AT + Vector3(0, 0.9, 0), 0.4, 0.01)


func _dress_rod() -> void:
	_rod_shown = Profile.rod_tier
	for c in _rod_holder.get_children():
		_rod_holder.remove_child(c)
		c.queue_free()
	var rod: Node3D = CharacterRig.RODS[clampi(Profile.rod_tier, 0, CharacterRig.RODS.size() - 1)].instantiate()
	# The rods are 6 m long up +y, the grip at the origin: leant on the tent.
	rod.scale = Vector3.ONE * 0.3
	rod.rotation = Vector3(-0.22, 0.6, 0.18)
	_rod_holder.add_child(rod)
	if hotspots.has("equipment"):
		for mi in rod.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = hotspots.equipment.overlays[-1]


## The oil drums: one standing, the lamp on it, unlit; one lying cut in
## half, water in it (the fish tank).
func _drums() -> void:
	_put("drum", DRUM_AT, 0.4).scale = Vector3.ONE * DRUM_SCALE
	_put("drum", DRUM_2_AT, 2.3).scale = Vector3.ONE * DRUM_SCALE
	_drum_lamp = CharacterRig.LAMP.instantiate()
	_drum_lamp.name = "DrumLamp"
	_drum_lamp.position = DRUM_AT + LAMP_ON_DRUM
	add_child(_drum_lamp)
	var trough := Node3D.new()
	trough.name = "Trough"
	trough.position = TROUGH_AT
	trough.rotation.y = TROUGH_YAW
	trough.scale = Vector3.ONE * TROUGH_SCALE
	add_child(trough)
	trough.add_child(CampModel.make("drum_trough"))
	# The water: dark, a glint of the moon and the fire on it, rings now and
	# then where a fish turns.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform float fish = 0.0;
varying vec3 lpos;
void vertex() { lpos = VERTEX; }
void fragment() {
	vec2 p = lpos.xz;
	float rip = 0.0;
	for (int i = 0; i < 2; i++) {
		float t = fract(TIME * 0.23 + float(i) * 0.5);
		vec2 c = vec2(sin(float(i) * 4.1 + floor(TIME * 0.23 + float(i) * 0.5) * 2.7) * 0.28, cos(float(i) * 2.3 + floor(TIME * 0.23) * 1.9) * 0.12);
		float r = length(p - c);
		rip += smoothstep(0.012, 0.0, abs(r - t * 0.22)) * (1.0 - t) * fish;
	}
	ALBEDO = vec3(0.02, 0.05, 0.05) + vec3(0.25, 0.3, 0.3) * rip;
	// A faint sheen, so the water reads from across the camp.
	EMISSION = vec3(0.05, 0.09, 0.1) + vec3(0.3, 0.35, 0.35) * rip;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	NORMAL_MAP = normalize(vec3(0.5 + sin(p.x * 40.0 + TIME * 1.3) * 0.03, 0.5 + cos(p.y * 33.0 - TIME) * 0.03, 1.0));
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = sh
	_water_mat.set_shader_parameter("fish", 1.0 if not Profile.tank.is_empty() else 0.0)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = TROUGH_WATER[1]
	water.mesh = pm
	water.material_override = _water_mat
	water.position = Vector3(0, TROUGH_WATER[0], 0)
	trough.add_child(water)
	var leaf := CampModel.make("lotus_leaf")
	if leaf != null:
		var mat := (leaf.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.9, 0.95, 0.85)
		for pad in TROUGH_PADS:
			var mi := leaf.duplicate() as MeshInstance3D
			mi.name = "Pad"
			mi.material_override = mat
			mi.scale = Vector3.ONE * pad[2] * 2.0
			mi.position = Vector3(pad[0], TROUGH_WATER[0] - 0.004, pad[1])
			mi.rotation.y = pad[0] * 9.0
			trough.add_child(mi)
		leaf.free()
	_hotspot("fish_tank", trough, "魚缸", TROUGH_AT + Vector3(0, 0.3, 0), 0.75, 0.012)


## The 渡石: the stone the travellers cross by, its runes glowing faintly.
func _stone() -> void:
	var stone := _put("rune_stone", STONE_AT, 0.0, 1.0)
	stone.name = "Stone"
	stone.scale = Vector3.ONE * STONE_SCALE
	_stone_mat = stone.material_override as StandardMaterial3D
	_stone_mat.albedo_color = Color(0.42, 0.44, 0.46)
	_stone_mat.emission = Color(0.4, 0.8, 1.0)
	_stone_light = OmniLight3D.new()
	_stone_light.light_color = Color(0.45, 0.75, 1.0)
	_stone_light.light_energy = 0.5
	_stone_light.omni_range = 3.4
	_stone_light.position = STONE_AT + Vector3(0, 0.9, 0.45)
	add_child(_stone_light)


## The merchant's stall back by the water (the shop), a lamp at its corner;
## the frog merchant pottering about it; his boat tied up by the dock.
func _stall() -> void:
	var hut := Node3D.new()
	hut.name = "Stall"
	hut.position = HUT_AT
	hut.rotation.y = HUT_YAW
	hut.scale = Vector3.ONE * HUT_SCALE
	add_child(hut)
	var shop := CampModel.make("bookshop", 1.6)
	(shop.material_override as StandardMaterial3D).albedo_color = Color(0.86, 0.84, 0.82)
	hut.add_child(shop)
	var lamp_light := OmniLight3D.new()
	lamp_light.light_color = Color(1.0, 0.7, 0.35)
	lamp_light.light_energy = 1.6
	lamp_light.omni_range = 4.5
	lamp_light.position = Vector3(0.0, 2.2, 1.6)
	hut.add_child(lamp_light)
	_hotspot("shop", hut, "商人", HUT_AT + Vector3(0, 1.2, 0), 1.3)
	# The merchant, pottering about his stall and down to his boat.
	var t := hut.transform
	var camp := Vector3(0.6, 0, 1.0)
	merchant = CampMerchant.new()
	merchant.name = "Merchant"
	for name in MERCHANT_PLACES:
		merchant.places[name] = [t * MERCHANT_PLACES[name], camp]
	merchant.places.inside[1] = t * Vector3(0, 0, 3.0)
	merchant.places.counter[1] = t * MERCHANT_PLACES.inside
	for name in ["side_r", "side_l"]:
		merchant.places[name][1] = t * (MERCHANT_PLACES[name] * 2.0)
	for name in MERCHANT_OUT:
		merchant.places[name] = [MERCHANT_OUT[name], camp]
	merchant.places.dock[1] = BOAT_AT
	merchant.places.dock_base[1] = BOAT_AT
	merchant.links = MERCHANT_LINKS
	# Round the back he only passes by; at the counter he doesn't stand
	# (a visitor does); on the dock he's met at its foot.
	merchant.through = ["back", "back_l", "back_r"]
	merchant.meet_at = {"inside": "counter", "dock": "dock_base"}
	merchant.at = "corner"
	merchant.scale = Vector3.ONE * MERCHANT_SCALE
	add_child(merchant)
	if merchant.body() != null:
		_hotspot("shop", merchant.body(), "商人", HUT_AT + Vector3(0, 1.2, 0), 1.3, 0.012)
	_boat = CampModel.make("boat")
	_boat.position = BOAT_AT
	_boat.rotation.y = PI / 2.0
	_boat.scale = Vector3(BOAT_LENGTH, 1.0, 1.0)
	add_child(_boat)
	_hotspot("shop", _boat, "商人", BOAT_AT + Vector3(0, 1.1, 0), 1.2, 0.015)


## Now and then an animal's dark shape walks the far bank, at the foot of
## the forest across the lake (user request: a rare surprise in the
## distance).
func _wildlife() -> void:
	var w := CampWildlife.new()
	w.name = "Wildlife"
	var pts := PackedVector3Array()
	for i in 15:
		var x := -21.0 + i * 3.0
		var k: float = x / (LAKE_RADIUS * 1.9)
		pts.append(Vector3(x, 0.0, LAKE_CENTER.z - LAKE_RADIUS * sqrt(1.0 - k * k) - 0.6))
	w.path = pts
	add_child(w)


## A dock into the lake, planks on posts.
func _dock() -> void:
	var dock := Node3D.new()
	dock.position = DOCK_AT
	add_child(dock)
	var wood := _mat(Color(0.17, 0.12, 0.08))
	for i in 14:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.15, 0.05, 0.28)
		plank.mesh = pm
		plank.material_override = wood
		plank.position = Vector3(_rng.randf_range(-0.03, 0.03), 0.2, -i * 0.32)
		plank.rotation.y = _rng.randf_range(-0.03, 0.03)
		dock.add_child(plank)
	for i in 3:
		for x in [-0.55, 0.55]:
			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.06
			cm.height = 0.8
			cm.radial_segments = 6
			post.mesh = cm
			post.material_override = wood
			post.position = Vector3(x, 0.05, -i * 1.6)
			dock.add_child(post)


## The character by the fire, resting: its hands empty (the lamp is on the
## drum, the rod by the tent).
func _character() -> void:
	character_pivot = Node3D.new()
	character_pivot.position = CHARACTER_AT
	character_pivot.rotation.y = 0.35
	add_child(character_pivot)
	character = CharacterRig.new()
	character.hold_gear = false
	character_pivot.add_child(character)
	life = CampLife.new()
	life.name = "Life"
	life.stage = self
	add_child(life)
	var blob := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_texture = UiKit.glow()
	bm.albedo_color = Color(0, 0, 0, 0.6)
	blob.material_override = bm
	blob.position = Vector3(0, 0.01, 0)
	character_pivot.add_child(blob)
