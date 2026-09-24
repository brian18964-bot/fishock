class_name Ripple
extends ColorRect

## User request: water that reacts to what touches it (the look of
## Physical Open Waters' wake casters and ripples, done live in 2D). One
## short-lived expanding ring drawn by shaders/ripple.gdshader, which writes
## a normal map so the lantern lights the crests like the pre-rendered
## sprites. Squashed vertically by sin 55deg to lie on the same ground plane
## as the art, and clipped to the water zone it started in.
##
## Spawned via Ripple.spawn(): bobber/lure landing and bobbing, the lure's
## wake while reeled, bites, the player wading, moored boats rocking.

const SHADER := preload("res://shaders/ripple.gdshader")
const GROUND_SQUASH := 0.819  # sin 55deg

var _life: float = 1.0
var _age: float = 0.0
var _material: ShaderMaterial


## Starts a ripple at `pos` if it's inside water; returns null otherwise.
## radius: world px the front reaches; strength: 0..1+ crest height.
static func spawn(parent: Node, pos: Vector2, radius: float, strength: float = 1.0, life: float = 1.4) -> Ripple:
	var zone: WaterZone = water_at(parent.get_tree(), pos)
	if zone == null:
		return null
	var ripple := Ripple.new()
	ripple._setup(pos, radius, strength, life, zone)
	parent.add_child(ripple)
	return ripple


static func water_at(tree: SceneTree, pos: Vector2) -> WaterZone:
	for zone in tree.get_nodes_in_group("water_zones"):
		if zone.contains(pos):
			return zone
	return null


func _setup(pos: Vector2, radius: float, strength: float, life: float, zone: WaterZone) -> void:
	_life = life
	size = Vector2(radius * 2.0, radius * 2.0 * GROUND_SQUASH)
	position = pos - size / 2.0
	z_index = -4  # above the water (-5), below docks (-3) and everything else
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("strength", strength)
	_material.set_shader_parameter("zone_center", zone.global_position)
	_material.set_shader_parameter("zone_radius", zone.radius)
	material = _material


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_material.set_shader_parameter("progress", _age / _life)
