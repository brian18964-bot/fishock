extends "res://tools/loading_shots_work.gd"
## tools/surf_shots.gd's work.


func _run() -> void:
	OS.set_environment("THEME", "coast")
	await begin(false)
	var v: RunView3D = RunView3D.active
	var p := player()
	var side := MapGenerator.sea_side
	var along := Vector2(side.y, side.x)
	var mid := Vector2(Player.WORLD_WIDTH, Player.WORLD_HEIGHT) * 0.5
	hud(false)
	# (the water's edge a little along from the map's middle; the traveller - the lamp - up from it)
	var spot := mid
	for k in 3000:
		var q := mid + side * float(k) * 2.0 + along * 300.0
		if v._sea_at(q) > -4.0:
			spot = q
			break
	p.global_position = spot - side * 45.0
	p.velocity = Vector2.ZERO
	p.aim_dir = side
	p.get_node("Camera2D").reset_smoothing()
	await seconds(1.0)
	var at := RunView3D.to3(spot, v.ground_y(spot))
	var s3 := Vector3(side.x, 0, side.y)
	var a3 := Vector3(along.x, 0, along.y)
	var n := int(_env("N", "16"))
	var step := float(_env("STEP", "0.5"))
	aim(at + s3 * 0.3 - a3 * 0.5, at - s3 * float(_env("DIST", "4.5")) + a3 * 1.8 + Vector3(0, float(_env("H", "2.6")), 0), 55.0)
	for i in n:
		await seconds(step)
		await shot("surf_%02d" % i)
	if v._wetness != null and v._wetness.texture() != null:
		v._wetness.texture().get_image().save_png(OUT + "/wetness.png")
	get_tree().quit()


func _env(key: String, default: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else default
