class_name AppSettings
extends RefCounted

## Player settings kept in `user://settings.cfg`. For now only the language:
## Ukrainian unless the file says otherwise (the settings screen comes in Ф11).

const PATH: String = "user://settings.cfg"
const DEFAULT_LOCALE: String = "uk"
const LOCALES: Array[String] = ["uk", "en"]


static func locale() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		return DEFAULT_LOCALE
	var value: String = str(config.get_value("app", "locale", DEFAULT_LOCALE))
	return value if LOCALES.has(value) else DEFAULT_LOCALE


static func apply_locale() -> void:
	TranslationServer.set_locale(locale())
