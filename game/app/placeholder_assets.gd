class_name PlaceholderAssets
extends RefCounted

## Private stand-in 2D art and sounds for the prototype, read from a folder
## OUTSIDE the project (never `res://`) through the table
## `data/placeholder_map.json` (our id -> path relative to that folder).
##
## The folder is taken from the `AM_PLACEHOLDERS` environment variable, else
## from `user://settings.cfg` ([placeholders] path). Without it, or for an id
## or file it lacks, a texture is a neutral icon (a coloured square with the
## first letter of the id) and a sound is `null` (silence). A release build
## never reads the folder at all: these files must not ship.

const MAP_PATH: String = "res://data/placeholder_map.json"
const SETTINGS_PATH: String = "user://settings.cfg"
const ENV_ROOT: String = "AM_PLACEHOLDERS"
const NEUTRAL_SIZE: int = 64

const _GLYPH_SCALE: int = 6
const _GLYPH_WIDTH: int = 5
const _GLYPH_HEIGHT: int = 7
## 5x7 bitmap letters, one row per byte, bit 4 is the left column.
const _GLYPHS: Dictionary = {
	"A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
	"B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
	"C": [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
	"D": [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E],
	"E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
	"F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
	"G": [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F],
	"H": [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
	"I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
	"J": [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
	"K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
	"L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
	"M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
	"N": [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11],
	"O": [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
	"P": [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
	"Q": [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
	"R": [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
	"S": [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
	"T": [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
	"U": [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
	"V": [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
	"W": [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A],
	"X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
	"Y": [0x11, 0x11, 0x11, 0x0A, 0x04, 0x04, 0x04],
	"Z": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
	"0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
	"1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
	"2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
	"3": [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
	"4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
	"5": [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
	"6": [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
	"7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
	"8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
	"9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
	"?": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04],
}

static var _configured: bool = false
## Absolute path of the placeholder folder, or "" when there is none.
static var _root: String = ""
static var _map: Dictionary = {}
## "section/kind/id" -> Texture2D.
static var _textures: Dictionary = {}
## id -> AudioStream (or null: silence).
static var _sounds: Dictionary = {}


## Portrait of a hero or a creature (`kind` = &"hero", &"creature").
static func portrait(kind: StringName, id: StringName) -> Texture2D:
	return _texture("portrait", kind, id)


## Icon of a spell, skill, perk, artifact, resource… (`kind` names the table).
static func icon(kind: StringName, id: StringName) -> Texture2D:
	return _texture("icon", kind, id)


## A sound, or `null` when there is none (the caller plays nothing).
static func sound(id: StringName) -> AudioStream:
	_ensure_configured()
	if _sounds.has(id):
		return _sounds[id]
	var stream: AudioStream = null
	var path: String = _file_path(_lookup("sound", &"", id))
	if path != "":
		match path.get_extension().to_lower():
			"wav":
				stream = WavLoader.load(path)
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
	_sounds[id] = stream
	return stream


## True when the placeholder folder is found (and the build may read it).
static func is_available() -> bool:
	_ensure_configured()
	return _root != ""


## For tests: use this folder and table instead of the configured ones.
static func configure(root: String, map: Dictionary) -> void:
	_root = root
	_map = map
	_configured = true
	_textures.clear()
	_sounds.clear()


## Forgets the folder, the table and every cached file.
static func reset() -> void:
	_configured = false
	_root = ""
	_map = {}
	_textures.clear()
	_sounds.clear()


## A path the table may hold: relative, inside the folder, no `..`.
static func is_safe_relative(path: String) -> bool:
	if path == "" or path.begins_with("/") or path.begins_with("\\") or path.contains("://"):
		return false
	if path.length() >= 2 and path[1] == ":":
		return false
	for part: String in path.replace("\\", "/").split("/"):
		if part == "..":
			return false
	return true


## The neutral icon of `id`: a square coloured by the id, with its first letter.
## The same id always gives the same picture.
static func neutral_icon(id: String) -> ImageTexture:
	var image: Image = Image.create_empty(NEUTRAL_SIZE, NEUTRAL_SIZE, false, Image.FORMAT_RGBA8)
	var hue: float = float(posmod(id.hash(), 360)) / 360.0
	var fill: Color = Color.from_hsv(hue, 0.45, 0.55)
	image.fill(fill.darkened(0.45))
	image.fill_rect(Rect2i(3, 3, NEUTRAL_SIZE - 6, NEUTRAL_SIZE - 6), fill)
	var rows: Array = _GLYPHS.get(_first_letter(id), _GLYPHS["?"])
	var left: int = (NEUTRAL_SIZE - _GLYPH_WIDTH * _GLYPH_SCALE) / 2
	var top: int = (NEUTRAL_SIZE - _GLYPH_HEIGHT * _GLYPH_SCALE) / 2
	for row: int in _GLYPH_HEIGHT:
		var bits: int = rows[row]
		for column: int in _GLYPH_WIDTH:
			if (bits & (1 << (_GLYPH_WIDTH - 1 - column))) != 0:
				image.fill_rect(Rect2i(left + column * _GLYPH_SCALE, top + row * _GLYPH_SCALE, _GLYPH_SCALE, _GLYPH_SCALE), Color(0.95, 0.95, 0.92))
	return ImageTexture.create_from_image(image)


static func _texture(section: String, kind: StringName, id: StringName) -> Texture2D:
	_ensure_configured()
	var key: String = "%s/%s/%s" % [section, kind, id]
	if _textures.has(key):
		return _textures[key]
	var texture: Texture2D = null
	var path: String = _file_path(_lookup(section, kind, id))
	if path != "":
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		texture = neutral_icon(String(id))
	_textures[key] = texture
	return texture


## Absolute path of a table entry inside the folder, or "" if it cannot be read.
static func _file_path(relative: String) -> String:
	if _root == "" or relative == "":
		return ""
	var path: String = _root.path_join(relative)
	return path if FileAccess.file_exists(path) else ""


## The table entry `section` / `kind` / `id` (no `kind` level when it is empty).
static func _lookup(section: String, kind: StringName, id: StringName) -> String:
	var table: Variant = _map.get(section, {})
	if kind != &"":
		table = (table as Dictionary).get(String(kind), {}) if table is Dictionary else {}
	if not table is Dictionary:
		return ""
	var entry: Variant = (table as Dictionary).get(String(id), "")
	if not entry is String:
		return ""
	var relative: String = entry
	if relative != "" and not is_safe_relative(relative):
		push_warning("PlaceholderAssets: ignored unsafe path for %s/%s/%s" % [section, kind, id])
		return ""
	return relative


static func _ensure_configured() -> void:
	if _configured:
		return
	_configured = true
	_map = _load_map()
	_root = _find_root()


static func _find_root() -> String:
	if not OS.is_debug_build():
		return ""
	var path: String = OS.get_environment(ENV_ROOT)
	if path == "":
		var settings: ConfigFile = ConfigFile.new()
		if settings.load(SETTINGS_PATH) == OK:
			path = str(settings.get_value("placeholders", "path", ""))
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return ""
	return path


static func _load_map() -> Dictionary:
	if not FileAccess.file_exists(MAP_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	return parsed if parsed is Dictionary else {}


static func _first_letter(id: String) -> String:
	for index: int in id.length():
		var letter: String = id[index].to_upper()
		if _GLYPHS.has(letter):
			return letter
	return "?"
