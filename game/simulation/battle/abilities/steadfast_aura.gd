extends AbilityHook

## Steadfast aura (docs/MECHANICS.md §5): the owner and its neighbours never
## have morale below 0, so they never lose a turn to bad morale.


func modify_morale(_state: BattleState, _owner: BattleStack, _stack: BattleStack, morale: int,
		_params: Dictionary) -> int:
	return maxi(morale, 0)
