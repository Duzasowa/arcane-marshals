class_name BattleHud
extends Control

## The 2D layer of the battle screen: count badges over the stacks, the
## initiative line, the action buttons, the stack panel, the hit forecast at
## the cursor and the battle log. Reads the state and the views; actions go
## out through `action_pressed`, never into the state.

signal action_pressed(action: StringName)
## The stack under the cursor on the initiative line (-1 — none).
signal slot_hovered(stack_id: int)

const QUEUE_LENGTH: int = 10
const PORTRAIT_SIZE: int = 72
const LOG_LINES: int = 200
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const PANEL_COLOR: Color = Color(0.08, 0.08, 0.1, 0.82)

var _state: BattleState = null
var _data: GameData = null
var _view: BattleView = null
var _camera: BattleCamera = null
var _badges: Dictionary[int, Control] = {}
var _badge_layer: Control = null
var _queue_box: HBoxContainer = null
var _stack_panel: Label = null
var _cursor_label: Label = null
var _cursor_panel: PanelContainer = null
var _log_panel: PanelContainer = null
var _log: RichTextLabel = null
var _status: Label = null
var _auto_button: Button = null
var _grid_button: Button = null
var _speed_button: Button = null
var _speed_index: int = 0
## Where the cursor text sits when not following the mouse (scripts, screenshots); x < 0 — follow.
var cursor_pin: Vector2 = Vector2(-1.0, -1.0)
var _buttons: Array[Button] = []


func setup(state: BattleState, data: GameData, view: BattleView, camera: BattleCamera) -> void:
	_state = state
	_data = data
	_view = view
	_camera = camera
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_layer = Control.new()
	_badge_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge_layer)
	for stack: BattleStack in state.stacks:
		_badges[stack.id] = _make_badge(stack.side)
		_badge_layer.add_child(_badges[stack.id])
	# Layout: a top row (hint, status), free space, a bottom row (stack panel,
	# initiative line, actions); the log and the cursor text float on top.
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side_name: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side_name, 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top: HBoxContainer = _row()
	column.add_child(top)
	var middle: Control = Control.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var bottom: HBoxContainer = _row()
	column.add_child(bottom)
	_build_top(top)
	bottom.add_child(_build_stack_panel())
	bottom.add_child(_build_queue())
	bottom.add_child(_build_actions())
	_build_log()
	_build_cursor()
	refresh()


## Re-reads the initiative line and the active stack.
func refresh() -> void:
	for child: Node in _queue_box.get_children():
		child.queue_free()
	for stack_id: int in AtbTimeline.forecast(_state, QUEUE_LENGTH):
		_queue_box.add_child(_make_slot(_state.stack(stack_id), _queue_box.get_child_count() == 0))
	show_stack(_state.active_stack())


func show_stack(stack: BattleStack) -> void:
	if stack == null:
		_stack_panel.get_parent().visible = false
		return
	_stack_panel.get_parent().visible = true
	var lines: PackedStringArray = PackedStringArray()
	lines.append(unit_name(stack.unit_id))
	lines.append("%s: %d" % [tr(&"UI_STAT_COUNT"), stack.count])
	lines.append("%s: %d   %s: %d" % [tr(&"UI_STAT_ATTACK"), stack.attack, tr(&"UI_STAT_DEFENCE"), stack.defence])
	lines.append("%s: %d–%d" % [tr(&"UI_STAT_DAMAGE"), stack.min_dmg, stack.max_dmg])
	lines.append("%s: %d / %d" % [tr(&"UI_STAT_HP"), stack.top_hp, stack.hp])
	lines.append("%s: %d   %s: %d" % [tr(&"UI_STAT_SPEED"), stack.speed, tr(&"UI_STAT_INITIATIVE"), stack.initiative])
	if stack.is_shooter():
		lines.append("%s: %d / %d" % [tr(&"UI_STAT_SHOTS"), stack.shots_left, stack.shots])
	if stack.defending:
		lines.append(tr(&"UI_STAT_DEFENDING"))
	_stack_panel.text = "\n".join(lines)


## The text at the cursor (action and forecast); "" hides it.
func set_cursor_text(text: String) -> void:
	_cursor_label.text = text
	_cursor_panel.visible = text != ""


func set_status(text: String) -> void:
	_status.text = text
	_status.get_parent().visible = text != ""


func set_auto(on: bool) -> void:
	_auto_button.set_pressed_no_signal(on)


func set_grid(on: bool) -> void:
	_grid_button.set_pressed_no_signal(on)


func set_actions_enabled(on: bool) -> void:
	for button: Button in _buttons:
		if button != _auto_button and button != _grid_button and button != _speed_button:
			button.disabled = not on


func speed() -> float:
	return SPEEDS[_speed_index]


func add_log(line: String) -> void:
	_log.append_text(line + "\n")
	if _log.get_paragraph_count() > LOG_LINES:
		_log.remove_paragraph(0)


func unit_name(unit_id: StringName) -> String:
	var unit: UnitDef = _data.unit(unit_id)
	return tr(unit.name_key) if unit != null else String(unit_id)


## The log line of one event ("" — not logged).
func describe(event: BattleEvent) -> String:
	var actor: String = _stack_name(event.stack_id)
	var target: String = _stack_name(event.target_id)
	match event.kind:
		BattleEvent.Kind.TURN_STARTED:
			return "[color=#9aa]" + tr(&"UI_LOG_TURN") % actor + "[/color]"
		BattleEvent.Kind.MOVED:
			return tr(&"UI_LOG_MOVE") % actor
		BattleEvent.Kind.ATTACKED:
			return tr(&"UI_LOG_ATTACK") % [actor, target]
		BattleEvent.Kind.SHOT:
			return tr(&"UI_LOG_SHOOT") % [actor, target]
		BattleEvent.Kind.RETALIATED:
			return tr(&"UI_LOG_RETALIATE") % [actor, target]
		BattleEvent.Kind.DAMAGED:
			return "  " + tr(&"UI_LOG_DAMAGE") % [target, event.damage, event.killed]
		BattleEvent.Kind.DIED:
			return "[color=#f88]" + tr(&"UI_LOG_DIED") % actor + "[/color]"
		BattleEvent.Kind.WAITED:
			return tr(&"UI_LOG_WAIT") % actor
		BattleEvent.Kind.DEFENDED:
			return tr(&"UI_LOG_DEFEND") % actor
		BattleEvent.Kind.MORALE_GOOD:
			return "[color=#8f8]" + tr(&"UI_LOG_MORALE_GOOD") % actor + "[/color]"
		BattleEvent.Kind.MORALE_BAD:
			return "[color=#f98]" + tr(&"UI_LOG_MORALE_BAD") % actor + "[/color]"
		BattleEvent.Kind.LUCK_GOOD:
			return "[color=#fd6]" + tr(&"UI_LOG_LUCK_GOOD") % actor + "[/color]"
		BattleEvent.Kind.LUCK_BAD:
			return "[color=#c9f]" + tr(&"UI_LOG_LUCK_BAD") % actor + "[/color]"
		BattleEvent.Kind.SURRENDERED:
			return tr(&"UI_LOG_SURRENDER") % side_name(event.side)
		BattleEvent.Kind.BATTLE_ENDED:
			return "[b]" + tr(&"UI_LOG_END") % side_name(event.side) + "[/b]"
		BattleEvent.Kind.ABILITY:
			return "[color=#adf]" + tr(&"UI_LOG_ABILITY") % [actor, ability_name(event.ability)] + "[/color]"
		BattleEvent.Kind.EFFECT_ADDED:
			return "  " + tr(&"UI_LOG_EFFECT_ADDED") % [target, ability_name(event.ability)]
		BattleEvent.Kind.EFFECT_ENDED:
			return "  " + tr(&"UI_LOG_EFFECT_ENDED") % [actor, ability_name(event.ability)]
		BattleEvent.Kind.HEALED:
			return "  [color=#8f8]" + tr(&"UI_LOG_HEALED") % [target, event.damage, event.killed] + "[/color]"
	return ""


func ability_name(ability_id: StringName) -> String:
	var ability: AbilityDef = _data.ability(ability_id)
	return tr(ability.name_key) if ability != null else String(ability_id)


func side_name(side: int) -> String:
	return tr(&"UI_SIDE_ATTACKER") if side == 0 else tr(&"UI_SIDE_DEFENDER")


func _stack_name(stack_id: int) -> String:
	var stack: BattleStack = _state.stack(stack_id)
	return "" if stack == null else unit_name(stack.unit_id)


func _process(_delta: float) -> void:
	if _view == null or _camera == null or _camera.camera == null:
		return
	if _cursor_panel.visible:
		var at: Vector2 = cursor_pin if cursor_pin.x >= 0.0 else get_local_mouse_position()
		_cursor_panel.position = at + Vector2(22.0, 18.0)
	for stack_id: int in _badges:
		var badge: Control = _badges[stack_id]
		var stack_view: StackView = _view.view(stack_id)
		if stack_view == null or stack_view.dead or not stack_view.visible \
				or _camera.camera.is_position_behind(stack_view.badge_anchor()):
			badge.visible = false
			continue
		badge.visible = true
		var count_label: Label = badge.get_node("Box/Count")
		count_label.text = str(stack_view.shown_count)
		var bar: ProgressBar = badge.get_node("Box/Health")
		bar.max_value = stack_view.max_total_hp
		bar.value = stack_view.shown_hp
		badge.position = _camera.camera.unproject_position(stack_view.badge_anchor()) - badge.size * 0.5


func _make_badge(side: int) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _box(Color(0.05, 0.05, 0.07, 0.8), StackView.SIDE_COLORS[side], 2, 4))
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 1)
	panel.add_child(box)
	var count: Label = Label.new()
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override(&"font_size", 16)
	box.add_child(count)
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "Health"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(46.0, 5.0)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 0.35)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.25, 0.08, 0.08)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", back)
	box.add_child(bar)
	return panel


func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	return row


func _panel(padding: int = 8) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _box(PANEL_COLOR, Color(0.3, 0.3, 0.35), 1, padding))
	return panel


func _build_top(top: HBoxContainer) -> void:
	var hint: Label = Label.new()
	hint.text = tr(&"UI_BATTLE_HINT")
	hint.add_theme_font_size_override(&"font_size", 14)
	hint.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.9, 0.8))
	hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hint.add_theme_constant_override(&"outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_stretch_ratio = 1.0
	top.add_child(hint)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(center)
	var holder: PanelContainer = _panel()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	center.add_child(holder)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 18)
	holder.add_child(_status)
	var right: Control = Control.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)


func _build_queue() -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_END
	var holder: PanelContainer = _panel(6)
	center.add_child(holder)
	_queue_box = HBoxContainer.new()
	_queue_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue_box.add_theme_constant_override(&"separation", 6)
	holder.add_child(_queue_box)
	return center


func _make_slot(stack: BattleStack, current: bool) -> Control:
	var slot: PanelContainer = PanelContainer.new()
	slot.add_theme_stylebox_override(&"panel", _box(Color(0.12, 0.12, 0.14), StackView.SIDE_COLORS[stack.side],
			4 if current else 2, 4))
	slot.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE) * (1.15 if current else 1.0)
	var picture: TextureRect = TextureRect.new()
	picture.texture = PlaceholderAssets.portrait(&"creature", stack.unit_id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(picture)
	var count: Label = Label.new()
	count.text = str(stack.count)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override(&"font_size", 15)
	count.add_theme_color_override(&"font_outline_color", Color.BLACK)
	count.add_theme_constant_override(&"outline_size", 5)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)
	var stack_id: int = stack.id
	slot.mouse_entered.connect(func() -> void: slot_hovered.emit(stack_id))
	slot.mouse_exited.connect(func() -> void: slot_hovered.emit(-1))
	return slot


func _build_actions() -> Control:
	var holder: PanelContainer = _panel(6)
	holder.size_flags_vertical = Control.SIZE_SHRINK_END
	var box: VBoxContainer = VBoxContainer.new()
	holder.add_child(box)
	for spec: Array in [[&"wait", &"UI_BATTLE_WAIT"], [&"defend", &"UI_BATTLE_DEFEND"],
			[&"auto", &"UI_BATTLE_AUTO"], [&"surrender", &"UI_BATTLE_SURRENDER"],
			[&"grid", &"UI_BATTLE_GRID"], [&"speed", &"UI_BATTLE_SPEED"], [&"log", &"UI_BATTLE_LOG"]]:
		var button: Button = Button.new()
		button.name = String(spec[0])
		button.text = tr(spec[1])
		button.custom_minimum_size = Vector2(170.0, 34.0)
		button.focus_mode = Control.FOCUS_NONE
		var action: StringName = spec[0]
		if action == &"auto" or action == &"grid" or action == &"log":
			button.toggle_mode = true
		button.pressed.connect(func() -> void: _on_button(action))
		box.add_child(button)
		_buttons.append(button)
		match action:
			&"auto":
				_auto_button = button
			&"grid":
				_grid_button = button
				button.set_pressed_no_signal(true)
			&"speed":
				_speed_button = button
	_update_speed_text()
	return holder


func _on_button(action: StringName) -> void:
	if action == &"speed":
		_speed_index = (_speed_index + 1) % SPEEDS.size()
		_update_speed_text()
	elif action == &"log":
		_log_panel.visible = not _log_panel.visible
		return
	action_pressed.emit(action)


func _update_speed_text() -> void:
	_speed_button.text = tr(&"UI_BATTLE_SPEED") % str(int(SPEEDS[_speed_index]))


func _build_stack_panel() -> Control:
	var holder: PanelContainer = _panel()
	holder.size_flags_vertical = Control.SIZE_SHRINK_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack_panel = Label.new()
	_stack_panel.custom_minimum_size = Vector2(260.0, 0.0)
	_stack_panel.add_theme_font_size_override(&"font_size", 17)
	holder.add_child(_stack_panel)
	return holder


func _build_log() -> void:
	_log_panel = _panel()
	_log_panel.custom_minimum_size = Vector2(440.0, 320.0)
	_log_panel.visible = false
	add_child(_log_panel)
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override(&"normal_font_size", 15)
	_log.add_theme_font_size_override(&"bold_font_size", 15)
	_log_panel.add_child(_log)


func _build_cursor() -> void:
	_cursor_panel = PanelContainer.new()
	_cursor_panel.add_theme_stylebox_override(&"panel", _box(Color(0.05, 0.05, 0.07, 0.9), Color(0.85, 0.75, 0.45), 1, 6))
	_cursor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_panel.visible = false
	add_child(_cursor_panel)
	_cursor_label = Label.new()
	_cursor_label.add_theme_font_size_override(&"font_size", 16)
	_cursor_panel.add_child(_cursor_label)


static func _box(fill: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box
