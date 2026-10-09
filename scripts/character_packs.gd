extends Node

## User request (the web build was 148 MB, too much for a phone's first
## visit): on the web only the first character (Profile.CHARACTERS' black
## cat) comes inside the game's own pack. Each other one's pictures and camp
## model (CharacterArt's files) are a pack of their own beside it,
## packs/<id>-<hash>.pck (tools/pack_presets.py, tools/export_web.py). One
## is fetched the first time that character is wanted - the camp's fire
## tapped, or the game opened with it chosen - its progress shown, and kept
## in the browser after (user://), the next one round the fire fetched
## quietly behind it. Off the web (the editor, the tests) they're all
## there already and nothing here does anything.

signal progressed(id: String, ratio: float)
signal finished(id: String, ok: bool)

## Where they're kept, and the build's list of them ({id: file}; written by
## tools/export_web.py, only in the web build).
const DIR := "user://packs/"
const MANIFEST := "res://assets/packs.json"
## (tests: these characters made to look missing, and a fetch of one only
## pretends, taking this long)
var missing := {}
var pretend_time := 0.0

var _busy := {}
var _manifest := {}
## (a fetch that failed is tried once more before it's given up)
var _tried := {}


func _ready() -> void:
	if FileAccess.file_exists(MANIFEST):
		var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if data is Dictionary:
			_manifest = data
	# Kept from an earlier visit: mounted now, so they're simply there.
	for id in _manifest:
		var path: String = DIR + str(_manifest[id])
		if not has(id) and FileAccess.file_exists(path):
			_mount(path)
	# (The page opened with ?packcheck: all of them fetched now, each said
	# in the browser's console - a check of the web build.)
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search", true)).contains("packcheck"):
		_check_all.call_deferred()


func _check_all() -> void:
	for id in _manifest:
		var got: bool = await wait_for(id)
		print("packcheck %s %s" % [id, "ok" if got else "FAILED"])
	print("packcheck done")


## Its pictures and model are here to load.
func has(id: String) -> bool:
	if missing.has(id):
		return false
	return ResourceLoader.exists(CharacterArt.MODEL % id)


## Being fetched now.
func fetching(id: String) -> bool:
	return _busy.has(id)


## Fetches `id`'s pack if it isn't here; `finished` says when (at once if it
## is).
func fetch(id: String) -> void:
	if has(id):
		finished.emit.call_deferred(id, true)
		return
	if _busy.has(id):
		return
	if missing.has(id):
		_pretend(id)
		return
	var file: String = str(_manifest.get(id, ""))
	if file == "" or not OS.has_feature("web"):
		finished.emit.call_deferred(id, false)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var req := HTTPRequest.new()
	req.name = "Fetch_" + id
	# (64 KB a frame by default: 2 MB/s at the camp's 30 frames a second)
	req.download_chunk_size = 4 << 20
	# (User report: every fetch failed on the site. GitHub Pages sends the
	# packs gzipped; the browser has already unzipped them by the time
	# they're here, so Godot unzipping them again fails.)
	req.accept_gzip = false
	add_child(req)
	_busy[id] = req
	req.request_completed.connect(func(result, code, _headers, body: PackedByteArray):
		_fetched(id, file, body if result == HTTPRequest.RESULT_SUCCESS and code == 200 else PackedByteArray()))
	if req.request(_base_url() + "packs/" + file) != OK:
		_fetched(id, file, PackedByteArray())


## Fetches `id` and waits for it: true once it's here.
func wait_for(id: String) -> bool:
	if has(id):
		return true
	var got := [false, false]
	var on_done := func(which: String, ok: bool):
		if which == id:
			got[0] = true
			got[1] = ok
	finished.connect(on_done)
	fetch(id)
	while not got[0]:
		await get_tree().process_frame
	finished.disconnect(on_done)
	return got[1] and has(id)


func _process(_delta: float) -> void:
	for id in _busy:
		var req = _busy[id]
		if req is HTTPRequest:
			var total: int = req.get_body_size()
			progressed.emit(id, clampf(float(req.get_downloaded_bytes()) / total, 0.0, 1.0) if total > 0 else 0.0)


func _fetched(id: String, file: String, body: PackedByteArray) -> void:
	var req = _busy.get(id)
	_busy.erase(id)
	if req is Node:
		req.queue_free()
	if body.is_empty() and not _tried.has(id):
		_tried[id] = true
		_refetch.call_deferred(id)
		return
	_tried.erase(id)
	var ok := false
	if body.is_empty():
		push_warning("CharacterPacks: %s not fetched" % file)
	else:
		# Older ones of this character's go; this one's kept.
		var dir := DirAccess.open(DIR)
		if dir != null:
			for f in dir.get_files():
				if f.begins_with(id + "-") and f != file:
					dir.remove(f)
		ok = _keep(DIR + file, body) and has(id)
		# (The browser won't keep it - a private window, no room: kept only
		# till the page closes.)
		if not ok:
			ok = _keep("/tmp/" + file, body) and has(id)
		if not ok:
			push_warning("CharacterPacks: %s fetched but not kept (%s)" % [file, error_string(FileAccess.get_open_error())])
	finished.emit(id, ok)


## Once more - with the site's own list of them first (a game the browser
## kept from before the site last changed asks for packs no longer there).
func _refetch(id: String) -> void:
	var req := HTTPRequest.new()
	req.accept_gzip = false
	add_child(req)
	_busy[id] = true
	if req.request(_base_url() + "packs/packs.json?t=%d" % Time.get_ticks_msec()) == OK:
		var got: Array = await req.request_completed
		if got[0] == HTTPRequest.RESULT_SUCCESS and got[1] == 200:
			var data = JSON.parse_string((got[3] as PackedByteArray).get_string_from_utf8())
			if data is Dictionary:
				_manifest = data
	req.queue_free()
	_busy.erase(id)
	fetch(id)


func _keep(path: String, body: PackedByteArray) -> bool:
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(body)
	out.close()
	return _mount(path)


## (Its files only: the game's own copies of what the pack also carries -
## the project, the autoloads - are kept.)
func _mount(path: String) -> bool:
	return ProjectSettings.load_resource_pack(path, false)


func _pretend(id: String) -> void:
	_busy[id] = true
	var t := 0.0
	while t < pretend_time:
		await get_tree().process_frame
		t += get_process_delta_time()
		progressed.emit(id, clampf(t / maxf(pretend_time, 0.001), 0.0, 1.0))
	_busy.erase(id)
	missing.erase(id)
	finished.emit(id, true)


## The page's own address, without the page (the packs sit beside it).
func _base_url() -> String:
	var href := str(JavaScriptBridge.eval("window.location.href", true))
	href = href.split("#")[0].split("?")[0]
	return href.substr(0, href.rfind("/") + 1)


## A dark cover over `parent` saying what's being fetched, how far along;
## gone when it's done.
func cover(parent: Control, id: String) -> Control:
	var shade := ColorRect.new()
	shade.name = "PackCover"
	shade.color = Color(0.02, 0.027, 0.043, 0.96)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	centre.add_child(col)
	var text := UiKit.label("下載角色：%s" % Profile.character_name(id), 20, UiKit.GOLD_BRIGHT, true, 4)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(320, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	col.add_child(bar)
	parent.add_child(shade)
	var on_progress := func(which: String, ratio: float):
		if which == id and is_instance_valid(bar):
			bar.value = ratio
	progressed.connect(on_progress)
	shade.tree_exiting.connect(func(): progressed.disconnect(on_progress))
	return shade
