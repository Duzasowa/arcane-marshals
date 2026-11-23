extends TestSuite

## Guard: no file of the private placeholders ever enters the project. They are
## read only through PlaceholderAssets from a folder outside `res://`.

## Game archive formats that have no business in this project at all.
const FORBIDDEN_EXTENSIONS: Array[String] = ["dds", "pak", "xdb", "h5m", "h5c", "h5u"]
## Media whose name must not hint at the source game.
const MEDIA_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp", "tga", "bmp", "wav", "ogg", "mp3"]
const FORBIDDEN_NAME_PARTS: Array[String] = ["h5", "homm"]
## Hidden folders (.godot, .git) are skipped by DirAccess already.
const SKIPPED_DIRECTORIES: Array[String] = ["build", "dist", "exports"]
const PLACEHOLDER_FOLDER_NAME: String = "h5_placeholders"


func test_no_game_archive_or_named_media() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	expect_true(paths.size() > 10, "files found: %d" % paths.size())
	for path: String in paths:
		var extension: String = path.get_extension().to_lower()
		expect_false(FORBIDDEN_EXTENSIONS.has(extension), "%s has a forbidden extension" % path)
		if MEDIA_EXTENSIONS.has(extension):
			var file_name: String = path.get_file().to_lower()
			for part: String in FORBIDDEN_NAME_PARTS:
				expect_false(file_name.contains(part), "%s: media named with '%s'" % [path, part])


func test_placeholder_map_holds_only_relative_paths() -> void:
	expect_true(FileAccess.file_exists(PlaceholderAssets.MAP_PATH), "map exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PlaceholderAssets.MAP_PATH))
	expect_true(parsed is Dictionary, "map parses")
	if not parsed is Dictionary:
		return
	var values: Array[String] = []
	_collect_strings(parsed, values)
	for value: String in values:
		expect_true(PlaceholderAssets.is_safe_relative(value), "map path '%s' is relative" % value)
		expect_false(value.to_lower().contains(PLACEHOLDER_FOLDER_NAME), "map path '%s' names the folder" % value)


func test_project_files_do_not_name_the_folder() -> void:
	for path: String in ["res://project.godot", "res://export_presets.cfg"]:
		if FileAccess.file_exists(path):
			var text: String = FileAccess.get_file_as_string(path).to_lower()
			expect_false(text.contains(PLACEHOLDER_FOLDER_NAME), "%s names the placeholder folder" % path)


func test_screenshots_never_reach_the_build() -> void:
	# Screenshots may show placeholder art: the export skips them and Godot does not import them.
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	expect_true(presets.contains("reports/*"), "export excludes reports/")
	if DirAccess.dir_exists_absolute("res://reports"):
		expect_true(FileAccess.file_exists("res://reports/.gdignore"), "reports/ is hidden from the importer")


func _collect(directory_path: String, into: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	for subdirectory: String in directory.get_directories():
		if directory_path == "res://" and SKIPPED_DIRECTORIES.has(subdirectory):
			continue
		_collect(directory_path.path_join(subdirectory), into)
	for file_name: String in directory.get_files():
		into.append(directory_path.path_join(file_name))


func _collect_strings(value: Variant, into: Array[String]) -> void:
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			_collect_strings((value as Dictionary)[key], into)
	elif value is Array:
		for element: Variant in value:
			_collect_strings(element, into)
	elif value is String:
		into.append(value)
