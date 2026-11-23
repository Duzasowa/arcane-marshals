extends Control

## Quick battle: pick two armies from the units in `data/`, who plays each side
## (player / bot and how well the bot plays) and the seed, then fight. For hand
## checks and demos.

const SLOT_COUNT: int = BattleSideSetup.MAX_SLOTS
const MAX_COUNT: int = 999
## Item order of the difficulty pick = `BattleAi.Difficulty`.
const LEVEL_KEYS: Array[StringName] = [&"UI_AI_EASY", &"UI_AI_NORMAL", &"UI_AI_HARD"]

var _data: GameData = GameData.new()
var _unit_ids: Array[StringName] = []
## Per side: per slot [OptionButton, SpinBox].
var _slots: Array[Array] = [[], []]
var _human: Array[CheckButton] = []
var _level: Array[OptionButton] = []
var _power: Array[Label] = []
var _seed: SpinBox = null


func _ready() -> void:
	AppSettings.apply_locale()
	_data.load_all()
	for unit: UnitDef in _data.units.values():
		_unit_ids.append(unit.id)
	_build()
	if BattleLaunch.is_set():
		_fill_from(BattleLaunch.attacker, BattleLaunch.defender)
	else:
		_demo()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.07, 0.075, 0.1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = tr(&"UI_QUICK_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 44)
	title.add_theme_color_override(&"font_color", Color(0.92, 0.84, 0.6))
	box.add_child(title)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 48)
	box.add_child(columns)
	for side: int in BattleState.SIDE_COUNT:
		columns.add_child(_side_column(side))
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override(&"separation", 16)
	box.add_child(footer)
	var seed_label: Label = Label.new()
	seed_label.text = tr(&"UI_QUICK_SEED")
	footer.add_child(seed_label)
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 999999
	_seed.value = BattleLaunch.seed_value
	footer.add_child(_seed)
	footer.add_child(_button(&"UI_QUICK_RANDOM", func() -> void: _seed.value = randi_range(1, 999999)))
	footer.add_child(_button(&"UI_QUICK_DEMO", _demo))
	var start: Button = _button(&"UI_QUICK_START", _start)
	start.name = "Start"
	start.custom_minimum_size = Vector2(200.0, 48.0)
	footer.add_child(start)
	footer.add_child(_button(&"UI_RESULT_BACK", func() -> void:
		get_tree().change_scene_to_file("res://game/app/main.tscn")))


func _side_column(side: int) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var name_label: Label = Label.new()
	name_label.text = tr(&"UI_SIDE_ATTACKER" if side == 0 else &"UI_SIDE_DEFENDER").capitalize()
	name_label.add_theme_font_size_override(&"font_size", 24)
	name_label.add_theme_color_override(&"font_color", StackView.SIDE_COLORS[side])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var human: CheckButton = CheckButton.new()
	human.text = tr(&"UI_QUICK_HUMAN")
	human.button_pressed = BattleLaunch.human[side]
	header.add_child(human)
	_human.append(human)
	var level: OptionButton = OptionButton.new()
	level.tooltip_text = tr(&"UI_QUICK_DIFFICULTY")
	for key: StringName in LEVEL_KEYS:
		level.add_item(tr(key))
	level.select(clampi(BattleLaunch.ai_level[side], 0, LEVEL_KEYS.size() - 1))
	level.disabled = human.button_pressed
	human.toggled.connect(func(on: bool) -> void: level.disabled = on)
	header.add_child(level)
	_level.append(level)
	for slot: int in SLOT_COUNT:
		var row: HBoxContainer = HBoxContainer.new()
		column.add_child(row)
		var unit_pick: OptionButton = OptionButton.new()
		unit_pick.custom_minimum_size = Vector2(260.0, 0.0)
		unit_pick.add_item(tr(&"UI_QUICK_EMPTY"))
		for unit_id: StringName in _unit_ids:
			unit_pick.add_item(tr(_data.unit(unit_id).name_key))
		unit_pick.item_selected.connect(func(_index: int) -> void: _update_power())
		row.add_child(unit_pick)
		var count: SpinBox = SpinBox.new()
		count.min_value = 1
		count.max_value = MAX_COUNT
		count.value_changed.connect(func(_value: float) -> void: _update_power())
		row.add_child(count)
		_slots[side].append([unit_pick, count])
	var power: Label = Label.new()
	power.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.8))
	column.add_child(power)
	_power.append(power)
	return column


func _button(text_key: StringName, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(text_key)
	button.custom_minimum_size = Vector2(0.0, 40.0)
	button.pressed.connect(action)
	return button


func _demo() -> void:
	BattleLaunch.demo()
	_fill_from(BattleLaunch.attacker, BattleLaunch.defender)


func _fill_from(attacker: BattleSideSetup, defender: BattleSideSetup) -> void:
	var setups: Array[BattleSideSetup] = [attacker, defender]
	for side: int in BattleState.SIDE_COUNT:
		for slot: int in SLOT_COUNT:
			var unit_pick: OptionButton = _slots[side][slot][0]
			var count: SpinBox = _slots[side][slot][1]
			var index: int = _unit_ids.find(setups[side].slot_units[slot])
			unit_pick.select(index + 1)
			count.set_value_no_signal(maxi(1, setups[side].slot_counts[slot]))
	_update_power()


func _setup_of(side: int) -> BattleSideSetup:
	var setup: BattleSideSetup = BattleSideSetup.new()
	for slot: int in SLOT_COUNT:
		var unit_pick: OptionButton = _slots[side][slot][0]
		var count: SpinBox = _slots[side][slot][1]
		if unit_pick.selected > 0:
			setup.set_slot(slot, _unit_ids[unit_pick.selected - 1], int(count.value))
	return setup


func _update_power() -> void:
	for side: int in BattleState.SIDE_COUNT:
		var setup: BattleSideSetup = _setup_of(side)
		var total: int = 0
		for slot: int in SLOT_COUNT:
			if setup.slot_units[slot] != &"":
				total += PowerEstimator.power(_data.unit(setup.slot_units[slot]), _data) * setup.slot_counts[slot]
		_power[side].text = tr(&"UI_QUICK_POWER") % total


func _start() -> void:
	var attacker: BattleSideSetup = _setup_of(0)
	var defender: BattleSideSetup = _setup_of(1)
	if attacker.is_empty() or defender.is_empty():
		return
	BattleLaunch.attacker = attacker
	BattleLaunch.defender = defender
	BattleLaunch.seed_value = int(_seed.value)
	BattleLaunch.human = [_human[0].button_pressed, _human[1].button_pressed]
	BattleLaunch.ai_level = [_level[0].selected, _level[1].selected]
	BattleLaunch.return_scene = BattleLaunch.QUICK_BATTLE_SCENE
	get_tree().change_scene_to_file(BattleLaunch.BATTLE_SCENE)
