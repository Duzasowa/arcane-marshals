extends TestSuite


class _Sample:
	extends RefCounted
	const HASH_SKIPPED_FIELDS: Array[StringName] = [&"_cache"]
	var cells: PackedInt32Array = PackedInt32Array([1, 2, 3])
	var names: Dictionary = {"a": 1}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var _cache: int = 0


func _make_sample() -> _Sample:
	var sample: _Sample = _Sample.new()
	sample.rng.seed = 42
	return sample


func test_equal_states_have_equal_digests() -> void:
	expect_eq(StateHasher.digest(_make_sample()), StateHasher.digest(_make_sample()), "digest")


func test_changed_field_changes_digest() -> void:
	var changed: _Sample = _make_sample()
	changed.cells[1] = 99
	expect_ne(StateHasher.digest(_make_sample()), StateHasher.digest(changed), "digest")


func test_rng_state_is_hashed() -> void:
	var advanced: _Sample = _make_sample()
	advanced.rng.randi()
	expect_ne(StateHasher.digest(_make_sample()), StateHasher.digest(advanced), "digest")


func test_skipped_field_is_ignored() -> void:
	var cached: _Sample = _make_sample()
	cached._cache = 123
	expect_eq(StateHasher.digest(_make_sample()), StateHasher.digest(cached), "digest")


func test_field_digests_name_the_differing_field() -> void:
	var changed: _Sample = _make_sample()
	changed.names["b"] = 2
	var expected: Dictionary = StateHasher.field_digests(_make_sample())
	var actual: Dictionary = StateHasher.field_digests(changed)
	expect_eq(expected[&"cells"], actual[&"cells"], "cells digest")
	expect_ne(expected[&"names"], actual[&"names"], "names digest")
	expect_false(actual.has(&"_cache"), "skipped field listed")
