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

var cap := START_CAP
var _settle := SETTLE
var _time := 0.0
var _frames := 0


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_apply()


func _process(delta: float) -> void:
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
