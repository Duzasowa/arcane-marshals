extends AbilityHook

## Test handler: takes `damage` at the start of each of its turns.


func on_turn_start(state: BattleState, owner: BattleStack, params: Dictionary) -> void:
	state.emit_ability(owner, &"bleeding")
	state.deal_damage(null, owner, int(params[&"damage"]))
