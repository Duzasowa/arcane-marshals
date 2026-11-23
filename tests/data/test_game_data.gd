extends TestSuite

## GameData loads every type from a directory, reports duplicates and stray
## resources, and loads the real data/ without errors.

const DIRECTORY: String = "user://test_game_data"


func test_real_data_loads() -> void:
	var data: GameData = GameData.new()
	expect_true(data.load_all(), "data/ loads: %s" % [data.errors])


func test_every_type_loads_from_files() -> void:
	var root: String = _fresh_directory("all")
	var samples: Array[GameDef] = DataSamples.all()
	for def: GameDef in samples:
		ResourceSaver.save(def, root.path_join("%s/%s.tres" % [GameData.kind_of(def), def.id]))
	_write_text(root.path_join("notes.json"), "{}")
	var data: GameData = GameData.new()
	expect_true(data.load_all(root), "loads: %s" % [data.errors])
	expect_eq(samples.size(), data.all_defs().size(), "every sample registered")
	for def: GameDef in samples:
		var table: Dictionary = data.tables()[GameData.kind_of(def)]
		expect_true(table.has(def.id), "%s registered" % def.id)
	expect_eq(&"sample_faction", data.unit(&"sample_unit").faction, "unit lookup")


func test_duplicate_id_is_an_error() -> void:
	var root: String = _fresh_directory("dup")
	var first: UnitDef = DataSamples.unit()
	var second: UnitDef = DataSamples.unit()
	second.hp = 99
	ResourceSaver.save(first, root.path_join("a.tres"))
	ResourceSaver.save(second, root.path_join("b.tres"))
	var data: GameData = GameData.new()
	expect_false(data.load_all(root), "duplicate fails")
	expect_eq(1, data.errors.size(), "one error")
	expect_true(data.errors.size() == 1 and data.errors[0].contains("duplicate unit id 'sample_unit'"), "names the id")
	expect_eq(11, data.unit(&"sample_unit").hp, "first file wins (sorted order)")


func test_same_id_in_different_types_is_fine() -> void:
	var data: GameData = GameData.new()
	var unit: UnitDef = DataSamples.unit()
	var ability: AbilityDef = DataSamples.ability()
	ability.id = unit.id
	expect_true(data.add(unit) and data.add(ability), "ids are per type")


func test_stray_resource_and_empty_id_are_errors() -> void:
	var root: String = _fresh_directory("stray")
	ResourceSaver.save(MapZoneDef.new(), root.path_join("zone.tres"))
	ResourceSaver.save(UnitDef.new(), root.path_join("unit.tres"))
	var data: GameData = GameData.new()
	expect_false(data.load_all(root), "fails")
	expect_eq(2, data.errors.size(), "two errors: %s" % [data.errors])


func test_units_of_faction_order() -> void:
	var data: GameData = GameData.new()
	var upgraded: UnitDef = DataSamples.upgraded_unit()
	var low: UnitDef = DataSamples.unit()
	low.id = &"sample_low"
	low.tier = 1
	data.add(upgraded)
	data.add(DataSamples.unit())
	data.add(low)
	var ids: Array[StringName] = []
	for def: UnitDef in data.units_of_faction(&"sample_faction"):
		ids.append(def.id)
	expect_eq([&"sample_low", &"sample_unit", &"sample_unit_up"], ids, "tier, base before upgrade")


func _fresh_directory(name: String) -> String:
	var root: String = DIRECTORY.path_join(name)
	_remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root)
	for kind: StringName in GameData.new().tables().keys():
		DirAccess.make_dir_recursive_absolute(root.path_join(kind))
	return root


func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for subdirectory: String in directory.get_directories():
		_remove_tree(path.path_join(subdirectory))
	for file_name: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
