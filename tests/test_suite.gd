class_name TestSuite
extends RefCounted

## Base for headless test suites. The runner calls every `test_*()` method;
## a test fails if any `expect_*` call inside it fails.

var _failures: Array[String] = []


func begin_test() -> void:
	_failures.clear()


func take_failures() -> Array[String]:
	var failures: Array[String] = _failures.duplicate()
	_failures.clear()
	return failures


func fail(message: String) -> void:
	_failures.append(message)


func expect_true(condition: bool, label: String) -> void:
	if not condition:
		fail("%s: expected true" % label)


func expect_false(condition: bool, label: String) -> void:
	if condition:
		fail("%s: expected false" % label)


func expect_eq(expected: Variant, actual: Variant, label: String) -> void:
	if typeof(expected) != typeof(actual) or expected != actual:
		fail("%s: expected %s, got %s" % [label, var_to_str(expected), var_to_str(actual)])


func expect_ne(unexpected: Variant, actual: Variant, label: String) -> void:
	if typeof(unexpected) == typeof(actual) and unexpected == actual:
		fail("%s: expected anything but %s" % [label, var_to_str(unexpected)])


func expect_between(low: int, high: int, actual: int, label: String) -> void:
	if actual < low or actual > high:
		fail("%s: expected %d..%d, got %d" % [label, low, high, actual])
