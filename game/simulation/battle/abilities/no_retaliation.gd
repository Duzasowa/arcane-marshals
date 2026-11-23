extends AbilityHook

## The owner's blows are not answered (docs/MECHANICS.md §5). With
## `wounded_only`, only a wounded target (some HP lost before the blow) does
## not answer.


func can_retaliate(_state: BattleState, owner: BattleStack, attacker: BattleStack, defender: BattleStack,
		params: Dictionary) -> bool:
	if owner != attacker:
		return true
	if params.get(&"wounded_only", false):
		return defender.total_hp() >= defender.initial_count * defender.hp
	return false
