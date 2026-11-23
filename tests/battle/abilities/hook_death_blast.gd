extends AbilityHook

## Test handler: when wiped out, deals `damage` to every stack next to it.


func on_death(state: BattleState, owner: BattleStack, _killer: BattleStack, params: Dictionary) -> void:
	state.emit_ability(owner, &"death_blast")
	for other: BattleStack in state.alive_stacks():
		if BattleGrid.adjacent(other.cell, other.size, owner.cell, owner.size):
			state.deal_damage(owner, other, int(params[&"damage"]))
