class_name FuelStation
extends Area2D

## The player's spawn point doubles as a refuel point (moved off the altar
## per design request). A fixed light circle like the altar/escape point,
## but backed by a shared total fuel pool rather than discrete charges -
## it runs out when the pool empties, at which point the light dies and
## its ghost-proof safe zone goes with it (see ghost.gd, which only avoids
## this while the light is visible).
##
## User request: it's drawn as a cluster of oil drums with a kerosene lamp on
## top (tools/render_props.py), and that lamp is its light: lit while the
## station has fuel in it, day or night - the beacon that shows where a
## refuel and the ghost-proof safe spot still are. Drained to 0 it goes
## dark; an oil drum carried in from the map lights it again.

const BASE_TOTAL_FUEL := 500.0
const SHEET := [preload("res://assets/sprites/fuel_station/fuel_station_55deg_albedo.png"),
	preload("res://assets/sprites/fuel_station/fuel_station_55deg_normal.png")]
const SPRITE_SCALE := 0.5
## (center_x, -center_y) * 27.108 for the render's camera (render_props.py).
const OFFSET := Vector2(-0.42, -10.43)
## The lamp's flame, world px from the drums' origin (render_props.py).
const FLAME := Vector2(0.0, -21.06)
const LIGHT_ENERGY := 1.4
const GLOW_COLOR := Color(1.0, 0.72, 0.35, 0.85)

var max_total_fuel: float = BASE_TOTAL_FUEL
var total_fuel: float = BASE_TOTAL_FUEL

@onready var light: PointLight2D = $Light
@onready var charge_label: Label = $ChargeLabel
@onready var visual: Sprite2D = $Visual
@onready var glow: Sprite2D = $Glow

var _time := randf() * 10.0
var _was_lit := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("fuel_stations")

	max_total_fuel = BASE_TOTAL_FUEL + Profile.get_upgrade_bonus("fuel_station_charges")
	total_fuel = max_total_fuel

	var tex := CanvasTexture.new()
	tex.diffuse_texture = SHEET[0]
	tex.normal_texture = SHEET[1]
	visual.texture = tex
	Art.place(visual, OFFSET, SPRITE_SCALE)
	light.position = visual.position + FLAME
	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.65
	light.color = Color(1.0, 0.75, 0.4)
	light.energy = LIGHT_ENERGY
	light.height = Lantern.LIGHT_HEIGHT
	light.shadow_enabled = true
	LightTwin.attach(light)
	# The flame's own glow: drawn over the lamp, unaffected by the darkness.
	glow.position = light.position
	glow.texture = LightTextureFactory.make_radial_texture(64, 0.5)
	glow.scale = Vector2(0.4, 0.4)
	glow.modulate = GLOW_COLOR
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = add

	_refresh_label()


func _process(delta: float) -> void:
	var lit := total_fuel > 0.0
	light.visible = lit
	glow.visible = lit
	if lit != _was_lit:
		_was_lit = lit
		GameState.push_message("煤油站的油燈重新亮起來了" if lit else "煤油站的油用完了，油燈熄了（從地圖提油箱回來補）")
	if lit:
		# A live flame: a slow waver and a quick flutter.
		_time += delta
		var f := 1.0 + sin(_time * 7.3) * 0.05 + sin(_time * 19.1) * 0.03
		light.energy = LIGHT_ENERGY * f
		glow.scale = Vector2.ONE * 0.4 * (0.95 + (f - 1.0) * 2.0)


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
	charge_label.text = "煤油站 %d/%d" % [int(total_fuel), int(max_total_fuel)]


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_fuel_station"):
		body.set_in_fuel_station(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_fuel_station"):
		body.set_in_fuel_station(false, self)
