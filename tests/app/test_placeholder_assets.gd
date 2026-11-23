extends TestSuite

## PlaceholderAssets against a temporary folder in `user://` (never the real
## placeholder folder: the tests must pass on a machine without it).

const TEMP_DIR: String = "user://test_placeholders"


func _temp_root() -> String:
	var root: String = ProjectSettings.globalize_path(TEMP_DIR)
	DirAccess.make_dir_recursive_absolute(root.path_join("icons"))
	var image: Image = Image.create_empty(20, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	image.save_png(root.path_join("icons/sample.png"))
	return root


func _map() -> Dictionary:
	return {
		"portrait": {"hero": {"knight": "icons/sample.png", "lost": "icons/missing.png"}},
		"icon": {"spell": {"escape": "../outside.png", "absolute": "C:/outside.png"}},
		"sound": {"hit": "sounds/missing.wav"},
	}


func test_without_folder_textures_are_neutral() -> void:
	PlaceholderAssets.configure("", _map())
	var texture: Texture2D = PlaceholderAssets.portrait(&"hero", &"knight")
	expect_true(texture != null, "texture exists")
	expect_eq(PlaceholderAssets.NEUTRAL_SIZE, texture.get_width(), "neutral width")
	expect_eq(PlaceholderAssets.NEUTRAL_SIZE, texture.get_height(), "neutral height")
	expect_false(PlaceholderAssets.is_available(), "available")
	PlaceholderAssets.reset()


func test_file_from_folder_is_loaded() -> void:
	PlaceholderAssets.configure(_temp_root(), _map())
	var texture: Texture2D = PlaceholderAssets.portrait(&"hero", &"knight")
	expect_eq(20, texture.get_width(), "loaded width")
	expect_eq(12, texture.get_height(), "loaded height")
	expect_true(PlaceholderAssets.portrait(&"hero", &"knight") == texture, "cached")
	PlaceholderAssets.reset()


func test_missing_file_or_entry_is_neutral() -> void:
	PlaceholderAssets.configure(_temp_root(), _map())
	expect_eq(PlaceholderAssets.NEUTRAL_SIZE, PlaceholderAssets.portrait(&"hero", &"lost").get_width(), "missing file")
	expect_eq(PlaceholderAssets.NEUTRAL_SIZE, PlaceholderAssets.icon(&"skill", &"nothing").get_width(), "missing entry")
	PlaceholderAssets.reset()


func test_unsafe_paths_are_ignored() -> void:
	PlaceholderAssets.configure(_temp_root(), _map())
	expect_eq(PlaceholderAssets.NEUTRAL_SIZE, PlaceholderAssets.icon(&"spell", &"escape").get_width(), "dot-dot path")
	expect_eq(PlaceholderAssets.NEUTRAL_SIZE, PlaceholderAssets.icon(&"spell", &"absolute").get_width(), "absolute path")
	expect_false(PlaceholderAssets.is_safe_relative("../a.png"), "dot-dot")
	expect_false(PlaceholderAssets.is_safe_relative("D:/a.png"), "drive")
	expect_false(PlaceholderAssets.is_safe_relative("/a.png"), "root")
	expect_false(PlaceholderAssets.is_safe_relative("res://a.png"), "scheme")
	expect_true(PlaceholderAssets.is_safe_relative("icons/spells/a.png"), "relative")
	PlaceholderAssets.reset()


func test_missing_sound_is_silence() -> void:
	PlaceholderAssets.configure(_temp_root(), _map())
	expect_true(PlaceholderAssets.sound(&"hit") == null, "missing sound")
	expect_true(PlaceholderAssets.sound(&"unknown") == null, "unknown sound")
	PlaceholderAssets.reset()


func test_neutral_icon_is_stable_per_id() -> void:
	var first: Image = PlaceholderAssets.neutral_icon("griffin").get_image()
	var again: Image = PlaceholderAssets.neutral_icon("griffin").get_image()
	var other: Image = PlaceholderAssets.neutral_icon("archer").get_image()
	expect_eq(first.get_data(), again.get_data(), "same id")
	expect_ne(first.get_data(), other.get_data(), "other id")
