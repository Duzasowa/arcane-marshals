extends Control

## Splash stand-in until the main menu (Ф11): the title, the version, and the
## way into the quick battle.

@onready var _version_label: Label = $Center/Box/Version
@onready var _box: VBoxContainer = $Center/Box


func _ready() -> void:
	AppSettings.apply_locale()
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_add_button(&"UI_MENU_QUICK_BATTLE", func() -> void:
		get_tree().change_scene_to_file(BattleLaunch.QUICK_BATTLE_SCENE))
	_add_button(&"UI_MENU_QUIT", func() -> void: get_tree().quit())


func _add_button(text_key: StringName, action: Callable) -> void:
	var button: Button = Button.new()
	button.name = String(text_key)
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(320.0, 52.0)
	button.add_theme_font_size_override(&"font_size", 24)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	_box.add_child(button)
