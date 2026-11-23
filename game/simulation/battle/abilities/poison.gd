extends AbilityHook

## Poison (docs/MECHANICS.md §5): a target that survives a blow or a shot is
## poisoned for `turns` of its turns: `per_creature` permille HP per owner's
## creature (at least 1) at the start of each. Poison again renews it.

const ID: StringName = &"poison"
const POISONED: String = "res://game/simulation/battle/abilities/effects/poisoned.gd"


func on_after_attack(state: BattleState, owner: BattleStack, target: BattleStack, _kind: DamageCalc.Kind,
		params: Dictionary) -> void:
	if target.is_alive():
		var damage: int = maxi(1, owner.count * int(params[&"per_creature"]) / DamageCalc.NORMAL)
		state.add_effect(owner, target, ID, POISONED, {&"damage": damage}, int(params[&"turns"]))
