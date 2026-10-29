extends SceneTree

## godot --headless --path . -s tools/raster_svg.gd -- IN.svg OUT.png [SIZE]
## An SVG drawn to a PNG (the icon tools' one step that needs it).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var size := int(args[2]) if args.size() > 2 else 256
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(args[0]), float(size) / 128.0)
	img.save_png(args[1])
	quit()
