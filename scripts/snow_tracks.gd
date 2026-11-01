class_name SnowTracks
extends Node3D

## User request (the snowy map): where the traveller walks the snow keeps their footprints - one
## each time a foot of the model actually comes down, where it came down and the way it pointed,
## in the shape of that character's own foot - and after a while they smooth over and the snow is
## as it was.
##
## The shapes are baked from the models (tools/bake_footprints.gd -> assets/sprites/footprints/
## soles.png + soles.json): for each character and foot, the part of the sole that meets the
## ground, in the foot's own frame and in foot lengths. Each frame (feel) the rig's ankle and toe
## tip are read; a foot that was lifted and is now down flat on open ground leaves a print there
## (one MultiMesh of flat quads, shaders/footprint.gdshader, in a ring - the oldest overwritten
## when it's full). How deep: the character's weight, and harder at a run.

const MAX := 256
## Seconds a print stays whole, then how long it takes to fade away.
const HOLD := 14.0
const FADE := 26.0
const LIFT_Y := 0.012
## A step: each heel's height (foot lengths over the ground) is kept for the last HISTORY frames;
## the foot comes down when its heel falls to within DOWN of the way from its lowest to its
## highest there, and is up again past UP. (Each character's own legs, gait and pace: its own
## lowest and highest - nothing set per character.) A foot that swings less than SWING isn't
## stepping (standing, turning on the spot).
const HISTORY := 72
const DOWN := 0.3
const UP := 0.6
const SWING := 0.15
## How heavy each one treads (0..1): a print's depth.
const WEIGHT := {"cat": 0.45, "dog": 0.35, "dog3": 0.6, "bear": 1.0, "bear2": 0.95, "deer": 0.8,
	"deer2": 0.7, "sheep": 0.65, "sheep2": 0.65, "owl": 0.4, "owl2": 0.45, "croc": 0.75}
## The walk and the run (m/s): the print deeper the faster.
const WALK_SPEED := 2.0
const RUN_SPEED := 4.0
const SOLES_JSON := "res://assets/sprites/footprints/soles.json"
const SOLES_PNG := "res://assets/sprites/footprints/soles.png"
## The atlas's rows: the twelve characters', then the animals' (soles.json "rows").
const ROWS := 15
## User request: each one walking keeps only its last PER_WALKER prints - a new one and the oldest
## fades out (over RETIRE s); the slow fade with time stays too.
const PER_WALKER := 8
const RETIRE := 0.6
## The animals that leave prints, by their 3D kind (RunView3D): the baked row ("@hoof"...), the
## print's size (m), the foot bones (the quadrupeds' feet are FF / FFB; the big ghost has the
## characters' skeleton). A floating ghost and the altar's keeper leave none.
const ANIMALS := {
	"deer": {"row": "@hoof", "size": 0.2, "bones": ["FF.L", "FF.R", "FFB.L", "FFB.R"]},
	"stag": {"row": "@hoof", "size": 0.24, "bones": ["FF.L", "FF.R", "FFB.L", "FFB.R"]},
	"fox": {"row": "@paw", "size": 0.13, "bones": ["FF.L", "FF.R", "FFB.L", "FFB.R"]},
	"wolf": {"row": "@paw", "size": 0.19, "bones": ["FF.L", "FF.R", "FFB.L", "FFB.R"]},
	"dragon": {"row": "@claw", "size": 0.55, "bones": ["ball_l", "ball_r"]},
}
## An animal's foot swinging less than this (m) isn't stepping.
const SWING_M := 0.02

static var _soles: Dictionary = {}

var character := ""
var _mm: MultiMesh
var _mat: ShaderMaterial
var _age := PackedFloat32Array()
var _deep := PackedFloat32Array()
var _cell := PackedVector2Array()
## Where each print is and the way its toe points (x, z), kept here too.
var spot := PackedVector3Array()
var toe := PackedVector2Array()
var _next := 0
var _tick := 0.0
## Each foot's state: down (on the ground) or not, and its heel's recent heights.
var _down := {"_l": true, "_r": true}
var _heights := {"_l": PackedFloat32Array(), "_r": PackedFloat32Array()}
var _at := 0
## A foot coming down, its heel still going lower; the heel's height last frame.
var _landing := {"_l": false, "_r": false}
var _last_h := {"_l": 0.0, "_r": 0.0}
## Prints of each foot (for tests: the feet take turns).
var steps := {"_l": 0, "_r": 0}
## Prints made (all time), for tests.
var made := 0
## Whose each print is (a walker's key: "player" or an animal's instance id), and each walker's
## prints, oldest first (PER_WALKER).
var _owner_of := []
var _owned := {}
## The animals' feet: key -> {bone name -> {h: heights, down, landing, last}}.
var _animal_feet := {}


func _ready() -> void:
	name = "SnowTracks"
	top_level = true
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/footprint.gdshader")
	_mat.set_shader_parameter("soles", load(SOLES_PNG))
	_mat.set_shader_parameter("rows", float(ROWS))
	quad.material = _mat
	_mm.mesh = quad
	_mm.instance_count = MAX
	_age.resize(MAX)
	_deep.resize(MAX)
	_cell.resize(MAX)
	spot.resize(MAX)
	toe.resize(MAX)
	_owner_of.resize(MAX)
	for i in MAX:
		_age[i] = -1.0
		_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50.0, 0)))
		_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Prints"
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The baked soles (soles.json), loaded once.
static func soles() -> Dictionary:
	if _soles.is_empty():
		var f := FileAccess.open(SOLES_JSON, FileAccess.READ)
		if f != null:
			var got = JSON.parse_string(f.get_as_text())
			if got is Dictionary:
				_soles = got
	return _soles


## The skeleton `skel` of the one walking; `ground` (Callable: Vector3 -> float) the ground's
## height under a point, `open` (Callable: Vector3 -> bool) whether it's open snow there (not a
## deck, the altar's stone, the water's edge); `speed` how fast it's going (m/s).
func feel(skel: Skeleton3D, ground: Callable, open: Callable, speed: float) -> void:
	var sole: Dictionary = soles().get(character, {})
	if skel == null or sole.is_empty():
		return
	for side in ["_l", "_r"]:
		var foot := skel.find_bone("foot" + side)
		var leaf := skel.find_bone("ball_leaf" + side)
		if foot < 0 or leaf < 0:
			continue
		var g := skel.global_transform
		var ankle: Vector3 = g * skel.get_bone_global_pose(foot).origin
		var toe: Vector3 = g * skel.get_bone_global_pose(leaf).origin
		# (the foot's length, as at rest - the same whatever the pose)
		var rest := skel.get_bone_global_rest(leaf).origin - skel.get_bone_global_rest(foot).origin
		var length := Vector2(rest.x, rest.z).length() * g.basis.get_scale().x
		if length <= 0.001:
			continue
		var floor_y: float = ground.call(ankle)
		var h := (ankle.y - floor_y) / length
		var hist: PackedFloat32Array = _heights[side]
		if hist.size() < HISTORY:
			hist.append(h)
		else:
			hist[_at % HISTORY] = h
		_heights[side] = hist
		var lo := h
		var hi := h
		for v in hist:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var swing := hi - lo
		if swing < SWING:
			_down[side] = true
			continue
		var was: float = _last_h[side]
		_last_h[side] = h
		if _down[side]:
			if h > lo + UP * swing:
				_down[side] = false
				_landing[side] = false
			elif _landing[side] and h >= was:
				# (the heel's lowest: the foot's down - its print where it is now)
				_landing[side] = false
				if open.call(ankle):
					var along := Vector2(toe.x - ankle.x, toe.z - ankle.z)
					if along.length() > 0.0001:
						_print_foot(sole, side, Vector3(ankle.x, floor_y + LIFT_Y, ankle.z), along.normalized(), length, speed)
		elif h < lo + DOWN * swing:
			_down[side] = true
			_landing[side] = true
	_at += 1


## A print of foot `side` (its ankle at `at`, pointing `fwd` - x, z) `length` long.
func _print_foot(sole: Dictionary, side: String, at: Vector3, fwd: Vector2, length: float, speed: float) -> void:
	var box: Array = sole.get(side.substr(1), [])
	if box.size() < 4:
		return
	var f0 := float(box[0]) * length
	var f1 := float(box[1]) * length
	var s0 := float(box[2]) * length
	var s1 := float(box[3]) * length
	var fwd3 := Vector3(fwd.x, 0.0, fwd.y)
	var right3 := Vector3(-fwd.y, 0.0, fwd.x)
	var centre := at + fwd3 * ((f0 + f1) * 0.5) + right3 * ((s0 + s1) * 0.5)
	# (the quad's -z along the foot, its +x to the foot's right; stretched to the sole's box)
	var basis := Basis(right3, Vector3.UP, -fwd3).scaled_local(Vector3(s1 - s0, 1.0, f1 - f0))
	var weight := float(WEIGHT.get(character, 0.6))
	var pace := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	var deep := clampf(0.4 + 0.45 * weight + 0.2 * pace, 0.0, 1.0)
	var i := _next
	_next = (_next + 1) % MAX
	_age[i] = 0.0
	_deep[i] = deep
	_cell[i] = Vector2(0.0 if side == "_l" else 1.0, float(sole.row))
	spot[i] = at
	toe[i] = fwd
	_mm.set_instance_transform(i, Transform3D(basis, centre))
	_mm.set_instance_custom_data(i, Color(1.0, _cell[i].x, _cell[i].y, deep))
	_claim(i, "player")
	made += 1
	steps[side] += 1


## Print `i` is `key`'s now: the walker's oldest past PER_WALKER fades out.
func _claim(i: int, key) -> void:
	var was = _owner_of[i]
	if was != null and _owned.has(was):
		(_owned[was] as Array).erase(i)
	_owner_of[i] = key
	if not _owned.has(key):
		_owned[key] = []
	var mine: Array = _owned[key]
	mine.append(i)
	while mine.size() > PER_WALKER:
		var old: int = mine.pop_front()
		_owner_of[old] = null
		if _age[old] >= 0.0:
			_age[old] = maxf(_age[old], HOLD + FADE - RETIRE)
			_tick = 1.0


## How many prints `key` has showing.
func count_of(key) -> int:
	var n := 0
	for i in _owned.get(key, []):
		if left_of(_age[i]) > 0.0:
			n += 1
	return n


## An animal (or the big ghost) walking: `key` its id, `kind` its ANIMALS entry, `skel` its
## skeleton, `yaw` the way it faces; `ground` and `open` as for feel(). A print where a foot
## comes down - each foot's lowest, judged by its own swing - pointing the way it faces.
func feel_animal(key: int, kind: String, skel: Skeleton3D, yaw: float, ground: Callable, open: Callable) -> void:
	var spec: Dictionary = ANIMALS.get(kind, {})
	var row: Dictionary = soles().get(spec.get("row", ""), {})
	if skel == null or spec.is_empty() or row.is_empty():
		return
	if not _animal_feet.has(key):
		_animal_feet[key] = {}
	var feet: Dictionary = _animal_feet[key]
	var g := skel.global_transform
	var fwd := Vector2(sin(yaw), cos(yaw))
	var k := 0
	for name in spec.bones:
		var b := skel.find_bone(name)
		k += 1
		if b < 0:
			continue
		var at: Vector3 = g * skel.get_bone_global_pose(b).origin
		var floor_y: float = ground.call(at)
		var h := at.y - floor_y
		if not feet.has(name):
			feet[name] = {"h": PackedFloat32Array(), "at": 0, "down": true, "landing": false, "last": h}
		var f: Dictionary = feet[name]
		var hist: PackedFloat32Array = f.h
		if hist.size() < HISTORY:
			hist.append(h)
		else:
			hist[int(f.at) % HISTORY] = h
		f.h = hist
		f.at = int(f.at) + 1
		var lo := h
		var hi := h
		for v in hist:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var swing := hi - lo
		var was: float = f.last
		f.last = h
		if swing < SWING_M:
			f.down = true
			continue
		if f.down:
			if h > lo + UP * swing:
				f.down = false
				f.landing = false
			elif f.landing and h >= was:
				f.landing = false
				if open.call(at):
					_print_animal(key, Vector3(at.x, floor_y + LIFT_Y, at.z), fwd, float(spec.size), int(row.row), k % 2)
		elif h < lo + DOWN * swing:
			f.down = true
			f.landing = true


func _print_animal(key: int, at: Vector3, fwd: Vector2, size: float, row: int, col: int) -> void:
	var fwd3 := Vector3(fwd.x, 0.0, fwd.y)
	var right3 := Vector3(-fwd.y, 0.0, fwd.x)
	var basis := Basis(right3, Vector3.UP, -fwd3).scaled_local(Vector3(size, 1.0, size))
	var i := _next
	_next = (_next + 1) % MAX
	_age[i] = 0.0
	_deep[i] = 0.6
	_cell[i] = Vector2(float(col), float(row))
	spot[i] = at
	toe[i] = fwd
	_mm.set_instance_transform(i, Transform3D(basis, at))
	_mm.set_instance_custom_data(i, Color(1.0, _cell[i].x, _cell[i].y, _deep[i]))
	_claim(i, key)


## An animal gone (caught, faded away, freed): its feet forgotten (its prints stay to fade).
func forget(key: int) -> void:
	_animal_feet.erase(key)


## How much of a print `age` s old is left (1 whole .. 0 gone).
static func left_of(age: float) -> float:
	if age < 0.0:
		return 0.0
	return clampf(1.0 - (age - HOLD) / FADE, 0.0, 1.0)


## How many prints are showing.
func count() -> int:
	var n := 0
	for a in _age:
		if left_of(a) > 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	for i in MAX:
		if _age[i] >= 0.0:
			_age[i] += delta
	_tick += delta
	if _tick < 0.25 and delta < 1.0:
		return
	_tick = 0.0
	for i in MAX:
		if _age[i] < 0.0:
			continue
		var k := left_of(_age[i])
		if k <= 0.0:
			_age[i] = -1.0
			_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -50.0, 0)))
			var who = _owner_of[i]
			if who != null and _owned.has(who):
				(_owned[who] as Array).erase(i)
			_owner_of[i] = null
		_mm.set_instance_custom_data(i, Color(k, _cell[i].x, _cell[i].y, _deep[i]))
