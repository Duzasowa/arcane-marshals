extends TestSuite

## Every script of the game and of the measurements parses. The other tests
## load only what they use: a script of the UI or a measurement can be broken
## by a renamed function without any of them noticing.

const ROOTS: Array[String] = ["res://game", "res://scripts"]
## Raise as the game grows, so a broken directory walk cannot pass silently.
const MIN_SCRIPTS: int = 55


func test_every_script_parses() -> void:
	var paths: Array[String] = []
	for root: String in ROOTS:
		_collect(root, paths)
	expect_true(paths.size() >= MIN_SCRIPTS, "scripts found: %d" % paths.size())
	for path: String in paths:
		var script: GDScript = load(path)
		expect_true(script != null and script.can_instantiate(), "%s parses" % path)


func _collect(directory_path: String, into: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	for subdirectory: String in directory.get_directories():
		_collect(directory_path.path_join(subdirectory), into)
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			into.append(directory_path.path_join(file_name))
