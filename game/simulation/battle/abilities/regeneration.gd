extends AbilityHook

## Regeneration (docs/MECHANICS.md §5): at the start of its turn the top
## creature heals to full HP; the dead do not rise.


func on_turn_start(state: BattleState, owner: BattleStack, _params: Dictionary) -> void:
	state.heal(owner, owner, owner.hp - owner.top_hp, false)
