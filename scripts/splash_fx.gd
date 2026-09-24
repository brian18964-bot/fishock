class_name SplashFx
extends Sprite2D

## Water step 4: pre-rendered splashes (tools/render_splash.py - procedural
## droplets and a small leaping fish through the same 55deg albedo + normal
## pipeline). Plays its frames once and frees itself. Spawned by main.gd:
## the bait landing, a bite, and now and then a fish jumping somewhere near
## the player.

const SPRITE_SCALE := 0.5
## Half the fish's jump span in world px (1.6 units / 2 x 13.554).
const FISH_HALF_SPAN := 10.8

const KINDS := {
	"splash_land": {"frames": 8, "fps": 13.0, "offset": Vector2(0.0, -1.7),
		"albedo": preload("res://assets/sprites/splash/splash_land_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/splash/splash_land_55deg_normal.png")},
	"splash_bite": {"frames": 6, "fps": 13.0, "offset": Vector2(0.0, -1.21),
		"albedo": preload("res://assets/sprites/splash/splash_bite_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/splash/splash_bite_55deg_normal.png")},
	"fish_jump_right": {"frames": 10, "fps": 12.5, "offset": Vector2(0.0, -9.39),
		"albedo": preload("res://assets/sprites/splash/fish_jump_right_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/splash/fish_jump_right_55deg_normal.png")},
	"fish_jump_left": {"frames": 10, "fps": 12.5, "offset": Vector2(0.0, -9.39),
		"albedo": preload("res://assets/sprites/splash/fish_jump_left_55deg_albedo.png"),
		"normal": preload("res://assets/sprites/splash/fish_jump_left_55deg_normal.png")},
}

var _frames := 1
var _fps := 12.0
var _age := 0.0


static func play(parent: Node, kind: String, pos: Vector2) -> SplashFx:
	var fx := SplashFx.new()
	var data: Dictionary = KINDS[kind]
	var tex := CanvasTexture.new()
	tex.diffuse_texture = data.albedo
	tex.normal_texture = data.normal
	fx.texture = tex
	fx.hframes = data.frames
	fx.offset = data.offset
	fx.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	fx.position = pos
	fx.z_index = 5
	fx._frames = data.frames
	fx._fps = data.fps
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_age += delta
	var f := int(_age * _fps)
	if f >= _frames:
		queue_free()
		return
	frame = f
