class_name ItemPreview
extends Control

## A thing turning slowly in 3D, lit like a jeweller's window - the shop's
## and the item cards' preview (user request: out of the game, show things
## in 3D as far as it goes). Drag across it to turn it by hand. Drawn at
## twice its size (a SubViewport shown through a TextureRect) so it stays
## sharp on a phone.

const RENDER_SCALE := 2.0

var _viewport: SubViewport
var _view: TextureRect
var _holder: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _spin := 0.0
var _drag := false
var _id := ""
var _fish: MeshInstance3D
var _sway := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_stage()
	resized.connect(_fit_viewport)
	_fit_viewport()
	if _id.begins_with("fish:"):
		show_fish(_id.substr(5))
	elif _id != "":
		show_item(_id)


func _fit_viewport() -> void:
	if _viewport != null:
		_viewport.size = Vector2i((size * RENDER_SCALE).max(Vector2(8, 8)))
		if _camera != null:
			_frame()


func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.36, 0.45)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.82, 0.6)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, -30, 0)
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.7, 1.0)
	rim.light_energy = 1.2
	rim.rotation_degrees = Vector3(-15, 150, 0)
	_viewport.add_child(rim)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_holder = Node3D.new()
	_pivot.add_child(_holder)
	_camera = Camera3D.new()
	_camera.fov = 28.0
	_viewport.add_child(_camera)
	_frame()


func _frame() -> void:
	_camera.position = Vector3(0, 0.35, 3.4)
	_camera.look_at(Vector3.ZERO)


## Shows `id`'s model (Items.model_path); false (and nothing shown) when it
## has none.
func show_item(id: String) -> bool:
	_id = id
	if _holder == null:
		return Items.model_path(id) != ""
	_clear()
	var path := Items.model_path(id)
	if path == "" or not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	_holder.add_child(inst)
	_fit(inst, true)
	return true


## Shows species `id` as its 3D fish (FishModel), swimming where it is;
## false when it has no model.
func show_fish(id: String) -> bool:
	_id = "fish:" + id
	if _holder == null:
		return FishModel.has_model(id)
	_clear()
	_fish = FishModel.make(id)
	if _fish == null:
		return false
	_holder.add_child(_fish)
	_fit(_fish, false)
	# Side-on first, then it turns.
	_spin = -0.2
	_sway = 0.0
	return true


func _clear() -> void:
	_fish = null
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()


## Sizes and centres a shown thing; long things (rods) lean across the
## frame when `lean`, the rest stand as they are.
func _fit(inst: Node3D, lean: bool) -> void:
	var box := _bounds(inst)
	var long_axis := box.get_longest_axis_index()
	_holder.transform = Transform3D.IDENTITY
	if lean and box.size[long_axis] > 3.0 * box.size[(long_axis + 1) % 3]:
		_holder.rotation = Vector3(0, 0, deg_to_rad(-55)) if long_axis == Vector3.AXIS_Y else Vector3(0, 0, deg_to_rad(30))
	box = _bounds(inst)
	# (a thing standing tall - a bottle - smaller: the frame's wider than
	# it's high)
	var tall := box.get_longest_axis_index() == Vector3.AXIS_Y
	var k := (1.25 if tall else 1.7) / maxf(box.get_longest_axis_size(), 0.001)
	_holder.scale = Vector3.ONE * k
	box = _bounds(inst)
	_holder.position -= box.get_center()
	_spin = 0.0


## The model's bounds in the pivot's space.
func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var to_pivot := _pivot.global_transform.affine_inverse()
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		var box: AABB = (to_pivot * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _process(delta: float) -> void:
	if _pivot == null:
		return
	if _fish != null and is_instance_valid(_fish):
		# A fish swims where it is, swinging from one three-quarter view to
		# the other (turned all the way round it's only a sliver).
		FishModel.swim(_fish, delta, 0.3)
		if not _drag:
			_sway += delta * 0.5
		_pivot.rotation.y = _spin + sin(_sway) * 0.75
		return
	if not _drag:
		_spin += delta * 0.7
	_pivot.rotation.y = _spin


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_spin += event.relative.x * 0.015
		accept_event()
