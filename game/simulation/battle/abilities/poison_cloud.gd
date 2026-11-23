extends AbilityHook

## Poison cloud (docs/MECHANICS.md §5): when the owner is wiped out, every
## enemy next to it is poisoned (the effect of `poison`) for `turns`:
## `per_creature` permille HP per creature the owner began the battle with.

const ID: StringName = &"poison_cloud"
const POISON: StringName = &"poison"
const POISONED: String = "res://game/simulation/battle/abilities/effects/poisoned.gd"


func on_death(state: BattleState, owner: BattleStack, _killer: BattleStack, params: Dictionary) -> void:
	var neighbours: Array[BattleStack] = state.adjacent_stacks(owner, 1 - owner.side)
	if neighbours.is_empty():
		return
	state.emit_ability(owner, ID)
	var damage: int = maxi(1, owner.initial_count * int(params[&"per_creature"]) / DamageCalc.NORMAL)
	for enemy: BattleStack in neighbours:
		state.add_effect(owner, enemy, POISON, POISONED, {&"damage": damage}, int(params[&"turns"]))
