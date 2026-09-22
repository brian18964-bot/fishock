extends CanvasModulate

## Design doc request: day should read as hazy/foggy, not pitch black; only
## night collapses visibility down to near-nothing outside the lantern.
## User feedback: a fog weather event darkens things further on top of that.

const DAY_COLOR := Color(0.32, 0.34, 0.4, 1)
const FOG_COLOR := Color(0.22, 0.24, 0.28, 1)
const NIGHT_COLOR := Color(0.035, 0.035, 0.06, 1)

func _process(_delta: float) -> void:
	if GameState.is_night:
		color = NIGHT_COLOR
	elif GameState.weather == GameState.Weather.FOG:
		color = FOG_COLOR
	else:
		color = DAY_COLOR
