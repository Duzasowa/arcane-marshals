extends AbilityHook

## Heal, an active ability (docs/MECHANICS.md §5): instead of acting, heals a
## wounded stack of its side (itself too) by `per_creature` HP per owner's
## creature, raising the dead up to the starting count.


func use_targets(state: BattleState, owner: BattleStack, _params: Dictionary) -> Array[BattleStack]:
	var wounded: Array[BattleStack] = []
	for ally: BattleStack in state.alive_stacks(owner.side):
		if ally.total_hp() < ally.initial_count * ally.hp:
			wounded.append(ally)
	return wounded


func on_use(state: BattleState, owner: BattleStack, target: BattleStack, params: Dictionary) -> void:
	state.heal(owner, target, owner.count * int(params[&"per_creature"]), true)
