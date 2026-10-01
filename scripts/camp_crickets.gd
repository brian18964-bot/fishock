class_name CampCrickets
extends AudioStreamPlayer

## User feedback: the camp's crickets were too loud and too steady. They
## sing softly now (well under the fire and the lake), swelling and easing
## a little; now and then they hush, fading away until they can't be heard,
## and after a while strike up again all at once - as crickets do.

const SOUND := "camp_crickets_loop"
const LEVEL_DB := -23.0
## The slow swell either side of LEVEL_DB.
const SWELL_DB := 2.5
const SILENT_DB := -60.0
## How long they sing between hushes, how long the hush takes to fall
## away, how long it lasts, and how quickly they come back.
const SING := Vector2(18.0, 50.0)
const FALL := Vector2(2.5, 6.0)
const HUSH := Vector2(4.0, 14.0)
const RISE := Vector2(0.15, 0.5)

enum State { SING, FALL, HUSH, RISE }

var state := State.SING
var _left := 0.0
var _span := 1.0
var _from := LEVEL_DB
var _t := 0.0


func _ready() -> void:
	stream = Sfx.stream(SOUND)
	volume_db = SILENT_DB
	if stream == null:
		return
	play(randf() * stream.get_length())
	# They're already singing when the camp comes up: in quickly.
	_enter(State.RISE, 1.5)


## The level they're aiming at while singing: a slow, uneven swell.
func singing_db() -> float:
	return LEVEL_DB + SWELL_DB * (0.6 * sin(_t * 0.31) + 0.4 * sin(_t * 0.83 + 1.7))


func _enter(s: State, span := -1.0) -> void:
	state = s
	_from = volume_db
	var r: Vector2 = {State.SING: SING, State.FALL: FALL, State.HUSH: HUSH, State.RISE: RISE}[s]
	_span = span if span > 0.0 else randf_range(r.x, r.y)
	_left = _span


func _process(delta: float) -> void:
	if stream == null:
		return
	_t += delta
	_left -= delta
	var k := clampf(1.0 - _left / _span, 0.0, 1.0)
	match state:
		State.SING:
			volume_db = singing_db()
			if _left <= 0.0:
				_enter(State.FALL)
		State.FALL:
			# Thinning out: quick at first, then trailing away to nothing.
			volume_db = lerpf(_from, SILENT_DB, 1.0 - pow(1.0 - k, 2.0))
			if _left <= 0.0:
				_enter(State.HUSH)
		State.HUSH:
			volume_db = SILENT_DB
			if _left <= 0.0:
				_enter(State.RISE)
		State.RISE:
			volume_db = lerpf(_from, singing_db(), k)
			if _left <= 0.0:
				_enter(State.SING)
