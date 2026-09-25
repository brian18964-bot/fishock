class_name SilhouetteShadow
extends Sprite2D

## User request: a tree lit by the lamp should throw a tree-shaped shadow,
## not the hard wedge Godot's occluders extrude. This draws the object's
## own silhouette (its albedo sprite, soft-edged, black) lying on the
## ground, pivoting at its base and pointing away from whichever light is
## hitting it hardest (the "shadow_lights" group - the player's lamp and
## the fixed lamps, see LightTwin). The farther from the light, the longer
## it stretches; out of any light's reach it fades away.

const SHADER := preload("res://shaders/silhouette_shadow.gdshader")
const ACTIVE_RANGE := 520.0  # only work near the player
const LENGTH_PER_PX := 1.0 / 70.0
const LENGTH_RANGE := Vector2(0.55, 2.2)
const MAX_ALPHA := 0.7
const FADE := 6.0

var _strength := 0.0
var _player: Node2D


## Gives `owner_node` (whose origin is the object's base) a shadow made
## from `albedo`, drawn with the object's own sprite offset and scale.
static func attach(owner_node: Node2D, albedo: Texture2D, sprite_offset: Vector2, sprite_scale: float) -> SilhouetteShadow:
	var old := owner_node.get_node_or_null("SilhouetteShadow")
	if old != null:
		old.free()
	var shadow := SilhouetteShadow.new()
	shadow.name = "SilhouetteShadow"
	shadow.texture = albedo
	shadow.offset = sprite_offset
	shadow.set_meta("sprite_scale", sprite_scale)
	owner_node.add_child(shadow)
	return shadow


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	# Flat on the ground: under everything y-sorted, over ground cover,
	# water and docks (-3).
	z_as_relative = false
	z_index = -2
	visible = false
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	var base: Vector2 = (get_parent() as Node2D).global_position
	if _player == null or base.distance_to(_player.global_position) > ACTIVE_RANGE:
		visible = false
		_strength = 0.0
		return
	var best := 0.0
	var best_light: Node2D = null
	for light in get_tree().get_nodes_in_group("shadow_lights"):
		var l := light as PointLight2D
		if l == null or not l.is_visible_in_tree() or not l.enabled:
			continue
		var reach: float = 128.0 * l.texture_scale
		var d := base.distance_to(l.global_position)
		if d >= reach or d < 1.0:
			continue
		if l.has_method("illuminates") and not l.illuminates(base):
			continue
		# Full strength across most of the lit area, fading at its rim.
		var power: float = minf(l.energy, 1.0) * (1.0 - smoothstep(0.55, 1.0, d / reach))
		if power > best:
			best = power
			best_light = l
	_strength = move_toward(_strength, clampf(best, 0.0, 1.0), delta * FADE)
	visible = _strength > 0.01
	if not visible:
		return
	if best_light != null:
		var away := base - best_light.global_position
		var dist := away.length()
		var dir := away / dist
		var length := clampf(dist * LENGTH_PER_PX, LENGTH_RANGE.x, LENGTH_RANGE.y)
		var s: float = get_meta("sprite_scale")
		# Sprite "up" (the object's top) points away from the light.
		transform = Transform2D(-dir.orthogonal() * s, -dir * s * length, Vector2.ZERO)
	(material as ShaderMaterial).set_shader_parameter("strength", _strength * MAX_ALPHA)
