class_name AudioDirector
extends Node

## User request: sound. Listens to the game and plays it through Sfx: the
## cast, the float going in, nibbles and bites, the reel's ratchet while
## reeling (and the line creaking when it's tight), the fish leaping,
## flicks, catches and snapped lines; footsteps (wood on docks, crunching
## on snow); the lamp lighting and going out, the strong light; the big
## ghost's chain wherever it walks and a heartbeat when it's close on your
## heels; floating ghosts' whispers, the water ghost, the cage, offerings,
## thunder in a storm. Beds: each map style's ambience (wind on snow, frogs
## in the swamp, birds in the jungle...), water lapping as you near a pond,
## rain in a storm; quiet music by day, the hunt's music at night.

const STEP_INTERVAL := 0.34
## ghost.gd GhostState.HAUNT.
const HAUNT := 1
const HEART_RANGE := 280.0
const WATER_HEAR := 160.0
const THUNDER_GAP := Vector2(9.0, 22.0)
const THEME_AMBIENCE := {"snow": "amb_wind", "swamp": "amb_swamp", "jungle": "amb_jungle",
	"prehistoric": "amb_jungle", "tropical": "amb_jungle"}

var _player: Player
var _lantern: Lantern
var _big: Node2D
var _chain: AudioStreamPlayer2D
var _theme := ""
var _step_timer := 0.0
var _was_lit := true
var _flash_cd := 0.0
var _thunder_timer := 0.0
var _plop_timer := -1.0
var _plop_at := Vector2.ZERO
var _quota := 0.0
var _ghost_states := {}


func _ready() -> void:
	var main := get_parent()
	_player = main.get_node("Player")
	_lantern = _player.get_node("Lantern")
	_big = main.get_node_or_null("BigGhost")
	var gen := main.get_node_or_null("MapGenerator")
	if gen != null:
		_theme = gen.theme_name
	_player.cast_started.connect(_on_cast)
	_player.nibble.connect(func(_fake): Sfx.play_at("nibble", _bobber(), -4.0))
	_player.bite_started.connect(func(): Sfx.play_at("splash_small", _bobber(), -2.0))
	_player.hook_success.connect(_on_hooked)
	_player.fight_event.connect(_on_fight_event)
	_player.catch_success.connect(func(_fish): Sfx.play("catch", -4.0, 0.0); Sfx.play("flop", -6.0))
	_player.catch_failed.connect(_on_failed)
	GameState.night_fell.connect(_on_night)
	GameState.weather_changed.connect(_on_weather)
	GameState.quota_updated.connect(_on_quota)
	GameState.run_ended.connect(_on_run_ended)
	if _big != null:
		_chain = AudioStreamPlayer2D.new()
		_chain.stream = Sfx.stream("chain_loop")
		_chain.max_distance = 520.0
		_chain.attenuation = 1.4
		_chain.volume_db = -6.0
		_big.add_child(_chain)
		_big.mode_changed.connect(_on_big_mode)
	_was_lit = _lantern.lit
	_bed_for_time()
	_on_weather(GameState.Weather.keys()[GameState.weather])


func _bobber() -> Vector2:
	return get_parent().get_node("Bobber").global_position


func _bed_for_time() -> void:
	if GameState.is_night:
		Sfx.ambience("amb_wind" if _theme == "snow" else "amb_night")
		Sfx.music("music_night")
	else:
		Sfx.ambience(THEME_AMBIENCE.get(_theme, "amb_day"))
		Sfx.music("music_day")


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_update_fishing_loops()
	_update_steps(delta)
	_update_lamp(delta)
	_update_threats()
	_update_ghost_whispers()
	var near := _player._nearest_water_edge_distance()
	Sfx.loop("amb_water", near < WATER_HEAR, lerpf(-6.0, -24.0, clampf(near / WATER_HEAR, 0.0, 1.0)))
	if _plop_timer >= 0.0:
		_plop_timer -= delta
		if _plop_timer < 0.0:
			Sfx.play_at("plop", _plop_at)
	if GameState.weather == GameState.Weather.STORM:
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = randf_range(THUNDER_GAP.x, THUNDER_GAP.y)
			Sfx.play("thunder", -6.0, 0.1)


func _update_fishing_loops() -> void:
	var reeling := _player.state == Player.State.REELING and _player._is_action_pressed()
	var retrieving := _player.state == Player.State.WAITING and _player.fishing_mode == Player.FishingMode.LURE \
		and _player._is_action_pressed()
	Sfx.loop("reel_loop", reeling or retrieving, -8.0)
	var tight := _player.state == Player.State.REELING and _player.fight != null and _player.fight.tension > 0.72
	Sfx.loop("creak_loop", tight, -6.0)


func _update_steps(delta: float) -> void:
	var speed := _player.velocity.length()
	if speed < 12.0 or _player.held:
		_step_timer = 0.0
		return
	_step_timer -= delta * clampf(speed / 90.0, 0.6, 1.6)
	if _step_timer > 0.0:
		return
	_step_timer = STEP_INTERVAL
	var feet := _player.global_position + Player.FEET
	var kind := "step_soft"
	if Dock.on_walkway(get_tree(), feet):
		kind = "step_wood"
	elif _theme == "snow":
		kind = "step_snow"
	elif _theme in ["rocky", "stone_forest", "deadwood"]:
		kind = "step_hard"
	Sfx.play(kind, -10.0, 0.12)


func _update_lamp(delta: float) -> void:
	if _lantern.lit != _was_lit:
		_was_lit = _lantern.lit
		Sfx.play("ignite" if _lantern.lit else "extinguish", -6.0)
	# The strong light: its cooldown jumps back to full when it fires.
	if _lantern.flash_cooldown > _flash_cd + 0.5:
		Sfx.play("flash", -3.0, 0.02)
	_flash_cd = _lantern.flash_cooldown


func _update_threats() -> void:
	if _big == null:
		return
	var roaming: bool = _big.visible and _big.mode not in [BigGhost.Mode.ASLEEP, BigGhost.Mode.CAGED]
	if roaming and not _chain.playing:
		_chain.play()
	elif not roaming and _chain.playing:
		_chain.stop()
	var d := _big.global_position.distance_to(_player.global_position)
	var hunting: bool = _big.mode in [BigGhost.Mode.CHASE, BigGhost.Mode.SUSPICIOUS, BigGhost.Mode.CARRY]
	var close := hunting and d < HEART_RANGE
	Sfx.loop("heartbeat_loop", close, lerpf(0.0, -14.0, clampf(d / HEART_RANGE, 0.0, 1.0)))


func _update_ghost_whispers() -> void:
	# A floating ghost moving in to haunt the player whispers.
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if not ("ghost_state" in ghost):
			continue
		var s: int = ghost.ghost_state
		if _ghost_states.get(ghost, s) != s and s == HAUNT:
			Sfx.play_at("whisper", ghost.global_position, -4.0, 0.15)
		_ghost_states[ghost] = s


func _on_cast(target: Vector2, _tier: String) -> void:
	Sfx.play("cast", -4.0)
	_plop_timer = 0.42
	_plop_at = target


func _on_hooked() -> void:
	if _player.fight != null and _player.fight.perfect:
		Sfx.play("perfect", -3.0, 0.0)
	Sfx.play_at("splash_small", _bobber(), -3.0)


func _on_fight_event(kind: String) -> void:
	match kind:
		"jump":
			Sfx.play_at("splash", _bobber())
		"dive", "run":
			Sfx.play_at("splash_small", _bobber(), -6.0)
		"swipe_hit":
			Sfx.play("swipe_hit", -2.0)
		"enrage":
			Sfx.play_at("splash", _bobber(), 2.0, 0.0)


func _on_failed(reason: String) -> void:
	match reason:
		"line_break", "cover", "line_cut":
			Sfx.play("snap", -2.0)
		"shook_off":
			Sfx.play_at("splash", _bobber(), -2.0)
		"walked_off":
			Sfx.play("tap", -6.0)
		_:
			Sfx.play("fail", -8.0)


func _on_big_mode(mode: String) -> void:
	match mode:
		"CHASE":
			Sfx.play_at("moan", _big.global_position, 0.0, 0.1)
		"CARRY":
			Sfx.play("moan", -2.0, 0.05)
		"CAGED":
			Sfx.play_at("cage", _big.global_position)


func _on_night() -> void:
	_bed_for_time()
	Sfx.play("moan", -2.0, 0.0)


func _on_weather(weather: String) -> void:
	var storm := weather == "STORM"
	Sfx.loop("amb_rain", storm, -8.0)
	if storm:
		_thunder_timer = randf_range(2.0, 6.0)


func _on_quota(progress: float, _target: float) -> void:
	if progress > _quota + 0.01:
		var altar := get_parent().get_node_or_null("Altar")
		if altar != null:
			Sfx.play_at("offering", altar.global_position, 0.0, 0.0)
	_quota = progress


func _on_run_ended(success: bool, _message: String) -> void:
	Sfx.stop_all()
	Sfx.play("escape" if success else "cage", -2.0, 0.0)


func _exit_tree() -> void:
	# A new run (scene reload) starts its own beds.
	for name in ["reel_loop", "creak_loop", "heartbeat_loop", "amb_water", "amb_rain"]:
		Sfx.loop(name, false)
