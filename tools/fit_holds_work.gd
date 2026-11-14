extends "res://tests/scenarios.gd"
## tools/fit_holds.gd's work: see there.

const ACROSS := [0.0, -0.25, -0.5, -0.75, -1.0, -1.25]
const UP := [-0.75, -0.55, -0.35, -0.2]
const AHEAD := [0.45, 0.6, 0.75, 0.9]
const OUT := [0.0, 0.5, 1.0]
## A forearm and hand this much in the body at most counts as clear (the cuff's own folds).
const CLEAR := 0.02

var _check: HoldCheck
var _zone: Node
var _line := 0.0


func _run() -> void:
	var who := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else Profile.character
	Profile.choose_character(who)
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	seed(5)
	camp().clear()
	gs.reset_run()
	gs.last_return = ""
	camp().begin_free([], "")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames(3)
	main = get_tree().current_scene
	gs.start_run()
	for _i in 600:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	await frames(150)
	var rv: RunView3D = RunView3D.active
	var p := player()
	p.bait_count = 20
	_zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(_zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	p.aim_dir = Vector2.UP
	await frames(6)
	p.charge_time = p.MAX_CHARGE_TIME * 0.5
	p._launch_cast()
	await frames(90)
	if p.state != Player.State.WAITING:
		push_error("fit_holds: %s isn't waiting on a bite (%d)" % [who, p.state])
		get_tree().quit(1)
		return
	_check = HoldCheck.new(rv.rig, 2)
	var t0 := Time.get_ticks_msec()
	# The right hand's places, waiting: how much of the forearm and hand is in the body.
	var waiting := await _try_grips(rv, false)
	# (a fish on, reeled: the fight kept as it is while the places are tried)
	await _hook()
	var reeling := await _try_grips(rv, true)
	if reeling.is_empty():
		push_error("fit_holds: %s lost its fish before the places were tried" % who)
		get_tree().quit(1)
		return
	# The place: clear of the body and in reach both waiting and reeling, the nearest the
	# middle.
	var best := {}
	var least := INF
	for i in waiting.size():
		var w: Dictionary = waiting[i]
		var r: Dictionary = reeling[i]
		var g: Array = w.grip
		var cost: float = 60.0 * (maxf(w.r - CLEAR, 0.0) + maxf(r.r - CLEAR, 0.0)) \
			+ 2.0 * (maxf(w.strain - 1.0, 0.0) + maxf(r.strain - 1.0, 0.0)) \
			+ 0.25 * absf(g[0]) + 0.15 * absf(g[1] + 0.55) + 0.1 * (g[2] - 0.45) + 0.12 * float(w.out)
		if cost < least:
			least = cost
			best = {"grip": g, "out": w.out, "in_wait": w.r, "in_reel": r.r, "strain": maxf(w.strain, r.strain)}
	# Then the left hand's place, the nearest the reel's (under the rod, just up it from the
	# grip) that's clear of the body and in reach: reeling, and (the fish let go, the float out
	# again) waiting.
	var left_reel := await _try_left(rv, best, true)
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	p._fail_catch("escaped")
	for _i in 240:
		if p.state == Player.State.IDLE:
			break
		await frames(1)
	await frames(30)
	p.bait_count = 20
	p.aim_dir = Vector2.UP
	p.charge_time = p.MAX_CHARGE_TIME * 0.5
	p._launch_cast()
	await frames(90)
	var left_wait := left_reel
	if p.state == Player.State.WAITING:
		left_wait = await _try_left(rv, best, false)
	else:
		push_warning("fit_holds: %s didn't get its float out again (%d): the left hand kept as reeling" % [who, p.state])
	var path := "res://assets/sprites/player/%s/fit.json" % who
	var fit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	fit.erase("torso")
	fit.hold = {"grip": best.grip, "left": left_wait.at, "left_reel": left_reel.at, "out": best.out}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(fit, "", false))
	f.close()
	print("HOLD %-7s grip %s out %.1f | right arm in the body %.3f waiting %.3f reeling, reach %.2f | left %s (in %.3f, %.2f m off the reel) reeling %s (in %.3f, %.2f m off)  (%d s)" % [
		who, best.grip, best.out, best.in_wait, best.in_reel, best.strain,
		left_wait.at, left_wait.l, left_wait.off, left_reel.at, left_reel.l, left_reel.off, (Time.get_ticks_msec() - t0) / 1000])
	get_tree().quit()


func _hook() -> void:
	var p := player()
	p.cast_target = p.global_position + Vector2(0, -150)
	p.cast_water_zone = _zone
	p.tier_data = FishData.get_tier_data("near").duplicate()
	p.difficulty_key = "advanced"
	p.fish_id = ""
	p.fish_habit = ""
	p.is_heart_catch = false
	p.is_epic_catch = false
	p.is_rare_catch = false
	p._hook_fish()
	p.fish_id = "carp"
	p.fight.plan("medium", "normal")
	_line = p.fight.distance
	await _keep(120)


## One look: how much of each forearm and hand is in the body, and each arm's reach.
func _look(rv: RunView3D, reeling: bool) -> Dictionary:
	if reeling:
		if not await _keep(4):
			return {}
	else:
		await frames(4)
	var got := {}
	rv.rig.skeleton.skeleton_updated.connect(func():
		got.merge(_check.buried(Transform3D(rv.pivot.global_basis.orthonormalized() * rv._rig_scale(), rv.pivot.global_position))),
		CONNECT_ONE_SHOT)
	await frames(1)
	got["sr"] = rv.strain_r
	got["sl"] = rv.strain_l
	return got


## Every place for the right hand: [{grip, r, strain}] ([] if the fish got off).
func _try_grips(rv: RunView3D, reeling: bool) -> Array:
	var out := []
	for wide in OUT:
		for x in ACROSS:
			for y in UP:
				for z in AHEAD:
					rv.hold_try = {"grip": [x, y, z], "left": [1.0, y, z], "left_reel": [1.0, y, z], "out": wide}
					var got := await _look(rv, reeling)
					if got.is_empty():
						rv.hold_try = {}
						return []
					out.append({"grip": [x, y, z], "out": wide, "r": float(got.get("r", 1.0)), "strain": float(got.sr)})
	rv.hold_try = {}
	return out


## The left hand's place, the right at `hold`: the nearest the reel's that's clear of the body
## and in reach - each looked at twice, a moment apart (the body sways, the hand goes round).
## {at, l, off}: the place, how much of that arm's in the body there, how far it is from the
## reel's (m).
func _try_left(rv: RunView3D, hold: Dictionary, reeling: bool) -> Dictionary:
	var sk := rv.rig.skeleton
	var half := sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin.distance_to(sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin) * 0.5
	var arm := rv._left_len
	var g: Array = hold.grip
	# (the reel's place, as the hold's own measures)
	var reel := Vector3(float(g[0]) + 0.05 / half, float(g[1]) - 0.08 / arm, float(g[2]) + 0.03 / arm)
	var best := {"at": [minf(float(g[0]) + 1.2, 1.0), g[1], g[2]], "l": 1.0, "off": 9.0}
	var least := INF
	var seen := {}
	# (across: from beside the right hand to out before its own shoulder)
	for x_at in [float(g[0]) + 0.2, float(g[0]) + 0.45, float(g[0]) + 0.7, 0.2, 0.45, 0.7, 1.0, 1.25]:
		var x := minf(float(x_at), 1.25)
		for dy in [0.0, -0.15, 0.15, 0.3]:
			for dz in [0.0, -0.15, 0.12, 0.25]:
				var at := [snappedf(x, 0.01), snappedf(float(g[1]) + dy, 0.01), snappedf(float(g[2]) + dz, 0.01)]
				if seen.has(str(at)):
					continue
				seen[str(at)] = true
				var off := Vector3((at[0] - reel.x) * half, (at[1] - reel.y) * arm, (at[2] - reel.z) * arm).length()
				if off >= least:
					continue
				rv.hold_try = {"grip": g, "left": at, "left_reel": at, "out": hold.out}
				var worst := 0.0
				var far := 0.0
				for _pass in 2:
					var got := await _look(rv, reeling)
					worst = maxf(worst, float(got.get("l", 1.0)))
					far = maxf(far, float(got.get("sl", 9.0)))
				var cost := off + 8.0 * maxf(worst - CLEAR, 0.0) + 2.0 * maxf(far - 1.0, 0.0)
				if cost < least:
					least = cost
					best = {"at": at, "l": worst, "off": off}
	rv.hold_try = {}
	return best


## A fish kept on, reeled, as it was (the fight's not played): `n` frames.
func _keep(n: int) -> bool:
	var p := player()
	for _i in n:
		if p.state != Player.State.REELING or p.fight == null:
			return false
		var f: FishFight = p.fight
		f.tension = 0.4
		f.progress = minf(f.progress, 0.3)
		f.distance = _line
		p._snap_at = -1.0
		key(KEY_SPACE, true)
		key(KEY_SHIFT, f.opening_left <= 0.0)
		await frames(1)
	return true
