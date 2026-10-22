extends Node

## tools/render_portraits.gd's work, as a node in the running game (the
## autoloads up - CharacterRig needs Profile).

const SIZE := Vector2i(199, 112)
## The camera: how far off the head, its height over it, how far round
## from the front (deg, toward the character's left) and its field of view.
const DIST := 1.25
const ABOVE := 0.12
const TURN := 15.0
const FOV := 32.0
## Where the head sits in the frame (m under the head bone the camera aims;
## over it, so the head stands in the top half).
const AIM_DOWN := -0.08
## Per character, (DIST, AIM_DOWN) in place of the usual: the deer further
## off and its head lower, its antlers in.
const FRAMING := {"deer": Vector2(1.3, -0.24)}


func _ready() -> void:
	for id in OS.get_cmdline_user_args():
		await _render(id)
	get_tree().quit()


func _render(id: String) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.9)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-30, -25, 0)
	vp.add_child(key)
	var rig := CharacterRig.new()
	rig.hold_gear = false
	rig.follow_profile = false
	rig.auto_idle = false
	vp.add_child(rig)
	rig.set_character(id)
	rig.anim.seek(0.0, true)
	rig.anim.pause()
	await get_tree().process_frame
	var sk := rig.skeleton
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var t := OS.get_environment("PT").split(",") if OS.has_environment("PT") else PackedStringArray()
	var fr: Vector2 = FRAMING.get(id, Vector2(DIST, AIM_DOWN))
	var dist := float(t[0]) if t.size() > 3 else fr.x
	var down := float(t[1]) if t.size() > 3 else fr.y
	var turn := float(t[2]) if t.size() > 3 else TURN
	var fov := float(t[3]) if t.size() > 3 else FOV
	var aim := head + Vector3(0, -down, 0)
	var a := deg_to_rad(turn)
	var cam := Camera3D.new()
	cam.fov = fov
	vp.add_child(cam)
	cam.look_at_from_position(aim + Vector3(sin(a) * dist, ABOVE, cos(a) * dist), aim)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("res://assets/ui/portraits/%s.png" % id)
	print("portrait ", id, " head ", head)
	vp.queue_free()
