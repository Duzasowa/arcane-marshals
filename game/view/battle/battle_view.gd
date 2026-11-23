class_name BattleView
extends Node3D

## Shows the battle: one `StackView` per stack, played event by event
## (`play`). Reads the state and the events only; after a batch of events it
## snaps every view to the state, so a missed detail can never drift.

## Each event as it is shown, for the log and the sounds.
signal event_shown(event: BattleEvent)

const PROJECTILE_TIME: float = 0.3
const TEXT_TIME: float = 0.9
const PAUSE_AFTER_HIT: float = 0.25

var views: Dictionary[int, StackView] = {}
var busy: bool = false
## Animation speed: 1 — normal, 2 — twice as fast.
var speed: float = 1.0:
	set(value):
		speed = maxf(0.1, value)
		for view: StackView in views.values():
			view.speed = speed

var _state: BattleState = null


func setup(state: BattleState, data: GameData) -> void:
	_state = state
	for stack: BattleStack in state.stacks:
		var view: StackView = StackView.new()
		add_child(view)
		view.setup(stack, data.unit(stack.unit_id))
		view.speed = speed
		if not stack.is_alive():
			view.visible = false
		views[stack.id] = view
	_mark_active()


func view(stack_id: int) -> StackView:
	return views.get(stack_id, null)


## Plays the events in order; returns when the last animation is done.
func play(events: Array[BattleEvent]) -> void:
	busy = true
	for event: BattleEvent in events:
		event_shown.emit(event)
		await _show(event)
	sync()
	busy = false


## Snaps all views to the state.
func sync() -> void:
	for stack: BattleStack in _state.stacks:
		views[stack.id].sync(stack)
	_mark_active()


func _show(event: BattleEvent) -> void:
	var actor: StackView = view(event.stack_id)
	var target: StackView = view(event.target_id)
	match event.kind:
		BattleEvent.Kind.TURN_STARTED:
			_mark_active()
		BattleEvent.Kind.MOVED:
			var points: Array[Vector3] = []
			for cell_index: int in event.cells:
				points.append(BattleArena.cell_center(BattleGrid.cell_at(cell_index), actor.size))
			await actor.move_along(points)
		BattleEvent.Kind.ATTACKED, BattleEvent.Kind.RETALIATED:
			target.face(actor.global_position)
			await actor.strike(target.global_position, false)
		BattleEvent.Kind.SHOT:
			await actor.strike(target.global_position, true)
			await _projectile(actor.badge_anchor() - Vector3(0.0, 0.4, 0.0), target.badge_anchor() - Vector3(0.0, 0.5, 0.0))
		BattleEvent.Kind.DAMAGED:
			target.take_hit(event.damage, event.killed)
			var text: String = "−%d" % event.damage
			if event.killed > 0:
				text = tr(&"UI_BATTLE_DAMAGE_KILLED") % [event.damage, event.killed]
			_float_text(target.badge_anchor(), text, Color(1.0, 0.85, 0.3))
			await _wait(PAUSE_AFTER_HIT)
		BattleEvent.Kind.DIED:
			await actor.die()
		BattleEvent.Kind.HEALED:
			target.heal(event.damage, event.killed)
			_float_text(target.badge_anchor(), tr(&"UI_BATTLE_HEALED") % event.damage, Color(0.5, 1.0, 0.6))
			await _wait(0.35)
		BattleEvent.Kind.DEFENDED:
			actor.defend()
			_float_text(actor.badge_anchor(), tr(&"UI_BATTLE_DEFEND"), Color(0.6, 0.85, 1.0))
			await _wait(0.35)
		BattleEvent.Kind.WAITED:
			_float_text(actor.badge_anchor(), tr(&"UI_BATTLE_WAIT"), Color(0.85, 0.85, 0.85))
			await _wait(0.2)
		BattleEvent.Kind.MORALE_GOOD:
			_float_text(actor.badge_anchor(), tr(&"UI_BATTLE_MORALE_GOOD"), Color(0.5, 1.0, 0.5))
			await _wait(0.4)
		BattleEvent.Kind.MORALE_BAD:
			_float_text(actor.badge_anchor(), tr(&"UI_BATTLE_MORALE_BAD"), Color(1.0, 0.45, 0.4))
			await _wait(0.4)
		BattleEvent.Kind.LUCK_GOOD:
			_float_text(actor.badge_anchor(), tr(&"UI_BATTLE_LUCK_GOOD"), Color(1.0, 0.9, 0.3))
		BattleEvent.Kind.LUCK_BAD:
			_float_text(actor.badge_anchor(), tr(&"UI_BATTLE_LUCK_BAD"), Color(0.8, 0.6, 1.0))
		BattleEvent.Kind.BATTLE_ENDED:
			for stack_view: StackView in views.values():
				if stack_view.side == event.side:
					stack_view.cheer()
			await _wait(0.6)


func _mark_active() -> void:
	for stack_view: StackView in views.values():
		stack_view.set_active(stack_view.stack_id == _state.active_id)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / speed).timeout


func _projectile(from: Vector3, to: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.45)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.25, 0.15)
	mesh.material = material
	var bolt: MeshInstance3D = MeshInstance3D.new()
	bolt.mesh = mesh
	add_child(bolt)
	bolt.global_position = from
	bolt.look_at_from_position(from, to, Vector3.UP)
	var tween: Tween = create_tween()
	tween.tween_property(bolt, "global_position", to, PROJECTILE_TIME / speed)
	await tween.finished
	bolt.queue_free()


func _float_text(at: Vector3, text: String, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.outline_size = 12
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	add_child(label)
	label.global_position = at
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", at + Vector3(0.0, 0.7, 0.0), TEXT_TIME / speed)
	tween.tween_property(label, "modulate:a", 0.0, TEXT_TIME / speed).set_delay(TEXT_TIME * 0.5 / speed)
	tween.chain().tween_callback(label.queue_free)
