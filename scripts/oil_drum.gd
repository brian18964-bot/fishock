class_name OilDrum
extends Area2D

## Design doc request: a world pickup that refills every fuel station's
## charges at once. One-time use, then relocates elsewhere after a delay -
## same relocate pattern as Hotspot.

const RESPAWN_DELAY := 45.0
const MARGIN := 150.0

var active: bool = true

var _respawn_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_relocate()


func _process(delta: float) -> void:
	visible = active
	if not active:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_relocate()


func use() -> void:
	if not active:
		return
	active = false
	_respawn_timer = RESPAWN_DELAY

	var refilled := 0
	for station in get_tree().get_nodes_in_group("fuel_stations"):
		station.refill_charges()
		refilled += 1

	if refilled > 0:
		GameState.push_message("油桶補滿了地圖上所有煤油站的次數！")
	else:
		GameState.push_message("油桶用掉了，但附近沒有煤油站")


func _relocate() -> void:
	global_position = Vector2(
		randf_range(MARGIN, Player.WORLD_WIDTH - MARGIN),
		randf_range(MARGIN, Player.WORLD_HEIGHT - MARGIN)
	)
	active = true


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_oil_drum"):
		body.set_in_oil_drum(true, self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_oil_drum"):
		body.set_in_oil_drum(false, self)
