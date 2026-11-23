extends SceneTree

## A picture of one scene without playing it:
##   godot --path . -s scripts/screenshot.gd -- [scene] [out.png] [frames]
## Defaults: the splash scene, `user://screenshot.png`, 30 frames to settle.
## Needs a window (not --headless): a headless run renders nothing.
## The base for the screenshot scripts of later phases.

const DEFAULT_SCENE: String = "res://game/app/main.tscn"
const DEFAULT_OUTPUT: String = "user://screenshot.png"
const DEFAULT_FRAMES: int = 30

var _output: String = DEFAULT_OUTPUT
var _frames_left: int = DEFAULT_FRAMES


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	if args.size() > 1:
		_output = args[1]
	if args.size() > 2:
		_frames_left = maxi(1, args[2].to_int())
	var scene: PackedScene = load(scene_path)
	if scene == null:
		printerr("screenshot: cannot load %s" % scene_path)
		quit(1)
		return
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(_output)
	if error != OK:
		printerr("screenshot: cannot save %s (error %d)" % [_output, error])
		quit(1)
		return true
	print("saved %s (%dx%d)" % [ProjectSettings.globalize_path(_output), image.get_width(), image.get_height()])
	return true
