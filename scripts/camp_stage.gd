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

## User request: the camp's things further apart (15%, then 13% more -
## user report: crowded to walk about in), out from its middle - all but
## the dock and the boat, at the water.
const SPREAD := 1.3
const MID := Vector3(0.3, 0.0, -1.2)
const FLAT := Vector3(SPREAD, 1.0, SPREAD)
const STATIONS := {
	"home": [MID + (Vector3(0.3, 2.3, 6.9) - MID) * FLAT, MID + (Vector3(-0.15, 0.75, -2.2) - MID) * FLAT, 42.0],
	"warehouse": [MID + (Vector3(-1.6, 1.5, 2.9) - MID) * FLAT, MID + (Vector3(-3.05, 0.45, 0.35) - MID) * FLAT, 38.0],
	"equipment": [MID + (Vector3(-1.4, 1.7, 1.6) - MID) * FLAT, MID + (Vector3(-3.4, 0.9, -2.6) - MID) * FLAT, 40.0],
	"shop": [MID + (Vector3(3.3, 1.7, -1.3) - MID) * FLAT, MID + (Vector3(5.9, 1.1, -5.7) - MID) * FLAT, 40.0],
	"fish_tank": [MID + (Vector3(2.25, 2.1, 1.6) - MID) * FLAT, MID + (Vector3(3.3, 0.25, 0.3) - MID) * FLAT, 40.0],
	"fish_log": [MID + (Vector3(2.25, 2.1, 1.6) - MID) * FLAT, MID + (Vector3(3.3, 0.25, 0.3) - MID) * FLAT, 40.0],
	"stone": [STONE_AT + Vector3(2.1, 1.55, 3.4), STONE_AT + Vector3(0, 0.8, 0), 40.0],
	"journey": [STONE_AT + Vector3(2.1, 1.55, 3.4), STONE_AT + Vector3(0, 0.8, 0), 40.0],
	# (user request: the fire tapped, in close on it as on the rest - the
	# characters' page over it)
	"character": [FIRE_AT + Vector3(0.9, 1.35, 2.5), FIRE_AT + Vector3(-0.1, 0.35, 0), 40.0],
}
const CHARACTER_AT := MID + (Vector3(-0.2, 0.0, 0.85) - MID) * FLAT
const FIRE_AT := MID + (Vector3(0.75, 0.0, -0.35) - MID) * FLAT
const CRATE_AT := MID + (Vector3(-3.05, 0.0, 0.3) - MID) * FLAT
## The crate drawn out longer than the pack's (user request: 30%, then
## 20% more).
const CRATE_LENGTH := 1.56
const BACKPACK_AT := MID + (Vector3(-2.2, 0.0, 1.05) - MID) * FLAT
const TENT_AT := MID + (Vector3(-5.0, 0.0, -3.9) - MID) * FLAT
## User request: the tent, the crate, the backpack, the fire and the logs
## bigger, in proportion to the character (and the fish trough half as big
## again).
const TENT_SCALE := 1.1
const CRATE_SCALE := 1.25
const PACK_SCALE := 1.4
const FIRE_SCALE := 1.12
## The logs longer (not higher: the clips sit on them at their height).
const SEAT_LONGER := 1.2
## Where it stands to lie down in the tent (m out from its middle, toward
## its mouth).
const TENT_BED := 0.45
const ROD_AT := MID + (Vector3(-2.95, 0.0, -2.55) - MID) * FLAT
const DRUM_AT := MID + (Vector3(0.2, 0.0, -2.05) - MID) * FLAT
## A second drum beside it (no lamp).
const DRUM_2_AT := MID + (Vector3(0.95, 0.0, -2.55) - MID) * FLAT
## The fish trough out on the right, its length toward the camera.
const TROUGH_AT := MID + (Vector3(3.3, 0.0, 0.3) - MID) * FLAT
const TROUGH_YAW := PI / 2.0
## The drums made bigger than life, easier to tap (user request: the drum
## 20%, the fish trough 30%).
const DRUM_SCALE := 1.2
const TROUGH_SCALE := 1.95
## The lamp on the drum's lid.
const LAMP_ON_DRUM := Vector3(0.05, 0.92 * DRUM_SCALE, 0.02)
## The 渡石 (user request: moved from far off by the water to the camp's
## left, past the tent - the view swiped left to it - and tapped, it's
## 出發夜釣: the journey page, the camera drawn in close to it). Turned a
## little toward the camp.
## User request (the walkable camp): further off, out to the left, at the
## forest's edge.
const STONE_AT := Vector3(-10.3, 0.0, -1.6)
const STONE_YAW := 1.0
const STONE_SCALE := 0.92
## (user request: the merchant's stall in the home view - nearer, turned
## to the camp)
const HUT_AT := MID + (Vector3(4.7, 0.0, -4.7) - MID) * FLAT
const HUT_YAW := -0.75
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
	"dock_base": Vector3(2.7, 0.0, -6.6), "dock": Vector3(3.15, 0.225, -8.2), "lookout": MID + (Vector3(2.4, 0.0, -2.9) - MID) * FLAT,
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
const MERCHANT_SCALE := 0.85
const DOCK_AT := Vector3(2.9, 0.0, -7.05)
## The dock's planks: how far out (m), half their width (walked on), how
## high; its lamp post (from DOCK_AT), on the side away from the boat.
const DOCK_LENGTH := 4.4
const DOCK_HALF := 0.3
const DOCK_DECK := 0.225
const DOCK_LAMP := Vector3(-0.52, 0.0, -3.9)
## The boat afloat, tied up against the dock (its right side), its bow
## just short of the beach (user request); the pack's boat drawn in to 60%
## of its length.
## The model stands on its rudder, its keel half a metre up: sunk so the
## hull sits in the water.
const BOAT_AT := Vector3(4.12, -0.7, -9.3)
const BOAT_LENGTH := 0.6
## User request: the boat 20% bigger, its mast 30% shorter (the part over
## the cabin roof - BOAT_MAST_FROM up, at BOAT_MAST_X - drawn down).
const BOAT_SIZE := 1.2
const BOAT_MAST_X := -0.868
const BOAT_MAST_FROM := 1.55
const BOAT_MAST_KEEP := 0.56
const LAKE_CENTER := Vector3(0.0, 0.0, -20.6)
const LAKE_RADIUS := 13.5
const MOON_DIR := Vector3(0.1, 0.17, -1.0)
## The logs to sit on by the fire (thicker than the pack's log, so the
## hips sit on it: its top at about 0.52 m): [where, which way one sits on
## it (null: facing the fire)] - the second lies across behind the fire,
## sat on facing out. And the woodpile by the tent.
const SEATS := [[MID + (Vector3(-0.95, 0.0, -0.7) - MID) * FLAT, null], [MID + (Vector3(2.0, 0.0, -1.6) - MID) * FLAT, Vector3(0, 0, 1)]]
const SEAT_SCALE := Vector3(1.18, 1.18, 1.15)
## How far round a point its log's top is looked for (m; seat_top()).
const SEAT_PROBE := 0.06
const WOODPILE_AT := MID + (Vector3(-2.0, 0.0, -2.6) - MID) * FLAT
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
## The fire flaring as the character changes (1, dying down to 0).
var _fire_flare := 0.0
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
## The trees on the walkable ground (walked round, CampStage obstacles).
var _edge_trees: Array = []
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
	_fit_body()
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

## User request: the main screen swiped left and right (a drag no longer
## spins the character round - that broke whatever it was doing): how far
## the home view's moved sideways (m, + to the right), and how far it goes.
const PAN_RANGE := Vector2(-4.4, 2.6)
## (the walkable camp - Camp3D - moves the camera itself, after the
## character: no home view then, only the glide to a page's spot)
var free_camera := false
var view_pan := 0.0
var _pan_now := 0.0
var _station := "home"


## Moves the home view sideways by `metres` (within PAN_RANGE).
func pan_view(metres: float) -> void:
	view_pan = clampf(view_pan + metres, PAN_RANGE.x, PAN_RANGE.y)


## Where the camera is at `station` (home: moved sideways by `pan`).
func station_transform(station: String, pan := 0.0) -> Transform3D:
	var spot: Array = STATIONS.get(station, STATIONS.home)
	var shift := Vector3.ZERO
	if station == "home":
		var ahead: Vector3 = spot[1] - spot[0]
		shift = Vector3(-ahead.z, 0.0, ahead.x).normalized() * pan
	return Transform3D(Basis.IDENTITY, spot[0] + shift).looking_at(spot[1] + shift, Vector3.UP)


## Glides the camera to a station ("home", "shop", ...); `done` is called
## once it's there.
func go_to(station: String, animate := true, done := Callable()) -> void:
	var spot: Array = STATIONS.get(station, STATIONS.home)
	_station = station
	if free_camera and station == "home":
		if _cam_tween != null:
			_cam_tween.kill()
		if done.is_valid():
			done.call()
		return
	_pan_now = view_pan
	var to := station_transform(station, view_pan)
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


## User request: the fire tapped, another character takes over - in the
## same place, doing what it was (sat, it stays sat), the fire flaring up.
func set_character(id: String) -> void:
	character.set_character(id)
	_lamp_spot()
	_fit_body()
	life.restart()
	_fire_flare = 1.0


func _process(delta: float) -> void:
	_time += delta
	# The home view following a swipe (eased).
	if _station == "home" and not free_camera and (_cam_tween == null or not _cam_tween.is_running()) and absf(_pan_now - view_pan) > 0.0005:
		_pan_now = lerpf(_pan_now, view_pan, minf(1.0, delta * 12.0))
		camera.transform = station_transform("home", _pan_now)
	# The fire breathes: its light flickers, its glow swells, its embers pulse.
	var flick := 0.85 + 0.1 * sin(_time * 7.3) + 0.06 * sin(_time * 13.1 + 1.3) + 0.04 * sin(_time * 23.0)
	_fire_flare = maxf(_fire_flare - delta * 1.5, 0.0)
	_fire_light.light_energy = 1.45 * flick + 2.5 * _fire_flare
	_fire_glow.scale = Vector3.ONE * (0.95 + 0.08 * flick + 0.5 * _fire_flare)
	_embers_mat.emission_energy_multiplier = 0.32 * flick
	# The 渡石's runes breathe, slowly - and blaze as someone crosses.
	_stone_flare = maxf(_stone_flare - delta * 0.6, 0.0)
	# Far off, a faint glow: part of the view, not a beacon.
	_stone_mat.emission_energy_multiplier = 0.9 + 0.35 * sin(_time * 1.3) + 3.0 * _stone_flare
	_stone_light.light_energy = 0.35 + 0.1 * sin(_time * 1.3) + 5.0 * _stone_flare
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


## Where the character stands to take the lamp off the drum: where its
## reaching hand (CharacterArt.reach()) gets to the lamp's bail.
func _lamp_spot() -> void:
	var reach := CharacterArt.reach(character.character if character != null else "")
	var ahead := Vector3(0.6, 0, -0.8)
	var left := Vector3(ahead.z, 0, -ahead.x)
	var lamp_at := DRUM_AT + LAMP_ON_DRUM
	var stand := lamp_at - ahead * reach.z - left * reach.x
	_spot("lamp", stand, stand + ahead * 2.0)


## Where the character goes and what it walks round (CampLife).
func _places() -> void:
	# A seat: standing just in front of the log, facing the way one sits on
	# it (sat, the hips go back onto it).
	for i in SEATS.size():
		var f := seat_facing(i)
		_spot("seat_%d" % i, SEATS[i][0] + f * 0.33, SEATS[i][0] + f * 3.0)
	_spot("home", CHARACTER_AT, CHARACTER_AT + Vector3(0.35, 0, 1.0))
	# (a step nearer the camera than it was: a long tail behind it reached
	# the drums)
	_spot("warm", FIRE_AT + Vector3(-0.8, 0, -0.6), FIRE_AT)
	# Stood looking into the fire (user request: much of the time) - from
	# its right side, and from in front of it to the left.
	_spot("fire_0", FIRE_AT + Vector3(0.95, 0, 0.25), FIRE_AT)
	_spot("fire_1", FIRE_AT + Vector3(-0.5, 0, 0.85), FIRE_AT)
	var tent_front := Vector3(sin(0.7), 0, cos(0.7))
	_spot("tent", TENT_AT + tent_front * 2.2, TENT_AT)
	# In under the tent, on its middle line, facing out (lying down, it goes
	# down on its back into the tent): a nap, and waking after a run lost
	# (user request: lying down only in the tent).
	_spot("bed", TENT_AT + tent_front * TENT_BED, TENT_AT + tent_front * 4.0)
	var crate_side := Vector3(cos(0.55), 0, -sin(0.55))
	_spot("crate", CRATE_AT + crate_side * 0.94 * CRATE_SCALE, CRATE_AT)
	_spot("pack", BACKPACK_AT + Vector3(0.15, 0, 0.62), BACKPACK_AT)
	_spot("trough", TROUGH_AT + Vector3(-1.05, 0, 0.1), TROUGH_AT)
	for name in ["crate", "pack", "trough"]:
		_laid_out[name] = spots[name].at
	# (a bigger one's belly and head went into the drum any nearer)
	_spot("lean", DRUM_AT + Vector3(0, 0, 0.38), DRUM_AT + Vector3(0, 0, -3.0))
	_spot("lake", Vector3(1.3, 0, -6.35), Vector3(1.7, 0, -10.0))
	_spot("gather_0", spread(Vector3(-2.3, 0, 1.6)), spread(Vector3(-2.6, 0, 2.6)))
	_spot("gather_1", spread(Vector3(1.9, 0, 1.6)), spread(Vector3(2.2, 0, 2.6)))
	_spot("gather_2", spread(Vector3(-0.7, 0, 1.95)), spread(Vector3(-0.9, 0, 3.0)))
	_lamp_spot()
	_spot("rod", ROD_AT + Vector3(0.45, 0, 0.35), ROD_AT + Vector3(0, 0, 0))
	var stone_front := Vector3(sin(STONE_YAW), 0, cos(STONE_YAW))
	_spot("stone", STONE_AT + stone_front * 0.95, STONE_AT)
	_spot("stone_in", STONE_AT + stone_front * 0.12, STONE_AT - stone_front * 2.0)
	# Sat on the ground by the fire, side on to the camera (by the lake the
	# drums hid it).
	_spot("ground", spread(Vector3(1.75, 0, 0.55)), FIRE_AT)
	# What it walks round: everything on the ground, as capsules [a, b,
	# radius] (a circle when a == b) - user request: never through things.
	var t := Transform3D(Basis(Vector3.UP, HUT_YAW).scaled(Vector3.ONE * HUT_SCALE), HUT_AT)
	obstacles = [
		_round(FIRE_AT, 0.62 * FIRE_SCALE), _round(DRUM_AT, 0.36), _round(DRUM_2_AT, 0.36),
		[WOODPILE_AT + Vector3(-0.55, 0, 0.1), WOODPILE_AT + Vector3(0.55, 0, 0.1), 0.35],
		_round(ROD_AT, 0.15), _round(TENT_AT, 1.45 * TENT_SCALE / 0.85),
		_round(STONE_AT, 0.55),
		# (the stall, its awning's edge too - user report: walked into it)
		[t * Vector3(-1.0, 0, 0), t * Vector3(0.8, 0, 0), 1.1],
	]
	# (the crate, the pack, the trough off their own meshes - user report:
	# the black bear stood in the crate; its capsule had been laid across
	# it, short of its long sides)
	for name in _sided:
		obstacles.append(_capsule(_footprint(_sided[name])))
	for p in _edge_trees:
		obstacles.append(_round(p, 0.42))
	for i in SEATS.size():
		var f := seat_facing(i)
		var along := Vector3(-f.z, 0, f.x)
		var at: Vector3 = SEATS[i][0]
		obstacles.append([at - along * 0.62 * SEAT_LONGER, at + along * 0.62 * SEAT_LONGER, 0.34])


## The things the character goes up to from whichever side it's nearest
## (user request: the fish tank only opened from its left - from its right
## the character walked all the way round first): name -> its footprint
## (_footprint()). Stood off a side by the character's own front
## (CharacterArt.front_between) and STAND_GAP more (user report: the black
## bear stood in the crate and the trough).
var _sided := {}
## The logs to sit on (SEATS).
var _seat_logs: Array = []
var _laid_out := {}
const STAND_GAP := 0.14


## A thing's footprint on the ground off its meshes: [middle, across (flat,
## unit), half across, along, half along].
func _footprint(node: Node3D) -> Array:
	var inv := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		var b: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var t := node.global_transform
	var mid := t * box.get_center()
	var ax := Vector3(t.basis.x.x, 0, t.basis.x.z)
	var az := Vector3(t.basis.z.x, 0, t.basis.z.z)
	return [Vector3(mid.x, 0, mid.z), ax.normalized(), box.size.x * 0.5 * ax.length(),
		az.normalized(), box.size.z * 0.5 * az.length()]


## Where to stand to use `name` coming from `from`: off the side of it the
## shortest walk away (a side with no room left out), `front` (m) its body
## comes forward. Just its spot for a thing not done from any side.
func stand_at(name: String, from: Vector3, front: float) -> Dictionary:
	if not _sided.has(name):
		return spots[name]
	var f := _footprint(_sided[name])
	var best: Dictionary = spots[name]
	var best_len := INF
	for k in 4:
		var axis: Vector3 = f[1] if k < 2 else f[3]
		var half: float = f[2] if k < 2 else f[4]
		var out := axis * (1.0 if k % 2 == 0 else -1.0)
		var at: Vector3 = f[0] + out * (half + front + STAND_GAP)
		if not GRID_AREA.has_point(Vector2(at.x, at.z)) or _in_lake(at, 0.3) or blocked(at, body * 0.75):
			continue
		var length := 0.0
		var last := Vector3(from.x, 0, from.z)
		for q in route(from, at):
			length += last.distance_to(q)
			last = q
		if length < best_len:
			best_len = length
			best = {"at": at, "face": at - out * 3.0}
	return best


## A point of the camp as first laid out, moved out with the rest (SPREAD).
static func spread(p: Vector3) -> Vector3:
	return MID + (p - MID) * FLAT


## A footprint (_footprint()) as a capsule: along its longer way, as wide
## as it is across.
static func _capsule(f: Array) -> Array:
	var along: Vector3 = f[1] if f[2] > f[4] else f[3]
	var r: float = minf(f[2], f[4])
	var reach: float = maxf(f[2], f[4]) - r
	return [f[0] - along * reach, f[0] + along * reach, r]


static func _round(at: Vector3, r: float) -> Array:
	return [at, at, r]


## The seat (index in SEATS) nearest `at`.
func nearest_seat(at: Vector3) -> int:
	var best := 0
	for i in SEATS.size():
		if Vector2(at.x - SEATS[i][0].x, at.z - SEATS[i][0].z).length() < Vector2(at.x - SEATS[best][0].x, at.z - SEATS[best][0].z).length():
			best = i
	return best


## How high seat `i`'s log is at `at` (its top there, m, the stage's own;
## -1 not over it).
func seat_top(i: int, at: Vector3) -> float:
	var log: MeshInstance3D = _seat_logs[i] if i < _seat_logs.size() else null
	if log == null or log.mesh == null:
		return -1.0
	var top := -1.0
	var xf := log.transform
	for s in log.mesh.get_surface_count():
		for v: Vector3 in log.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var w := xf * v
			if Vector2(w.x - at.x, w.z - at.z).length() < SEAT_PROBE:
				top = maxf(top, w.y)
	return top


## The way one sits on seat `i` (flat, unit).
func seat_facing(i: int) -> Vector3:
	var face: Variant = SEATS[i][1]
	return face if face != null else _toward(SEATS[i][0], FIRE_AT)


# ---------------------------------------------------------------- the ways

## The ground the character walks on, in cells (GRID_CELL m), solid where
## something stands (its body's width round it) or the lake is.
const GRID_AREA := Rect2(-11.5, -11.0, 23.0, 17.0)
const GRID_CELL := 0.2
const BODY := 0.18
## The character's own half-width (m) the ways keep clear by - BODY at the
## least (user report: the black bear brushed through what the cat
## passed): its measured side (CharacterArt.side_between), up to BODY_MOST.
const BODY_MOST := 0.34
var body := BODY
var _grid: AStarGrid2D


## The ways laid again for the character now at the camp.
func _fit_body() -> void:
	var id := character.character if character != null else ""
	body = clampf(CharacterArt.side_between(id, 0.3, 1.4, BODY) * 0.85, BODY, BODY_MOST)
	_build_grid()
	# (each one's own spot: the side of it nearest where it was laid out)
	var front := CharacterArt.front_between(id, 0.2, 1.4, 0.25)
	for name in _sided:
		spots[name] = stand_at(name, _laid_out[name], front)


func _build_grid() -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, ceili(GRID_AREA.size.x / GRID_CELL), ceili(GRID_AREA.size.y / GRID_CELL))
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			var p := _cell_point(Vector2i(x, y))
			if _in_lake(p, 0.3) or blocked(p, body):
				_grid.set_point_solid(Vector2i(x, y), true)


func _cell_of(p: Vector3) -> Vector2i:
	var c := Vector2i(floori((p.x - GRID_AREA.position.x) / GRID_CELL), floori((p.z - GRID_AREA.position.y) / GRID_CELL))
	return c.clamp(Vector2i.ZERO, _grid.region.size - Vector2i.ONE)


func _cell_point(c: Vector2i) -> Vector3:
	return Vector3(GRID_AREA.position.x + (c.x + 0.5) * GRID_CELL, 0.0, GRID_AREA.position.y + (c.y + 0.5) * GRID_CELL)


## Ground the character can stand on with `room` (m) round it past
## things' edges: in the camp, not in the lake.
func roomy(p: Vector3, room: float) -> bool:
	return GRID_AREA.has_point(Vector2(p.x, p.z)) and not _in_lake(p, 0.3) and not blocked(p, room)


## How far `p` is from the nearest thing's edge (m; the lake aside).
func clearance(p: Vector3) -> float:
	var near := INF
	for o in obstacles:
		near = minf(near, _to_segment(p, o[0], o[1]) - float(o[2]))
	return near


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
			var limit := r + body * 0.9
			var by := minf(_to_segment(a, o[0], o[1]), _to_segment(b, o[0], o[1]))
			if by < r + body:
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


## Which of its parts the last hotspot_at() found (e.g. which log).
var hit_part := 0


## The page whose thing is under `at` (viewport pixels), nearest first; ""
## if none.
func hotspot_at(at: Vector2) -> String:
	var best := ""
	var best_d := INF
	for page in hotspots:
		var k := -1
		for part in hotspots[page].parts:
			k += 1
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
				hit_part = k
	return best


## Lights `page`'s thing up (pressed or hovered); "" for none.
func highlight(page: String) -> void:
	if page == _lit:
		return
	_lit = page
	for p in hotspots:
		for mat in hotspots[p].overlays:
			(mat as ShaderMaterial).set_shader_parameter("strength", 0.7 if p == page else 0.12)


## User request: a thing's name pops up as the character comes near it:
## [page, part] of the nearest within `reach` (m) of `at`, or [] - and
## where its name goes (world).
func near_spot(at: Vector3, reach: float) -> Array:
	var best: Array = []
	var best_d := reach
	for page in hotspots:
		if page == "character":
			continue
		var parts: Array = hotspots[page].parts
		for k in parts.size():
			var c: Vector3 = parts[k][1]
			var d := Vector2(c.x - at.x, c.z - at.z).length() - float(parts[k][2]) * 0.5
			if d < best_d:
				best_d = d
				best = [page, k, c + Vector3(0, float(parts[k][2]) * 0.9 + 0.2, 0)]
	return best


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
	# (user request: the rocks scattered over the camp's ground stood out -
	# gone; the shore's stay)
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
		# (nor between the walkable camp's following camera and the
		# character, all along its south side)
		if p.z > 0.3 and p.z < 13.0 and absf(p.x) < 13.5:
			continue
		if p.distance_to(STONE_AT) < 2.0 or _by_camp(p):
			continue
		near.append(p)
	# User request (the walkable camp): the edges thick with trees - left
	# and right past the camp's things, round behind the 渡石, and a few
	# along the shore; none where the camera follows from (south).
	for i in 110:
		var p := Vector3(_rng.randf_range(-15.0, 15.0), 0, _rng.randf_range(-10.5, 7.0))
		if absf(p.x) < 9.6 and p.z < 5.6:
			continue
		# (none between the following camera and the character, at the
		# camp's south side)
		if p.z > 0.3 and p.z < 13.0 and absf(p.x) < 13.5:
			continue
		if _in_lake(p, 1.0) or p.distance_to(STONE_AT) < 2.0 or _by_camp(p):
			continue
		near.append(p)
		if GRID_AREA.has_point(Vector2(p.x, p.z)):
			_edge_trees.append(p)
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
	_trees("dead_a", [Vector3(-6.6, 0, -6.9), Vector3(8.4, 0, -6.6), Vector3(-9.5, 0, -8.4)].filter(func(q): return not _by_camp(q)),
		Vector2(0.45, 0.6))
	_trees("dead_b", [Vector3(-8.2, 0, -3.6), Vector3(9.6, 0, -2.4)].filter(func(q): return not _by_camp(q)), Vector2(0.45, 0.6))


## Whether a tree at `p` would stand in the tent or the stall (spread out
## to the forest's edge).
static func _by_camp(p: Vector3) -> bool:
	return p.distance_to(TENT_AT) < 3.4 * TENT_SCALE or p.distance_to(HUT_AT) < 2.8


## The campfire (the pack's stones and logs, its embers glowing), the
## flames and smoke from its flame pictures, sparks, the light it throws.
func _fire() -> void:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.position = FIRE_AT
	add_child(fire)
	var pit := CampModel.make("campfire", 0.5)
	pit.scale = Vector3.ONE * 0.85 * FIRE_SCALE
	fire.add_child(pit)
	# User request: tapping the fire changes who's travelling.
	_hotspot("character", pit, "換角色", FIRE_AT + Vector3(0, 0.3, 0), 0.6)
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
		var seat := _put("log", SEATS[i][0], atan2(-f.z, f.x))
		seat.scale = SEAT_SCALE * Vector3(SEAT_LONGER, 1.0, 1.0)
		_seat_logs.append(seat)
		# User request: a tap on a log, it goes and sits on it.
		_hotspot("sit", seat, "坐下", SEATS[i][0] + Vector3(0, 0.4, 0), 0.7, 0.01)
	# A few logs stacked by the tent.
	for k in 3:
		var l := _put("log", WOODPILE_AT + Vector3(-0.05 + k * 0.05, 0.17 if k == 2 else 0.0, -0.15 + k * 0.24 - (0.12 if k == 2 else 0.0)), 1.5)
		if l != null:
			l.scale = Vector3.ONE * 0.75


## The crate and the backpack leant against it (the warehouse, both).
func _crate() -> void:
	var crate := _put("crate", CRATE_AT, 0.55)
	crate.scale = Vector3(CRATE_LENGTH, 1.0, 1.0) * CRATE_SCALE
	_hotspot("warehouse", crate, "倉庫", CRATE_AT + Vector3(0, 0.4, 0), 0.9 * CRATE_SCALE)
	_sided["crate"] = crate
	# The backpack by it opens the warehouse too (user request).
	var pack := _put("backpack", BACKPACK_AT, 0.25)
	pack.rotation.x = -0.18
	pack.scale = Vector3.ONE * PACK_SCALE
	_hotspot("backpack", pack, "背包", BACKPACK_AT + Vector3(0, 0.35, 0), 0.38 * PACK_SCALE, 0.012)
	_sided["pack"] = pack


## The tent (the equipment page): the one Profile.camp_tent names, and the
## rod the player has on leant beside it.
func _tent() -> void:
	_tent_holder = Node3D.new()
	_tent_holder.name = "Tent"
	_tent_holder.position = TENT_AT
	_tent_holder.rotation.y = 0.7
	_tent_holder.scale = Vector3.ONE * TENT_SCALE
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
	_hotspot("equipment", _tent_holder, "裝備", TENT_AT + Vector3(0, 1.2, 0), 1.35 * TENT_SCALE / 0.85)
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
	_hotspot("fish_tank", trough, "魚缸", TROUGH_AT + Vector3(0, 0.4, 0), 1.1, 0.012)
	_sided["trough"] = trough


## The 渡石: the stone the travellers cross by, its runes glowing faintly
## (tools/build_camp_models.py ferry_stone()).
func _stone() -> void:
	var stone := _put("ferry_stone", STONE_AT, STONE_YAW, 1.0)
	stone.name = "Stone"
	stone.scale = Vector3.ONE * STONE_SCALE
	_stone_mat = stone.material_override as StandardMaterial3D
	_stone_mat.emission = Color(0.4, 0.8, 1.0)
	# (the colour through the runes only - added, it lit the whole stone)
	_stone_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_stone_light = OmniLight3D.new()
	_stone_light.light_color = Color(0.45, 0.75, 1.0)
	_stone_light.light_energy = 0.5
	_stone_light.omni_range = 2.6
	_stone_light.position = STONE_AT + Vector3(sin(STONE_YAW), 0, cos(STONE_YAW)) * 0.8 + Vector3(0, 0.5, 0)
	add_child(_stone_light)
	_hotspot("journey", stone, "渡石", STONE_AT + Vector3(0, 0.8, 0), 0.75)


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
	_boat.mesh = _short_mast(_boat.mesh)
	_boat.position = BOAT_AT
	_boat.rotation.y = PI / 2.0
	_boat.scale = Vector3(BOAT_LENGTH, 1.0, 1.0) * BOAT_SIZE
	add_child(_boat)
	_hotspot("shop", _boat, "商人", BOAT_AT + Vector3(0, 1.1, 0), 1.2, 0.015)


## The boat's mesh with its mast drawn down (BOAT_MAST_KEEP of it left
## over BOAT_MAST_FROM).
static func _short_mast(mesh: Mesh) -> Mesh:
	if mesh == null:
		return mesh
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for k in verts.size():
			var v := verts[k]
			if v.y > BOAT_MAST_FROM and absf(v.x - BOAT_MAST_X) < 0.06:
				verts[k].y = BOAT_MAST_FROM + (v.y - BOAT_MAST_FROM) * BOAT_MAST_KEEP
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays)
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out


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
	# User request: the camp's one lamp post, out on the dock (the fire and
	# the moon light the rest).
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.045
	pc.bottom_radius = 0.06
	pc.height = 1.9
	pc.radial_segments = 6
	pole.mesh = pc
	pole.material_override = wood
	pole.position = Vector3(DOCK_LAMP.x, 0.2 + pc.height * 0.5, DOCK_LAMP.z)
	dock.add_child(pole)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.42, 0.05, 0.05)
	arm.mesh = am
	arm.material_override = wood
	arm.position = Vector3(DOCK_LAMP.x - 0.18, 2.05, DOCK_LAMP.z)
	dock.add_child(arm)
	var lamp: Node3D = load("res://assets/models/oil_lamp.glb").instantiate()
	lamp.scale = Vector3.ONE * 0.8
	lamp.position = Vector3(DOCK_LAMP.x - 0.34, 1.68, DOCK_LAMP.z)
	dock.add_child(lamp)
	var flame := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.04
	fs.height = 0.08
	flame.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.8, 0.45)
	flame.material_override = fm
	flame.position = Vector3(DOCK_LAMP.x - 0.34, 1.8, DOCK_LAMP.z)
	dock.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.35)
	light.light_energy = 1.3
	light.omni_range = 4.0
	light.position = Vector3(DOCK_LAMP.x - 0.34, 1.85, DOCK_LAMP.z)
	dock.add_child(light)


## Whether `p` is on the dock's planks (Camp3D walks out on them).
func on_dock(p: Vector3) -> bool:
	return absf(p.x - DOCK_AT.x) < DOCK_HALF and p.z < DOCK_AT.z + 0.15 and p.z > DOCK_AT.z - DOCK_LENGTH


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
