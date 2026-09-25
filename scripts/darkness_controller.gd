extends CanvasModulate

## Design doc request: day should read as hazy/foggy, not pitch black; only
## night collapses visibility down to near-nothing outside the lantern.
## User feedback: a fog weather event darkens things further on top of that.

## User feedback: the day read murky and grey - lighter and nearly neutral
## now (was 0.32, 0.34, 0.4), fog weather likewise.
const DAY_COLOR := Color(0.5, 0.5, 0.53, 1)
const FOG_COLOR := Color(0.34, 0.35, 0.39, 1)
const NIGHT_COLOR := Color(0.035, 0.035, 0.06, 1)

## User request: the dark breathes - the whole scene's light swells and
## fades by a few percent on a slow cycle.
const BREATH_PERIOD := 7.0
const BREATH_AMOUNT := 0.06

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var base := DAY_COLOR
	if GameState.is_night:
		base = NIGHT_COLOR
	elif GameState.weather == GameState.Weather.FOG:
		base = FOG_COLOR
	var breath := 1.0 + BREATH_AMOUNT * sin(_time * TAU / BREATH_PERIOD)
	color = Color(base.r * breath, base.g * breath, base.b * breath, 1.0)
