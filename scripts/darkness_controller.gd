extends CanvasModulate

## Design doc request: day should read as hazy/foggy, not pitch black; only
## night collapses visibility down to near-nothing outside the lantern.

const DAY_COLOR := Color(0.32, 0.34, 0.4, 1)
const NIGHT_COLOR := Color(0.035, 0.035, 0.06, 1)

func _process(_delta: float) -> void:
	color = NIGHT_COLOR if GameState.is_night else DAY_COLOR
