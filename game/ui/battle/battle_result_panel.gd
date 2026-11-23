class_name BattleResultPanel
extends Control

## The end of the battle: who won, the losses of both sides by unit, the
## experience, and the way on ("Again" / "Back").

signal again_pressed
signal back_pressed


## `viewer_side` — the side a human played (-1 — bot against bot).
func show_result(result: BattleResult, hud: BattleHud, viewer_side: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", BattleHud._box(Color(0.09, 0.09, 0.11, 0.96), Color(0.85, 0.75, 0.45), 2, 24))
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	var title: Label = Label.new()
	if viewer_side >= 0:
		title.text = tr(&"UI_RESULT_VICTORY") if result.winner == viewer_side else tr(&"UI_RESULT_DEFEAT")
	else:
		title.text = tr(&"UI_RESULT_WINNER") % hud.side_name(result.winner)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 40)
	title.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.55))
	box.add_child(title)
	if result.ended_by == BattleResult.EndedBy.SURRENDER:
		box.add_child(_line(tr(&"UI_RESULT_BY_SURRENDER"), 18))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 40)
	box.add_child(columns)
	for side: int in BattleState.SIDE_COUNT:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var heading: Label = _line(hud.side_name(side).capitalize(), 22)
		heading.add_theme_color_override(&"font_color", StackView.SIDE_COLORS[side])
		column.add_child(heading)
		column.add_child(_line(tr(&"UI_RESULT_LOSSES") + ":", 17))
		var losses: Dictionary = result.losses[side]
		if losses.is_empty():
			column.add_child(_line("  " + tr(&"UI_RESULT_NO_LOSSES"), 17))
		for unit_id: StringName in losses:
			column.add_child(_line("  %s × %d" % [hud.unit_name(unit_id), losses[unit_id]], 17))
		column.add_child(_line(tr(&"UI_RESULT_EXPERIENCE") % result.experience[side], 17))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	box.add_child(buttons)
	var again: Button = Button.new()
	again.name = "Again"
	again.text = tr(&"UI_RESULT_AGAIN")
	again.custom_minimum_size = Vector2(160.0, 40.0)
	again.pressed.connect(again_pressed.emit)
	buttons.add_child(again)
	var back: Button = Button.new()
	back.name = "Back"
	back.text = tr(&"UI_RESULT_BACK")
	back.custom_minimum_size = Vector2(160.0, 40.0)
	back.pressed.connect(back_pressed.emit)
	buttons.add_child(back)


static func _line(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
