extends AbilityHook

## Test handler: counts its hooks in its params (the stack's own copy).


func on_battle_start(_state: BattleState, _owner: BattleStack, params: Dictionary) -> void:
	_count(params, &"battle_start")


func on_turn_start(state: BattleState, owner: BattleStack, params: Dictionary) -> void:
	_count(params, &"turn_start")
	state.emit_ability(owner, &"counter")


func on_after_move(_state: BattleState, _owner: BattleStack, _from: Vector2i, params: Dictionary) -> void:
	_count(params, &"after_move")


func on_after_attack(_state: BattleState, _owner: BattleStack, _target: BattleStack, _kind: DamageCalc.Kind,
		params: Dictionary) -> void:
	_count(params, &"after_attack")


static func _count(params: Dictionary, key: StringName) -> void:
	params[key] = int(params.get(key, 0)) + 1
