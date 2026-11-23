extends AbilityHook

## Test handler: whom it strikes does not retaliate.


func can_retaliate(_state: BattleState, owner: BattleStack, attacker: BattleStack, _defender: BattleStack,
		_params: Dictionary) -> bool:
	return owner.id != attacker.id
