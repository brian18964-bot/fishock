extends CanvasModulate

## Design doc request: day should read as hazy/foggy, not pitch black; only
## night collapses visibility down to near-nothing outside the lantern.
## User feedback: a fog weather event darkens things further on top of that.

## User request: the day darkens in four stages (GameState.light_stage()) -
## dark enough from the start that you need the lamp, darker each quarter.
## Near-neutral, not the old murky blue-grey. Fog weather darkens a step.
const STAGE_COLORS := [
	Color(0.26, 0.26, 0.28, 1),
	Color(0.19, 0.19, 0.21, 1),
	Color(0.13, 0.13, 0.15, 1),
	Color(0.085, 0.085, 0.1, 1),
]
const FOG_MULT := 0.8
## Seconds to ease from one stage into the next.
const STAGE_EASE := 6.0
const NIGHT_COLOR := Color(0.035, 0.035, 0.06, 1)

## User request: the dark breathes - the whole scene's light swells and
## fades by a few percent on a slow cycle.
const BREATH_PERIOD := 7.0
const BREATH_AMOUNT := 0.06

## User request (map styles): the theme's light - cool on snow, warm in
## autumn, sickly in the swamp (MapGenerator.THEMES "tint"). Multiplies the
## day's colour; night stays night.
var tint := Color.WHITE
var _time := 0.0
var _base: Color = STAGE_COLORS[0]


func _process(delta: float) -> void:
	_time += delta
	var target: Color = STAGE_COLORS[GameState.light_stage()]
	if GameState.is_night:
		target = NIGHT_COLOR
	elif GameState.weather == GameState.Weather.FOG:
		target = target * FOG_MULT
	if not GameState.is_night:
		target = Color(target.r * tint.r, target.g * tint.g, target.b * tint.b, 1.0)
	_base = _base.lerp(target, minf(1.0, delta / STAGE_EASE * 3.0))
	var breath := 1.0 + BREATH_AMOUNT * sin(_time * TAU / BREATH_PERIOD)
	color = Color(_base.r * breath, _base.g * breath, _base.b * breath, 1.0)
