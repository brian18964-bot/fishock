class_name Lantern
extends PointLight2D

## Directional lantern (design doc §2.1). Brightness trades light reach for
## fuel burn. Refueling is a limited-use action at a fuel station (see
## fuel_station.gd) now, not a passive drip while standing anywhere -
## the altar is sacrifice-only. `[` / `]` are desktop placeholders for a
## future HUD brightness control.

const MAX_FUEL := 100.0
const DRAIN_RATE := 7.0
const MIN_BRIGHTNESS := 0.35
const MAX_BRIGHTNESS := 1.0
const BRIGHTNESS_STEP := 0.5
const MIN_SCALE := 1.1
const MAX_SCALE := 2.6

# Must match LightTextureFactory.make_cone_texture()'s defaults below, since
# illuminates() re-derives the cone's world-space shape from these instead
# of reading pixels back out of the generated texture.
const CONE_HALF_ANGLE_DEG := 32.0
const TEXTURE_HALF_SIZE := 128.0

## Design doc §2.3: strong-light skill. Shorter reach than the ambient
## cone, and only lands on a ghost that's both in range and lit.
const FLASH_RANGE := 160.0
const FLASH_FUEL_COST := 25.0
const FLASH_COOLDOWN := 3.0
const FLASH_STUN_DURATION := 1.75

## Base values plus Profile upgrade bonuses (design doc §9.1), computed once
## at _ready() since upgrades only change between runs, not mid-run.
var max_fuel: float = MAX_FUEL
var flash_cooldown_max: float = FLASH_COOLDOWN

var fuel: float = MAX_FUEL
var brightness: float = 0.75
var flash_cooldown: float = 0.0

var _flash_held: bool = false

@onready var _player: Node2D = get_parent()


func _ready() -> void:
	texture = LightTextureFactory.make_cone_texture()
	color = Color(1.0, 0.92, 0.75)
	shadow_enabled = true

	max_fuel = MAX_FUEL + Profile.get_upgrade_bonus("fuel_capacity")
	flash_cooldown_max = max(FLASH_COOLDOWN - Profile.get_upgrade_bonus("flash_cooldown"), 1.0)
	fuel = max_fuel


func _process(delta: float) -> void:
	_handle_brightness_input(delta)
	_handle_flash_input(delta)

	fuel = max(fuel - DRAIN_RATE * brightness * delta, 0.0)

	var out_of_fuel := fuel <= 0.0
	visible = not out_of_fuel
	rotation = _player.aim_dir.angle()
	texture_scale = lerp(MIN_SCALE, MAX_SCALE, brightness)
	energy = lerp(0.7, 1.3, brightness)


func _handle_brightness_input(delta: float) -> void:
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		brightness = clamp(brightness - BRIGHTNESS_STEP * delta, MIN_BRIGHTNESS, MAX_BRIGHTNESS)
	elif Input.is_key_pressed(KEY_BRACKETRIGHT):
		brightness = clamp(brightness + BRIGHTNESS_STEP * delta, MIN_BRIGHTNESS, MAX_BRIGHTNESS)


func _handle_flash_input(delta: float) -> void:
	flash_cooldown = max(flash_cooldown - delta, 0.0)
	var held := Input.is_key_pressed(KEY_F)
	var just_pressed := held and not _flash_held
	_flash_held = held
	if just_pressed and flash_cooldown <= 0.0:
		_try_flash()


func _try_flash() -> void:
	if fuel < FLASH_FUEL_COST:
		GameState.push_message("燃油不足，無法使用強光")
		return

	flash_cooldown = flash_cooldown_max
	fuel -= FLASH_FUEL_COST

	var hit_any := false
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if global_position.distance_to(ghost.global_position) <= FLASH_RANGE and illuminates(ghost.global_position):
			ghost.stun(FLASH_STUN_DURATION)
			hit_any = true

	if hit_any:
		GameState.push_message("強光把鬼定住了！")
	else:
		GameState.push_message("強光沒有照到任何鬼")


## True if `point` currently falls inside this cone (design doc §3.1: light
## aimed at the ghost gives the player away). Used by ghost perception and,
## later, by the strong-light skill.
func illuminates(point: Vector2) -> bool:
	if not visible:
		return false
	var offset := point - global_position
	var dist := offset.length()
	var effective_radius := TEXTURE_HALF_SIZE * texture_scale
	if dist > effective_radius:
		return false
	var relative_angle: float = abs(wrapf(offset.angle() - rotation, -PI, PI))
	return relative_angle <= deg_to_rad(CONE_HALF_ANGLE_DEG)
