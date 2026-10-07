extends Node

## Performance on phones (user report: the phone ran hot playing). Autoload
## "Perf".
##
## A phone browser draws at the screen's full pixel density - 3x on an
## iPhone, nine times the pixels of the page's own size - while the art has
## about two texels per screen pixel at 1.5x already, so most of that is
## heat for nothing. The page (export_presets.cfg, html/head_include) caps
## the pixel ratio the engine sees at window.fishockPixelCap; this sets it:
## 2x to start, and if the game can't hold SLOW_FPS it steps down (to
## MIN_CAP at the lowest) - the canvas resizes on the fly. Only ever down,
## within a session, so it can't see-saw.
##
## User report (again: the phone runs hot). Most of a run is standing at
## the water waiting for a bite, and nothing on screen needs 60 frames a
## second then. In a run (on the web) the frame rate drops to CALM_FPS once
## it's been calm for CALM_AFTER s - no finger on the screen, the player
## standing (not walking, casting, fighting, swinging, staggering or held)
## and the camera settled - and is back to full the frame any of that
## changes.

const START_CAP := 2.0
const MIN_CAP := 1.25
const STEP := 0.25
const WINDOW := 4.0
const SLOW_FPS := 50.0
## Time to settle after starting or after a step, before judging again.
const SETTLE := 6.0
## A frame longer than this is a stall (tab switched away, loading), not
## the steady load: the window starts over.
const STALL := 0.25

const CALM_FPS := 30
const CALM_AFTER := 0.6

var cap := START_CAP
var _touches := {}
var _calm := 0.0
var _zoom := 0.0
var _settle := SETTLE
var _time := 0.0
var _frames := 0


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_apply()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
		else:
			_touches.erase(event.index)


func _process(delta: float) -> void:
	_pace(delta)
	if delta > STALL:
		_time = 0.0
		_frames = 0
		return
	if _settle > 0.0:
		_settle -= delta
		return
	_time += delta
	_frames += 1
	if _time < WINDOW:
		return
	var fps := _frames / _time
	_time = 0.0
	_frames = 0
	if fps < SLOW_FPS and cap > MIN_CAP:
		cap = maxf(cap - STEP, MIN_CAP)
		_apply()
		_settle = SETTLE


func _apply() -> void:
	JavaScriptBridge.eval("window.fishockPixelCap = %.2f;" % cap, true)


## The frame rate for what's going on (see CALM_FPS); the camp keeps its own.
func _pace(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		_calm = 0.0
		return
	if is_calm(player):
		_calm += delta
	else:
		_calm = 0.0
	Engine.max_fps = CALM_FPS if _calm >= CALM_AFTER else 0


## Nothing going on that needs every frame.
func is_calm(player: Player) -> bool:
	if not _touches.is_empty() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_anything_pressed():
		return false
	if player.velocity.length() > 1.0 or player.held or player.knocked() or player.swing_left > 0.0:
		return false
	if not player.state in [Player.State.IDLE, Player.State.WAITING]:
		return false
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		var z := cam.zoom.x
		var settled := absf(z - _zoom) < 0.0005
		_zoom = z
		if not settled:
			return false
	return true
