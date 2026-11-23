extends SceneTree

## Headless test runner:
##   godot --headless --path . -s tests/test_runner.gd [-- name_filter]
## Finds every `tests/**/test_*.gd` whose class extends TestSuite and runs its
## `test_*()` methods. Exit code 0 when everything passes, 1 otherwise.

const TESTS_ROOT: String = "res://tests"


func _initialize() -> void:
	var name_filter: String = ""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		name_filter = user_args[0]

	var passed_count: int = 0
	var failed_count: int = 0
	var suite_paths: Array[String] = []
	_collect_suite_paths(TESTS_ROOT, suite_paths)
	suite_paths.sort()

	print("Running headless tests...")
	for path: String in suite_paths:
		var script: GDScript = load(path)
		# A script with a parse error loads but cannot be instantiated; calling
		# `new()` on it would abort this function and leave the run hanging.
		if script == null or not script.can_instantiate():
			failed_count += 1
			printerr("[FAIL] %s: failed to load" % path)
			continue
		var instance: Variant = script.new()
		if not instance is TestSuite:
			failed_count += 1
			printerr("[FAIL] %s: does not extend TestSuite" % path)
			continue
		var suite: TestSuite = instance
		var suite_name: String = path.get_file().get_basename()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var full_name: String = "%s.%s" % [suite_name, method_name]
			if name_filter != "" and not full_name.contains(name_filter):
				continue
			suite.begin_test()
			await suite.call(method_name)
			var failures: Array[String] = suite.take_failures()
			if failures.is_empty():
				passed_count += 1
				print("[PASS] %s" % full_name)
			else:
				failed_count += 1
				printerr("[FAIL] %s" % full_name)
				for failure: String in failures:
					printerr("       %s" % failure)

	print("")
	print("Test summary: passed=%d, failed=%d, total=%d" % [passed_count, failed_count, passed_count + failed_count])
	quit(0 if failed_count == 0 and passed_count > 0 else 1)


func _collect_suite_paths(directory_path: String, into: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	for subdirectory: String in directory.get_directories():
		_collect_suite_paths(directory_path.path_join(subdirectory), into)
	for file_name: String in directory.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_runner.gd" and file_name != "test_suite.gd":
			into.append(directory_path.path_join(file_name))
