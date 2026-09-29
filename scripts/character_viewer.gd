class_name CharacterViewer
extends SubViewportContainer

## User request (the main screen): the player's character shown in 3D,
## front on - it'll be dressed up later (a paper doll), so the player
## should see their own. A small 3D stage in a SubViewport: the character
## (assets/models/menu_character.glb - Quaternius' Universal Animation
## Library mannequin, CC0, trimmed by hand to three clips) breathing on a
## round stone, lit by a warm lantern from the front and a cold rim from
## behind, in the dark. Drag to turn it; tap it and it waves.
##
## Paper doll: equip(slot, scene) hangs a model on a bone (SLOTS) - the rod
## in the right hand now; hats, packs and the rest later.

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

## Where the character stands in the frame: -1 left edge .. 1 right edge.
@export var frame_x := 0.0
@export var zoom := 1.0

var _viewport: SubViewport
var _pivot: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _camera: Camera3D
var _attachments := {}
var _turn := 0.0
var _turn_vel := 0.0
var _dragging := false
var _drag_moved := 0.0
var _time := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_build_stage()
	resized.connect(func(): _frame())
	_frame()
	equip_rod(Profile.rod_tier)
	equip_lamp()
	Profile.profile_changed.connect(func(): equip_rod(Profile.rod_tier))


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.3, 0.42)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_viewport.add_child(env)

	# Warm lantern light from the front-left, cold moonlight rim from behind.
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.72, 0.4)
	key.light_energy = 2.6
	key.omni_range = 7.0
	key.position = Vector3(-1.2, 1.6, 2.0)
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.7, 1.0)
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-25, 160, 0)
	_viewport.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.7, 0.75, 0.9)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-40, -20, 0)
	_viewport.add_child(fill)

	# The round stone it stands on, and a faint glow ring round it.
	var stone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.85
	cyl.height = 0.18
	cyl.radial_segments = 40
	stone.mesh = cyl
	stone.position.y = -0.09
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.2, 0.2, 0.22)
	sm.roughness = 0.9
	stone.material_override = sm
	_viewport.add_child(stone)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 0.82
	ring.mesh = torus
	ring.position.y = 0.005
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.8, 0.45)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.75, 0.35)
	rm.emission_energy_multiplier = 1.5
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	_viewport.add_child(ring)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var body: Node3D = CHARACTER.instantiate()
	_pivot.add_child(body)
	_anim = _find(body, "AnimationPlayer") as AnimationPlayer
	_skeleton = _find(body, "Skeleton3D") as Skeleton3D
	_dress(body)
	if _anim != null:
		_anim.animation_finished.connect(func(_n): _play_idle())
		_play_idle()
	for slot in SLOTS:
		var att := BoneAttachment3D.new()
		att.bone_name = SLOTS[slot]
		_skeleton.add_child(att)
		_attachments[slot] = att

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)


func _find(n: Node, cls: String) -> Node:
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


func _play_idle() -> void:
	if _anim == null:
		return
	for name in _anim.get_animation_list():
		if name == "Idle" or name.begins_with("Idle_Loop"):
			_anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			_anim.play(name, 0.3)
			return


func wave() -> void:
	if _anim == null:
		return
	for name in _anim.get_animation_list():
		if name.begins_with("Interact"):
			_anim.play(name, 0.2)
			return


## Hangs `model` (a PackedScene) on a paper-doll slot, replacing what was
## there; null empties it.
func equip(slot: String, model: PackedScene, offset := Transform3D.IDENTITY) -> void:
	var att: BoneAttachment3D = _attachments.get(slot)
	if att == null:
		return
	for c in att.get_children():
		c.queue_free()
	if model != null:
		var inst: Node3D = model.instantiate()
		inst.transform = offset
		att.add_child(inst)


## The rod bought (Profile.rod_tier) in the right hand, held up and out.
## The rods' models are 6 m long along +Y, the grip at the origin.
const ROD_AIM := Vector3(-0.42, 1.0, 0.15)
const ROD_SCALE := 0.24
const ROD_GRIP := Vector3.ZERO
## The oil lamp (0.3 m, base at the origin) hangs from the left hand.
const LAMP := preload("res://assets/models/oil_lamp.glb")
const LAMP_DROP := Vector3(0.0, -0.3, 0.02)


func equip_rod(tier: int) -> void:
	var y := ROD_AIM.normalized()
	var x := y.cross(Vector3.BACK).normalized()
	equip("hand_r", RODS[clampi(tier, 0, RODS.size() - 1)],
		_held("hand_r", Basis(x, y, x.cross(y)).scaled(Vector3.ONE * ROD_SCALE), Vector3.ZERO, ROD_GRIP))


func equip_lamp() -> void:
	equip("hand_l", LAMP, _held("hand_l", Basis.IDENTITY, LAMP_DROP))


## An offset for a slot's bone that puts a model at `world` (a basis in the
## character's frame) `drop` away in that frame, plus `grip` in the bone's -
## set against the bone as the idle pose holds it (the rig's rest is a
## T-pose), so it holds whichever way the bone's axes happen to lie.
func _held(slot: String, world: Basis, drop: Vector3, grip := Vector3.ZERO) -> Transform3D:
	var bone := _skeleton.find_bone(SLOTS[slot])
	if _anim != null:
		_anim.advance(0.0)
	var pose := _skeleton.get_bone_global_pose(bone).basis.orthonormalized() if bone >= 0 else Basis.IDENTITY
	var inv := pose.inverse()
	return Transform3D(inv * world, inv * drop + grip)


func _frame() -> void:
	if _viewport == null or _camera == null:
		return
	# Full body, from a little above and in front.
	var dist := 5.6 / zoom
	_camera.position = Vector3(0, 1.25, dist)
	_camera.look_at(Vector3(0, 0.95, 0))
	# Shift so the character stands at frame_x across the view.
	_camera.h_offset = -frame_x * dist * tan(deg_to_rad(_camera.fov) / 2.0) * size.x / maxf(size.y, 1.0)


func _process(delta: float) -> void:
	_time += delta
	if not _dragging:
		# Eases back to facing front.
		_turn_vel = lerpf(_turn_vel, 0.0, minf(1.0, delta * 3.0))
		_turn += _turn_vel * delta
		_turn = lerpf(_turn, 0.0, minf(1.0, delta * 0.8))
	_pivot.rotation.y = _turn + sin(_time * 0.5) * 0.06


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_moved = 0.0
		else:
			_dragging = false
			if _drag_moved < 6.0:
				wave()
		accept_event()
	elif (event is InputEventMouseMotion and _dragging) or event is InputEventScreenDrag:
		var dx: float = event.relative.x
		_turn += dx * 0.012
		_turn_vel = dx * 0.6
		_drag_moved += absf(dx)
		accept_event()
