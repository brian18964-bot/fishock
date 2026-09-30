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

## The player's colour in the game (the sprite's cyan-blue).
const SKIN := CharacterRig.SKIN

## Where the character stands in the frame: -1 left edge .. 1 right edge.
@export var frame_x := 0.0
@export var zoom := 1.0

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
## The character itself (CharacterRig: the model, its clips, what it holds).
var rig: CharacterRig
var _anim: AnimationPlayer:
	get:
		return rig.anim if rig != null else null
var _attachments: Dictionary:
	get:
		return rig.attachments if rig != null else {}
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
	rig = CharacterRig.new()
	_pivot.add_child(rig)

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)


func wave() -> void:
	rig.wave()


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
