extends Node

## User request: sound (there was none). The game's sounds are synthesized
## by tools/make_sounds.py into assets/audio/<name>.wav (imported QOA-
## compressed; the loops - *_loop, amb_*, music_* - loop in their import
## settings). This autoload plays them:
##   Sfx.play(name)             a one-shot, heard everywhere
##   Sfx.play_at(name, pos)     a one-shot at a spot in the world (fades
##                              with distance from the camera)
##   Sfx.loop(name, on, db)     a loop faded in/out, e.g. the reel's ratchet
##   Sfx.ambience(name) / Sfx.music(name)   crossfaded beds
## Streams load on first use. Everything goes through the Master bus;
## Sfx.muted silences it all.

const DIR := "res://assets/audio/%s.wav"
const VOICES := 10
const VOICES_2D := 8
const FADE := 1.5
const AMBIENCE_DB := -9.0
const MUSIC_DB := -15.0

var muted := false:
	set(v):
		muted = v
		AudioServer.set_bus_mute(0, v)

var _voices: Array[AudioStreamPlayer] = []
var _voices_2d: Array[AudioStreamPlayer2D] = []
var _next := 0
var _next_2d := 0
var _loops := {}
var _loop_target := {}
var _beds := {"ambience": [], "music": []}
var _bed_names := {"ambience": "", "music": ""}
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for i in VOICES_2D:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 700.0
		p.attenuation = 1.6
		add_child(p)
		_voices_2d.append(p)
	for kind in _beds:
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.volume_db = -80.0
			add_child(p)
			_beds[kind].append(p)


func stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := DIR % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]


func play(name: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var s := stream(name)
	if s == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_at(name: String, pos: Vector2, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var s := stream(name)
	if s == null:
		return
	var p := _voices_2d[_next_2d]
	_next_2d = (_next_2d + 1) % VOICES_2D
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## A looping sound faded toward `volume_db` (on) or silence (off).
func loop(name: String, on: bool, volume_db := 0.0) -> void:
	if not _loops.has(name):
		if not on:
			return
		var s := stream(name)
		if s == null:
			return
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = -60.0
		add_child(p)
		_loops[name] = p
	_loop_target[name] = volume_db if on else -60.0
	var player: AudioStreamPlayer = _loops[name]
	if on and not player.playing:
		player.play()


func ambience(name: String) -> void:
	_bed("ambience", name)


func music(name: String) -> void:
	_bed("music", name)


func stop_all() -> void:
	for name in _loops:
		_loop_target[name] = -60.0
	_bed("ambience", "")
	_bed("music", "")


func _bed(kind: String, name: String) -> void:
	if _bed_names[kind] == name:
		return
	_bed_names[kind] = name
	var pair: Array = _beds[kind]
	# The quieter player takes the new bed; the other fades out.
	var incoming: AudioStreamPlayer = pair[0] if pair[0].volume_db < pair[1].volume_db else pair[1]
	if name != "":
		incoming.stream = stream(name)
		if incoming.stream != null:
			incoming.play()


func _process(delta: float) -> void:
	for name in _loops:
		var p: AudioStreamPlayer = _loops[name]
		p.volume_db = move_toward(p.volume_db, _loop_target[name], 60.0 / 0.4 * delta)
		if p.playing and p.volume_db <= -59.0 and _loop_target[name] <= -59.0:
			p.stop()
	for kind in _beds:
		var level: float = AMBIENCE_DB if kind == "ambience" else MUSIC_DB
		for p: AudioStreamPlayer in _beds[kind]:
			var wanted := -80.0
			if p.playing and _bed_names[kind] != "" and p.stream == _streams.get(_bed_names[kind]):
				wanted = level
			p.volume_db = move_toward(p.volume_db, wanted, 80.0 / FADE * delta)
			if p.playing and p.volume_db <= -79.0 and wanted <= -79.0:
				p.stop()
