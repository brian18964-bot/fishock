class_name FuelStation
extends Area2D

## The player's spawn point doubles as a refuel point (moved off the altar
## per design request). A fixed light circle like the altar/escape point,
## but backed by a shared total fuel pool rather than discrete charges -
## it runs out when the pool empties, at which point the light dies and
## its ghost-proof safe zone goes with it (see ghost.gd, which only avoids
## this while the light is visible).

const BASE_TOTAL_FUEL := 500.0

var max_total_fuel: float = BASE_TOTAL_FUEL
var total_fuel: float = BASE_TOTAL_FUEL

@onready var light: PointLight2D = $Light
@onready var charge_label: Label = $ChargeLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("fuel_stations")

	max_total_fuel = BASE_TOTAL_FUEL + Profile.get_upgrade_bonus("fuel_station_charges")
	total_fuel = max_total_fuel

	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.65
	light.color = Color(1.0, 0.75, 0.4)
	light.energy = 1.4
	light.height = Lantern.LIGHT_HEIGHT
	light.shadow_enabled = true
	LightTwin.attach(light)

	_refresh_label()


func _process(_delta: float) -> void:
	light.visible = total_fuel > 0.0 and not GameState.is_night


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
