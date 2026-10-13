class_name SplashFx
extends Sprite2D

## A splash on the water: the bait landing, a bite, now and then a fish
## jumping near the player (main.gd). User decision (3D only): RunView3D
## shows it in 3D by `kind` (droplets, a ring, the fish leaping); this only
## says where and what, and lasts its time.

const KINDS := {
	"splash_land": 0.65, "splash_bite": 0.5, "fish_jump_right": 0.8, "fish_jump_left": 0.8,
}

var kind := ""
var _life := 0.6
var _age := 0.0


static func play(parent: Node, which: String, pos: Vector2) -> SplashFx:
	var fx := SplashFx.new()
	fx.kind = which
	fx._life = float(KINDS.get(which, 0.6))
	fx.position = pos
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
