extends AbilityHook

## The effect "poisoned" (docs/MECHANICS.md §5): at the start of each of its
## turns the owner takes `damage`.


func on_turn_start(state: BattleState, owner: BattleStack, params: Dictionary) -> void:
	state.deal_damage(null, owner, int(params[&"damage"]))
