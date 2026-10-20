class_name CharacterRig
extends Node3D

## The player's character in 3D - in the main screen's camp and on the
## equipment page (CharacterViewer): the one travelling (Profile.character;
## its model CharacterArt.model() - a greybox animal person in its trial
## colours on Quaternius' Universal Animation Library skeleton (CC0;
## tools/build_menu_character.py)), with its clips - breathing, waving when tapped, and dressed as a paper
## doll: equip(slot, scene) hangs a model on a bone (SLOTS) - the rod bought
## in the right hand, the oil lamp in the left; hats, packs and the rest
## later.

const RODS := [
	preload("res://assets/models/fishing_rod_lvl1.glb"), preload("res://assets/models/fishing_rod_lvl2.glb"),
	preload("res://assets/models/fishing_rod_lvl3.glb"), preload("res://assets/models/fishing_rod_lvl4.glb"),
	preload("res://assets/models/fishing_rod_lvl5.glb"),
]
## Slot -> the bone it hangs from.
const SLOTS := {"hand_r": "hand_r", "hand_l": "hand_l", "head": "Head", "back": "spine_03"}
## The player's colour in the game (the sprite's cyan-blue).
const SKIN := Color(0.38, 0.72, 0.84)
const JOINTS := Color(0.2, 0.36, 0.45)
## The rod bought (Profile.rod_tier) in the right hand, held up and out.
## The rods' models are 6 m long along +Y, the grip at the origin.
const ROD_AIM := Vector3(-0.42, 1.0, 0.15)
const ROD_SCALE := 0.24
const ROD_GRIP := Vector3.ZERO
## The oil lamp (0.3 m, base at the origin) hangs from the left hand.
const LAMP := preload("res://assets/models/oil_lamp.glb")
## The left hand reaching out and up (Interact, this far through): where
## the fingers get to - each character's own, CharacterArt.reach() - is
## where a lamp to be picked up should hang.
const REACH_CLIP := "Interact"
const REACH_AT := 0.32
## Where the lamp is held (its own frame): the top of its bail - it hangs
## from the fingers by it (user request: the lamp held exactly). The bail
## runs across the lamp's x there (tools/make_menu_lamp.py), turned to go
## through the fist the way its hole goes (CharacterArt.fit().grip_axis).
const LAMP_BAIL := Vector3(0.0, 0.47, 0.0)
## (it's hinged on lugs BAIL_FOOT up the lamp, and lies folded over to its
## +z on a lamp stood down - fold_bail())
const BAIL_FOOT := 0.24

## The flashlight (built along +x, lens forward, about 1.05 long), held
## out in the left hand in place of the lamp - the shop's try-on.
const FLASHLIGHT := preload("res://assets/models/items/flashlight.glb")
const FLASHLIGHT_SCALE := 0.3

var anim: AnimationPlayer
var skeleton: Skeleton3D
## Who's wearing it (Profile.character when built; set_character()).
var character := ""
var _body: Node3D
var attachments := {}
## Holds the rod the player owns, following the profile; off for the
## shop's try-on (it holds what's being tried).
var follow_profile := true
## Takes up the rod and the lamp when it's ready. Off at the camp (user
## request): resting there, its hands are empty - the lamp sits on the oil
## drum, the rod leans on the tent - until it sets out.
var hold_gear := true
## Back to breathing when a clip ends. Off at the camp, where CampLife says
## what comes next.
var auto_idle := true
## The lamp hanging from the left hand: it stays upright and swings as the
## hand moves (eased in from `_hang_from`, where it was picked up).
var _hang: Node3D
var _hang_from := Transform3D.IDENTITY
var _hang_in := 1.0
## (how far its bail was folded down where it was picked up)
var _fold_from := 0.0
var _grip_last := Vector3.ZERO
var _grip_vel := Vector3.ZERO
var _swing := Vector2.ZERO
var _swing_vel := Vector2.ZERO
## A push on the hanging lamp from the stride (set each frame by whoever
## walks it - RunView3D: user request, the lamp swings as it's walked).
var gait_push := Vector2.ZERO
## The left fingers closed round the lamp's bail while it's held (whatever
## the clip does with them).
var _grip_mod: Grip
## The lamp's arm held out from the side as far as the lamp needs to clear
## the leg under it (each character's own width - CharacterArt.fit()),
## while it's in the hand; off where something else holds the lamp
## (RunView3D at the hip).
var lamp_in_hand := true
var _clear_mod: LampClear


func _ready() -> void:
	_build(Profile.character)
	Profile.profile_changed.connect(_on_profile_changed)


## User request (the camp's fire changes who's travelling): another
## character in the same place - its own model, idling, holding what this
## one held if it holds gear (what hung on the slots otherwise goes).
func set_character(id: String) -> void:
	if id == character:
		return
	if _body != null:
		remove_child(_body)
		_body.queue_free()
	_body = null
	anim = null
	skeleton = null
	_grip_mod = null
	_clear_mod = null
	_hang = null
	attachments = {}
	_build(id)


func _build(id: String) -> void:
	character = id
	_body = CharacterArt.model(id).instantiate()
	add_child(_body)
	anim = _find(_body, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(_body, "Skeleton3D") as Skeleton3D
	if skeleton != null:
		skeleton.skeleton_updated.connect(_on_skeleton_updated)
		_grip_mod = Grip.new()
		_grip_mod.name = "Grip"
		_grip_mod.influence = 0.0
		skeleton.add_child(_grip_mod)
		# User request: each one's arms kept off its own body - the clips were
		# made for a slim one, the round ones' hands went into their hips.
		var room := ArmRoom.new()
		room.name = "ArmRoom"
		room.rig = self
		skeleton.add_child(room)
		_clear_mod = LampClear.new()
		_clear_mod.name = "LampClear"
		_clear_mod.rig = self
		_clear_mod.influence = 0.0
		skeleton.add_child(_clear_mod)
		# User request: the ears and the tail move on their own.
		var sway := EarTailSway.new()
		sway.name = "EarTailSway"
		sway.follow_steps = true
		skeleton.add_child(sway)
	_dress(_body)
	if anim != null:
		anim.animation_finished.connect(func(_n):
			if auto_idle:
				play_idle())
		play_idle()
	for slot in SLOTS:
		var att := BoneAttachment3D.new()
		att.bone_name = SLOTS[slot]
		skeleton.add_child(att)
		attachments[slot] = att
	if hold_gear:
		equip_rod(Profile.rod_tier)
		equip_lamp()


func _on_profile_changed() -> void:
	if is_inside_tree() and follow_profile and hold_gear:
		equip_rod(Profile.rod_tier)


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null


## The mannequin in the game's colours. A character with its own
## pictures (the beginner owl person) or its own colours (a greybox animal
## person's trial ones, tools/greybox_colour.py: "col_<zone>") keeps them,
## with the same rim.
func _dress(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var src := mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D and ((src as BaseMaterial3D).albedo_texture != null or src.resource_name.begins_with("col_")):
				var own := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				own.rim_enabled = true
				own.rim = 0.25
				mi.set_surface_override_material(i, own)
				continue
			var m := StandardMaterial3D.new()
			var joints := src != null and src.resource_name.contains("Joint")
			m.albedo_color = JOINTS if joints else SKIN
			m.roughness = 0.55
			m.rim_enabled = true
			m.rim = 0.35
			mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_dress(c)


func play_idle() -> void:
	if anim == null:
		return
	for name in anim.get_animation_list():
		if name == "Idle" or name.begins_with("Idle_Loop"):
			anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			anim.play(name, 0.3)
			return


func wave() -> void:
	if anim == null:
		return
	for name in anim.get_animation_list():
		if name.begins_with("Interact"):
			anim.play(name, 0.2)
			return


## Hangs `model` (a PackedScene) on a paper-doll slot, replacing what was
## there; null empties it.
func equip(slot: String, model: PackedScene, offset := Transform3D.IDENTITY) -> void:
	var att: BoneAttachment3D = attachments.get(slot)
	if att == null:
		return
	for c in att.get_children():
		att.remove_child(c)
		c.queue_free()
	if model != null:
		var inst: Node3D = model.instantiate()
		inst.transform = offset
		att.add_child(inst)


## Hangs `node` (built in code) on a slot, replacing what was there.
func equip_node(slot: String, node: Node3D, offset := Transform3D.IDENTITY) -> void:
	equip(slot, null)
	var att: BoneAttachment3D = attachments.get(slot)
	if att == null:
		node.free()
		return
	node.transform = offset
	att.add_child(node)


## A bone's pose (skeleton space) `t` into clip `a`, worked out from its
## tracks - no need to play it.
func pose_at(a: Animation, t: float, bone_name: String) -> Transform3D:
	var chain: Array[int] = []
	var b := skeleton.find_bone(bone_name)
	while b >= 0:
		chain.push_front(b)
		b = skeleton.get_bone_parent(b)
	var xf := Transform3D.IDENTITY
	for bi in chain:
		var rest := skeleton.get_bone_rest(bi)
		var pos := rest.origin
		var rot := rest.basis.get_rotation_quaternion()
		var scl := rest.basis.get_scale()
		var suffix := ":" + skeleton.get_bone_name(bi)
		for ti in a.get_track_count():
			if not str(a.track_get_path(ti)).ends_with(suffix):
				continue
			match a.track_get_type(ti):
				Animation.TYPE_POSITION_3D:
					pos = a.position_track_interpolate(ti, t)
				Animation.TYPE_ROTATION_3D:
					rot = a.rotation_track_interpolate(ti, t)
				Animation.TYPE_SCALE_3D:
					scl = a.scale_track_interpolate(ti, t)
		xf = xf * Transform3D(Basis(rot).scaled(scl), pos)
	return xf


## The offset that holds a thing as `world` (a basis in the character's
## frame) `drop` from the hand, against the resting pose (see _held).
func held_offset(slot: String, world: Basis, drop: Vector3) -> Transform3D:
	return _held(slot, world, drop)


func equip_rod(tier: int) -> void:
	var y := ROD_AIM.normalized()
	var x := y.cross(Vector3.BACK).normalized()
	equip("hand_r", RODS[clampi(tier, 0, RODS.size() - 1)],
		_held("hand_r", Basis(x, y, x.cross(y)).scaled(Vector3.ONE * ROD_SCALE), Vector3.ZERO, ROD_GRIP))


## The lamp in the left hand, hanging by its bail from the fingers; picked
## up from `from` (its world place, e.g. on the drum), it's eased into the
## hand from there.
func equip_lamp(from: Variant = null) -> void:
	equip("hand_l", LAMP)
	var att: BoneAttachment3D = attachments.get("hand_l")
	if att == null or att.get_child_count() == 0:
		return
	_hang = att.get_child(0)
	_hang.top_level = true
	if _grip_mod != null:
		_grip_mod.fist(self)
	_swing = Vector2.ZERO
	_swing_vel = Vector2.ZERO
	_grip_last = _grip()
	_grip_vel = Vector3.ZERO
	_hang_in = 1.0
	if from is Transform3D:
		_hang_from = from
		_hang_in = 0.0
	_hang_lamp(0.0)


## Where the left fist leaves room for the bail (world): measured on each
## character (CharacterArt.fit().grip, the hand_l bone's frame) - else
## between the fingers.
func _grip() -> Vector3:
	var fit := CharacterArt.fit(character)
	var h := skeleton.find_bone("hand_l")
	if fit.has("grip") and h >= 0:
		var g: Array = fit.grip
		return skeleton.global_transform * (skeleton.get_bone_global_pose(h) * Vector3(g[0], g[1], g[2]))
	var a := skeleton.find_bone("middle_01_l")
	var b := skeleton.find_bone("middle_02_l")
	if a < 0 or b < 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(h).origin
	var mid := (skeleton.get_bone_global_pose(a).origin + skeleton.get_bone_global_pose(b).origin) / 2.0
	return skeleton.global_transform * mid


func _process(delta: float) -> void:
	if _grip_mod != null:
		var want := 1.0 if _hang != null and is_instance_valid(_hang) else 0.0
		_grip_mod.influence = move_toward(_grip_mod.influence, want, delta / 0.2)
	if _clear_mod != null:
		var on := 1.0 if _hang != null and is_instance_valid(_hang) and lamp_in_hand else 0.0
		_clear_mod.influence = move_toward(_clear_mod.influence, on, delta / 0.25)


## User report: getting up off the ground after a run lost (CampLife,
## LayToIdle - UAL's clip, made for its mannequin's proportions) sank the
## animal people into the ground. While a clip in FLOOR_CLIPS is on, the
## body's lifted so none of FLOOR_BONES is lower than its clearance (m off
## the ground: the trunk lies on its back, the feet stand on it) - at once
## when it would sink, eased back down after.
const FLOOR_CLIPS := ["LayToIdle"]
const FLOOR_BONES := {"pelvis": 0.12, "spine_03": 0.12, "Head": 0.1, "hand_l": 0.03, "hand_r": 0.03,
	"foot_l": 0.05, "foot_r": 0.05, "ball_l": 0.02, "ball_r": 0.02, "ball_leaf_l": 0.0, "ball_leaf_r": 0.0}
const FLOOR_EASE := 0.35
var _floor_lift := 0.0


func _keep_off_floor(delta: float) -> void:
	var want := 0.0
	if anim != null and anim.assigned_animation in FLOOR_CLIPS:
		var to_rig := global_transform.affine_inverse() * skeleton.global_transform
		for b in FLOOR_BONES:
			var i := skeleton.find_bone(b)
			if i >= 0:
				var y := (to_rig * skeleton.get_bone_global_pose(i).origin).y - _body.position.y
				want = maxf(want, float(FLOOR_BONES[b]) - y)
	_floor_lift = want if want > _floor_lift else move_toward(_floor_lift, want, delta / FLOOR_EASE)
	_body.position.y = _floor_lift


## After the skeleton's posed for the frame (so the lamp keeps to the
## fingers, not a frame behind).
func _on_skeleton_updated() -> void:
	_keep_off_floor(get_process_delta_time())
	if _hang != null:
		if not is_instance_valid(_hang) or not _hang.is_inside_tree():
			_hang = null
		else:
			_hang_lamp(get_process_delta_time())


## How the lamp's swinging (radians about the world's z and x).
func lamp_swing() -> Vector2:
	return _swing


## Keeps the lamp hanging from the fingers: upright, swinging back as the
## hand speeds up and forward as it stops, a damped pendulum.
func _hang_lamp(delta: float) -> void:
	var grip := _grip()
	if delta > 0.0:
		var vel := (grip - _grip_last) / delta
		var acc := (vel - _grip_vel) / delta
		_grip_vel = vel
		var push := Vector2(-acc.x, -acc.z) * 0.012 + gait_push
		_swing_vel += (push.limit_length(0.45) - _swing) * 60.0 * delta - _swing_vel * 6.0 * delta
		_swing = (_swing + _swing_vel * delta).limit_length(0.5)
	_grip_last = grip
	var yaw := Basis(Vector3.UP, _bail_yaw(delta))
	var b := yaw
	var k := global_transform.basis.get_scale().x
	# (not swung into the body: as far as it can go short of it)
	for share in [1.0, 0.6, 0.3, 0.0]:
		var sw: Vector2 = _swing * share
		b = yaw
		if sw.length() > 0.001:
			b = Basis(Vector3(sw.y, 0.0, -sw.x).normalized(), sw.length()) * yaw
		if share == 0.0 or not _into_body(grip, b.scaled(Vector3.ONE * k)):
			if share < 1.0:
				_swing = sw
				_swing_vel *= share
			break
	b = _off_forearm(grip, b, k) * b
	b = b.scaled(Vector3.ONE * k)
	var to := Transform3D(b, grip - b * LAMP_BAIL)
	if _hang_in < 1.0:
		_hang_in = minf(_hang_in + delta / 0.3, 1.0)
		to = _hang_from.interpolate_with(to, smoothstep(0.0, 1.0, _hang_in))
		# (its bail coming up from folded as it's lifted by it)
		fold_bail(_hang, _fold_from * (1.0 - smoothstep(0.0, 1.0, _hang_in)))
	elif _fold_from != 0.0:
		_fold_from = 0.0
		fold_bail(_hang, 0.0)
	_hang.global_transform = to


## The lamp pushed aside by the forearm it hangs under (raised steeply, a
## short arm's lay over its top): turned about the bail just far enough
## that its top and cap clear the forearm - its own thickness.
func _off_forearm(grip: Vector3, b: Basis, k: float) -> Basis:
	var e := skeleton.find_bone("lowerarm_l")
	var w := skeleton.find_bone("hand_l")
	if e < 0 or w < 0:
		return Basis.IDENTITY
	var elbow := skeleton.global_transform * skeleton.get_bone_global_pose(e).origin
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(w).origin
	var thick := float(CharacterArt.fit(character).get("forearm", 0.04)) * k
	# (the forearm, and the hand on from it - each finger, a long one's
	# claws hanging down past the fist)
	var limbs := [[elbow, wrist, thick]]
	for digit in ["thumb", "index", "middle", "ring", "pinky"]:
		var leaf := skeleton.find_bone(digit + "_04_leaf_l")
		if leaf >= 0:
			var tip := skeleton.global_transform * skeleton.get_bone_global_pose(leaf).origin
			limbs.append([wrist, tip + (tip - wrist) * 0.15, thick * 0.75])
	var turn := Basis.IDENTITY
	# (looked at again after each push - one finger's push can bring it to
	# the next)
	for _pass in 3:
		for limb in limbs:
			turn = _push_off(grip, turn * b, k, limb[0], limb[1], limb[2]) * turn
	if turn.get_rotation_quaternion().get_angle() > 0.9:
		turn = Basis(Quaternion.IDENTITY.slerp(turn.get_rotation_quaternion(), 0.9 / turn.get_rotation_quaternion().get_angle()))
	return turn


func _push_off(grip: Vector3, b: Basis, k: float, from: Vector3, to_: Vector3, thick: float) -> Basis:
	var turn := Basis.IDENTITY
	for part in LAMP_TOP:
		var c: Vector3 = grip + turn * b * (Vector3(0.0, part.x, 0.0) - LAMP_BAIL) * k
		var on := Geometry3D.get_closest_point_to_segment(c, from, to_)
		var away := c - on
		var room: float = part.y * k + thick + 0.035 * k
		if away.length() >= room:
			continue
		var arm := c - grip
		var to := arm + away.normalized() * (room - away.length()) if away.length() > 0.001 else arm
		var axis := arm.cross(to)
		if axis.length() <= 0.000001:
			# (a finger straight down the bail at it gives no way aside: then
			# away to the lamp's front, as far as it's short)
			var side := b.z - arm.normalized() * b.z.dot(arm.normalized())
			to = arm + side.normalized() * (room - away.length())
			axis = arm.cross(to)
		if axis.length() > 0.000001:
			turn = Basis(axis.normalized(), minf(arm.angle_to(to), 0.7)) * turn
	return turn


## (the lamp's top and its cap: height, radius - its own frame)
const LAMP_TOP := [Vector2(0.28, 0.044), Vector2(0.24, 0.08)]


## Whether the lamp hanging from `grip` so (its basis, scaled) would be in
## the body: its base, middle and cap against the body's front and sides at
## their heights (CharacterArt.fit(); the back taken as far as the front).
func _into_body(grip: Vector3, b: Basis) -> bool:
	var fit := CharacterArt.fit(character)
	if fit.is_empty():
		return false
	var k := global_transform.basis.get_scale().x
	var to_me := global_transform.affine_inverse()
	for h in [0.03, 0.15, 0.24]:
		var p: Vector3 = to_me * (grip + b * (Vector3(0.0, h, 0.0) - LAMP_BAIL))
		var r := 0.075 * b.get_scale().x / k
		var front := CharacterArt.front_between(character, p.y - r, p.y + r, -1.0)
		var side := CharacterArt.side_between(character, p.y - r, p.y + r, -1.0)
		if front < 0.0 or side < 0.0:
			continue
		if absf(p.x) - r < side and p.z - r < front and p.z + r > -front:
			return true
	return false


## Which way the lamp's turned about the up (its bail, along its x, through
## the fist as the hole goes): eased round, never flipped end for end -
## the bail's the same either way.
var _bail := NAN


func _bail_yaw(delta: float) -> float:
	var want := global_rotation.y
	var fit := CharacterArt.fit(character)
	var h := skeleton.find_bone("hand_l")
	if fit.has("grip_axis") and h >= 0:
		var g: Array = fit.grip_axis
		var axis := (skeleton.global_transform.basis * skeleton.get_bone_global_pose(h).basis) * Vector3(g[0], g[1], g[2])
		axis.y = 0.0
		if axis.length() > 0.05:
			# (the lamp's x along it: its yaw is the axis's, less a right angle -
			# whichever of the two ways is nearer the lamp as it is)
			want = atan2(-axis.z, axis.x)
			var ref := _bail if not is_nan(_bail) else global_rotation.y
			if absf(angle_difference(ref, want + PI)) < absf(angle_difference(ref, want)):
				want += PI
	if is_nan(_bail) or delta <= 0.0:
		_bail = want
	else:
		_bail = lerp_angle(_bail, want, minf(delta * 10.0, 1.0))
	return _bail


## A lamp's bail laid over toward its +z by `angle` (radians; 0 upright).
static func fold_bail(lamp: Node3D, angle: float) -> void:
	var bail := lamp.find_child("Bail", true, false) as Node3D
	if bail != null:
		bail.rotation.x = angle


## Where the middle of the bail's top is (the lamp's frame), folded so.
static func bail_top(angle: float) -> Vector3:
	var span := LAMP_BAIL.y - BAIL_FOOT
	return Vector3(0.0, BAIL_FOOT + span * cos(angle), span * sin(angle))


## The flashlight in the left hand, pointed ahead and a little down.
func equip_flashlight() -> void:
	var ahead := Vector3(0.35, -0.2, 1.0).normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	var world := Basis(ahead, side.cross(ahead), side).scaled(Vector3.ONE * FLASHLIGHT_SCALE)
	equip("hand_l", FLASHLIGHT, _held("hand_l", world, Vector3(0.0, -0.04, 0.06)))


## An offset for a slot's bone that puts a model at `world` (a basis in the
## character's frame) `drop` away in that frame, plus `grip` in the bone's -
## set against the bone as the idle pose holds it (the rig's rest is a
## T-pose), so it holds whichever way the bone's axes happen to lie.
func _held(slot: String, world: Basis, drop: Vector3, grip := Vector3.ZERO) -> Transform3D:
	var bone := skeleton.find_bone(SLOTS[slot])
	if anim != null:
		anim.advance(0.0)
	var pose := skeleton.get_bone_global_pose(bone).basis.orthonormalized() if bone >= 0 else Basis.IDENTITY
	var inv := pose.inverse()
	return Transform3D(inv * world, inv * drop + grip)


## The left hand's fingers held as Idle holds them - a loose fist, closed
## round a bail - over whatever the clip does (blended by `influence`).
class Grip extends SkeletonModifier3D:
	var _rotations := {}

	func fist(rig: CharacterRig) -> void:
		if not _rotations.is_empty() or rig.anim == null or not rig.anim.has_animation("Idle"):
			return
		var a := rig.anim.get_animation("Idle")
		var sk := rig.skeleton
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if not n.ends_with("_l") or not (n.begins_with("index") or n.begins_with("middle")
					or n.begins_with("ring") or n.begins_with("pinky") or n.begins_with("thumb")):
				continue
			for ti in a.get_track_count():
				if a.track_get_type(ti) == Animation.TYPE_ROTATION_3D and str(a.track_get_path(ti)).ends_with(":" + n):
					_rotations[i] = a.rotation_track_interpolate(ti, 0.0)

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		for b in _rotations:
			sk.set_bone_pose_rotation(b, _rotations[b])


## The left arm turned out at the shoulder (about the body's front-back) as
## far as the lamp hanging from its fist needs to clear the body beside it -
## the hips and the leg at the lamp's height (CharacterArt.fit()'s side) -
## eased, over whatever the clip does.
class LampClear extends SkeletonModifier3D:
	const ROOM := 0.05
	const MOST := 0.6
	var rig: CharacterRig
	var _turn := 0.0

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or rig == null or rig._hang == null or not is_instance_valid(rig._hang):
			return
		var arm := sk.find_bone("upperarm_l")
		if arm < 0:
			return
		var to_rig := rig.global_transform.affine_inverse() * sk.global_transform
		var k := rig.global_basis.get_scale().x
		var lamp := rig._hang.global_basis.get_scale().x / maxf(k, 0.001)
		var shoulder := to_rig * sk.get_bone_global_pose(arm).origin
		var grip := rig.global_transform.affine_inverse() * rig._grip()
		var top := grip.y - 0.1 * lamp
		var low := grip.y - LAMP_BAIL.y * lamp
		var need := CharacterArt.side_between(rig.character, low, top, -1.0)
		var want := 0.0
		if need > 0.0:
			need += 0.08 * lamp + ROOM
			var v := Vector2(grip.x - shoulder.x, grip.y - shoulder.y)
			var r := v.length()
			var t := need - shoulder.x
			if grip.x < need and r > 0.05 and absf(t) < r:
				want = clampf(-acos(t / r) - atan2(v.y, v.x), 0.0, MOST)
		_turn = lerpf(_turn, want, 0.25)
		if _turn < 0.002:
			return
		var axis := (sk.global_basis.inverse() * rig.global_basis.z).normalized()
		var pose := sk.get_bone_global_pose(arm)
		var turned := Basis(axis, _turn) * pose.basis
		var parent := sk.get_bone_parent(arm)
		var up := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		sk.set_bone_pose_rotation(arm, (up.inverse() * turned).get_rotation_quaternion())


## Each arm turned out at the shoulder as far as it needs to keep the elbow,
## the forearm and the hand off the body - its own front and sides at their
## heights (CharacterArt.fit(), an ellipse about the hips' line), its own
## forearm's thickness - eased. Standing only (the hips down, sat or
## knelt, the shape's another).
class ArmRoom extends SkeletonModifier3D:
	const ROOM := -0.015
	const MOST := 0.5
	var rig: CharacterRig
	var _turn := {"l": Basis.IDENTITY, "r": Basis.IDENTITY}

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or rig == null:
			return
		var fit := CharacterArt.fit(rig.character)
		if fit.is_empty():
			return
		var to_rig := rig.global_transform.affine_inverse() * sk.global_transform
		var pelvis := sk.find_bone("pelvis")
		var standing := smoothstep(0.75, 0.9, (to_rig * sk.get_bone_global_pose(pelvis).origin).y / float(fit.pelvis))
		var thick := float(fit.get("forearm", 0.05))
		for side in ["l", "r"]:
			var arm := sk.find_bone("upperarm_" + side)
			if arm < 0:
				continue
			var shoulder := to_rig * sk.get_bone_global_pose(arm).origin
			var elbow := to_rig * sk.get_bone_global_pose(sk.find_bone("lowerarm_" + side)).origin
			var wrist := to_rig * sk.get_bone_global_pose(sk.find_bone("hand_" + side)).origin
			var leaf := sk.find_bone("middle_04_leaf_" + side)
			var tip := to_rig * sk.get_bone_global_pose(leaf).origin if leaf >= 0 else wrist
			var round_elbow := float(fit.get("elbow", thick))
			var probes := [[elbow, round_elbow], [elbow.lerp(wrist, 0.3), lerpf(round_elbow, thick, 0.6)], [elbow.lerp(wrist, 0.65), thick],
				[wrist, thick], [wrist.lerp(tip, 0.6), thick * 0.8]]
			# (and each finger's end - a long hand's splay in to the hip)
			for digit in ["thumb", "index", "ring", "pinky"]:
				var end := sk.find_bone("%s_04_leaf_%s" % [digit, side])
				if end >= 0:
					probes.append([to_rig * sk.get_bone_global_pose(end).origin, thick * 0.4])
			# (turned a little at a time, looked at again, till it's out)
			var want := Basis.IDENTITY
			for _step in 4:
				var most := 0.0
				var axis := Vector3.ZERO
				for q in probes:
					var at: Vector3 = shoulder + want * (q[0] - shoulder)
					var d := _out_of_body(fit, at, q[1])
					if d.length() < 0.001:
						continue
					var from := at - shoulder
					var a := d.length() / maxf(from.length(), 0.05)
					var ax := from.cross(d)
					if a > most and ax.length() > 0.000001:
						most = a
						axis = ax.normalized()
				if most <= 0.0:
					break
				want = Basis(axis, most) * want
			if want.get_rotation_quaternion().get_angle() > MOST:
				want = Basis(Quaternion.IDENTITY.slerp(want.get_rotation_quaternion(), MOST / want.get_rotation_quaternion().get_angle()))
			want = Basis(Quaternion.IDENTITY.slerp(want.get_rotation_quaternion(), standing))
			_turn[side] = Basis((_turn[side] as Basis).get_rotation_quaternion().slerp(want.get_rotation_quaternion(), 0.35))
			var q_turn := (_turn[side] as Basis).get_rotation_quaternion()
			if q_turn.get_angle() < 0.002:
				continue
			# (the turn's in the character's frame; the bone's in the skeleton's)
			var in_sk := to_rig.basis.inverse() * Basis(q_turn) * to_rig.basis
			var pose := sk.get_bone_global_pose(arm)
			var parent := sk.get_bone_parent(arm)
			var up := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
			sk.set_bone_pose_rotation(arm, (up.inverse() * (in_sk * pose.basis)).get_rotation_quaternion())

	## How far (and which way, flat) a point `r` round has to go to be out of
	## the body at its height - its outline a rounded box (a superellipse)
	## out to its own front, back and sides there; zero if it's out.
	static func _out_of_body(fit: Dictionary, q: Vector3, r: float) -> Vector3:
		var right := q.x < 0.0
		var side := _band(fit.get("side_r" if right else "side", []), q.y)
		var zc := float(fit.get("hips_z", 0.0))
		var ahead := q.z >= zc
		var reach := _band(fit.get("front", []), q.y) - zc if ahead else zc - _band(fit.get("back", []), q.y, -1.0)
		if side <= 0.0 or reach <= 0.0:
			return Vector3.ZERO
		var a := side + r + ROOM
		var b := reach + r + ROOM
		var x := absf(q.x) / a
		var z := absf(q.z - zc) / b
		var e := pow(x, 4.0) + pow(z, 4.0)
		if e >= 1.0 or e < 0.000001:
			return Vector3.ZERO
		var k := pow(1.0 / e, 0.25)
		return Vector3(q.x * (k - 1.0), 0.0, (q.z - zc) * (k - 1.0))

	static func _band(bins: Array, y: float, sign := 1.0) -> float:
		var i := int(floor(y / CharacterArt.FIT_BIN))
		if i < 0 or i >= bins.size():
			return -1.0 if sign > 0.0 else 1.0
		return float(bins[i])
