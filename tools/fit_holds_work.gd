extends "res://tests/scenarios.gd"
## tools/fit_holds.gd's work: see there.

const ACROSS := [0.0, -0.25, -0.5, -0.75, -1.0, -1.25]
const UP := [-0.75, -0.55, -0.35, -0.2]
const AHEAD := [0.45, 0.6, 0.75, 0.9]
const OUT := [0.0, 0.5, 1.0]
## A forearm and hand this much in the body at most counts as clear (the cuff's own folds).
const CLEAR := 0.02
## Looks at the reeling hand per place: 5 frames apart, once round the crank.
const REEL_LOOKS := 9
## User report (the owl's left hand in its chest as a fish was first held): reeling, the crank
## isn't always going round - the strike's first pull is held against (FishFight.opening_left),
## and there the body takes its own stance (Fish_Hold), dragged toward the fish. Each hand's places
## are looked at there too (_fit_grip, _left_held). (HELD_SETTLE: frames for the body to come to
## the hold, for BURY_TIME's look at it.)
const HELD_SETTLE := 24
## Frames from the strike before its first pull's held stance is looked at (the strike's tug
## played out, Fish_Hold blended in), and how many frames of looks a strike's good for - the
## first pull's own first moments, as the hold test looks at it - before the next fish is struck.
const STRIKE_SETTLE := 40
const STRIKE_WINDOW := 70
## Every fish struck meets the same (HELD_SEED), its first pull a surge (FishFight.open_curve:
## from, peak, when) - the body dragged hardest toward it - so every place meets the same.
const HELD_SEED := 7
const HELD_PULL := Vector3(0.18, 0.8, 0.45)
## Each share of the left forearm and hand in the body past CLEAR costs this (m): any of it
## worse than any way off the reel's place.
const BURIED_COST := 30.0
## User report (the bear's left hand gone behind its belly): the left forearm and hand at least
## this share seen from the game's camera (HoldCheck.seen), each share short costing this (m).
const SEEN_MIN := 0.2
const SEEN_COST := 1.0

var _check: HoldCheck
## (looks that found the float in: none, or the fit's not written)
var _empty := 0
var _zone: Node
var _line := 0.0
## (the profile's character before the fitting, put back as it ends)
var _was := ""
## (the frame the last fish was struck and settled into its first pull held)
var _struck_at := -1


func _run() -> void:
	var who := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else Profile.character
	# (the profile's own character put back however the fitting ends - it's the real profile, and
	# the tests that follow play whoever it holds: _quit())
	_was = Profile.character
	Profile.choose_character(who)
	gs = get_tree().root.get_node("GameState")
	RunView3D.intro = false
	# (the night the hold test plays - test_fishing_hold_every_character: the same map, the same
	# place on the shore, the same cast and fish - so a hold fitted here is one looked at there)
	await _fresh_game()
	for _i in 600:
		if RunView3D.active != null and RunView3D.active.built:
			break
		await frames(1)
	await frames(30)
	var rv: RunView3D = RunView3D.active
	var p := player()
	# (no ghost to the float: it'd take the bait, and the hands' places be looked at empty)
	still_ghosts()
	p.bait_count = 20
	_zone = main.get_tree().get_nodes_in_group("water_zones_common")[0]
	await put(_zone.shore_point(Vector2.DOWN) + Vector2(0, 60))
	p.aim_dir = Vector2.UP
	await frames(6)
	p.charge_time = p.MAX_CHARGE_TIME * 0.5
	p._launch_cast()
	for _i in 240:
		if p.state == Player.State.WAITING:
			break
		await frames(1)
	p.wait_timer = 1000.0
	await frames(60)
	if p.state != Player.State.WAITING:
		push_error("fit_holds: %s isn't waiting on a bite (%d)" % [who, p.state])
		_quit(1)
		return
	_check = HoldCheck.new(rv.rig, 2)
	if OS.has_environment("FIT_DEBUG"):
		p.catch_failed.connect(func(why): print("CATCH FAILED ", why, " (state ", p.state, ")"))
	var t0 := Time.get_ticks_msec()
	if OS.has_environment("BURY_TIME"):
		# (how much of each forearm and hand is in the body, moment by moment after the cast)
		var line := ""
		for i in 24:
			var got := await _look(rv, false)
			line += " %.2f/%.2f[c%d t%.2f i%.2f s%.2f f%.2f st%d]" % [got.get("r", -1.0), got.get("l", -1.0), rv._visual.clip, rv._centred, rv._left_ik.influence, rv._stow, rv._left_free, p.state]
			await frames(11)
		print("BURY %-7s waiting r/l every 0.25 s:%s" % [who, line])
		await _hook()
		line = ""
		for i in 30:
			var got := await _look(rv, true)
			line += " %.2f/%.2f[%.2f c%d]" % [got.get("r", -1.0), got.get("l", -1.0), fmod(rv._crank, TAU), rv._visual.clip]
		print("BURY %-7s reeling r/l every 5 frames:%s" % [who, line])
		p.fight.open(p.fight.heft)
		await _keep(HELD_SETTLE, false)
		line = ""
		for i in 12:
			var got := await _look(rv, true, false, true)
			line += " %.2f/%.2f[c%d]" % [got.get("r", -1.0), got.get("l", -1.0), rv._visual.clip]
		print("BURY %-7s the first pull held r/l every 5 frames:%s" % [who, line])
		_quit()
		return
	if OS.has_environment("SEEN_ONLY"):
		# (how much of each hand the camera sees as it's held now, waiting and reeling)
		var w := await _look(rv, false, true)
		await _hook()
		var r := await _look(rv, true, true)
		print("SEEN %-7s waiting R %.2f L %.2f (L in the body %.3f) | reeling R %.2f L %.2f (L in the body %.3f)" % [who, w.seen_r, w.seen_l, w.l, r.get("seen_r", -1.0), r.get("seen_l", -1.0), r.get("l", -1.0)])
		_quit()
		return
	var path := "res://assets/sprites/player/%s/fit.json" % who
	var fit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var best := {}
	if OS.has_environment("LEFT_ONLY") and fit.has("hold"):
		# (the right hand's place kept as it was fitted: only the left hand's fitted again)
		best = {"grip": fit.hold.grip, "out": fit.hold.out, "in_wait": -1.0, "in_reel": -1.0, "strain": -1.0}
		await _hook()
	else:
		best = await _fit_grip(rv)
		if best.is_empty():
			_quit(1)
			return
	# Then the left hand's place, the nearest the reel's (under the rod, just up it from the
	# grip) that's clear of the body and in reach: reeling - the crank going round, and a fish
	# struck afresh, its first pull held - then (the fish let go, the float out again) waiting.
	var cranked := await _left_looks(rv, best, "crank")
	if cranked.is_empty():
		push_error("fit_holds: %s lost its fish before the left hand's places were tried" % who)
		_quit(1)
		return
	# (each place as the crank's looks rank it, best first, then struck with and held as the hold
	# test does - until no place left could beat the best so far)
	var order := range(cranked.size())
	order.sort_custom(func(a, b): return _left_cost(cranked[a]) < _left_cost(cranked[b]))
	var left_reel := {}
	var least := INF
	for i in order:
		var c: Dictionary = cranked[i]
		if _left_cost(c) >= least:
			break
		var held_l := await _left_held(rv, best, c.at)
		if held_l < 0.0:
			push_error("fit_holds: %s lost its float or its fish before the left hand's places were tried held" % who)
			_quit(1)
			return
		var both := c.duplicate()
		both.l = maxf(c.l, held_l)
		var cost := _left_cost(both)
		if OS.has_environment("FIT_DEBUG"):
			print("HELD %s in %.3f cranked %.3f cost %.2f" % [str(c.at), held_l, c.l, cost])
		if cost < least:
			least = cost
			left_reel = {"at": c.at, "l": both.l, "off": c.off, "seen": c.seen}
	var left_wait := left_reel
	if await _cast_again():
		left_wait = _pick_left([await _left_looks(rv, best, "wait")])
	else:
		push_warning("fit_holds: %s didn't get its float out again (%d): the left hand kept as reeling" % [who, p.state])
	if _empty > 0:
		push_error("fit_holds: %s - %d looks found the float in (a bite, a ghost at it): nothing written" % [who, _empty])
		_quit(1)
		return
	fit.erase("torso")
	fit.hold = {"grip": best.grip, "left": left_wait.at, "left_reel": left_reel.at, "out": best.out}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(fit, "", false))
	f.close()
	print("HOLD %-7s grip %s out %.1f | right arm in the body %.3f waiting %.3f reeling or held, reach %.2f | left %s (in %.3f, %.2f m off the reel, seen %.2f) reeling %s (in %.3f, %.2f m off, seen %.2f)  (%d s)" % [
		who, best.grip, best.out, best.in_wait, best.in_reel, best.strain,
		left_wait.at, left_wait.l, left_wait.off, left_wait.seen, left_reel.at, left_reel.l, left_reel.off, left_reel.seen, (Time.get_ticks_msec() - t0) / 1000])
	_quit()


## The right hand's place: each tried waiting on a bite, then (a fish hooked, kept on) reeling -
## how much of the forearm and hand is in the body. The one clear of it and in reach both ways,
## the nearest the middle: {grip, out, in_wait, in_reel, strain} ({} if the float or the fish
## was lost before they'd all been tried).
func _fit_grip(rv: RunView3D) -> Dictionary:
	var waiting := await _try_grips(rv, false)
	if waiting.is_empty():
		push_error("fit_holds: %s stopped waiting on a bite before the places were tried" % Profile.character)
		return {}
	# User report (the owl's left hand in its chest as a fish was first held): a fish struck, its
	# first pull held against - the crank still, the body in its own stance for it (Fish_Hold, not
	# Fish_Wait or Fish_Reel), where a forearm can come further into a belly - each place looked
	# at in a strike's own first moments, the strike's tug played out (a fresh fish every
	# STRIKE_WINDOW frames of looks).
	var held := await _try_grips(rv, true, true)
	if held.is_empty():
		push_error("fit_holds: %s lost its fish before the places were tried held" % Profile.character)
		return {}
	# (then the first pull let be over, and the fish reeled: the crank going round)
	player().fight.opening_left = 0.0
	await _keep(120)
	var reeling := await _try_grips(rv, true)
	if reeling.is_empty():
		push_error("fit_holds: %s lost its fish before the places were tried" % Profile.character)
		return {}
	# The place: clear of the body and in reach waiting, reeling and held, the nearest the middle.
	var best := {}
	var least := INF
	for i in waiting.size():
		var w: Dictionary = waiting[i]
		var r: Dictionary = reeling[i]
		var h: Dictionary = held[i]
		var g: Array = w.grip
		var cost: float = 60.0 * (maxf(w.r - CLEAR, 0.0) + maxf(r.r - CLEAR, 0.0) + maxf(h.r - CLEAR, 0.0)) \
			+ 2.0 * (maxf(w.strain - 1.0, 0.0) + maxf(r.strain - 1.0, 0.0) + maxf(h.strain - 1.0, 0.0)) \
			+ 0.25 * absf(g[0]) + 0.15 * absf(g[1] + 0.55) + 0.1 * (g[2] - 0.45) + 0.12 * float(w.out)
		if cost < least:
			least = cost
			best = {"grip": g, "out": w.out, "in_wait": w.r, "in_reel": maxf(r.r, h.r), "strain": maxf(maxf(w.strain, r.strain), h.strain)}
	return best


## A fish hooked and kept on, reeled `keep` frames (0: straight from the strike, its first pull on).
func _hook(keep := 120) -> void:
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
	await _keep(keep)


## One look: how much of each forearm and hand is in the body, and each arm's reach.
func _look(rv: RunView3D, reeling: bool, with_seen := false, held := false, keep := 4) -> Dictionary:
	if reeling:
		if not await _keep(keep, not held):
			return {}
	else:
		# (kept waiting: no bite comes while it's looked at - one taken and lost would have the
		# rod slung, and every look after that a look at empty hands)
		var p := player()
		p.wait_timer = maxf(p.wait_timer, 1000.0)
		await frames(4)
		if p.state != Player.State.WAITING:
			_empty += 1
			if OS.has_environment("FIT_DEBUG"):
				print("NOT WAITING state %d at %s" % [p.state, str(p.global_position)])
			return {}
	var got := {}
	rv.rig.skeleton.skeleton_updated.connect(func():
		var frame := Transform3D(rv.pivot.global_basis.orthonormalized() * rv._rig_scale(), rv.pivot.global_position)
		got.merge(_check.buried(frame))
		if with_seen:
			var s: Dictionary = _check.seen(frame, RunView3D.CAMERA_PITCH)
			got["seen_r"] = s.r
			got["seen_l"] = s.l,
		CONNECT_ONE_SHOT)
	await frames(1)
	got["sr"] = rv.strain_r
	got["sl"] = rv.strain_l
	return got


## Every place for the right hand: [{grip, r, strain}] ([] if the fish got off) - reeling, the
## crank going round, or (`held`) the first pull held against.
func _try_grips(rv: RunView3D, reeling: bool, held := false) -> Array:
	var out := []
	for wide in OUT:
		for x in ACROSS:
			for y in UP:
				for z in AHEAD:
					if held and not await _strike_fresh_if_due():
						rv.hold_try = {}
						return []
					rv.hold_try = {"grip": [x, y, z], "left": [1.0, y, z], "left_reel": [1.0, y, z], "out": wide}
					var got := await _look(rv, reeling, false, held)
					if got.is_empty():
						rv.hold_try = {}
						return []
					out.append({"grip": [x, y, z], "out": wide, "r": float(got.get("r", 1.0)), "strain": float(got.sr)})
	rv.hold_try = {}
	return out


## The places tried for the left hand, the right at `hold`: [[at, off]] - from beside the right
## hand to out before its own shoulder, a little up, down, in and out; `off`, how far each is from
## the reel's place under the rod (m).
func _left_places(rv: RunView3D, hold: Dictionary) -> Array:
	var sk := rv.rig.skeleton
	var half := sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin.distance_to(sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin) * 0.5
	var arm := rv._left_len
	var g: Array = hold.grip
	# (the reel's place, as the hold's own measures)
	var reel := Vector3(float(g[0]) + 0.05 / half, float(g[1]) - 0.08 / arm, float(g[2]) + 0.03 / arm)
	var out := []
	var seen := {}
	for x_at in [float(g[0]) + 0.2, float(g[0]) + 0.45, float(g[0]) + 0.7, 0.2, 0.45, 0.7, 1.0, 1.25]:
		var x := minf(float(x_at), 1.25)
		for dy in [0.0, -0.15, 0.15, 0.3]:
			for dz in [0.0, -0.15, 0.12, 0.25]:
				var at := [snappedf(x, 0.01), snappedf(float(g[1]) + dy, 0.01), snappedf(float(g[2]) + dz, 0.01)]
				if seen.has(str(at)):
					continue
				seen[str(at)] = true
				out.append([at, Vector3((at[0] - reel.x) * half, (at[1] - reel.y) * arm, (at[2] - reel.z) * arm).length()])
	return out


## Every place for the left hand looked at one way (`how`): "crank" - reeling, all the way round
## the crank; "wait" - waiting on a bite, twice a moment apart. [{at, off, l, far, seen}] (l: the
## most of that arm in the body; far: its reach; seen: how much of it the camera sees); [] if the
## fish or the float was lost.
func _left_looks(rv: RunView3D, hold: Dictionary, how: String) -> Array:
	var out := []
	var looks := REEL_LOOKS if how == "crank" else 2
	for place in _left_places(rv, hold):
		var at: Array = place[0]
		rv.hold_try = {"grip": hold.grip, "left": at, "left_reel": at, "out": hold.out}
		var worst := 0.0
		var far := 0.0
		var shown := 1.0
		for pass_n in looks:
			var got := await _look(rv, how != "wait", pass_n == 0)
			if got.is_empty():
				rv.hold_try = {}
				return []
			worst = maxf(worst, float(got.get("l", 1.0)))
			far = maxf(far, float(got.get("sl", 9.0)))
			if pass_n == 0:
				shown = float(got.get("seen_l", 1.0))
		if OS.has_environment("FIT_DEBUG"):
			print("TRY %s %s in %.3f off %.2f reach %.2f seen %.2f" % [how, str(at), worst, float(place[1]), far, shown])
		out.append({"at": at, "off": float(place[1]), "l": worst, "far": far, "seen": shown})
	rv.hold_try = {}
	return out


## The left hand's place from its looks (each list one way it was looked at, in the same order):
## the nearest the reel's that's clear of the body and in reach every way, and seen enough.
## {at, l, off, seen}.
func _pick_left(lists: Array) -> Dictionary:
	var best := {}
	var least := INF
	var first: Array = lists[0]
	for i in first.size():
		var worst := 0.0
		var far := 0.0
		var shown := 1.0
		for list: Array in lists:
			var r: Dictionary = list[i]
			worst = maxf(worst, r.l)
			far = maxf(far, r.far)
			shown = minf(shown, r.seen)
		var off: float = first[i].off
		var cost := _left_cost({"off": off, "l": worst, "far": far, "seen": shown})
		if cost < least:
			least = cost
			best = {"at": first[i].at, "l": worst, "off": off, "seen": shown}
	return best


## What a place for the left hand costs ({off, l, far, seen}): its way off the reel's place (m),
## and dearly any of the arm in the body past CLEAR, a reach past the arm's, too little of it seen.
func _left_cost(r: Dictionary) -> float:
	return float(r.off) + BURIED_COST * maxf(float(r.l) - CLEAR, 0.0) + 2.0 * maxf(float(r.far) - 1.0, 0.0) \
		+ SEEN_COST * maxf(SEEN_MIN - float(r.seen), 0.0)


## The left hand at `at` as a fish is struck and its first pull held, looked at as the hold test
## looks (test_fishing_hold_every_character): the most of that arm in the body (-1 if the float
## or the fish was lost). The first pull's always the same hard one - it surges - so every place
## meets the same.
func _left_held(rv: RunView3D, hold: Dictionary, at: Array) -> float:
	if not await _cast_again():
		return -1.0
	rv.hold_try = {"grip": hold.grip, "left": at, "left_reel": at, "out": hold.out}
	if not await _strike():
		return -1.0
	var worst := 0.0
	for i in 60:
		if i >= 24 and i % 4 == 0:
			var got := await _look(rv, true, false, true, 1)
			if got.is_empty():
				return -1.0
			worst = maxf(worst, float(got.get("l", 1.0)))
		elif not await _keep(1, false):
			return -1.0
	rv.hold_try = {}
	return worst


## The fish let go and the float cast out again (true if it's out, waiting on a bite).
func _cast_again() -> bool:
	var p := player()
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	# (the rod as good as new: every cast wears it)
	Profile.wear.clear()
	if p.state == Player.State.WAITING:
		return true
	if p.state == Player.State.REELING:
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
	for _i in 240:
		if p.state == Player.State.WAITING:
			break
		await frames(1)
	p.wait_timer = 1000.0
	await frames(60)
	return p.state == Player.State.WAITING


## A fish struck afresh and settled into its first pull, held, if the last one's first moments are
## used up (STRIKE_WINDOW) or there's none on (false if the float or the fish was lost).
func _strike_fresh_if_due() -> bool:
	var p := player()
	if _struck_at >= 0 and p.state == Player.State.REELING and Engine.get_process_frames() - _struck_at <= STRIKE_WINDOW:
		return true
	if not await _cast_again():
		return false
	if not await _strike():
		return false
	await _keep(STRIKE_SETTLE, false)
	_struck_at = Engine.get_process_frames()
	return p.state == Player.State.REELING


## A fish struck, its first pull the same hard one every time (HELD_SEED, HELD_PULL): false if
## it didn't take.
func _strike() -> bool:
	seed(HELD_SEED)
	await _hook(0)
	var f: FishFight = player().fight
	if f == null:
		return false
	f.open_curve = HELD_PULL
	return true


## A fish kept on, reeled, as it was (the fight's not played): `n` frames - the crank going
## round, or (`cranking` false) the line held against the strike's first pull, kept on.
func _keep(n: int, cranking := true) -> bool:
	var p := player()
	for _i in n:
		if p.state != Player.State.REELING or p.fight == null:
			return false
		var f: FishFight = p.fight
		f.tension = 0.4
		f.progress = minf(f.progress, 0.3)
		f.distance = _line
		p._snap_at = -1.0
		if not cranking:
			f.opening_left = maxf(f.opening_left, 0.1)
		key(KEY_SPACE, true)
		# (cranked only once the first pull's over: into it, the line snaps - FishFight "rush")
		key(KEY_SHIFT, cranking and f.opening_left <= 0.0)
		await frames(1)
	return true


func _quit(code := 0) -> void:
	if _was != "":
		Profile.choose_character(_was)
	get_tree().quit(code)
