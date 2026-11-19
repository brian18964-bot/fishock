class_name Flock
extends Node3D

## User request: small birds that really fly - up out of the trees in a flock when the dragon comes,
## out of a tree when it's chopped, out of a bush as someone goes by. Made ours from the user's bird
## figures (tools/make_desert_animals.py songbird: the dove in flight, rigged, beating its wings) and
## coloured for each map (TINT, SPAN): brown songbirds in the forest, pale snow birds, black crows
## in the autumn wood, sandy birds at the oasis.
##
## Who has birds in it: about PERCH_TREES of the trees and PERCH_BUSHES of the bushes (each its own,
## the same every look), a handful each; flown off, a perch fills again after REFILL s. A bird flies
## up and away from what startled it - climbing steep at first, flapping hard, then off level and
## fast, now and then a short glide - and is gone past GONE_DIST m or LIFE s. POOL of them, made
## once (no stall the moment they fly), fewer on a phone.

const MODEL := "res://assets/models/run3d/songbird.glb"
## Per map style (RunView3D's): their colour (the model's pale picture multiplied) and wingspan (m).
const TINT := {"": Color(0.8, 0.68, 0.52), "snow": Color(0.9, 0.92, 0.96), "autumn": Color(0.13, 0.12, 0.13),
	"desert": Color(0.94, 0.82, 0.62)}
## (a little bigger than life - seen from the game's camera at night, a sparrow's own size is a speck)
const SPAN := {"": 0.44, "snow": 0.42, "autumn": 0.75, "desert": 0.42}
## How fast the wings beat (the clip's rate) - the crows' slower.
const BEAT := {"": 2.6, "snow": 2.6, "autumn": 1.5, "desert": 2.6}
const POOL := 30
const POOL_LOW := 12
const PERCH_TREES := 0.5
const PERCH_BUSHES := 0.55
const REFILL := 120.0
const LIFE := 9.0
const GONE_DIST := 48.0
## Flying: off at SPEED_START m/s, up to CRUISE; climbing till CLIMB_TO m over the ground (each its
## own, within it).
const SPEED_START := 4.5
const CRUISE := 9.0
const CLIMB_TO := Vector2(9.0, 16.0)
## Going past a bush within this (px) startles what's in it.
const BUSH_NEAR := 48.0

var view: RunView3D
var style := ""
var _idle: Array = []
var _live: Array = []
var _emptied := {}
var _time := 0.0
var _bush_check := 0.0
var _bushes: Array = []
var _rng := RandomNumberGenerator.new()


func setup(v: RunView3D, map_style: String) -> void:
	view = v
	style = map_style
	_rng.seed = 29
	if not ResourceLoader.exists(MODEL):
		return
	var scene := load(MODEL) as PackedScene
	var tint: Color = TINT.get(style, TINT[""])
	var mat: StandardMaterial3D = null
	for i in (POOL_LOW if RunView3D.low_end() else POOL):
		var holder := Node3D.new()
		holder.name = "Bird%d" % i
		add_child(holder)
		var model := scene.instantiate() as Node3D
		holder.add_child(model)
		var box := view._aabb(model)
		var k := float(SPAN.get(style, SPAN[""])) / maxf(box.size.x, 0.001)
		model.scale = Vector3.ONE * k
		model.position = -box.get_center() * k
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if mat == null and m.mesh != null and m.mesh.get_surface_count() > 0:
				var src := m.mesh.surface_get_material(0) as StandardMaterial3D
				if src != null:
					mat = src.duplicate() as StandardMaterial3D
					mat.albedo_color = tint
			if mat != null:
				m.material_override = mat
			# (the crows big enough to throw a shadow worth drawing; not on a phone)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if style == "autumn" and not RunView3D.low_end() \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var anim: AnimationPlayer = null
		var aps := model.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			anim = aps[0]
			for a in anim.get_animation_list():
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		holder.visible = false
		holder.process_mode = Node.PROCESS_MODE_DISABLED
		_idle.append({"node": holder, "anim": anim})
	GameState.dragon_came.connect(dragon_came)


## Whether a perch (a tree's or a bush's node) has birds in it now.
func has_birds(perch: Node2D, share: float) -> bool:
	if not is_instance_valid(perch):
		return false
	if float(_emptied.get(perch.get_instance_id(), -1e9)) + REFILL > _time:
		return false
	var p := perch.global_position
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0) < share


## Birds up out of a perch at 3D `at`, away from 2D `from`: `count` of them (as many as are free).
func fly(at: Vector3, from: Vector2, count: int) -> int:
	var f3 := RunView3D.to3(from, 0.0)
	return fly_toward(at, Vector2(at.x - f3.x, at.z - f3.z), count, CLIMB_TO)


## Birds up out of a perch at 3D `at`, off along `way` (x, z; spread about it), climbing to within
## `climb` m over the ground.
func fly_toward(at: Vector3, way: Vector2, count: int, climb: Vector2, low_for := 0.0) -> int:
	var away := way
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	away = away.normalized()
	var n := 0
	for i in count:
		if _idle.is_empty():
			break
		var b: Dictionary = _idle.pop_back()
		var dir := away.rotated(_rng.randf_range(-0.6, 0.6))
		var holder: Node3D = b.node
		holder.position = at + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.3, 0.4), _rng.randf_range(-0.6, 0.6))
		holder.process_mode = Node.PROCESS_MODE_INHERIT
		b.vel = Vector3(dir.x * SPEED_START, _rng.randf_range(2.5, 4.5) * (0.4 if low_for > 0.0 else 1.0), dir.y * SPEED_START)
		b.t = -_rng.randf_range(0.0, 0.35)
		b.top = _rng.randf_range(climb.x, climb.y)
		# (low first, for `low_for` s - under the game's camera, which looks down from not far over
		# the traveller - then up and away)
		b.rise_at = low_for * _rng.randf_range(0.8, 1.2) if low_for > 0.0 else -1.0
		b.glide = 0.0
		b.next_glide = _rng.randf_range(1.2, 2.4)
		b.phase = _rng.randf() * TAU
		holder.visible = false
		if b.anim != null:
			(b.anim as AnimationPlayer).play("Flap")
			(b.anim as AnimationPlayer).speed_scale = float(BEAT.get(style, 2.6)) * _rng.randf_range(0.9, 1.15)
			(b.anim as AnimationPlayer).seek(_rng.randf() * 0.3, true)
		_live.append(b)
		n += 1
	if n > 0:
		Sfx.play_at("flutter", RunView3D.to2(at), -4.0 if n < 4 else 0.0, 0.12)
	return n


## A tree chopped (MapTree's chopped_by): what's in it flies, away from the blow.
func chopped(from: Vector2, mi: MeshInstance3D, tree: Node2D) -> void:
	if not has_birds(tree, PERCH_TREES) or not is_instance_valid(mi):
		return
	_emptied[tree.get_instance_id()] = _time
	var f3 := RunView3D.to3(from, 0.0)
	var at := _crown(mi, 0.35, 0.55)
	fly_toward(at, Vector2(at.x - f3.x, at.z - f3.z), _rng.randi_range(3, 6), LOW_CLIMB, 1.2)


## The dragon comes (GameState.dragon_came): flocks up out of the trees and across what the
## traveller sees - from the trees in sight and from just past each side of the picture, low across
## it (under the game's camera, which looks down from not far over the traveller), then up and away.
## (a startled bird's first height, m over the ground; the dragon's flocks skimming lower still,
## through what the camera sees - it shows little more than a man's height over the ground)
const LOW_CLIMB := Vector2(2.5, 4.0)
const SKIM := Vector2(1.6, 2.6)


func dragon_came() -> void:
	if view == null or not is_instance_valid(view) or view.player == null or view.camera == null:
		return
	var me: Vector2 = view.player.global_position
	var cam := view.camera
	var right := cam.global_basis.x
	var side := Vector2(right.x, right.z).normalized()
	var ahead := -side.orthogonal() if side.orthogonal().dot(Vector2(-cam.global_basis.z.x, -cam.global_basis.z.z)) < 0.0 else side.orthogonal()
	var made := 0
	# (the trees in sight: their birds off sideways across the picture)
	for pair in view._trees:
		if made >= 4:
			break
		var tree: Node2D = pair[0]
		if not is_instance_valid(tree) or not is_instance_valid(pair[1]):
			continue
		var crown := _crown(pair[1], 0.35, 0.55)
		if not cam.is_position_in_frustum(crown):
			continue
		_emptied[tree.get_instance_id()] = _time
		var way := side * (1.0 if _rng.randf() < 0.5 else -1.0)
		_later(_rng.randf_range(0.0, 0.8), crown, way, _rng.randi_range(3, 5), SKIM)
		made += 1
	# (and from just past each side of the picture, crossing it the other way)
	var m3 := RunView3D.to3(me, view.land_y(me))
	for k in [-1.0, 1.0]:
		var off: Vector2 = side * k * 13.0 + ahead * _rng.randf_range(-3.5, 1.0)
		var at := m3 + Vector3(off.x, 2.0, off.y)
		_later(_rng.randf_range(0.0, 1.0), at, -side * k + ahead * _rng.randf_range(-0.15, 0.15), _rng.randi_range(5, 7), SKIM)


func _later(wait: float, at: Vector3, way: Vector2, count: int, climb: Vector2) -> void:
	get_tree().create_timer(wait).timeout.connect(func():
		if is_inside_tree():
			fly_toward(at, way, count, climb, 2.6))


func _crown(mi: MeshInstance3D, lo := 0.55, hi := 0.85) -> Vector3:
	var top := 4.0
	if mi.mesh != null:
		top = mi.mesh.get_aabb().end.y * mi.scale.y
	return mi.global_position + Vector3(0.0, top * _rng.randf_range(lo, hi), 0.0)


func _process(delta: float) -> void:
	_time += delta
	_check_bushes(delta)
	if _live.is_empty():
		return
	var cam := view.pivot.global_position if view != null and view.pivot != null else Vector3.ZERO
	var done := []
	for b in _live:
		b.t = float(b.t) + delta
		var holder: Node3D = b.node
		if float(b.t) < 0.0:
			continue
		holder.visible = true
		var v: Vector3 = b.vel
		var pos := holder.position
		var over := pos.y - view.ground_y(RunView3D.to2(pos))
		if float(b.rise_at) >= 0.0 and float(b.t) > float(b.rise_at):
			b.rise_at = -1.0
			b.top = _rng.randf_range(CLIMB_TO.x, CLIMB_TO.y)
		# (steep up at first, then level off at its height - or down to it)
		var climb := 3.2 if over < float(b.top) else (0.15 if over < float(b.top) + 1.0 else -2.2)
		v.y = lerpf(v.y, climb, 1.0 - exp(-delta * 1.6))
		var flat := Vector2(v.x, v.z)
		var speed := move_toward(flat.length(), CRUISE, delta * 3.5)
		flat = flat.normalized().rotated(sin(float(b.t) * 2.3 + float(b.phase)) * 0.35 * delta) * speed
		v = Vector3(flat.x, v.y, flat.y)
		b.vel = v
		holder.position = pos + v * delta
		var ahead := v.normalized()
		if absf(ahead.dot(Vector3.UP)) < 0.98:
			holder.basis = Basis.looking_at(-ahead, Vector3.UP)
		# (small birds: a short glide on folded-out wings now and then once they're up - the crows
		# glide longer)
		var anim: AnimationPlayer = b.anim
		if anim != null and over > float(b.top) * 0.7:
			b.next_glide = float(b.next_glide) - delta
			if float(b.glide) > 0.0:
				b.glide = float(b.glide) - delta
				if float(b.glide) <= 0.0:
					anim.play("Flap", 0.1)
			elif float(b.next_glide) <= 0.0:
				b.glide = _rng.randf_range(0.25, 0.5) * (2.0 if style == "autumn" else 1.0)
				b.next_glide = _rng.randf_range(1.0, 2.2)
				anim.play("Soar", 0.1)
		if float(b.t) > LIFE or holder.position.distance_to(cam) > GONE_DIST:
			done.append(b)
	for b in done:
		_live.erase(b)
		(b.node as Node3D).visible = false
		(b.node as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
		_idle.append(b)


## Going past a bush with birds in it: up they go, away from the one going by.
func _check_bushes(delta: float) -> void:
	_bush_check -= delta
	if _bush_check > 0.0 or view == null or view.player == null:
		return
	_bush_check = 0.2
	if _bushes.is_empty():
		for n in view.main.get_children():
			if RunView3D._script_name(n) == "bush.gd":
				_bushes.append(n)
	var me: Vector2 = view.player.global_position
	if (view.player as CharacterBody2D).velocity.length() < 20.0:
		return
	for bush in _bushes:
		if not is_instance_valid(bush) or (bush as Node2D).global_position.distance_to(me) > BUSH_NEAR + float(bush.get("radius")):
			continue
		if not has_birds(bush, PERCH_BUSHES):
			continue
		_emptied[bush.get_instance_id()] = _time
		var at := RunView3D.to3((bush as Node2D).global_position, view.land_y((bush as Node2D).global_position) + 0.6)
		var m3 := RunView3D.to3(me, 0.0)
		fly_toward(at, Vector2(at.x - m3.x, at.z - m3.z), _rng.randi_range(1, 3), LOW_CLIMB, 1.0)


## (the warm-up behind the loading cover: one shown in front of its camera, so its skin's built)
func warm(at: Vector3) -> void:
	if _idle.is_empty():
		return
	var b: Dictionary = _idle[0]
	var holder: Node3D = b.node
	holder.position = at
	holder.visible = true
	holder.process_mode = Node.PROCESS_MODE_INHERIT


func cool() -> void:
	for b in _idle:
		(b.node as Node3D).visible = false
		(b.node as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
