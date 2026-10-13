class_name FuelStation
extends Area2D

## The player's spawn point doubles as a refuel point (moved off the altar
## per design request). A fixed light circle like the altar/escape point,
## but backed by a shared total fuel pool rather than discrete charges -
## it runs out when the pool empties, at which point the light dies and
## its ghost-proof safe zone goes with it (see ghost.gd, which only avoids
## this while the light is visible).
##
## User request (Camp v2): it's a snapshot of the safe camp the travellers
## set out from - the campfire, the oil drums that feed it, the tent the
## player has pitched at home (Profile.camp_tent) - rendered from the
## camp's own models (tools/render_props.py: start_camp, camp_tents). The
## fire is its light: burning while the drums have fuel in them, the one
## safe place in the otherworld; drained to 0 it goes out and the camp is
## safe no more; an oil drum carried in from the map lights it again. (No
## 渡石 here: the way out is a rune pillar somewhere on the map.)

const BASE_TOTAL_FUEL := 500.0
const FLAMES := preload("res://assets/models/camp/fire_flames.png")
const SPRITE_SCALE := 0.5
## The fire pit and drums: drawn from VISUAL_AT (their y-sort point, behind
## where the player starts); (center_x, -center_y) * 27.108 for the
## render's camera, moved to suit.
const VISUAL_AT := Vector2(0, -30)
const OFFSET := Vector2(-40.22, -64.75 + 60.0)
## The fire (world px from the camp's origin, at sprite scale 0.5), and the
## tent's spot.
const FLAME := Vector2(0.0, -33.8)
const TENT_AT := Vector2(56.0, -50.0)
## User request (3D: nothing walks into anything): what RunView3D builds
## here and the solids under it are the same - the fire ring (px radius),
## the drums ([spot, yaw, lying]; a drum 0.62 m across, 0.92 m long), and
## the tent at TENT_SCALE, beside the fire with room between.
const FIRE_RADIUS := 17.0
const DRUMS := [[Vector2(-40, -40), 0.3, false], [Vector2(-23, -50), 1.1, false], [Vector2(-30, -17), 0.6, true]]
const DRUM_RADIUS := 8.8
const DRUM_LYING_RADIUS := 12.8
const TENT_SCALE := 0.8
const TENT_GAP := 14.0
const PX := 27.108
## Each tent's sprite offset (render_props.py camp_tents).
const TENT_OFFSETS := {
	1: Vector2(-0.22, -14.62), 2: Vector2(-0.71, -13.85), 3: Vector2(3.02, -21.87),
	4: Vector2(-2.38, -14.98), 5: Vector2(0.12, -13.29), 6: Vector2(2.28, -17.07),
	7: Vector2(0.61, -20.91), 8: Vector2(-1.19, -16.27), 9: Vector2(-0.73, -13.83),
}
const LIGHT_ENERGY := 1.6
const GLOW_COLOR := Color(1.0, 0.62, 0.3, 0.8)

var max_total_fuel: float = BASE_TOTAL_FUEL
var total_fuel: float = BASE_TOTAL_FUEL

@onready var light: PointLight2D = $Light
@onready var charge_label: Label = $ChargeLabel
@onready var visual: Sprite2D = $Visual
@onready var glow: Sprite2D = $Glow

var _time := randf() * 10.0
var _was_lit := true
var _embers: Sprite2D
var _flames: CPUParticles2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("fuel_stations")

	max_total_fuel = BASE_TOTAL_FUEL + Profile.get_upgrade_bonus("fuel_station_charges")
	total_fuel = max_total_fuel

	var tex := CanvasTexture.new()
	visual.texture = tex
	visual.position = VISUAL_AT
	Art.place(visual, OFFSET, SPRITE_SCALE)
	_build_camp()
	light.position = FLAME + Vector2(0, -6)
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.8
	light.color = Color(1.0, 0.62, 0.3)
	light.energy = LIGHT_ENERGY
	light.height = Lantern.LIGHT_HEIGHT
	light.shadow_enabled = true
	LightTwin.attach(light)
	# The fire's own glow: drawn over it, unaffected by the darkness.
	glow.position = light.position
	glow.texture = LightTextureFactory.make_radial_texture(64, 0.5)
	glow.scale = Vector2(0.5, 0.5)
	glow.modulate = GLOW_COLOR
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = add

	_refresh_label()


## The camp round the fire: the embers' glow and the flames over the pit,
## the tent pitched at home behind, and what can't be walked through.
func _build_camp() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_embers = Sprite2D.new()
	_embers.name = "Embers"
	_embers.material = add
	_embers.z_index = 1
	_embers.position = VISUAL_AT
	Art.place(_embers, OFFSET, SPRITE_SCALE)
	add_child(_embers)
	var flame_mat := CanvasItemMaterial.new()
	flame_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flame_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flame_mat.particles_animation = true
	flame_mat.particles_anim_h_frames = 2
	flame_mat.particles_anim_v_frames = 2
	_flames = CPUParticles2D.new()
	_flames.name = "Flames"
	_flames.texture = FLAMES
	_flames.material = flame_mat
	_flames.z_index = 2
	_flames.position = FLAME + Vector2(0, 3)
	_flames.amount = 8
	_flames.lifetime = 0.8
	_flames.preprocess = 1.0
	_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 3.0
	_flames.direction = Vector2.UP
	_flames.spread = 10.0
	_flames.gravity = Vector2(0, -14)
	_flames.initial_velocity_min = 4.0
	_flames.initial_velocity_max = 9.0
	var size := float(FLAMES.get_width()) / 2.0
	_flames.scale_amount_min = 15.0 / size
	_flames.scale_amount_max = 22.0 / size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1, 0.3))
	_flames.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.7, 0.0))
	ramp.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.85, 0.6, 0.85))
	ramp.add_point(0.6, Color(1.0, 0.6, 0.3, 0.6))
	_flames.color_ramp = ramp
	_flames.anim_offset_max = 1.0
	add_child(_flames)
	# The tent pitched at home.
	var n := clampi(Profile.camp_tent, 1, 9)
	var tent := Sprite2D.new()
	tent.name = "Tent"
	var ttex := CanvasTexture.new()
	tent.texture = ttex
	tent.position = tent_spot()
	Art.place(tent, TENT_OFFSETS[n], SPRITE_SCALE)
	add_child(tent)
	# Solid: the drums, the fire pit, the tent - each as big as its model.
	$Drums.position = Vector2.ZERO
	$Drums/CollisionShape2D.queue_free()
	for b in solids_local():
		var part := CollisionShape2D.new()
		if is_equal_approx(b[1].x, b[1].y):
			var circle := CircleShape2D.new()
			circle.radius = b[1].x
			part.shape = circle
		else:
			var rect := RectangleShape2D.new()
			rect.size = b[1] * 2.0
			part.shape = rect
		part.position = b[0]
		$Drums.add_child(part)
	add_to_group("solids")


## The tent's model's base (m: half across x, half across z, centre x, z).
static func _tent_box() -> AABB:
	var m := CampModel.mesh("tent_%d" % clampi(Profile.camp_tent, 1, 9))
	return m.get_aabb() if m != null else AABB(Vector3(-1.75, 0, -2.5), Vector3(3.5, 2.5, 5.0))


## Where the tent stands (px from the camp's origin): its near side
## TENT_GAP past the fire's ring.
static func tent_spot() -> Vector2:
	var box := _tent_box()
	var half := box.size.x * 0.5 * TENT_SCALE * PX
	return Vector2(FLAME.x + FIRE_RADIUS + TENT_GAP + half, TENT_AT.y)


## The solids here, from the camp's origin: [[centre, radii (equal: a
## circle; else a box's half size)], ...].
static func solids_local() -> Array:
	var out := [[FLAME, Vector2(FIRE_RADIUS, FIRE_RADIUS)]]
	for d in DRUMS:
		var r: float = DRUM_LYING_RADIUS if d[2] else DRUM_RADIUS
		out.append([d[0], Vector2(r, r)])
	var box := _tent_box()
	# (turned round, PI: its centre mirrored)
	var c := Vector2(-box.get_center().x, -box.get_center().z) * TENT_SCALE * PX
	out.append([tent_spot() + c, Vector2(box.size.x, box.size.z) * 0.5 * TENT_SCALE * PX])
	return out


## For Solids (the tent's box as the ellipse round it).
func solids() -> Array:
	var out := []
	for b in solids_local():
		var r: Vector2 = b[1]
		out.append([global_position + b[0], r if is_equal_approx(r.x, r.y) else r * 1.41])
	return out


func _process(delta: float) -> void:
	var lit := total_fuel > 0.0
	light.visible = lit
	glow.visible = lit
	_embers.visible = lit
	_flames.emitting = lit
	if lit != _was_lit:
		_was_lit = lit
		GameState.push_message("營火重新燒起來了，營地又安全了" if lit else "油桶的油用完了，營火熄了——營地不再安全（從地圖提油箱回來補）")
		GameState.report("營火又燒起來了" if lit else "營火熄了，營地不再安全", "good" if lit else "warn")
		if not lit:
			Campaign.stat("fire_out")
	if lit:
		# A live fire: a slow waver and a quick flutter.
		_time += delta
		var f := 1.0 + sin(_time * 7.3) * 0.08 + sin(_time * 13.1 + 1.3) * 0.05 + sin(_time * 21.0) * 0.03
		light.energy = LIGHT_ENERGY * f
		glow.scale = Vector2.ONE * 0.5 * (0.95 + (f - 1.0) * 2.0)
		_embers.modulate.a = 0.75 + (f - 1.0) * 2.0


## Tops the lantern up by whatever it's missing, capped by what's left in
## the shared pool - design doc request: no more discrete "charges" you
## either have or don't, just a total that drains by the amount actually
## used and that partial refuels are fine against.
func try_refuel(lantern: Lantern) -> bool:
	if total_fuel <= 0.0:
		return false
	var needed: float = lantern.max_fuel - lantern.fuel
	if needed <= 0.01:
		return false
	var given: float = min(needed, total_fuel)
	lantern.fuel += given
	total_fuel -= given
	_refresh_label()
	return true


## Design doc request: an oil drum is carried here and dumped in rather
## than refilling every station on the map at once - see OilDrum.deliver().
func add_fuel(amount: float) -> float:
	var space: float = max_total_fuel - total_fuel
	var added: float = min(space, amount)
	total_fuel += added
	_refresh_label()
	return added


func _refresh_label() -> void:
	charge_label.text = "營地油桶 %d/%d" % [int(total_fuel), int(max_total_fuel)]


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_fuel_station"):
		body.set_in_fuel_station(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_fuel_station"):
		body.set_in_fuel_station(false, self)
