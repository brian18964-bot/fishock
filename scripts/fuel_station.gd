class_name FuelStation
extends Area2D

## The player's spawn point doubles as a limited-use refuel point (moved
## off the altar per design request). A fixed light circle like the
## altar/escape point, but its charge count runs out, at which point the
## light dies and its ghost-proof safe zone goes with it (see ghost.gd,
## which only avoids this while the light is visible).

const BASE_MAX_CHARGES := 5

var max_charges: int = BASE_MAX_CHARGES
var charges_remaining: int = BASE_MAX_CHARGES

@onready var light: PointLight2D = $Light
@onready var charge_label: Label = $ChargeLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("fuel_stations")

	max_charges = BASE_MAX_CHARGES + int(Profile.get_upgrade_bonus("fuel_station_charges"))
	charges_remaining = max_charges

	light.texture = LightTextureFactory.make_radial_texture()
	light.texture_scale = 0.65
	light.color = Color(1.0, 0.75, 0.4)
	light.energy = 1.4
	light.shadow_enabled = true

	_refresh_label()


func _process(_delta: float) -> void:
	light.visible = charges_remaining > 0 and not GameState.is_night


## Refuels to full and spends one charge; refuses if already full (so
## standing there doesn't waste charges) or out of charges.
func try_refuel(lantern: Lantern) -> bool:
	if charges_remaining <= 0:
		return false
	if lantern.fuel >= lantern.max_fuel - 0.01:
		return false
	charges_remaining -= 1
	lantern.fuel = lantern.max_fuel
	_refresh_label()
	return true


## Design doc request: an oil drum can refill every fuel station's charges.
func refill_charges() -> void:
	charges_remaining = max_charges
	_refresh_label()


func _refresh_label() -> void:
	charge_label.text = "煤油站 %d/%d" % [charges_remaining, max_charges]


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_fuel_station"):
		body.set_in_fuel_station(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_fuel_station"):
		body.set_in_fuel_station(false, self)
