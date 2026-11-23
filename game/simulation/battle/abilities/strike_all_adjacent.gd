extends AbilityHook

## A blow hits every enemy next to the owner (docs/MECHANICS.md §5); only the
## chosen target may answer.


func extra_targets(state: BattleState, owner: BattleStack, _target: BattleStack, _params: Dictionary) -> Array[BattleStack]:
	return state.adjacent_stacks(owner, 1 - owner.side)
