class_name CharacterRig
extends Node3D

## The player's character in 3D - in the main screen's camp and on the
## equipment page (CharacterViewer): assets/models/menu_character.glb -
## Quaternius' Universal Animation Library mannequin, CC0, trimmed by hand
## to three clips - breathing, waving when tapped, and dressed as a paper
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
const LAMP_DROP := Vector3(0.0, -0.3, 0.02)

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


func _ready() -> void:
	var body: Node3D = CHARACTER.instantiate()
	add_child(body)
	anim = _find(body, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(body, "Skeleton3D") as Skeleton3D
	_dress(body)
	if anim != null:
		anim.animation_finished.connect(func(_n): play_idle())
		play_idle()
	for slot in SLOTS:
		var att := BoneAttachment3D.new()
		att.bone_name = SLOTS[slot]
		skeleton.add_child(att)
		attachments[slot] = att
	equip_rod(Profile.rod_tier)
	equip_lamp()
	Profile.profile_changed.connect(_on_profile_changed)


func _on_profile_changed() -> void:
	if is_inside_tree() and follow_profile:
		equip_rod(Profile.rod_tier)


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null


## The mannequin in the game's colours.
func _dress(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var src := mi.mesh.surface_get_material(i)
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


func equip_rod(tier: int) -> void:
	var y := ROD_AIM.normalized()
	var x := y.cross(Vector3.BACK).normalized()
	equip("hand_r", RODS[clampi(tier, 0, RODS.size() - 1)],
		_held("hand_r", Basis(x, y, x.cross(y)).scaled(Vector3.ONE * ROD_SCALE), Vector3.ZERO, ROD_GRIP))


func equip_lamp() -> void:
	equip("hand_l", LAMP, _held("hand_l", Basis.IDENTITY, LAMP_DROP))


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
