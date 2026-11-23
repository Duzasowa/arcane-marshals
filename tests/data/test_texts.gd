extends TestSuite

## Every text key used by the data has a Ukrainian line, the CSV files have no
## duplicate keys, and the project registers the translations.

const UK_CSV: String = "res://data/text/uk.csv"
const EN_CSV: String = "res://data/text/en.csv"
const UK_TRANSLATION: String = "res://data/text/uk.uk.translation"


func test_every_data_key_has_ukrainian_text() -> void:
	var data: GameData = GameData.new()
	data.load_all()
	var keys: Dictionary[String, String] = _read_csv(UK_CSV)
	for def: GameDef in data.all_defs():
		expect_true(keys.has(String(def.name_key)), "%s name_key %s in uk.csv" % [def.id, def.name_key])
		if not def.desc_key.is_empty():
			expect_true(keys.has(String(def.desc_key)), "%s desc_key %s in uk.csv" % [def.id, def.desc_key])


func test_csv_keys_are_unique_and_filled() -> void:
	for path: String in [UK_CSV, EN_CSV]:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		file.get_csv_line()
		var seen: Dictionary[String, bool] = {}
		while not file.eof_reached():
			var row: PackedStringArray = file.get_csv_line()
			if row.size() == 1 and row[0].is_empty():
				continue
			expect_true(row.size() == 2 and not row[1].strip_edges().is_empty(), "%s: %s has text" % [path, row[0]])
			expect_false(seen.has(row[0]), "%s: %s once" % [path, row[0]])
			seen[row[0]] = true


func test_english_has_no_stray_keys() -> void:
	var uk: Dictionary[String, String] = _read_csv(UK_CSV)
	for key: String in _read_csv(EN_CSV):
		expect_true(uk.has(key), "en key %s exists in uk.csv" % key)


func test_translation_server_speaks_ukrainian() -> void:
	var translation: Translation = load(UK_TRANSLATION)
	expect_true(translation != null, "uk translation imported")
	if translation != null:
		expect_eq("Ополченець", String(translation.get_message(&"UNIT_THRONE_MILITIA_NAME")), "resource has the line")
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("uk")
	expect_eq("Ополченець", String(TranslationServer.translate(&"UNIT_THRONE_MILITIA_NAME")), "project translation registered")
	TranslationServer.set_locale(previous)


func _read_csv(path: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		fail("cannot open %s" % path)
		return result
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2:
			result[row[0]] = row[1]
	return result
