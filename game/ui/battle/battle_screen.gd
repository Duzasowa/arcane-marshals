class_name BattleScreen
extends Node

## The battle screen: owns the battle state, shows it through `BattleView`,
## turns the player's clicks into commands and lets `BattleAi` play the other
## side (and the player's side on "Auto"). The state changes only in `submit` →
## `BattleState.apply(cmd)`; everything else reads it.
##
## Mouse: hover shows where the stack can go, whom it can strike and the hit
## forecast; a click does it. Keys: W wait, D defend, A auto, G grid.

const BOT_DELAY: float = 0.35
const NOWHERE: Vector2i = Vector2i(-1, -1)

var state: BattleState = null
var data: GameData = null
var arena: BattleArena = null
var camera_rig: BattleCamera = null
var view: BattleView = null
var hud: BattleHud = null
var sounds: BattleSounds = null

## Per side: the bot plays it (a bot side, or a human side on "Auto").
var _auto: Array[bool] = [false, false]
## Per side: the AI that plays it when `_auto` is on.
var _ais: Array[BattleAi] = []
var _busy: bool = false
var _reach: Dictionary[int, int] = {}
var _planned: BattleCmd = null
var _canvas: CanvasLayer = null
var _result_panel: BattleResultPanel = null


func _ready() -> void:
	AppSettings.apply_locale()
	data = GameData.new()
	data.load_all()
	if not BattleLaunch.is_set():
		BattleLaunch.demo()
	state = BattleSetup.create(data, BattleLaunch.attacker, BattleLaunch.defender, BattleLaunch.seed_value)
	_auto = [not BattleLaunch.human[0], not BattleLaunch.human[1]]
	for side: int in BattleState.SIDE_COUNT:
		var level: int = BattleAi.Difficulty.NORMAL if BattleLaunch.human[side] else BattleLaunch.ai_level[side]
		_ais.append(BattleAi.new(level as BattleAi.Difficulty, BattleLaunch.seed_value * 2 + side))
	arena = BattleArena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(state.grid)
	camera_rig = BattleCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	view = BattleView.new()
	view.name = "View"
	add_child(view)
	view.setup(state, data)
	sounds = BattleSounds.new()
	sounds.name = "Sounds"
	add_child(sounds)
	sounds.setup(state)
	_canvas = CanvasLayer.new()
	add_child(_canvas)
	hud = BattleHud.new()
	hud.name = "Hud"
	_canvas.add_child(hud)
	hud.setup(state, data, view, camera_rig)
	hud.action_pressed.connect(_on_action)
	hud.slot_hovered.connect(_on_slot_hovered)
	view.event_shown.connect(_on_event_shown)
	_play(state.take_events())


## Applies a command and plays what it caused. False when it was refused.
func submit(cmd: BattleCmd) -> bool:
	if _busy or cmd == null or state.is_over():
		return false
	var reason: String = state.validate(cmd)
	if reason != "" or not state.apply(cmd):
		hud.add_log("[color=#f66]%s[/color]" % reason)
		return false
	_play(state.take_events())
	return true


## True when a human may act now.
func is_player_turn() -> bool:
	var who: BattleStack = state.active_stack()
	return not _busy and not state.is_over() and who != null and not _auto[who.side]


func is_busy() -> bool:
	return _busy


## The command a click would give now ("" plan — null).
func planned_command() -> BattleCmd:
	return _planned


## Shows the hover of the cursor over `cell` (and a point inside it), as if the
## mouse were there; for scripts and screenshots.
func preview(cell: Vector2i, offset: Vector2 = Vector2.ZERO) -> void:
	var point: Vector3 = BattleArena.cell_center(cell) + Vector3(offset.x, 0.0, offset.y)
	_hover(point)
	hud.cursor_pin = camera_rig.camera.unproject_position(point)


func set_auto(side: int, on: bool) -> void:
	_auto[side] = on
	if not _busy and not state.is_over():
		_next_turn()


func _play(events: Array[BattleEvent]) -> void:
	_busy = true
	_planned = null
	arena.clear_highlights()
	hud.set_cursor_text("")
	hud.set_actions_enabled(false)
	await view.play(events)
	_busy = false
	hud.refresh()
	_next_turn()


func _next_turn() -> void:
	if state.is_over():
		_show_result()
		return
	var who: BattleStack = state.active_stack()
	if _auto[who.side]:
		hud.set_status(tr(&"UI_BATTLE_BOT_TURN"))
		hud.set_actions_enabled(false)
		var turn: int = state.turn_count
		await get_tree().create_timer(BOT_DELAY / view.speed).timeout
		# The player may have switched "Auto" or the turn moved on meanwhile.
		if _busy or state.is_over() or state.turn_count != turn or not _auto[state.active_stack().side]:
			return
		submit(_ais[state.active_stack().side].choose(state))
		return
	hud.set_status("")
	hud.set_actions_enabled(true)
	_reach = BattlePathfinder.reachable(state, who)
	_show_turn()
	var point: Variant = camera_rig.ground_point(get_viewport().get_mouse_position())
	if point != null:
		_hover(point)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hud.cursor_pin = Vector2(-1.0, -1.0)
		var point: Variant = camera_rig.ground_point((event as InputEventMouseMotion).position)
		if point != null:
			_hover(point)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and is_player_turn() and _planned != null:
			submit(_planned)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_W:
				_on_action(&"wait")
			KEY_D:
				_on_action(&"defend")
			KEY_A:
				_on_action(&"auto")
			KEY_G:
				_on_action(&"grid")


func _on_action(action: StringName) -> void:
	sounds.click()
	match action:
		&"grid":
			arena.set_grid_visible(not arena.is_grid_visible())
			hud.set_grid(arena.is_grid_visible())
		&"speed":
			view.speed = hud.speed()
		&"auto":
			var human_side: int = _human_side()
			if human_side >= 0:
				var on: bool = not _auto[human_side]
				hud.set_auto(on)
				set_auto(human_side, on)
		&"wait":
			if is_player_turn():
				submit(WaitCmd.new(state.active_id))
		&"defend":
			if is_player_turn():
				submit(DefendCmd.new(state.active_id))
		&"surrender":
			if is_player_turn():
				submit(SurrenderCmd.new(state.active_stack().side))


func _on_event_shown(event: BattleEvent) -> void:
	sounds.on_event(event)
	var line: String = hud.describe(event)
	if line != "":
		hud.add_log(line)
	if event.kind == BattleEvent.Kind.TURN_STARTED or event.kind == BattleEvent.Kind.DIED:
		hud.refresh()


func _on_slot_hovered(stack_id: int) -> void:
	if not is_player_turn():
		return
	_show_turn()
	var stack: BattleStack = state.stack(stack_id)
	if stack != null:
		arena.highlight(stack.cell, BattleArena.Highlight.HOVER, stack.size)
		hud.show_stack(stack)
	else:
		hud.show_stack(state.active_stack())


## The highlights of the turn: where the stack can go, whom it can strike.
func _show_turn() -> void:
	arena.clear_highlights()
	var who: BattleStack = state.active_stack()
	if who == null:
		return
	for cell_index: int in _reach:
		arena.highlight(BattleGrid.cell_at(cell_index), BattleArena.Highlight.REACHABLE)
	var shoots: bool = state.can_shoot(who)
	for enemy: BattleStack in state.enemies_of(who):
		if shoots or not state.attack_spots(who, enemy, _reach).is_empty():
			arena.highlight(enemy.cell, BattleArena.Highlight.TARGET, enemy.size)
	arena.highlight(who.cell, BattleArena.Highlight.ACTIVE, who.size)


## Works out what a click at `point` would do and shows it.
func _hover(point: Vector3) -> void:
	if not is_player_turn():
		return
	_planned = null
	_show_turn()
	var who: BattleStack = state.active_stack()
	var cell: Vector2i = BattleArena.world_to_cell(point)
	var under: BattleStack = state.stack_at(cell)
	hud.show_stack(under if under != null else who)
	var text: String = ""
	if under != null and under.side != who.side:
		if state.can_shoot(who):
			_planned = ShootCmd.new(who.id, under.id)
			var far: bool = BattleGrid.distance(who.cell, who.size, under.cell, under.size) > DamageCalc.LONG_RANGE
			text = tr(&"UI_BATTLE_ACTION_SHOOT_HALF" if far else &"UI_BATTLE_ACTION_SHOOT") + "\n" \
					+ _forecast_text(DamageCalc.estimate(state, who, who.cell, under, DamageCalc.Kind.SHOT))
		else:
			var spot: Vector2i = _nearest_spot(who, under, point)
			if spot != NOWHERE:
				_planned = AttackCmd.new(who.id, under.id, spot)
				arena.highlight(spot, BattleArena.Highlight.SPOT, who.size)
				var forecast: Dictionary = DamageCalc.estimate(state, who, spot, under, DamageCalc.Kind.MELEE)
				text = tr(&"UI_BATTLE_ACTION_ATTACK") + "\n" + _forecast_text(forecast) + "\n" \
						+ _retaliation_text(who, spot, under, forecast)
	elif under == null and BattleGrid.in_bounds(cell) and _reach.has(BattleGrid.index(cell)) and cell != who.cell:
		_planned = MoveCmd.new(who.id, cell)
		for cell_index: int in BattlePathfinder.path(state, who, cell):
			arena.highlight(BattleGrid.cell_at(cell_index), BattleArena.Highlight.PATH, who.size)
		text = tr(&"UI_BATTLE_ACTION_MOVE")
	elif BattleGrid.in_bounds(cell) and under == null:
		arena.highlight(cell, BattleArena.Highlight.HOVER)
	hud.set_cursor_text(text)


## The attack spot closest to the cursor: the side of the target it points at.
func _nearest_spot(who: BattleStack, target: BattleStack, point: Vector3) -> Vector2i:
	var best: Vector2i = NOWHERE
	var best_distance: float = INF
	for spot: Vector2i in state.attack_spots(who, target, _reach):
		var distance: float = BattleArena.cell_center(spot, who.size).distance_squared_to(point)
		if distance < best_distance - 0.0001:
			best = spot
			best_distance = distance
	return best


func _forecast_text(forecast: Dictionary) -> String:
	return tr(&"UI_BATTLE_FORECAST") % [forecast[&"min_damage"], forecast[&"max_damage"],
			forecast[&"min_killed"], forecast[&"max_killed"]]


## The retaliation range: after the strongest blow the least comes back, after
## the weakest the most (`BattleForecast.retaliation`, the AI's forecast too).
func _retaliation_text(who: BattleStack, spot: Vector2i, target: BattleStack, forecast: Dictionary) -> String:
	if target.retaliations_left <= 0:
		return tr(&"UI_BATTLE_NO_RETALIATION")
	var after_strong: Dictionary = BattleForecast.retaliation(state, who, spot, target, forecast[&"max_damage"])
	var after_weak: Dictionary = BattleForecast.retaliation(state, who, spot, target, forecast[&"min_damage"])
	var low: int = after_strong.get(&"min_damage", 0)
	var high: int = after_weak.get(&"max_damage", 0)
	if high == 0:
		return tr(&"UI_BATTLE_NO_RETALIATION")
	return tr(&"UI_BATTLE_FORECAST_RETALIATION") % [low, high]


func _human_side() -> int:
	for side: int in BattleState.SIDE_COUNT:
		if BattleLaunch.human[side]:
			return side
	return -1


func _show_result() -> void:
	hud.set_status("")
	hud.set_actions_enabled(false)
	if _result_panel != null:
		return
	_result_panel = BattleResultPanel.new()
	_canvas.add_child(_result_panel)
	var viewer: int = _human_side()
	if BattleLaunch.human[0] and BattleLaunch.human[1]:
		viewer = -1
	_result_panel.show_result(state.result, hud, viewer)
	_result_panel.again_pressed.connect(_on_again)
	_result_panel.back_pressed.connect(_on_back)


func _on_again() -> void:
	sounds.click()
	BattleLaunch.seed_value += 1
	get_tree().reload_current_scene()


func _on_back() -> void:
	sounds.click()
	get_tree().change_scene_to_file(BattleLaunch.return_scene)
