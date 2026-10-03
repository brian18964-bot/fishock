class_name CharacterRig
extends Node3D

## The player's character in 3D - in the main screen's camp and on the
## equipment page (CharacterViewer): assets/models/menu_character.glb -
## the black cat (a greybox animal person in its trial colours) on
## Quaternius' Universal Animation Library skeleton (CC0;
## tools/build_menu_character.py), with its clips - breathing, waving when tapped, and dressed as a paper
## doll: equip(slot, scene) hangs a model on a bone (SLOTS) - the rod bought
## in the right hand, the oil lamp in the left; hats, packs and the rest
## later.

const CHARACTER := preload("res://assets/models/menu_character.glb")
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
## the fingers get to, in the character's frame (+z ahead, +x its left) -
## where a lamp to be picked up should hang. Measured from the clip on
## the character wearing it (the black cat: its index fingertip).
const REACH_CLIP := "Interact"
const REACH_AT := 0.32
const REACH := Vector3(0.10, 1.01, 0.42)
## Where the lamp is held (its own frame): the top of its bail - it hangs
## from the fingers by it (user request: the lamp held exactly).
const LAMP_BAIL := Vector3(0.0, 0.29, 0.0)

## The flashlight (built along +x, lens forward, about 1.05 long), held
## out in the left hand in place of the lamp - the shop's try-on.
const FLASHLIGHT := preload("res://assets/models/items/flashlight.glb")
const FLASHLIGHT_SCALE := 0.3

var anim: AnimationPlayer
var skeleton: Skeleton3D
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
var _grip_last := Vector3.ZERO
var _grip_vel := Vector3.ZERO
var _swing := Vector2.ZERO
var _swing_vel := Vector2.ZERO
## The left fingers closed round the lamp's bail while it's held (whatever
## the clip does with them).
var _grip_mod: Grip


func _ready() -> void:
	var body: Node3D = CHARACTER.instantiate()
	add_child(body)
	anim = _find(body, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(body, "Skeleton3D") as Skeleton3D
	if skeleton != null:
		skeleton.skeleton_updated.connect(_on_skeleton_updated)
		_grip_mod = Grip.new()
		_grip_mod.name = "Grip"
		_grip_mod.influence = 0.0
		skeleton.add_child(_grip_mod)
	_dress(body)
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
	Profile.profile_changed.connect(_on_profile_changed)


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


## Between the fingers of the left hand (world).
func _grip() -> Vector3:
	var a := skeleton.find_bone("middle_01_l")
	var b := skeleton.find_bone("middle_02_l")
	if a < 0 or b < 0:
		var h := skeleton.find_bone("hand_l")
		return skeleton.global_transform * skeleton.get_bone_global_pose(h).origin
	var mid := (skeleton.get_bone_global_pose(a).origin + skeleton.get_bone_global_pose(b).origin) / 2.0
	return skeleton.global_transform * mid


func _process(delta: float) -> void:
	if _grip_mod != null:
		var want := 1.0 if _hang != null and is_instance_valid(_hang) else 0.0
		_grip_mod.influence = move_toward(_grip_mod.influence, want, delta / 0.2)


## After the skeleton's posed for the frame (so the lamp keeps to the
## fingers, not a frame behind).
func _on_skeleton_updated() -> void:
	if _hang != null:
		if not is_instance_valid(_hang) or not _hang.is_inside_tree():
			_hang = null
		else:
			_hang_lamp(get_process_delta_time())


## Keeps the lamp hanging from the fingers: upright, swinging back as the
## hand speeds up and forward as it stops, a damped pendulum.
func _hang_lamp(delta: float) -> void:
	var grip := _grip()
	if delta > 0.0:
		var vel := (grip - _grip_last) / delta
		var acc := (vel - _grip_vel) / delta
		_grip_vel = vel
		var push := Vector2(-acc.x, -acc.z) * 0.012
		_swing_vel += (push.limit_length(0.45) - _swing) * 60.0 * delta - _swing_vel * 6.0 * delta
		_swing = (_swing + _swing_vel * delta).limit_length(0.5)
	_grip_last = grip
	var b := Basis(Vector3.UP, global_rotation.y)
	if _swing.length() > 0.001:
		b = Basis(Vector3(_swing.y, 0.0, -_swing.x).normalized(), _swing.length()) * b
	b = b.scaled(Vector3.ONE * global_transform.basis.get_scale().x)
	var to := Transform3D(b, grip - b * LAMP_BAIL)
	if _hang_in < 1.0:
		_hang_in = minf(_hang_in + delta / 0.3, 1.0)
		to = _hang_from.interpolate_with(to, smoothstep(0.0, 1.0, _hang_in))
	_hang.global_transform = to


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
