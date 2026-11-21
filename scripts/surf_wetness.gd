class_name SurfWetness
extends Node

## User request (the sandy beach): the sand wet where the sea's water has actually been - dark at
## once where a wave runs over it, still wet in the shape of that wave's reach when it has drained
## away, drying slowly back to pale (Surf.DRY_TIME), wet again when the next one reaches it.
##
## The water's cover now and the sand's wetness are kept apart: the cover is Surf's model (where its
## water is this moment); the wetness is a picture over the beach, each texel a patch of sand
## (`texel` m), its red how wet - drawn again every so often from the last one: drier by a step, but
## never less than the water covering it now (max(last - step, cover)). Two pictures turn about
## (each drawn from the other - a picture can't be drawn from itself), the ground's shader reading
## the newest (texture()). A step is one level of the picture's 255, so the steps come every
## DRY_TIME / 255 s and the sand dries over DRY_TIME s. (Its green: the film of water left lying on
## the sand as a wave drains - the sheet's depth where it is now, running off over Surf.FILM_TIME s:
## the gleam gone long before the dark.)

const SIM_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D prev : filter_nearest, repeat_disable;
uniform sampler2D sea_tex : filter_linear, repeat_disable;
uniform vec4 sea_box;
uniform vec2 sea_range;
// (the picture's patch of the world: x, z, width, depth m)
uniform vec4 rect;
uniform float dry_step = 0.0045;
// (the film of water left on it: how much less each step - it runs off far quicker than the sand dries)
uniform float film_step = 0.04;
// (the first: the sand as the last few waves would have left it)
uniform float init = 0.0;
""" + Surf.GLSL + """
void fragment() {
	vec2 w = rect.xy + UV * rect.zw;
	float shore = -mix(sea_range.x, sea_range.y, surf_smooth(sea_tex, (w - sea_box.xy) / sea_box.zw));
	float edge; float u; float n; float reach;
	float cover = surf_at(w, shore, edge, u, n, reach);
	vec2 last = init > 0.5 ? vec2((1.0 - smoothstep(surf_run_up.x * 0.4, surf_run_up.y * 0.9, shore)) * 0.85, 0.0) : texture(prev, UV).rg;
	// (red: the sand's own wetness - soaked where the water is, drying slowly after; green: the film
	// of water on it - as deep as the sheet over it now, running off quickly once it's gone)
	float film = cover * smoothstep(0.0, 16.0, edge - shore);
	COLOR = vec4(max(last.x - dry_step, cover), max(last.y - film_step, film), 0.0, 1.0);
}
"""

## The picture's patch of the world (3D x, z m) and its size (texels).
var rect := Rect2()
var size := Vector2i.ZERO
var _vp: Array[SubViewport] = []
var _mats: Array[ShaderMaterial] = []
var _cur := 0
var _since := 0.0
var _first := true
## Steps drawn (for tests).
var steps := 0


## Over `world` (3D x, z m), a texel every `texel` m (at most `most` texels a side); the sea's depth
## as the sea's surface has it.
func setup(world: Rect2, texel: float, sea_tex: Texture2D, sea_box: Vector4, sea_range: Vector2, most := 2048) -> void:
	rect = world
	var t := maxf(texel, maxf(world.size.x, world.size.y) / float(most))
	size = Vector2i(maxi(4, ceili(world.size.x / t)), maxi(4, ceili(world.size.y / t)))
	var sh := Shader.new()
	sh.code = SIM_SHADER
	for k in 2:
		var vp := SubViewport.new()
		vp.name = "Wetness%d" % k
		vp.size = size
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("sea_tex", sea_tex)
		mat.set_shader_parameter("sea_box", sea_box)
		mat.set_shader_parameter("sea_range", sea_range)
		mat.set_shader_parameter("rect", Vector4(world.position.x, world.position.y, world.size.x, world.size.y))
		Surf.uniforms(mat)
		var paper := ColorRect.new()
		paper.size = Vector2(size)
		paper.material = mat
		vp.add_child(paper)
		_vp.append(vp)
		_mats.append(mat)
	for k in 2:
		_mats[k].set_shader_parameter("prev", _vp[1 - k].get_texture())


## The newest picture of the sand's wetness (red: 0 dry .. 1 soaked).
func texture() -> Texture2D:
	return _vp[_cur].get_texture() if not _vp.is_empty() else null


## The world rect as the shaders take it (x, z, width, depth m).
func rect4() -> Vector4:
	return Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)


## Draw the next picture if it's time: returns true when it did (the ground's shader then reads it).
func step(delta: float) -> bool:
	if _vp.is_empty():
		return false
	_since += delta
	var every := Surf.DRY_TIME / 255.0
	if _since < every and not _first:
		return false
	# (as many levels drier as steps' worth of time has gone - a slow frame dries as much)
	var levels := maxf(floorf(_since / every), 1.0)
	_since = fmod(_since, every)
	var next := 1 - _cur
	var mat := _mats[next]
	mat.set_shader_parameter("surf_time", Surf.time)
	mat.set_shader_parameter("dry_step", (levels + 0.1) / 255.0)
	mat.set_shader_parameter("film_step", levels * every / Surf.FILM_TIME + 0.1 / 255.0)
	mat.set_shader_parameter("init", 1.0 if _first else 0.0)
	_first = false
	_vp[next].render_target_update_mode = SubViewport.UPDATE_ONCE
	_cur = next
	steps += 1
	return true
