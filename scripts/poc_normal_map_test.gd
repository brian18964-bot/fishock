extends Node2D

## Art-pipeline POC (see the handoff doc's "美術產線回覆" section): checks
## that a pre-rendered sprite + normal map actually shades directionally
## under a PointLight2D, the same way it will under the in-game lantern.
## The light sweeps left/right on its own - open this scene and watch the
## barrel's highlight/shadow follow it.

@onready var light: PointLight2D = $PointLight2D

const SWEEP_RANGE := 240.0
const SWEEP_SPEED := 0.6


func _ready() -> void:
	light.texture = LightTextureFactory.make_radial_texture(500, 0.35)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	light.position.x = sin(t * SWEEP_SPEED) * SWEEP_RANGE
