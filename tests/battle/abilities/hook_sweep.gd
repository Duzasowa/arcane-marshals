extends AbilityHook

## Test handler: its melee blow also hits every other enemy next to it.


func extra_targets(state: BattleState, owner: BattleStack, _target: BattleStack, _params: Dictionary) -> Array[BattleStack]:
	return state.adjacent_stacks(owner, 1 - owner.side)
