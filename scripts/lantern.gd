class_name Lantern
extends PointLight2D

## The light the player carries (design doc §2.1). Brightness trades light
## reach for what it burns. `[` / `]` step brightness.
##
## User request: two tools.
## - The oil lamp (煤燈), what every run starts with: a wide, umbrella-shaped
##   spread of warm light in front of the player (plus a little glow at their
##   feet), shorter reach. Burns fuel, refilled only at a fuel station (see
##   fuel_station.gd).
## - The flashlight (手電筒), bought once in the shop: the long, narrow cone.
##   Runs on batteries - also bought in the shop - and a flat one is swapped
##   anywhere on the map (hold L), no trip back to a station.
## K switches between them once the flashlight is owned.

enum Tool { LAMP, FLASHLIGHT }

const MAX_FUEL := 100.0
## User feedback: lights last 40% longer (was 7 fuel/s at full brightness).
const DRAIN_RATE := 5.0
const MIN_BRIGHTNESS := 0.35
const MAX_BRIGHTNESS := 1.0
const BRIGHTNESS_STEP := 0.5

## Per tool: spread (half angle, deg - must match the texture), reach
## (texture_scale range), colour and energy range.
const TOOLS := {
	Tool.LAMP: {"half_angle": 80.0, "min_scale": 0.85, "max_scale": 1.6,
		"color": Color(1.0, 0.8, 0.52), "energy": Vector2(0.8, 1.25)},
	Tool.FLASHLIGHT: {"half_angle": 24.0, "min_scale": 1.3, "max_scale": 3.0,
		"color": Color(0.92, 0.96, 1.0), "energy": Vector2(0.9, 1.45)},
}

## Flashlight: a full battery lasts BATTERY_LIFE s at full brightness;
## holding L on a flat one swaps in a fresh battery over BATTERY_SWAP_DURATION.
const BATTERY_LIFE := 126.0
const BATTERY_SWAP_DURATION := 1.0

## Design doc request: the flame can be put out at will (instant, e.g. to
## stop burning fuel or to go dark near a ghost) but relighting takes a
## short held progress bar, so the player is committing to being lit again
## rather than it happening for free. (The flashlight just clicks on.)
const RELIGHT_DURATION := 1.2

## Normal-map light height in px (also used by the other lamps).
const LIGHT_HEIGHT := 60.0

## The light textures are TEXTURE_HALF_SIZE px in radius before scaling;
## illuminates() re-derives the lit shape from this and the tool's angle
## instead of reading pixels back out of the texture.
const TEXTURE_HALF_SIZE := 128.0

## Design doc §2.3: strong-light skill. Shorter reach than the ambient
## light, and only lands on a ghost that's both in range and lit. Paid
## for from whichever tool is out.
const FLASH_RANGE := 160.0
const FLASH_FUEL_COST := 25.0
const FLASH_CHARGE_COST := 20.0
const FLASH_COOLDOWN := 3.0
const FLASH_STUN_DURATION := 1.75

static var _lamp_texture: ImageTexture
static var _flashlight_texture: ImageTexture

## Base values plus Profile upgrade bonuses (design doc §9.1), computed once
## at _ready() since upgrades only change between runs, not mid-run.
var max_fuel: float = MAX_FUEL
var flash_cooldown_max: float = FLASH_COOLDOWN

var tool: Tool = Tool.LAMP
var fuel: float = MAX_FUEL
## Flashlight battery, 0-100 (a fresh one goes in when first switched to).
var charge: float = 0.0
var brightness: float = 0.75
var flash_cooldown: float = 0.0

var lit: bool = true
var relight_progress: float = 0.0

signal relight_progress_updated(progress: float)

var _flash_held: bool = false
var _light_key_held: bool = false
var _switch_key_held: bool = false

@onready var _player: Node2D = get_parent()


func _ready() -> void:
	if _lamp_texture == null:
		_lamp_texture = LightTextureFactory.make_fan_texture(256, TOOLS[Tool.LAMP].half_angle, 30.0)
		_flashlight_texture = LightTextureFactory.make_cone_texture(256, TOOLS[Tool.FLASHLIGHT].half_angle, 8.0)
	shadow_enabled = true
	# User decision: held up off the ground, so upward-facing surfaces
	# (dock boards, plants, rock tops) catch the light, not just the sides.
	height = LIGHT_HEIGHT
	_apply_tool()
	LightTwin.attach(self)

	max_fuel = MAX_FUEL + Profile.get_upgrade_bonus("fuel_capacity")
	flash_cooldown_max = max(FLASH_COOLDOWN - Profile.get_upgrade_bonus("flash_cooldown"), 1.0)
	fuel = max_fuel


func _process(delta: float) -> void:
	_handle_tool_switch()
	_handle_brightness_input(delta)
	_handle_flash_input(delta)
	_handle_light_toggle(delta)

	if lit:
		var burn := brightness * (1.0 + boost)  # charging burns faster
		if tool == Tool.LAMP:
			fuel = max(fuel - DRAIN_RATE * burn * delta, 0.0)
		else:
			charge = max(charge - 100.0 / BATTERY_LIFE * burn * delta, 0.0)
		if power() <= 0.0:
			lit = false
			GameState.push_message("煤燈的油燒完了" if tool == Tool.LAMP else "手電筒沒電了，按住 L 換電池")

	visible = lit and power() > 0.0
	rotation = _player.aim_dir.angle()
	var spec: Dictionary = TOOLS[tool]
	# User request: as the day darkens (GameState.light_stage()) the same
	# setting reaches less far and less bright - late on you must turn it up
	# to see what the lowest setting showed at first.
	var stage := GameState.light_stage()
	_stage_reach = lerpf(_stage_reach, STAGE_REACH[stage], minf(1.0, delta))
	_stage_power = lerpf(_stage_power, STAGE_POWER[stage], minf(1.0, delta))
	texture_scale = lerp(spec.min_scale, spec.max_scale, brightness) * _stage_reach * (1.0 + BOOST_REACH * boost)
	energy = lerp(spec.energy.x, spec.energy.y, brightness) * _stage_power * (1.0 + BOOST_POWER * boost)
	if tool == Tool.LAMP:
		energy *= _flame(delta)


## User request: holding the aimed light charges it up (Player's light
## skill) - brighter and reaching further as `boost` goes 0 -> 1 - and the
## flash on letting go is stronger for it: longer reach and a longer stun.
const BOOST_REACH := 0.3
const BOOST_POWER := 1.0
const BOOST_FLASH_RANGE := 0.6
const BOOST_STUN := 0.8
var boost := 0.0

const STAGE_REACH := [1.0, 0.9, 0.8, 0.7]
const STAGE_POWER := [1.0, 0.85, 0.72, 0.62]
var _stage_reach := 1.0
var _stage_power := 1.0

## User request: a flame isn't a steady bulb - a faint constant waver, and
## every few seconds a brief dip before it catches again.
const FLICKER_GAP := Vector2(1.5, 4.0)
const FLICKER_DIP := Vector2(0.12, 0.25)
const FLICKER_TIME := Vector2(0.08, 0.3)

var _flame_time := 0.0
var _flicker_timer := 2.0
var _dip_left := 0.0
var _dip_depth := 0.0
var _dip := 0.0


func _flame(delta: float) -> float:
	_flame_time += delta
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = randf_range(FLICKER_GAP.x, FLICKER_GAP.y)
		_dip_left = randf_range(FLICKER_TIME.x, FLICKER_TIME.y)
		_dip_depth = randf_range(FLICKER_DIP.x, FLICKER_DIP.y)
	var target := 0.0
	if _dip_left > 0.0:
		_dip_left -= delta
		target = _dip_depth
	_dip = move_toward(_dip, target, delta * 3.0)
	return 1.0 + sin(_flame_time * 9.3) * 0.015 + sin(_flame_time * 23.7) * 0.01 - _dip


## What the current tool has left: lamp fuel, or flashlight charge.
func power() -> float:
	return fuel if tool == Tool.LAMP else charge


func tool_name() -> String:
	return "煤燈" if tool == Tool.LAMP else "手電筒"


func _apply_tool() -> void:
	texture = _lamp_texture if tool == Tool.LAMP else _flashlight_texture
	color = TOOLS[tool].color


func _handle_tool_switch() -> void:
	var held := Input.is_key_pressed(KEY_K)
	var just_pressed := held and not _switch_key_held
	_switch_key_held = held
	if not just_pressed:
		return
	switch_tool(Tool.FLASHLIGHT if tool == Tool.LAMP else Tool.LAMP)


## User request: also picked straight from the backpack (Backpack).
func switch_tool(to: Tool) -> void:
	if to == tool:
		return
	if to == Tool.FLASHLIGHT and not Profile.has_flashlight:
		GameState.push_message("還沒有手電筒，可以在商店購買")
		return
	tool = to
	relight_progress = 0.0
	if tool == Tool.FLASHLIGHT and charge <= 0.0 and Profile.use_battery():
		charge = 100.0
	_apply_tool()
	lit = power() > 0.0
	if tool == Tool.LAMP:
		GameState.push_message("換回煤燈")
	elif charge > 0.0:
		GameState.push_message("換成手電筒（電量 %d%%，備用電池 %d）" % [int(charge), Profile.batteries])
	else:
		GameState.push_message("換成手電筒，但沒有電池了")


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


## Out at once (L, or on a phone a tap on the lamp button or its
## brightness slider pulled right down - see TouchControls).
func put_out() -> void:
	if not lit:
		return
	lit = false
	relight_progress = 0.0
	GameState.push_message("熄滅了%s" % tool_name())


## Design doc request: L puts the light out instantly (free, deliberate
## control), but relighting needs a held progress bar - meant to read as
## the player confirming it's safe to be lit again. The flashlight clicks
## on at once; flat, holding L swaps in a battery.
func _handle_light_toggle(delta: float) -> void:
	var held := Input.is_key_pressed(KEY_L)
	var just_pressed := held and not _light_key_held
	_light_key_held = held

	if lit:
		if just_pressed:
			put_out()
	elif tool == Tool.FLASHLIGHT:
		if charge > 0.0:
			if just_pressed:
				lit = true
				GameState.push_message("打開了手電筒")
		elif held:
			if Profile.batteries <= 0:
				if just_pressed:
					GameState.push_message("沒有電池了，到商店買電池")
				relight_progress = 0.0
			else:
				relight_progress += delta / BATTERY_SWAP_DURATION
				if relight_progress >= 1.0 and Profile.use_battery():
					relight_progress = 0.0
					charge = 100.0
					lit = true
					GameState.push_message("換上新電池（還剩 %d 顆）" % Profile.batteries)
		else:
			relight_progress = 0.0
	elif held:
		if fuel <= 0.0:
			if just_pressed:
				GameState.push_message("燃油用完了，得先加油才能點燃")
			relight_progress = 0.0
		else:
			relight_progress += delta / RELIGHT_DURATION
			if relight_progress >= 1.0:
				relight_progress = 0.0
				lit = true
				GameState.push_message("煤燈點燃了")
	else:
		relight_progress = 0.0

	relight_progress_updated.emit(relight_progress)


## The ghost nearest the player within the flash's reach, if any.
func nearest_ghost() -> Node2D:
	var best: Node2D = null
	var best_d := FLASH_RANGE
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		var d := global_position.distance_to(ghost.global_position)
		if d <= best_d:
			best_d = d
			best = ghost
	return best


## User request: letting go of the aimed light (Player._update_light_skill)
## flashes it - if there's a ghost in the light to flash. The charge built
## up (`boost`) makes it reach further and hold them longer.
func release_flash() -> void:
	var charged := boost
	boost = 0.0
	rotation = _player.aim_dir.angle()
	if not lit or power() <= 0.0:
		return
	var reach := FLASH_RANGE * (1.0 + BOOST_FLASH_RANGE * charged)
	var target := false
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if _flash_hits(ghost, reach):
			target = true
	if not target:
		return
	if flash_cooldown > 0.0:
		GameState.push_message("強光還在冷卻（%.0f 秒）" % ceilf(flash_cooldown))
		return
	_try_flash(reach, FLASH_STUN_DURATION * (1.0 + BOOST_STUN * charged))


## In the flash: within `reach` and in the light - its feet or its body (the
## big ghost stands tall, its middle well above its feet).
func _flash_hits(ghost: Node2D, reach: float) -> bool:
	for p in [ghost.global_position, ghost.global_position + Vector2(0, -22)]:
		if global_position.distance_to(p) <= reach and _in_beam(p, reach):
			return true
	return false


## In the beam's angle, and within `reach` even past the light's glow.
func _in_beam(point: Vector2, reach: float) -> bool:
	if not visible:
		return false
	var offset := point - global_position
	if offset.length() > maxf(reach, TEXTURE_HALF_SIZE * texture_scale):
		return false
	return absf(wrapf(offset.angle() - rotation, -PI, PI)) <= deg_to_rad(TOOLS[tool].half_angle)


func _try_flash(reach: float = FLASH_RANGE, stun: float = FLASH_STUN_DURATION) -> void:
	if tool == Tool.LAMP:
		if fuel < FLASH_FUEL_COST:
			GameState.push_message("燃油不足，無法使用強光")
			return
		fuel -= FLASH_FUEL_COST
	else:
		if charge < FLASH_CHARGE_COST:
			GameState.push_message("電量不足，無法使用強光")
			return
		charge -= FLASH_CHARGE_COST

	flash_cooldown = flash_cooldown_max

	var hit_any := false
	var hit_big := false
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if _flash_hits(ghost, reach):
			ghost.stun(stun)
			hit_any = true
			hit_big = hit_big or ghost is BigGhost

	# Wolves and meat-eating dinosaurs (see Critter) bolt from the flash.
	var scared_any := false
	for hunter in get_tree().get_nodes_in_group("hunters"):
		if hunter.visible and global_position.distance_to(hunter.global_position) <= FLASH_RANGE \
				and illuminates(hunter.global_position):
			hunter.scare()
			scared_any = true

	if hit_big:
		GameState.push_message("強光把大鬼定住了！趁現在快跑")
	elif hit_any:
		GameState.push_message("強光把鬼定住了！")
	elif scared_any:
		GameState.push_message("強光把野獸嚇跑了！")
	else:
		GameState.push_message("強光沒有照到任何鬼")


## True if `point` currently falls inside the lit area (design doc §3.1:
## light aimed at the ghost gives the player away). Used by ghost
## perception and by the strong-light skill.
func illuminates(point: Vector2) -> bool:
	if not visible:
		return false
	var offset := point - global_position
	var dist := offset.length()
	var effective_radius := TEXTURE_HALF_SIZE * texture_scale
	if dist > effective_radius:
		return false
	var relative_angle: float = abs(wrapf(offset.angle() - rotation, -PI, PI))
	return relative_angle <= deg_to_rad(TOOLS[tool].half_angle)
