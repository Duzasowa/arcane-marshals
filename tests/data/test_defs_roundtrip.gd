extends TestSuite

## Every definition type survives ResourceSaver -> load: typed dictionaries,
## typed arrays, enums and nested zones come back equal.

const DIRECTORY: String = "user://test_defs_roundtrip"


func test_every_type_round_trips() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	for def: GameDef in DataSamples.all():
		var path: String = DIRECTORY.path_join("%s.tres" % def.id)
		expect_eq(OK, ResourceSaver.save(def, path), "%s saves" % def.id)
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		expect_true(loaded != null and loaded.get_script() == def.get_script(), "%s loads as its class" % def.id)
		if loaded != null:
			_expect_same(def, loaded, String(def.id))
		DirAccess.remove_absolute(path)


func test_typed_containers_stay_typed() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var path: String = DIRECTORY.path_join("typed.tres")
	ResourceSaver.save(DataSamples.unit(), path)
	var loaded: UnitDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as UnitDef
	expect_true(loaded != null, "unit loads")
	if loaded != null:
		expect_true(loaded.cost.is_typed(), "cost stays a typed dictionary")
		expect_true(loaded.abilities.is_typed(), "abilities stay a typed array")
		expect_eq(TYPE_STRING_NAME, typeof(loaded.cost.keys()[0]), "cost keys are StringName")
	DirAccess.remove_absolute(path)


func _expect_same(expected: Variant, actual: Variant, label: String) -> void:
	if expected is Resource:
		if not actual is Resource:
			fail("%s: resource expected" % label)
			return
		for property: Dictionary in (expected as Resource).get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var field: String = property["name"]
			_expect_same((expected as Resource).get(field), (actual as Resource).get(field), "%s.%s" % [label, field])
	elif expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		expect_eq(expected_array.size(), actual_array.size(), "%s size" % label)
		for index: int in mini(expected_array.size(), actual_array.size()):
			_expect_same(expected_array[index], actual_array[index], "%s[%d]" % [label, index])
	else:
		expect_eq(expected, actual, label)
